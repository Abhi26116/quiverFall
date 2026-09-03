import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/affix_reroll.dart';
import 'package:quiverfall/game/arrows/affix_roller.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/arrows/arrow_refinement.dart';
import 'package:quiverfall/game/arrows/material_tier.dart';

/// Spends gold and materials against a [PlayerSave] to craft, refine, reroll,
/// or lock/unlock an [ArrowInstance] — docs/08 §8.4's economy, applied.
///
/// Every method here is a pure `PlayerSave -> Result<PlayerSave, EconomyError>`
/// function: it validates preconditions, and on success returns the *whole*
/// new save rather than mutating anything. `lib/game/arrows` stays pure Dart
/// (docs/12-architecture.md §12.2), so a caller applies the result through
/// `PlayerRepository.mutate`/`mutateAndFlush` — this class never touches the
/// repository, a widget, or `dart:math`'s `Random` directly (the caller
/// supplies the [Rng], the same seeded, injectable generator every other
/// roll in the game uses).
abstract final class ArrowWorkshop {
  /// Crafts a new, unrefined [ArrowInstance] — docs/08 §8.4's craft-cost
  /// table, keyed by [ArrowDefinition.contentTier] via
  /// [ArrowDefinition.craftCost].
  static Result<PlayerSave, EconomyError> craft(
    PlayerSave save,
    ArrowCatalogue arrows,
    String arrowId,
  ) {
    final ArrowDefinition? def = arrows.byKey(arrowId);
    if (def == null) return Err<PlayerSave, EconomyError>(EconomyError.unknownArrow(arrowId));
    if (save.inventory.arrows.containsKey(arrowId)) {
      return Err<PlayerSave, EconomyError>(EconomyError.arrowAlreadyOwned(arrowId));
    }

    final ArrowCraftCost cost = def.craftCost;
    final Wallet wallet = save.wallet;
    if (wallet.gold < cost.gold) {
      return Err<PlayerSave, EconomyError>(
        EconomyError.insufficientGold(need: cost.gold, have: wallet.gold),
      );
    }
    for (final MapEntry<int, int> need in cost.materialsByTier.entries) {
      final String key = MaterialTier.keyFor(need.key);
      final int have = wallet.materialCount(key);
      if (have < need.value) {
        return Err<PlayerSave, EconomyError>(EconomyError.insufficientMaterials(
          tier: need.key,
          need: need.value,
          have: have,
        ));
      }
    }

    final Map<String, int> newMaterials = Map<String, int>.of(wallet.materials);
    for (final MapEntry<int, int> need in cost.materialsByTier.entries) {
      final String key = MaterialTier.keyFor(need.key);
      newMaterials[key] = (newMaterials[key] ?? 0) - need.value;
    }

    final Map<String, ArrowInstance> newArrows =
        Map<String, ArrowInstance>.of(save.inventory.arrows)
          ..[arrowId] = ArrowInstance(arrowId: arrowId, crafted: true);

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      wallet: wallet.copyWith(gold: wallet.gold - cost.gold, materials: newMaterials),
      inventory: save.inventory.copyWith(arrows: newArrows),
    ));
  }

  /// Advances an owned arrow one refine step (I→II … IV→V), rolling exactly
  /// one new [Affix] into the slot that step unlocks.
  ///
  /// The roll excludes every affix the arrow already carries — ADR 0013 §2.
  static Result<PlayerSave, EconomyError> refine(
    PlayerSave save,
    AffixCatalogue affixes,
    String arrowId,
    Rng rng,
  ) {
    final ArrowInstance? inst = save.inventory.arrows[arrowId];
    if (inst == null) return Err<PlayerSave, EconomyError>(EconomyError.arrowNotOwned(arrowId));
    if (inst.refineLevel >= ArrowRefinement.maxLevel) {
      return Err<PlayerSave, EconomyError>(EconomyError.maxRefined(arrowId));
    }

    final int goldCost = ArrowRefinement.goldCost(inst.refineLevel);
    final int materialCount = ArrowRefinement.materialCount(inst.refineLevel);
    final String materialKey = MaterialTier.keyFor(ArrowRefinement.materialTier(inst.refineLevel));

    final Wallet wallet = save.wallet;
    if (wallet.gold < goldCost) {
      return Err<PlayerSave, EconomyError>(
        EconomyError.insufficientGold(need: goldCost, have: wallet.gold),
      );
    }
    final int haveMaterials = wallet.materialCount(materialKey);
    if (haveMaterials < materialCount) {
      return Err<PlayerSave, EconomyError>(EconomyError.insufficientMaterials(
        tier: ArrowRefinement.materialTier(inst.refineLevel),
        need: materialCount,
        have: haveMaterials,
      ));
    }

    final Set<String> exclude = inst.affixes.map((Affix a) => a.affixId).toSet();
    final Affix rolled = AffixRoller.roll(affixes, rng, exclude: exclude);

    final Map<String, ArrowInstance> newArrows =
        Map<String, ArrowInstance>.of(save.inventory.arrows)
          ..[arrowId] = inst.copyWith(
            refineLevel: inst.refineLevel + 1,
            affixes: <Affix>[...inst.affixes, rolled],
          );

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      wallet: wallet.copyWith(
        gold: wallet.gold - goldCost,
        materials: Map<String, int>.of(wallet.materials)
          ..[materialKey] = haveMaterials - materialCount,
      ),
      inventory: save.inventory.copyWith(arrows: newArrows),
    ));
  }

  /// Rerolls the one affix in [slot], at the escalating cost
  /// [AffixReroll.goldCost] charges for the session's rerolls so far.
  ///
  /// The roll excludes every *other* slot's affix (ADR 0013 §2) but not the
  /// slot being rerolled itself — landing back on the same archetype is a
  /// legitimate unlucky reroll, not a duplicate.
  static Result<PlayerSave, EconomyError> rerollAffix(
    PlayerSave save,
    AffixCatalogue affixes,
    String arrowId,
    int slot,
    Rng rng,
  ) {
    final ArrowInstance? inst = save.inventory.arrows[arrowId];
    if (inst == null) return Err<PlayerSave, EconomyError>(EconomyError.arrowNotOwned(arrowId));
    if (slot < 0 || slot >= inst.affixes.length) {
      return Err<PlayerSave, EconomyError>(EconomyError.slotOutOfRange(slot));
    }
    if (inst.lockedAffixSlots.contains(slot)) {
      return Err<PlayerSave, EconomyError>(EconomyError.slotLocked(slot));
    }

    final int rerollCount = save.inventory.rerollCountThisSession;
    final int goldCost = AffixReroll.goldCost(rerollCount);
    final Wallet wallet = save.wallet;
    if (wallet.gold < goldCost) {
      return Err<PlayerSave, EconomyError>(
        EconomyError.insufficientGold(need: goldCost, have: wallet.gold),
      );
    }

    final Set<String> exclude = <String>{
      for (int i = 0; i < inst.affixes.length; i++)
        if (i != slot) inst.affixes[i].affixId,
    };
    final Affix rolled = AffixRoller.roll(affixes, rng, exclude: exclude);

    final List<Affix> newAffixes = List<Affix>.of(inst.affixes)..[slot] = rolled;
    final Map<String, ArrowInstance> newArrows =
        Map<String, ArrowInstance>.of(save.inventory.arrows)
          ..[arrowId] = inst.copyWith(affixes: newAffixes);

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      wallet: wallet.copyWith(gold: wallet.gold - goldCost),
      inventory: save.inventory.copyWith(
        arrows: newArrows,
        rerollCountThisSession: rerollCount + 1,
      ),
    ));
  }

  /// Locks [slot] against reroll (up to [ArrowInstance.maxLockedSlots]).
  /// Free — only rerolling costs gold. Locking an already-locked slot is a
  /// no-op success, not an error, so a UI double-tap is harmless.
  static Result<PlayerSave, EconomyError> lockAffix(
    PlayerSave save,
    String arrowId,
    int slot,
  ) {
    final ArrowInstance? inst = save.inventory.arrows[arrowId];
    if (inst == null) return Err<PlayerSave, EconomyError>(EconomyError.arrowNotOwned(arrowId));
    if (slot < 0 || slot >= inst.affixes.length) {
      return Err<PlayerSave, EconomyError>(EconomyError.slotOutOfRange(slot));
    }
    if (inst.lockedAffixSlots.contains(slot)) {
      return Ok<PlayerSave, EconomyError>(save);
    }
    if (!inst.canLockMore) {
      return const Err<PlayerSave, EconomyError>(EconomyError.lockLimitReached());
    }

    final Map<String, ArrowInstance> newArrows =
        Map<String, ArrowInstance>.of(save.inventory.arrows)
          ..[arrowId] = inst.copyWith(
            lockedAffixSlots: <int>{...inst.lockedAffixSlots, slot},
          );
    return Ok<PlayerSave, EconomyError>(
      save.copyWith(inventory: save.inventory.copyWith(arrows: newArrows)),
    );
  }

  /// Unlocks [slot]. A no-op success if it was not locked.
  static Result<PlayerSave, EconomyError> unlockAffix(
    PlayerSave save,
    String arrowId,
    int slot,
  ) {
    final ArrowInstance? inst = save.inventory.arrows[arrowId];
    if (inst == null) return Err<PlayerSave, EconomyError>(EconomyError.arrowNotOwned(arrowId));
    if (!inst.lockedAffixSlots.contains(slot)) {
      return Ok<PlayerSave, EconomyError>(save);
    }

    final Map<String, ArrowInstance> newArrows =
        Map<String, ArrowInstance>.of(save.inventory.arrows)
          ..[arrowId] = inst.copyWith(
            lockedAffixSlots: inst.lockedAffixSlots.difference(<int>{slot}),
          );
    return Ok<PlayerSave, EconomyError>(
      save.copyWith(inventory: save.inventory.copyWith(arrows: newArrows)),
    );
  }
}
