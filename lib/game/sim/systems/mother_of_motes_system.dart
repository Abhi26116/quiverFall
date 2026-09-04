import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';

/// Mother of Motes — docs/06 §6.3, Endless Descent boss #19. Floor 40, 80…
///
/// "Spawns 200+ Motes over the fight. Pure crowd-clear check and the
/// game's designated 'look how strong I've become' power fantasy — the
/// fight exists so that a maxed build feels absurd, on purpose."
///
/// **A single mechanic across all three phases, escalating in rate rather
/// than changing in kind.** Unlike a campaign boss, docs/06 gives this
/// fight one paragraph, not a P1/P2/P3 breakdown — read literally, there
/// is only one thing this boss ever does. `BossPhaseSystem`'s own generic
/// three-phase machinery still applies (every boss gets it, `bosses.json`
/// already carries the standard `[0.66, 0.33]` thresholds), so the three
/// phases are read as the spawn rate itself intensifying as the fight
/// wears on — "look how strong I've become" is exactly the escalating-
/// swarm shape a raw crowd-clear check would take.
///
/// **No new sim primitive at all — the fourth boss in this roster whose
/// entire threat is delegated to what it spawns.** The cycle is the Rift
/// Maw's own (`RiftbornTree._riftMaw`), the same `EnemySpawner.spawn`/
/// `EnemyStore.liveAdds`/`EnemySpawner.atEnemyCap`/`EnemySpawner.ringPoint`
/// machinery Arclight's Swarmlings, the Green Mother's Knitters, and the
/// Weeping Gate's own roster escalation all already use (ADR 0027/0028/
/// 0030) — here spawning nothing but Motes, the single cheapest, plainest
/// enemy in the game (docs/05's own first-introduced archetype), matching
/// "pure crowd-clear" literally: no elemental gimmick, no special
/// interaction, just volume. The body itself deals no direct damage of
/// its own, the same "P1 has no attack" shape Skarn's, the Weeping
/// Gate's, and the Green Mother's own spawn-only phases already
/// established.
///
/// **"200+ Motes over the fight" is a lifetime count, not a simultaneous
/// one** — `comboStep` (free; nothing else in this file touches it)
/// tallies every Mote ever summoned, unbounded, entirely separate from
/// `liveAdds`'s own simultaneous on-screen cap. Nothing mechanical keys
/// off reaching 200 specifically; docs/06 states no on-screen behaviour
/// change at that count, only that the fight's own total volume reaches
/// it — a target the escalating rate below is authored to comfortably
/// clear over a normal-length Endless fight, not a threshold this system
/// itself checks or enforces. See ADR 0056.
///
/// **The exact escalation rate, like every Endless boss's own missing
/// `targetDurationSeconds` (ADR 0017), is an authored placeholder.**
/// docs/06 states no per-phase cadence at all, and unlike a campaign
/// boss, Endless bosses have no stated fight length to size a rate
/// against — real tuning is a Phase 14 balance-harness question.
abstract final class MotherOfMotesSystem {
  /// Reused from the Rift Maw (docs/05 #22) — the same wind-up every add
  /// spawn in the roster announces itself with.
  static const double _spawnWindUpSeconds = 0.5;

  /// Authored — escalates roughly 2x each phase, "look how strong I've
  /// become" read as the swarm visibly thickening as the fight wears on.
  static const double _p1IntervalSeconds = 0.8;
  static const double _p2IntervalSeconds = 0.4;
  static const double _p3IntervalSeconds = 0.2;

  /// Reused from the Rift Maw again — the same "beyond this a phone
  /// screen is unreadable" ceiling every other spawner boss caps at.
  static const int _spawnCap = 16;

  /// How many ring positions new Motes cycle through — Green Mother's own
  /// staging choice (ADR 0028), reused rather than a fresh number.
  static const int _ringPositions = 8;

  /// Places the Mother's single, stationary body. Returns its slot, or -1
  /// if the entity pool was full or [BossArchetype.motherOfMotes] has no
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
        content.bosses.indexOfArchetype(BossArchetype.motherOfMotes);
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.motherOfMotes) {
        continue;
      }

      final double interval = switch (enemies.bossPhase[i]) {
        0 => _p1IntervalSeconds,
        1 => _p2IntervalSeconds,
        _ => _p3IntervalSeconds,
      };
      _tickSpawns(ctx, i, dt, interval);
    }
  }

  /// The Rift Maw's own cycle, reused directly: wind up (with a telegraph
  /// announcing where the next Mote will arrive), spawn, cool down on
  /// [interval], repeat — capped both locally ([_spawnCap], via
  /// `EnemyStore.liveAdds`) and globally (`EnemySpawner.atEnemyCap`).
  static void _tickSpawns(AiContext ctx, int slot, double dt, double interval) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (enemies.stateOf(slot) == AiState.windUp) {
      enemies.stateTimer[slot] -= dt;
      if (enemies.stateTimer[slot] > 0) return;
      EnemyAttack.endTelegraph(ctx, slot);
      _summon(ctx, slot);
      enemies.attackCooldown[slot] = interval;
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
    final int contentIndex = ctx.content.enemyIndexById['mote'] ?? -1;
    if (contentIndex < 0) return;
    if (ctx.enemies.liveAdds[slot] >= _spawnCap) return;
    if (EnemySpawner.atEnemyCap(ctx)) return;

    EnemySpawner.ringPoint(
      ctx,
      slot,
      ctx.enemies.comboStep[slot] % _ringPositions,
      _ringPositions,
      EnemyTuning.riftMawSpawnRadius,
    );
    EnemySpawner.spawn(
      ctx,
      contentIndex: contentIndex,
      x: EnemySpawner.pointX,
      y: EnemySpawner.pointY,
      spawnerSlot: slot,
    );
    // The fight's own lifetime total — see the class doc comment.
    ctx.enemies.comboStep[slot]++;
  }
}
