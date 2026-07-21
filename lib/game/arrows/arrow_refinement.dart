import 'dart:math' as math;

/// docs/08-arrows.md §8.4's refinement table, exact formula plus the effects
/// it buys.
///
/// Refine levels are 0-indexed here (0 = "I", the unrefined starting state,
/// matching `ArrowInstance.refineLevel`'s own default of 0) even though
/// docs/08 writes them as roman numerals I–V. `t` in the cost formula is the
/// refine being bought — going from I to II is `t = 1`.
abstract final class ArrowRefinement {
  static const int maxLevel = 4; // "V", the highest refine.

  static const double _costBase = 800.0;
  static const double _costGrowth = 4.2;

  /// Gold cost to refine from [level] to [level] + 1.
  ///
  /// `refineCost(t) = 800 · 4.2^(t-1)` from docs/08 §8.4, with `t` the
  /// 1-indexed refine step (I→II is t=1). The doc's own table rounds the
  /// result (14,100 rather than 14,112 for III→IV) for display; this is the
  /// unrounded formula, which is what the game actually charges.
  static int goldCost(int level) {
    assert(level >= 0 && level < maxLevel, 'no refine step from $level');
    final int t = level + 1;
    return (_costBase * math.pow(_costGrowth, t - 1)).round();
  }

  /// Materials required for the same step, all of one tier.
  ///
  /// `3·t materials of tier ceil(t·0.8)` — docs/08 §8.4.
  static int materialCount(int level) {
    assert(level >= 0 && level < maxLevel);
    final int t = level + 1;
    return 3 * t;
  }

  static int materialTier(int level) {
    assert(level >= 0 && level < maxLevel);
    final int t = level + 1;
    return (t * 0.8).ceil();
  }

  /// `baseMult` bonus at [level], cumulative from the unrefined arrow.
  /// docs/08 §8.4: I is the base (no bonus), II is +8 %, III +17 %, IV +27 %,
  /// V +40 %.
  static const List<double> _baseMultBonus = <double>[0, 0.08, 0.17, 0.27, 0.40];

  static double baseMultMultiplier(int level) {
    assert(level >= 0 && level <= maxLevel);
    return 1.0 + _baseMultBonus[level];
  }

  /// Affix slots unlocked at [level]. docs/08 §8.4: I has none, II through V
  /// add one each.
  static int affixSlots(int level) {
    assert(level >= 0 && level <= maxLevel);
    return level;
  }

  /// Total gold to go from 0 (unrefined) to [level].
  static int cumulativeGoldCost(int level) {
    assert(level >= 0 && level <= maxLevel);
    int total = 0;
    for (int i = 0; i < level; i++) {
      total += goldCost(i);
    }
    return total;
  }
}
