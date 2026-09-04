import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// Thrall of the Nine — docs/06 §9, chapter 9's boss. "Tests: target
/// priority under pressure."
///
/// **P1 only, built here.** "Nine floating sigils orbit; each grants the
/// Thrall one ability. Destroying a sigil removes that ability permanently.
/// The player chooses which of the nine threats to delete — and there is
/// time to remove only about four." docs/06 never enumerates what the nine
/// abilities actually *are* — a real GDD gap, resolved here (see ADR 0029)
/// as three of the roster's own already-established attack shapes (cone,
/// line, circle), assigned to the nine sigils round-robin (three of each).
/// The Thrall itself is a single, stationary body — the attacks fire from
/// its own position, not the orbiting sigil's — cycling through whichever
/// living sigil's own turn is next, the exact round-robin
/// `bossActiveChildIndex`/"next alive child" shape Cinder Choir's own P3
/// already established (ADR 0020), just against nine slots instead of
/// three. A sigil's own death permanently shortens the rotation — "removes
/// that ability permanently" needed no extra code once framed this way,
/// the same free consequence Cinder Choir's own alternating-cone cycle
/// already gets from a living-child lookup.
///
/// **Sigils hold their own, independent health — not a shared pool.**
/// Unlike every multi-body boss so far (Cinder Choir, Skarn), a sigil's own
/// death is a *side resource* elimination, not progress against the
/// Thrall's own HP bar; `EnemyStore.linkedHealthSlot` is deliberately never
/// set on one, so the existing damage pipeline needs no redirect at all —
/// simpler than every prior multi-body boss, not more complex.
///
/// **Not built here: P2 ("remaining sigils accelerate and the Thrall uses
/// two abilities simultaneously") and P3 ("absorbs all remaining sigils
/// for +25% damage each... a player who destroyed five sigils fights a
/// fundamentally different, easier phase 3").** Both need real new work —
/// P2 a second concurrent turn, P3 a damage multiplier keyed to however
/// many sigils survived. Once `bossPhase` reaches 1, the rotation and orbit
/// both freeze and any live telegraph is cleared — the same posture every
/// other boss's own undone phases already take.
abstract final class ThrallOfNineSystem {
  static const int sigilCount = 9;

  /// Authored staging, not a GDD number — the same "no boss arena exists
  /// yet" gap every prior boss's own geometry already carries (ADR 0017).
  static const double _orbitRadius = 3.0;

  /// One full revolution every 20s. Authored — docs/06 gives no orbital
  /// rate at all.
  static const double _orbitAngularVelocity = 2 * math.pi / 20.0;

  /// Reused everywhere else a mechanic switches on: the wind-up before any
  /// ability resolves.
  static const double _windUpSeconds = 0.6;

  /// Authored — the same magnitude Green Mother's own spawn interval
  /// already uses (ADR 0028), reused here as the pause between one
  /// ability's resolve and the next turn's own wind-up.
  static const double _turnCooldownSeconds = 1.0;

  /// The Thresher-derived "persistent aura" anchor, reused a fifth time —
  /// every ability shape below deals the same amount, differing only in
  /// range and footprint, the same "one damage anchor, several shapes"
  /// choice Cinder Choir's own P2/P3 already made.
  static const double _abilityDamage = 0.09;

  // ── Cone ability (sigil index % 3 == 0) — Silversong/Rimefather's own
  // numbers (ADR 0024/0026).
  static const double _coneHalfAngle = 30 * math.pi / 180;
  static const double _coneRange = 5.0;

  // ── Line ability (sigil index % 3 == 1) — Cinder Choir's own tether
  // anchor (ADR 0019).
  static const double _lineWidth = SimConfig.windlineHitWidth;
  static const double _lineLength = 9.0;

  // ── Circle ability (sigil index % 3 == 2) — authored radius, no existing
  // "burst AoE from an enemy's own body" anchor to reuse a number from.
  static const double _circleRadius = 2.0;

