import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/game/research/research_catalogue.dart';
import 'package:quiverfall/game/research/research_workshop.dart';
import 'package:test/test.dart';

import 'research_test_support.dart';

/// docs/04 §4.6's Research Lab economy, applied against a [PlayerSave]. See
/// ADR 0093.
void main() {
  late ResearchCatalogue research;
  final DateTime now = DateTime.utc(2026, 3);

  setUpAll(() {
    research = loadResearch();
  });

  PlayerSave freshSave({int accountLevel = 9, int insight = 10000}) =>
      PlayerSave.initial(playerId: 'p1', now: now).copyWith(
        profile: PlayerProfile(accountLevel: accountLevel),
        wallet: Wallet(insight: insight),
      );

  test('fails for an unknown key', () {
    final result = ResearchWorkshop.unlock(freshSave(), research, 'nope');
    expect(result.errorOrNull?.code, 'economy_unknown_research');
  });

  test('fails below account level 9', () {
    final result = ResearchWorkshop.unlock(
        freshSave(accountLevel: 8), research, 'windline_memory');
    expect(result.errorOrNull?.code, 'economy_research_lab_locked');
  });

  test('succeeds at exactly account level 9, spending the exact Insight cost',
      () {
    final save = freshSave(insight: 1000);
    final result = ResearchWorkshop.unlock(save, research, 'windline_memory');
    expect(result.isOk, isTrue);

    final updated = result.valueOrNull!;
    expect(updated.research.completedIds, contains('windline_memory'));
    expect(updated.wallet.insight, 1000 - 220);
    expect(updated.research.insightSpent, 220);
  });

  test('fails with insufficient Insight', () {
    final result = ResearchWorkshop.unlock(
        freshSave(insight: 10), research, 'windline_memory');
    expect(result.errorOrNull?.code, 'economy_insufficient_insight');
  });

  test('refuses to unlock the same item twice', () {
    final once =
        ResearchWorkshop.unlock(freshSave(), research, 'second_loadout')
            .valueOrNull!;
    final twice = ResearchWorkshop.unlock(once, research, 'second_loadout');
    expect(twice.errorOrNull?.code, 'economy_research_already_completed');
  });

  test('the free item (damage-number toggle) still costs nothing but is '
      'still tracked', () {
    final result = ResearchWorkshop.unlock(
        freshSave(insight: 0), research, 'damage_number_toggle');
    expect(result.isOk, isTrue);
    expect(result.valueOrNull!.research.completedIds,
        contains('damage_number_toggle'));
  });
}
