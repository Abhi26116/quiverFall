import 'package:quiverfall/game/balance/curves.dart';

/// docs/02 §2.4: **"The Shrine — 40 – 900 gold, scales with chapter — Buy a
/// Boon, heal 35 %, reroll next Boon set, or gamble."**
///
/// Three of those four actions have a formula here. The fourth — "gamble" — is
/// named once in that one line and nowhere else in the GDD: no odds, no stake,
/// no payout. Rather than invent a mechanic the document never specified,
/// [ShrinePricing] and the Shrine screen it feeds implement the three that are
/// actually specified and leave gambling out, the same way ADR 0002 and ADR
/// 0004 recorded a gap instead of quietly filling it with a guess.
///
/// Every price is driven by [Curves.stageGold] rather than an independent
/// curve, so the Shrine scales with the same economy the rest of the game
/// does instead of drifting away from it as chapters progress. The `[40, 900]`
/// clamp is the one number docs/02 gives directly, and it is what keeps a
/// formula that would otherwise blow past 900 gold by chapter 6 inside the
/// documented band — exact factors are Phase 12 balance-harness territory,
/// same as every other approximate constant in this file's neighbours.
abstract final class ShrinePricing {
  static const double minPrice = 40;
  static const double maxPrice = 900;

  /// Fraction of max HP a heal purchase restores. docs/02 §2.4: "heal 35 %".
  static const double healFraction = 0.35;

  /// Price factors, calibrated against [Curves.stageGold] so the *cheapest*
  /// action starts near [minPrice] at the Shrine's first appearance (chapter
  /// 2, docs/14 §14.2) and the *priciest* reaches [maxPrice] well before the
  /// campaign's end.
  // Deliberately distinct from [healFraction] above — that is the documented
  // 35 % heal amount, this is an invented price-scaling factor, and giving
  // them the same value would read as a copy-paste rather than a coincidence.
  static const double _healFactor = 0.30;
  static const double _rerollFactor = 0.55;
  static const double _boonFactor = 1.10;

  static double healPrice(int chapter, int stage, {double discount = 0}) =>
      _priceFor(chapter, stage, _healFactor, discount);

  static double rerollPrice(int chapter, int stage, {double discount = 0}) =>
      _priceFor(chapter, stage, _rerollFactor, discount);

  static double boonPrice(int chapter, int stage, {double discount = 0}) =>
      _priceFor(chapter, stage, _boonFactor, discount);

  static double _priceFor(
    int chapter,
    int stage,
    double factor,
    double discount,
  ) {
    final double base = Curves.stageGold(chapter, stage) * factor;
    final double clamped =
        base < minPrice ? minPrice : (base > maxPrice ? maxPrice : base);
    // Bargainer (#100) and, later, the Spire's Shrine Favour node both write
    // to this same fraction — see docs/09 §9.2 F and docs/04 §4.2 Wing IV.
    // Clamped so a future stacked discount cannot invert the price.
    final double clampedDiscount = discount < 0 ? 0 : (discount > 1 ? 1 : discount);
    return clamped * (1.0 - clampedDiscount);
  }
}