  /// A sigil's own health, as a fraction of the Thrall's max health.
  /// Authored, not GDD-stated — "time to remove only about four" is a real
  /// balance-tuning target (how long a given power level takes to kill
  /// one) that a single implementation pass cannot verify; a
  /// balance-harness (Phase 14) question, flagged in ADR 0029.
  static const double _sigilHealthFraction = 0.05;

  static const double _sigilRadius = 0.35;

  /// Places the Thrall's single, stationary body plus nine orbiting sigils,
  /// three of each ability shape. Returns the Thrall's own slot, or -1 if
  /// the entity pool was full or [BossArchetype.thrallOfNine] has no
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
    final int bossIndex =
        content.bosses.indexOfArchetype(BossArchetype.thrallOfNine);
    if (bossIndex < 0) return -1;

    final EntityId primaryId = store.spawn(EntityKind.enemy);
    if (primaryId.isNone) return -1;
    final int primary = primaryId.index;

    store.posX[primary] = centerX;
    store.posY[primary] = centerY;
    store.radius[primary] = radius;
    store.health[primary] = health;
    store.maxHealth[primary] = health;
    store.contentIndex[primary] = -1;
    events.emit(SimEventType.entitySpawned, entityA: primary, x: centerX, y: centerY);

    enemies.reset(primary);
    enemies.bossIndex[primary] = bossIndex;
    // One before sigil 0 — the first `_nextAliveSigilIndex` search (which
    // always looks strictly after this) lands on sigil 0 first.
    enemies.bossActiveChildIndex[primary] = sigilCount - 1;

    final double sigilHealth = health * _sigilHealthFraction;

    for (int sigil = 0; sigil < sigilCount; sigil++) {
      final double angle = 2 * math.pi * sigil / sigilCount;
      final double x = centerX + _orbitRadius * math.cos(angle);
      final double y = centerY + _orbitRadius * math.sin(angle);

      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      store.posX[slot] = x;
      store.posY[slot] = y;
      store.radius[slot] = _sigilRadius;
      store.health[slot] = sigilHealth;
      store.maxHealth[slot] = sigilHealth;
      store.contentIndex[slot] = -1;
      events.emit(SimEventType.entitySpawned, entityA: slot, x: x, y: y);

      enemies.reset(slot);
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = sigil;
    }

