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
/// **P2: "Remaining sigils accelerate and the Thrall uses two abilities
/// simultaneously."** The orbit's own angular velocity doubles (authored —
/// docs/06 states no exact multiplier). "Two abilities simultaneously" is
/// read as *synchronised*, not independently timed: both share the same
/// wind-up/resolve/cooldown clock (`state`/`stateTimer`/`attackCooldown`
/// stay solely on the primary, unchanged from P1), so no second concurrent
/// state machine was needed — only a second *telegraph owner*. Since "an
/// enemy owns at most one telegraph at a time" (the same constraint every
/// multi-line boss in this roster already works around), the first
/// ability keeps using the primary's own `telegraphSlot` exactly as P1
/// already does, and the second uses *that turn's own second sigil's* own
/// slot instead — both still fire from the Thrall's own position, per the
/// class's own P1 rule, only the telegraph *bookkeeping* differs.
/// `comboStep` (free on this boss — nothing else here touches it) holds
/// the second sigil's own ordinal for the duration of one turn, sentinelled
/// by equalling the first when there is no second (P1, or only one living
/// sigil remains). See ADR 0041.
///
/// **Not built here: P3 ("absorbs all remaining sigils for +25% damage
/// each... a player who destroyed five sigils fights a fundamentally
/// different, easier phase 3").** Needs a damage multiplier keyed to
/// however many sigils survived to that point — real, scoped work not
/// attempted here. Once `bossPhase` reaches 2, the rotation and orbit both
/// freeze and every live telegraph (the primary's own, and any live second
/// ability's own) is cleared — the same posture every other boss's own
/// undone phase already takes.
abstract final class ThrallOfNineSystem {
  static const int sigilCount = 9;

  /// Authored staging, not a GDD number — the same "no boss arena exists
  /// yet" gap every prior boss's own geometry already carries (ADR 0017).
  static const double _orbitRadius = 3.0;

  /// One full revolution every 20s. Authored — docs/06 gives no orbital
  /// rate at all.
  static const double _orbitAngularVelocity = 2 * math.pi / 20.0;

  /// "Accelerate" — authored, docs/06 states no exact multiplier.
  static const double _orbitAngularVelocityP2 = _orbitAngularVelocity * 2;

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

