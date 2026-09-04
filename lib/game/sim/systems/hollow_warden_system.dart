import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
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

/// The Hollow Warden — docs/06 §4, chapter 4's boss. "Tests: understanding
/// your own kit." "A mirror of the player's current hero, at 80% of the
/// player's own stats, using the player's own arrow type and a fixed Boon
/// set."
///
/// **P1 only, built here.** "Mirrors movement inverted (Echo AI). It
/// Draws — its own arc is visible, so the player can read exactly when its
/// heavy shot lands." Two pieces, both real work, both scoped down hard:
///
/// **Movement is the ordinary Echo's own math (docs/05 #24,
/// `RiftbornTree._echo`), not a call into it** — the Echo is an ordinary
/// enemy whose own tree needs an `EnemyDefinition` this bare boss body
/// doesn't have, so the mirror-about-arena-centre approach is reimplemented
/// here directly against `Steering`, the same "reuse the *shape*, not the
/// private function" posture every boss in this session already takes for
/// borrowed movement (Gaunt/Vermillion both reuse `Steering.moveToward`
/// itself rather than another enemy's own tree method).
///
/// **The Draw itself is genuinely new sim surface: `SimWorld.
/// hollowWardenDraw`, a second live [DrawState]** — the exact instance
/// [DrawState]'s own doc comment already named this boss as needing,
/// predating this fight by several phases. It ramps under the identical
/// rule the player's own does (`DrawSystem.update`, fed `isMoving` from
/// whether the Warden is still closing on its own mirror point) — Draws
/// only once its own movement settles, mirroring the player's own
/// stand-still-to-ramp trade exactly. The instant it reaches Tier III, one
/// heavy bolt fires (`EnemyAttack.fireBolt`, the same primitive the
/// ordinary Echo already fires with, reusing its own numbers) and the ramp
/// resets to zero — "its own arc is visible" *is* the telegraph here, so
/// no separate wind-up/circle telegraph is layered on top.
///
/// **What "using the player's own arrow type" and "80% of the player's own
/// stats" do NOT mean here.** Neither is implemented. Porting arrow-type
/// behaviour (pierce, elemental procs, hitbox scaling) or hero-specific
/// stats onto an enemy body is a materially larger redesign question
/// docs/06 does not itself resolve, and is well outside a single pass —
/// the heavy shot instead reuses the same "fraction of the player's max
/// HP" damage model every other enemy attack in the game already uses,
/// with its own fraction *derived* from an existing anchor (the ordinary
/// Echo's own attack damage, scaled by Tier III's own damage multiplier)
/// rather than by "80%" of anything. See ADR 0031.
///
/// **Not built here: P2 (lays Windlines, gains Confluence off them;
/// crossing them slows the player) and P3 (both Windline sets live;
/// crossing your line through its line creates a Discord — a neutral
/// detonation damaging whoever is closer).** P3 especially needs an idea
/// nothing in the sim has any analogue for: a hazard whose *source* is a
/// crossing between two independently-drawn trail sets, not a single
/// enemy's own attack. Once `bossPhase` reaches 1, the mirror halts and
/// the Draw ramp freezes wherever it was — the same posture every other
/// boss's own undone phases already take.
abstract final class HollowWardenSystem {
  /// Reused from the ordinary Echo (docs/05 #24) — the same movement speed
  /// and mirror-catch-up gain its own family tree already uses.
  static const double _mirrorSpeed = 2.4;
  static const double _mirrorGain = EnemyTuning.echoMirrorGain;

  /// Reused from the Echo's own mirror-arrival check.
  static const double _mirrorArrivedDistanceSq = 0.01;

  /// Reused from the Echo's own bolt (docs/05 #24).
  static const double _boltProjectileSpeed = 8.0;
  static const double _boltRange = 14.0;
  static const double _boltRadius = EnemyTuning.boltRadius;

  /// The heavy shot's own damage: the Echo's own `attackDamage` (6%),
  /// scaled by Tier III's own damage multiplier (2.10x) — a derived,
  /// reused-anchor number, not an invented one. See the class doc comment.
  static const double _heavyShotDamage = 0.06 * 2.10;

  /// Places the Warden's single, mirroring body. Returns its slot, or -1
  /// if the entity pool was full or [BossArchetype.hollowWarden] has no
  /// catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 0.5,
  }) {
    final int bossIndex =
        content.bosses.indexOfArchetype(BossArchetype.hollowWarden);
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

    return slot;
  }

  static void update(AiContext ctx) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final ContentLibrary content = ctx.content;
    final double dt = ctx.dt;
    final DrawState? draw = ctx.hollowWardenDraw;
    if (draw == null) return;

    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.hollowWarden) {
        continue;
      }

      // P2/P3 not built yet (see the class doc comment) — the mirror
      // halts and the ramp simply stops advancing, rather than either
      // being left mid-chase or silently continuing to threaten.
      if (enemies.bossPhase[i] >= 1) {
        Steering.halt(ctx, i);
        continue;
      }

      final bool isMoving = _mirror(ctx, i);
      DrawSystem.update(draw, isMoving, dt, ctx.events);

      if (draw.tier == DrawTier.three) {
        _fireHeavyShot(ctx, i);
        draw.drawSeconds = 0;
      }
    }
  }

  /// Moves toward the mirror of the player's own position about the
  /// arena's centre — the ordinary Echo's own approach (`RiftbornTree.
  /// _echo`), reimplemented against `Steering` directly since this bare
  /// boss body has no `EnemyDefinition` to run that tree with. Returns
  /// whether the Warden is still closing on its own mirror point, which
  /// is exactly the signal [DrawSystem.update] needs as `isMoving`.
  static bool _mirror(AiContext ctx, int slot) {
    final EntityStore store = ctx.entities;

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return false;
    }

    double mirrorX = ctx.arena.width - ctx.playerX;
    double mirrorY = ctx.arena.height - ctx.playerY;

    // The mirror of a reachable point is not always reachable — fall back
    // to the player's own position rather than pressing into a wall.
    if (ctx.arena.circleHitsWall(mirrorX, mirrorY, store.radius[slot])) {
      mirrorX = ctx.playerX;
      mirrorY = ctx.playerY;
    }

    final double dx = mirrorX - store.posX[slot];
    final double dy = mirrorY - store.posY[slot];

    Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);

    if (dx * dx + dy * dy <= _mirrorArrivedDistanceSq) {
      Steering.halt(ctx, slot);
      return false;
    }

    Steering.moveToward(
      ctx,
      slot,
      mirrorX,
      mirrorY,
      _mirrorSpeed * _mirrorGain,
      separate: false,
    );
    return true;
  }

  static void _fireHeavyShot(AiContext ctx, int slot) {
    final EntityStore store = ctx.entities;
    final double angle = math.atan2(
      ctx.playerY - store.posY[slot],
      ctx.playerX - store.posX[slot],
    );
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
}
