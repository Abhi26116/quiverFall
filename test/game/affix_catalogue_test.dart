import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/affix_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/effects/affix_behaviour.dart';
import 'package:test/test.dart';

import 'affix_test_support.dart';

/// docs/08 §8.4's own affix table — see ADR 0012 for why this is 17
/// entries, not the doc's own stated 18.
void main() {
  late AffixCatalogue catalogue;

  setUpAll(() {
    catalogue = loadAffixes();
  });

  group('the catalogue matches docs/08 §8.4', () {
    test('there are 17 affixes, one per archetype', () {
      expect(catalogue.length, AffixCatalogue.expectedCount);
      for (final AffixArchetype archetype in AffixArchetype.values) {
        expect(catalogue.byArchetype(archetype), isNotNull,
            reason: '${archetype.name} has no catalogue entry');
      }
    });

    test('every affix has readable card text and a real roll range', () {
      for (final AffixDefinition a in catalogue.all) {
        expect(a.name.trim(), isNotEmpty, reason: a.key);
        expect(a.description.trim(), isNotEmpty, reason: a.key);
        expect(a.minValue, lessThanOrEqualTo(a.maxValue), reason: a.key);
      }
    });

    test('exactly one of channel or behaviour is set, never both', () {
      for (final AffixDefinition a in catalogue.all) {
        expect(a.channel == null, isNot(a.behaviour == null), reason: a.key);
      }
    });

    test('rarity counts: 5 common, 9 rare, 3 epic', () {
      int common = 0, rare = 0, epic = 0;
      for (final AffixDefinition a in catalogue.all) {
        switch (a.rarity) {
          case AffixRarity.common:
            common++;
          case AffixRarity.rare:
            rare++;
          case AffixRarity.epic:
            epic++;
        }
      }
      expect(common, 5);
      expect(rare, 9);
      expect(epic, 3);
    });

    test('the four elemental affixes each roll into a distinct element channel',
        () {
      const Map<String, String> expected = <String, String>{
        'kindled': 'emberDamage',
        'rimed': 'frostEffect',
        'charged': 'stormDamage',
        'blighted': 'toxinDamage',
      };
      for (final MapEntry<String, String> e in expected.entries) {
        expect(catalogue.byKey(e.key)!.channel?.name, e.value, reason: e.key);
      }
    });

    test('Piercing and Threaded are flat values — min equals max', () {
      for (final String key in <String>['piercing', 'threaded']) {
        final AffixDefinition a = catalogue.byKey(key)!;
        expect(a.minValue, a.maxValue, reason: key);
      }
    });

    test('Echoing is the one behaviour affix, and rolls a real chance range',
        () {
      final AffixDefinition echoing = catalogue.byKey('echoing')!;
      expect(echoing.behaviour, AffixBehaviour.echoing);
      expect(echoing.channel, isNull);
      expect(echoing.minValue, greaterThan(0));
      expect(echoing.maxValue, lessThan(1.0));
    });
  });

  group('no card is a blank', () {
    test('every declared AffixBehaviour is referenced by some affix', () {
      final Set<AffixBehaviour> used = catalogue.all
          .map((AffixDefinition a) => a.behaviour)
          .whereType<AffixBehaviour>()
          .toSet();
      final Iterable<AffixBehaviour> orphans = AffixBehaviour.values
          .where((AffixBehaviour b) => !used.contains(b));
      expect(orphans, isEmpty,
          reason: 'declared but granted by no affix: '
              '${orphans.map((AffixBehaviour b) => b.name).join(', ')}');
    });
  });

  group('parse rejects bad content', () {
    test('neither channel nor behaviour set is an error', () {
      const String json = '''
{"affixes": [{
  "archetype": "sharpened", "key": "t", "name": "T", "rarity": "common",
  "description": "d", "minValue": 0.04, "maxValue": 0.09
}]}''';
      final (AffixCatalogue?, List<ContentError>) r = AffixCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('exactly one of channel or behaviour'));
    });

    test('both channel and behaviour set is an error', () {
      const String json = '''
{"affixes": [{
  "archetype": "sharpened", "key": "t", "name": "T", "rarity": "common",
  "description": "d", "channel": "damage", "behaviour": "echoing",
  "minValue": 0.04, "maxValue": 0.09
}]}''';
      final (AffixCatalogue?, List<ContentError>) r = AffixCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('exactly one of channel or behaviour'));
    });

    test('maxValue below minValue is an error', () {
      const String json = '''
{"affixes": [{
  "archetype": "sharpened", "key": "t", "name": "T", "rarity": "common",
  "description": "d", "channel": "damage", "minValue": 0.09, "maxValue": 0.04
}]}''';
      final (AffixCatalogue?, List<ContentError>) r = AffixCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('must be >= minValue'));
    });
  });
}
