import 'package:meta/meta.dart';

/// Deterministic, seedable random number generator.
///
/// Quiverfall does not use `dart:math`'s [Random]. Its algorithm is not
/// specified, so it is not guaranteed to produce identical sequences across
/// Dart versions or platforms — which would silently break run replays, the
/// balance harness, and the weekly-seeded Endless Descent ladder where every
/// player must descend the identical sequence.
///
/// This is xorshift128+, chosen because it is fast, has a long period
/// (2^128 - 1), passes BigCrush, and is trivially reimplementable if we ever
/// need to validate a run server-side.
///
/// See [docs/12-architecture.md] §12.0.
final class Rng {
  /// Creates a generator from a 64-bit seed.
  factory Rng(int seed) {
    // SplitMix64 is used to expand a single seed into the two 64-bit words of
    // xorshift128+ state. Seeding both words from the raw seed directly would
    // give poor results for small seeds (e.g. 0, 1, 2), which are exactly the
    // seeds tests use.
    int z = seed;
    int next() {
      z = (z + 0x9E3779B97F4A7C15) & _mask64;
      int result = z;
      result = ((result ^ (result >>> 30)) * 0xBF58476D1CE4E5B9) & _mask64;
      result = ((result ^ (result >>> 27)) * 0x94D049BB133111EB) & _mask64;
      return (result ^ (result >>> 31)) & _mask64;
    }

    int s0 = next();
    int s1 = next();
    // xorshift128+ must never be seeded with all-zero state.
    if (s0 == 0 && s1 == 0) {
      s0 = 0x9E3779B97F4A7C15;
      s1 = 0xBF58476D1CE4E5B9;
    }
    return Rng._(s0, s1);
  }

  Rng._(this._s0, this._s1);

  /// Restores a generator from a previously captured [state].
  factory Rng.fromState(RngState state) => Rng._(state.s0, state.s1);

  /// All-ones 64-bit pattern. Note this equals `-1` when read as a signed int —
  /// it is only ever used as a bitmask, never in arithmetic comparisons.
  static const int _mask64 = 0xFFFFFFFFFFFFFFFF;

  /// `2^63 - 1`. The largest representable positive int, and the upper bound of
  /// `nextInt64() >>> 1`.
  static const int _maxPositive = 0x7FFFFFFFFFFFFFFF;

  static const int _mask53 = 0x1FFFFFFFFFFFFF;

  int _s0;
  int _s1;

  /// Captures the generator's exact position so a run can be resumed or
  /// replayed from mid-stream.
  RngState get state => RngState(_s0, _s1);

  /// Next raw 64-bit value.
  int nextInt64() {
    int s1 = _s0;
    final int s0 = _s1;
    _s0 = s0;
    s1 ^= (s1 << 23) & _mask64;
    _s1 = (s1 ^ s0 ^ (s1 >>> 18) ^ (s0 >>> 5)) & _mask64;
    return (_s1 + s0) & _mask64;
  }

  /// Uniform integer in `[0, max)`.
  ///
  /// Uses rejection sampling rather than a plain modulo, because modulo
  /// introduces bias that is small but real — and in a game where Boon rarity
  /// weights and loot pity are audited, biased draws are a correctness bug.
  ///
  /// **Everything here works in the non-negative half of the range.** Dart ints
  /// are signed 64-bit, so `0xFFFFFFFFFFFFFFFF` is `-1`, not `2^64 - 1`. Doing
  /// the bias arithmetic on the raw 64-bit value yields a negative threshold and
  /// an infinite rejection loop. `nextInt64() >>> 1` gives a value in
  /// `[0, 2^63 - 1]`, and the bounds below stay representable.
  int nextInt(int max) {
    assert(max > 0, 'max must be positive, got $max');
    if (max & (max - 1) == 0) {
      // Power of two: mask directly, no bias possible.
      return (nextInt64() >>> 1) & (max - 1);
    }

    // Number of candidate values is 2^63, which is not representable, so the
    // remainder is derived from `2^63 - 1` instead.
    final int remainder = ((_maxPositive % max) + 1) % max;
    if (remainder == 0) {
      // 2^63 divides evenly by max — no bias to correct.
      return (nextInt64() >>> 1) % max;
    }

    // Largest multiple of `max` that fits in [0, 2^63). Always <= _maxPositive.
    final int threshold = _maxPositive - remainder + 1;
    int value;
    do {
      value = nextInt64() >>> 1;
    } while (value >= threshold);
    return value % max;
  }

  /// Uniform integer in `[min, max)`.
  int nextIntRange(int min, int max) {
    assert(max > min, 'max ($max) must exceed min ($min)');
    return min + nextInt(max - min);
  }

  /// Uniform double in `[0, 1)`.
  double nextDouble() => (nextInt64() >>> 11) / (_mask53 + 1);

  /// Uniform double in `[min, max)`.
  double nextDoubleRange(double min, double max) =>
      min + nextDouble() * (max - min);

  /// True with the given [probability] in `[0, 1]`.
  bool chance(double probability) {
    if (probability <= 0) return false;
    if (probability >= 1) return true;
    return nextDouble() < probability;
  }

  /// Uniformly picks one element of [items].
  T pick<T>(List<T> items) {
    assert(items.isNotEmpty, 'cannot pick from an empty list');
    return items[nextInt(items.length)];
  }

  /// Picks an index according to [weights].
  ///
  /// This is the primitive behind Boon rarity draws, loot tables, and enemy
  /// composition, so it is kept allocation-free.
  int pickWeightedIndex(List<double> weights) {
    assert(weights.isNotEmpty, 'cannot pick from empty weights');
    double total = 0;
    for (int i = 0; i < weights.length; i++) {
      assert(weights[i] >= 0, 'weights must be non-negative');
      total += weights[i];
    }
    assert(total > 0, 'weights must sum to more than zero');

    double roll = nextDouble() * total;
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return weights.length - 1;
  }

  /// In-place Fisher-Yates shuffle.
  void shuffle<T>(List<T> items) {
    for (int i = items.length - 1; i > 0; i--) {
      final int j = nextInt(i + 1);
      final T tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }

  /// Derives an independent child generator.
  ///
  /// Used to give each subsystem its own stream from one run seed, so that (for
  /// example) drawing an extra Boon does not shift the enemy composition of a
  /// later room. Without this, any change to one system's consumption silently
  /// reshuffles every other system.
  Rng split(int label) => Rng(nextInt64() ^ (label * 0x9E3779B97F4A7C15));
}

/// A snapshot of an [Rng]'s internal position.
@immutable
final class RngState {
  const RngState(this.s0, this.s1);

  factory RngState.fromJson(Map<String, dynamic> json) => RngState(
        (json['s0'] as num).toInt(),
        (json['s1'] as num).toInt(),
      );

  final int s0;
  final int s1;

  Map<String, dynamic> toJson() => <String, dynamic>{'s0': s0, 's1': s1};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RngState && other.s0 == s0 && other.s1 == s1);

  @override
  int get hashCode => Object.hash(s0, s1);

  @override
  String toString() => 'RngState($s0, $s1)';
}
