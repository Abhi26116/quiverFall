import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/harness/expected_power.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';

/// The single-fight half of the TTK Law's harness (docs/02 §2.6): how long
/// an expected-power loadout takes to kill one fresh common enemy.
///
/// [measure] is the smallest possible version — one hero, one arrow, one
/// [EnemyArchetype.mote], no room, no other enemies, no Boons.
/// [measureAgainstFreshMote] is the shared core it and `TtkWithBoonsProbe`
/// (Phase 12 Part 2 — a real generated stage and an accumulated Boon draw
/// via `HarnessBot`) both tick: given *any* world already carrying whatever
/// loadout matters, reset it to one clean fight and time it.
abstract final class TtkProbe {
  /// Every TTK reading in this harness is taken with Wren: the starter
  /// hero, with no elemental application, chain, or AoE hook of her own to
  /// skew a measurement meant to characterise the campaign's *curve*, not
  /// any one hero's kit — the same "plainest available option" reasoning
  /// [ExpectedPower] uses picking an arrow per tier. See ADR 0089.
  static const HeroArchetype referenceHero = HeroArchetype.wren;

  /// Distance in front of the player the mote spawns at. Far enough that
  /// the arrow's own travel time is a negligible sliver of any real TTK
  /// reading, close enough that autoFire's own targeting always has one shot
  /// in flight.
  static const double targetDistance = 8.0;

  /// A kill that has not landed by here is a harness failure to report, not
  /// a slow-but-valid TTK — every hard-bound chapter target is well under
  /// this (docs/02 §2.6's own ceiling is 2.2 s).
  static const double timeoutSeconds = 12.0;

  /// The fixed point every measurement teleports the player to before
  /// spawning the mote — arena-agnostic (every standard arena is clear
  /// here), so a caller with an already-live world (mid-room, `HarnessBot`
  /// having walked the player anywhere at all) never has to reason about
  /// that room's own wall geometry to get a clean shot.
  static const double _playerX = 4.0;
  static const double _playerY = 4.5;

  /// Seconds to kill one fresh mote at global stage [globalStage], for
  /// [hero] carrying [arrow] at [power]. `null` means the mote outlived
  /// [timeoutSeconds]. No Boons, no room — see [measureAgainstFreshMote] for
  /// the version that measures a world already carrying either.
  static double? measure({
    required HeroDefinition hero,
    required ArrowDefinition arrow,
    required ExpectedPower power,
    required ContentLibrary content,
    required int globalStage,
    required int seed,
  }) {
    final SimWorld world = SimWorld(seed: seed, content: content)
      ..autoFire = true;
    world.spawnPlayer(_playerX, _playerY);
    HeroLoadoutResolver.apply(
      world,
      hero,
      power.heroState(hero.key),
      arrow,
      power.arrowInstance(arrow.key),
    );
    return measureAgainstFreshMote(world, globalStage: globalStage);
  }

  /// Resets [world] to one clean fight and times it: every currently-alive
  /// enemy is despawned (so only the fresh mote's own death can end this —
  /// whatever room `HarnessBot` left the world mid-fight in is irrelevant
  /// from here on), the player is teleported to [_playerX]/[_playerY] and
  /// rooted, and one fresh mote is spawned [targetDistance] away at
  /// [globalStage]'s own HP curve.
  ///
  /// Whatever hero, arrow, and Boon build [world] already carries is left
  /// completely untouched — this only ever adds a clean target to shoot at.
  static double? measureAgainstFreshMote(
    SimWorld world, {
    required int globalStage,
  }) {
    world.enemyHpBase = Curves.enemyHp(globalStage);
    world.autoFire = true;

    for (int i = 0; i < world.entities.highWater; i++) {
      if (world.entities.alive[i] == 0) continue;
      if (world.entities.kind[i] != EntityKind.enemy.index) continue;
      world.entities.despawn(world.entities.idAt(i));
    }

    if (!world.entities.isAlive(world.player)) return null;
    final int p = world.player.index;
    world.entities.posX[p] = _playerX;
    world.entities.posY[p] = _playerY;
    world.entities.velX[p] = 0;
    world.entities.velY[p] = 0;

    final int mote = world.spawnEnemy(
      EnemyArchetype.mote,
      _playerX + targetDistance,
      _playerY,
    );
    if (mote < 0) return null;
    // Stationary target: TTK measures the loadout's DPS against the HP
    // curve, not a mote's own drift AI closing or opening the range.
    world.enemies.speedScale[mote] = 0;

    final InputSnapshot idle = InputSnapshot();
    final int maxTicks = (timeoutSeconds * 60).round();
    for (int tick = 0; tick < maxTicks; tick++) {
      world.tick(idle);
      if (world.entities.alive[mote] == 0 || world.entities.health[mote] <= 0) {
        return (tick + 1) / 60.0;
      }
    }
    return null;
  }
}
