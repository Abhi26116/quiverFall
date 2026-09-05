import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/balance/curves.dart';

/// docs/02 §2.6's "expected power" — the loadout the TTK Law is defined
/// against — made concrete enough to build a live [SimWorld] from.
///
/// The GDD names four inputs: "hero at chapter level cap, Spire nodes at the
/// tier band unlocked by that chapter, one crafted arrow of matching tier,
/// and an average Boon draw at room 5." Two of those are exact, not
/// approximations — see the two static members below. Two are genuine gaps
/// this class fills in, both resolved and justified in ADR 0089:
///
/// - **Spire** has no implementation anywhere in `lib/` (it is Phase 13
///   scope). This model contributes none of its stat bonuses. That is a
///   conservative gap, not a silent one: omitting a source of *more* power
///   can only read a *slower* TTK than the real game will have, so a chapter
///   that already passes the hard band under this model stays passing once
///   Phase 13 folds the Spire in.
/// - **Star tier** has no chapter schedule anywhere in the GDD (unlike hero
///   level, which does — [heroLevel] below). [heroStars] floors at the
///   lowest tier a hero can be at all, for the same conservative reason as
///   the Spire.
///
/// "Average Boon draw at room 5" is not modelled here at all — this is the
/// loadout-only half of the harness. See `HarnessBot` for the half that
/// actually plays a stage and accumulates real Boons.
class ExpectedPower {
  const ExpectedPower({
    required this.heroLevel,
    required this.heroStars,
    required this.arrow,
  });

  /// `Curves.heroLevelCap(chaptersCleared)` — already the exact formula
  /// `hero_workshop.dart` enforces as the real level ceiling, so "hero at
  /// chapter level cap" needs no approximation at all: a player who has
  /// cleared chapters 1..c-1 and is now playing chapter [chapter] has
  /// `chaptersCleared = chapter - 1`.
  final int heroLevel;

  /// The lowest star tier a hero can be at ([heroStarsFloor]) — see the class
  /// doc for why this floors rather than schedules.
  final int heroStars;

  /// The arrow this chapter's "one crafted arrow of matching tier" resolves
  /// to. Always at `refineLevel: 0` — see [arrowInstance]: "crafted" is
  /// docs/08's own word for an unrefined copy, so this is exact too, not an
  /// approximation.
  final ArrowArchetype arrow;

  static const int heroStarsFloor = 1;

  /// The chapter boundaries an arrow's [ArrowContentTier] becomes "matching"
  /// at, taken directly from docs/06's own boss-reward material schedule
  /// (chapters 1-2 pay T1 mats, 3-6 pay T2, 7-9 pay T3, 10-12 pay T4) rather
  /// than authored from nothing — see ADR 0089.
  static ArrowArchetype _arrowForChapter(int chapter) {
    if (chapter <= 2) return ArrowArchetype.ashShaft; // T1, the plain shaft.
    if (chapter <= 6) return ArrowArchetype.emberhead; // T2, no plain shaft.
    if (chapter <= 9) return ArrowArchetype.lancehead; // T3, no plain shaft.
    return ArrowArchetype.ghostshaft; // T4, no plain shaft.
  }

  /// The expected-power loadout for campaign [chapter] (1-12).
  factory ExpectedPower.forChapter(int chapter) {
    assert(chapter >= 1 && chapter <= 12,
        'campaign chapters run 1-12, got $chapter');
    return ExpectedPower(
      heroLevel: Curves.heroLevelCap(chapter - 1),
      heroStars: heroStarsFloor,
      arrow: _arrowForChapter(chapter),
    );
  }

  HeroState heroState(String heroId) =>
      HeroState(heroId: heroId, level: heroLevel, stars: heroStars);

  /// `refineLevel: 0` is not a placeholder — docs/08 distinguishes "crafted"
  /// (content unlocked, one copy owned) from refined (the separate I-V axis
  /// on that copy), and the GDD's own phrase is "one **crafted** arrow".
  ArrowInstance arrowInstance(String arrowId) =>
      ArrowInstance(arrowId: arrowId, crafted: true);
}
