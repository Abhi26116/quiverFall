import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';

/// Arclight — docs/06 §7, chapter 7's boss. "Tests: Storm, and spacing."
///
/// **P1 only, built here.** "Chains lightning between itself and any active
/// Swarmlings; killing adds breaks the chain." A stationary single body,
/// unlike every prior boss, whose own P1 mechanic is entirely about entities
/// it creates rather than itself.
///
/// **The add-spawning half is the Rift Maw (docs/05 #22) verbatim.** "Tears
/// open and spills Swarmlings on a fixed cadence, capped" is a mechanic that
/// already exists — `RiftbornTree._riftMaw`/`_summon` — down to the same
/// numbers (4 every 4.0s, capped at 16, 0.5s wind-up). Arclight's own
/// spawning reuses those numbers directly through the same
/// `EnemySpawner.spawn`/`liveAdds`/`atEnemyCap` machinery rather than
/// re-deriving a boss-specific cadence.
///
/// **The chain itself is Cinder Choir's own tether sweep (ADR 0019), aimed
/// at a moving target instead of a rotating angle.** Each spawned
/// Swarmling still runs its own ordinary `DriftTree._flock` behaviour
/// (`contentIndex >= 0`, unlike every other boss's own inert children) —
/// this system does not steer it, only draws and resolves a line hazard
/// from Arclight to wherever that Swarmling currently is, on that
/// Swarmling's own `telegraphSlot` (never touched by `_flock`, confirmed
/// free). "Killing adds breaks the chain" needed no explicit code at all:
/// `AiSystem._reap` already ends whatever telegraph a dying entity owns,
/// for every entity in the game.
///
/// **P2: "Charges the arena floor in a grid; alternating grid cells go
/// live on a 1.5s cycle. Pure pattern-reading."** No new telegraph shape
/// needed — `TelegraphShape` has no notion of a grid, but "pure
/// pattern-reading" reads as the alternating state itself being the whole
/// tell (rendering an always-visible checkerboard is a presentation
/// concern, left to a later pass, the same split every other boss's own
/// visuals already take), so this is checked directly rather than routed
/// through the telegraph system: the arena is a plain grid of authored
/// cells, and every cell whose own `(col + row)` parity matches the
/// current half of the 1.5s cycle (docs/06's own stated rate) is live,
/// damaging the player on the roster's own established 0.6s tick while
/// they remain on one. Chains from P1 keep running unmodified alongside
/// it. See ADR 0039.
///
/// **P3, built here: "Becomes untargetable and orbits as pure light; four
/// grounded conduits must be destroyed."** Spawning, chains, and the grid
/// all stop — the same posture every other boss's own undone phase
/// already takes, since P3 replaces the offence entirely rather than
/// adding to it. `_tickP3` places four ordinary, independently-healthed,
/// fully targetable conduits around the primary's own position — once,
/// gated by a genuine one-time latch (`bossActiveChildIndex`) rather than
/// the usual "scan for an existing *alive* child" shape every other
/// placed-once child in this roster uses, since conduits are actually
/// meant to be fought down to zero; see `_spawnConduits`'s own doc
/// comment for the infinite-respawn bug that shape caused here. Makes
/// the primary itself genuinely unkillable — `untargetable` alone only
/// ever affects auto-aim target *selection* (`AimAssist`'s own doc
/// comment: a manually-aimed shot still lands on an untargetable body),
/// so the primary is also given the same full-circle, tiny-positive-
/// flat-factor plate every conditional-invulnerability boss in this
/// roster already uses (Weeping Gate's own plate, ADR 0042; the Green
/// Mother's own bloom, ADR 0047) — the third reuse of that exact trick.
/// When the last conduit falls, the primary's own health is zeroed
/// directly, letting the ordinary death/reap pass finish the job the same
/// tick, so the boss room's own zero-enemies clear condition (ADR 0021)
/// still fires normally once every conduit and the primary are both gone.
/// "Orbits as pure light" is left to the render layer — a purely visual
/// flourish on an entity the sim already keeps stationary, the same
/// "rendering question, not a sim one" split this session's own other
/// cosmetic card details already take (Gaunt's own shockwave "ring", ADR
/// 0035).
///
/// **Not built here: "Confluence chains between conduits, making a
/// Windline lattice roughly twice as fast."** The card's own words frame
/// this as a bonus, not a requirement — "the first fight where the depth
/// mechanic is dramatically better *without being required*" — so
/// deferring it leaves the phase completely winnable exactly as built,
/// unlike every other deferred piece this session has flagged. What
/// "roughly twice as fast" would even mean operationally (a Confluence
/// stack bonus for threading near two conduits? A literal lattice-
/// formation-rate concept nothing in the sim tracks today?) is real,
/// separate design work this pass does not attempt. Any Swarmling still
/// alive when P3 begins is *not* despawned — the same "an add outlives
/// its summoner" behaviour the ordinary Rift Maw already has (ADR 0027).
/// See ADR 0051.
abstract final class ArclightSystem {
  // ── Spawning — Rift Maw's own numbers (docs/05 #22), reused directly ────
  static const double _spawnWindUpSeconds = 0.5;
  static const double _spawnCooldownSeconds = 4.0;
  static const int _spawnCount = 4;
  static const int _spawnCap = 16;

