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
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/hero_runtime.dart';
import 'package:quiverfall/game/sim/elements.dart';
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
  final HeroDefinition kade = heroes.byArchetype(HeroArchetype.kade)!;
  final HeroDefinition sela = heroes.byArchetype(HeroArchetype.sela)!;
  final HeroDefinition sable = heroes.byArchetype(HeroArchetype.sable)!;
  final HeroDefinition nyx = heroes.byArchetype(HeroArchetype.nyx)!;
  final HeroDefinition oriel = heroes.byArchetype(HeroArchetype.oriel)!;
  final HeroDefinition vane = heroes.byArchetype(HeroArchetype.vane)!;
  final HeroDefinition halden = heroes.byArchetype(HeroArchetype.halden)!;
  final HeroDefinition lira = heroes.byArchetype(HeroArchetype.lira)!;
  final HeroDefinition bram = heroes.byArchetype(HeroArchetype.bram)!;
  final HeroDefinition thane = heroes.byArchetype(HeroArchetype.thane)!;
  final HeroDefinition mirelle = heroes.byArchetype(HeroArchetype.mirelle)!;
  final HeroDefinition torv = heroes.byArchetype(HeroArchetype.torv)!;
  final HeroDefinition rook = heroes.byArchetype(HeroArchetype.rook)!;
  final HeroDefinition iris = heroes.byArchetype(HeroArchetype.iris)!;
  final ArrowDefinition ashShaft = arrows.byArchetype(ArrowArchetype.ashShaft)!;

  /// A live world carrying [hero] and Ash Shaft, with a stationary target due
  /// east of the player — the neutral arrow, so nothing here is ever the
  /// arrow's own element rather than the hero's.
  ({SimWorld world, int target}) heroArena(HeroDefinition hero) {
    final SimWorld world = SimWorld(seed: 11, content: content)
      ..autoFire = true;
    world.spawnPlayer(4.0, 4.5);
    HeroLoadoutResolver.apply(
      world,
      hero,
      HeroState(heroId: hero.key),
      ashShaft,
      const ArrowInstance(arrowId: 'ash_shaft'),
    );
    final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
    world.enemies.speedScale[mote] = 0;
    world.entities.maxHealth[mote] = 1e9;
    world.entities.health[mote] = 1e9;
    return (world: world, target: mote);
  }

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
    world.enemies.speedScale[mote] = 0;
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
    world.enemies.speedScale[mote] = 0;
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
      // The target sits 8 u away; at 14 u/s the arrow alone needs ~34 ticks
      // to arrive, before a hit can land at all.
      run(a.world, 60);
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

  group('the three innate elements — same numbers as an arrow\'s own', () {
    test('Kindling applies Burn on a Tier III hit, never before', () {
      final ({SimWorld world, int target}) a = heroArena(kade);
      final InputSnapshot idle = InputSnapshot();

      // Tier I fires immediately: Kindling must not have applied yet.
      a.world.tick(idle);
      expect(a.world.status.burnStacks[a.target], 0);

      // Run out to Tier III (1.10 s), plus the travel time a frozen target 8 u
      // away actually costs (~0.6 s more) before a hit can land at all.
      for (int t = 0; t < 240; t++) {
        a.world.tick(idle);
      }
      expect(a.world.status.burnStacks[a.target], greaterThan(0));
    });

    test('an Emberhead arrow does not double-stack Burn under Kindling', () {
      final ArrowDefinition emberhead =
          arrows.byArchetype(ArrowArchetype.emberhead)!;
      final SimWorld world = SimWorld(seed: 11, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        kade,
        const HeroState(heroId: 'kade'),
        emberhead,
        const ArrowInstance(arrowId: 'emberhead'),
      );
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
      }
      // ElementTuning.burnMaxStacks — one hit cannot exceed it regardless of
      // how many sources tried to apply Burn on that same hit.
      expect(world.status.burnStacks[mote], lessThanOrEqualTo(2));
    });

    /// Runs [world] until its first `damageDealt` event — an arrow spends
    /// real travel time crossing to a distant target (8 u at 14 u/s is ~34
    /// ticks), so checking status state after a single tick catches the shot
    /// leaving the bow, not the shot landing.
    void runUntilFirstHit(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        if (world.events.countOf(SimEventType.damageDealt) > 0) return;
      }
      fail('no hit landed within 120 ticks');
    }

    test('Chill stacks 12 per hit and freezes at 100, +30 % damage while frozen', () {
      final ({SimWorld world, int target}) a = heroArena(sela);
      // Tier I fires immediately — Chill has no tier gate.
      runUntilFirstHit(a.world);
      // ElementSystem's decay pass runs later in the same tick the hit
      // landed (chillDecayPerSecond = 8/s, one tick's worth is ~0.13), so
      // this reads a hair under the raw +12 application rather than exactly
      // it.
      expect(a.world.status.chill[a.target], closeTo(12.0, 0.2));
      expect(a.world.status.isFrozen(a.target), isFalse);

      // 9 hits reach 108, past the 100 threshold, and reset to 0 on freezing.
      // Momentum/AI cannot touch this mote (speedScale 0, isMoving false), so
      // driving idle ticks alone is enough for auto-fire to land every hit.
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 480 && !a.world.status.isFrozen(a.target); t++) {
        a.world.tick(idle);
      }
      expect(a.world.status.isFrozen(a.target), isTrue);
      expect(
        a.world.status.damageTakenBonus(a.target),
        closeTo(0.30, 1e-9),
      );
    });

    test('Toxin stacks once per hit, capped at 10, and reduces healing 5 % per stack', () {
      final ({SimWorld world, int target}) a = heroArena(sable);
      runUntilFirstHit(a.world);
      expect(a.world.status.toxinStacks[a.target], 1);
      expect(
        a.world.status.healingMultiplier(a.target),
        closeTo(0.95, 1e-9),
      );

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 480; t++) {
        a.world.tick(idle);
      }
      expect(a.world.status.toxinStacks[a.target], 10);
      expect(
        a.world.status.healingMultiplier(a.target),
        closeTo(0.50, 1e-9),
      );
    });
  });

  group('First Blood', () {
    ({SimWorld world, int target}) nyxArena({
      double targetHealthFraction = 1.0,
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 21, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        nyx,
        HeroState(heroId: 'nyx', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1000;
      world.entities.health[mote] = 1000 * targetHealthFraction;
      return (world: world, target: mote);
    }

    /// The `valueA` (damage dealt) of the first `damageDealt` event, or null
    /// if no hit lands in time.
    double? firstDamageDealt(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.damageDealt) {
            return world.events.valueAAt(e);
          }
        }
      }
      return null;
    }

    test('deals +70 % damage to a target above 90 % HP', () {
      final double? full = firstDamageDealt(nyxArena().world);
      final double? mid =
          firstDamageDealt(nyxArena(targetHealthFraction: 0.60).world);
      expect(full, isNotNull);
      expect(mid, isNotNull);
      expect(full! / mid!, closeTo(1.70, 0.01));
    });

    test("Executioner's Eye (★1a) adds the same fight below 20 % HP, at its own +35 %", () {
      final double? low = firstDamageDealt(nyxArena(
        targetHealthFraction: 0.10,
        stars: 1,
        talentChoices: <String, String>{'1': 'a'},
      ).world);
      final double? mid = firstDamageDealt(nyxArena(
        targetHealthFraction: 0.60,
        stars: 1,
        talentChoices: <String, String>{'1': 'a'},
      ).world);
      expect(low, isNotNull);
      expect(mid, isNotNull);
      expect(low! / mid!, closeTo(1.35, 0.01));
    });

    test('without the ★1a talent, low HP gets neither bonus', () {
      final double? low =
          firstDamageDealt(nyxArena(targetHealthFraction: 0.10).world);
      final double? mid =
          firstDamageDealt(nyxArena(targetHealthFraction: 0.60).world);
      expect(low, isNotNull);
      expect(mid, isNotNull);
      expect(low! / mid!, closeTo(1.0, 0.01));
    });

    test('a kill grants +25 % move speed for 1.5 s, then reverts', () {
      // Two identical worlds driven by the same movement input in lockstep,
      // one with the burst forced on. Momentum accrues identically in both,
      // so comparing their velocities isolates First Blood's own
      // contribution — a single world's "before vs. long after" velocity
      // would also pick up Momentum's own speed bonus building up over the
      // many ticks it takes the burst to expire.
      SimWorld buildWorld() {
        final SimWorld world = SimWorld(seed: 22, content: content)
          ..autoFire = false;
        world.spawnPlayer(4.0, 4.5);
        HeroLoadoutResolver.apply(
          world,
          nyx,
          const HeroState(heroId: 'nyx'),
          ashShaft,
          const ArrowInstance(arrowId: 'ash_shaft'),
        );
        return world;
      }

      final SimWorld boosted = buildWorld();
      final SimWorld unboosted = buildWorld();
      final InputSnapshot moving = InputSnapshot()..set(1.0, 0.0);

      boosted.hero.firstBloodSpeedRemaining =
          HeroRuntime.firstBloodSpeedDuration;
      boosted.tick(moving);
      unboosted.tick(moving);
      expect(
        boosted.entities.velX[boosted.player.index] /
            unboosted.entities.velX[unboosted.player.index],
        closeTo(1.25, 0.01),
      );

      for (int t = 0; t < 100; t++) {
        boosted.tick(moving);
        unboosted.tick(moving);
      }
      expect(boosted.hero.firstBloodSpeedRemaining, 0);
      expect(
        boosted.entities.velX[boosted.player.index] /
            unboosted.entities.velX[unboosted.player.index],
        closeTo(1.0, 0.01),
      );
    });

    test("a real kill triggers the burst via AiSystem's death pass", () {
      final SimWorld world = SimWorld(seed: 23, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        nyx,
        const HeroState(heroId: 'nyx'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.entities.maxHealth[mote] = 1;
      world.entities.health[mote] = 1; // one hit kills it

      expect(world.hero.firstBloodSpeedRemaining, 0);
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0;
          t < 120 && world.hero.firstBloodSpeedRemaining == 0;
          t++) {
        world.tick(idle);
      }
      expect(world.hero.firstBloodSpeedRemaining, greaterThan(0));
    });
  });

  group('Spectrum and Prism', () {
    ({SimWorld world, int target}) orielArena() {
      final SimWorld world = SimWorld(seed: 31, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        oriel,
        const HeroState(heroId: 'oriel'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;
      return (world: world, target: mote);
    }

    /// Elements of the first [count] arrows fired, in firing order.
    List<int> firstArrowElements(SimWorld world, int count) {
      final List<int> out = <int>[];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 600 && out.length < count; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) != SimEventType.arrowFired) continue;
          out.add(world.projectiles.element[world.events.entityAAt(e)]);
        }
        world.events.clear();
      }
      return out;
    }

    test('Spectrum cycles Ember -> Frost -> Storm -> Toxin, one per shot', () {
      final List<int> elements = firstArrowElements(orielArena().world, 8);
      expect(elements, hasLength(8));
      for (int i = 0; i < 8; i++) {
        expect(elements[i], i % 4, reason: 'arrow $i');
      }
      // Declaration order in SimElement is the cycle order, not incidental.
      expect(SimElement.ember.index, 0);
      expect(SimElement.frost.index, 1);
      expect(SimElement.storm.index, 2);
      expect(SimElement.toxin.index, 3);
    });

    test('Prism carries all four elements at once for its window', () {
      final ({SimWorld world, int target}) a = orielArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.prismRemaining, closeTo(HeroRuntime.prismDuration, 1e-9));

      final InputSnapshot idle = InputSnapshot();
      bool sawAllFour = false;
      for (int t = 0; t < 60; t++) {
        a.world.tick(idle);
        for (int e = 0; e < a.world.events.count; e++) {
          if (a.world.events.typeAt(e) != SimEventType.arrowFired) continue;
          final int slot = a.world.events.entityAAt(e);
          if (a.world.projectiles.elementMask[slot] == 0xF) sawAllFour = true;
        }
        a.world.events.clear();
      }
      expect(sawAllFour, isTrue);
    });

    test('Endless Prism (★5a) extends the window to 16 s', () {
      final ({SimWorld world, int target}) a = orielArena();
      HeroLoadoutResolver.apply(
        a.world,
        oriel,
        const HeroState(
          heroId: 'oriel',
          stars: 5,
          talentChoices: <String, String>{'5': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.prismRemaining, closeTo(16.0, 1e-9));
    });
  });

  group('Distance and Piercing Horizon', () {
    test('the per-unit bonus and its cap compose exactly, via combat.damageSumFor', () {
      final SimWorld world = SimWorld(seed: 41, content: content);
      world.spawnPlayer(0, 0);
      HeroLoadoutResolver.apply(
        world,
        vane,
        const HeroState(heroId: 'vane'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      // +6 %/u, uncapped at 5 u (0.30 < the 0.90 cap).
      expect(
        world.combat.damageSumFor(
          targetHealthFraction: 1.0,
          shotDistance: 5.0,
          targetId: -1,
        ),
        closeTo(0.30, 1e-9),
      );
      // Capped at +90 % well past the point 6 %/u alone would exceed it.
      expect(
        world.combat.damageSumFor(
          targetHealthFraction: 1.0,
          shotDistance: 40.0,
          targetId: -1,
        ),
        closeTo(0.90, 1e-9),
      );
    });

    test('Farsight (★1a) raises the cap to +130 %', () {
      final SimWorld world = SimWorld(seed: 41, content: content);
      world.spawnPlayer(0, 0);
      HeroLoadoutResolver.apply(
        world,
        vane,
        const HeroState(
          heroId: 'vane',
          stars: 1,
          talentChoices: <String, String>{'1': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      expect(
        world.combat.damageSumFor(
          targetHealthFraction: 1.0,
          shotDistance: 40.0,
          targetId: -1,
        ),
        closeTo(1.30, 1e-9),
      );
    });

    /// The `valueA` of the first `damageDealt` event against a target placed
    /// [distance] units east of the player.
    double? firstDamageAtDistance(
      double distance, {
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 42, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        vane,
        HeroState(heroId: 'vane', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int mote =
          world.spawnEnemy(EnemyArchetype.mote, 4.0 + distance, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.damageDealt) {
            return world.events.valueAAt(e);
          }
        }
      }
      return null;
    }

    test('Steady (★1b) removes the close-range penalty at the same distance', () {
      const double distance = 1.5; // well under the 3 u threshold
      // Both sides at ★1 so heroAtk's star scaling is identical — the only
      // difference between them is which talent (if any) that star bought.
      final double? penalized = firstDamageAtDistance(distance, stars: 1);
      final double? steady = firstDamageAtDistance(
        distance,
        stars: 1,
        talentChoices: <String, String>{'1': 'b'},
      );
      expect(penalized, isNotNull);
      expect(steady, isNotNull);

      // Both share the same per-unit term at this distance (0.06 * 1.5 =
      // 0.09); only the -30 % close-range term differs between them.
      const double perUnit = 0.06 * distance;
      const double expectedRatio =
          (1.0 + perUnit) / (1.0 + perUnit - 0.30);
      expect(steady! / penalized!, closeTo(expectedRatio, 0.03));
    });

    test('Piercing Horizon: one Tier III arrow at 600 % with very high pierce', () {
      final SimWorld world = SimWorld(seed: 43, content: content)
        ..autoFire = false;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        vane,
        const HeroState(heroId: 'vane'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      world.hero.ultimateCharge = 1.0;
      world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final List<int> slots = <int>[
        for (int e = 0; e < world.events.count; e++)
          if (world.events.typeAt(e) == SimEventType.arrowFired)
            world.events.entityAAt(e),
      ];
      expect(slots, hasLength(1));
      final int slot = slots.single;
      expect(world.projectiles.drawTier[slot], DrawTier.three.index);
      expect(
        world.projectiles.damage[slot],
        closeTo(world.playerAttack * 6.0, 1e-9),
      );
      expect(world.projectiles.pierceRemaining[slot], greaterThan(1000));
    });

    test('Twin Horizon (★5a): two lances 90° apart', () {
      final SimWorld world = SimWorld(seed: 44, content: content)
        ..autoFire = false;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        vane,
        const HeroState(
          heroId: 'vane',
          stars: 5,
          talentChoices: <String, String>{'5': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      world.hero.ultimateCharge = 1.0;
      world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final List<int> slots = <int>[
        for (int e = 0; e < world.events.count; e++)
          if (world.events.typeAt(e) == SimEventType.arrowFired)
            world.events.entityAAt(e),
      ];
      expect(slots, hasLength(2));
      final double a0 = math.atan2(
          world.entities.velY[slots[0]], world.entities.velX[slots[0]]);
      final double a1 = math.atan2(
          world.entities.velY[slots[1]], world.entities.velX[slots[1]]);
      expect((a1 - a0).abs(), closeTo(math.pi / 2, 1e-6));
    });

    test('Sundering Horizon (★5b): one line at 1,400 % instead of 600 %', () {
      final SimWorld world = SimWorld(seed: 45, content: content)
        ..autoFire = false;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        vane,
        const HeroState(
          heroId: 'vane',
          stars: 5,
          talentChoices: <String, String>{'5': 'b'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      world.hero.ultimateCharge = 1.0;
      world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final List<int> slots = <int>[
        for (int e = 0; e < world.events.count; e++)
          if (world.events.typeAt(e) == SimEventType.arrowFired)
            world.events.entityAAt(e),
      ];
      expect(slots, hasLength(1));
      expect(
        world.projectiles.damage[slots.single],
        closeTo(world.playerAttack * 14.0, 1e-9),
      );
    });
  });

  group('Verdict and Judgment Spear', () {
    ({SimWorld world, int target}) haldenArena({bool elite = false}) {
      final SimWorld world = SimWorld(seed: 51, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        halden,
        const HeroState(heroId: 'halden'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.enemies.elite[mote] = elite ? 1 : 0;
      world.entities.maxHealth[mote] = 1000;
      world.entities.health[mote] = 1000;
      return (world: world, target: mote);
    }

    double? firstDamageDealt(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.damageDealt) {
            return world.events.valueAAt(e);
          }
        }
      }
      return null;
    }

    test('Verdict: +40 % damage to an elite target, nothing to a common one', () {
      final double? common = firstDamageDealt(haldenArena().world);
      final double? elite = firstDamageDealt(haldenArena(elite: true).world);
      expect(common, isNotNull);
      expect(elite, isNotNull);
      expect(elite! / common!, closeTo(1.40, 0.01));
    });

    test('Judgment Spear: a single Tier III strike at 900 %', () {
      final ({SimWorld world, int target}) a = haldenArena()
        ..world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final List<int> slots = <int>[
        for (int e = 0; e < a.world.events.count; e++)
          if (a.world.events.typeAt(e) == SimEventType.arrowFired)
            a.world.events.entityAAt(e),
      ];
      expect(slots, hasLength(1));
      expect(a.world.projectiles.drawTier[slots.single], DrawTier.three.index);
      expect(
        a.world.projectiles.damage[slots.single],
        closeTo(a.world.playerAttack * 9.0, 1e-9),
      );
    });

    test('below 40 % HP the strike doubles to 1,800 %', () {
      final ({SimWorld world, int target}) a = haldenArena()
        ..world.autoFire = false;
      a.world.entities.health[a.target] = 1000 * 0.35;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final int slot = <int>[
        for (int e = 0; e < a.world.events.count; e++)
          if (a.world.events.typeAt(e) == SimEventType.arrowFired)
            a.world.events.entityAAt(e),
      ].single;
      expect(
        a.world.projectiles.damage[slot],
        closeTo(a.world.playerAttack * 18.0, 1e-9),
      );
    });

    test('Final Verdict (★5a): below 25 % HP the Spear executes at 3,000 %', () {
      final ({SimWorld world, int target}) a = haldenArena()
        ..world.autoFire = false;
      HeroLoadoutResolver.apply(
        a.world,
        halden,
        const HeroState(
          heroId: 'halden',
          stars: 5,
          talentChoices: <String, String>{'5': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      a.world.entities.health[a.target] = 1000 * 0.20;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final int slot = <int>[
        for (int e = 0; e < a.world.events.count; e++)
          if (a.world.events.typeAt(e) == SimEventType.arrowFired)
            a.world.events.entityAAt(e),
      ].single;
      expect(
        a.world.projectiles.damage[slot],
        closeTo(a.world.playerAttack * 30.0, 1e-9),
      );
    });

    test('Twin Spear (★5b): 2 spears at 600 % each, regardless of HP', () {
      final ({SimWorld world, int target}) a = haldenArena()
        ..world.autoFire = false;
      HeroLoadoutResolver.apply(
        a.world,
        halden,
        const HeroState(
          heroId: 'halden',
          stars: 5,
          talentChoices: <String, String>{'5': 'b'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      // Below Final Verdict's own threshold, to prove Twin Spear ignores it.
      a.world.entities.health[a.target] = 1000 * 0.10;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final List<int> slots = <int>[
        for (int e = 0; e < a.world.events.count; e++)
          if (a.world.events.typeAt(e) == SimEventType.arrowFired)
            a.world.events.entityAAt(e),
      ];
      expect(slots, hasLength(2));
      for (final int slot in slots) {
        expect(
          a.world.projectiles.damage[slot],
          closeTo(a.world.playerAttack * 6.0, 1e-9),
        );
      }
    });
  });

  group('Lifebound and Verdant Bloom', () {
    ({SimWorld world, int target}) liraArena() {
      final SimWorld world = SimWorld(seed: 61, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        lira,
        const HeroState(heroId: 'lira'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      world.entities.health[world.player.index] = 50; // room to observe healing
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;
      return (world: world, target: mote);
    }

    /// Runs until a `damageDealt` event lands, returning the health healed
    /// over that span.
    double? healedByFirstHit(SimWorld world) {
      final int p = world.player.index;
      final double before = world.entities.health[p];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        if (world.events.countOf(SimEventType.damageDealt) > 0) {
          return world.entities.health[p] - before;
        }
      }
      return null;
    }

    test("Lifebound heals 4 % of a Tier I hit's damage", () {
      final ({SimWorld world, int target}) a = liraArena();
      final double? healed = healedByFirstHit(a.world);
      expect(healed, isNotNull);
      expect(healed!, closeTo(a.world.playerAttack * 1.0 * 0.04, 0.5));
    });

    test('the +2 % Tier III bonus lifts Lifebound to 6 % of the (larger) hit', () {
      final ({SimWorld world, int target}) a = liraArena();
      a.world.playerDraw.drawSeconds = 999; // force Tier III immediately
      final double? healed = healedByFirstHit(a.world);
      expect(healed, isNotNull);
      expect(
        healed!,
        closeTo(a.world.playerAttack * DrawTier.three.damageMultiplier * 0.06, 1.0),
      );
    });

    test('Deep Roots (★1a): base lifesteal rises to 6 % even at Tier I', () {
      final SimWorld world = SimWorld(seed: 61, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        lira,
        const HeroState(
          heroId: 'lira',
          stars: 1,
          talentChoices: <String, String>{'1': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      world.entities.health[world.player.index] = 50;
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;

      final double? healed = healedByFirstHit(world);
      expect(healed, isNotNull);
      expect(healed!, closeTo(world.playerAttack * 1.0 * 0.06, 0.5));
    });

    test("Bloom Speed (★1b) raises the Ultimate's charge rate by 25 %", () {
      // Both at ★1 so heroAtk/heroFireRate's star scaling (ADR 0006) is
      // identical on both sides — the only difference is which branch (if
      // any) that star bought.
      final SimWorld baseline = SimWorld(seed: 61, content: content);
      baseline.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        baseline,
        lira,
        const HeroState(heroId: 'lira', stars: 1),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      final SimWorld boosted = SimWorld(seed: 61, content: content);
      boosted.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        boosted,
        lira,
        const HeroState(
          heroId: 'lira',
          stars: 1,
          talentChoices: <String, String>{'1': 'b'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      expect(
        boosted.hero.chargePerDamage,
        closeTo(baseline.hero.chargePerDamage * 1.25, 1e-12),
      );
    });

    test('Verdant Bloom: heals 40 % over 4 s and grants +25 % damage while active', () {
      final ({SimWorld world, int target}) a = liraArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.bloomRemaining, closeTo(4.0, 1e-9));
      expect(
        a.world.hero.bloomHealPerSecond,
        closeTo(0.40 / 4.0, 1e-9),
      );
      expect(a.world.hero.bloomDamageBonus, closeTo(0.25, 1e-9));

      // One tick's worth of the heal rate lands on the next tick.
      final int p = a.world.player.index;
      final double maxHp = a.world.entities.maxHealth[p];
      final double before = a.world.entities.health[p];
      a.world.tick(InputSnapshot());
      final double healedOneTick = a.world.entities.health[p] - before;
      expect(
        healedOneTick,
        closeTo(maxHp * (0.40 / 4.0) * (1 / 60), 1e-6),
      );
    });

    test('Endless Bloom (★5a): 8 s at 60 % instead of 4 s at 40 %', () {
      final ({SimWorld world, int target}) a = liraArena();
      HeroLoadoutResolver.apply(
        a.world,
        lira,
        const HeroState(
          heroId: 'lira',
          stars: 5,
          talentChoices: <String, String>{'5': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.bloomRemaining, closeTo(8.0, 1e-9));
      expect(a.world.hero.bloomHealPerSecond, closeTo(0.60 / 8.0, 1e-9));
    });

    test('Blood Bloom (★5b): no healing, +80 % damage instead of +25 %', () {
      final ({SimWorld world, int target}) a = liraArena();
      HeroLoadoutResolver.apply(
        a.world,
        lira,
        const HeroState(
          heroId: 'lira',
          stars: 5,
          talentChoices: <String, String>{'5': 'b'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.bloomHealPerSecond, 0);
      expect(a.world.hero.bloomDamageBonus, closeTo(0.80, 1e-9));
    });
  });

  group('Heavy Ordnance', () {
    /// A primary target 8 u east of the player, and a second, undamaged
    /// "nearby" enemy [offset] u further east still — far enough along the
    /// same line that a non-piercing Tier I arrow can only ever reach it
    /// through splash, never a direct hit.
    ({SimWorld world, int primary, int nearby}) bramArena({
      double offset = 1.0,
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 71, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        bram,
        HeroState(heroId: 'bram', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int primary = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[primary] = 0;
      world.entities.maxHealth[primary] = 1e9;
      world.entities.health[primary] = 1e9;

      final int nearby =
          world.spawnEnemy(EnemyArchetype.mote, 12.0 + offset, 4.5);
      world.enemies.speedScale[nearby] = 0;
      world.entities.maxHealth[nearby] = 1e9;
      world.entities.health[nearby] = 1e9;
      return (world: world, primary: primary, nearby: nearby);
    }

    /// Runs until the primary target's first hit, returning the damage each
    /// of the two enemies took over that span.
    ({double primaryDamage, double nearbyDamage})? damageFromFirstHit(
      SimWorld world,
      int primary,
      int nearby,
    ) {
      final double primaryBefore = world.entities.health[primary];
      final double nearbyBefore = world.entities.health[nearby];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        if (world.events.countOf(SimEventType.damageDealt) > 0) {
          return (
            primaryDamage: primaryBefore - world.entities.health[primary],
            nearbyDamage: nearbyBefore - world.entities.health[nearby],
          );
        }
      }
      return null;
    }

    test('splashes 45 % of the direct hit to a nearby enemy within 1.6 u', () {
      final ({SimWorld world, int primary, int nearby}) a = bramArena();
      final ({double primaryDamage, double nearbyDamage})? result =
          damageFromFirstHit(a.world, a.primary, a.nearby);
      expect(result, isNotNull);
      expect(
        result!.nearbyDamage,
        closeTo(result.primaryDamage * 0.45, 0.5),
      );
    });

    test('does nothing beyond 1.6 u without Wider Blast', () {
      final ({SimWorld world, int primary, int nearby}) a =
          bramArena(offset: 2.0);
      final ({double primaryDamage, double nearbyDamage})? result =
          damageFromFirstHit(a.world, a.primary, a.nearby);
      expect(result, isNotNull);
      expect(result!.nearbyDamage, 0);
    });

    test('Wider Blast (★1a): reaches 2.2 u', () {
      final ({SimWorld world, int primary, int nearby}) a = bramArena(
        offset: 2.0,
        stars: 1,
        talentChoices: <String, String>{'1': 'a'},
      );
      final ({double primaryDamage, double nearbyDamage})? result =
          damageFromFirstHit(a.world, a.primary, a.nearby);
      expect(result, isNotNull);
      expect(
        result!.nearbyDamage,
        closeTo(result.primaryDamage * 0.45, 0.5),
      );
    });

    test('Denser Blast (★1b): 65 % splash, shrunk to a 1.2 u radius', () {
      final ({SimWorld world, int primary, int nearby}) close = bramArena(
        offset: 0.5,
        stars: 1,
        talentChoices: <String, String>{'1': 'b'},
      );
      final ({double primaryDamage, double nearbyDamage})? result =
          damageFromFirstHit(close.world, close.primary, close.nearby);
      expect(result, isNotNull);
      expect(
        result!.nearbyDamage,
        closeTo(result.primaryDamage * 0.65, 0.5),
      );

      final ({SimWorld world, int primary, int nearby}) far = bramArena(
        offset: 1.4, // inside the base 1.6 u radius, outside Denser's 1.2 u
        stars: 1,
        talentChoices: <String, String>{'1': 'b'},
      );
      final ({double primaryDamage, double nearbyDamage})? beyond =
          damageFromFirstHit(far.world, far.primary, far.nearby);
      expect(beyond, isNotNull);
      expect(beyond!.nearbyDamage, 0);
    });
  });

  group('Bloodtide and Red Draw', () {
    ({SimWorld world, int target}) thaneArena({
      double playerHealthFraction = 1.0,
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 81, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        thane,
        HeroState(heroId: 'thane', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int p = world.player.index;
      world.entities.health[p] = world.entities.maxHealth[p] * playerHealthFraction;
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;
      return (world: world, target: mote);
    }

    double? firstDamageDealt(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.damageDealt) {
            return world.events.valueAAt(e);
          }
        }
      }
      return null;
    }

    test('deals +1.2 % damage per 1 % missing HP', () {
      final double? full = firstDamageDealt(thaneArena().world);
      final double? half =
          firstDamageDealt(thaneArena(playerHealthFraction: 0.50).world);
      expect(full, isNotNull);
      expect(half, isNotNull);
      // Full HP: 0 % missing, no bonus. Half HP: 50 % missing * 1.2 = +60 %.
      expect(half! / full!, closeTo(1.60, 0.01));
    });

    test('caps at +85 %', () {
      final double? full = firstDamageDealt(thaneArena().world);
      // 90 % missing * 1.2 = 108 %, past the 85 % cap.
      final double? nearlyDead =
          firstDamageDealt(thaneArena(playerHealthFraction: 0.10).world);
      expect(full, isNotNull);
      expect(nearlyDead, isNotNull);
      expect(nearlyDead! / full!, closeTo(1.85, 0.01));
    });

    test('Deeper Tide (★1a): the cap rises to +120 %', () {
      // At 5 % HP (95 % missing), the raw formula wants +114 % — past the
      // base 85 % cap, but still under Deeper Tide's 120 %. Comparing the
      // same health fraction with and against the talent isolates exactly
      // the cap's own effect; both sides are ★1 so heroAtk's star scaling
      // matches too.
      final double? capped =
          firstDamageDealt(thaneArena(playerHealthFraction: 0.05, stars: 1).world);
      final double? uncapped = firstDamageDealt(thaneArena(
        playerHealthFraction: 0.05,
        stars: 1,
        talentChoices: <String, String>{'1': 'a'},
      ).world);
      expect(capped, isNotNull);
      expect(uncapped, isNotNull);
      // (1 + 1.14) / (1 + 0.85)
      expect(uncapped! / capped!, closeTo(2.14 / 1.85, 0.01));
    });

    test('Red Draw costs 20 % current HP and grants +120 % damage, +30 % fire rate for 6 s', () {
      final ({SimWorld world, int target}) a = thaneArena();
      final int p = a.world.player.index;
      final double before = a.world.entities.health[p];

      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.entities.health[p], closeTo(before * 0.80, 1e-6));
      expect(a.world.hero.redDrawRemaining, closeTo(6.0, 1e-9));
      expect(a.world.hero.redDrawDamageBonus, closeTo(1.20, 1e-9));
      expect(a.world.hero.redDrawFireRateMultiplier, closeTo(1.30, 1e-9));
    });

    test('Red Draw never drops the player below 1 HP', () {
      final ({SimWorld world, int target}) a = thaneArena();
      final int p = a.world.player.index;
      a.world.entities.health[p] = 1.0;

      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.entities.health[p], greaterThanOrEqualTo(1.0));
    });

    test('Long Red (★5a): the window lasts 10 s instead of 6', () {
      final ({SimWorld world, int target}) a =
          thaneArena(stars: 5, talentChoices: <String, String>{'5': 'a'});
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.redDrawRemaining, closeTo(10.0, 1e-9));
    });

    test('Crimson Draw (★5b): every shot is Tier III while Red Draw runs', () {
      final ({SimWorld world, int target}) a =
          thaneArena(stars: 5, talentChoices: <String, String>{'5': 'b'});
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      // The Draw meter itself must still read honestly right after — the
      // override is read-time only, same as Perfect Form and Flurry.
      expect(a.world.playerDraw.tier, DrawTier.one);

      final InputSnapshot idle = InputSnapshot();
      bool sawTierThree = false;
      for (int t = 0; t < 30; t++) {
        a.world.tick(idle);
        for (int e = 0; e < a.world.events.count; e++) {
          if (a.world.events.typeAt(e) == SimEventType.arrowFired &&
              a.world.events.valueAAt(e).round() == DrawTier.three.index) {
            sawTierThree = true;
          }
        }
        a.world.events.clear();
      }
      expect(sawTierThree, isTrue);
    });

    test('Last Stand (★3a): +40 % damage reduction below 25 % HP', () {
      final ({SimWorld world, int target}) full =
          thaneArena(stars: 3, talentChoices: <String, String>{'3': 'a'});
      final double atFullHealth = full.world.incomingDamageFactor;

      final ({SimWorld world, int target}) low = thaneArena(
        playerHealthFraction: 0.20,
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
      );
      final double atLowHealth = low.world.incomingDamageFactor;

      expect(atLowHealth / atFullHealth, closeTo(0.60, 0.01));
    });

    test('Frenzy (★3b): +50 % fire rate below 25 % HP', () {
      int arrowsOver(SimWorld world, int ticks) {
        int count = 0;
        final InputSnapshot idle = InputSnapshot();
        for (int t = 0; t < ticks; t++) {
          world.tick(idle);
          count += world.events.countOf(SimEventType.arrowFired);
          world.events.clear();
        }
        return count;
      }

      // Same ★3 on both sides so heroFireRate's star scaling is identical;
      // only the HP fraction (and so whether Frenzy's own condition is met)
      // differs. A long window keeps the shot counts stable against tick
      // rounding.
      final ({SimWorld world, int target}) low = thaneArena(
        playerHealthFraction: 0.20,
        stars: 3,
        talentChoices: <String, String>{'3': 'b'},
      );
      final ({SimWorld world, int target}) full =
          thaneArena(stars: 3, talentChoices: <String, String>{'3': 'b'});

      const int window = 600; // 10 s
      final int lowCount = arrowsOver(low.world, window);
      final int fullCount = arrowsOver(full.world, window);

      expect(lowCount / fullCount, closeTo(1.50, 0.05));
    });
  });

  group('Reflection', () {
    ({SimWorld world, int target}) mirelleArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 91, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        mirelle,
        HeroState(heroId: 'mirelle', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;
      return (world: world, target: mote);
    }

    /// (damage, angle) for every arrow fired over [ticks].
    List<({double damage, double angle})> arrowsOver(SimWorld world, int ticks) {
      final List<({double damage, double angle})> out =
          <({double damage, double angle})>[];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < ticks; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) != SimEventType.arrowFired) continue;
          final int slot = world.events.entityAAt(e);
          out.add((
            damage: world.projectiles.damage[slot],
            angle: math.atan2(
                world.entities.velY[slot], world.entities.velX[slot]),
          ));
        }
        world.events.clear();
      }
      return out;
    }

    test('duplicates roughly 25 % of shots, each duplicate at 85 % damage', () {
      final ({SimWorld world, int target}) a = mirelleArena();
      final List<({double damage, double angle})> arrows =
          arrowsOver(a.world, 3000);
      expect(arrows, isNotEmpty);

      final double fullDamage = a.world.playerAttack;
      // Every arrow's damage must be a power of 0.85 down from full — proof
      // the geometric cascade never exceeds the 4-arrow cap (a 5th
      // generation would read as fullDamage * 0.85^4, outside this set).
      final Set<double> allowedShares = <double>{1.0, 0.85, 0.85 * 0.85, 0.85 * 0.85 * 0.85};
      for (final ({double damage, double angle}) arrow in arrows) {
        final double share = arrow.damage / fullDamage;
        final bool matched =
            allowedShares.any((double s) => (s - share).abs() < 1e-6);
        expect(matched, isTrue, reason: 'unexpected damage share $share');
      }

      // More arrows landed than shots fired — duplication is actually
      // happening, not just declared.
      final int duplicates =
          arrows.where((({double damage, double angle}) a) => a.damage < fullDamage - 1e-6).length;
      expect(duplicates, greaterThan(0));
    });

    test('Truer Mirror (★1a) raises the chance, so duplicates happen more often', () {
      final ({SimWorld world, int target}) base = mirelleArena();
      final ({SimWorld world, int target}) truer = mirelleArena(
        stars: 1,
        talentChoices: <String, String>{'1': 'a'},
      );

      double duplicateFraction(SimWorld world) {
        final List<({double damage, double angle})> arrows =
            arrowsOver(world, 3000);
        final double fullDamage = world.playerAttack;
        final int duplicates = arrows
            .where((({double damage, double angle}) a) =>
                a.damage < fullDamage - 1e-6)
            .length;
        return duplicates / arrows.length;
      }

      expect(duplicateFraction(truer.world), greaterThan(duplicateFraction(base.world)));
    });

    test('Silvered (★3a): duplicates deal full damage, not 85 %', () {
      final ({SimWorld world, int target}) a = mirelleArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
      );
      final List<({double damage, double angle})> arrows =
          arrowsOver(a.world, 3000);
      expect(arrows, isNotEmpty);
      for (final ({double damage, double angle}) arrow in arrows) {
        expect(arrow.damage, closeTo(a.world.playerAttack, 1e-6));
      }
    });

    test('Fractured (★3b): some duplicates spread away from the original angle', () {
      final ({SimWorld world, int target}) a = mirelleArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'b'},
      );
      final List<({double damage, double angle})> arrows =
          arrowsOver(a.world, 3000);
      // The target sits due east of the player: an unspread shot's angle is
      // ~0. Fractured must produce at least one arrow measurably off that.
      final bool sawSpread =
          arrows.any((({double damage, double angle}) a) => a.angle.abs() > 0.05);
      expect(sawSpread, isTrue);
    });

    test('Deeper Mirror (★1b): raises the cap, so more arrows land per shot on average', () {
      final ({SimWorld world, int target}) base = mirelleArena();
      final ({SimWorld world, int target}) deeper = mirelleArena(
        stars: 1,
        talentChoices: <String, String>{'1': 'b'},
      );

      double arrowsPerShot(SimWorld world) {
        // A "shot" is any arrowFired whose damage equals the full share —
        // every duplicate cascade starts from exactly one of those.
        final List<({double damage, double angle})> arrows =
            arrowsOver(world, 6000);
        final double fullDamage = world.playerAttack;
        final int shots = arrows
            .where((({double damage, double angle}) a) =>
                (a.damage - fullDamage).abs() < 1e-6)
            .length;
        return arrows.length / shots;
      }

      expect(arrowsPerShot(deeper.world), greaterThan(arrowsPerShot(base.world)));
    });
  });

  group('Arc and Tempest Nock', () {
    /// A primary target 8 u east of the player, plus four more enemies
    /// clustered around it at 0.3/0.4/0.5/0.8 u — all off the y = 4.5 firing
    /// line, so a piercing arrow travelling along it never hits them
    /// directly. Chain damage is the only way any of the four ever take
    /// damage.
    ({SimWorld world, int primary, List<int> nearby}) torvArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 101, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        torv,
        HeroState(heroId: 'torv', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int primary = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[primary] = 0;
      world.entities.maxHealth[primary] = 1e9;
      world.entities.health[primary] = 1e9;

      final List<int> nearby = <int>[];
      for (final double offset in <double>[0.3, 0.4, 0.5, 0.8]) {
        final int e = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5 + offset);
        world.enemies.speedScale[e] = 0;
        world.entities.maxHealth[e] = 1e9;
        world.entities.health[e] = 1e9;
        nearby.add(e);
      }
      return (world: world, primary: primary, nearby: nearby);
    }

    test('every 5th arrow chains to the 3 nearest other enemies at 60 % damage', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = torvArena();
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 400; t++) {
        a.world.tick(idle);
      }

      final double primaryDamageTaken =
          1e9 - a.world.entities.health[a.primary];
      expect(primaryDamageTaken, greaterThan(0));

      // The 3 nearest (0.3, 0.4, 0.5 u) took chain damage; the 4th (0.8 u)
      // did not — proof the chain count is exactly 3, not "everything
      // nearby".
      final List<double> taken = <int>[0, 1, 2, 3]
          .map((int i) => 1e9 - a.world.entities.health[a.nearby[i]])
          .toList();
      expect(taken[0], greaterThan(0));
      expect(taken[1], greaterThan(0));
      expect(taken[2], greaterThan(0));
      expect(taken[3], 0);
    });

    test('Frequent Arc (★1a): triggers every 3rd arrow instead of every 5th', () {
      // Both sides fire for the same window; Frequent Arc should have
      // produced strictly more total chain damage by then.
      final ({SimWorld world, int primary, List<int> nearby}) base =
          torvArena();
      final ({SimWorld world, int primary, List<int> nearby}) frequent =
          torvArena(stars: 1, talentChoices: <String, String>{'1': 'a'});

      double totalChainDamage(
          ({SimWorld world, int primary, List<int> nearby}) a) {
        final InputSnapshot idle = InputSnapshot();
        for (int t = 0; t < 400; t++) {
          a.world.tick(idle);
        }
        double total = 0;
        for (final int e in a.nearby) {
          total += 1e9 - a.world.entities.health[e];
        }
        return total;
      }

      expect(totalChainDamage(frequent), greaterThan(totalChainDamage(base)));
    });

    test('Wide Arc (★1b): chains to all 4 targets instead of 3', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = torvArena(
        stars: 1,
        talentChoices: <String, String>{'1': 'b'},
      );
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 400; t++) {
        a.world.tick(idle);
      }
      for (final int e in a.nearby) {
        expect(1e9 - a.world.entities.health[e], greaterThan(0),
            reason: 'enemy $e never took chain damage');
      }
    });

    test('Tempest Nock: every arrow chains to 5 targets for its window', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = torvArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.tempestNockRemaining, closeTo(5.0, 1e-9));

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 200; t++) {
        a.world.tick(idle);
      }
      // Every one of the 4 nearby enemies took damage from the very first
      // shot fired during the window — no need to wait for a 5th arrow.
      for (final int e in a.nearby) {
        expect(1e9 - a.world.entities.health[e], greaterThan(0),
            reason: 'enemy $e never took chain damage during Tempest Nock');
      }
    });

    test('Long Tempest (★5a): the window lasts 8 s instead of 5', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = torvArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'a'},
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.tempestNockRemaining, closeTo(8.0, 1e-9));
    });
  });

  group('Pull', () {
    /// A primary target 8 u east of the player, and [groupedCount] bystanders
    /// further east still along the same line — close enough to the primary
    /// to count as "grouped" (within 1.6 u, ADR 0007) but never directly hit,
    /// since a non-piercing arrow always reaches the nearer primary first.
    /// Mirrors bramArena's own placement trick exactly.
    ({SimWorld world, int primary, List<int> grouped}) rookArena({
      int groupedCount = 0,
      double groupedSpacing = 0.3,
      bool forceCrit = false,
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 111, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        rook,
        HeroState(heroId: 'rook', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      if (forceCrit) {
        world.combat.critChance = 1.0;
      }
      final int primary = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[primary] = 0;
      world.entities.maxHealth[primary] = 1e9;
      world.entities.health[primary] = 1e9;

      final List<int> grouped = <int>[];
      for (int i = 0; i < groupedCount; i++) {
        final int e = world.spawnEnemy(
          EnemyArchetype.mote,
          12.0 + groupedSpacing * (i + 1),
          4.5,
        );
        world.enemies.speedScale[e] = 0;
        world.entities.maxHealth[e] = 1e9;
        world.entities.health[e] = 1e9;
        grouped.add(e);
      }
      return (world: world, primary: primary, grouped: grouped);
    }

    double? firstDamageDealt(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.damageDealt) {
            return world.events.valueAAt(e);
          }
        }
      }
      return null;
    }

    test('grouped enemies within 1.6 u each add +12 % damage to the hit', () {
      final double? alone = firstDamageDealt(rookArena().world);
      final double? withTwo =
          firstDamageDealt(rookArena(groupedCount: 2).world);
      final double? withFour =
          firstDamageDealt(rookArena(groupedCount: 4).world);
      expect(alone, isNotNull);
      expect(withTwo, isNotNull);
      expect(withFour, isNotNull);
      expect(withTwo! / alone!, closeTo(1.24, 0.01));
      expect(withFour! / alone, closeTo(1.48, 0.01));
    });

    test('the bonus caps at 4 grouped enemies (+48 %) — a 5th adds nothing',
        () {
      final double? withFour =
          firstDamageDealt(rookArena(groupedCount: 4).world);
      final double? withFive =
          firstDamageDealt(rookArena(groupedCount: 5, groupedSpacing: 0.2).world);
      expect(withFour, isNotNull);
      expect(withFive, isNotNull);
      expect(withFive! / withFour!, closeTo(1.0, 0.01));
    });

    test('a bystander beyond 1.6 u does not count as grouped', () {
      final double? alone = firstDamageDealt(rookArena().world);
      final double? withFarBystander = firstDamageDealt(
        rookArena(groupedCount: 1, groupedSpacing: 2.0).world,
      );
      expect(alone, isNotNull);
      expect(withFarBystander, isNotNull);
      expect(withFarBystander! / alone!, closeTo(1.0, 0.01));
    });

    test('Denser Grouping (★1b): +18 % per enemy instead of +12 %', () {
      // Both sides ★1 (one with the branch picked, one without) so heroAtk's
      // star scaling matches on both — only the per-enemy rate differs.
      final double? base = firstDamageDealt(
        rookArena(groupedCount: 2, stars: 1).world,
      );
      final double? denser = firstDamageDealt(rookArena(
        groupedCount: 2,
        stars: 1,
        talentChoices: <String, String>{'1': 'b'},
      ).world);
      expect(base, isNotNull);
      expect(denser, isNotNull);
      // (1 + 2*0.18) / (1 + 2*0.12)
      expect(denser! / base!, closeTo(1.36 / 1.24, 0.01));
    });

    test('a crit pulls the target 1.2 u toward the point of impact', () {
      final ({SimWorld world, int primary, List<int> grouped}) a =
          rookArena(forceCrit: true);
      final double x0 = a.world.entities.posX[a.primary];
      final double y0 = a.world.entities.posY[a.primary];

      final InputSnapshot idle = InputSnapshot();
      bool hit = false;
      for (int t = 0; t < 120; t++) {
        a.world.tick(idle);
        if (a.world.events.countOf(SimEventType.damageDealt) > 0) {
          hit = true;
          break;
        }
      }
      expect(hit, isTrue);

      final double dx = a.world.entities.posX[a.primary] - x0;
      final double dy = a.world.entities.posY[a.primary] - y0;
      expect(math.sqrt(dx * dx + dy * dy), closeTo(1.2, 0.05));
    });

    test('Stronger Pull (★1a): displacement rises to 2.0 u', () {
      final ({SimWorld world, int primary, List<int> grouped}) a = rookArena(
        forceCrit: true,
        stars: 1,
        talentChoices: <String, String>{'1': 'a'},
      );
      final double x0 = a.world.entities.posX[a.primary];
      final double y0 = a.world.entities.posY[a.primary];

      final InputSnapshot idle = InputSnapshot();
      bool hit = false;
      for (int t = 0; t < 120; t++) {
        a.world.tick(idle);
        if (a.world.events.countOf(SimEventType.damageDealt) > 0) {
          hit = true;
          break;
        }
      }
      expect(hit, isTrue);

      final double dx = a.world.entities.posX[a.primary] - x0;
      final double dy = a.world.entities.posY[a.primary] - y0;
      expect(math.sqrt(dx * dx + dy * dy), closeTo(2.0, 0.05));
    });

    test('without a crit, the target is never pulled', () {
      final ({SimWorld world, int primary, List<int> grouped}) a =
          rookArena();
      final double x0 = a.world.entities.posX[a.primary];
      final double y0 = a.world.entities.posY[a.primary];

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        a.world.tick(idle);
      }
      expect(a.world.entities.posX[a.primary], closeTo(x0, 1e-9));
      expect(a.world.entities.posY[a.primary], closeTo(y0, 1e-9));
    });
  });

  group('Chill and Glacier Nail', () {
    /// A primary target 8 u east of the player (always the nearest enemy, so
    /// it is always what Glacier Nail's own target-selection locks onto),
    /// plus one bystander per entry in [nearbyOffsets] further east still —
    /// close enough to the player to still be background, but placed at a
    /// known distance from the *primary* for radius/chain checks.
    ({SimWorld world, int primary, List<int> nearby}) selaArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
      List<double> nearbyOffsets = const <double>[],
    }) {
      final SimWorld world = SimWorld(seed: 131, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        sela,
        HeroState(heroId: 'sela', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int primary = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[primary] = 0;
      world.entities.maxHealth[primary] = 1e9;
      world.entities.health[primary] = 1e9;

      final List<int> nearby = <int>[];
      for (final double offset in nearbyOffsets) {
        final int e =
            world.spawnEnemy(EnemyArchetype.mote, 12.0 + offset, 4.5);
        world.enemies.speedScale[e] = 0;
        world.entities.maxHealth[e] = 1e9;
        world.entities.health[e] = 1e9;
        nearby.add(e);
      }
      return (world: world, primary: primary, nearby: nearby);
    }

    double? firstDamageDealt(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.damageDealt) {
            return world.events.valueAAt(e);
          }
        }
      }
      return null;
    }

    test('grants +30 % damage to a target that is already frozen', () {
      // Frozen state is seeded directly, before the first arrow lands — the
      // Chill *stack* a hit itself applies only takes effect on the *next*
      // hit, since element application runs after damage resolves.
      final double? notFrozen = firstDamageDealt(selaArena().world);

      final ({SimWorld world, int primary, List<int> nearby}) frozenArena =
          selaArena();
      frozenArena.world.status.frozenRemaining[frozenArena.primary] = 10.0;
      final double? frozen = firstDamageDealt(frozenArena.world);

      expect(notFrozen, isNotNull);
      expect(frozen, isNotNull);
      expect(frozen! / notFrozen!, closeTo(1.30, 0.01));
    });

    test('Deeper Chill (★1a): 16 Chill per hit instead of 12', () {
      final ({SimWorld world, int primary, List<int> nearby}) a =
          selaArena(stars: 1, talentChoices: <String, String>{'1': 'a'});
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        a.world.tick(idle);
        if (a.world.events.countOf(SimEventType.damageDealt) > 0) break;
      }
      // Same decay-window slack as the base Chill test.
      expect(a.world.status.chill[a.primary], closeTo(16.0, 0.3));
    });

    test('Brittle (★1b): +45 % instead of +30 % while frozen', () {
      // Both sides ★1 so heroAtk's star scaling matches on both.
      final ({SimWorld world, int primary, List<int> nearby}) base =
          selaArena(stars: 1);
      base.world.status.frozenRemaining[base.primary] = 10.0;
      final double? baseFrozen = firstDamageDealt(base.world);

      final ({SimWorld world, int primary, List<int> nearby}) brittle =
          selaArena(stars: 1, talentChoices: <String, String>{'1': 'b'});
      brittle.world.status.frozenRemaining[brittle.primary] = 10.0;
      final double? brittleFrozen = firstDamageDealt(brittle.world);

      expect(baseFrozen, isNotNull);
      expect(brittleFrozen, isNotNull);
      // (1 + 0.45) / (1 + 0.30)
      expect(brittleFrozen! / baseFrozen!, closeTo(1.45 / 1.30, 0.01));
    });

    test('Glacier Nail freezes the target and everything within 3.5 u for 3 s',
        () {
      final ({SimWorld world, int primary, List<int> nearby}) a =
          selaArena(nearbyOffsets: <double>[1.0, 5.0]);
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.status.isFrozen(a.primary), isTrue);
      // A tick's worth of decay (ElementSystem runs after the Ultimate is
      // fired, in the same tick) has already come off by the time this reads.
      expect(a.world.status.frozenRemaining[a.primary], closeTo(3.0, 0.02));
      // 1.0 u from the primary — inside the 3.5 u radius.
      expect(a.world.status.isFrozen(a.nearby[0]), isTrue);
      // 5.0 u from the primary — outside it.
      expect(a.world.status.isFrozen(a.nearby[1]), isFalse);
    });

    test('Absolute Zero (★5a): 5 u radius, 5 s duration', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = selaArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'a'},
        // 4.5 u from the primary: outside the base 3.5 u, inside 5 u.
        nearbyOffsets: <double>[4.5],
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.status.frozenRemaining[a.primary], closeTo(5.0, 0.02));
      expect(a.world.status.isFrozen(a.nearby[0]), isTrue);
    });

    test('Cascading Nail (★5b): chains the freeze to the 3 nearest enemies '
        'the radius missed', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = selaArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'b'},
        // All 4 sit outside the base 3.5 u radius; only the nearest 3 chain.
        nearbyOffsets: <double>[5.0, 5.5, 6.0, 6.5],
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.status.isFrozen(a.nearby[0]), isTrue);
      expect(a.world.status.isFrozen(a.nearby[1]), isTrue);
      expect(a.world.status.isFrozen(a.nearby[2]), isTrue);
      expect(a.world.status.isFrozen(a.nearby[3]), isFalse);
    });
  });

  group('Toxin and Miasma', () {
    /// A primary target 8 u east of the player, plus one bystander per
    /// [nearbyOffsets] entry further east still — the same placement trick
    /// [selaArena] uses, since Contagion's transfer target needs a second
    /// enemy at a known distance from the *primary*, not from the player.
    ({SimWorld world, int primary, List<int> nearby}) sableArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
      List<double> nearbyOffsets = const <double>[],
    }) {
      final SimWorld world = SimWorld(seed: 151, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        sable,
        HeroState(heroId: 'sable', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int primary = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[primary] = 0;
      world.entities.maxHealth[primary] = 1e9;
      world.entities.health[primary] = 1e9;

      final List<int> nearby = <int>[];
      for (final double offset in nearbyOffsets) {
        final int e =
            world.spawnEnemy(EnemyArchetype.mote, 12.0 + offset, 4.5);
        world.enemies.speedScale[e] = 0;
        world.entities.maxHealth[e] = 1e9;
        world.entities.health[e] = 1e9;
        nearby.add(e);
      }
      return (world: world, primary: primary, nearby: nearby);
    }

    /// Miasma is centred on the *player*, not on a distant target, so its own
    /// tests place enemies at a known distance from the player instead of
    /// reusing [sableArena]'s "8 u due east" primary. `autoFire` stays off:
    /// an arrow landing would apply its own Toxin stack from `sableToxin`
    /// and confound "how much did the cloud alone apply".
    ({SimWorld world, List<int> enemies}) sableMiasmaArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
      List<double> distancesFromPlayer = const <double>[],
    }) {
      final SimWorld world = SimWorld(seed: 152, content: content);
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        sable,
        HeroState(heroId: 'sable', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final List<int> enemies = <int>[];
      for (final double d in distancesFromPlayer) {
        final int e = world.spawnEnemy(EnemyArchetype.mote, 4.0 + d, 4.5);
        world.enemies.speedScale[e] = 0;
        world.entities.maxHealth[e] = 1e9;
        world.entities.health[e] = 1e9;
        enemies.add(e);
      }
      return (world: world, enemies: enemies);
    }

    void runUntilFirstHit(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        if (world.events.countOf(SimEventType.damageDealt) > 0) return;
      }
      fail('no hit landed within 120 ticks');
    }

    test('Virulence (★1a): the Toxin cap rises to 12', () {
      final ({SimWorld world, int primary, List<int> nearby}) a =
          sableArena(stars: 1, talentChoices: <String, String>{'1': 'a'});
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 600; t++) {
        a.world.tick(idle);
      }
      expect(a.world.status.toxinStacks[a.primary], 12);
    });

    test('Fast Acting (★1b): 2 stacks per hit, capped at 8', () {
      final ({SimWorld world, int primary, List<int> nearby}) a =
          sableArena(stars: 1, talentChoices: <String, String>{'1': 'b'});
      runUntilFirstHit(a.world);
      expect(a.world.status.toxinStacks[a.primary], 2);

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 600; t++) {
        a.world.tick(idle);
      }
      expect(a.world.status.toxinStacks[a.primary], 8);
    });

    test(
        'Contagion (★3a): half a dying enemy\'s Toxin stacks jump to the '
        'nearest other enemy', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = sableArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
        nearbyOffsets: <double>[1.0],
      );
      a.world.status.toxinStacks[a.primary] = 6;
      // Lethal to Toxin's own DoT on the very next tick — deferDeath routes
      // the actual reap (and this talent's hook) through AiSystem, exactly
      // like an arrow-finished kill would.
      a.world.entities.health[a.primary] = 0.001;
      a.world.tick(InputSnapshot());

      expect(a.world.entities.alive[a.primary], 0);
      expect(a.world.status.toxinStacks[a.nearby[0]], 3);
    });

    test('Corrosion (★3b): each Toxin stack cuts the enemy\'s own damage by 2 %',
        () {
      final ({SimWorld world, int primary, List<int> nearby}) without =
          sableArena(stars: 3);
      without.world.status.toxinStacks[without.primary] = 5;
      without.world.tick(InputSnapshot());
      expect(without.world.enemies.attackBuff[without.primary], 0);

      final ({SimWorld world, int primary, List<int> nearby}) with_ =
          sableArena(stars: 3, talentChoices: <String, String>{'3': 'b'});
      with_.world.status.toxinStacks[with_.primary] = 5;
      with_.world.tick(InputSnapshot());
      expect(
        with_.world.enemies.attackBuff[with_.primary],
        closeTo(-0.10, 1e-9),
      );
    });

    test('Miasma pulses Toxin onto enemies within 5 u of the cast point', () {
      final ({SimWorld world, List<int> enemies}) a =
          sableMiasmaArena(distancesFromPlayer: <double>[2.0, 6.0]);
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      // The first pulse lands the instant the cloud is cast.
      expect(a.world.status.toxinStacks[a.enemies[0]], greaterThanOrEqualTo(1));
      expect(a.world.status.toxinStacks[a.enemies[1]], 0);
    });

    test('the cloud pulses at 2 stacks/s for 8 s, capped at 10 stacks', () {
      final ({SimWorld world, List<int> enemies}) a =
          sableMiasmaArena(distancesFromPlayer: <double>[2.0]);
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 600; t++) {
        a.world.tick(idle);
      }
      // 8 s at 2/s = 16 pulses, past the base 10-stack ceiling.
      expect(a.world.status.toxinStacks[a.enemies[0]], 10);
    });

    test('Lasting Miasma (★5a): the cloud lasts 14 s instead of 8', () {
      final ({SimWorld world, List<int> enemies}) a = sableMiasmaArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'a'},
        distancesFromPlayer: <double>[2.0],
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.miasmaRemaining, closeTo(14.0, 0.02));
    });

    test('Concentrated Miasma (★5b): 3 u radius instead of 5', () {
      final ({SimWorld world, List<int> enemies}) a = sableMiasmaArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'b'},
        distancesFromPlayer: <double>[2.5, 4.0],
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      // 2.5 u is inside 3 u; 4.0 u would have been inside the base 5 u but
      // sits outside Concentrated Miasma's own tighter radius.
      expect(a.world.status.toxinStacks[a.enemies[0]], greaterThanOrEqualTo(1));
      expect(a.world.status.toxinStacks[a.enemies[1]], 0);
    });
  });

  group('Kindling and Pyre Line', () {
    /// A single target [distance] u east of the player — kept close (1 u
    /// default) for the tier-gate tests, where the arrow's own travel time
    /// must stay negligible next to the ~0.65 s Tier II window itself.
    ({SimWorld world, int target}) kadeArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
      double distance = 8.0,
    }) {
      final SimWorld world = SimWorld(seed: 171, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        kade,
        HeroState(heroId: 'kade', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int target =
          world.spawnEnemy(EnemyArchetype.mote, 4.0 + distance, 4.5);
      world.enemies.speedScale[target] = 0;
      world.entities.maxHealth[target] = 1e9;
      world.entities.health[target] = 1e9;
      return (world: world, target: target);
    }

    /// One enemy sitting on the player's aim line (due east — the nearest
    /// enemy, so it is what target selection locks the wall's direction
    /// onto) and one 1.5 u off it — well outside the wall's own tolerance
    /// (ADR 0008's borrowed Windline width plus a mote's radius).
    ({SimWorld world, int onLine, int offLine}) kadePyreArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 172, content: content);
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        kade,
        HeroState(heroId: 'kade', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int onLine = world.spawnEnemy(EnemyArchetype.mote, 9.0, 4.5);
      world.enemies.speedScale[onLine] = 0;
      world.entities.maxHealth[onLine] = 1e9;
      world.entities.health[onLine] = 1e9;

      final int offLine = world.spawnEnemy(EnemyArchetype.mote, 9.0, 6.0);
      world.enemies.speedScale[offLine] = 0;
      world.entities.maxHealth[offLine] = 1e9;
      world.entities.health[offLine] = 1e9;
      return (world: world, onLine: onLine, offLine: offLine);
    }

    test('Hot Iron (★1a): Burn also applies at Tier II', () {
      final ({SimWorld world, int target}) a = kadeArena(
        stars: 1,
        talentChoices: <String, String>{'1': 'a'},
        distance: 1.0,
      );
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60; t++) {
        a.world.tick(idle);
      }
      expect(a.world.playerDraw.tier, DrawTier.two);
      expect(a.world.status.burnStacks[a.target], greaterThan(0));
    });

    test('without Hot Iron, Tier II does not apply Burn', () {
      final ({SimWorld world, int target}) a = kadeArena(distance: 1.0);
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60; t++) {
        a.world.tick(idle);
      }
      expect(a.world.playerDraw.tier, DrawTier.two);
      expect(a.world.status.burnStacks[a.target], 0);
    });

    test('Deep Burn (★1b): Burn deals 6 % max HP/s instead of 4 %', () {
      final ({SimWorld world, int target}) a =
          kadeArena(stars: 1, talentChoices: <String, String>{'1': 'b'});
      a.world.status.burnStacks[a.target] = 1;
      a.world.status.burnRemaining[a.target] = 10.0;
      final double before = a.world.entities.health[a.target];
      a.world.tick(InputSnapshot());
      final double lost = before - a.world.entities.health[a.target];
      // maxHealth * 0.06 * 1 stack * one tick's dt (1/60 s).
      expect(lost, closeTo(1e9 * 0.06 / 60.0, 1.0));
    });

    test(
        'Wildfire (★3a): Burn spreads to one enemy within 2 u on the '
        "carrier's death", () {
      final ({SimWorld world, int target}) a =
          kadeArena(stars: 3, talentChoices: <String, String>{'3': 'a'});
      final int nearby = a.world.spawnEnemy(
        EnemyArchetype.mote,
        a.world.entities.posX[a.target] + 1.0,
        a.world.entities.posY[a.target],
      );
      a.world.enemies.speedScale[nearby] = 0;
      a.world.entities.maxHealth[nearby] = 1e9;
      a.world.entities.health[nearby] = 1e9;

      a.world.status.burnStacks[a.target] = 1;
      a.world.status.burnRemaining[a.target] = 10.0;
      // Lethal to Burn's own DoT on the very next tick — deferDeath routes
      // the reap (and this talent's hook) through AiSystem either way.
      a.world.entities.health[a.target] = 0.001;
      a.world.tick(InputSnapshot());

      expect(a.world.entities.alive[a.target], 0);
      expect(a.world.status.burnStacks[nearby], greaterThan(0));
    });

    test('Pyre Line burns whoever stands on the wall along the aim vector',
        () {
      final ({SimWorld world, int onLine, int offLine}) a = kadePyreArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.status.burnStacks[a.onLine], greaterThan(0));
      expect(a.world.status.burnStacks[a.offLine], 0);
    });

    test('Slow Burn (★3b) via Pyre Line: 3 stacks lasting 8 s', () {
      final ({SimWorld world, int onLine, int offLine}) a =
          kadePyreArena(stars: 3, talentChoices: <String, String>{'3': 'b'});
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      // The wall re-applies every tick standing in it (not a once-per-
      // crossing burst — see _tickKadePyreLine's own note), so a handful of
      // extra ticks lets the stack count climb to its cap.
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 5; t++) {
        a.world.tick(idle);
      }

      expect(a.world.status.burnStacks[a.onLine], 3);
      expect(a.world.status.burnRemaining[a.onLine], closeTo(8.0, 0.1));
    });

    test('Long Pyre (★5a): the wall lasts 14 s instead of 8', () {
      final ({SimWorld world, int onLine, int offLine}) a =
          kadePyreArena(stars: 5, talentChoices: <String, String>{'5': 'a'});
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.pyreLineRemaining, closeTo(14.0, 0.02));
    });

    test('Twin Pyre (★5b): a second, perpendicular wall also burns', () {
      final ({SimWorld world, int onLine, int offLine}) a =
          kadePyreArena(stars: 5, talentChoices: <String, String>{'5': 'b'});
      // 6 u due north of the player — further than onLine's 5 u, so target
      // selection still locks the primary wall eastward — but exactly on
      // the perpendicular wall Twin Pyre adds.
      final int perpTester =
          a.world.spawnEnemy(EnemyArchetype.mote, 4.0, 10.5);
      a.world.enemies.speedScale[perpTester] = 0;
      a.world.entities.maxHealth[perpTester] = 1e9;
      a.world.entities.health[perpTester] = 1e9;

      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.status.burnStacks[perpTester], greaterThan(0));
    });
  });

  group('Weave', () {
    /// A player 1 u from the west wall and a stationary target at 14 u —
    /// both, and every pre-existing Windline in between, kept inside
    /// `SimConfig.arenaWidth`'s 16 u (an out-of-bounds target is never hit
    /// at all: `ProjectileSystem` misses any arrow whose flight leaves
    /// `arena.containsPoint`, silently, which is what the first version of
    /// this arena did at a naive "2 u / 20 u" placement — zero hits, zero
    /// Confluence events past the crossings an arrow racks up before going
    /// out of bounds and being discarded).
    ///
    /// [lineCount] pre-existing, already-old Windlines are laid
    /// perpendicular to the firing line — geometry lifted directly from
    /// confluence_test.dart's own "an arrow crossing an existing trail
    /// triggers Confluence" end-to-end check, just repeated enough times
    /// for one arrow to thread every one of them before it reaches the
    /// target. Spaced 1.5 u apart rather than further: a wider spacing let
    /// an arrow's trajectory drift (auto-aim tracking a moving reticle)
    /// enough to miss one of the later lines by the time it reached them,
    /// empirically capping every arrow at 4 stacks — this spacing was
    /// checked to reliably reach 5.
    ({SimWorld world, int target}) irisArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
      int lineCount = 5,
    }) {
      final SimWorld world = SimWorld(seed: 181, content: content)
        ..autoFire = true;
      world.spawnPlayer(1.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        iris,
        HeroState(heroId: 'iris', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int target = world.spawnEnemy(EnemyArchetype.mote, 14.0, 4.5);
      world.enemies.speedScale[target] = 0;
      world.entities.maxHealth[target] = 1e9;
      world.entities.health[target] = 1e9;

      for (int i = 0; i < lineCount; i++) {
        final double x = 3.0 + i * 1.5;
        world.windlines.add(
          fromX: x,
          fromY: 1.0,
          toX: x,
          toY: 8.0,
          expiresAt: 1e9,
          ownerIndex: 0,
          trailId: 90000 + i,
        );
      }
      return (world: world, target: target);
    }

    test('Windlines last 2.6 s instead of the base 1.2 s', () {
      final ({SimWorld world, int target}) a = irisArena();
      expect(a.world.windlineDuration, closeTo(2.6, 1e-6));
    });

    test('Long Weave (★1a): Windlines last 3.4 s', () {
      final ({SimWorld world, int target}) a =
          irisArena(stars: 1, talentChoices: <String, String>{'1': 'a'});
      expect(a.world.windlineDuration, closeTo(3.4, 1e-6));
    });

    test('Bright Weave (★1b): +25 % Confluence damage', () {
      final ({SimWorld world, int target}) a =
          irisArena(stars: 1, talentChoices: <String, String>{'1': 'b'});
      expect(a.world.confluenceDamageMultiplier, closeTo(1.25, 1e-6));
    });

    test('Cutting Lines (★3a): Windlines damage enemies 2 % max HP/s', () {
      final ({SimWorld world, int target}) a =
          irisArena(stars: 3, talentChoices: <String, String>{'3': 'a'});
      expect(a.world.windlineDamageFraction, closeTo(0.02, 1e-6));
    });

    test('Binding Lines (★3b): adds +27 % Windline slow', () {
      final ({SimWorld world, int target}) a =
          irisArena(stars: 3, talentChoices: <String, String>{'3': 'b'});
      expect(a.world.windlineSlow, closeTo(0.27, 1e-6));
    });

    test('without Binding Lines, Iris does not touch Windline slow', () {
      final ({SimWorld world, int target}) a = irisArena();
      expect(a.world.windlineSlow, 0);
    });

    test(
        'the stack cap rises to 5, unlocking the 4th (+230 %) and 5th '
        '(+320 %) bonuses', () {
      final ({SimWorld world, int target}) a = irisArena();
      final InputSnapshot idle = InputSnapshot();
      int maxStacksSeen = 0;
      double bonusAtMax = 0;
      for (int t = 0; t < 400; t++) {
        a.world.tick(idle);
        for (int e = 0; e < a.world.events.count; e++) {
          if (a.world.events.typeAt(e) == SimEventType.confluenceTriggered) {
            final int stacks = a.world.events.valueAAt(e).round();
            if (stacks > maxStacksSeen) {
              maxStacksSeen = stacks;
              bonusAtMax = a.world.events.valueBAt(e);
            }
          }
        }
      }
      expect(maxStacksSeen, 5);
      expect(bonusAtMax, closeTo(3.20, 0.01));
    });

    test('the 5th Confluence stack also splashes a 2 u AoE', () {
      final ({SimWorld world, int target}) a = irisArena();
      // 1 u past the primary target — beyond a non-piercing arrow's reach,
      // so it can only take damage from the splash, never a direct hit.
      final int bystander =
          a.world.spawnEnemy(EnemyArchetype.mote, 15.0, 4.5);
      a.world.enemies.speedScale[bystander] = 0;
      a.world.entities.maxHealth[bystander] = 1e9;
      a.world.entities.health[bystander] = 1e9;

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 400; t++) {
        a.world.tick(idle);
      }
      expect(a.world.entities.health[bystander], lessThan(1e9));
    });
  });

  group('Umbral Step', () {
    /// A near enemy 2 u east of the player and a far one further out and
    /// off-axis — far enough that it, not the near one, is what a teleport
    /// to "the furthest enemy" should land on.
    ({SimWorld world, int near, int far}) nyxStepArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 191, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        nyx,
        HeroState(heroId: 'nyx', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int near = world.spawnEnemy(EnemyArchetype.mote, 6.0, 4.5);
      world.enemies.speedScale[near] = 0;
      world.entities.maxHealth[near] = 1e9;
      world.entities.health[near] = 1e9;

      final int far = world.spawnEnemy(EnemyArchetype.mote, 12.0, 6.0);
      world.enemies.speedScale[far] = 0;
      world.entities.maxHealth[far] = 1e9;
      world.entities.health[far] = 1e9;
      return (world: world, near: near, far: far);
    }

    double? firstDamageDealt(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.damageDealt) {
            return world.events.valueAAt(e);
          }
        }
      }
      return null;
    }

    test('teleports to the furthest enemy', () {
      final ({SimWorld world, int near, int far}) a = nyxStepArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final int p = a.world.player.index;
      expect(a.world.entities.posX[p], closeTo(a.world.entities.posX[a.far], 1e-9));
      expect(a.world.entities.posY[p], closeTo(a.world.entities.posY[a.far], 1e-9));
    });

    test('becomes untargetable for 1.5 s — an enemy hit cannot land', () {
      final ({SimWorld world, int near, int far}) a = nyxStepArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.umbralStepRemaining, closeTo(1.5, 0.02));
      final double dealt =
          EnemyAttack.damagePlayer(a.world.ai, 0.5, source: -1);
      expect(dealt, 0);
    });

    test('without Umbral Step active, a hit lands normally', () {
      final ({SimWorld world, int near, int far}) a = nyxStepArena();
      a.world.tick(InputSnapshot());
      final double dealt =
          EnemyAttack.damagePlayer(a.world.ai, 0.5, source: -1);
      expect(dealt, greaterThan(0));
    });

    test('Deeper Shadow (★1b): the window lasts 2.5 s instead of 1.5', () {
      final ({SimWorld world, int near, int far}) a =
          nyxStepArena(stars: 1, talentChoices: <String, String>{'1': 'b'});
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.umbralStepRemaining, closeTo(2.5, 0.02));
    });

    /// `_updateFiring` runs before `_updateUltimate` within the same tick,
    /// so pressing the button on a tick where an ordinary shot's cooldown
    /// also happens to be ready would fire that shot *first*, unboosted —
    /// racy, since exactly which tick that lands on depends on the fire
    /// cooldown's own phase. Turning `autoFire` off for the press itself
    /// removes the race outright rather than timing around it: no ordinary
    /// shot can fire at all until it is switched back on, immediately
    /// after, for the measurement that follows.
    void fireUltimateWithoutRacing(SimWorld world) {
      world.autoFire = false;
      world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      world.autoFire = true;
    }

    test('guarantees the next shot crits at 300 % rather than rolling', () {
      final double? normal = firstDamageDealt(nyxStepArena().world);

      final ({SimWorld world, int near, int far}) a = nyxStepArena();
      a.world.hero.ultimateCharge = 1.0;
      fireUltimateWithoutRacing(a.world);
      expect(a.world.hero.umbralStepGuaranteedCritShots, 3);
      final double? boosted = firstDamageDealt(a.world);

      expect(normal, isNotNull);
      expect(boosted, isNotNull);
      expect(boosted! / normal!, closeTo(3.00, 0.02));
    });

    test('the guarantee is spent after exactly 3 shots', () {
      final ({SimWorld world, int near, int far}) a = nyxStepArena();
      a.world.hero.ultimateCharge = 1.0;
      fireUltimateWithoutRacing(a.world);

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0;
          t < 300 && a.world.events.countOf(SimEventType.arrowFired) < 3;
          t++) {
        a.world.tick(idle);
      }
      expect(a.world.events.countOf(SimEventType.arrowFired), greaterThanOrEqualTo(3));
      expect(a.world.hero.umbralStepGuaranteedCritShots, 0);
    });

    test('Perfect Step (★5b): 1 shot at 600 % instead of 3 at 300 %', () {
      // Both ★5 (the baseline holds no talent at that node) so heroAtk's
      // own star scaling matches on both sides.
      final double? normal = firstDamageDealt(nyxStepArena(stars: 5).world);

      final ({SimWorld world, int near, int far}) a =
          nyxStepArena(stars: 5, talentChoices: <String, String>{'5': 'b'});
      a.world.hero.ultimateCharge = 1.0;
      fireUltimateWithoutRacing(a.world);
      expect(a.world.hero.umbralStepGuaranteedCritShots, 1);
      final double? boosted = firstDamageDealt(a.world);

      expect(normal, isNotNull);
      expect(boosted, isNotNull);
      expect(boosted! / normal!, closeTo(6.00, 0.02));
    });

    test(
        'Chain Kill (★3b): each stacked kill adds another +25 % move speed, '
        'up to 3', () {
      SimWorld buildWorld({
        int stars = 0,
        Map<String, String> talentChoices = const <String, String>{},
      }) {
        final SimWorld world = SimWorld(seed: 192, content: content)
          ..autoFire = false;
        world.spawnPlayer(4.0, 4.5);
        HeroLoadoutResolver.apply(
          world,
          nyx,
          HeroState(heroId: 'nyx', stars: stars, talentChoices: talentChoices),
          ashShaft,
          const ArrowInstance(arrowId: 'ash_shaft'),
        );
        return world;
      }

      // Both ★3 (unboosted holds no talent at that node) so heroMoveSpeed's
      // own star scaling matches on both sides — only Chain Kill's stack
      // multiplier should differ.
      final SimWorld boosted =
          buildWorld(stars: 3, talentChoices: <String, String>{'3': 'b'});
      final SimWorld unboosted = buildWorld(stars: 3);
      final InputSnapshot moving = InputSnapshot()..set(1.0, 0.0);

      boosted.hero.firstBloodSpeedRemaining = HeroRuntime.firstBloodSpeedDuration;
      boosted.hero.firstBloodSpeedStacks = 3;
      boosted.tick(moving);
      unboosted.tick(moving);
      expect(
        boosted.entities.velX[boosted.player.index] /
            unboosted.entities.velX[unboosted.player.index],
        closeTo(1.75, 0.01), // 1 + 3 * 0.25
      );
    });

    test('two real kills within the window stack to 2', () {
      final SimWorld world = SimWorld(seed: 194, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        nyx,
        const HeroState(
            heroId: 'nyx', stars: 3, talentChoices: <String, String>{'3': 'b'}),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int first = world.spawnEnemy(EnemyArchetype.mote, 5.0, 4.5);
      world.entities.maxHealth[first] = 1;
      world.entities.health[first] = 1;
      final int second = world.spawnEnemy(EnemyArchetype.mote, 5.5, 4.5);
      world.entities.maxHealth[second] = 1;
      world.entities.health[second] = 1;

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 200 && world.hero.firstBloodSpeedStacks < 2; t++) {
        world.tick(idle);
      }
      expect(world.hero.firstBloodSpeedStacks, 2);
    });

    test(
        'Shadowline (★3a): lays a damaging Windline segment while '
        'untargetable', () {
      final ({SimWorld world, int near, int far}) a =
          nyxStepArena(stars: 3, talentChoices: <String, String>{'3': 'a'});
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final InputSnapshot idle = InputSnapshot();
      bool sawShadowlineSegment = false;
      for (int t = 0; t < 60 && !sawShadowlineSegment; t++) {
        a.world.tick(idle);
        for (int s = 0; s < a.world.windlines.capacity; s++) {
          if (a.world.windlines.isAlive(s) &&
              a.world.windlines.isShadowlineAt(s)) {
            sawShadowlineSegment = true;
            break;
          }
        }
      }
      expect(sawShadowlineSegment, isTrue);
    });

    test('a Shadowline-tagged segment damages an enemy standing on it', () {
      final SimWorld world = SimWorld(seed: 195, content: content);
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        nyx,
        const HeroState(
            heroId: 'nyx', stars: 3, talentChoices: <String, String>{'3': 'a'}),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int target = world.spawnEnemy(EnemyArchetype.mote, 8.0, 4.5);
      world.enemies.speedScale[target] = 0;
      world.entities.maxHealth[target] = 1e9;
      world.entities.health[target] = 1e9;
      world.windlines.add(
        fromX: 7.0,
        fromY: 4.5,
        toX: 9.0,
        toY: 4.5,
        expiresAt: 1e9,
        ownerIndex: 0,
        trailId: 555,
        isShadowline: true,
      );

      final double before = world.entities.health[target];
      world.tick(InputSnapshot());
      expect(world.entities.health[target], lessThan(before));
    });

    test('without Shadowline, the same tagged segment does nothing', () {
      final SimWorld world = SimWorld(seed: 196, content: content);
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        nyx,
        const HeroState(heroId: 'nyx'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int target = world.spawnEnemy(EnemyArchetype.mote, 8.0, 4.5);
      world.enemies.speedScale[target] = 0;
      world.entities.maxHealth[target] = 1e9;
      world.entities.health[target] = 1e9;
      world.windlines.add(
        fromX: 7.0,
        fromY: 4.5,
        toX: 9.0,
        toY: 4.5,
        expiresAt: 1e9,
        ownerIndex: 0,
        trailId: 556,
        isShadowline: true,
      );

      final double before = world.entities.health[target];
      world.tick(InputSnapshot());
      expect(world.entities.health[target], before);
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
      // pendingBehaviourWork was for Phase 9's Boons. 138 hero behaviours
      // total (kestrelSharperNock, vaneFarsight and liraDeepRoots never
      // joined this enum — each turned out to be one StatModifier, not a
      // behaviour). Out so far: Wren's four, Kestrel's Flurry plus both ★5
      // variants, Kade/Sela/Sable's innate-element passives, Nyx's First
      // Blood plus Executioner's Eye, Oriel's Spectrum/Prism/Endless Prism,
      // Vane's Distance/Steady/Piercing Horizon/Twin Horizon/Sundering
      // Horizon, Halden's Verdict/Judgment Spear/Final Verdict/Twin Spear,
      // Lira's Lifebound/Verdant Bloom/Endless Bloom/Blood Bloom, Bram's
      // Heavy Ordnance/Wider Blast/Denser Blast, Thane's
      // Bloodtide/Red Draw/Deeper Tide/Last Stand/Frenzy/Long Red/
      // Crimson Draw, Mirelle's Reflection/Truer Mirror/Deeper
      // Mirror/Silvered/Fractured, Torv's Arc/Tempest Nock/Frequent
      // Arc/Wide Arc/Long Tempest, Rook's Pull/Stronger Pull/Denser
      // Grouping, Sela's Glacier Nail/Deeper Chill/Brittle/Absolute
      // Zero/Cascading Nail, Sable's whole kit (Miasma/Virulence/Fast
      // Acting/Contagion/Corrosion/Lasting Miasma/Concentrated Miasma), and
      // Kade's whole kit (Pyre Line/Hot Iron/Deep Burn/Wildfire/Slow
      // Burn/Long Pyre/Twin Pyre), Iris's Weave, and Nyx's Umbral
      // Step/Deeper Shadow/Shadowline/Chain Kill/Perfect Step.
      expect(
        pendingHeroBehaviourWork.length,
        lessThanOrEqualTo(62),
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

  // bramHeavyOrdnance, bramWiderBlast and bramDenserBlast are implemented —
  // see the "Heavy Ordnance" group.
  HeroBehaviour.bramMortarRain,
  // Concussion needs a stagger effect Rush-family enemies do not have a
  // hook for yet, and Incendiary needs a chance roll on top of splash —
  // both plausible, neither built. Mortar Rain and its two ★5 variants need
  // the hazard/telegraph system extended to a player-triggered volley,
  // which nothing before now has asked of it.
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

  // kadeKindling is implemented — see the "three innate elements" group.
  // kadePyreLine, kadeHotIron, kadeDeepBurn, kadeWildfire, kadeSlowBurn,
  // kadeLongPyre and kadeTwinPyre are all implemented too — see the
  // "Kindling and Pyre Line" group. Kade is the second hero (after Sable)
  // whose entire kit is reachable with nothing deferred.

  // selaChill is implemented — see the "three innate elements" group; its own
  // "+30 % damage while frozen" clause was not actually wired into damage
  // until the "Chill and Glacier Nail" group landed (status.isFrozen was
  // only ever read for a Boon's own targetAfflicted condition before then).
  // selaGlacierNail, selaDeeperChill, selaBrittle, selaAbsoluteZero and
  // selaCascadingNail are implemented — see that same group. Shatter needs
  // an on-kill AoE hook nothing before now has asked of a hero passive (every
  // existing per-kill hook, Nyx's First Blood included, only sets timed
  // state on the killer's own runtime — none of them deal damage to a third
  // party), and Lingering Frost needs a real "timed slow zone independent of
  // Windlines" primitive: the sim's only existing slow mechanism
  // (`EnemyStore.slowRemaining`/`windlineSlowFactor`) is Windline- and
  // Boon-specific by construction (`BoonSystem`'s own pass only reads the
  // *player's* live trail and a Boon's own `slow` stat), so faking a zone by
  // dropping a zero-length Windline segment would silently depend on
  // whatever slow-related Boon the player happens to hold, not on Sela at
  // all.
  HeroBehaviour.selaShatter,
  HeroBehaviour.selaLingeringFrost,

  // torvArc, torvTempestNock, torvFrequentArc, torvWideArc and
  // torvLongTempest are implemented — see the "Arc and Tempest Nock" group.
  // Chains hit the nearest enemies by distance rather than genuinely
  // travelling along Windlines, which nothing in the sim currently indexes
  // (see the implementation's own note) — Conductive Lines specifically
  // rewards the Windline-travel case and stays pending until that
  // relationship exists to reward. Overload needs a timed per-enemy debuff
  // this hit path does not track yet; Thunderhead needs a stun applied per
  // chain link.
  HeroBehaviour.torvConductiveLines,
  HeroBehaviour.torvOverload,
  HeroBehaviour.torvThunderhead,

  // sableToxin is implemented — see the "three innate elements" group.
  // sableMiasma, sableVirulence, sableFastActing, sableContagion,
  // sableCorrosion, sableLastingMiasma and sableConcentratedMiasma are all
  // implemented too — see the "Toxin and Miasma" group. Sable is the first
  // hero whose entire kit is reachable with nothing deferred.

  // liraLifebound, liraVerdantBloom, liraEndlessBloom and liraBloodBloom are
  // implemented — see the "Lifebound and Verdant Bloom" group.
  // liraDeepRoots never joined this enum — one StatModifier on lifesteal.
  HeroBehaviour.liraOverheal,

  HeroBehaviour.corvinBounce,
  HeroBehaviour.corvinCaroms,
  HeroBehaviour.corvinTrueBounce,
  HeroBehaviour.corvinHardBounce,
  HeroBehaviour.corvinDoubleBounce,
  HeroBehaviour.corvinEndlessCarom,
  HeroBehaviour.corvinPerfectCarom,

  // vaneDistance, vaneSteady, vanePiercingHorizon, vaneTwinHorizon and
  // vaneSunderingHorizon are implemented — see the "Distance and Piercing
  // Horizon" group. vaneFarsight never joined this enum — one StatModifier
  // on damagePerDistanceCap.
  HeroBehaviour.vaneMarked,

  // thaneBloodtide, thaneRedDraw, thaneDeeperTide, thaneLastStand,
  // thaneFrenzy, thaneLongRed and thaneCrimsonDraw are implemented — see
  // the "Bloodtide and Red Draw" group. Bloodtide's own healing-cap clause
  // ("cannot be healed above 70 % max HP by any source") is not: it would
  // need a cap threaded into every heal source (lifesteal, every
  // BoonSystem regen/shield call), and whether a heal-to-full Boon should
  // respect it too is a design question the card's text does not answer.
  // Tempered is the same gap at a different number (90 %) and stays
  // pending for the same reason.
  HeroBehaviour.thaneTempered,

  // nyxFirstBlood and nyxExecutionersEye are implemented — see the "First
  // Blood" group. nyxUmbralStep, nyxDeeperShadow, nyxShadowline,
  // nyxChainKill and nyxPerfectStep are all implemented too — see the
  // "Umbral Step" group. Untargetable is a new concept for the *player*
  // (enemies already had one, for the Bounder's leap and the Gravebound's
  // downed state) — checked in EnemyAttack.damagePlayer, the same "ignore
  // this hit outright" spot Covenant/Ghost Step/Immortal Draw already use.
  // Twin Step (T5a, "2 charges") stays pending: every hero's Ultimate today
  // shares one single-charge meter (`ultimateCharge`/`ultimateReady`), and
  // a second charge would mean restructuring that shared system rather
  // than adding a hero-local check — a bigger, riskier change, and the
  // card's own text does not say whether charge accumulation overflows
  // into the second charge or fills it separately, an unanswered design
  // question worth its own pass rather than a guess here.
  HeroBehaviour.nyxTwinStep,

  // irisWeave is implemented — see the "Weave" group. Its own data half
  // (Windline duration, the raised Confluence stack cap, and the 4th/5th
  // stack damage bonuses) needed no new code at all: `windlineDuration` and
  // `confluenceStacks` are plain StatChannels every Boon already composes
  // through, and `ConfluenceTuning.bonusByStacks` has carried entries for
  // 4 and 5 stacks since Phase 9's own comment named Iris as the reason
  // ("x4 and x5 exist only for Iris"). Long Weave, Bright Weave, Cutting
  // Lines and Binding Lines are the same story — pure StatModifiers with no
  // `behaviour` field of their own, so they never even joined this enum.
  // The Lattice (and its own ★5 pair) stays pending: "every shot through it
  // caps out at 5 Confluence" wants either a guaranteed-max override bolted
  // onto the shared Confluence-detection code every Boon build depends on,
  // or a genuinely dense criss-crossing web geometry docs/07 does not
  // describe — a bigger, riskier change than a hero-local addition, and
  // worth its own dedicated pass rather than a rushed one here.
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

  // rookPull, rookStrongerPull and rookDenserGrouping are implemented — see
  // the "Pull" group. The Ultimate (Singularity) and its own two ★5 variants
  // stay pending: a multi-tick "pull everything toward a point, then
  // detonate" well needs a sustained field effect nothing before now has
  // asked of Ultimates (every other one so far resolves in a single tick).
  // Crush needs a stacking per-enemy DoT (the same missing "5th kind of
  // status" gap as kestrelBleed) and Anchor needs a per-enemy root/stun
  // timer, neither of which exists yet.
  HeroBehaviour.rookSingularity,
  HeroBehaviour.rookCrush,
  HeroBehaviour.rookAnchor,
  HeroBehaviour.rookTwinSingularity,
  HeroBehaviour.rookCollapsingSingularity,

  // haldenVerdict, haldenJudgmentSpear, haldenFinalVerdict and
  // haldenTwinSpear are implemented — see the "Verdict and Judgment Spear"
  // group. Verdict itself only reaches its elite half: the boss half of
  // both its clauses, plus every one of these four talents, needs an
  // `isBoss` check EnemyStore does not have before Phase 11.
  HeroBehaviour.haldenZealot,
  HeroBehaviour.haldenWarded,
  HeroBehaviour.haldenSentence,
  HeroBehaviour.haldenSwiftJudgment,

  HeroBehaviour.ashlinRekindle,
  HeroBehaviour.ashlinRebirthNova,
  HeroBehaviour.ashlinBrightRekindle,
  HeroBehaviour.ashlinTwiceKindled,
  HeroBehaviour.ashlinEmberBody,
  HeroBehaviour.ashlinPhoenixTrail,
  HeroBehaviour.ashlinEternal,
  HeroBehaviour.ashlinSupernova,

  // mirelleReflection, mirelleTruerMirror, mirelleDeeperMirror,
  // mirelleSilvered and mirelleFractured are implemented — see the
  // "Reflection" group. Hall of Mirrors and its two ★5 variants stay
  // pending: "a mirror clone of the player fights alongside" needs a
  // companion entity — an AI-driven ally that mimics the player's own
  // shooting, the same missing piece that blocks Zea's Skyhawk.
  HeroBehaviour.mirelleHallOfMirrors,
  HeroBehaviour.mirelleEndlessHall,
  HeroBehaviour.mirelleTwinWarden,

  // orielSpectrum, orielPrism and orielEndlessPrism are implemented — see
  // the "Spectrum and Prism" group.
  HeroBehaviour.orielFasterCycle,
  HeroBehaviour.orielSaturation,
  // orielWhiteLight: the 6 s duration is free, but "reactions deal x3"
  // needs Reaction/elementalBonus damage wiring that does not exist yet —
  // projectiles.elementalBonus is set and never read anywhere. Shipping the
  // duration alone would be a card that promises x3 and does not deliver.
  // Real work for whoever needs elemental/reaction damage bonuses first —
  // Attuned (#Oriel T1b, allElementDamage) and Resonance (T3a,
  // reactionDamage) are blocked on the exact same wiring.
  HeroBehaviour.orielWhiteLight,
};
