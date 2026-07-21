import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_inventory.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'arrow_test_support.dart';
import 'boon_test_support.dart';
import 'hero_test_support.dart';

/// [HeroLoadoutResolver] is the seam Phase 10 was building toward all along —
/// `LoadoutResolver.apply` (Phase 9) already took `base*` parameters shaped
/// exactly for "hero, arrow, Spire, research and ascension already composed".
/// This proves the hero and arrow halves of that composition, against the
/// shipping catalogues rather than fixtures — Wren and Ash Shaft are the
/// reference hero and the reference arrow specifically so a test against them
/// is a test against docs/07 §7.0's own baseline numbers.
void main() {
  final HeroCatalogue heroes = loadHeroes();
  final ArrowCatalogue arrows = loadArrows();
  final BoonCatalogue boons = loadBoons();

  final HeroDefinition wren = heroes.byArchetype(HeroArchetype.wren)!;
  final ArrowDefinition ashShaft = arrows.byArchetype(ArrowArchetype.ashShaft)!;
  final ArrowDefinition broadhead = arrows.byArchetype(ArrowArchetype.broadhead)!;

  SimWorld freshWorld() {
    final SimWorld world = SimWorld(seed: 1);
    world.spawnPlayer(0, 0);
    return world;
  }

  group('level-1, star-0 Wren with Ash Shaft matches the reference baseline', () {
    late SimWorld world;
    setUp(() {
      world = freshWorld();
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(heroId: 'wren'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
    });

    test('attack is the bare ATK 100 baseline, unscaled by the neutral arrow', () {
      expect(world.playerAttack, closeTo(100.0, 1e-9));
    });

    test('fire rate multiplier is 1.0 — 2.20 hero stat over the 2.20 Tier I base', () {
      expect(world.fireRateMultiplier, closeTo(1.0, 1e-9));
    });

    test('move speed is the bare 3.20 u/s baseline', () {
      expect(world.playerMoveSpeed, closeTo(3.20, 1e-9));
    });

    test('max health is the bare 100 baseline', () {
      expect(world.entities.maxHealth[world.player.index], closeTo(100.0, 1e-9));
    });

    test("Wren's passive and ultimate behaviours are both live", () {
      expect(world.hero.has(HeroBehaviour.wrenTrueshot), isTrue);
      expect(world.hero.has(HeroBehaviour.wrenVolleyFan), isTrue);
    });

    test("Trueshot's +8 % crit chance reaches CombatModifiers", () {
      expect(world.combat.critChance, closeTo(0.08, 1e-9));
    });

    test('no talent behaviour is live below ★1', () {
      expect(world.hero.has(HeroBehaviour.wrenWideFan), isFalse);
      expect(world.hero.has(HeroBehaviour.wrenFocusedFan), isFalse);
      expect(world.hero.has(HeroBehaviour.wrenWardensLattice), isFalse);
      expect(world.hero.has(HeroBehaviour.wrenWardensFury), isFalse);
    });

    test('the arrow carries no behaviour of its own', () {
      expect(ashShaft.behaviour, isNull);
    });
  });

  group('level and star scaling flows through Curves.heroStat unchanged', () {
    test('a levelled, starred Wren scales attack, HP, move speed and fire rate', () {
      final SimWorld world = freshWorld();
      const HeroState state = HeroState(heroId: 'wren', level: 11, stars: 2);
      HeroLoadoutResolver.apply(
        world,
        wren,
        state,
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      final double expectedAtk = Curves.heroStat(100, 11, 2);
      final double expectedHp = Curves.heroStat(100, 11, 2);
      final double expectedMove = Curves.heroStat(3.20, 11, 2);
      final double expectedFireRate = Curves.heroStat(2.20, 11, 2);

      expect(world.playerAttack, closeTo(expectedAtk, 1e-9));
      expect(
        world.entities.maxHealth[world.player.index],
        closeTo(expectedHp, 1e-9),
      );
      expect(world.playerMoveSpeed, closeTo(expectedMove, 1e-9));
      expect(
        world.fireRateMultiplier,
        closeTo(expectedFireRate / DrawTier.one.fireRate, 1e-9),
      );
    });
  });

  group('talent gating: inert below the star, inert with no choice made, live once chosen', () {
    // ★1 already scales the base stat block itself (docs/07 §7.0's own
    // +12 %/star, via Curves.heroStat) — separate from, and stacked
    // underneath, whichever talent the star also unlocks.
    final double baseMoveAtStar1 = Curves.heroStat(3.20, 1, 1);

    test('★1 reached but no choice recorded contributes nothing beyond the star bonus', () {
      final SimWorld world = freshWorld();
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(heroId: 'wren', stars: 1),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      expect(world.playerMoveSpeed, closeTo(baseMoveAtStar1, 1e-9));
      expect(
        world.combat.critMultiplier,
        closeTo(DamageResolver.baseCritMultiplier, 1e-9),
      );
    });

    test("choosing Steady Hand ('a') adds +12 % crit damage, not move speed", () {
      final SimWorld world = freshWorld();
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(
          heroId: 'wren',
          stars: 1,
          talentChoices: <String, String>{'1': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      expect(world.playerMoveSpeed, closeTo(baseMoveAtStar1, 1e-9));
      expect(
        world.combat.critMultiplier,
        closeTo(DamageResolver.baseCritMultiplier + 0.12, 1e-9),
      );
    });

    test("choosing Fleet ('b') adds +10 % move speed on top of the star bonus, not crit damage", () {
      final SimWorld world = freshWorld();
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(
          heroId: 'wren',
          stars: 1,
          talentChoices: <String, String>{'1': 'b'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      expect(world.playerMoveSpeed, closeTo(baseMoveAtStar1 * 1.10, 1e-9));
      expect(
        world.combat.critMultiplier,
        closeTo(DamageResolver.baseCritMultiplier, 1e-9),
      );
    });

    test('a ★3 choice made before reaching ★3 is ignored — stars gate, not the map key', () {
      final SimWorld world = freshWorld();
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(
          heroId: 'wren',
          stars: 1,
          talentChoices: <String, String>{'3': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      expect(world.hero.has(HeroBehaviour.wrenWideFan), isFalse);
    });

    test('★3 reached and chosen activates the matching behaviour only', () {
      final SimWorld world = freshWorld();
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(
          heroId: 'wren',
          stars: 3,
          talentChoices: <String, String>{'3': 'b'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      expect(world.hero.has(HeroBehaviour.wrenFocusedFan), isTrue);
      expect(world.hero.has(HeroBehaviour.wrenWideFan), isFalse);
    });
  });

  group('arrow contributions compose the same way a hero talent does', () {
    test("Broadhead's higher baseMult raises attack, its fire-rate penalty lowers it", () {
      final SimWorld world = freshWorld();
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(heroId: 'wren'),
        broadhead,
        const ArrowInstance(arrowId: 'broadhead'),
      );

      expect(world.playerAttack, closeTo(100.0 * 1.28, 1e-9));
      expect(world.fireRateMultiplier, closeTo(1.0 * (1 - 0.18), 1e-9));
    });
  });

  group('refinement raises the arrow half of attack, independent of the hero', () {
    test('a refined Ash Shaft applies its cumulative baseMult bonus', () {
      final SimWorld world = freshWorld();
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(heroId: 'wren'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft', refineLevel: 2),
      );
      // docs/08 §8.4: refine II -> III (index 2) carries a cumulative +17 %.
      expect(world.playerAttack, closeTo(100.0 * 1.17, 1e-9));
    });
  });

  group('hero and Boon contributions merge into the same StatChannel bucket', () {
    test("Trueshot's crit chance and a Boon's crit chance sum, not replace", () {
      final SimWorld world = freshWorld();
      final BoonInventory inventory = BoonInventory(catalogue: boons);
      // #2 "Keen Eye": +5 % crit chance.
      final bool taken = inventory.take(boons.byId(2)!);
      expect(taken, isTrue);

      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(heroId: 'wren'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
        boons: inventory,
      );

      expect(world.combat.critChance, closeTo(0.08 + 0.05, 1e-9));
    });

    test('the Boon inventory behaviours stay live alongside the hero ones', () {
      final SimWorld world = freshWorld();
      final BoonInventory inventory = BoonInventory(catalogue: boons);
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(heroId: 'wren'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
        boons: inventory,
      );
      expect(world.hero.has(HeroBehaviour.wrenTrueshot), isTrue);
    });
  });
}
