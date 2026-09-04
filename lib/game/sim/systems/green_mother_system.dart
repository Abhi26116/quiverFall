import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';

/// The Green Mother — docs/06 §8, chapter 8's boss. "Tests: Toxin, and DPS
/// checks."
///
/// **P1 only, built here.** "Spawns Knitters continuously; the Mother heals
/// from each. A raw DPS check — fail it and the fight is literally
/// unwinnable, which the game states outright in the death screen." A
/// stationary single body, spawning the same way Arclight already does
/// (ADR 0027, itself the Rift Maw's own cycle — `EnemySpawner.spawn`,
/// `EnemyStore.liveAdds`, `EnemySpawner.atEnemyCap`), so
/// [GreenMotherSystem] is *only* that spawn cycle: no attack, no line
/// hazard, nothing else — the same "P1 has no attack at all" shape Skarn's
/// own P1 already established (ADR 0022) when the card's own lesson is
/// entirely about something other than the boss's own offence.
///
/// **The heal itself needed no new code whatsoever.** `AiSystem._applyAuras`
/// already heals *any* alive `EntityKind.enemy` entity within a Knitter's
/// aura radius, boss body included, and `AiSystem._heal` already applies
/// `ctx.status.healingMultiplier` — Toxin's own healing-reduction hook — to
/// every heal it grants. Spawn real Knitters near the Mother and both of
/// this card's own stated lessons (Toxin, and the DPS check) are already
/// true, entirely from systems built for Phase 9's ordinary roster.
///
/// **A real, latent bug was found and fixed getting here, not introduced by
/// this boss**: `ChoirTree._isAlly` called `ctx.definitionOf(other)`
/// unconditionally, which crashes on any bare entity with no content
/// definition (`contentIndex = -1` — every boss's own body, since Phase
/// 11's very first commit). Nothing had ever put a Choir-family enemy
/// (Knitter, Chanter, Weaver, Warden-Fell) in a room with a boss before
/// this fight — the crash was reachable the moment it was. See ADR 0028.
///
/// **Not built here: P2 (telegraphed root-eruption lines; stacking poison
/// on contact) and P3 (a 3s exposed-core window every 8s; everything else
/// invulnerable).** Once `bossPhase` reaches 1, spawning stops — the same
/// posture every other boss's own undone phases already take. Any Knitter
/// still alive is *not* despawned, the same "an add outlives its summoner"
/// posture Arclight's own Swarmlings already established (ADR 0027) — a
/// boss room's own zero-enemies clear condition (ADR 0021) applies here
/// too.
abstract final class GreenMotherSystem {
  /// Reused from the Rift Maw (docs/05 #22) — the same wind-up every add
  /// spawn in the roster announces itself with.
  static const double _spawnWindUpSeconds = 0.5;

  /// Authored, not GDD-stated: "continuously" reads as a steady trickle
  /// rather than the Rift Maw's own periodic bursts, so this spawns one
  /// Knitter at a time rather than the Rift Maw's own four. The exact rate
  /// is an unproven placeholder — real DPS-check tuning (how fast must a
  /// given power level clear a Knitter to out-race its own heal) is a
  /// balance-harness question (Phase 14), not one this pass can answer.
  /// See ADR 0028.
  static const double _spawnIntervalSeconds = 1.0;

  /// Reused from the Rift Maw again: the same "beyond this a phone screen
  /// is unreadable" ceiling justifies the cap here as much as there.
  static const int _spawnCap = 16;

  /// How many ring positions new Knitters cycle through around the Mother.
  /// Authored staging, not a GDD number, the same kind of choice Cinder
  /// Choir's own `triangleRadius`/`effigyRadius` already are (ADR 0018) —
  /// just enough spread that a steady trickle does not stack every arrival
  /// on the exact same point.
  static const int _ringPositions = 8;

  /// Places the Mother's single, stationary body. Returns its slot, or -1
  /// if the entity pool was full or [BossArchetype.greenMother] has no
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
        content.bosses.indexOfArchetype(BossArchetype.greenMother);
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.greenMother) {
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

  /// The Rift Maw's own cycle (`RiftbornTree._riftMaw`), reused directly:
  /// wind up (with a telegraph announcing where the next Knitter will
  /// arrive), spawn, cool down, repeat — capped both locally
  /// ([_spawnCap], via `EnemyStore.liveAdds`) and globally
  /// (`EnemySpawner.atEnemyCap`). The Mother's own healing from each
  /// Knitter needs no call here at all — see the class doc comment.
  static void _tickSpawns(AiContext ctx, int slot, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (enemies.stateOf(slot) == AiState.windUp) {
      enemies.stateTimer[slot] -= dt;
      if (enemies.stateTimer[slot] > 0) return;
      EnemyAttack.endTelegraph(ctx, slot);
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
    final int contentIndex = ctx.content.enemyIndexById['knitter'] ?? -1;
    if (contentIndex < 0) return;
    if (ctx.enemies.liveAdds[slot] >= _spawnCap) return;
    if (EnemySpawner.atEnemyCap(ctx)) return;

    EnemySpawner.ringPoint(
      ctx,
      slot,
      ctx.enemies.liveAdds[slot] % _ringPositions,
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
  }
}
