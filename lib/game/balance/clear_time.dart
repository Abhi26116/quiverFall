import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';

/// How long a room takes to clear, estimated.
///
/// docs/14 §14.2 rejects any generated room whose estimated clear time falls
/// outside **18–55 s at expected power**, and attributes the estimate to "the
/// balance harness's model". That harness is Phase 12. **This is the
/// placeholder it will replace**, and it is built to be replaced: one function,
/// a handful of named constants, no caller depending on how it works.
///
/// ## Why this is dimensionless
///
/// Design Law 1 (the TTK Law) says a common enemy dies in 0.8–1.6 s *at every
/// point in the game* for a correctly-progressed player. Every HP curve is
/// derived from that, and so is the player's attack. The stage index therefore
/// **cancels**: a x1.0 enemy costs the same number of seconds at stage 1 and at
/// stage 240, and a room's clear time depends only on the sum of its enemies'
/// HP multipliers.
///
/// That is a strong claim, and it is exactly the claim Phase 12 will measure.
/// If the harness disagrees with this model, the harness is right — but the
/// disagreement will itself be the finding, because it means the TTK Law is not
/// holding somewhere.
///
/// ## What it deliberately ignores
///
/// Boons, hero kits, arrow types, and player skill. All four move clear time
/// enormously, and none of them exist at room-generation time — the generator
/// runs before the player has picked this run's Boons. Modelling "expected
/// power" is the only thing a generator *can* do.
abstract final class ClearTimeModel {
  /// Seconds to kill a x1.0 enemy at expected power.
  ///
  /// Two Tier-III arrows at 1.7 shots/second. Sits inside the 0.8–1.6 s TTK
  /// band by construction, which is the point: this constant *is* the TTK Law,
  /// expressed as time.
  static const double secondsPerHpMultiplier = 2 / 1.7;

  /// A plated enemy takes longer, because a player will not always flank and
  /// will not always be at Tier III when the shot lands.
  ///
  /// Not the full armour factor: a Tier-I arrow into a live plate deals 10 %,
  /// which would be a x10 penalty, and no real player plinks a Husk to death at
  /// Tier I. This is the blended cost of the puzzle, not its worst case.
  static const double platedPenalty = 1.45;

  /// Everything that is not shooting: repositioning, dodging telegraphs,
  /// waiting out an airborne Bounder, re-acquiring after a kill.
  static const double engagementOverhead = 1.25;

  /// Seconds lost to each wave transition beyond the first.
  ///
  /// Waves trigger on remaining-enemy thresholds rather than timers
  /// (docs/14 §14.4), so a fast player is rewarded with a faster room — but
  /// there is still a real gap while the next wave's spawn telegraphs resolve.
  static const double waveTransitionSeconds = 1.5;

  /// The acceptance band from docs/14 §14.2.
  static const double minSeconds = 18.0;
  static const double maxSeconds = 55.0;

  /// The upper bound the composer packs against.
  ///
  /// Below [maxSeconds] on purpose. The composer packs greedily and cannot see
  /// the enemy it is about to add, so it must stop short of the ceiling or it
  /// would routinely overshoot and be rejected by its own validator.
  static const double packingTarget = 46.0;

  /// Estimated seconds to clear a set of enemies.
  ///
  /// [waves] beyond the first each add a transition. Pass 1 to price a single
  /// wave in isolation.
  static double secondsFor(
    Iterable<EnemyDefinition> enemies, {
    int waves = 1,
  }) {
    double hp = 0;
    for (final EnemyDefinition enemy in enemies) {
      hp += enemy.hpMultiplier *
          (enemy.hasFrontalPlate ? platedPenalty : 1.0);
    }

    final double fighting = hp * secondsPerHpMultiplier * engagementOverhead;
    final int transitions = waves > 1 ? waves - 1 : 0;
    return fighting + transitions * waveTransitionSeconds;
  }

  /// Seconds one enemy contributes. Used by the composer's packing loop, which
  /// needs to price a candidate before committing to it.
  static double secondsForOne(EnemyDefinition enemy) =>
      enemy.hpMultiplier *
      (enemy.hasFrontalPlate ? platedPenalty : 1.0) *
      secondsPerHpMultiplier *
      engagementOverhead;

  /// Seconds for a room described by content indices.
  static double secondsForIndices(
    ContentLibrary content,
    Iterable<int> indices, {
    int waves = 1,
  }) =>
      secondsFor(
        indices.map((int i) => content.enemies[i]),
        waves: waves,
      );

  static bool isWithinBand(double seconds) =>
      seconds >= minSeconds && seconds <= maxSeconds;
}
