import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// Rimefather — docs/06 §6, chapter 6's boss. "Tests: Frost, and forced
/// movement."
///
/// **P1: "Freezing cone; a player hit twice within 4s is rooted for
/// 1.2s."** A stationary single body whose cone attack is the identical
/// windUp→resolve→cooldown cycle Silversong's own scream already
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
/// **P2: "The arena floor freezes outward from the boss; standing on ice
/// reduces friction and makes precise positioning hard. Momentum builds
/// are *stronger* on ice."** Built in two honestly-separated halves. The
/// growing ice radius and "Momentum is stronger while standing in it" are
/// real: a new `DrawState.momentumEffectivenessMultiplier` (a plain scale
/// on `moveSpeedBonus`/`damageReduction`, recomputed fresh every tick from
/// current position — the same "live, not accumulated" posture
/// `EnemyStore.attackBuff` already uses) is set to an authored 1.5x while
/// the player stands inside the boss's own spreading circle. **"Reduces
/// friction" is not implemented.** The sim has no friction or velocity-
/// persistence model at all — `SimWorld._applyInput` sets the player's own
/// velocity directly from input every tick, with nothing to decay or
/// slide once the stick releases — so "ice" changing that would mean
/// building a genuinely new movement-physics layer touching the one
/// function every other interaction in the game already depends on, a
/// materially larger and riskier change than any other piece in this P2
/// pass. Flagged, not guessed at. See ADR 0038.
///
/// **P3, built here: "Shatters into three ice-mirrors, only one of which
/// is real (revealed by which one casts a shadow — a purely visual read,
/// no HUD marker). Wrong-target damage heals it."** The cone attack and
/// the spreading ice both stop — this phase reads as a pure target-
/// discipline puzzle, not another offensive layer. Three ordinary,
/// independently-*targetable* children (unlike every other placed child
/// in this roster, which is deliberately `untargetable`, since the whole
/// point here is that the player *can* hit the wrong one) are placed in a
/// small triangle around the primary's own position, one at random
/// (`bossActiveChildIndex`, repurposed to hold the chosen ordinal) marked
/// as the real one. "Which one casts a shadow" is a rendering-only tell
/// this system deliberately never encodes anywhere queryable — the sim
/// picks the real one and keeps it to itself, which is what makes "no HUD
/// marker" a true statement rather than a promise the sim quietly breaks.
///
/// **"Wrong-target damage heals it" needed no change to the core damage
/// pipeline.** Rather than intercepting a hit before it lands (a riskier
/// change to shared, heavily-tested combat code), `_tickMirrors` compares
/// each mirror's own health against what it read last tick
/// (`bossLastHitAgo`, unused anywhere in this file until now, repurposed
/// per-child as a health baseline rather than a time) — the same
/// "observe and correct after the fact" shape `AiSystem._applyAuras`
/// already uses for the Green Mother's own Knitters (ADR 0028). A drop on
/// the *real* mirror stands; a drop on a *fake* one is refunded in full
/// (the decoy is never actually killable) and the same amount heals the
/// real mirror instead. The primary's own `health` is kept mirrored to
/// the real one every tick, so `BossPhaseSystem`'s own generic
/// health-fraction machinery and the death check both keep working
/// unmodified. See ADR 0050.
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

  // ── P2: the spreading ice ────────────────────────────────────────────────
  // See ADR 0038 for the friction half's own honest non-implementation.

  /// Authored — docs/06 states no cap. Large enough to threaten roughly
  /// half a default 16x9 arena's own working space from a central spawn,
  /// echoing Vermillion's own "safe floor ~50%" framing (ADR 0037) even
  /// though this card states no percentage of its own.
  static const double _iceMaxRadius = 6.0;

  /// Authored — reaches the cap in 15s.
  static const double _iceGrowthPerSecond = _iceMaxRadius / 15.0;

  /// Authored — "stronger" with no stated multiplier.
  static const double _momentumMultiplierOnIce = 1.5;

  // ── P3: the ice-mirrors ───────────────────────────────────────────────
  // See ADR 0050.

  static const int _mirrorCount = 3;

  /// A small triangle around the primary's own position — authored, the
  /// same staging-radius reasoning Cinder Choir's own triangle already
  /// used (ADR 0018), docs/06 states no layout.
  static const double _mirrorPlacementRadius = 1.5;

  static const double _mirrorRadius = 0.6;

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

      // P3: the cone and the ice both stop — a pure target-discipline
      // puzzle, not another offensive layer (see the class doc comment).
      if (enemies.bossPhase[i] >= 2) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        ctx.playerDraw?.momentumEffectivenessMultiplier = 1.0;
        _spawnMirrors(ctx, i);
        _tickMirrors(ctx, i);
        if (store.health[i] <= 0) _despawnMirrors(ctx, i);
        continue;
      }

      if (enemies.bossPhase[i] >= 1) _tickIce(ctx, i, dt);

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

  /// Grows the ice outward from the boss's own position, capped at
  /// [_iceMaxRadius], and sets the player's own Momentum multiplier for
  /// this tick based on whether they are currently standing in it —
  /// `bossSweepAngle` repurposed as a plain scalar radius, free on this
  /// boss (P1 never touches it) rather than a rotating angle.
  static void _tickIce(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;
    final EntityStore store = ctx.entities;

    double radius = enemies.bossSweepAngle[primary];
    if (radius < _iceMaxRadius) {
      radius += _iceGrowthPerSecond * dt;
      if (radius > _iceMaxRadius) radius = _iceMaxRadius;
      enemies.bossSweepAngle[primary] = radius;
    }

    final DrawState? draw = ctx.playerDraw;
    if (draw == null) return;

    final bool onIce = ctx.hasPlayer &&
        EnemyAttack.playerInCircle(ctx, store.posX[primary], store.posY[primary], radius);
    draw.momentumEffectivenessMultiplier = onIce ? _momentumMultiplierOnIce : 1.0;
  }

  /// Places [_mirrorCount] independently-*targetable* mirrors around the
  /// primary's own position, exactly once — idempotent by a scan for an
  /// existing child, the same shape every other placed-once-per-phase
  /// child in this roster uses. Each starts with however much health the
  /// primary had left the instant it shattered, not its own full health —
  /// the fight's own remaining threat carries over, split by which mirror
  /// the player finds. `bossActiveChildIndex` (free — P1/P2 never touch
  /// it) holds the real one's own ordinal, chosen once at random.
  static void _spawnMirrors(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] == primary) return; // already placed
    }

    final double shatteredHealth = store.health[primary];
    final int realOrdinal = ctx.rng.nextInt(_mirrorCount);
    enemies.bossActiveChildIndex[primary] = realOrdinal;

    for (int ordinal = 0; ordinal < _mirrorCount; ordinal++) {
      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      final double angle = 2 * math.pi * ordinal / _mirrorCount;
      final double x = store.posX[primary] + _mirrorPlacementRadius * math.cos(angle);
      final double y = store.posY[primary] + _mirrorPlacementRadius * math.sin(angle);

      store.posX[slot] = x;
      store.posY[slot] = y;
      store.radius[slot] = _mirrorRadius;
      store.health[slot] = shatteredHealth;
      store.maxHealth[slot] = store.maxHealth[primary];
      store.contentIndex[slot] = -1;
      ctx.events.emit(SimEventType.entitySpawned, entityA: slot, x: x, y: y);

      enemies.reset(slot);
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = ordinal;
      // A health baseline for `_tickMirrors`'s own tick-to-tick diff —
      // `bossLastHitAgo` is unused anywhere in this file otherwise.
      enemies.bossLastHitAgo[slot] = shatteredHealth;
    }
  }

  /// Compares every mirror's own current health against what it read
  /// last tick. A drop on the real one stands; a drop on a fake one is
  /// refunded in full — the decoy is never actually killable — and the
  /// same amount heals the real mirror instead. See the class doc
  /// comment for why this reads health after the fact rather than
  /// intercepting the hit itself.
  static void _tickMirrors(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int realOrdinal = enemies.bossActiveChildIndex[primary];

    int realSlot = -1;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (enemies.bossChildIndex[j] == realOrdinal) realSlot = j;
    }
    if (realSlot < 0) return; // the real mirror is already gone this tick

    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (j == realSlot) continue; // handled implicitly — its drops stand

      final double drop = enemies.bossLastHitAgo[j] - store.health[j];
      if (drop > 0) {
        store.health[j] = enemies.bossLastHitAgo[j]; // refund in full
        double healed = store.health[realSlot] + drop;
        if (healed > store.maxHealth[realSlot]) healed = store.maxHealth[realSlot];
        store.health[realSlot] = healed;
      }
      enemies.bossLastHitAgo[j] = store.health[j];
    }

    enemies.bossLastHitAgo[realSlot] = store.health[realSlot];
    store.health[primary] = store.health[realSlot];
  }

  static void _despawnMirrors(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
      store.despawn(store.idAt(j));
    }
  }
}
