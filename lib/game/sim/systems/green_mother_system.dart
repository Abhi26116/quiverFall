import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
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
/// **P2: "Roots erupt along telegraphed lines; contact applies stacking
/// poison to the player."** Each eruption spawns three fresh, untargetable
/// line-anchor children (Cinder Choir's own "one telegraph per owning
/// child" shape, ADR 0018), each warning then resolving once and
/// despawning itself — a one-shot event, not a persistent hazard like
/// Silversong's own pillars (ADR 0036). Deals no direct HP damage of its
/// own, matching the card's own silence on damage (it only ever names the
/// poison) — the same reading Silversong's own "no HP damage at all" card
/// already established for a status-only attack.
///
/// **"Stacking poison" reuses the real Toxin primitive, not a parallel
/// one.** `StatusStore.apply` already stacks Toxin identically regardless
/// of source — an arrow's own element, a Boon, or (now) contact with a
/// root — so `ctx.status.apply(ctx.player, SimElement.toxin)` on contact
/// is the entire "stacking" implementation. The *tick damage* from those
/// stacks is the one genuinely new piece: `ElementSystem`'s own DoT pass
/// only ever processes `EntityKind.enemy` entities (Toxin has only ever
/// been something the player inflicts, never receives), so
/// `GreenMotherSystem` applies `ElementTuning.toxinPerStackPerSecond`
/// itself, every tick, directly to the player — the same rate and the
/// same continuous-not-discretised cadence `ElementSystem` already uses
/// for every ordinary DoT, just executed from outside it rather than by
/// widening a shared system's own gate. See ADR 0040.
///
/// **Not built here: P3 (a 3s exposed-core window every 8s; everything
/// else invulnerable).** Once `bossPhase` reaches 2, spawning and root
/// eruptions both stop — the same posture every other boss's own undone
/// phase already takes. Any Knitter still alive is *not* despawned, the
/// same "an add outlives its summoner" posture Arclight's own Swarmlings
/// already established (ADR 0027) — a boss room's own zero-enemies clear
/// condition (ADR 0021) applies here too.
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

  // ── P2: root eruptions ───────────────────────────────────────────────────
  // See ADR 0040.

  /// "Lines", plural — authored, not GDD-stated.
  static const int _rootCount = 3;

  /// The roster's own established "amber warning" wind-up.
  static const double _rootWindUpSeconds = 0.6;

  /// Authored — docs/06 gives no cadence between eruptions.
  static const double _rootCooldownSeconds = 3.0;

  /// Authored — no stated root length.
  static const double _rootLength = 5.0;

  /// ADR 0008/0019's own reused line-hazard width.
  static const double _rootWidth = SimConfig.windlineHitWidth;

  /// A conservative stand-in for `EnemySpawner.findSpawnPoint`'s own
  /// radius argument — the same "authored placement radius, not a real
  /// enemy's own" choice the Weeping Gate's own portals already made
  /// (ADR 0030).
  static const double _rootPlacementRadius = 0.5;

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

      // The primary's own health reached zero this tick. Any root still
      // mid-formation is untargetable with no death condition of its
      // own — left alone, it would sit alive forever, and the boss
      // room's own "zero alive enemies" clear condition (ADR 0021) would
      // never fire. The same cleanup every multi-body boss's own
      // `_despawnChildren` already does.
      if (store.health[i] <= 0) {
        _despawnRoots(ctx, i);
        continue;
      }

      // P3 not built yet (see the class doc comment) — frozen, its own
      // spawn telegraph and every forming root cleared, rather than left
      // mid-wind-up forever.
      if (enemies.bossPhase[i] >= 2) {
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        _clearRootTelegraphs(ctx, i);
        continue;
      }

      _tickSpawns(ctx, i, dt);
      if (enemies.bossPhase[i] >= 1) _tickRoots(ctx, i, dt);
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

  /// Advances any forming/resolving roots, applies the ongoing Toxin DoT
  /// (see the class doc comment — `ElementSystem` never touches the
  /// player), and starts a fresh eruption once [_rootCooldownSeconds] has
  /// passed (`bossTimer`, free here — the spawn cycle above uses `state`/
  /// `stateTimer`/`attackCooldown` on the *primary*, never this field).
  static void _tickRoots(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (enemies.stateOf(j) != AiState.windUp) continue;

      enemies.stateTimer[j] -= dt;
      if (enemies.stateTimer[j] > 0) continue;
      _resolveRoot(ctx, j);
      store.despawn(store.idAt(j));
    }

    if (ctx.hasPlayer && ctx.status.toxinStacks[ctx.player] > 0) {
      EnemyAttack.damagePlayer(
        ctx,
        ElementTuning.toxinPerStackPerSecond * ctx.status.toxinStacks[ctx.player] * dt,
        source: primary,
      );
    }

    if (enemies.bossTimer[primary] > 0) {
      enemies.bossTimer[primary] -= dt;
      return;
    }

    _eruptRoots(ctx, primary);
    enemies.bossTimer[primary] = _rootCooldownSeconds;
  }

  /// Places [_rootCount] fresh root anchors, each its own randomly-placed,
  /// randomly-aimed line, each owning its own wind-up telegraph on its own
  /// slot — the same "one telegraph per owning child" shape Cinder
  /// Choir's own tether sweep already established (ADR 0018/0019).
  static void _eruptRoots(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    for (int k = 0; k < _rootCount; k++) {
      EnemySpawner.findSpawnPoint(ctx, _rootPlacementRadius);
      final double x0 = EnemySpawner.pointX;
      final double y0 = EnemySpawner.pointY;

      final double angle = ctx.rng.nextDouble() * 2 * math.pi;
      double x1 = x0 + _rootLength * math.cos(angle);
      double y1 = y0 + _rootLength * math.sin(angle);
      if (x1 < _rootPlacementRadius) x1 = _rootPlacementRadius;
      if (x1 > ctx.arena.width - _rootPlacementRadius) {
        x1 = ctx.arena.width - _rootPlacementRadius;
      }
      if (y1 < _rootPlacementRadius) y1 = _rootPlacementRadius;
      if (y1 > ctx.arena.height - _rootPlacementRadius) {
        y1 = ctx.arena.height - _rootPlacementRadius;
      }

      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      store.posX[slot] = x0;
      store.posY[slot] = y0;
      store.radius[slot] = 0.01;
      store.health[slot] = store.maxHealth[primary];
      store.maxHealth[slot] = store.maxHealth[primary];
      store.contentIndex[slot] = -1;
      ctx.events.emit(SimEventType.entitySpawned, entityA: slot, x: x0, y: y0);

      enemies.reset(slot);
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = k;
      enemies.untargetable[slot] = 1;
      enemies.state[slot] = AiState.windUp.index;
      enemies.stateTimer[slot] = _rootWindUpSeconds;

      EnemyAttack.beginLine(ctx, slot, x0, y0, x1, y1, _rootWidth, _rootWindUpSeconds);
    }
  }

  /// Resolves one root against the position its own wind-up already
  /// committed to — read back out of the telegraph itself (`xAt`/`yAt`/
  /// `toXAt`/`toYAt`), the same trick the Weeping Gate's own portals and
  /// Vermillion's own charge already use (ADR 0030/0037) — rather than a
  /// second field to remember it in. Applies one Toxin stack on contact,
  /// no direct damage of its own (see the class doc comment).
  static void _resolveRoot(AiContext ctx, int slot) {
    final EnemyStore enemies = ctx.enemies;
    final int telegraphSlot = enemies.telegraphSlot[slot];
    if (telegraphSlot < 0) return;

    final double x0 = ctx.telegraphs.xAt(telegraphSlot);
    final double y0 = ctx.telegraphs.yAt(telegraphSlot);
    final double x1 = ctx.telegraphs.toXAt(telegraphSlot);
    final double y1 = ctx.telegraphs.toYAt(telegraphSlot);

    EnemyAttack.beginLine(
      ctx,
      slot,
      x0,
      y0,
      x1,
      y1,
      _rootWidth,
      0,
      severity: TelegraphSeverity.lethal,
    );

    if (ctx.hasPlayer && EnemyAttack.playerOnLine(ctx, x0, y0, x1, y1, _rootWidth)) {
      ctx.status.apply(ctx.player, SimElement.toxin);
    }
  }

  static void _despawnRoots(AiContext ctx, int primary) {
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

  static void _clearRootTelegraphs(AiContext ctx, int primary) {
    final int high = ctx.entities.highWater;
    for (int j = 0; j < high; j++) {
      if (ctx.entities.alive[j] == 0) continue;
      if (ctx.enemies.bossParent[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
    }
  }
}
