import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// Silversong — docs/06 §3, chapter 3's boss. "Tests: Momentum as a build,
/// not a fallback."
///
/// **P1 only, built here.** "A resonant bell-figure that hunts the
/// player's mechanic rather than their HP... Cone screams inflict Draw-lock
/// 2.5s." A stationary single body — unlike every boss built before it,
/// this one's own P1 attack deals **no HP damage at all**; the card is
/// explicit that this fight is about the Draw, not health.
///
/// Draw-lock itself needed no new primitive: `DrawState.applyDrawLock` and
/// the whole "cone telegraph → `EnemyAttack.playerInCone` → resolve" shape
/// already exist and are already used together, by the Screecher (docs/05
/// §5.4) — Silversong's own scream reuses several of the Screecher's own
/// numbers directly (see the constants below and ADR 0024) rather than
/// inventing a parallel set.
///
/// **Not built here: P2 (standing resonance-pillar hazards) and P3
/// (permanent Draw-lock).** Once `bossPhase` reaches 1 this system stops
/// screaming entirely — a known, flagged gap, the same posture every other
/// boss's own undone phases already take.
abstract final class SilversongSystem {
  /// docs/06 §3's own stated lock duration.
  static const double _drawLockSeconds = 2.5;

  /// Reused from the Screecher (docs/05 §5.4) — the same cone attack this
  /// mechanic already exists on, just without its own damage component
  /// (Silversong's card states none). See ADR 0024.
  static const double _coneHalfAngle = 30 * math.pi / 180;
  static const double _coneRange = 5.0;
  static const double _windUpSeconds = 0.6;

  /// Authored, not a Screecher number: docs/06 §3's own "Tier III is
  /// unavailable roughly half the time" is the anchor instead — a cooldown
  /// matching the lock's own duration means a scream recurs about as often
  /// as its lock lasts. See ADR 0024.
  static const double _cooldownSeconds = _drawLockSeconds;

  /// Places Silversong's single, stationary body. Returns its slot, or -1
  /// if the entity pool was full or [BossArchetype.silversong] has no
  /// catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 0.8,
  }) {
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.silversong);
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

  /// Cycles the scream: wind up, resolve (Draw-lock whoever is still in the
  /// cone), cool down, repeat.
  static void update(AiContext ctx) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final ContentLibrary content = ctx.content;
    final double dt = ctx.dt;

    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.silversong) {
        continue;
      }

      // P2/P3 not built yet (see the class doc comment) — frozen, telegraph
      // cleared, rather than left mid-wind-up forever.
      if (enemies.bossPhase[i] >= 1) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        continue;
      }

      if (enemies.stateOf(i) == AiState.windUp) {
        enemies.stateTimer[i] -= dt;
        if (enemies.stateTimer[i] > 0) continue;
        _resolve(ctx, i);
        continue;
      }

      if (enemies.attackCooldown[i] > 0) {
        enemies.attackCooldown[i] -= dt;
        continue;
      }

      _beginWindUp(ctx, i);
    }
  }

  static void _beginWindUp(AiContext ctx, int slot) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    enemies.state[slot] = AiState.windUp.index;
    enemies.stateTimer[slot] = _windUpSeconds;

    final double x = store.posX[slot];
    final double y = store.posY[slot];
    final double facing = ctx.hasPlayer
        ? math.atan2(ctx.playerY - y, ctx.playerX - x)
        : store.facing[slot];
    store.facing[slot] = facing;

    EnemyAttack.beginCone(
      ctx,
      slot,
      x,
      y,
      facing,
      _coneHalfAngle,
      _coneRange,
      _windUpSeconds,
    );
  }

  static void _resolve(AiContext ctx, int slot) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final double x = store.posX[slot];
    final double y = store.posY[slot];
    final double facing = store.facing[slot];

    // The Screecher's own scream shape: a one-tick lethal flash exactly
    // where the amber cone was aimed.
    EnemyAttack.beginCone(
      ctx,
      slot,
      x,
      y,
      facing,
      _coneHalfAngle,
      _coneRange,
      0,
      severity: TelegraphSeverity.lethal,
    );

    if (EnemyAttack.playerInCone(ctx, x, y, facing, _coneHalfAngle, _coneRange)) {
      ctx.playerDraw?.applyDrawLock(_drawLockSeconds);
    }

    enemies.state[slot] = AiState.idle.index;
    enemies.attackCooldown[slot] = _cooldownSeconds;
  }
}
