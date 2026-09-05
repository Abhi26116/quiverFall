import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/marks/mark_catalogue.dart';
import 'package:quiverfall/game/marks/mark_equip_workshop.dart';
import 'package:test/test.dart';

import 'mark_test_support.dart';

/// docs/04 §4.5's "6 equippable at once (slots at account levels
/// 12/20/30/45/65/90)", applied against a [PlayerSave]. See ADR 0095.
void main() {
  late MarkCatalogue marks;
  final DateTime now = DateTime.utc(2026, 3);

  setUpAll(() {
    marks = loadMarks();
  });

  PlayerSave freshSave({
    int accountLevel = 12,
    Set<String> unlocked = const {'mark_of_ruin', 'mark_of_the_gale'},
  }) =>
      PlayerSave.initial(playerId: 'p1', now: now).copyWith(
        profile: PlayerProfile(accountLevel: accountLevel),
        marks: MarkState(unlockedIds: unlocked),
      );

  group('slotsFor', () {
    test('is 0 below account level 12, then steps at each threshold', () {
      expect(MarkEquipWorkshop.slotsFor(1), 0);
      expect(MarkEquipWorkshop.slotsFor(11), 0);
      expect(MarkEquipWorkshop.slotsFor(12), 1);
      expect(MarkEquipWorkshop.slotsFor(20), 2);
      expect(MarkEquipWorkshop.slotsFor(30), 3);
      expect(MarkEquipWorkshop.slotsFor(45), 4);
      expect(MarkEquipWorkshop.slotsFor(65), 5);
      expect(MarkEquipWorkshop.slotsFor(90), 6);
      expect(MarkEquipWorkshop.slotsFor(200), 6);
    });
  });

  group('equip', () {
    test('fails for an unknown key', () {
      final result = MarkEquipWorkshop.equip(freshSave(), marks, 'nope');
      expect(result.errorOrNull?.code, 'economy_unknown_mark');
    });

    test('fails for a Mark that is not unlocked', () {
      final result =
          MarkEquipWorkshop.equip(freshSave(unlocked: {}), marks, 'mark_of_ruin');
      expect(result.errorOrNull?.code, 'economy_mark_not_unlocked');
    });

    test('fails below account level 12 (zero slots)', () {
      final result = MarkEquipWorkshop.equip(
          freshSave(accountLevel: 11), marks, 'mark_of_ruin');
      expect(result.errorOrNull?.code, 'economy_mark_slots_full');
    });

    test('succeeds and adds the key to equippedMarkIds', () {
      final result = MarkEquipWorkshop.equip(freshSave(), marks, 'mark_of_ruin');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.profile.equippedMarkIds, ['mark_of_ruin']);
    });

    test('refuses to equip the same Mark twice', () {
      final once =
          MarkEquipWorkshop.equip(freshSave(), marks, 'mark_of_ruin').valueOrNull!;
      final twice = MarkEquipWorkshop.equip(once, marks, 'mark_of_ruin');
      expect(twice.errorOrNull?.code, 'economy_mark_already_equipped');
    });

    test('refuses past the account\'s own slot count', () {
      // 1 slot at level 12 - equipping a second Mark must fail even though
      // both are unlocked.
      final once =
          MarkEquipWorkshop.equip(freshSave(), marks, 'mark_of_ruin').valueOrNull!;
      final result =
          MarkEquipWorkshop.equip(once, marks, 'mark_of_the_gale');
      expect(result.errorOrNull?.code, 'economy_mark_slots_full');
    });

    test('a second slot at level 20 allows a second Mark', () {
      final once = MarkEquipWorkshop.equip(
              freshSave(accountLevel: 20), marks, 'mark_of_ruin')
          .valueOrNull!;
      final result = MarkEquipWorkshop.equip(once, marks, 'mark_of_the_gale');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.profile.equippedMarkIds,
          ['mark_of_ruin', 'mark_of_the_gale']);
    });
  });

  group('unequip', () {
    test('removes an equipped Mark', () {
      final equipped =
          MarkEquipWorkshop.equip(freshSave(), marks, 'mark_of_ruin').valueOrNull!;
      final result = MarkEquipWorkshop.unequip(equipped, 'mark_of_ruin');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.profile.equippedMarkIds, isEmpty);
    });

    test('fails for a Mark that is not currently equipped', () {
      final result = MarkEquipWorkshop.unequip(freshSave(), 'mark_of_ruin');
      expect(result.errorOrNull?.code, 'economy_mark_not_equipped');
    });
  });
}
