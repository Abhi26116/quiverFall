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
/// **Not built here: P3 (untargetable orbit; four grounded conduits;
/// Confluence chains between them).** Once `bossPhase` reaches 2, spawning,
/// chains, and the grid all stop — the same posture every other boss's own
/// undone phase already takes. Any Swarmling still alive at that point (or
/// spawned before Arclight itself dies) is *not* despawned — the same "an
/// add outlives its summoner" behaviour the ordinary Rift Maw already has
/// — so a boss room's own zero-enemies clear condition (ADR 0021) extends
/// to mopping up any stragglers, which reads as "and spacing" continuing
/// to matter even after Arclight itself falls, rather than as a bug. See
/// ADR 0027.
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

      // P3 not built yet (see the class doc comment) — frozen, both its
      // own spawn telegraph and every live chain cleared, rather than left
      // mid-wind-up or mid-hazard forever.
      if (enemies.bossPhase[i] >= 2) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        _clearChains(ctx, i);
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
}