  // ── The chain — Cinder Choir's own tether anchor (ADR 0019), reused ─────
  /// docs/06 rule 2's own warning window, the same magnitude used everywhere
  /// else a mechanic switches on mid-fight rather than existing since spawn.
  static const double _chainWarningSeconds = 0.6;

  /// ADR 0008/0019's own reused line-hazard width.
  static const double _chainWidth = SimConfig.windlineHitWidth;

  /// The Thresher-derived "persistent aura" anchor, reused a fourth time.
  static const double _chainDamage = 0.09;
  static const double _chainCooldown = 0.6;

  // ── P2: the charged grid ─────────────────────────────────────────────────
  // See ADR 0039.

  /// docs/06 §7 P2's own stated cycle.
  static const double _gridCycleSeconds = 1.5;

  /// Authored — no stated cell size. Divides a default 16x9 arena into a
  /// readable checkerboard without needing an actual arena definition
  /// (ADR 0017/0021's still-open gap).
  static const double _gridCellSize = 2.0;

  /// The roster's own established tick magnitude, reused rather than a
  /// fresh cadence for standing on a live cell.
  static const double _gridDamageTickSeconds = 0.6;

  /// The Thresher-derived anchor, reused a fifth time.
  static const double _gridDamagePerTick = 0.09;

  // ── P3: the untargetable orbit and four conduits ─────────────────────
  // See ADR 0051.

  /// docs/06 §7 P3's own stated count.
  static const int _p3ConduitCount = 4;

  /// Authored — docs/06 states no layout. Spread wide enough that
  /// destroying one is a real trip across the room, not a tap on an
  /// adjacent target.
  static const double _p3ConduitPlacementRadius = 4.0;

  /// Split evenly across all four rather than a fresh number.
  static const double _p3ConduitHealthFraction = 1.0 / _p3ConduitCount;

  /// `_armourFor` only takes the flat-factor branch when it reads greater
  /// than zero — reused verbatim from every other conditional-
  /// invulnerability boss in this roster (Weeping Gate ADR 0042, the
  /// Green Mother ADR 0047).
  static const double _p3ShutPlateFactor = 0.0001;

