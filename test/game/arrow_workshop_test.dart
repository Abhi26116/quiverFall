import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/affix_reroll.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_refinement.dart';
import 'package:quiverfall/game/arrows/arrow_workshop.dart';
import 'package:test/test.dart';

import 'affix_test_support.dart';
import 'arrow_test_support.dart';

/// docs/08 §8.4's crafting/refinement/reroll economy, applied against a
/// [PlayerSave] — see ADR 0013 for the three gaps this filled in along the
/// way (material-tier keys, no-duplicate-affix rolls, and the daily reset
/// this deliberately leaves to a not-yet-built system).
void main() {
  late ArrowCatalogue arrows;
  late AffixCatalogue affixes;

  setUpAll(() {
    arrows = loadArrows();
    affixes = loadAffixes();
  });

  PlayerSave freshSave() => PlayerSave.initial(
        playerId: 'p1',
        now: DateTime.utc(2026),
      );

  group('craft', () {
    test('a gold-only arrow deducts gold and adds an unrefined instance', () {
      final PlayerSave save =
          freshSave().copyWith(wallet: const Wallet(gold: 1000));

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.craft(save, arrows, 'broadhead');
      final PlayerSave updated = result.valueOrNull!;

      expect(updated.wallet.gold, 200); // 1000 - 800
      final ArrowInstance inst = updated.inventory.arrows['broadhead']!;
      expect(inst.crafted, isTrue);
      expect(inst.refineLevel, 0);
      expect(inst.affixes, isEmpty);
    });

    test('an arrow with a material cost deducts both gold and materials', () {
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(gold: 5000, materials: <String, int>{'ashwood': 20}),
      );

      final PlayerSave updated =
          ArrowWorkshop.craft(save, arrows, 'emberhead').valueOrNull!;

      expect(updated.wallet.gold, 5000 - 3400);
      expect(updated.wallet.materialCount('ashwood'), 20 - 12);
      expect(updated.inventory.arrows.containsKey('emberhead'), isTrue);
    });

    test('fails when gold is insufficient, spending nothing', () {
      final PlayerSave save =
          freshSave().copyWith(wallet: const Wallet(gold: 100));

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.craft(save, arrows, 'broadhead');

      expect(result.errorOrNull?.code, 'economy_insufficient_gold');
      expect(save.wallet.gold, 100); // save itself is untouched — pure fn
    });

    test('fails when materials are insufficient even with enough gold', () {
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(gold: 999999, materials: <String, int>{'ashwood': 3}),
      );

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.craft(save, arrows, 'emberhead');

      expect(result.errorOrNull?.code, 'economy_insufficient_materials');
    });

    test('fails when the arrow is already owned', () {
      // ash_shaft ships pre-owned in PlayerSave.initial.
      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.craft(freshSave(), arrows, 'ash_shaft');

      expect(result.errorOrNull?.code, 'economy_arrow_already_owned');
    });

    test('fails for an unknown arrow id', () {
      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.craft(freshSave(), arrows, 'not_a_real_arrow');

      expect(result.errorOrNull?.code, 'economy_unknown_arrow');
    });
  });

  group('refine', () {
    PlayerSave saveWith(ArrowInstance inst, {int gold = 999999}) {
      return freshSave().copyWith(
        wallet: Wallet(
          gold: gold,
          materials: const <String, int>{
            'ashwood': 999,
            'ironhead': 999,
            'skyfeather': 999,
            'prismcore': 999,
          },
        ),
        inventory: InventoryState(
          arrows: <String, ArrowInstance>{inst.arrowId: inst},
        ),
      );
    }

    test('advances refineLevel and deducts gold + materials for step I->II',
        () {
      const ArrowInstance inst =
          ArrowInstance(arrowId: 'broadhead', crafted: true);
      final PlayerSave save = saveWith(inst);

      final PlayerSave updated =
          ArrowWorkshop.refine(save, affixes, 'broadhead', Rng(1)).valueOrNull!;

      expect(updated.wallet.gold, save.wallet.gold - ArrowRefinement.goldCost(0));
      expect(
        updated.wallet.materialCount('ashwood'),
        save.wallet.materialCount('ashwood') - ArrowRefinement.materialCount(0),
      );
      final ArrowInstance newInst = updated.inventory.arrows['broadhead']!;
      expect(newInst.refineLevel, 1);
      expect(newInst.affixes, hasLength(1));
    });

    test('rolls exactly one new affix, appended after any existing ones', () {
      const ArrowInstance inst = ArrowInstance(
        arrowId: 'broadhead',
        crafted: true,
        refineLevel: 1,
        affixes: <Affix>[Affix(affixId: 'keen', value: 0.03)],
      );
      final PlayerSave save = saveWith(inst);

      final ArrowInstance newInst = ArrowWorkshop.refine(
        save,
        affixes,
        'broadhead',
        Rng(2),
      ).valueOrNull!.inventory.arrows['broadhead']!;

      expect(newInst.affixes, hasLength(2));
      expect(newInst.affixes.first.affixId, 'keen'); // untouched
    });

    test('fails when gold is insufficient', () {
      const ArrowInstance inst =
          ArrowInstance(arrowId: 'broadhead', crafted: true);
      final PlayerSave save = saveWith(inst, gold: 10);

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.refine(save, affixes, 'broadhead', Rng(3));

      expect(result.errorOrNull?.code, 'economy_insufficient_gold');
    });

    test('fails when materials are insufficient', () {
      const ArrowInstance inst =
          ArrowInstance(arrowId: 'broadhead', crafted: true);
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(gold: 999999, materials: <String, int>{'ashwood': 0}),
        inventory: const InventoryState(
          arrows: <String, ArrowInstance>{'broadhead': inst},
        ),
      );

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.refine(save, affixes, 'broadhead', Rng(4));

      expect(result.errorOrNull?.code, 'economy_insufficient_materials');
    });

    test('fails when the arrow is not owned', () {
      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.refine(freshSave(), affixes, 'broadhead', Rng(5));

      expect(result.errorOrNull?.code, 'economy_arrow_not_owned');
    });

    test('fails once already at max refinement (V)', () {
      const ArrowInstance inst = ArrowInstance(
        arrowId: 'broadhead',
        crafted: true,
        refineLevel: ArrowRefinement.maxLevel,
      );
      final PlayerSave save = saveWith(inst);

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.refine(save, affixes, 'broadhead', Rng(6));

      expect(result.errorOrNull?.code, 'economy_max_refined');
    });

    test('never rolls a duplicate of an affix the arrow already carries', () {
      const List<String> existing = <String>['sharpened', 'keen', 'swift'];
      final ArrowInstance inst = ArrowInstance(
        arrowId: 'broadhead',
        crafted: true,
        refineLevel: 3,
        affixes: <Affix>[
          for (final String id in existing) Affix(affixId: id, value: 0.05),
        ],
      );
      final PlayerSave save = saveWith(inst);

      for (int seed = 0; seed < 300; seed++) {
        final ArrowInstance updated = ArrowWorkshop.refine(
          save,
          affixes,
          'broadhead',
          Rng(seed),
        ).valueOrNull!.inventory.arrows['broadhead']!;
        final String rolledId = updated.affixes.last.affixId;
        expect(existing.contains(rolledId), isFalse,
            reason: 'seed $seed rolled a duplicate: $rolledId');
      }
    });
  });

  group('rerollAffix', () {
    PlayerSave saveWith(ArrowInstance inst, {int gold = 999999}) {
      return freshSave().copyWith(
        wallet: Wallet(gold: gold),
        inventory: InventoryState(
          arrows: <String, ArrowInstance>{inst.arrowId: inst},
        ),
      );
    }

    const ArrowInstance twoAffixInstance = ArrowInstance(
      arrowId: 'broadhead',
      crafted: true,
      refineLevel: 2,
      affixes: <Affix>[
        Affix(affixId: 'sharpened', value: 0.05),
        Affix(affixId: 'keen', value: 0.03),
      ],
    );

    test('replaces exactly the target slot and leaves the other untouched',
        () {
      final PlayerSave save = saveWith(twoAffixInstance);

      final ArrowInstance updated = ArrowWorkshop.rerollAffix(
        save,
        affixes,
        'broadhead',
        0,
        Rng(9),
      ).valueOrNull!.inventory.arrows['broadhead']!;

      expect(updated.affixes[1].affixId, 'keen'); // slot 1 untouched
      expect(updated.affixes, hasLength(2));
    });

    test('costs AffixReroll.goldCost and increments the session counter', () {
      final PlayerSave save = saveWith(twoAffixInstance);

      final PlayerSave updated = ArrowWorkshop.rerollAffix(
        save,
        affixes,
        'broadhead',
        0,
        Rng(10),
      ).valueOrNull!;

      expect(save.wallet.gold - updated.wallet.gold, AffixReroll.goldCost(0));
      expect(updated.inventory.rerollCountThisSession, 1);
    });

    test('cost escalates across consecutive rerolls in the same session', () {
      PlayerSave save = saveWith(twoAffixInstance);

      for (int i = 0; i < 4; i++) {
        final int expectedCost = AffixReroll.goldCost(i);
        final int goldBefore = save.wallet.gold;
        final PlayerSave updated = ArrowWorkshop.rerollAffix(
          save,
          affixes,
          'broadhead',
          0,
          Rng(100 + i),
        ).valueOrNull!;
        expect(goldBefore - updated.wallet.gold, expectedCost, reason: 'reroll #$i');
        save = updated;
      }
    });

    test('fails on a locked slot', () {
      final PlayerSave save = saveWith(
        twoAffixInstance.copyWith(lockedAffixSlots: const <int>{0}),
      );

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.rerollAffix(save, affixes, 'broadhead', 0, Rng(11));

      expect(result.errorOrNull?.code, 'economy_slot_locked');
    });

    test('fails on an out-of-range slot', () {
      final PlayerSave save = saveWith(twoAffixInstance);

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.rerollAffix(save, affixes, 'broadhead', 5, Rng(12));

      expect(result.errorOrNull?.code, 'economy_slot_out_of_range');
    });

    test('fails when gold is insufficient', () {
      final PlayerSave save = saveWith(twoAffixInstance, gold: 10);

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.rerollAffix(save, affixes, 'broadhead', 0, Rng(13));

      expect(result.errorOrNull?.code, 'economy_insufficient_gold');
    });

    test('never rerolls into a duplicate of another slot\'s affix', () {
      final PlayerSave save = saveWith(twoAffixInstance);

      for (int seed = 0; seed < 300; seed++) {
        final ArrowInstance updated = ArrowWorkshop.rerollAffix(
          save,
          affixes,
          'broadhead',
          0,
          Rng(seed),
        ).valueOrNull!.inventory.arrows['broadhead']!;
        expect(updated.affixes[0].affixId, isNot('keen'),
            reason: 'seed $seed duplicated slot 1\'s affix');
      }
    });
  });

  group('lockAffix / unlockAffix', () {
    const ArrowInstance threeAffixInstance = ArrowInstance(
      arrowId: 'broadhead',
      crafted: true,
      refineLevel: 3,
      affixes: <Affix>[
        Affix(affixId: 'sharpened', value: 0.05),
        Affix(affixId: 'keen', value: 0.03),
        Affix(affixId: 'swift', value: 0.04),
      ],
    );

    PlayerSave saveWith(ArrowInstance inst) => PlayerSave.initial(
          playerId: 'p1',
          now: DateTime.utc(2026),
        ).copyWith(
          inventory: InventoryState(
            arrows: <String, ArrowInstance>{inst.arrowId: inst},
          ),
        );

    test('locks a slot; locking it again is a no-op success', () {
      final PlayerSave save = saveWith(threeAffixInstance);

      final PlayerSave once =
          ArrowWorkshop.lockAffix(save, 'broadhead', 0).valueOrNull!;
      expect(once.inventory.arrows['broadhead']!.lockedAffixSlots, <int>{0});

      final PlayerSave twice =
          ArrowWorkshop.lockAffix(once, 'broadhead', 0).valueOrNull!;
      expect(twice, once); // idempotent — no change on the second call
    });

    test('refuses a third lock past the 2-slot limit', () {
      final PlayerSave save = saveWith(
        threeAffixInstance.copyWith(lockedAffixSlots: const <int>{0, 1}),
      );

      final Result<PlayerSave, EconomyError> result =
          ArrowWorkshop.lockAffix(save, 'broadhead', 2);

      expect(result.errorOrNull?.code, 'economy_lock_limit_reached');
    });

    test('unlocks a slot; unlocking an unlocked slot is a no-op success', () {
      final PlayerSave save = saveWith(
        threeAffixInstance.copyWith(lockedAffixSlots: const <int>{0}),
      );

      final PlayerSave unlocked =
          ArrowWorkshop.unlockAffix(save, 'broadhead', 0).valueOrNull!;
      expect(unlocked.inventory.arrows['broadhead']!.lockedAffixSlots, isEmpty);

      final PlayerSave again =
          ArrowWorkshop.unlockAffix(unlocked, 'broadhead', 0).valueOrNull!;
      expect(again, unlocked);
    });

    test('a locked slot blocks reroll; unlocking it allows reroll again', () {
      final PlayerSave locked = saveWith(
        threeAffixInstance.copyWith(lockedAffixSlots: const <int>{1}),
      ).copyWith(wallet: const Wallet(gold: 999999));

      final Result<PlayerSave, EconomyError> blocked =
          ArrowWorkshop.rerollAffix(locked, affixes, 'broadhead', 1, Rng(14));
      expect(blocked.errorOrNull?.code, 'economy_slot_locked');

      final PlayerSave unlocked =
          ArrowWorkshop.unlockAffix(locked, 'broadhead', 1).valueOrNull!;
      final Result<PlayerSave, EconomyError> allowed =
          ArrowWorkshop.rerollAffix(unlocked, affixes, 'broadhead', 1, Rng(14));
      expect(allowed.isOk, isTrue);
    });
  });
}
