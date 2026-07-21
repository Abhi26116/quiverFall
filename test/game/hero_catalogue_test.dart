import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:test/test.dart';

import 'hero_test_support.dart';

/// The hero catalogue is content, and content is testable — the same posture
/// `boon_catalogue_test.dart` takes toward `boons.json`.
///
/// docs/20 Phase 10's exit criterion is "all 20 heroes playable with working
/// ultimates". This file is the data half: that the 20 heroes match docs/07
/// exactly, and that nothing in the shipping table is a card that reads as
/// real but does nothing. The behaviour half — that each hero's kit actually
/// runs — lives in `hero_behaviour_test.dart`, alongside each implementation.
void main() {
  late HeroCatalogue catalogue;

  setUpAll(() {
    catalogue = loadHeroes();
  });

  group('the catalogue matches docs/07', () {
    test('there are 20 heroes, numbered 1 to 20, one per archetype', () {
      expect(catalogue.length, HeroCatalogue.expectedCount);
      for (int id = 1; id <= HeroCatalogue.expectedCount; id++) {
        final HeroDefinition? h = catalogue.byId(id);
        expect(h, isNotNull, reason: 'hero #$id is missing');
        expect(h!.id, id);
      }
      for (final HeroArchetype a in HeroArchetype.values) {
        expect(catalogue.byArchetype(a), isNotNull,
            reason: '${a.name} has no catalogue entry');
      }
    });

    test('rarity distribution is 4 Common, 8 Rare, 6 Epic, 2 Legendary', () {
      // docs/07 §7.0: "4 Common · 8 Rare · 6 Epic · 2 Legendary."
      const Map<HeroRarity, int> expected = <HeroRarity, int>{
        HeroRarity.common: 4,
        HeroRarity.rare: 8,
        HeroRarity.epic: 6,
        HeroRarity.legendary: 2,
      };
      for (final MapEntry<HeroRarity, int> e in expected.entries) {
        final int actual = catalogue.all
            .where((HeroDefinition h) => h.rarity == e.key)
            .length;
        expect(actual, e.value,
            reason: 'docs/07 §7.0 says ${e.key.name} has ${e.value}, found '
                '$actual');
      }
    });

    test('Wren is the free starting hero', () {
      final HeroDefinition wren = catalogue.byKey('wren')!;
      expect(wren.unlock.kind, HeroUnlockKind.free);
      expect(wren.unlock.chapter, isNull);
    });

    test('every hero has readable text', () {
      for (final HeroDefinition h in catalogue.all) {
        expect(h.name.trim(), isNotEmpty, reason: '#${h.id} has no name');
        expect(h.epithet.trim(), isNotEmpty, reason: '#${h.id} has no epithet');
        expect(h.passive.description.trim(), isNotEmpty,
            reason: '#${h.id} passive has no card text');
        expect(h.ultimate.description.trim(), isNotEmpty,
            reason: '#${h.id} ultimate has no card text');
        for (final HeroTalentNode node in h.talents) {
          for (final HeroTalentBranch b in node.branches) {
            expect(b.description.trim(), isNotEmpty,
                reason: '#${h.id} ★${node.starRequired}${b.key} has no text');
          }
        }
      }
    });
  });

  group('every hero kit is complete', () {
    test('exactly three talent nodes, at star 1, 3 and 5', () {
      for (final HeroDefinition h in catalogue.all) {
        expect(h.talents.length, 3, reason: '#${h.id} ${h.name}');
        final List<int> stars = h.talents
            .map((HeroTalentNode n) => n.starRequired)
            .toList()
          ..sort();
        expect(stars, <int>[1, 3, 5], reason: '#${h.id} ${h.name}');
      }
    });

    test('every talent node offers exactly two branches, keyed a and b', () {
      for (final HeroDefinition h in catalogue.all) {
        for (final HeroTalentNode node in h.talents) {
          expect(node.branches, hasLength(2),
              reason: '#${h.id} ${h.name} ★${node.starRequired}');
          final Set<String> keys =
              node.branches.map((HeroTalentBranch b) => b.key).toSet();
          expect(keys, <String>{'a', 'b'},
              reason: '#${h.id} ${h.name} ★${node.starRequired}');
        }
      }
    });

    test('no talent branch is a blank', () {
      for (final HeroDefinition h in catalogue.all) {
        for (final HeroTalentNode node in h.talents) {
          for (final HeroTalentBranch b in node.branches) {
            expect(
              b.modifiers.isNotEmpty || b.behaviour != null,
              isTrue,
              reason: '#${h.id} ${h.name} ★${node.starRequired}${b.key} '
                  '"${b.name}" does nothing',
            );
          }
        }
      }
    });

    test('every ultimate has a behaviour', () {
      // docs/07 §7.0: "Ultimates are manual — a single large button ... never
      // auto-cast." A stat-only "ultimate" is a passive with a cooldown, not
      // what any hero in the roster actually has.
      for (final HeroDefinition h in catalogue.all) {
        expect(h.ultimate.behaviour, isNotNull,
            reason: '#${h.id} ${h.name}\'s ultimate has no coded effect');
      }
    });

    test('every passive does something', () {
      for (final HeroDefinition h in catalogue.all) {
        expect(
          h.passive.modifiers.isNotEmpty || h.passive.behaviour != null,
          isTrue,
          reason: '#${h.id} ${h.name}\'s passive does nothing',
        );
      }
    });
  });

  group('no orphaned behaviour', () {
    test('every declared HeroBehaviour is referenced by some hero', () {
      // The inverse of "every ability does something": a behaviour with no
      // card pointing at it is dead code the switch arms still pay for, and
      // usually means a kit was rewritten and the enum was not.
      final Set<HeroBehaviour> used = <HeroBehaviour>{};
      for (final HeroDefinition h in catalogue.all) {
        if (h.passive.behaviour != null) used.add(h.passive.behaviour!);
        if (h.ultimate.behaviour != null) used.add(h.ultimate.behaviour!);
        for (final HeroTalentNode node in h.talents) {
          for (final HeroTalentBranch b in node.branches) {
            if (b.behaviour != null) used.add(b.behaviour!);
          }
        }
      }

      final Iterable<HeroBehaviour> orphans =
          HeroBehaviour.values.where((HeroBehaviour b) => !used.contains(b));
      expect(
        orphans,
        isEmpty,
        reason: 'declared but granted by no hero: '
            '${orphans.map((HeroBehaviour b) => b.name).join(', ')}',
      );
    });
  });

  group('parse rejects bad content', () {
    test('a hero with only one talent branch is an error', () {
      final String json = _oneHero('''
        "talents": [
          {"starRequired": 1, "branches": [
            {"key": "a", "name": "A", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]}
          ]},
          {"starRequired": 3, "branches": [
            {"key": "a", "name": "A", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]},
            {"key": "b", "name": "B", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]}
          ]},
          {"starRequired": 5, "branches": [
            {"key": "a", "name": "A", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]},
            {"key": "b", "name": "B", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]}
          ]}
        ]
      ''');
      final (HeroCatalogue?, List<ContentError>) r = HeroCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('expected 2'));
    });

    test('an unknown behaviour is rejected rather than dropped', () {
      final String json = _oneHero('''
        "ultimate": {"name": "U", "description": "d", "behaviour": "totallyMadeUp"}
      ''');
      final (HeroCatalogue?, List<ContentError>) r = HeroCatalogue.parse(json);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('unknown behaviour'));
    });
  });
}