    return primary;
  }

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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.thrallOfNine) {
        continue;
      }

      // P2/P3 not built yet (see the class doc comment) — frozen, orbit and
      // rotation both stopped, any live telegraph cleared, rather than
      // left mid-wind-up or mid-orbit forever.
      if (enemies.bossPhase[i] >= 1) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        continue;
      }

      _orbit(ctx, i, dt);
      _tickRotation(ctx, i, dt);
    }
  }

  /// Advances the shared orbital angle and repositions every living sigil
  /// around it — the same "one continuously-incrementing angle drives
  /// several evenly-spaced points" shape `bossSweepAngle` already carries
  /// for Cinder Choir's own tether sweep (ADR 0019), reused here for
  /// literal orbital motion instead of a rotating line.
  static void _orbit(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    enemies.bossSweepAngle[primary] += _orbitAngularVelocity * dt;
    if (enemies.bossSweepAngle[primary] > 2 * math.pi) {
      enemies.bossSweepAngle[primary] -= 2 * math.pi;
    }

    final double centerX = store.posX[primary];
    final double centerY = store.posY[primary];

    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;

      final double angle = 2 * math.pi * enemies.bossChildIndex[j] / sigilCount +
          enemies.bossSweepAngle[primary];
      store.posX[j] = centerX + _orbitRadius * math.cos(angle);
      store.posY[j] = centerY + _orbitRadius * math.sin(angle);
    }
  }

  /// Cycles the Thrall's own attack through whichever living sigil's turn
  /// is next — an ordinary single-body wind-up/resolve/cooldown cycle
  /// (the same shape Silversong's own scream and Arclight's/Green
  /// Mother's own spawn cycles already use), with one extra step before
  /// each wind-up begins: find the next *living* sigil in ring order. A
  /// dead sigil's own turn is simply skipped forever — the entire
  /// mechanism behind "destroying a sigil removes that ability
  /// permanently," the same "next alive child" shape Cinder Choir's own
  /// P3 already established (ADR 0020).
  static void _tickRotation(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    if (enemies.stateOf(primary) == AiState.windUp) {
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;
      _resolve(ctx, primary, enemies.bossActiveChildIndex[primary]);
      enemies.state[primary] = AiState.idle.index;
      enemies.attackCooldown[primary] = _turnCooldownSeconds;
      return;
    }

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }

    final int next =
        _nextAliveSigilIndex(ctx, primary, enemies.bossActiveChildIndex[primary]);
    if (next < 0) return; // no living sigil at all — nothing to cast
    enemies.bossActiveChildIndex[primary] = next;
    _beginWindUp(ctx, primary, next);
  }

  static void _beginWindUp(AiContext ctx, int primary, int sigilIndex) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = _windUpSeconds;

    final double x = store.posX[primary];
    final double y = store.posY[primary];
    final double facing = ctx.hasPlayer
        ? math.atan2(ctx.playerY - y, ctx.playerX - x)
        : store.facing[primary];
    store.facing[primary] = facing;

    switch (sigilIndex % 3) {
      case 0:
        EnemyAttack.beginCone(
            ctx, primary, x, y, facing, _coneHalfAngle, _coneRange, _windUpSeconds);
      case 1:
        final double toX = x + _lineLength * math.cos(facing);
        final double toY = y + _lineLength * math.sin(facing);
        EnemyAttack.beginLine(
            ctx, primary, x, y, toX, toY, _lineWidth, _windUpSeconds);
      default:
        EnemyAttack.beginCircle(ctx, primary, x, y, _circleRadius, _windUpSeconds);
    }
  }

  static void _resolve(AiContext ctx, int primary, int sigilIndex) {
    final EntityStore store = ctx.entities;
    final double x = store.posX[primary];
    final double y = store.posY[primary];
    final double facing = store.facing[primary];

    bool hit;
    switch (sigilIndex % 3) {
      case 0:
        EnemyAttack.beginCone(ctx, primary, x, y, facing, _coneHalfAngle, _coneRange,
            0, severity: TelegraphSeverity.lethal);
        hit = EnemyAttack.playerInCone(ctx, x, y, facing, _coneHalfAngle, _coneRange);
      case 1:
        final double toX = x + _lineLength * math.cos(facing);
        final double toY = y + _lineLength * math.sin(facing);
        EnemyAttack.beginLine(ctx, primary, x, y, toX, toY, _lineWidth, 0,
            severity: TelegraphSeverity.lethal);
        hit = EnemyAttack.playerOnLine(ctx, x, y, toX, toY, _lineWidth);
      default:
        EnemyAttack.beginCircle(ctx, primary, x, y, _circleRadius, 0,
            severity: TelegraphSeverity.lethal);
        hit = EnemyAttack.playerInCircle(ctx, x, y, _circleRadius);
    }

    if (hit) EnemyAttack.damagePlayer(ctx, _abilityDamage, source: primary);
  }

  /// This Thrall's own living sigil at ordinal [sigilIndex], or -1.
  static int _findSigil(AiContext ctx, int primary, int sigilIndex) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (enemies.bossChildIndex[j] == sigilIndex) return j;
    }
    return -1;
  }

  /// The next living sigil's ordinal after [from], wrapping — or -1 if none
  /// remain.
  static int _nextAliveSigilIndex(AiContext ctx, int primary, int from) {
    for (int step = 1; step <= sigilCount; step++) {
      final int candidate = (from + step) % sigilCount;
      if (_findSigil(ctx, primary, candidate) >= 0) return candidate;
    }
    return -1;
  }
}
