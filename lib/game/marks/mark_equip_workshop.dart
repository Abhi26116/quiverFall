import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/game/marks/mark_catalogue.dart';

/// Equips and unequips Marks against a [PlayerSave]'s
/// `PlayerProfile.equippedMarkIds` — docs/04 §4.5's "6 equippable at once
/// (slots at account levels 12/20/30/45/65/90)", applied.
///
/// Deliberately not how a Mark gets *unlocked* — `PlayerSave.marks
/// .unlockedIds` is read here, never written; earning one is a separate,
/// cross-cutting task this Part does not attempt (see ADR 0095). This is
/// only the "equip/unequip a Mark you already have" half, the same
/// distinction [ArrowWorkshop] draws between crafting an arrow and slotting
/// it into a loadout.
abstract final class MarkEquipWorkshop {
  /// docs/04 §4.5's own six thresholds, in order. `slotsFor(1)` is `0` — no
  /// Mark can be equipped at all before account level 12.
  static const List<int> slotUnlockLevels = <int>[12, 20, 30, 45, 65, 90];

  static int slotsFor(int accountLevel) =>
      slotUnlockLevels.where((int level) => accountLevel >= level).length;

  static Result<PlayerSave, EconomyError> equip(
    PlayerSave save,
    MarkCatalogue catalogue,
    String markKey,
  ) {
    if (catalogue.byKey(markKey) == null) {
      return Err<PlayerSave, EconomyError>(EconomyError.unknownMark(markKey));
    }
    if (!save.marks.unlockedIds.contains(markKey)) {
      return Err<PlayerSave, EconomyError>(EconomyError.markNotUnlocked(markKey));
    }
    if (save.profile.equippedMarkIds.contains(markKey)) {
      return Err<PlayerSave, EconomyError>(EconomyError.markAlreadyEquipped(markKey));
    }
    final int slots = slotsFor(save.profile.accountLevel);
    if (save.profile.equippedMarkIds.length >= slots) {
      return Err<PlayerSave, EconomyError>(EconomyError.markSlotsFull(slots));
    }

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      profile: save.profile.copyWith(
        equippedMarkIds: <String>[...save.profile.equippedMarkIds, markKey],
      ),
    ));
  }

  static Result<PlayerSave, EconomyError> unequip(
    PlayerSave save,
    String markKey,
  ) {
    if (!save.profile.equippedMarkIds.contains(markKey)) {
      return Err<PlayerSave, EconomyError>(EconomyError.markNotEquipped(markKey));
    }
    return Ok<PlayerSave, EconomyError>(save.copyWith(
      profile: save.profile.copyWith(
        equippedMarkIds: save.profile.equippedMarkIds
            .where((String k) => k != markKey)
            .toList(),
      ),
    ));
  }
}
