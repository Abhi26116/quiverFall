import 'dart:math' as math;

/// Every balance curve in the game, in one pure-Dart place.
///
/// These are the formulas from the GDD, not approximations of them. The balance
/// harness (Phase 12) sweeps these directly, and the TTK Law is asserted against
/// them in CI — so a change here is a change the tests will argue with, which is
/// the intent.
///
/// Sources: docs/02-economy.md §2.3 and §2.6, docs/06-bosses.md §6.4,
/// docs/14-level-design.md §14.2.
abstract final class Curves {
  // ── Enemy health ──────────────────────────────────────────────────────────

  static const double baseEnemyHp = 44.0;

  /// Growth per stage for chapters 1–4.
  static const double earlyGrowth = 1.072;

  /// Growth per stage for chapters 5+.
  static const double lateGrowth = 1.054;

  /// Global stage index at which growth steps down (end of chapter 4).
  static const int growthStepIndex = 80;

  /// Common-enemy HP at global stage index [g] (1-based).
  ///
  /// The step-down at chapter 5 is deliberate and load-bearing. Early chapters
  /// need to *feel* like fast power gain; late chapters need a curve flat enough
  /// that a session's worth of Spire levels is still perceptible. Without the
  /// step, late-game upgrades feel like nothing, which docs/02 §2.6 identifies
  /// as the single most common late-game churn cause in this category.
  static double enemyHp(int g) {
    assert(g >= 1, 'global stage index is 1-based, got $g');
    if (g <= growthStepIndex) {
      return baseEnemyHp * math.pow(earlyGrowth, g - 1).toDouble();
    }
    final double atStep =
        baseEnemyHp * math.pow(earlyGrowth, growthStepIndex - 1).toDouble();
    return atStep * math.pow(lateGrowth, g - growthStepIndex).toDouble();
  }

  // ── Threat budget ─────────────────────────────────────────────────────────

  static const double baseThreatBudget = 100.0;
  static const double threatGrowth = 1.04;

  /// How much enemy the room generator may spend at global stage [g].
  ///
  /// Difficulty is delivered by density and composition, not by HP inflation —
  /// see the TTK Law (Design Law 1).
  static double threatBudget(int g) =>
      baseThreatBudget * math.pow(threatGrowth, g - 1).toDouble();

  // ── Gold ──────────────────────────────────────────────────────────────────

  static const double baseGold = 110.0;
  static const double goldChapterGrowth = 1.26;

  /// Full-clear gold for chapter [c], stage [s].
  ///
  /// Variance is applied by the caller from the run's seeded RNG, and shown to
  /// the player as the "haul" number rather than hidden.
  static double stageGold(int c, int s) =>
      baseGold * math.pow(goldChapterGrowth, c - 1).toDouble() *
      (1 + 0.02 * (s - 1));

  /// Payout for dying partway through.
  ///
  /// **There is no zero-reward run.** The 0.7 factor is the entire penalty for
  /// dying, and it is small on purpose — see docs/10-ui-ux.md §10.9. This is
  /// what lets Quiverfall have permadeath runs without the churn that usually
  /// comes with them.
  static double partialGold(int c, int s, int roomsCleared, int totalRooms) {
    assert(totalRooms > 0);
    if (roomsCleared <= 0) return 0;
    return stageGold(c, s) / totalRooms * roomsCleared * 0.7;
  }

  /// Hard ceiling on stacked gold multipliers. Enforced in code, not by
  /// convention — docs/02 §2.3.
  static const double maxGoldMultiplier = 6.0;

  static double clampGoldMultiplier(double m) =>
      m > maxGoldMultiplier ? maxGoldMultiplier : m;

  // ── Spire ─────────────────────────────────────────────────────────────────

  static const double spireCostGrowth = 1.145;

  /// Cost of buying level [n] (1-based) of a node with the given [base].
  static double spireNodeCost(double base, int n) =>
      base * math.pow(spireCostGrowth, n - 1).toDouble();

  /// Total cost of levels 1..[n].
  static double spireCumulativeCost(double base, int n) {
    if (n <= 0) return 0;
    // Geometric series, closed form — the harness calls this in inner loops.
    return base *
        (math.pow(spireCostGrowth, n).toDouble() - 1) /
        (spireCostGrowth - 1);
  }

  // ── Heroes ────────────────────────────────────────────────────────────────

  static const double heroLevelCostBase = 90.0;
  static const double heroLevelCostGrowth = 1.11;
  static const double heroStatPerLevel = 0.085;
  static const double heroStatPerStar = 0.12;

  static double heroLevelCost(int level) =>
      heroLevelCostBase * math.pow(heroLevelCostGrowth, level - 1).toDouble();

  /// Hero stat at a given level and star tier, from its level-1 value.
  static double heroStat(double statAtL1, int level, int stars) =>
      statAtL1 *
      (1 + heroStatPerLevel * (level - 1)) *
      (1 + heroStatPerStar * stars);

  /// Level cap rises 8 per chapter cleared, so hero levelling can never outrun
  /// campaign progress and become a gold dump with no purpose.
  static int heroLevelCap(int chaptersCleared) => 8 * (chaptersCleared + 1);

  // ── Bosses ────────────────────────────────────────────────────────────────

  /// Boss HP. [multiplier] is the per-boss value from docs/06.
  ///
  /// [encounterCount] is how many times this player has already killed this
  /// boss: repeat kills get 6% harder each time, so farming a known boss stays
  /// engaging rather than becoming free. Boss *damage* never scales — bosses get
  /// tougher, never cheaper.
  static double bossHp(int g, double multiplier, int encounterCount) =>
      enemyHp(g) * multiplier * (1 + 0.06 * encounterCount);

  // ── Endless Descent ───────────────────────────────────────────────────────

  static const double endlessHpGrowth = 1.09;
  static const double endlessThreatGrowth = 1.05;

  static double endlessHp(int floor) =>
      enemyHp(240) * math.pow(endlessHpGrowth, floor).toDouble();

  // ── Ascension ─────────────────────────────────────────────────────────────

  /// Emberdust awarded for ascending at [highestChapter].
  ///
  /// Super-linear in chapter, so "ascend now or push two more chapters" is a
  /// real decision every cycle — the same push-or-bank tension as the Shrine,
  /// at a three-week scale.
  static int emberdustFor(int highestChapter, int ascensionCount) {
    if (highestChapter <= 8) return 0;
    final double raw = 12 *
        math.pow(highestChapter - 8, 1.35).toDouble() *
        (1 + 0.08 * ascensionCount);
    return raw.floor();
  }

  // ── Vigor ─────────────────────────────────────────────────────────────────

  static const int vigorRegenMinutes = 6;

  /// Vigor accrued over [elapsed]. Caller clamps to the player's max.
  static int vigorRegenerated(Duration elapsed) =>
      elapsed.inMinutes ~/ vigorRegenMinutes;

  // ── TTK Law (Design Law 1) ────────────────────────────────────────────────

  /// A common enemy must die within this band at every point in the game, for a
  /// correctly-progressed player. Every other curve is derived from it, and the
  /// balance harness fails CI when the p10–p90 band escapes [ttkHardMin],
  /// [ttkHardMax].
  static const double ttkTargetMin = 0.8;
  static const double ttkTargetMax = 1.6;
  static const double ttkHardMin = 0.6;
  static const double ttkHardMax = 2.2;

  static bool ttkWithinTarget(double seconds) =>
      seconds >= ttkTargetMin && seconds <= ttkTargetMax;

  static bool ttkWithinHardBounds(double seconds) =>
      seconds >= ttkHardMin && seconds <= ttkHardMax;
}
