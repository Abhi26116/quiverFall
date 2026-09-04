import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';

/// The Weeping Gate — docs/06 §10, chapter 10's boss. "Tests: everything
/// from chapters 1-9 · Ascension gate." "A stationary arch that never
/// moves and never directly attacks."
///
/// **P1 only, built here.** "Opens portals spawning waves that escalate
/// through the full enemy roster." Unlike every other single-body boss so
/// far, the Gate has no attack of its own at all in P1 — the threat is
/// entirely the ordinary enemies it spawns, each running its own already-
/// built family tree the instant it exists, the same "spawn a real,
/// independent enemy and the existing roster does the rest" shape
/// Arclight's Swarmlings and Green Mother's Knitters already established
/// (ADR 0027/0028).
///
/// **A real, honestly-scoped-down reading of "the full enemy roster":**
/// docs/05 names 26 base enemies; cycling live spawn logic through all of
/// them by name is a large content-mapping exercise this pass does not
/// attempt. Instead, six archetypes spanning chapters 1-6's own unlock
/// order (Mote, Swarmling, Wisp, Bounder, Thresher, Screecher — one
/// representative per early chapter, each already a plain, no-special-
/// interaction enemy) unlock one at a time as P1's own elapsed time
/// passes, each spawn drawing at random from whichever prefix is unlocked
/// so far. "Escalates" here means the *pool widens*, not that the raw
/// spawn rate also climbs — a deliberate simplification. See ADR 0030.
///
/// **No plate in P1.** docs/06's own plate line ("The Gate's own plating
/// opens only while fewer than three enemies are alive") is written
/// against P2, not P1 — read literally as the plate itself arriving with
/// P2, not as a permanently-shut plate the whole fight sits behind. That
/// keeps `BossPhaseSystem`'s own generic HP-threshold advance working
/// completely unmodified, the same posture every other boss's own plain,
/// undefended P1 already takes (Skarn, Green Mother).
///
/// **Not built here: P2 (portals spawn Riftborn elites in pairs; the
/// Gate's own plate opens only while fewer than three enemies are alive —
/// a genuinely new conditional-plate mechanic) and P3 (all portals open at
/// once, permanently; a 40s survival check while burning the core).** Once
/// `bossPhase` reaches 1, spawning stops and any live telegraph is
/// cleared — the same posture every other boss's own undone phases
/// already take. Any spawned enemy is not despawned — the same "an add
/// outlives its summoner" posture Arclight's/Green Mother's own adds
/// already established.
abstract final class WeepingGateSystem {
  /// Reused from the Rift Maw (docs/05 #22) — the same wind-up every add
  /// spawn in the roster announces itself with.
  static const double _spawnWindUpSeconds = 0.5;

  /// Reused from Green Mother's own spawn interval (ADR 0028).
  static const double _spawnIntervalSeconds = 1.0;

  /// Reused from the Rift Maw again — the same "beyond this a phone screen
  /// is unreadable" ceiling.
  static const int _spawnCap = 16;

  /// A conservative stand-in for `EnemySpawner.findSpawnPoint`'s own
  /// radius argument, used before the archetype for a given portal has
  /// even been chosen (the choice happens at resolve time, once the
  /// portal's own position is already committed via its telegraph — see
  /// the class doc comment). Authored, not derived from any specific
  /// enemy's own radius.
  static const double _portalPlacementRadius = 0.5;

  /// How long P1 runs before the next archetype tier unlocks. Authored —
  /// docs/06 states no escalation cadence at all. See ADR 0030.
  static const double _tierUnlockIntervalSeconds = 15.0;

  /// One representative per chapter 1-6 unlock, in unlock order (docs/05's
  /// own per-chapter table). Content indices are resolved once, lazily,
  /// the first time [_summon] runs — [ContentLibrary] is immutable for the
  /// life of a run, so nothing here needs to re-resolve them per spawn.
  static const List<String> _rosterIds = <String>[
    'mote',
    'swarmling',
    'wisp',
    'bounder',
    'thresher',
    'screecher',
  ];

  /// Places the Gate's single, stationary, unplated body. Returns its
  /// slot, or -1 if the entity pool was full or [BossArchetype.weepingGate]
  /// has no catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 1.0,
  }) {
    final int bossIndex =
        content.bosses.indexOfArchetype(BossArchetype.weepingGate);
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.weepingGate) {
        continue;
      }

      // P2/P3 not built yet (see the class doc comment) — frozen, its own
      // spawn telegraph cleared, rather than left mid-wind-up forever.
      if (enemies.bossPhase[i] >= 1) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        continue;
      }

      _tickSpawns(ctx, i, dt);
    }
  }

  static void _tickSpawns(AiContext ctx, int slot, double dt) {
    final EnemyStore enemies = ctx.enemies;

    // `bossTimer` doubles as P1's own elapsed-time clock — the same reuse
    // Cinder Choir's P2 sweep already established for that field.
    enemies.bossTimer[slot] += dt;

    if (enemies.stateOf(slot) == AiState.windUp) {
      enemies.stateTimer[slot] -= dt;
      if (enemies.stateTimer[slot] > 0) return;
      _summon(ctx, slot);
      enemies.attackCooldown[slot] = _spawnIntervalSeconds;
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

    EnemySpawner.findSpawnPoint(ctx, _portalPlacementRadius);
    enemies.state[slot] = AiState.windUp.index;
    enemies.stateTimer[slot] = _spawnWindUpSeconds;
    EnemyAttack.beginCircle(
      ctx,
      slot,
      EnemySpawner.pointX,
      EnemySpawner.pointY,
      _portalPlacementRadius,
      _spawnWindUpSeconds,
    );
  }

  /// Spawns at the portal's own committed position — read back from its
  /// own live telegraph rather than a second, separately-tracked field,
  /// since a telegraph already persists an x/y across the wind-up it was
  /// given. The archetype itself is only chosen now, from whichever
  /// prefix of [_rosterIds] P1's own elapsed time has unlocked so far.
  static void _summon(AiContext ctx, int slot) {
    final EnemyStore enemies = ctx.enemies;
    if (!EnemyAttack.hasTelegraph(ctx, slot)) return;

    final int telegraphSlot = enemies.telegraphSlot[slot];
    final double x = ctx.telegraphs.xAt(telegraphSlot);
    final double y = ctx.telegraphs.yAt(telegraphSlot);
    EnemyAttack.endTelegraph(ctx, slot);

    if (enemies.liveAdds[slot] >= _spawnCap) return;
    if (EnemySpawner.atEnemyCap(ctx)) return;

    final int unlocked = 1 +
        (enemies.bossTimer[slot] / _tierUnlockIntervalSeconds).floor();
    final int prefixLength =
        unlocked > _rosterIds.length ? _rosterIds.length : unlocked;
    final String id = _rosterIds[ctx.rng.nextInt(prefixLength)];
    final int contentIndex = ctx.content.enemyIndexById[id] ?? -1;
    if (contentIndex < 0) return;

    EnemySpawner.spawn(
      ctx,
      contentIndex: contentIndex,
      x: x,
      y: y,
      spawnerSlot: slot,
    );
  }
}
