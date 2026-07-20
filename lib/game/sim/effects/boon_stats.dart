import 'dart:typed_data';

import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// The summed contribution of everything the player is carrying.
///
/// One `Float64List` indexed by [StatChannel.index]. Adding a Boon is a handful
/// of `+=`; there is no list of active effects to walk, no per-hit iteration,
/// and no allocation. A twenty-Boon build costs exactly as much to read as an
/// empty one, which is what lets damage resolution stay in the hot path.
///
/// **Additivity is structural, not a convention.** There is no way to express
/// "multiply this channel by another Boon's value" through this class, so
/// docs/04 §4.1 rule 1 cannot be violated by accident. Genuine cross-source
/// multiplication happens one level up, in [LoadoutResolver], where each
/// *source* contributes its own composed term.
class BoonStats {
  BoonStats() : _values = Float64List(StatChannel.values.length) {
    reset();
  }

  final Float64List _values;

  /// Raw summed value on a channel, before any interpretation.
  double operator [](StatChannel channel) => _values[channel.index];

  void add(StatChannel channel, double value) {
    _values[channel.index] += value;
  }

  /// Multiplies a channel by [factor].
  ///
  /// Only meaningful for [StatChannel.isMultiplicative] channels, which rest at
  /// 1.0. Three copies of "Momentum decays 40 % slower" must compose to 1.4³,
  /// not to 1 + 3×0.4 — summing them is wrong in a way that only shows up at
  /// the third copy, which is exactly late enough to ship.
  void multiplyBy(StatChannel channel, double factor) {
    assert(
      channel.isMultiplicative,
      '${channel.name} is a bonus channel; use add()',
    );
    _values[channel.index] *= factor;
  }

  /// Sets a channel to the larger of its current value and [value].
  ///
  /// For channels where two sources should not stack — a hard floor or ceiling
  /// rather than a bonus. Rare, and always a deliberate authoring choice.
  void raiseTo(StatChannel channel, double value) {
    if (value > _values[channel.index]) _values[channel.index] = value;
  }

  /// The channel read as a multiplier.
  ///
  /// Bonus channels read as `1 + sum`; the handful of channels flagged
  /// [StatChannel.isMultiplicative] rest at 1.0 and read as-is. Callers should
  /// use this rather than `1 + stats[c]` so they never have to know which kind
  /// a channel is.
  double multiplierFor(StatChannel channel) =>
      channel.isMultiplicative ? _values[channel.index] : 1.0 + _values[channel.index];

  /// The channel read as a whole number.
  int countFor(StatChannel channel) => _values[channel.index].round();

  /// Clears every channel to its resting value.
  ///
  /// Called at the start of each run, and again whenever the loadout is
  /// recomposed. Multiplicative channels rest at 1.0, everything else at 0.
  void reset() {
    for (final StatChannel channel in StatChannel.values) {
      _values[channel.index] = channel.isMultiplicative ? 1.0 : 0.0;
    }
  }

  /// Copies [other] over this, without allocating.
  void copyFrom(BoonStats other) {
    _values.setAll(0, other._values);
  }

  /// Adds every channel of [other] into this one.
  void addAll(BoonStats other) {
    for (int i = 0; i < _values.length; i++) {
      // Multiplicative channels compose by multiplying, not by summing: two
      // sources that each halve the Draw time should give 0.25x, and summing
      // their 0.5s would give 1.0x — no change at all.
      final StatChannel channel = StatChannel.values[i];
      if (channel.isMultiplicative) {
        _values[i] *= other._values[i];
      } else {
        _values[i] += other._values[i];
      }
    }
  }

  /// Whether anything at all has been contributed. Cheap early-out for the
  /// no-Boons case, which is every run's first room.
  bool get isEmpty {
    for (int i = 0; i < _values.length; i++) {
      final StatChannel channel = StatChannel.values[i];
      final double resting = channel.isMultiplicative ? 1.0 : 0.0;
      if (_values[i] != resting) return false;
    }
    return true;
  }

  /// Debug view. Only non-resting channels, so a build reads at a glance.
  Map<String, double> describe() {
    final Map<String, double> out = <String, double>{};
    for (int i = 0; i < _values.length; i++) {
      final StatChannel channel = StatChannel.values[i];
      final double resting = channel.isMultiplicative ? 1.0 : 0.0;
      if (_values[i] != resting) out[channel.name] = _values[i];
    }
    return out;
  }
}
