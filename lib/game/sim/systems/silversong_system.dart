import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';

/// Silversong — docs/06 §3, chapter 3's boss. "Tests: Momentum as a build,
/// not a fallback."
///
/// **P1: "A resonant bell-figure that hunts the player's mechanic rather
/// than their HP... Cone screams inflict Draw-lock 2.5s."** A stationary
/// single body — unlike every boss built before it, this one's own P1
/// attack deals **no HP damage at all**; the card is explicit that this
/// fight is about the Draw, not health.
///
/// Draw-lock itself needed no new primitive: `DrawState.applyDrawLock` and
/// the whole "cone telegraph → `EnemyAttack.playerInCone` → resolve" shape
/// already exist and are already used together, by the Screecher (docs/05
/// §5.4) — Silversong's own scream reuses several of the Screecher's own
/// numbers directly (see the constants below and ADR 0024) rather than
/// inventing a parallel set.
///
/// **P2: "Adds standing crimson resonance pillars that Draw-lock on
/// contact; the safe floor shrinks."** "Adds" is additive, not a
/// replacement — the cone scream keeps running unmodified, and pillars
/// accumulate on top of it. Each pillar is a real, separate, untargetable
/// child entity (`bossParent`/`bossChildIndex`, the same structural
/// bookkeeping every multi-body boss already uses) placed with
/// `EnemySpawner.findSpawnPoint` — the Weeping Gate's own "anywhere legal
/// in the arena" search (ADR 0030), reused here for the first time by a
/// *non*-add-spawning boss. Each pillar owns its own brief forming
/// telegraph on its own slot before it solidifies into a permanent hazard
/// — a genuinely new shape (a placed object with a one-time wind-up, not a
/// repeating attack cycle) needing its own `state`/`stateTimer`, kept on
/// the *child's* slot precisely because the primary's own `state`/
/// `stateTimer` are already spoken for by the cone's own cycle.
/// Draw-lock-on-contact reuses the *same* 2.5s `applyDrawLock` call the
/// cone already makes — the same effect, the same number, a different
/// trigger, not a second lock duration invented for it. See ADR 0036.
///
/// **Not built here: P3 ("Permanent Draw-lock. The entire final third must
/// be won at Tier I with maximum Momentum").** Once `bossPhase` reaches 2
/// this system stops screaming and stops growing new pillars — any pillar
/// already standing also stops applying its own lock, the same "the whole
/// mechanic freezes, not just the parts still mid-cycle" posture every
/// other boss's own undone phase already takes, chosen deliberately here
/// over leaving placed objects half-alive in a phase nothing has built.
abstract final class SilversongSystem {
  /// docs/06 §3's own stated lock duration — reused for both the cone and
  /// the pillars; the same effect deserves the same number, not two.
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

  // ── P2: resonance pillars ────────────────────────────────────────────────
  // See ADR 0036.

  /// How long a pillar visibly forms before it solidifies. Reused —
  /// the roster's own established "amber warning" magnitude.
  static const double _pillarWindUpSeconds = 0.6;

  /// How long between one pillar finishing and the next beginning to
  /// form. Authored — docs/06 gives no cadence, only "the safe floor
  /// shrinks" over the course of P2.
  static const double _pillarSpawnIntervalSeconds = 4.0;

  /// How many pillars P2 can ever place. Authored, so "shrinks" stops
  /// short of "vanishes" — an unbounded floor would make survival a
  /// matter of P2's own duration rather than a real spatial puzzle.
  static const int _pillarCap = 5;

  /// A pillar's own footprint. Authored — docs/06 states no size.
  static const double _pillarRadius = 1.0;

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
  /// cone), cool down, repeat. Once P2 begins, also grows the pillar field
  /// and locks whoever stands in one.
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

      // The primary's own health reached zero this tick. Pillars are
      // untargetable and have no death condition of their own — left
      // alone once any exist, they would sit alive forever, and the boss
      // room's own "zero alive enemies" clear condition (ADR 0021) would
      // never fire. The same cleanup every multi-body boss's own
      // `_despawnChildren` already does.
      if (store.health[i] <= 0) {
        _despawnChildren(ctx, i);
        continue;
      }

      // P3 not built yet (see the class doc comment) — everything freezes,
      // including any pillar already standing, rather than leaving placed
      // objects half-alive in a phase nothing has built.
      if (enemies.bossPhase[i] >= 2) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        _clearPillarTelegraphs(ctx, i);
        continue;
      }

      if (enemies.stateOf(i) == AiState.windUp) {
        enemies.stateTimer[i] -= dt;
        if (enemies.stateTimer[i] <= 0) _resolve(ctx, i);
      } else if (enemies.attackCooldown[i] > 0) {
        enemies.attackCooldown[i] -= dt;
      } else {
        _beginWindUp(ctx, i);
      }

      if (enemies.bossPhase[i] >= 1) _tickPillars(ctx, i, dt);
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

  /// Advances every pillar's own forming wind-up, Draw-locks the player
  /// against any already-solidified one, and grows the field on its own
  /// cooldown (`bossTimer` — free on the primary, since the cone cycle
  /// above already owns `state`/`stateTimer`/`attackCooldown`) up to
  /// [_pillarCap].
  static void _tickPillars(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    int pillarCount = 0;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      pillarCount++;

      if (enemies.stateOf(j) == AiState.windUp) {
        enemies.stateTimer[j] -= dt;
        if (enemies.stateTimer[j] <= 0) {
          EnemyAttack.endTelegraph(ctx, j);
          enemies.state[j] = AiState.idle.index;
        }
        continue; // still forming — not a hazard yet
      }

      if (EnemyAttack.playerInCircle(ctx, store.posX[j], store.posY[j], _pillarRadius)) {
        ctx.playerDraw?.applyDrawLock(_drawLockSeconds);
      }
    }

    if (pillarCount >= _pillarCap) return;

    if (enemies.bossTimer[primary] > 0) {
      enemies.bossTimer[primary] -= dt;
      return;
    }

    _spawnPillar(ctx, primary, pillarCount);
    enemies.bossTimer[primary] = _pillarSpawnIntervalSeconds;
  }

  static void _spawnPillar(AiContext ctx, int primary, int ordinal) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    EnemySpawner.findSpawnPoint(ctx, _pillarRadius);
    final double x = EnemySpawner.pointX;
    final double y = EnemySpawner.pointY;

    final EntityId id = store.spawn(EntityKind.enemy);
    if (id.isNone) return;
    final int slot = id.index;

    store.posX[slot] = x;
    store.posY[slot] = y;
    store.radius[slot] = _pillarRadius;
    // Matches the primary's own max health, the same "large enough that a
    // stray splash hit can't prematurely kill it" margin Cinder Choir's
    // own effigies already lean on.
    store.health[slot] = store.maxHealth[primary];
    store.maxHealth[slot] = store.maxHealth[primary];
    store.contentIndex[slot] = -1;
    ctx.events.emit(SimEventType.entitySpawned, entityA: slot, x: x, y: y);

    enemies.reset(slot);
    enemies.bossParent[slot] = primary;
    enemies.bossChildIndex[slot] = ordinal;
    enemies.untargetable[slot] = 1;
    enemies.state[slot] = AiState.windUp.index;
    enemies.stateTimer[slot] = _pillarWindUpSeconds;

    EnemyAttack.beginCircle(ctx, slot, x, y, _pillarRadius, _pillarWindUpSeconds);
  }

  static void _despawnChildren(AiContext ctx, int primary) {
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

  static void _clearPillarTelegraphs(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
    }
  }
}
