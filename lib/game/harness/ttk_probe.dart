import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/harness/expected_power.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';

/// The single-fight half of the TTK Law's harness (docs/02 §2.6): how long
/// an expected-power loadout takes to kill one fresh common enemy.
///
/// Deliberately the smallest possible measurement — one hero, one arrow, one
/// [EnemyArchetype.mote], no room, no other enemies, no Boons. `HarnessBot`
/// (a later Part of this same phase) is where a real generated stage and an
/// accumulated Boon draw get folded in; this probe is the part of docs/02's
/// own DPS-vs-HP chain that needs neither.
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

  /// Seconds to kill one fresh mote at global stage [globalStage], for
  /// [hero] carrying [arrow] at [power]. `null` means the mote outlived
  /// [timeoutSeconds].
  static double? measure({
    required HeroDefinition hero,
    required ArrowDefinition arrow,
    required ExpectedPower power,
    required ContentLibrary content,
    required int globalStage,
    required int seed,
  }) {
    final SimWorld world = SimWorld(seed: seed, content: content)
      ..autoFire = true
      ..enemyHpBase = Curves.enemyHp(globalStage);
    world.spawnPlayer(4.0, 4.5);
    HeroLoadoutResolver.apply(
      world,
      hero,
      power.heroState(hero.key),
      arrow,
      power.arrowInstance(arrow.key),
    );

    final int mote =
        world.spawnEnemy(EnemyArchetype.mote, 4.0 + targetDistance, 4.5);
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