  /// Places Arclight's single, stationary body. Returns its slot, or -1 if
  /// the entity pool was full or [BossArchetype.arclight] has no catalogue
  /// entry.
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
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.arclight);
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

    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.arclight) {
        continue;
      }

      // P3: spawning, chains, and the grid all stop — replaced entirely
      // by the untargetable orbit and the four conduits (see the class
      // doc comment), not layered on top of them.
      if (enemies.bossPhase[i] >= 2) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        _clearChains(ctx, i);
        _tickP3(ctx, i);
        continue;
      }

      _tickSpawns(ctx, i, dt);
      _tickChains(ctx, i, dt);
      if (enemies.bossPhase[i] >= 1) _tickGrid(ctx, i, dt);
    }
  }

  /// The Rift Maw's own cycle (`RiftbornTree._riftMaw`), reused verbatim:
  /// wind up (with a telegraph announcing where the tear will open), spawn,
  /// cool down, repeat — capped both locally ([_spawnCap], via
  /// `EnemyStore.liveAdds`) and globally (`EnemySpawner.atEnemyCap`).
  static void _tickSpawns(AiContext ctx, int slot, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (enemies.stateOf(slot) == AiState.windUp) {
      enemies.stateTimer[slot] -= dt;
      if (enemies.stateTimer[slot] > 0) return;
      EnemyAttack.endTelegraph(ctx, slot);
      _summon(ctx, slot);
      enemies.attackCooldown[slot] = _spawnCooldownSeconds;
      enemies.state[slot] = AiState.idle.index;
      return;
    }

    enemies.state[slot] = AiState.idle.index;

    if (enemies.attackCooldown[slot] > 0) {
      enemies.attackCooldown[slot] -= dt;
      return;
    }
    if (enemies.liveAdds[slot] >= _spawnCap) return;
    if (EnemySpawner.atEnemyCap(ctx)) return;

    enemies.state[slot] = AiState.windUp.index;
    enemies.stateTimer[slot] = _spawnWindUpSeconds;
    EnemyAttack.beginCircle(
      ctx,
      slot,
      store.posX[slot],
      store.posY[slot],
      EnemyTuning.riftMawSpawnRadius,
      _spawnWindUpSeconds,
    );
  }

  static void _summon(AiContext ctx, int slot) {
    final int contentIndex = ctx.content.enemyIndexById['swarmling'] ?? -1;
    if (contentIndex < 0) return;

    for (int k = 0; k < _spawnCount; k++) {
      if (ctx.enemies.liveAdds[slot] >= _spawnCap) return;
      if (EnemySpawner.atEnemyCap(ctx)) return;

      EnemySpawner.ringPoint(
        ctx,
        slot,
        k,
        _spawnCount,
        EnemyTuning.riftMawSpawnRadius,
      );
      final int child = EnemySpawner.spawn(
        ctx,
        contentIndex: contentIndex,
        x: EnemySpawner.pointX,
        y: EnemySpawner.pointY,
        spawnerSlot: slot,
      );
      // This Swarmling's own chain gets the same brief warning every new
      // hazard in the roster gets before it can actually hit — a per-add
      // countdown, not the boss-wide one every other tether-style mechanic
      // uses, since Swarmlings spawn staggered across the whole fight
      // rather than all switching on at once.
      if (child >= 0) ctx.enemies.bossTimer[child] = _chainWarningSeconds;
    }
  }

  /// Draws and resolves a chain from Arclight to every Swarmling it spawned
  /// that is still alive, one line telegraph per add on that add's own
  /// `telegraphSlot`. A single shared damage cooldown
  /// (`EnemyStore.bossTimer` on Arclight's *own* slot — a different array
  /// index from any add's own warm-up countdown on its own slot, so the two
  /// uses never collide) fires once per tick the player touches any live
  /// chain, mirroring `CinderChoirSystem._tickTetherSweep` exactly.
  static void _tickChains(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (enemies.bossTimer[primary] > 0) enemies.bossTimer[primary] -= dt;

    final double originX = store.posX[primary];
    final double originY = store.posY[primary];
    bool playerHit = false;

    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.spawnerSlot[j] != primary) continue;

      if (enemies.bossTimer[j] > 0) enemies.bossTimer[j] -= dt;
      final bool lethal = enemies.bossTimer[j] <= 0;
      final TelegraphSeverity severity =
          lethal ? TelegraphSeverity.lethal : TelegraphSeverity.warning;

      final double toX = store.posX[j];
      final double toY = store.posY[j];

      if (EnemyAttack.hasTelegraph(ctx, j) &&
          ctx.telegraphs.severityAt(enemies.telegraphSlot[j]) == severity) {
        // Same severity as last tick — just follow the add as it wanders.
        EnemyAttack.retarget(ctx, j, toX, toY);
        EnemyAttack.extendTelegraph(ctx, j, ctx.now + _chainCooldown);
      } else {
        // Either this add's very first tick, or its own warning→lethal
        // transition — `beginLine` ends whatever was there first.
        EnemyAttack.beginLine(
          ctx,
          j,
          originX,
          originY,
          toX,
          toY,
          _chainWidth,
          _chainCooldown,
          severity: severity,
        );
      }

      if (lethal &&
          EnemyAttack.playerOnLine(ctx, originX, originY, toX, toY, _chainWidth)) {
        playerHit = true;
      }
    }

    if (playerHit && enemies.bossTimer[primary] <= 0) {
      EnemyAttack.damagePlayer(ctx, _chainDamage, source: primary);
      enemies.bossTimer[primary] = _chainCooldown;
    }
  }

  static void _clearChains(AiContext ctx, int primary) {
    final int high = ctx.entities.highWater;
    for (int j = 0; j < high; j++) {
      if (ctx.entities.alive[j] == 0) continue;
      if (ctx.enemies.spawnerSlot[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
    }
  }

  /// Flips the grid's own parity every [_gridCycleSeconds]
  /// (`bossLastHitAgo` as the countdown, `comboStep` as the 0/1 flag —
  /// both free on this boss's own primary, spoken for on other bosses'
  /// primaries by other meanings, never this one's) and damages the
  /// player on the roster's own established tick while they stand on a
  /// currently-live cell (`bossSweepAngle`, repurposed as a plain
  /// cooldown scalar rather than an angle — this boss never sweeps
  /// anything).
  static void _tickGrid(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    enemies.bossLastHitAgo[primary] -= dt;
    if (enemies.bossLastHitAgo[primary] <= 0) {
      enemies.bossLastHitAgo[primary] += _gridCycleSeconds;
      enemies.comboStep[primary] = enemies.comboStep[primary] == 0 ? 1 : 0;
    }

    if (enemies.bossSweepAngle[primary] > 0) {
      enemies.bossSweepAngle[primary] -= dt;
    }

    if (!ctx.hasPlayer) return;
    if (!_onLiveCell(ctx, primary)) return;
    if (enemies.bossSweepAngle[primary] > 0) return;

    EnemyAttack.damagePlayer(ctx, _gridDamagePerTick, source: primary);
    enemies.bossSweepAngle[primary] = _gridDamageTickSeconds;
  }

  static bool _onLiveCell(AiContext ctx, int primary) {
    final int cellX = (ctx.playerX / _gridCellSize).floor();
    final int cellY = (ctx.playerY / _gridCellSize).floor();
    final bool cellParity = (cellX + cellY).isEven;
    return cellParity == (ctx.enemies.comboStep[primary] == 0);
  }

  /// Makes the primary genuinely unkillable, places the four conduits
  /// (once), and — the instant the last one falls — zeroes the primary's
  /// own health so the ordinary death/reap pass finishes the boss off the
  /// same tick.
  static void _tickP3(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    enemies.untargetable[primary] = 1;
    enemies.plateHalfArc[primary] = math.pi;
    enemies.plateFlatFactor[primary] = _p3ShutPlateFactor;
    enemies.plateHealth[primary] = store.maxHealth[primary];

    _spawnConduits(ctx, primary);

    int aliveConduits = 0;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      aliveConduits++;
    }

    if (aliveConduits == 0 && store.health[primary] > 0) {
      store.health[primary] = 0;
    }
  }

  /// Places [_p3ConduitCount] ordinary, independently-healthed, fully
  /// targetable conduits around the primary's own position — exactly
  /// once. `bossActiveChildIndex` (free — P1/P2 never touch it) is a
  /// genuine one-time latch here, deliberately *not* the "scan for an
  /// existing alive child" shape every other placed-once child in this
  /// roster uses: that shape's "already placed" signal is really "any
  /// are still *alive*", which — for conduits that are actually meant to
  /// be fought down to zero, unlike every other roster's own
  /// untargetable accounting anchor — would read "none placed yet" the
  /// instant the last one died and silently respawn a fresh batch
  /// forever, an infinite-respawn bug this exact test file caught before
  /// it shipped.
  static void _spawnConduits(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (enemies.bossActiveChildIndex[primary] != 0) return; // already placed
    enemies.bossActiveChildIndex[primary] = 1;

    final double conduitHealth =
        store.maxHealth[primary] * _p3ConduitHealthFraction;

    for (int ordinal = 0; ordinal < _p3ConduitCount; ordinal++) {
      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      final double angle = 2 * math.pi * ordinal / _p3ConduitCount;
      final double x =
          store.posX[primary] + _p3ConduitPlacementRadius * math.cos(angle);
      final double y =
          store.posY[primary] + _p3ConduitPlacementRadius * math.sin(angle);

      store.posX[slot] = x;
      store.posY[slot] = y;
      store.radius[slot] = 0.5;
      store.health[slot] = conduitHealth;
      store.maxHealth[slot] = conduitHealth;
      store.contentIndex[slot] = -1;
      ctx.events.emit(SimEventType.entitySpawned, entityA: slot, x: x, y: y);

      enemies.reset(slot);
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = ordinal;
    }
  }
}
