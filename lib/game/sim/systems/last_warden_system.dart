import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/systems/draw_system.dart';

/// The Last Warden — docs/06 §6.3, Endless Descent boss #20. "×140 HP, 150s.
/// The true final boss. The Warden who held the Spire before you. Five
/// phases, not three." By far the largest single scope in the boss roster
/// (ADR 0058's own closing line) — built across several parts, one phase (or
/// phase-group) at a time, the same posture Cinder Choir's own four-part
/// P1-P3 build established early in this roster.
///
/// **P1, built here: "Draw/Momentum duel at parity — it plays the game
/// exactly as the player does."** The one card in this entire roster that
/// asks a boss to run the player's own core resource loop, not a themed
/// variant of it — which is exactly what makes this phase cheap to build
/// faithfully rather than approximate: `DrawState`/[DrawSystem] were already
/// generic across any number of live instances the moment the Hollow
/// Warden's own `hollowWardenDraw` proved it (ADR 0031), so a third
/// instance — `SimWorld.lastWardenDraw` — gets the identical ramp-while-
/// still, stack-while-moving rules the player's own Draw runs under, for
/// free.
///
/// "At parity" is read as two real trades, both ways:
///
/// - **Momentum's speed bonus is real for the Warden**, the same
///   `moveSpeedBonus` getter the player's own movement already reads,
///   applied to every step this system takes.
/// - **Momentum's damage reduction is real for the Warden too** — the one
///   piece with no existing hook to reuse, since every other enemy attack
///   pipeline in the game reduces the *player's* incoming damage, never an
///   enemy's own. Intercepting a hit before it lands would mean touching
///   `ProjectileSystem._applyHit`, the single most shared, most heavily
///   tested function in the whole combat pipeline, for a boss-archetype-
///   specific branch nothing else in that file has ever needed. Instead
///   this reuses Rimefather's own "observe and correct after the fact"
///   shape (ADR 0050): `_tickDamageReduction` diffs this tick's health
///   against a baseline read last tick (`bossLastHitAgo`, free — P1 has no
///   children yet to need it for) and refunds a `damageReduction` fraction
///   of whatever dropped. A player at max Momentum takes 10% less damage;
///   the Warden, fighting by the identical rule, does too.
///
/// The rhythm itself — approach and hold to ramp Draw, fire at Tier III,
/// then deliberately disengage to rebuild Momentum before closing again —
/// is docs/01 §1.1's own "root to escalate, move to survive, repeat" player
/// loop, mirrored: `bossTimer` (free) holds a reposition countdown that
/// starts the instant a heavy shot fires, during which the Warden retreats
/// (building Momentum, the mirror of the player's own dash-away-to-refill
/// beat) rather than closing straight back in. The heavy shot itself reuses
/// `EnemyAttack.fireBolt`, the same primitive — and the same "fraction of
/// max HP, derived from an existing anchor, not the player's own actual
/// arrow type or hero stats" honesty ADR 0031 already established for the
/// Hollow Warden's own heavy shot, since porting real arrow behaviour onto
/// an enemy body is the identical out-of-scope redesign question here that
/// it was there.
abstract final class LastWardenSystem {
  /// Reused from the Hollow Warden's own mirror-approach speed — a
  /// deliberate, readable closing pace, not a lunge.
  static const double _approachSpeed = 2.4;

  /// The distance at which the Warden stops closing and plants to Draw —
  /// authored, close enough that the duel reads as a real confrontation
  /// rather than kiting at range.
  static const double _engageRange = 3.0;
  static const double _engageRangeSq = _engageRange * _engageRange;

  /// How long the Warden deliberately disengages after each heavy shot to
  /// rebuild Momentum before closing again — authored, long enough to
  /// matter against [DrawState]'s own stack-gain rate without stalling the
  /// duel's own pace.
  static const double _repositionSeconds = 1.4;

  /// Reused from the Hollow Warden's own heavy bolt (docs/05 #24's own
  /// numbers, already reused once).
  static const double _boltProjectileSpeed = 8.0;
  static const double _boltRange = 14.0;
  static const double _boltRadius = 0.35;

  /// The heavy shot's own damage — the roster's own derived heavy-hit
  /// anchor (Thresher's 9% persistent-aura anchor, scaled by Tier III's own
  /// 2.10x multiplier), the same number this whole roster already reaches
  /// for by default. See the class doc comment.
  static const double _heavyShotDamage = 0.09 * 2.10;

