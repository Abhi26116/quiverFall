import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/spire/spire_catalogue.dart';
import 'package:quiverfall/game/spire/spire_workshop.dart';
import 'package:test/test.dart';

import 'spire_test_support.dart';

/// docs/04 §4.2's Spire economy (cost curve, level cap, tier gates), applied
/// against a [PlayerSave]. See ADR 0092.
void main() {
  late SpireCatalogue spire;
  final DateTime now = DateTime.utc(2026, 3);

  setUpAll(() {
    spire = loadSpire();
  });

  // Warden's Might (#1, Armory, unlocks account level 1) - the simplest
  // node to buy from a fresh account.
  const int wardensMight = 1;
  // Swiftshot (#13, Fletchery, unlocks account level 9) - used for the
  // wing-lock tests.
  const int swiftshot = 13;

  PlayerSave freshSave({int accountLevel = 1, int gold = 100000, int insight = 10000}) =>
      PlayerSave.initial(playerId: 'p1', now: now).copyWith(
        profile: PlayerProfile(accountLevel: accountLevel),
        wallet: Wallet(gold: gold, insight: insight),
      );

  group('requiredBandFor', () {
    test('is 0 through level 20, then steps at 21/41/61', () {
      expect(SpireWorkshop.requiredBandFor(1), 0);
      expect(SpireWorkshop.requiredBandFor(20), 0);
      expect(SpireWorkshop.requiredBandFor(21), 20);
      expect(SpireWorkshop.requiredBandFor(40), 20);
      expect(SpireWorkshop.requiredBandFor(41), 40);
      expect(SpireWorkshop.requiredBandFor(60), 40);
      expect(SpireWorkshop.requiredBandFor(61), 60);
      expect(SpireWorkshop.requiredBandFor(80), 60);
    });
  });

  group('levelUp', () {
    test('fails for an unknown node', () {
      final result = SpireWorkshop.levelUp(freshSave(), spire, 999);
      expect(result.errorOrNull?.code, 'economy_unknown_spire_node');
    });

    test('the first level costs exactly Curves.spireNodeCost(base, 1)', () {
      final node = spire.byId(wardensMight)!;
      final save = freshSave(gold: 1000000);
      final Result<PlayerSave, EconomyError> result =
          SpireWorkshop.levelUp(save, spire, wardensMight);

      expect(result.isOk, isTrue);
      final PlayerSave updated = result.valueOrNull!;
      expect(updated.spire.levelOf(wardensMight), 1);
      final int expectedCost =
          Curves.spireNodeCost(node.baseCost, 1).round();
      expect(updated.wallet.gold, save.wallet.gold - expectedCost);
      expect(updated.spire.totalGoldSpent, expectedCost);
    });

    test('fails when the wing is not yet unlocked', () {
      final result = SpireWorkshop.levelUp(freshSave(), spire, swiftshot);
      expect(result.errorOrNull?.code, 'economy_spire_wing_locked');
    });

    test('succeeds once the wing\'s own account level is reached', () {
      final result =
          SpireWorkshop.levelUp(freshSave(accountLevel: 9), spire, swiftshot);
      expect(result.isOk, isTrue);
    });

    test('fails with insufficient gold', () {
      final result =
          SpireWorkshop.levelUp(freshSave(gold: 0), spire, wardensMight);
      expect(result.errorOrNull?.code, 'economy_insufficient_gold');
    });

    test('is refused past level 80', () {
      PlayerSave save = freshSave(gold: 1 << 30, insight: 1 << 20);
      for (int i = 0; i < 80; i++) {
        for (final band in const [20, 40, 60]) {
          if (i + 1 == band + 1 && save.spire.bandOf(wardensMight) < band) {
            save = SpireWorkshop.unlockTierBand(save, spire, wardensMight, band)
                .valueOrNull!;
          }
        }
        save = SpireWorkshop.levelUp(save, spire, wardensMight).valueOrNull!;
      }
      expect(save.spire.levelOf(wardensMight), 80);

      final result = SpireWorkshop.levelUp(save, spire, wardensMight);
      expect(result.errorOrNull?.code, 'economy_spire_node_max_level');
    });

    test('is refused past level 20 until the L20 gate is unlocked', () {
      PlayerSave save = freshSave(gold: 1 << 30);
      for (int i = 0; i < 20; i++) {
        save = SpireWorkshop.levelUp(save, spire, wardensMight).valueOrNull!;
      }
      expect(save.spire.levelOf(wardensMight), 20);

      final result = SpireWorkshop.levelUp(save, spire, wardensMight);
      expect(result.errorOrNull?.code, 'economy_spire_tier_gate_locked');
    });

    test('succeeds past level 20 once the L20 gate is unlocked', () {
      PlayerSave save = freshSave(gold: 1 << 30);
      for (int i = 0; i < 20; i++) {
        save = SpireWorkshop.levelUp(save, spire, wardensMight).valueOrNull!;
      }
      save = SpireWorkshop.unlockTierBand(save, spire, wardensMight, 20)
          .valueOrNull!;

      final result = SpireWorkshop.levelUp(save, spire, wardensMight);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.spire.levelOf(wardensMight), 21);
    });
  });

  group('unlockTierBand', () {
    test('costs exactly the docs-stated Insight per band', () {
      final save = freshSave(insight: 1000);

      final PlayerSave after20 =
          SpireWorkshop.unlockTierBand(save, spire, wardensMight, 20)
              .valueOrNull!;
      expect(after20.wallet.insight, 1000 - 25);
      expect(after20.spire.bandOf(wardensMight), 20);

      final PlayerSave after40 =
          SpireWorkshop.unlockTierBand(after20, spire, wardensMight, 40)
              .valueOrNull!;
      expect(after40.wallet.insight, 1000 - 25 - 90);
      expect(after40.spire.bandOf(wardensMight), 40);

      final PlayerSave after60 =
          SpireWorkshop.unlockTierBand(after40, spire, wardensMight, 60)
              .valueOrNull!;
      expect(after60.wallet.insight, 1000 - 25 - 90 - 300);
      expect(after60.spire.bandOf(wardensMight), 60);
    });

    test('fails with insufficient Insight', () {
      final result = SpireWorkshop.unlockTierBand(
          freshSave(insight: 10), spire, wardensMight, 20);
      expect(result.errorOrNull?.code, 'economy_insufficient_insight');
    });

    test('refuses to skip a band', () {
      final result = SpireWorkshop.unlockTierBand(
          freshSave(), spire, wardensMight, 40);
      expect(result.errorOrNull?.code, 'economy_spire_tier_band_out_of_order');
    });

    test('refuses to unlock an already-unlocked band', () {
      final save =
          SpireWorkshop.unlockTierBand(freshSave(), spire, wardensMight, 20)
              .valueOrNull!;
      final result =
          SpireWorkshop.unlockTierBand(save, spire, wardensMight, 20);
      expect(
          result.errorOrNull?.code, 'economy_spire_tier_band_already_unlocked');
    });
  });
}
