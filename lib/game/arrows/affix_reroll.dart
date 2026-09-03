import 'dart:math' as math;

/// docs/08 §8.4 / docs/02 §2.11 rule 4: "Rerolling a single affix costs
/// 1,200 gold, +15 % per reroll in the same session" — the escalating sink
/// that gives surplus gold an uncapped drain scaling with how rich the
/// player is.
abstract final class AffixReroll {
  static const int baseGoldCost = 1200;
  static const double _growth = 1.15;

  /// Gold cost of the *next* reroll, given [rerollCountThisSession] rerolls
  /// already spent this session (`InventoryState.rerollCountThisSession`).
  static int goldCost(int rerollCountThisSession) {
    assert(rerollCountThisSession >= 0);
    return (baseGoldCost * math.pow(_growth, rerollCountThisSession)).round();
  }
}
