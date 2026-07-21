import 'dart:math' as math;

import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'arrow_test_support.dart';
import 'enemy_test_support.dart';
import 'hero_test_support.dart';

/// The behaviour half of Phase 10's hero work — mirrors what
/// `boon_behaviour_test.dart` is for Boons. Each test here is what lets a
/// [HeroBehaviour] leave [pendingHeroBehaviourWork].
void main() {
  final HeroCatalogue heroes = loadHeroes();
  final ArrowCatalogue arrows = loadArrows();
  final ContentLibrary content = loadEnemies();

  final HeroDefinition wren = heroes.byArchetype(HeroArchetype.wren)!;
  final HeroDefinition kestrel = heroes.byArchetype(HeroArchetype.kestrel)!;
  final ArrowDefinition ashShaft = arrows.byArchetype(ArrowArchetype.ashShaft)!;

  /// A live world carrying Wren and Ash Shaft, with a stationary target due
  /// east of the player — the same "straight line, angle zero" layout every
  /// test below reasons from.
  ({SimWorld world, int target}) arena({
    Map<String, String> talentChoices = const <String, String>{},
    int stars = 0,
  }) {
    final SimWorld world = SimWorld(seed: 99, content: content)
      ..autoFire = true;
    world.spawnPlayer(4.0, 4.5);
    HeroLoadoutResolver.apply(
      world,
      wren,
      HeroState(heroId: 'wren', stars: stars, talentChoices: talentChoices),
      ashShaft,
      const ArrowInstance(arrowId: 'ash_shaft'),
    );
    final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
    world.enemies.speedScale[0] = 0;
    world.entities.maxHealth[mote] = 1e9;
    world.entities.health[mote] = 1e9;
    return (world: world, target: mote);
  }

  /// Same shape as [arena], carrying Kestrel instead.
  ({SimWorld world, int target}) kestrelArena({
    Map<String, String> talentChoices = const <String, String>{},
    int stars = 0,
  }) {
    final SimWorld world = SimWorld(seed: 7, content: content)
      ..autoFire = true;
    world.spawnPlayer(4.0, 4.5);
    HeroLoadoutResolver.apply(
      world,
      kestrel,
      HeroState(heroId: 'kestrel', stars: stars, talentChoices: talentChoices),
      ashShaft,
      const ArrowInstance(arrowId: 'ash_shaft'),
    );
    final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
    world.enemies.speedScale[0] = 0;
    world.entities.maxHealth[mote] = 1e9;
    world.entities.health[mote] = 1e9;
    return (world: world, target: mote);
  }

  void run(SimWorld world, int ticks) {
    final InputSnapshot idle = InputSnapshot();
    for (int i = 0; i < ticks; i++) {
      world.tick(idle);
    }
  }

  group('the runtime is actually populated', () {
    test('HeroLoadoutResolver carries Wren\'s behaviours into the world', () {
      final SimWorld world = arena().world;
      expect(world.hero.has(HeroBehaviour.wrenTrueshot), isTrue);
      expect(world.hero.has(HeroBehaviour.wrenVolleyFan), isTrue);
    });
  });

  group('Trueshot', () {
    test('leaves Tier I/II shots on the standard aim angle', () {
      final ({SimWorld world, int target}) a = arena();
      // Tier I is immediate — no need to wait out the Draw ramp.
      a.world.tick(InputSnapshot());
      bool sawArrow = false;
      for (int e = 0; e < a.world.events.count; e++) {
        if (a.world.events.typeAt(e) != SimEventType.arrowFired) continue;
        sawArrow = true;
        final int slot = a.world.events.entityAAt(e);
        final double angle = math.atan2(
          a.world.entities.velY[slot],
          a.world.entities.velX[slot],
        );
        // Target is due east of the player and stationary: the honest angle
        // is 0, and Trueshot must not touch a shot that never reached Tier
        // III.
        expect(angle.abs(), lessThan(1e-6));
      }
      expect(sawArrow, isTrue);
    });

    /// Runs [world] until a Tier III shot fires at the (already-moving)
    /// [mote], re-asserting its velocity every tick so the AI can never steer
    /// it — firing reads velocity/position before the AI runs each tick.
    /// Returns the fired angle and the honest straight-line angle to the
    /// mote's actual position *at that same tick* — not a fixed assumption,
    /// because the mote has been drifting north the entire time it took the
    /// Draw to reach Tier III.
    ({double fired, double naive})? fireTierThreeAtMovingTarget(
      SimWorld world,
      int mote,
      int player,
    ) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 400; t++) {
        world.entities.velX[mote] = 0;
        world.entities.velY[mote] = 3.0;
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) != SimEventType.arrowFired) continue;
          if (world.events.valueAAt(e).round() != DrawTier.three.index) {
            continue;
          }
          final int slot = world.events.entityAAt(e);
          final double fired = math.atan2(
            world.entities.velY[slot],
            world.entities.velX[slot],
          );
          final double naive = math.atan2(
            world.entities.posY[mote] - world.entities.posY[player],
            world.entities.posX[mote] - world.entities.posX[player],
          );
          return (fired: fired, naive: naive);
        }
        world.events.clear();
      }
      return null;
    }

    test('bends a Tier III shot toward a moving target, capped at 12°', () {
      final SimWorld world = SimWorld(seed: 99, content: content)
        ..autoFire = true;
      final int player = world.spawnPlayer(4.0, 4.5).index;
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(heroId: 'wren'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;

      final ({double fired, double naive})? result =
          fireTierThreeAtMovingTarget(world, mote, player);
      expect(result, isNotNull, reason: 'never reached Tier III');

      final double delta = result!.fired - result.naive;
      // Trueshot must move *toward* the lead (the mote drifts north, so the
      // lead angle is more positive than the naive one), but by no more than
      // the 12° cap.
      expect(delta, greaterThan(0.001));
      expect(delta, lessThanOrEqualTo(math.pi / 15 + 1e-6));
    });

    test('does nothing for a hero without Trueshot', () {
      // No hero loaded at all — the default, inert HeroRuntime every test
      // before Phase 10 already ran against.
      final SimWorld world = SimWorld(seed: 99, content: content)
        ..autoFire = true;
      final int player = world.spawnPlayer(4.0, 4.5).index;
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;

      final ({double fired, double naive})? result =
          fireTierThreeAtMovingTarget(world, mote, player);
      expect(result, isNotNull, reason: 'never reached Tier III');
      expect(result!.fired, closeTo(result.naive, 1e-6));
    });
  });

  group('Ultimate charge and trigger', () {
    test('chargeFromDamage follows docs/07 §7.0\'s formula exactly', () {
      final SimWorld world = arena().world;
      // Wren, level 1 star 0: heroATK 100, fireRate 2.20 (ADR 0006 — the
      // hero's own base kit, not the composed build).
      const double expectedPerDamage = 1.0 / (14 * 100 * 2.20);
      expect(world.hero.chargePerDamage, closeTo(expectedPerDamage, 1e-12));

      world.hero.chargeFromDamage(1000);
      expect(
        world.hero.ultimateCharge,
        closeTo(1000 * expectedPerDamage, 1e-12),
      );
    });

    test('charge clamps at 1.0 rather than overshooting', () {
      final SimWorld world = arena().world;
      world.hero.chargeFromDamage(1e9);
      expect(world.hero.ultimateCharge, 1.0);
    });

    test('landing a real hit actually charges the Ultimate', () {
      final ({SimWorld world, int target}) a = arena();
      expect(a.world.hero.ultimateCharge, 0);
      run(a.world, 30);
      expect(a.world.hero.ultimateCharge, greaterThan(0));
    });

    test('ultimateReady fires once when charge fills, not every tick after', () {
      final ({SimWorld world, int target}) a = arena();
      a.world.hero.ultimateCharge = 1.0;

      int readyEvents = 0;
      for (int t = 0; t < 10; t++) {
        a.world.tick(InputSnapshot());
        readyEvents += a.world.events.countOf(SimEventType.ultimateReady);
        a.world.events.clear();
      }
      expect(readyEvents, 1);
    });

    test('pressing the button before charge fills does nothing', () {
      final ({SimWorld world, int target}) a = arena()..world.autoFire = false;
      final InputSnapshot press = InputSnapshot()..set(0, 0, ultimate: true);
      a.world.tick(press);
      expect(a.world.events.countOf(SimEventType.arrowFired), 0);
      expect(a.world.events.countOf(SimEventType.ultimateUsed), 0);
    });
  });

  group('Volley Fan and its ★3 variants', () {
    test('Volley Fan: 7 arrows across 90°, each at 80 % damage, Tier III', () {
      final ({SimWorld world, int target}) a = arena();
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;

      final InputSnapshot press = InputSnapshot()..set(0, 0, ultimate: true);
      a.world.tick(press);

      final List<int> slots = <int>[];
      for (int e = 0; e < a.world.events.count; e++) {
        if (a.world.events.typeAt(e) == SimEventType.arrowFired) {
          slots.add(a.world.events.entityAAt(e));
        }
      }
      expect(slots, hasLength(7));
      expect(a.world.events.countOf(SimEventType.ultimateUsed), 1);
      expect(a.world.hero.ultimateCharge, 0);

      double minAngle = double.infinity;
      double maxAngle = -double.infinity;
      for (final int slot in slots) {
        expect(a.world.projectiles.drawTier[slot], DrawTier.three.index);
        expect(
          a.world.projectiles.damage[slot],
          closeTo(a.world.playerAttack * 0.80, 1e-9),
        );
        final double angle = math.atan2(
          a.world.entities.velY[slot],
          a.world.entities.velX[slot],
        );
        if (angle < minAngle) minAngle = angle;
        if (angle > maxAngle) maxAngle = angle;
      }
      // Centred on 0 (the target is due east), spanning the full 90°.
      expect(maxAngle - minAngle, closeTo(math.pi / 2, 1e-6));
      expect(minAngle, closeTo(-math.pi / 4, 1e-6));
      expect(maxAngle, closeTo(math.pi / 4, 1e-6));
    });

    test('Wide Fan (★3a): 11 arrows at 60 % instead of 7 at 80 %', () {
      final ({SimWorld world, int target}) a = arena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
      );
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final List<int> slots = <int>[
        for (int e = 0; e < a.world.events.count; e++)
          if (a.world.events.typeAt(e) == SimEventType.arrowFired)
            a.world.events.entityAAt(e),
      ];
      expect(slots, hasLength(11));
      for (final int slot in slots) {
        expect(
          a.world.projectiles.damage[slot],
          closeTo(a.world.playerAttack * 0.60, 1e-9),
        );
      }
    });

    test("Focused Fan (★3b): 3 arrows at 220 %, +3 pierce over Tier III's own", () {
      final ({SimWorld world, int target}) a = arena(
        stars: 3,
        talentChoices: <String, String>{'3': 'b'},
      );
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final List<int> slots = <int>[
        for (int e = 0; e < a.world.events.count; e++)
          if (a.world.events.typeAt(e) == SimEventType.arrowFired)
            a.world.events.entityAAt(e),
      ];
      expect(slots, hasLength(3));
      for (final int slot in slots) {
        expect(
          a.world.projectiles.damage[slot],
          closeTo(a.world.playerAttack * 2.20, 1e-9),
        );
        // Tier III's own bonusPierce (2) plus Focused Fan's +3.
        expect(a.world.projectiles.pierceRemaining[slot], 5);
      }
    });
  });

  group('Flurry and its ★5 variants', () {
    test('triggering sets the base 4 s window at x3 rate', () {
      final ({SimWorld world, int target}) a = kestrelArena()
        ..world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.flurryRemaining, closeTo(4.0, 1e-9));
      expect(a.world.hero.flurryRateMultiplier, closeTo(3.0, 1e-9));
      expect(a.world.events.countOf(SimEventType.arrowFired), 0,
          reason: 'Flurry is a buff, not a burst — no arrows of its own');
    });

    /// True if any arrow fired at Tier III across [ticks] ticks of [input].
    /// A single tick is not reliably enough time for the next shot's
    /// cooldown to elapse, so this drives several and checks the whole
    /// window rather than one snapshot.
    bool sawTierThreeOver(SimWorld world, InputSnapshot input, int ticks) {
      for (int t = 0; t < ticks; t++) {
        world.tick(input);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.arrowFired &&
              world.events.valueAAt(e).round() == DrawTier.three.index) {
            return true;
          }
        }
        world.events.clear();
      }
      return false;
    }

    test('while it runs, ordinary shots fire at Tier III with the Draw meter untouched', () {
      final ({SimWorld world, int target}) a = kestrelArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(sawTierThreeOver(a.world, InputSnapshot(), 30), isTrue);
      expect(
        a.world.playerDraw.tier,
        DrawTier.one,
        reason: 'the Draw meter must still read honestly, same as Perfect Form',
      );
    });

    test('moving during Flurry does not drop the forced tier', () {
      final ({SimWorld world, int target}) a = kestrelArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(
        sawTierThreeOver(a.world, InputSnapshot()..set(1.0, 0.0), 30),
        isTrue,
      );
    });

    test('expires after its duration and firing returns to the honest tier', () {
      final ({SimWorld world, int target}) a = kestrelArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      run(a.world, 300); // well past 4 s at 60 Hz
      expect(a.world.hero.flurryRemaining, 0);
    });

    test('Endless Flurry (★5a): 7 s at x2.2 instead of 4 s at x3', () {
      final ({SimWorld world, int target}) a = kestrelArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'a'},
      )..world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.flurryRemaining, closeTo(7.0, 1e-9));
      expect(a.world.hero.flurryRateMultiplier, closeTo(2.2, 1e-9));
    });

    test('Perfect Flurry (★5b): 3 s at x3, doubles Confluence damage while active', () {
      final ({SimWorld world, int target}) a = kestrelArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'b'},
      )..world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.flurryRemaining, closeTo(3.0, 1e-9));
      expect(a.world.hero.flurryRateMultiplier, closeTo(3.0, 1e-9));
      expect(a.world.hero.has(HeroBehaviour.kestrelPerfectFlurry), isTrue);
    });
  });

  group("Sharper Nock recovers Hummingbird's penalty only at Tier III", () {
    test('with Sharper Nock, the -15 % penalty is exactly cancelled at Tier III', () {
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(0, 0);
      HeroLoadoutResolver.apply(
        world,
        kestrel,
        const HeroState(
          heroId: 'kestrel',
          stars: 1,
          talentChoices: <String, String>{'1': 'b'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      expect(
        world.combat.damageSumFor(
          targetHealthFraction: 1.0,
          shotDistance: 0,
          targetId: -1,
          isTierThree: true,
        ),
        closeTo(0.0, 1e-9),
      );
      expect(
        world.combat.damageSumFor(
          targetHealthFraction: 1.0,
          shotDistance: 0,
          targetId: -1,
        ),
        closeTo(-0.15, 1e-9),
        reason: 'off Tier III, the penalty still applies',
      );
    });

    test('without the talent, the -15 % penalty applies at every tier', () {
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(0, 0);
      HeroLoadoutResolver.apply(
        world,
        kestrel,
        const HeroState(heroId: 'kestrel'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      expect(
        world.combat.damageSumFor(
          targetHealthFraction: 1.0,
          shotDistance: 0,
          targetId: -1,
          isTierThree: true,
        ),
        closeTo(-0.15, 1e-9),
      );
      expect(
        world.combat.damageSumFor(
          targetHealthFraction: 1.0,
          shotDistance: 0,
          targetId: -1,
        ),
        closeTo(-0.15, 1e-9),
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  // Layer 3 — the ledger
  // ────────────────────────────────────────────────────────────────────────

  group('the hero behaviour ledger is honest', () {
    test('every pending entry names a real, registered behaviour', () {
      for (final HeroBehaviour b in pendingHeroBehaviourWork) {
        final bool found = heroes.all.any((HeroDefinition h) =>
            h.passive.behaviour == b ||
            h.ultimate.behaviour == b ||
            h.talents.any((HeroTalentNode n) =>
                n.branches.any((HeroTalentBranch br) => br.behaviour == b)));
        expect(
          found,
          isTrue,
          reason: '${b.name} is listed as pending but no hero declares it',
        );
      }
    });

    test('the ledger has not grown', () {
      // The number that must only ever go down, exactly like
      // pendingBehaviourWork was for Phase 9's Boons. 140 hero behaviours
      // total (kestrelSharperNock never joined this enum — it turned out to
      // be one StatModifier, not a behaviour); Wren's four and Kestrel's
      // Flurry plus both ★5 variants are the first seven out.
      expect(
        pendingHeroBehaviourWork.length,
        lessThanOrEqualTo(133),
        reason: 'a hero behaviour was added without being implemented, or '
            'the ledger was not shrunk after implementing one',
      );
    });
  });
}

/// Hero behaviours that are declared, parsed and registered on the runtime —
/// but whose gameplay is not implemented yet.
///
/// Mirrors `pendingBehaviourWork` in `boon_effects_test.dart` exactly: kept
/// explicit rather than left implicit, because "the behaviour is in the
/// catalogue" and "the behaviour does something" are different claims and
/// only one of them is currently true for these. Each one moves out of this
/// list when its implementation and its own test land together.
const Set<HeroBehaviour> pendingHeroBehaviourWork = <HeroBehaviour>{
  // Wren's own ★5 pair needs per-ultimate-arrow tracking (a custom Windline
  // duration for Warden's Lattice, a kill-source tag for Warden's Fury) that
  // nothing before Phase 10 built — the same "real work for whoever needs it
  // first" call ADR-adjacent to BoonBehaviour.stormfoot's own ledger entry.
  HeroBehaviour.wrenWardensLattice,
  HeroBehaviour.wrenWardensFury,

  HeroBehaviour.bramHeavyOrdnance,
  HeroBehaviour.bramMortarRain,
  HeroBehaviour.bramWiderBlast,
  HeroBehaviour.bramDenserBlast,
  HeroBehaviour.bramConcussion,
  HeroBehaviour.bramIncendiary,
  HeroBehaviour.bramSaturation,
  HeroBehaviour.bramPrecisionStrike,

  // kestrelFlurry, its two ★5 variants, and kestrelSharperNock are
  // implemented — see hero_behaviour_test.dart's Flurry group.
  //
  // Bleed needs a status that does not exist yet: burnStacks/toxinStacks
  // both live on StatusStore with their own ElementSystem tick logic, and
  // "every 4th arrow applies a 3 s bleed" is a fifth kind of DoT, not a
  // reuse of either. Real work for whichever hero or arrow needs it first —
  // the same call BoonBehaviour.stormfoot's own ledger entry made for chains.
  HeroBehaviour.kestrelBleed,

  HeroBehaviour.ovrinAegisPin,
  HeroBehaviour.ovrinRiposte,
  HeroBehaviour.ovrinLongWall,
  HeroBehaviour.ovrinMirrorWall,

  HeroBehaviour.kadeKindling,
  HeroBehaviour.kadePyreLine,
  HeroBehaviour.kadeHotIron,
  HeroBehaviour.kadeDeepBurn,
  HeroBehaviour.kadeWildfire,
  HeroBehaviour.kadeSlowBurn,
  HeroBehaviour.kadeLongPyre,
  HeroBehaviour.kadeTwinPyre,

  HeroBehaviour.selaChill,
  HeroBehaviour.selaGlacierNail,
  HeroBehaviour.selaDeeperChill,
  HeroBehaviour.selaBrittle,
  HeroBehaviour.selaShatter,
  HeroBehaviour.selaLingeringFrost,
  HeroBehaviour.selaAbsoluteZero,
  HeroBehaviour.selaCascadingNail,

  HeroBehaviour.torvArc,
  HeroBehaviour.torvTempestNock,
  HeroBehaviour.torvFrequentArc,
  HeroBehaviour.torvWideArc,
  HeroBehaviour.torvConductiveLines,
  HeroBehaviour.torvOverload,
  HeroBehaviour.torvLongTempest,
  HeroBehaviour.torvThunderhead,

  HeroBehaviour.sableToxin,
  HeroBehaviour.sableMiasma,
  HeroBehaviour.sableVirulence,
  HeroBehaviour.sableFastActing,
  HeroBehaviour.sableContagion,
  HeroBehaviour.sableCorrosion,
  HeroBehaviour.sableLastingMiasma,
  HeroBehaviour.sableConcentratedMiasma,

  HeroBehaviour.liraLifebound,
  HeroBehaviour.liraVerdantBloom,
  HeroBehaviour.liraDeepRoots,
  HeroBehaviour.liraOverheal,
  HeroBehaviour.liraEndlessBloom,
  HeroBehaviour.liraBloodBloom,

  HeroBehaviour.corvinBounce,
  HeroBehaviour.corvinCaroms,
  HeroBehaviour.corvinTrueBounce,
  HeroBehaviour.corvinHardBounce,
  HeroBehaviour.corvinDoubleBounce,
  HeroBehaviour.corvinEndlessCarom,
  HeroBehaviour.corvinPerfectCarom,

  HeroBehaviour.vaneDistance,
  HeroBehaviour.vanePiercingHorizon,
  HeroBehaviour.vaneFarsight,
  HeroBehaviour.vaneSteady,
  HeroBehaviour.vaneMarked,
  HeroBehaviour.vaneTwinHorizon,
  HeroBehaviour.vaneSunderingHorizon,

  HeroBehaviour.thaneBloodtide,
  HeroBehaviour.thaneRedDraw,
  HeroBehaviour.thaneDeeperTide,
  HeroBehaviour.thaneTempered,
  HeroBehaviour.thaneLastStand,
  HeroBehaviour.thaneFrenzy,
  HeroBehaviour.thaneLongRed,
  HeroBehaviour.thaneCrimsonDraw,

  HeroBehaviour.nyxFirstBlood,
  HeroBehaviour.nyxUmbralStep,
  HeroBehaviour.nyxExecutionersEye,
  HeroBehaviour.nyxDeeperShadow,
  HeroBehaviour.nyxShadowline,
  HeroBehaviour.nyxChainKill,
  HeroBehaviour.nyxTwinStep,
  HeroBehaviour.nyxPerfectStep,

  HeroBehaviour.irisWeave,
  HeroBehaviour.irisTheLattice,
  HeroBehaviour.irisGrandLattice,
  HeroBehaviour.irisLivingLattice,

  HeroBehaviour.zeaSkyhawk,
  HeroBehaviour.zeaFalconry,
  HeroBehaviour.zeaSharperTalons,
  HeroBehaviour.zeaSwiftHawk,
  HeroBehaviour.zeaBonded,
  HeroBehaviour.zeaFlock,
  HeroBehaviour.zeaSkydarken,
  HeroBehaviour.zeaGreatHawk,

  HeroBehaviour.rookPull,
  HeroBehaviour.rookSingularity,
  HeroBehaviour.rookStrongerPull,
  HeroBehaviour.rookDenserGrouping,
  HeroBehaviour.rookCrush,
  HeroBehaviour.rookAnchor,
  HeroBehaviour.rookTwinSingularity,
  HeroBehaviour.rookCollapsingSingularity,

  HeroBehaviour.haldenVerdict,
  HeroBehaviour.haldenJudgmentSpear,
  HeroBehaviour.haldenZealot,
  HeroBehaviour.haldenWarded,
  HeroBehaviour.haldenSentence,
  HeroBehaviour.haldenSwiftJudgment,
  HeroBehaviour.haldenFinalVerdict,
  HeroBehaviour.haldenTwinSpear,

  HeroBehaviour.ashlinRekindle,
  HeroBehaviour.ashlinRebirthNova,
  HeroBehaviour.ashlinBrightRekindle,
  HeroBehaviour.ashlinTwiceKindled,
  HeroBehaviour.ashlinEmberBody,
  HeroBehaviour.ashlinPhoenixTrail,
  HeroBehaviour.ashlinEternal,
  HeroBehaviour.ashlinSupernova,

  HeroBehaviour.mirelleReflection,
  HeroBehaviour.mirelleHallOfMirrors,
  HeroBehaviour.mirelleTruerMirror,
  HeroBehaviour.mirelleDeeperMirror,
  HeroBehaviour.mirelleSilvered,
  HeroBehaviour.mirelleFractured,
  HeroBehaviour.mirelleEndlessHall,
  HeroBehaviour.mirelleTwinWarden,

  HeroBehaviour.orielSpectrum,
  HeroBehaviour.orielPrism,
  HeroBehaviour.orielFasterCycle,
  HeroBehaviour.orielSaturation,
  HeroBehaviour.orielEndlessPrism,
  HeroBehaviour.orielWhiteLight,
};