/// A minimal single-hero document with valid talents, overridable per test.
String _oneHero(String override) {
  const String defaultTalents = '''
    "talents": [
      {"starRequired": 1, "branches": [
        {"key": "a", "name": "A", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]},
        {"key": "b", "name": "B", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]}
      ]},
      {"starRequired": 3, "branches": [
        {"key": "a", "name": "A", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]},
        {"key": "b", "name": "B", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]}
      ]},
      {"starRequired": 5, "branches": [
        {"key": "a", "name": "A", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]},
        {"key": "b", "name": "B", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]}
      ]}
    ]
  ''';
  final bool overridesTalents = override.contains('"talents"');
  return '''
{"heroes": [{
  "id": 1, "archetype": "wren", "key": "t", "name": "T", "epithet": "e",
  "rarity": "common", "role": "r",
  "stats": {"atk": 100, "hp": 100, "moveSpeed": 3.2, "fireRate": 2.2},
  "unlock": {"kind": "free"},
  "passive": {"name": "P", "description": "d", "modifiers": [{"channel":"moveSpeed","value":0.1}]},
  "ultimate": {"name": "U", "description": "d", "behaviour": "wrenVolleyFan"},
  ${overridesTalents ? '' : '$defaultTalents,'}
  $override
}]}''';
}