      // P3 not built yet (see the class doc comment) — frozen, orbit and
      // rotation both stopped, every live telegraph (the primary's own,
      // and any live second ability's own on a sigil) cleared, rather
      // than left mid-wind-up or mid-orbit forever.
      if (enemies.bossPhase[i] >= 2) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        _clearSigilTelegraphs(ctx, i);
        continue;
      }

      final bool inP2 = enemies.bossPhase[i] >= 1;
      _orbit(ctx, i, dt, inP2);
      _tickRotation(ctx, i, dt, inP2);
    }
  }

  /// Advances the shared orbital angle and repositions every living sigil
  /// around it — the same "one continuously-incrementing angle drives
  /// several evenly-spaced points" shape `bossSweepAngle` already carries
  /// for Cinder Choir's own tether sweep (ADR 0019), reused here for
  /// literal orbital motion instead of a rotating line.
  static void _orbit(AiContext ctx, int primary, double dt, bool inP2) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    enemies.bossSweepAngle[primary] +=
        (inP2 ? _orbitAngularVelocityP2 : _orbitAngularVelocity) * dt;
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
  /// P3 already established (ADR 0020). In P2, a second living sigil
  /// (found the same way, starting after the first) casts alongside the
  /// first — see the class doc comment for why that needs only a second
  /// telegraph *owner*, not a second timer.
  static void _tickRotation(AiContext ctx, int primary, double dt, bool inP2) {
    final EnemyStore enemies = ctx.enemies;

    if (enemies.stateOf(primary) == AiState.windUp) {
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;

      final int first = enemies.bossActiveChildIndex[primary];
      _resolve(ctx, primary, primary, first);
      final int second = enemies.comboStep[primary];
      if (second != first) {
        final int secondSlot = _findSigil(ctx, primary, second);
        if (secondSlot >= 0) _resolve(ctx, primary, secondSlot, second);
      }

      enemies.state[primary] = AiState.idle.index;
      enemies.attackCooldown[primary] = _turnCooldownSeconds;
      return;
    }

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }

    final int first =
        _nextAliveSigilIndex(ctx, primary, enemies.bossActiveChildIndex[primary]);
    if (first < 0) return; // no living sigil at all — nothing to cast
    enemies.bossActiveChildIndex[primary] = first;

    // Sentinelled by equalling `first` — P1, or only one living sigil
    // remains, either way "no second ability this turn".
    int second = first;
    if (inP2) {
      final int candidate = _nextAliveSigilIndex(ctx, primary, first);
      if (candidate >= 0 && candidate != first) second = candidate;
    }
    enemies.comboStep[primary] = second;

    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = _windUpSeconds;
    _beginWindUp(ctx, primary, primary, first);
    if (second != first) {
      final int secondSlot = _findSigil(ctx, primary, second);
      if (secondSlot >= 0) _beginWindUp(ctx, primary, secondSlot, second);
    }
  }

  /// [owner] is whichever entity's own `telegraphSlot` this ability's
  /// wind-up telegraph lives on — always `primary` in P1 (only one
  /// ability at a time); in P2 the first ability still uses `primary`,
  /// and the second uses that turn's own second sigil's slot instead, so
  /// two simultaneous telegraphs never collide on one owner. Both still
  /// fire from the Thrall's own position regardless of [owner].
  static void _beginWindUp(AiContext ctx, int primary, int owner, int sigilIndex) {
    final EntityStore store = ctx.entities;

    final double x = store.posX[primary];
    final double y = store.posY[primary];
    final double facing = ctx.hasPlayer
        ? math.atan2(ctx.playerY - y, ctx.playerX - x)
        : store.facing[primary];
    store.facing[primary] = facing;

    switch (sigilIndex % 3) {
      case 0:
        EnemyAttack.beginCone(
            ctx, owner, x, y, facing, _coneHalfAngle, _coneRange, _windUpSeconds);
      case 1:
        final double toX = x + _lineLength * math.cos(facing);
        final double toY = y + _lineLength * math.sin(facing);
        EnemyAttack.beginLine(
            ctx, owner, x, y, toX, toY, _lineWidth, _windUpSeconds);
      default:
        EnemyAttack.beginCircle(ctx, owner, x, y, _circleRadius, _windUpSeconds);
    }
  }

  static void _resolve(AiContext ctx, int primary, int owner, int sigilIndex) {
    final EntityStore store = ctx.entities;
    final double x = store.posX[primary];
    final double y = store.posY[primary];
    final double facing = store.facing[primary];

    bool hit;
    switch (sigilIndex % 3) {
      case 0:
        EnemyAttack.beginCone(ctx, owner, x, y, facing, _coneHalfAngle, _coneRange,
            0, severity: TelegraphSeverity.lethal);
        hit = EnemyAttack.playerInCone(ctx, x, y, facing, _coneHalfAngle, _coneRange);
      case 1:
        final double toX = x + _lineLength * math.cos(facing);
        final double toY = y + _lineLength * math.sin(facing);
        EnemyAttack.beginLine(ctx, owner, x, y, toX, toY, _lineWidth, 0,
            severity: TelegraphSeverity.lethal);
        hit = EnemyAttack.playerOnLine(ctx, x, y, toX, toY, _lineWidth);
      default:
        EnemyAttack.beginCircle(ctx, owner, x, y, _circleRadius, 0,
            severity: TelegraphSeverity.lethal);
        hit = EnemyAttack.playerInCircle(ctx, x, y, _circleRadius);
    }

    if (hit) EnemyAttack.damagePlayer(ctx, _abilityDamage, source: primary);
  }

  static void _clearSigilTelegraphs(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
    }
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
