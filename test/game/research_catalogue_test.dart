import 'package:quiverfall/game/research/research_catalogue.dart';
import 'package:quiverfall/game/research/research_definition.dart';
import 'package:test/test.dart';

import 'research_test_support.dart';

/// docs/04-upgrades.md §4.6: 12 Research Lab items (Branches B and C). See
/// ADR 0093.
void main() {
  late ResearchCatalogue research;

  setUpAll(() {
    research = loadResearch();
  });

  test('has exactly 12 items, ids 1-12 with no gaps', () {
    expect(research.length, 12);
    final List<int> ids = research.all.map((d) => d.id).toList()..sort();
    expect(ids, List<int>.generate(12, (i) => i + 1));
  });

  test('every item is reachable by id, key, and archetype', () {
    for (final d in research.all) {
      expect(research.byId(d.id), same(d));
      expect(research.byKey(d.key), same(d));
      expect(research.byArchetype(d.archetype), same(d));
    }
  });

  test('7 systemic + 5 quality-of-life, Branch A never a discrete item', () {
    expect(
      research.all.where((d) => d.branch == ResearchBranch.systemic).length,
      7,
    );
    expect(
      research.all
          .where((d) => d.branch == ResearchBranch.qualityOfLife)
          .length,
      5,
    );
    expect(
      research.all.where((d) => d.branch == ResearchBranch.tierGates),
      isEmpty,
    );
  });

  test('Insight costs match docs/04\'s own table', () {
    const Map<ResearchArchetype, int> expectedCost = {
      ResearchArchetype.secondLoadout: 60,
      ResearchArchetype.boonBanking: 120,
      ResearchArchetype.shrineLedger: 150,
      ResearchArchetype.windlineMemory: 220,
      ResearchArchetype.doubleDraw: 400,
      ResearchArchetype.elementalCodex: 300,
      ResearchArchetype.deepDescent: 500,
      ResearchArchetype.autoClaimChests: 30,
      ResearchArchetype.skipRunIntro: 20,
      ResearchArchetype.damageNumberToggle: 0,
      ResearchArchetype.extraVigorNotification: 25,
      ResearchArchetype.combatLog: 40,
    };
    for (final entry in expectedCost.entries) {
      expect(research.byArchetype(entry.key)!.insightCost, entry.value,
          reason: entry.key.name);
    }
  });

  test('Windline Memory and Second Loadout are implemented; the other ten '
      'are deferred with a balance note', () {
    expect(
        research.byArchetype(ResearchArchetype.windlineMemory)!.implemented,
        isTrue);
    expect(research.byArchetype(ResearchArchetype.secondLoadout)!.implemented,
        isTrue);

    final deferred = research.all.where((d) => !d.implemented).toList();
    expect(deferred, hasLength(10));
    for (final d in deferred) {
      expect(d.balanceNote, isNotEmpty, reason: d.name);
    }
  });
}
