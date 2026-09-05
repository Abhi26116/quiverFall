import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';

/// Saves, swaps, and deletes named [Loadout]s against a [PlayerSave] —
/// docs/04 §4.6's *Second Loadout* research, applied. Same shape as every
/// other workshop in this codebase: a pure
/// `PlayerSave -> Result<PlayerSave, EconomyError>` function.
///
/// A [Loadout] here is exactly the tuple docs/04 names — hero, arrow, and a
/// Mark set — stored by name in `PlayerProfile.loadouts`; [equip] is what
/// actually changes the account's *current* build
/// (`equippedHeroId`/`equippedArrowId`/`equippedMarkIds`), the same three
/// fields the Loadout Sheet already reads and writes today for a
/// single-build account.
abstract final class LoadoutWorkshop {
  /// How many named loadouts an account may hold — 1 until *Second
  /// Loadout* is researched, 2 after. docs/04's own name for the research
  /// ("Second Loadout") states no higher cap, so this reads literally: one
  /// additional slot, not an open-ended list.
  static int maxLoadouts(PlayerSave save) =>
      save.research.completedIds.contains('second_loadout') ? 2 : 1;

  /// Saves [loadout], overwriting any existing entry of the same name.
  static Result<PlayerSave, EconomyError> save(
    PlayerSave save,
    Loadout loadout,
  ) {
    final List<Loadout> current = save.profile.loadouts;
    final int existingIndex =
        current.indexWhere((Loadout l) => l.name == loadout.name);

    final List<Loadout> updated;
    if (existingIndex >= 0) {
      updated = List<Loadout>.of(current)..[existingIndex] = loadout;
    } else {
      if (current.length >= maxLoadouts(save)) {
        return Err<PlayerSave, EconomyError>(
            EconomyError.loadoutCapReached(maxLoadouts(save)));
      }
      updated = List<Loadout>.of(current)..add(loadout);
    }

    return Ok<PlayerSave, EconomyError>(
      save.copyWith(profile: save.profile.copyWith(loadouts: updated)),
    );
  }

  /// Deletes the saved loadout named [name]. The account's *currently
  /// equipped* build is untouched even if it matches — deleting a preset is
  /// not the same as unequipping it.
  static Result<PlayerSave, EconomyError> delete(PlayerSave save, String name) {
    final List<Loadout> current = save.profile.loadouts;
    if (!current.any((Loadout l) => l.name == name)) {
      return Err<PlayerSave, EconomyError>(EconomyError.unknownLoadout(name));
    }
    final List<Loadout> updated =
        current.where((Loadout l) => l.name != name).toList();
    return Ok<PlayerSave, EconomyError>(
      save.copyWith(profile: save.profile.copyWith(loadouts: updated)),
    );
  }

  /// Equips the saved loadout named [name] — the "swap" half of "save/swap
  /// a full hero + arrow + Mark set".
  static Result<PlayerSave, EconomyError> equip(PlayerSave save, String name) {
    final Loadout? loadout = save.profile.loadouts
        .where((Loadout l) => l.name == name)
        .firstOrNull;
    if (loadout == null) {
      return Err<PlayerSave, EconomyError>(EconomyError.unknownLoadout(name));
    }
    return Ok<PlayerSave, EconomyError>(save.copyWith(
      profile: save.profile.copyWith(
        equippedHeroId: loadout.heroId,
        equippedArrowId: loadout.arrowId,
        equippedMarkIds: loadout.markIds,
      ),
    ));
  }
}
