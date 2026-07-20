import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/boon_inventory.dart';
import 'package:quiverfall/game/boons/loadout_resolver.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boon_test_support.dart';
import 'enemy_test_support.dart';

/// docs/09 §9.3 synergy sets and §9.4 evolution paths.
///
/// Sets are the mid-run "my build became a thing" moment, and evolutions are
/// the run's climax. Both are super-additive **on purpose** — docs/09 §9.5 says
/// so explicitly, and the 2.4x degenerate-combo rule exists to separate these
/// designed spikes from emergent ones. So the tests here are about the trigger
/// conditions being exact, not about the bonuses being small.
void main() {
  late BoonCatalogue boons;
  late SynergyCatalogue synergies;
  late ContentLibrary content;

  setUpAll(() {
    boons = loadBoons();
    synergies = loadSynergies(boons);
    content = loadEnemies();
  });

  BoonInventory fresh() =>
      BoonInventory(catalogue: boons, synergies: synergies);

  SynergySet setById(String id) =>
      synergies.sets.firstWhere((SynergySet s) => s.id == id);

  group('the catalogue matches docs/09', () {
    test('ten sets and six evolutions', () {
      expect(synergies.sets.length, SynergyCatalogue.expectedSets);
      expect(synergies.evolutions.length, SynergyCatalogue.expectedEvolutions);
    });

    test('every set names its bonus in words the flourish can show', () {
      for (final SynergySet s in synergies.sets) {
        expect(s.name.trim(), isNotEmpty);
        expect(s.bonusText.trim(), isNotEmpty, reason: '${s.name} has no text');
      }
    });

    test('every member id is a real Boon', () {
      // A typo'd id is a set that can never complete, and nothing else in the
      // game would ever notice.
      for (final SynergySet s in synergies.sets) {
        for (final int id in s.members) {
          expect(boons.byId(id), isNotNull,
              reason: '${s.name} lists #$id, which does not exist');
        }
      }
    });

    test('every evolution requires the card it replaces', () {
      for (final BoonEvolution e in synergies.evolutions) {
        expect(
          e.requirements.any((EvolutionRequirement r) => r.id == e.replaces),
          isTrue,
          reason: '${e.name} replaces #${e.replaces} without requiring it',
        );
      }
    });

    test('no evolution asks for more copies than its card allows', () {
      // The failure mode this catches is silent: an evolution requiring ×4 of a
      // ×3 card simply never fires, and reads as "that never happens to me".
      for (final BoonEvolution e in synergies.evolutions) {
        for (final EvolutionRequirement r in e.requirements) {
          expect(r.copies, lessThanOrEqualTo(boons.byId(r.id)!.maxCopies),
              reason: '${e.name} needs ${r.copies} of #${r.id}');
        }
      }
    });
  });

  group('sets fire on three distinct members', () {
    test('The Weaver needs three different cards, not three copies', () {
      // The rule that stops a single stacked Common completing a set alone.
      final BoonInventory inv = fresh();
      final BoonDefinition longWeave = boons.byKey('long_weave')!;

      inv..take(longWeave)..take(longWeave)..take(longWeave);
      expect(inv.copiesOf(longWeave.id), 3);
      expect(inv.activeSets, isNot(contains('weaver')),
          reason: 'three copies of one card completed a set');

      inv..take(boons.byKey('bright_thread')!)..take(boons.byKey('tangle')!);
      expect(inv.activeSets, contains('weaver'));
    });

    test('The Weaver grants exactly what §9.3 says', () {
      final BoonInventory inv = fresh()
        ..take(boons.byKey('long_weave')!)
        ..take(boons.byKey('bright_thread')!)
        ..take(boons.byKey('tangle')!);

      expect(inv.activeSets, contains('weaver'));
      // Confluence cap +1 …
      expect(inv.stats.countFor(StatChannel.confluenceStacks), 1);
      // … and +25 % Confluence damage, on top of Bright Thread's own +8 %.
      expect(inv.stats[StatChannel.confluenceDamage], closeTo(0.33, 1e-9));
    });

    test('a set that grants a behaviour turns it on', () {
      // The Storm: "Momentum stacks are permanent for the room", which is what
      // Momentum Engine already does — reusing the behaviour rather than adding
      // a second one that means the same thing.
      final BoonInventory inv = fresh()
        ..take(boons.byKey('fleetfoot')!)
        ..take(boons.byKey('gale_step')!)
        ..take(boons.byKey('quick_recovery')!);

      expect(inv.activeSets, contains('storm'));
      expect(inv.hasBehaviour(BoonBehaviour.momentumEngine), isTrue);
    });

    test('The Sacrifice counts by category, not by a member list', () {
      // "any 3 Cursed" — an id list would go stale the moment a Cursed card is
      // added, and go stale silently.
      expect(setById('sacrifice').members, isEmpty);
      expect(setById('sacrifice').category, BoonCategory.cursed);

      final BoonInventory inv = fresh()
        ..take(boons.byKey('glass_draw')!)
        ..take(boons.byKey('blind_fury')!);
      expect(inv.activeSets, isNot(contains('sacrifice')));

      inv.take(boons.byKey('hollow_bones')!);
      expect(inv.activeSets, contains('sacrifice'));
      expect(inv.hasBehaviour(BoonBehaviour.sacrificeHalved), isTrue);
    });

    test('two members are never enough', () {
      for (final SynergySet s in synergies.sets) {
        final BoonInventory inv = fresh();
        final List<BoonDefinition> candidates = boons.all
            .where(s.countsMember)
            .take(s.threshold - 1)
            .toList();
        for (final BoonDefinition d in candidates) {
          inv.take(d);
        }
        expect(inv.activeSets, isNot(contains(s.id)),
            reason: '${s.name} fired on ${candidates.length} members');
      }
    });

    test('every set can actually be completed', () {
      // Content coverage. A set nobody can complete is a full-screen flourish
      // that never plays.
      for (final SynergySet s in synergies.sets) {
        final BoonInventory inv = fresh();
        for (final BoonDefinition d
            in boons.all.where(s.countsMember)) {
          inv.take(d);
          if (inv.activeSets.contains(s.id)) break;
        }
        expect(inv.activeSets, contains(s.id),
            reason: '${s.name} can never be completed');
      }
    });
  });

  group('The Fortress raises the mitigation cap', () {
    test('75 % becomes 82 %, and nothing else can move it', () {
      final BoonInventory inv = fresh()
        ..take(boons.byKey('toughened_hide')!)
        ..take(boons.byKey('warded')!)
        ..take(boons.byKey('bulwark_stance')!);
      expect(inv.activeSets, contains('fortress'));

      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(8, 4.5);
      LoadoutResolver.applyBuild(world, inv, baseAttack: 10);

      expect(world.damageReductionCapBonus, closeTo(0.07, 1e-9));

      // Pile on enough mitigation to be pinned at the ceiling.
      world
        ..boonDamageReduction = 0.9
        ..stationaryDamageReduction = 0.9;
      world.combat.playerStationary = true;
      world.playerDraw.momentumStacks = 5;

      expect(world.incomingDamageFactor, closeTo(1.0 - 0.82, 1e-9));
    });

    test('without the set the cap is still 75 %', () {
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(8, 4.5);
      world
        ..boonDamageReduction = 0.9
        ..stationaryDamageReduction = 0.9;
      world.combat.playerStationary = true;
      expect(world.incomingDamageFactor, closeTo(0.25, 1e-9));
    });
  });

  group('evolutions replace rather than add', () {
    test('Storm of Nocks consumes the Split Shots that paid for it', () {
      // Seven arrows at −30 % each, *not* seven arrows plus the three Split
      // Shots. Adding on top would let a run hold both halves of the trade.
      final BoonInventory inv = fresh();
      final BoonDefinition split = boons.byKey('split_shot')!;
      inv..take(split)..take(split)..take(split);

      expect(inv.activeEvolutions, isEmpty);
      expect(inv.stats.countFor(StatChannel.extraArrows), 3);
      expect(inv.stats[StatChannel.splitDamagePenalty], closeTo(-0.45, 1e-9));

      inv.take(boons.byKey('twin_nock')!);

      expect(inv.activeEvolutions, contains('storm_of_nocks'));
      expect(inv.hasBehaviour(BoonBehaviour.stormOfNocks), isTrue);
      // Twin Nock's +2 survives; Split Shot's +3 is removed and the
      // evolution's +4 takes its place, so six extra — seven arrows in the air,
      // which is what docs/09 §9.4 specifies.
      expect(inv.stats.countFor(StatChannel.extraArrows), 6);
      // And −30 % per arrow: Twin Nock's −0.25 plus the evolution's −0.05.
      expect(inv.stats[StatChannel.splitDamagePenalty], closeTo(-0.30, 1e-9));
    });

    test('an evolution needs the base card at max copies', () {
      final BoonInventory inv = fresh();
      final BoonDefinition split = boons.byKey('split_shot')!;
      inv..take(split)..take(split); // one short
      inv.take(boons.byKey('twin_nock')!);
      expect(inv.activeEvolutions, isEmpty,
          reason: 'the evolution fired below max copies');
    });

    test('every evolution can be reached', () {
      for (final BoonEvolution e in synergies.evolutions) {
        final BoonInventory inv = fresh();
        for (final EvolutionRequirement r in e.requirements) {
          final BoonDefinition def = boons.byId(r.id)!;
          for (int i = 0; i < r.copies; i++) {
            inv.take(def);
          }
        }
        expect(inv.activeEvolutions, contains(e.id),
            reason: '${e.name} could not be reached even with every '
                'requirement held');
      }
    });

    test('evolutions reach the simulation', () {
      final BoonInventory inv = fresh();
      final BoonDefinition split = boons.byKey('split_shot')!;
      inv..take(split)..take(split)..take(split);
      inv.take(boons.byKey('twin_nock')!);

      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(8, 4.5);
      LoadoutResolver.applyBuild(world, inv, baseAttack: 10);

      expect(world.extraArrows, 6);
      expect(world.boons.has(BoonBehaviour.stormOfNocks), isTrue);
    });
  });

  group('parse rejects bad content', () {
    test('an unreachable evolution is an error', () {
      // Split Shot caps at ×3; asking for four means the card never fires and
      // says nothing about it.
      const String json = '''
{"sets": [], "evolutions": [{
  "id": "x", "name": "X", "replaces": 10, "description": "d",
  "behaviour": "stormOfNocks",
  "requires": [{"id": 10, "copies": 4}]
}]}''';
      final (SynergyCatalogue?, List<ContentError>) r =
          SynergyCatalogue.parse(json, boons: boons);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('can never trigger'));
    });

    test('a member id outside the catalogue is an error', () {
      const String json = '''
{"sets": [{
  "id": "x", "name": "X", "bonusText": "b", "members": [1, 2, 999],
  "behaviour": "prismbreak"
}], "evolutions": []}''';
      final (SynergyCatalogue?, List<ContentError>) r =
          SynergyCatalogue.parse(json, boons: boons);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('not in the Boon catalogue'));
    });

    test('a set that grants nothing is an error', () {
      const String json = '''
{"sets": [{"id": "x", "name": "X", "bonusText": "b", "members": [1,2,3]}],
 "evolutions": []}''';
      final (SynergyCatalogue?, List<ContentError>) r =
          SynergyCatalogue.parse(json, boons: boons);
      expect(r.$1, isNull);
      expect(r.$2.map((ContentError e) => e.message).join(),
          contains('grants nothing'));
    });
  });
}
