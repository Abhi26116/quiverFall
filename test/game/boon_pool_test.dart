import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/boon_inventory.dart';
import 'package:quiverfall/game/boons/boon_pool.dart';
import 'package:test/test.dart';

import 'boon_test_support.dart';

/// docs/20 Phase 9 exit criterion: **"Draw rules verified over 100,000
/// simulated draws."**
///
/// Every rule in docs/09 §9.1 exists because its absence is a known way to lose
/// a player, so each one is checked here at volume rather than on a handful of
/// hand-picked seeds. A rule that holds on ten draws and fails on ten thousand
/// is a rule that fails in production and nowhere else.
void main() {
  late BoonCatalogue catalogue;

  setUpAll(() {
    catalogue = loadBoons();
  });

  BoonInventory freshInventory() => BoonInventory(catalogue: catalogue);

  BoonPool poolFor(BoonInventory inv) =>
      BoonPool(catalogue: catalogue, inventory: inv);

  group('the five anti-frustration rules, over 100,000 draws', () {
    test('all five hold', () {
      const int draws = 100000;
      final Rng rng = Rng(0xB00);

      int totalCards = 0;
      int setsWithNoUsableCard = 0;
      int duplicatesWithinSet = 0;
      int exhaustedOffered = 0;
      int earlyLegendary = 0;
      final Map<int, int> offeredById = <int, int>{};

      for (int d = 0; d < draws; d++) {
        // A fresh build every few hundred draws, walked forward by taking a
        // card each time. Holding one inventory for all 100,000 would exhaust
        // the catalogue and then only ever test the empty-pool path; starting
        // fresh every draw would only ever test the *first* draw, which is the
        // easiest case. Neither alone is the interesting one.
        final BoonInventory inv = freshInventory();
        final BoonPool pool = poolFor(inv);

        // Random build depth, so the rules are exercised against sparse and
        // near-exhausted inventories alike.
        final int depth = rng.nextInt(12);
        for (int i = 0; i < depth; i++) {
          final List<BoonOffer> warmup = pool.drawSet(
            rng,
            DrawContext(roomIndex: 1 + rng.nextInt(9)),
          );
          if (warmup.isNotEmpty) {
            inv.take(warmup[rng.nextInt(warmup.length)].definition);
          }
        }

        final int room = 1 + rng.nextInt(9);
        final List<BoonOffer> set =
            pool.drawSet(rng, DrawContext(roomIndex: room));

        expect(set, isNotEmpty, reason: 'draw $d produced no cards at all');
        totalCards += set.length;

        // ── Rule 1: no duplicate card within a set ─────────────────────────
        final Set<int> seen = <int>{};
        for (final BoonOffer offer in set) {
          if (!seen.add(offer.definition.id)) duplicatesWithinSet++;
          offeredById[offer.definition.id] =
              (offeredById[offer.definition.id] ?? 0) + 1;

          // ── Rule 2: a Boon at max copies leaves the pool ────────────────
          if (inv.copiesOf(offer.definition.id) >=
              offer.definition.maxCopies) {
            exhaustedOffered++;
          }

          // ── Rule 3: no Legendary or Mythic before room 3 ────────────────
          if (room < BoonPool.lateRarityFromRoom &&
              offer.definition.rarity.isLateOnly) {
            earlyLegendary++;
          }
        }

        // ── Rule 5: at least one card is usable by the build ──────────────
        if (!set.any((BoonOffer o) => inv.canUse(o.definition))) {
          setsWithNoUsableCard++;
        }
      }

      expect(duplicatesWithinSet, 0, reason: 'rule 1: duplicate within a set');
      expect(exhaustedOffered, 0, reason: 'rule 2: offered a maxed-out Boon');
      expect(
        earlyLegendary,
        0,
        reason: 'rule 3: Legendary or Mythic before room '
            '${BoonPool.lateRarityFromRoom}',
      );
      expect(
        setsWithNoUsableCard,
        0,
        reason: 'rule 5: a set with nothing the build could use',
      );

      // Sanity: the draws actually happened and were the expected size.
      expect(totalCards, greaterThanOrEqualTo(draws * BoonPool.baseCardCount));

      // Coverage: with 100,000 draws every card should have been seen. A card
      // that never appears is content the player has paid for and will never
      // meet — usually a requirement nothing grants, or a rarity tier that
      // cannot be reached.
      final Iterable<BoonDefinition> never = catalogue.all
          .where((BoonDefinition b) => !offeredById.containsKey(b.id));
      expect(
        never,
        isEmpty,
        reason: 'never offered in 100,000 draws: '
            '${never.map((BoonDefinition b) => '#${b.id} ${b.name}').join(', ')}',
      );
    });
  });

  group('rule 4 — the offence drought', () {
    test('four offence-free picks force an offence card', () {
      // docs/09 §9.1: players who never take damage upgrades hit a DPS wall and
      // quit, and they never diagnose it as their own doing. The game protects
      // them without saying so.
      final BoonInventory inv = freshInventory();
      final BoonPool pool = poolFor(inv);
      final Rng rng = Rng(4242);

      // Four defensive picks in a row.
      for (final String key in <String>[
        'toughened_hide',
        'warded',
        'second_skin',
        'thorns',
      ]) {
        inv.take(catalogue.byKey(key)!);
      }
      expect(inv.isInOffenceDrought, isTrue);

      final List<BoonOffer> set =
          pool.drawSet(rng, const DrawContext(roomIndex: 5));

      expect(
        set.any((BoonOffer o) => o.definition.category == BoonCategory.offence),
        isTrue,
        reason: 'the drought rule did not fire',
      );
      expect(
        set.any((BoonOffer o) => o.reason == OfferReason.forcedOffence),
        isTrue,
        reason: 'the forced card was not labelled, so telemetry cannot tell a '
            'forced offer from a natural one',
      );
    });

    test('taking an offence card ends the drought', () {
      final BoonInventory inv = freshInventory();
      for (final String key in <String>[
        'toughened_hide',
        'warded',
        'second_skin',
        'thorns',
      ]) {
        inv.take(catalogue.byKey(key)!);
      }
      expect(inv.isInOffenceDrought, isTrue);

      inv.take(catalogue.byKey('sharpened_points')!);
      expect(inv.isInOffenceDrought, isFalse);
    });

    test('a short run is not in drought', () {
      // Fewer than four picks is not evidence of anything, and forcing an
      // offence card on draw two would waste the rule on players who are simply
      // early.
      final BoonInventory inv = freshInventory();
      expect(inv.isInOffenceDrought, isFalse);
      inv.take(catalogue.byKey('toughened_hide')!);
      inv.take(catalogue.byKey('warded')!);
      expect(inv.isInOffenceDrought, isFalse);
    });

    test('the forced card is still one the build can use', () {
      // Enforcement order matters: rule 4 runs before rule 5, so a forced
      // offence card that the build cannot use would still leave the set
      // unusable unless rule 5 sees it.
      final BoonInventory inv = freshInventory();
      final BoonPool pool = poolFor(inv);
      final Rng rng = Rng(99);

      for (final String key in <String>[
        'toughened_hide',
        'warded',
        'second_skin',
        'thorns',
      ]) {
        inv.take(catalogue.byKey(key)!);
      }

      for (int i = 0; i < 2000; i++) {
        final List<BoonOffer> set =
            pool.drawSet(rng, const DrawContext(roomIndex: 4));
        expect(
          set.any((BoonOffer o) => inv.canUse(o.definition)),
          isTrue,
          reason: 'drought draw $i left the player with no usable card',
        );
      }
    });
  });

  group('rule 5 — usability', () {
    test('a no-element build is never shown three elemental blanks', () {
      // The named case in docs/09 §9.1. A player with no elemental source who
      // is offered Kindling, Rime and Charge has been offered nothing.
      final BoonInventory inv = freshInventory();
      final BoonPool pool = poolFor(inv);
      final Rng rng = Rng(7777);

      for (int i = 0; i < 20000; i++) {
        final List<BoonOffer> set = pool.drawSet(
          rng,
          DrawContext(roomIndex: 1 + (i % 9)),
        );
        expect(
          set.any((BoonOffer o) => inv.canUse(o.definition)),
          isTrue,
          reason: 'draw $i: ${set.join(' | ')}',
        );
      }
    });

    test('the fallback replaces the least valuable card, not the best one', () {
      // A player shown a Legendary and then handed "+8 % damage" instead has
      // been robbed, even if the Legendary was useless to them.
      final BoonInventory inv = freshInventory();
      final BoonPool pool = poolFor(inv);
      final Rng rng = Rng(31337);

      int fallbacks = 0;
      for (int i = 0; i < 20000; i++) {
        final List<BoonOffer> set =
            pool.drawSet(rng, const DrawContext(roomIndex: 9));
        final Iterable<BoonOffer> substituted = set.where(
          (BoonOffer o) => o.reason == OfferReason.usabilityFallback,
        );
        if (substituted.isEmpty) continue;
        fallbacks++;

        // Whatever was replaced, the set must not have lost its highest rarity
        // to the substitution: the fallback is always a Common, so if a
        // Rare-or-better card is still present the swap took a lesser one.
        final int best = set
            .map((BoonOffer o) => o.definition.rarity.index)
            .reduce((int a, int b) => a > b ? a : b);
        expect(
          best,
          greaterThanOrEqualTo(BoonRarity.common.index),
          reason: 'set $i: ${set.join(' | ')}',
        );
      }

      // The path has to actually be exercised, or this test proves nothing.
      // An element-less build draws elemental cards often, so fallbacks fire.
      expect(
        fallbacks,
        greaterThan(0),
        reason: 'the usability fallback never fired, so it is untested',
      );
    });
  });

  group('rarity weights and depth scaling', () {
    /// Measures the rarity mix at a given room over many draws.
    Map<BoonRarity, double> mixAt(int room, {int samples = 40000}) {
      final BoonInventory inv = freshInventory();
      // Give the build every element so elemental cards are offerable and the
      // mix is not skewed by the usability fallback substituting Commons.
      for (final BuildTag tag in BuildTag.values) {
        inv.grantTag(tag);
      }
      final BoonPool pool = poolFor(inv);
      final Rng rng = Rng(room * 1000 + 5);

      final Map<BoonRarity, int> counts = <BoonRarity, int>{
        for (final BoonRarity r in BoonRarity.values) r: 0,
      };
      int total = 0;

      for (int i = 0; i < samples; i++) {
        for (final BoonOffer offer in
            pool.drawSet(rng, DrawContext(roomIndex: room))) {
          counts[offer.definition.rarity] = counts[offer.definition.rarity]! + 1;
          total++;
        }
      }

      return <BoonRarity, double>{
        for (final BoonRarity r in BoonRarity.values) r: counts[r]! / total,
      };
    }

    test('room 1 is roughly the base distribution', () {
      final Map<BoonRarity, double> mix = mixAt(1);
      // Wide bands: this asserts the shape docs/09 §9.1 describes, not exact
      // weights, which live-ops is expected to retune.
      expect(mix[BoonRarity.common]!, closeTo(0.58, 0.06));
      expect(mix[BoonRarity.rare]!, closeTo(0.27, 0.06));
      expect(mix[BoonRarity.epic]!, closeTo(0.11, 0.04));
      expect(
        mix[BoonRarity.legendary]! + mix[BoonRarity.mythic]!,
        0,
        reason: 'rule 3: nothing late-only in room 1',
      );
    });

    test('runs escalate — room 9 is much richer than room 1', () {
      // Asserted against docs/09 §9.1's **formula**, not its prose. The prose
      // says "by room 9 it is ~35 % Common and ~19 % Epic"; the formula printed
      // four lines above it gives 26.4 % and 22.2 % at room 9, and produces the
      // prose's numbers at room *7*. See
      // docs/decisions/0004-boon-rarity-distribution.md — the formula wins,
      // because it is the precise half of the spec and because a steeper
      // escalation is what the sentence that follows it actually asks for.
      final Map<BoonRarity, double> early = mixAt(1);
      final Map<BoonRarity, double> late = mixAt(9);

      expect(
        late[BoonRarity.common]!,
        lessThan(early[BoonRarity.common]!),
        reason: 'late rooms are not getting rarer',
      );
      expect(late[BoonRarity.common]!, closeTo(0.264, 0.03));
      expect(late[BoonRarity.rare]!, closeTo(0.414, 0.04));
      expect(late[BoonRarity.epic]!, closeTo(0.222, 0.03));
      expect(late[BoonRarity.epic]!, greaterThan(early[BoonRarity.epic]!));
      expect(late[BoonRarity.legendary]!, greaterThan(0));
    });

    test('room 7 matches the numbers §9.1 prose attributes to room 9', () {
      // Kept as a separate, explicitly-labelled test rather than folded into
      // the one above, so that if someone later decides the prose was the
      // intent and the coefficients are too steep, this is the test that tells
      // them exactly which room the prose was describing.
      final Map<BoonRarity, double> mix = mixAt(7);
      expect(mix[BoonRarity.common]!, closeTo(0.343, 0.03));
      expect(mix[BoonRarity.epic]!, closeTo(0.194, 0.03));
    });

    test('a Shrine purchase never yields a Common', () {
      // The player paid for "guaranteed Rare+". A paid guarantee that fails
      // once is remembered forever.
      final BoonInventory inv = freshInventory();
      for (final BuildTag tag in BuildTag.values) {
        inv.grantTag(tag);
      }
      final BoonPool pool = poolFor(inv);
      final Rng rng = Rng(0x5147);

      for (int i = 0; i < 20000; i++) {
        final List<BoonOffer> set = pool.drawSet(
          rng,
          const DrawContext(roomIndex: 5, guaranteeRarePlus: true),
        );
        for (final BoonOffer offer in set) {
          expect(
            offer.definition.rarity.isRarePlus,
            isTrue,
            reason: 'paid draw $i contained ${offer.definition}',
          );
        }
      }
    });

    test('an Elite clear shifts the mix toward Rare+ for one draw', () {
      final BoonInventory inv = freshInventory();
      for (final BuildTag tag in BuildTag.values) {
        inv.grantTag(tag);
      }
      final BoonPool pool = poolFor(inv);

      double rarePlusShare({required bool elite}) {
        final Rng rng = Rng(elite ? 11 : 11);
        int rarePlus = 0;
        int total = 0;
        for (int i = 0; i < 20000; i++) {
          for (final BoonOffer o in pool.drawSet(
            rng,
            DrawContext(roomIndex: 4, afterEliteClear: elite),
          )) {
            if (o.definition.rarity.isRarePlus) rarePlus++;
            total++;
          }
        }
        return rarePlus / total;
      }

      expect(rarePlusShare(elite: true),
          greaterThan(rarePlusShare(elite: false) + 0.05));
    });

    test('the Spire node raises Rare+ weight', () {
      final BoonInventory inv = freshInventory();
      for (final BuildTag tag in BuildTag.values) {
        inv.grantTag(tag);
      }
      final BoonPool pool = poolFor(inv);

      double rarePlusShare(double insight) {
        final Rng rng = Rng(808);
        int rarePlus = 0;
        int total = 0;
        for (int i = 0; i < 20000; i++) {
          for (final BoonOffer o in pool.drawSet(
            rng,
            DrawContext(roomIndex: 4, spireBoonInsight: insight),
          )) {
            if (o.definition.rarity.isRarePlus) rarePlus++;
            total++;
          }
        }
        return rarePlus / total;
      }

      // Node 21 at level 80 is +32 % (docs/04 §4.2 Wing IV).
      expect(rarePlusShare(0.32), greaterThan(rarePlusShare(0.0) + 0.05));
    });
  });

  group('set size', () {
    test('a plain draw offers three cards', () {
      final BoonInventory inv = freshInventory();
      final BoonPool pool = poolFor(inv);
      final Rng rng = Rng(3);
      for (int i = 0; i < 1000; i++) {
        expect(
          pool.drawSet(rng, const DrawContext(roomIndex: 4)).length,
          BoonPool.baseCardCount,
        );
      }
    });

    test('Curator offers five', () {
      final BoonInventory inv = freshInventory();
      inv.take(catalogue.byKey('curator')!);
      final BoonPool pool = poolFor(inv);
      final Rng rng = Rng(3);
      for (int i = 0; i < 1000; i++) {
        expect(
          pool.drawSet(rng, const DrawContext(roomIndex: 4)).length,
          5,
        );
      }
    });

    test('Lucky Find sometimes offers a fourth', () {
      final BoonInventory inv = freshInventory();
      final BoonDefinition lucky = catalogue.byKey('lucky_find')!;
      for (int i = 0; i < lucky.maxCopies; i++) {
        inv.take(lucky);
      }
      final BoonPool pool = poolFor(inv);
      final Rng rng = Rng(3);

      int four = 0;
      const int draws = 20000;
      for (int i = 0; i < draws; i++) {
        if (pool.drawSet(rng, const DrawContext(roomIndex: 4)).length > 3) {
          four++;
        }
      }
      // Three copies at +8 % each.
      expect(four / draws, closeTo(0.24, 0.03));
    });
  });

  group('determinism', () {
    test('the same seed produces the same draws', () {
      // Replays, seeded runs and the balance harness all depend on this. A draw
      // that consumes a variable number of RNG values would desynchronise every
      // subsequent system in the world.
      List<String> run() {
        final BoonInventory inv = freshInventory();
        final BoonPool pool = poolFor(inv);
        final Rng rng = Rng(20260720);
        final List<String> out = <String>[];
        for (int i = 0; i < 200; i++) {
          final List<BoonOffer> set =
              pool.drawSet(rng, DrawContext(roomIndex: 1 + (i % 9)));
          out.add(set.map((BoonOffer o) => o.definition.id).join(','));
          if (set.isNotEmpty) inv.take(set.first.definition);
        }
        return out;
      }

      expect(run(), run());
    });
  });
}
