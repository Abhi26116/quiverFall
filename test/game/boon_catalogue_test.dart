import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/boon_inventory.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:test/test.dart';

import 'boon_test_support.dart';

/// The catalogue is content, and content is testable.
///
/// These assertions are about the *authored data* — that the 112 cards match
/// docs/09 §9.2, that none of them is a blank, and that the invariants the draw
/// relies on actually hold in the shipping file.
void main() {
  late BoonCatalogue catalogue;

  setUpAll(() {
    catalogue = loadBoons();
  });

  group('the catalogue matches docs/09 §9.2', () {
    test('there are 112 Boons, numbered 1 to 112', () {
      expect(catalogue.length, BoonCatalogue.expectedCount);
      for (int id = 1; id <= BoonCatalogue.expectedCount; id++) {
        expect(catalogue.byId(id), isNotNull, reason: 'Boon #$id is missing');
        expect(catalogue.byId(id)!.id, id);
      }
    });

    test('category sizes match the section headings', () {
      // docs/09 §9.2's section headings state these counts explicitly. They are
      // a design statement, not an accident: category D is deliberately
      // over-represented at 18 because Windline/Confluence is the mechanic the
      // game wants players discovering.
      const Map<BoonCategory, int> expected = <BoonCategory, int>{
        BoonCategory.offence: 25,
        BoonCategory.defence: 19,
        BoonCategory.mobility: 14,
        BoonCategory.windline: 18,
        BoonCategory.elemental: 18,
        BoonCategory.economy: 12,
        BoonCategory.cursed: 6,
      };

      for (final MapEntry<BoonCategory, int> entry in expected.entries) {
        final int actual = catalogue.all
            .where((BoonDefinition b) => b.category == entry.key)
            .length;
        expect(
          actual,
          entry.value,
          reason: 'docs/09 §9.2 heading says ${entry.key.name} has '
              '${entry.value} Boons, found $actual',
        );
      }
    });

    test('every card has text the player can read', () {
      for (final BoonDefinition b in catalogue.all) {
        expect(b.name.trim(), isNotEmpty, reason: '#${b.id} has no name');
        expect(
          b.description.trim(),
          isNotEmpty,
          reason: '#${b.id} ${b.name} has no card text',
        );
      }
    });
  });

  group('no card is a blank', () {
    test('every card either moves a number or runs a behaviour', () {
      for (final BoonDefinition b in catalogue.all) {
        expect(
          b.modifiers.isNotEmpty || b.behaviour != null,
          isTrue,
          reason: '#${b.id} ${b.name} does nothing at all',
        );
      }
    });

    test('every declared behaviour is reachable from some card', () {
      // The inverse of the check above, and the more useful direction: a
      // BoonBehaviour with no card is dead code that the switch arms still pay
      // for, and it usually means a card was renamed and the enum was not.
      final Set<BoonBehaviour> used = catalogue.all
          .map((BoonDefinition b) => b.behaviour)
          .whereType<BoonBehaviour>()
          .toSet();

      final Iterable<BoonBehaviour> orphans = BoonBehaviour.values
          .where((BoonBehaviour b) => !used.contains(b))
          // Evolutions are granted by docs/09 §9.4's upgrade paths, not by a
          // card in the catalogue, so they are expected to be absent here.
          .where((BoonBehaviour b) => !_evolutionBehaviours.contains(b));

      expect(
        orphans,
        isEmpty,
        reason: 'behaviours declared but never authored: '
            '${orphans.map((BoonBehaviour b) => b.name).join(', ')}',
      );
    });
  });

  group('invariants the draw depends on', () {
    test('Legendary and Mythic are once per run', () {
      for (final BoonDefinition b in catalogue.all) {
        if (b.rarity.index < BoonRarity.legendary.index) continue;
        expect(
          b.maxCopies,
          1,
          reason: '#${b.id} ${b.name} is ${b.rarity.name} but stacks — a '
              'stacking Legendary blows the docs/09 §9.5 power budget',
        );
      }
    });

    test('a pure-behaviour card stacks only if it says it does', () {
      // A behaviour is normally on or off, so a second copy of a card that is
      // *only* a behaviour would do nothing — and an offered card that does
      // nothing is a wasted slot the player cannot detect. The few that
      // genuinely scale must declare it, so the intent is in the data rather
      // than in someone's memory.
      for (final BoonDefinition b in catalogue.all) {
        if (b.behaviour == null || b.modifiers.isNotEmpty) continue;
        if (b.stacksByCopies) continue;
        expect(
          b.maxCopies,
          1,
          reason: '#${b.id} ${b.name} is on-or-off but authored ×${b.maxCopies}',
        );
      }
    });

    test('a card that declares copy-scaling has a behaviour to scale', () {
      for (final BoonDefinition b in catalogue.all) {
        if (!b.stacksByCopies) continue;
        expect(b.behaviour, isNotNull, reason: '#${b.id} ${b.name}');
        expect(
          b.maxCopies,
          greaterThan(1),
          reason: '#${b.id} ${b.name} declares copy-scaling but is ×1',
        );
      }
    });

    test('there are enough safe fallbacks to fill the largest set', () {
      // With Curator a set is 5 cards. If the usability rule has to fall back
      // it must have somewhere to fall.
      expect(
        catalogue.safeFallbacks.length,
        greaterThanOrEqualTo(BoonCatalogue.minSafeFallbacks),
      );
      for (final BoonDefinition b in catalogue.safeFallbacks) {
        expect(b.requires, isEmpty);
        expect(b.excludes, isEmpty);
        expect(b.rarity, BoonRarity.common);
      }
    });

    test('every rarity tier has cards to draw from', () {
      for (final BoonRarity r in BoonRarity.values) {
        expect(
          catalogue.ofRarity(r),
          isNotEmpty,
          reason: 'nothing at ${r.name} — the draw would always fall back',
        );
      }
    });
  });

  group('conditional cards declare their conditions', () {
    test('single-element riders require that element', () {
      // A "+12 % Ember damage" card offered to a Frost build is a blank, and
      // docs/09 §9.1's usability rule can only protect the player if the card
      // says what it needs.
      const Map<StatChannel, BuildTag> elementOf = <StatChannel, BuildTag>{
        StatChannel.emberDamage: BuildTag.ember,
        StatChannel.frostEffect: BuildTag.frost,
        StatChannel.stormDamage: BuildTag.storm,
        StatChannel.toxinDamage: BuildTag.toxin,
        StatChannel.freezeDuration: BuildTag.frost,
        StatChannel.stormChainTargets: BuildTag.storm,
        StatChannel.toxinMaxStacks: BuildTag.toxin,
      };

      for (final BoonDefinition b in catalogue.all) {
        for (final BoonModifier m in b.modifiers) {
          final BuildTag? tag = elementOf[m.channel];
          if (tag == null) continue;
          expect(
            b.requires,
            contains(tag),
            reason: '#${b.id} ${b.name} touches ${m.channel.name} but does not '
                'require ${tag.name}',
          );
        }
      }
    });

    test('reaction cards require an element to react with', () {
      for (final BoonDefinition b in catalogue.all) {
        final bool touchesReactions = b.modifiers
            .any((BoonModifier m) => m.channel == StatChannel.reactionDamage);
        if (!touchesReactions) continue;
        expect(
          b.requires,
          contains(BuildTag.anyElement),
          reason: '#${b.id} ${b.name} scales reactions but does not require an '
              'elemental source',
        );
      }
    });

    test('a card that requires a tag can be unlocked by something', () {
      // A requirement no card and no loadout can ever grant is a card that can
      // never be offered — 1/112th of the catalogue silently missing.
      final Set<BuildTag> grantable = <BuildTag>{
        for (final BoonDefinition b in catalogue.all) ...b.grants,
      };
      // These four arrive from the equipped arrow (docs/08), not from a Boon.
      grantable.addAll(<BuildTag>[
        BuildTag.anyElement,
        BuildTag.ember,
        BuildTag.frost,
        BuildTag.storm,
        BuildTag.toxin,
      ]);

      for (final BoonDefinition b in catalogue.all) {
        for (final BuildTag tag in b.requires) {
          expect(
            grantable,
            contains(tag),
            reason: '#${b.id} ${b.name} requires ${tag.name}, which nothing '
                'grants — it can never be offered',
          );
        }
      }
    });
  });

  group('Cursed cards keep their promise', () {
    test('every Cursed card states its downside, and only Cursed cards do', () {
      // docs/09 §9.2 G: "Never hidden, never a trap — a Cursed Boon that
      // surprises the player is a broken promise."
      for (final BoonDefinition b in catalogue.all) {
        if (b.category == BoonCategory.cursed) {
          expect(
            b.downside,
            isNotNull,
            reason: '#${b.id} ${b.name} is Cursed with no stated cost',
          );
          expect(b.downside!.trim(), isNotEmpty);
        } else {
          expect(
            b.downside,
            isNull,
            reason: '#${b.id} ${b.name} is not Cursed but carries a downside '
                'line, which renders a crimson border it has not earned',
          );
        }
      }
    });

    test('a Cursed card actually costs something', () {
      // The downside must be real, not just text. Every Cursed card either
      // moves a channel the wrong way or carries a behaviour that hurts.
      for (final BoonDefinition b in catalogue.all) {
        if (b.category != BoonCategory.cursed) continue;
        final bool hasNegative =
            b.modifiers.any((BoonModifier m) => m.value < 0) ||
                b.modifiers.any(
                  (BoonModifier m) =>
                      m.channel == StatChannel.damageTakenMultiplier &&
                      m.value > 1.0,
                ) ||
                b.behaviour != null;
        expect(
          hasNegative,
          isTrue,
          reason: '#${b.id} ${b.name} is Cursed but costs nothing',
        );
      }
    });
  });

  group('parse rejects bad content', () {
    test('a missing card is an error, not a smaller catalogue', () {
      const String json = '{"boons": []}';
      final (BoonCatalogue?, List<ContentError>) result =
          BoonCatalogue.parse(json);
      expect(result.$1, isNull);
      expect(result.$2, isNotEmpty);
    });

    test('an unknown behaviour is rejected rather than dropped', () {
      // Silently ignoring an unknown behaviour would ship a card that reads
      // like it does something and does nothing.
      final String json = _oneCard('"behaviour": "teleportToVictory"');
      final (BoonCatalogue?, List<ContentError>) result =
          BoonCatalogue.parse(json);
      expect(result.$1, isNull);
      expect(
        result.$2.map((ContentError e) => e.message).join(),
        contains('unknown behaviour'),
      );
    });

    test('an unknown stat channel is rejected', () {
      final String json =
          _oneCard('"modifiers": [{"channel": "luck", "value": 1}]');
      final (BoonCatalogue?, List<ContentError>) result =
          BoonCatalogue.parse(json);
      expect(result.$1, isNull);
      expect(
        result.$2.map((ContentError e) => e.message).join(),
        contains('unknown channel'),
      );
    });

    test('a multiplicative channel authored as a bonus is rejected', () {
      // "Momentum decays 40 % slower" written as 0.4 rather than 1.4 would cut
      // the grace period by 60 % instead of extending it — a sign error that
      // looks entirely reasonable in a diff.
      final String json = _oneCard(
        '"modifiers": [{"channel": "momentumDecayRate", "value": 0.0}]',
      );
      final (BoonCatalogue?, List<ContentError>) result =
          BoonCatalogue.parse(json);
      expect(result.$1, isNull);
      expect(
        result.$2.map((ContentError e) => e.message).join(),
        contains('must be > 0'),
      );
    });
  });

  group('the inventory composes what the catalogue declares', () {
    test('copies add, they do not multiply', () {
      // docs/04 §4.1 rule 1. Three Sharpened Points is +24 %, not 1.08³.
      final BoonInventory inv = BoonInventory(catalogue: catalogue);
      final BoonDefinition sharpened = catalogue.byKey('sharpened_points')!;

      inv.take(sharpened);
      expect(inv.stats[StatChannel.damage], closeTo(0.08, 1e-12));
      inv.take(sharpened);
      inv.take(sharpened);
      expect(inv.stats[StatChannel.damage], closeTo(0.24, 1e-12));
    });

    test('multiplicative channels compose by multiplying', () {
      // Quick Recovery ×3 must be 1.4³ = 2.744, not 1 + 3×0.4 = 2.2.
      final BoonInventory inv = BoonInventory(catalogue: catalogue);
      final BoonDefinition quick = catalogue.byKey('quick_recovery')!;

      inv.take(quick);
      expect(inv.stats[StatChannel.momentumDecayRate], closeTo(1.40, 1e-12));
      inv.take(quick);
      inv.take(quick);
      expect(
        inv.stats[StatChannel.momentumDecayRate],
        closeTo(1.40 * 1.40 * 1.40, 1e-12),
      );
    });

    test('max copies is a hard stop', () {
      final BoonInventory inv = BoonInventory(catalogue: catalogue);
      final BoonDefinition sharpened = catalogue.byKey('sharpened_points')!;
      for (int i = 0; i < sharpened.maxCopies; i++) {
        expect(inv.take(sharpened), isTrue);
      }
      expect(inv.take(sharpened), isFalse);
      expect(inv.copiesOf(sharpened.id), sharpened.maxCopies);
      expect(inv.isExhausted(sharpened), isTrue);
    });

    test('taking a card can unlock cards that depend on it', () {
      // Elemental Tips grants an element; Kindling requires one. Before the
      // first, the second is unofferable — and after, it is not.
      final BoonInventory inv = BoonInventory(catalogue: catalogue);
      final BoonDefinition kindling = catalogue.byKey('kindling')!;
      final BoonDefinition tips = catalogue.byKey('elemental_tips')!;

      expect(inv.canUse(kindling), isFalse);
      expect(inv.canUse(tips), isTrue);

      inv.take(tips);

      expect(inv.canUse(kindling), isFalse,
          reason: 'Elemental Tips grants anyElement, not Ember specifically');
      // Frostfire names its elements, so it does unlock Kindling.
      inv.take(catalogue.byKey('frostfire')!);
      expect(inv.canUse(kindling), isTrue);

      // And Elemental Tips excludes a build that already has an element, so it
      // stops being offerable to itself.
      expect(inv.canUse(tips), isFalse);
    });

    test('reset clears the run but keeps the catalogue', () {
      final BoonInventory inv = BoonInventory(catalogue: catalogue);
      inv.take(catalogue.byKey('ruin')!);
      inv.take(catalogue.byKey('quick_recovery')!);
      expect(inv.stats.isEmpty, isFalse);

      inv.reset();

      expect(inv.stats.isEmpty, isTrue);
      expect(inv.pickOrder, isEmpty);
      expect(inv.tags, isEmpty);
      expect(inv.stats[StatChannel.momentumDecayRate], 1.0);
      expect(inv.catalogue.length, BoonCatalogue.expectedCount);
    });
  });
}

/// docs/09 §9.4's six evolutions. Granted by upgrade paths mid-run rather than
/// drawn, so they have no catalogue entry.
const Set<BoonBehaviour> _evolutionBehaviours = <BoonBehaviour>{
  BoonBehaviour.stormOfNocks,
  BoonBehaviour.eternalWeave,
  BoonBehaviour.bloodwell,
  BoonBehaviour.windborn,
  BoonBehaviour.everburn,
  BoonBehaviour.firstLight,
};

/// A minimal single-card document with [extra] spliced in, for parse tests.
String _oneCard(String extra) => '''
{"boons": [{
  "id": 1, "key": "t", "name": "T", "category": "offence",
  "rarity": "common", "maxCopies": 1, "description": "t", $extra
}]}''';
