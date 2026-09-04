import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// Rimefather — docs/06 §6, chapter 6's boss. "Tests: Frost, and forced
/// movement."
///
/// **P1 only, built here.** "Freezing cone; a player hit twice within 4s is
/// rooted for 1.2s." A stationary single body whose cone attack is the
/// identical windUp→resolve→cooldown cycle Silversong's own scream already
/// established (ADR 0024) — this boss's own new piece is entirely the
/// *root*: two cone hits inside a rolling 4s window force the player to
/// stop moving outright, a stronger denial than Silversong's own Draw-lock
/// (which only denies tier *progress*).
///
/// That root needed a real new primitive — nothing in the sim let an enemy
/// stop the player from moving at all before now — `DrawState.rootRemaining`
/// (new) and `SimWorld._applyInput`/`_applyDash` both checking it. See ADR
/// 0026.
///
/// **Not built here: P2 (the arena floor freezing outward, changing
/// friction) and P3 (three ice-mirrors, only one real, revealed by a
/// shadow with no HUD marker).** P3 especially needs an idea the sim has no
/// analogue for at all — a *decoy* body indistinguishable from the real one
/// by anything the simulation itself can query, since "which one casts a
/// shadow" is a rendering-only tell. Once `bossPhase` reaches 1 this system
/// stops screaming and clears any live telegraph — the same posture every
/// other boss's own undone phases already take.
abstract final class RimefatherSystem {
  /// Reused from the Screecher (docs/05 §5.4) — the same cone shape
  /// Silversong's own scream already reuses (ADR 0024).
  static const double _coneHalfAngle = 30 * math.pi / 180;
  static const double _coneRange = 5.0;
  static const double _windUpSeconds = 0.6;

  /// Authored — shorter than Silversong's own 2.5s cooldown so two casts
  /// comfortably fit inside the 4s streak window below. See ADR 0026.
  static const double _cooldownSeconds = 1.5;

  /// Reused from the Thresher (docs/05) — the same "persistent aura" anchor
  /// Cinder Choir's own tether and cones already reused (ADR 0019/0020).
  static const double _coneDamage = 0.09;

  /// docs/06 §6's own stated numbers.
  static const double _streakWindowSeconds = 4.0;
  static const int _hitsToRoot = 2;
  static const double _rootSeconds = 1.2;

  /// Places Rimefather's single, stationary body. Returns its slot, or -1
  /// if the entity pool was full or [BossArchetype.rimefather] has no
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
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.rimefather);
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

  /// Cycles the freezing cone: wind up, resolve (damage plus a hit toward
  /// the root streak), cool down, repeat. The streak window itself
  /// (`bossTimer`) counts down every tick, independent of the attack cycle.
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.rimefather) {
        continue;
      }

      // P2/P3 not built yet (see the class doc comment) — frozen, telegraph
      // cleared, rather than left mid-wind-up forever.
      if (enemies.bossPhase[i] >= 1) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        continue;
      }

      if (enemies.bossTimer[i] > 0) enemies.bossTimer[i] -= dt;

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
      EnemyAttack.damagePlayer(ctx, _coneDamage, source: slot);
      _registerFreezeHit(ctx, slot);
    }

    enemies.state[slot] = AiState.idle.index;
    enemies.attackCooldown[slot] = _cooldownSeconds;
  }

  /// A cone hit toward the root streak. `bossTimer` holds the streak
  /// window's own remaining time (separate from — and decremented every
  /// tick regardless of — `attackCooldown`'s own attack-cycle cadence);
  /// `comboStep` (unused by a bare boss entity, the same "borrow the
  /// combo-swing counter" reuse Cinder Choir's own cone cycle never
  /// needed but Skarn's family-tree-adjacent state did) holds the count
  /// within it.
  static void _registerFreezeHit(AiContext ctx, int slot) {
    final EnemyStore enemies = ctx.enemies;

    if (enemies.bossTimer[slot] <= 0) {
      // First hit of a fresh streak.
      enemies.comboStep[slot] = 1;
      enemies.bossTimer[slot] = _streakWindowSeconds;
      return;
    }

    enemies.comboStep[slot]++;
    if (enemies.comboStep[slot] >= _hitsToRoot) {
      ctx.playerDraw?.applyRoot(_rootSeconds);
      enemies.comboStep[slot] = 0;
      enemies.bossTimer[slot] = 0;
    }
  }
}
