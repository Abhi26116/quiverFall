import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/ascension/ascension_workshop.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:test/test.dart';

/// docs/04 §4.7 — the Ascension gate, reset, and Emberdust award. See
/// ADR 0094.
void main() {
  final DateTime now = DateTime.utc(2026, 3);

  PlayerSave freshSave({
    int currentChapter = 11,
    int accountLevel = 40,
    int gold = 5000,
    int insight = 300,
    int gems = 200,
    int ascensionCount = 0,
    int highestChapterEver = 0,
  }) =>
      PlayerSave.initial(playerId: 'p1', now: now).copyWith(
        campaign: CampaignState(currentChapter: currentChapter),
        profile: PlayerProfile(accountLevel: accountLevel),
        wallet: Wallet(gold: gold, insight: insight, gems: gems),
        ascension: AscensionState(
          count: ascensionCount,
          highestChapterEver: highestChapterEver,
        ),
        spire: const SpireState(nodeLevels: {'1': 50, '7': 30}),
      );

  test('fails at or before chapter 10', () {
    final result = AscensionWorkshop.ascend(
        freshSave(currentChapter: 10), now: now);
    expect(result.errorOrNull?.code, 'economy_ascension_chapter_not_cleared');
  });

  test('fails below account level 40', () {
    final result = AscensionWorkshop.ascend(
        freshSave(accountLevel: 39), now: now);
    expect(
        result.errorOrNull?.code, 'economy_ascension_account_level_too_low');
  });

  test('succeeds at chapter 11, account level 40', () {
    final result = AscensionWorkshop.ascend(freshSave(), now: now);
    expect(result.isOk, isTrue);
  });

  test('resets Spire node levels and banked gold', () {
    final updated =
        AscensionWorkshop.ascend(freshSave(gold: 12345), now: now)
            .valueOrNull!;
    expect(updated.spire.nodeLevels, isEmpty);
    expect(updated.wallet.gold, 0);
  });

  test('resets campaign position to chapter 1, stage 1', () {
    final updated = AscensionWorkshop.ascend(
      freshSave(currentChapter: 14),
      now: now,
    ).valueOrNull!;
    expect(updated.campaign.currentChapter, 1);
    expect(updated.campaign.currentStage, 1);
  });

  test('awards Emberdust via the exact Curves.emberdustFor formula', () {
    final updated = AscensionWorkshop.ascend(
      freshSave(currentChapter: 14, ascensionCount: 2),
      now: now,
    ).valueOrNull!;
    final int expected = Curves.emberdustFor(14, 2);
    expect(expected, greaterThan(0));
    expect(updated.wallet.emberdust, expected);
  });

  test('emberdust adds to, rather than replaces, an existing balance', () {
    final save = freshSave(currentChapter: 14).copyWith(
      wallet: freshSave(currentChapter: 14).wallet.copyWith(emberdust: 500),
    );
    final updated = AscensionWorkshop.ascend(save, now: now).valueOrNull!;
    expect(updated.wallet.emberdust, 500 + Curves.emberdustFor(14, 0));
  });

  test('increments the ascension count and records the timestamp', () {
    final updated = AscensionWorkshop.ascend(
      freshSave(ascensionCount: 3),
      now: now,
    ).valueOrNull!;
    expect(updated.ascension.count, 4);
    expect(updated.ascension.lastAscendedAt, now);
  });

  test('highestChapterEver tracks the true lifetime peak, not just this run',
      () {
    // A player already peaked at chapter 20 in a prior cycle, and is
    // ascending now from a lower chapter (14) - the award and the stored
    // peak must both use 20, not silently regress to 14.
    final save = freshSave(currentChapter: 14, highestChapterEver: 20);
    final updated = AscensionWorkshop.ascend(save, now: now).valueOrNull!;

    expect(updated.ascension.highestChapterEver, 20);
    expect(updated.wallet.emberdust, Curves.emberdustFor(20, 0));
  });

  test('highestChapterEver rises when this run set a new peak', () {
    final save = freshSave(currentChapter: 25, highestChapterEver: 20);
    final updated = AscensionWorkshop.ascend(save, now: now).valueOrNull!;
    expect(updated.ascension.highestChapterEver, 25);
  });

  test('never resets: heroes, arrows, Insight, gems, account level', () {
    final save = freshSave().copyWith(
      heroes: const {'wren': HeroState(heroId: 'wren', unlocked: true, stars: 3)},
    );
    final updated = AscensionWorkshop.ascend(save, now: now).valueOrNull!;

    expect(updated.heroes['wren']?.stars, 3);
    expect(updated.inventory, save.inventory);
    expect(updated.wallet.insight, save.wallet.insight);
    expect(updated.wallet.gems, save.wallet.gems);
    expect(updated.profile.accountLevel, save.profile.accountLevel);
  });

  test('the Emberdust tree itself (emberdustRanks) never resets', () {
    final save = freshSave().copyWith(
      ascension: freshSave().ascension.copyWith(
          emberdustRanks: const {'cinder': 10}),
    );
    final updated = AscensionWorkshop.ascend(save, now: now).valueOrNull!;
    expect(updated.ascension.emberdustRanks, {'cinder': 10});
  });
}
