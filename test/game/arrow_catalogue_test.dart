import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/effects/arrow_behaviour.dart';
import 'package:test/test.dart';

import 'arrow_test_support.dart';

/// docs/20 Phase 10's exit criterion: "all 12 arrows craftable and
/// refinable." This is the craftable half — that the 12 arrows match docs/08
/// exactly and none of them is a blank. Refinement is Task #5's own test file.
void main() {
  late ArrowCatalogue catalogue;

  setUpAll(() {
    catalogue = loadArrows();
  });

  group('the catalogue matches docs/08 §8.3', () {
    test('there are 12 arrows, numbered 1 to 12, one per archetype', () {
      expect(catalogue.length, ArrowCatalogue.expectedCount);
      for (int id = 1; id <= ArrowCatalogue.expectedCount; id++) {
        final ArrowDefinition? a = catalogue.byId(id);
        expect(a, isNotNull, reason: 'arrow #$id is missing');
        expect(a!.id, id);
      }
      for (final ArrowArchetype archetype in ArrowArchetype.values) {
        expect(catalogue.byArchetype(archetype), isNotNull,
            reason: '${archetype.name} has no catalogue entry');
      }
    });

    test('Ash Shaft is the 1.00 reference', () {
      final ArrowDefinition ash = catalogue.byKey('ash_shaft')!;
      expect(ash.baseMult, 1.0);
      expect(ash.craftCost.gold, 0);
      expect(ash.element, isNull);
    });

    test('content tiers match docs/08\'s chapter gating', () {
      const Map<String, String> expectedTier = <String, String>{
        'ash_shaft': 't1',
        'broadhead': 't1',
        'splitshaft': 't1',
        'emberhead': 't2',
        'rimeshaft': 't2',
        'stormnock': 't2',
        'blightbarb': 't2',
        'skimmer': 't3',
        'lancehead': 't3',
        'twinfang': 't3',
        'ghostshaft': 't4',
        'prismshaft': 't4',
      };
      for (final MapEntry<String, String> e in expectedTier.entries) {
        expect(catalogue.byKey(e.key)!.contentTier.name, e.value,
            reason: e.key);
      }
    });

    test('the four elemental arrows each carry a distinct element', () {
      const Map<String, String> expected = <String, String>{
        'emberhead': 'ember',
        'rimeshaft': 'frost',
        'stormnock': 'storm',
        'blightbarb': 'toxin',
      };
      for (final MapEntry<String, String> e in expected.entries) {
        final ArrowDefinition a = catalogue.byKey(e.key)!;
        expect(a.element?.name, e.value, reason: e.key);
        expect(a.elementPotency, isNotNull,
            reason: '${e.key} has an element but no potency number');
      }
    });

    test('every arrow has readable card text', () {
      for (final ArrowDefinition a in catalogue.all) {
        expect(a.name.trim(), isNotEmpty, reason: '#${a.id}');
        expect(a.description.trim(), isNotEmpty, reason: '#${a.id}');
      }
    });
  });

  group('craft costs match docs/08 §8.4', () {
    test('T1 arrows other than Ash Shaft cost 800 gold, no materials', () {
      for (final String key in <String>['broadhead', 'splitshaft']) {
        final ArrowDefinition a = catalogue.byKey(key)!;
        expect(a.craftCost.gold, 800, reason: key);
        expect(a.craftCost.materialsByTier, isEmpty, reason: key);
      }
    });

    test('T2 arrows cost 3,400 gold and 12 T1 materials', () {
      for (final String key
          in <String>['emberhead', 'rimeshaft', 'stormnock', 'blightbarb']) {
        final ArrowDefinition a = catalogue.byKey(key)!;
        expect(a.craftCost.gold, 3400, reason: key);
        expect(a.craftCost.materialsByTier, <int, int>{1: 12}, reason: key);
      }
    });

    test('T3 arrows cost 14,000 gold and 10 T2 materials', () {
      for (final String key in <String>['skimmer', 'lancehead', 'twinfang']) {
        final ArrowDefinition a = catalogue.byKey(key)!;
        expect(a.craftCost.gold, 14000, reason: key);
        expect(a.craftCost.materialsByTier, <int, int>{2: 10}, reason: key);
      }
    });

    test('T4 arrows cost 45,000 gold, 8 T3 and 4 T4 materials', () {
      for (final String key in <String>['ghostshaft', 'prismshaft']) {
        final ArrowDefinition a = catalogue.byKey(key)!;
        expect(a.craftCost.gold, 45000, reason: key);
        expect(a.craftCost.materialsByTier, <int, int>{3: 8, 4: 4},
            reason: key);
      }
    });
  });

  group('no card is a blank', () {
    test('every arrow moves a number, carries an element, or has a behaviour',
        () {
      // Ash Shaft is deliberately excluded: docs/08 §8.3 describes it as "no
      // drawback... exists so every other arrow can be described as a trade
      // against it" — being the neutral reference *is* what it does.
      for (final ArrowDefinition a in catalogue.all) {
        if (a.archetype == ArrowArchetype.ashShaft) continue;
        final bool doesSomething = a.modifiers.isNotEmpty ||
            a.element != null ||
            a.behaviour != null ||
            a.baseMult != 1.0;
        expect(doesSomething, isTrue,
            reason: '#${a.id} ${a.name} is indistinguishable from Ash Shaft');
      }
    });

    test('every declared ArrowBehaviour is referenced by some arrow', () {
      final Set<ArrowBehaviour> used = catalogue.all
          .map((ArrowDefinition a) => a.behaviour)
          .whereType<ArrowBehaviour>()
          .toSet();
      final Iterable<ArrowBehaviour> orphans = ArrowBehaviour.values
          .where((ArrowBehaviour b) => !used.contains(b));
      expect(orphans, isEmpty,
          reason: 'declared but granted by no arrow: '
              '${orphans.map((ArrowBehaviour b) => b.name).join(', ')}');
    });
  });

  group('parse rejects bad content', () {
    test('elementPotency with no element is an error', () {
      const String json = '''
{"arrows": [{
  "id": 1, "archetype": "ashShaft", "key": "t", "name": "T",
  "contentTier": "t1", "baseMult": 1.0, "craftCost": {"gold": 0},
  "description": "d", "elementPotency": 5
}]}''';
      final (ArrowCatalogue?, List<ContentError>) r =
          ArrowCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('no element'));
    });

    test('a baseMult far outside a plausible range is rejected', () {
      const String json = '''
{"arrows": [{
  "id": 1, "archetype": "ashShaft", "key": "t", "name": "T",
  "contentTier": "t1", "baseMult": 40.0, "craftCost": {"gold": 0},
  "description": "d"
}]}''';
      final (ArrowCatalogue?, List<ContentError>) r =
          ArrowCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('plausible range'));
    });
  });
}
