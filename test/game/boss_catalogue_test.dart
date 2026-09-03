import 'package:quiverfall/game/content/boss_catalogue.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The boss catalogue is content, the same posture `hero_catalogue_test.dart`
/// takes toward `heroes.json`: this file is the data half of Phase 11's own
/// roadmap line ("12 campaign bosses... 4 elite/event... 4 Endless"), that
/// `bosses.json` matches docs/06 exactly. Each boss's own fight — what its
/// phases actually do — gets its own test file alongside its implementation,
/// the same split `hero_behaviour_test.dart` draws for heroes.
void main() {
  late BossCatalogue catalogue;

  setUpAll(() {
    catalogue = loadBosses();
  });

  group('the catalogue matches docs/06', () {
    test('there are 20 bosses, one per archetype', () {
      expect(catalogue.length, BossCatalogue.expectedCount);
      for (final BossArchetype a in BossArchetype.values) {
        expect(catalogue.byArchetype(a), isNotNull,
            reason: '${a.name} has no catalogue entry');
        expect(catalogue.indexOfArchetype(a), greaterThanOrEqualTo(0));
      }
    });

    test('12 campaign bosses cover chapters 1-12 exactly once', () {
      final List<BossDefinition> campaign = catalogue.all
          .where((BossDefinition b) => b.tier == BossTier.campaign)
          .toList();
      expect(campaign, hasLength(12));
      final List<int> chapters = campaign
          .map((BossDefinition b) => b.chapter!)
          .toList()
        ..sort();
      expect(chapters, List<int>.generate(12, (int i) => i + 1));
    });

    test('tier counts match docs/06 §6.2/§6.3: 1 elite, 3 event, 4 endless',
        () {
      const Map<BossTier, int> expected = <BossTier, int>{
        BossTier.campaign: 12,
        BossTier.elite: 1,
        BossTier.event: 3,
        BossTier.endless: 4,
      };
      for (final MapEntry<BossTier, int> e in expected.entries) {
        final int actual =
            catalogue.all.where((BossDefinition b) => b.tier == e.key).length;
        expect(actual, e.value, reason: e.key.name);
      }
    });

    test('non-campaign bosses carry no chapter', () {
      for (final BossDefinition b in catalogue.all) {
        if (b.tier != BossTier.campaign) {
          expect(b.chapter, isNull, reason: b.id);
        }
      }
    });

    test('spot-checks docs/06\'s own stated numbers', () {
      final BossDefinition cinderChoir =
          catalogue.byArchetype(BossArchetype.cinderChoir)!;
      expect(cinderChoir.hpMultiplier, 22);
      expect(cinderChoir.targetDurationSeconds, 55);
      expect(cinderChoir.phaseCount, 3);

      final BossDefinition quiverfall =
          catalogue.byArchetype(BossArchetype.quiverfall)!;
      expect(quiverfall.hpMultiplier, 90);
      expect(quiverfall.targetDurationSeconds, 110);

      final BossDefinition lastWarden =
          catalogue.byArchetype(BossArchetype.lastWarden)!;
      expect(lastWarden.hpMultiplier, 140);
      expect(lastWarden.targetDurationSeconds, 150);
      // docs/06 §6.3: "Five phases, not three."
      expect(lastWarden.phaseCount, 5);
    });

    test('every boss\'s thresholds are strictly descending and in (0, 1)',
        () {
      for (final BossDefinition b in catalogue.all) {
        double previous = 1.0;
        for (final double t in b.phaseThresholds) {
          expect(t, greaterThan(0), reason: b.id);
          expect(t, lessThan(previous), reason: b.id);
          previous = t;
        }
        // docs/06 §6.0 rule 1: three phases minimum, i.e. at least 2
        // thresholds.
        expect(b.phaseThresholds.length, greaterThanOrEqualTo(2),
            reason: b.id);
      }
    });

    test('every boss has a positive HP multiplier', () {
      for (final BossDefinition b in catalogue.all) {
        expect(b.hpMultiplier, greaterThan(0), reason: b.id);
      }
    });
  });

  group('parse rejects bad content', () {
    test('a duplicate id is an error', () {
      final String json = _twoBosses(
        idB: 'cinderChoir',
      );
      final (BossCatalogue?, List<ContentError>) r = BossCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('duplicate id'));
    });

    test('non-descending thresholds are rejected', () {
      final String json = _oneBoss(
        thresholds: '[0.33, 0.66]',
      );
      final (BossCatalogue?, List<ContentError>) r = BossCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('strictly descending'));
    });

    test('an unknown tier is rejected rather than dropped', () {
      final String json = _oneBoss(tier: 'legendary');
      final (BossCatalogue?, List<ContentError>) r = BossCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('unknown tier'));
    });

    test('an unknown archetype id is rejected rather than dropped', () {
      final String json = _oneBoss(id: 'totallyMadeUp');
      final (BossCatalogue?, List<ContentError>) r = BossCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('unknown boss id'));
    });

    test('a campaign boss with no chapter is an error', () {
      final String json = _oneBoss(chapter: null);
      final (BossCatalogue?, List<ContentError>) r = BossCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('no chapter'));
    });
  });
}

String _oneBoss({
  String id = 'cinderChoir',
  String tier = 'campaign',
  Object? chapter = 1,
  String thresholds = '[0.66, 0.33]',
}) {
  final String chapterField = chapter == null ? '' : '"chapter": $chapter,';
  return '''
{"bosses": [{
  "id": "$id", "name": "N", "tier": "$tier", $chapterField
  "hpMultiplier": 22, "targetDurationSeconds": 55,
  "phaseThresholds": $thresholds
}]}''';
}

String _twoBosses({required String idB}) => '''
{"bosses": [
  {"id": "cinderChoir", "name": "A", "tier": "campaign", "chapter": 1,
   "hpMultiplier": 22, "targetDurationSeconds": 55,
   "phaseThresholds": [0.66, 0.33]},
  {"id": "$idB", "name": "B", "tier": "campaign", "chapter": 2,
   "hpMultiplier": 30, "targetDurationSeconds": 60,
   "phaseThresholds": [0.66, 0.33]}
]}''';