  /// Places the Warden's single, stationary-until-it-moves body. Returns
  /// its slot, or -1 if the entity pool was full or [BossArchetype.
  /// lastWarden] has no catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 0.6,
  }) {
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.lastWarden);
    if (bossIndex < 0) return -1;

    final EntityId id = store.spawn(EntityKind.enemy);
    if (id.isNone) return -1;
    final int slot = id.index;

    store.posX[slot] = centerX;
    store.posY[slot] = centerY;
    store.radius[slot] = radius;
    store.health[slot] = health;
    store.maxHealth[slot] = health;
    store.contentIndex[slot] = -1;
    events.emit(SimEventType.entitySpawned, entityA: slot, x: centerX, y: centerY);

    enemies.reset(slot);
    enemies.bossIndex[slot] = bossIndex;
    // A health baseline for `_tickDamageReduction`'s own tick-to-tick
    // diff — the same repurposing Rimefather's own mirrors already use
    // `bossLastHitAgo` for (ADR 0050), free here since P1 has no children.
    enemies.bossLastHitAgo[slot] = health;

    return slot;
  }

  static void update(AiContext ctx) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final ContentLibrary content = ctx.content;
    final double dt = ctx.dt;
    final DrawState? draw = ctx.lastWardenDraw;
    if (draw == null) return;

    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.lastWarden) {
        continue;
      }

      _tickDamageReduction(ctx, i, draw);

      final bool isMoving = _tickMovement(ctx, i, draw, dt);
      DrawSystem.update(draw, isMoving, dt, ctx.events);

      if (draw.tier == DrawTier.three) {
        _fireHeavyShot(ctx, i, draw);
        draw.drawSeconds = 0;
        enemies.bossTimer[i] = _repositionSeconds;
      }
    }
  }

  /// Approach-and-hold while no reposition is pending, deliberate retreat
  /// once one is. Returns whether the Warden is moving this tick — exactly
  /// the signal [DrawSystem.update] needs as `isMoving`, the same "still
  /// closing" reading the Hollow Warden's own mirror already feeds it.
  static bool _tickMovement(AiContext ctx, int slot, DrawState draw, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return false;
    }

    final double speed = _approachSpeed * (1.0 + draw.moveSpeedBonus);

    if (enemies.bossTimer[slot] > 0) {
      enemies.bossTimer[slot] -= dt;
      Steering.moveAway(ctx, slot, ctx.playerX, ctx.playerY, speed);
      Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);
      return true;
    }

    final double dx = ctx.playerX - store.posX[slot];
    final double dy = ctx.playerY - store.posY[slot];
    Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);

    if (dx * dx + dy * dy <= _engageRangeSq) {
      Steering.halt(ctx, slot);
      return false;
    }

    Steering.moveToward(ctx, slot, ctx.playerX, ctx.playerY, speed);
    return true;
  }

  static void _fireHeavyShot(AiContext ctx, int slot, DrawState draw) {
    final EntityStore store = ctx.entities;
    final double fromX = store.posX[slot];
    final double fromY = store.posY[slot];
    final double angle = math.atan2(ctx.playerY - fromY, ctx.playerX - fromX);

    EnemyAttack.fireBolt(
      ctx,
      slot,
      angle: angle,
      speed: _boltProjectileSpeed,
      damage: _heavyShotDamage,
      radius: _boltRadius,
      lifetime: _boltRange / _boltProjectileSpeed,
    );
  }

  /// Compares this tick's health against what was read last tick and
  /// refunds a `draw.damageReduction` fraction of whatever dropped — the
  /// Warden's own Momentum stacks mitigating incoming damage the identical
  /// way the player's own do, without touching the shared hit-resolution
  /// pipeline. See the class doc comment.
  static void _tickDamageReduction(AiContext ctx, int slot, DrawState draw) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final double baseline = enemies.bossLastHitAgo[slot];
    final double current = store.health[slot];
    final double drop = baseline - current;

    if (drop > 0 && draw.damageReduction > 0) {
      double healed = current + drop * draw.damageReduction;
      if (healed > store.maxHealth[slot]) healed = store.maxHealth[slot];
      store.health[slot] = healed;
    }

    enemies.bossLastHitAgo[slot] = store.health[slot];
  }
}
