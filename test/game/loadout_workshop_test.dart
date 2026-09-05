import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/research/loadout_workshop.dart';
import 'package:test/test.dart';

/// docs/04 §4.6's *Second Loadout* research, applied against a
/// [PlayerSave]. See ADR 0093.
void main() {
  final DateTime now = DateTime.utc(2026, 3);

  PlayerSave freshSave({bool secondLoadoutResearched = false}) {
    final save = PlayerSave.initial(playerId: 'p1', now: now);
    return secondLoadoutResearched
        ? save.copyWith(
            research: const ResearchState(
                completedIds: <String>{'second_loadout'}))
        : save;
  }

  const Loadout a = Loadout(name: 'A', heroId: 'wren', arrowId: 'ash_shaft');
  const Loadout b = Loadout(name: 'B', heroId: 'kestrel', arrowId: 'broadhead');

  group('maxLoadouts', () {
    test('is 1 without the research, 2 with it', () {
      expect(LoadoutWorkshop.maxLoadouts(freshSave()), 1);
      expect(
        LoadoutWorkshop.maxLoadouts(freshSave(secondLoadoutResearched: true)),
        2,
      );
    });
  });

  group('save', () {
    test('adds a first loadout for free, no research needed', () {
      final result = LoadoutWorkshop.save(freshSave(), a);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.profile.loadouts, [a]);
    });

    test('refuses a second loadout without the research', () {
      final withA = LoadoutWorkshop.save(freshSave(), a).valueOrNull!;
      final result = LoadoutWorkshop.save(withA, b);
      expect(result.errorOrNull?.code, 'economy_loadout_cap_reached');
    });

    test('allows a second loadout once researched', () {
      final withA =
          LoadoutWorkshop.save(freshSave(secondLoadoutResearched: true), a)
              .valueOrNull!;
      final result = LoadoutWorkshop.save(withA, b);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.profile.loadouts, [a, b]);
    });

    test('overwrites an existing loadout of the same name in place', () {
      final withA = LoadoutWorkshop.save(freshSave(), a).valueOrNull!;
      const renamed = Loadout(name: 'A', heroId: 'sable', arrowId: 'rimeshaft');
      final result = LoadoutWorkshop.save(withA, renamed);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.profile.loadouts, [renamed]);
    });
  });

  group('delete', () {
    test('removes a saved loadout by name', () {
      final withBoth =
          LoadoutWorkshop.save(freshSave(secondLoadoutResearched: true), a)
              .valueOrNull!;
      final withBothPlusB = LoadoutWorkshop.save(withBoth, b).valueOrNull!;

      final result = LoadoutWorkshop.delete(withBothPlusB, 'A');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.profile.loadouts, [b]);
    });

    test('fails for an unknown name', () {
      final result = LoadoutWorkshop.delete(freshSave(), 'nope');
      expect(result.errorOrNull?.code, 'economy_unknown_loadout');
    });
  });

  group('equip', () {
    test('sets the account\'s equipped hero, arrow, and Marks', () {
      const withMarks = Loadout(
        name: 'A',
        heroId: 'wren',
        arrowId: 'ash_shaft',
        markIds: ['mark_of_the_thread'],
      );
      final saved = LoadoutWorkshop.save(freshSave(), withMarks).valueOrNull!;

      final result = LoadoutWorkshop.equip(saved, 'A');
      expect(result.isOk, isTrue);
      final updated = result.valueOrNull!;
      expect(updated.profile.equippedHeroId, 'wren');
      expect(updated.profile.equippedArrowId, 'ash_shaft');
      expect(updated.profile.equippedMarkIds, ['mark_of_the_thread']);
    });

    test('fails for an unknown name', () {
      final result = LoadoutWorkshop.equip(freshSave(), 'nope');
      expect(result.errorOrNull?.code, 'economy_unknown_loadout');
    });
  });
}
