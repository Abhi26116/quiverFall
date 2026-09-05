import 'dart:math' as math;

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/hero_runtime.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spawn/room_composer.dart';
import 'package:test/test.dart';

import 'arrow_test_support.dart';
import 'boss_test_support.dart';
import 'enemy_test_support.dart';
import 'hero_test_support.dart';

/// The behaviour half of Phase 10's hero work — mirrors what
/// `boon_behaviour_test.dart` is for Boons. Each test here is what lets a
/// [HeroBehaviour] leave [pendingHeroBehaviourWork].
void main() {
  final HeroCatalogue heroes = loadHeroes();
  final ArrowCatalogue arrows = loadArrows();
  final ContentLibrary content = loadEnemies();

  /// Only for Halden's own boss-half tests: `content` above has no boss
  /// catalogue (`loadEnemies`), and every boss system's own per-tick scan
  /// unconditionally indexes `content.bosses.all[bossIndex]` before
  /// checking archetype — setting `bossIndex` against an empty catalogue
  /// crashes the very next tick, not just whichever system might care.
  final ContentLibrary bossContent = loadContentWithBosses();

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
  final HeroDefinition ashlin = heroes.byArchetype(HeroArchetype.ashlin)!;
  final HeroDefinition corvin = heroes.byArchetype(HeroArchetype.corvin)!;
  final HeroDefinition zea = heroes.byArchetype(HeroArchetype.zea)!;
  final HeroDefinition ovrin = heroes.byArchetype(HeroArchetype.ovrin)!;
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

  /// Same shape as [heroArena], but for Corvin's own tests, which need an
  /// [Arena] with an interior wall to ricochet off of — none of the other
  /// heroes above needed geometry, only a stationary target.
  ({SimWorld world, int target}) corvinArena({
    Arena? arena,
    double playerX = 4.0,
    Map<String, String> talentChoices = const <String, String>{},
    int stars = 0,
  }) {
    final SimWorld world =
        SimWorld(seed: 13, content: content, arena: arena)..autoFire = true;
    world.spawnPlayer(playerX, 4.5);
    HeroLoadoutResolver.apply(
      world,
      corvin,
      HeroState(heroId: 'corvin', stars: stars, talentChoices: talentChoices),
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

  /// A primary target 8 u east of the player, and [groupedCount] bystanders
  /// further east still along the same line — close enough to the primary
  /// to count as "grouped" (within 1.6 u, ADR 0007) but never directly hit,
  /// since a non-piercing arrow always reaches the nearer primary first.
  /// Mirrors bramArena's own placement trick exactly. Shared by the "Pull"
  /// and "Crush" groups — both are Rook mechanics keyed off the identical
  /// grouping geometry.
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

  group("Warden's Lattice and Warden's Fury", () {
    /// The maximum "seconds left" seen on any live Windline segment across
    /// [ticks] — the closest a poll ever gets to a segment's own duration
    /// at the moment it was laid, since [WindlineStore.expiryAt] only
    /// counts down afterward.
    double maxWindlineSecondsRemaining(SimWorld world, int ticks) {
      double maxRemaining = 0;
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < ticks; t++) {
        world.tick(idle);
        for (int s = 0; s < world.windlines.capacity; s++) {
          if (!world.windlines.isAlive(s)) continue;
          final double remaining =
              world.windlines.expiryAt(s) - world.elapsedSeconds;
          if (remaining > maxRemaining) maxRemaining = remaining;
        }
      }
      return maxRemaining;
    }

    test("Warden's Lattice (★5a): the Ultimate's own Windlines last 4 s",
        () {
      final ({SimWorld world, int target}) a = arena(
        stars: 5,
        talentChoices: <String, String>{'5': 'a'},
      );
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(maxWindlineSecondsRemaining(a.world, 120), closeTo(4.0, 0.1));
    });

    test(
        "without Warden's Lattice, the Ultimate's own Windlines use the "
        'ordinary duration', () {
      final ({SimWorld world, int target}) a = arena();
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(maxWindlineSecondsRemaining(a.world, 120),
          closeTo(SimConfig.windlineDuration, 0.1));
    });

    /// Fires the Ultimate at a one-hit-kill target and returns the
    /// Ultimate's own charge once the kill has actually landed — [fury]
    /// toggles Warden's Fury so the two runs differ only in whether its
    /// own +30 % refund applied to that one kill.
    double chargeAfterUltimateKill({required bool fury}) {
      // Both runs stay at ★5 (with or without the branch actually picked) —
      // comparing against a ★0 baseline would silently mix Curves.heroStat's
      // own star scaling into the difference, the same trap an earlier
      // Halden test hit.
      final ({SimWorld world, int target}) a = arena(
        stars: 5,
        talentChoices: fury ? <String, String>{'5': 'b'} : const <String, String>{},
      );
      a.world.autoFire = false;
      a.world.entities.maxHealth[a.target] = 1;
      a.world.entities.health[a.target] = 1;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120 && a.world.entities.alive[a.target] == 1; t++) {
        a.world.tick(idle);
      }
      expect(a.world.entities.alive[a.target], 0,
          reason: 'the one-hit-kill target was never actually killed');
      return a.world.hero.ultimateCharge;
    }

    test(
        "Warden's Fury (★5b): a kill from the Ultimate's own arrow refunds "
        '+30 % more charge than the same kill without it', () {
      final double withoutFury = chargeAfterUltimateKill(fury: false);
      final double withFury = chargeAfterUltimateKill(fury: true);
      expect(withFury - withoutFury, closeTo(0.30, 1e-6));
    });

    test("Warden's Fury adds nothing to a kill made by an ordinary arrow",
        () {
      double chargeAfterOrdinaryKill({required bool fury}) {
        // Same ★5-on-both-sides reasoning as chargeAfterUltimateKill above.
        final ({SimWorld world, int target}) a = arena(
          stars: 5,
          talentChoices:
              fury ? <String, String>{'5': 'b'} : const <String, String>{},
        );
        a.world.entities.maxHealth[a.target] = 1;
        a.world.entities.health[a.target] = 1;
        final InputSnapshot idle = InputSnapshot();
        for (int t = 0;
            t < 120 && a.world.entities.alive[a.target] == 1;
            t++) {
          a.world.tick(idle);
        }
        expect(a.world.entities.alive[a.target], 0,
            reason: 'the one-hit-kill target was never actually killed');
        return a.world.hero.ultimateCharge;
      }

      final double withoutFury = chargeAfterOrdinaryKill(fury: false);
      final double withFury = chargeAfterOrdinaryKill(fury: true);
      expect(withFury, closeTo(withoutFury, 1e-6));
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

  group('Bleed', () {
    test('every 4th arrow fired is tagged to bleed, not the others', () {
      final ({SimWorld world, int target}) a = kestrelArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'b'},
      );
      final InputSnapshot idle = InputSnapshot();
      final List<int> bleedFlags = <int>[];
      // Events accumulate across ticks (cleared only on a room boundary,
      // not every tick), so re-scanning from index 0 on every iteration
      // would reprocess the same early ticks' events over and over — this
      // cursor is what keeps each event read exactly once. Read willBleed
      // the instant each arrow spawns, not from a slot index kept around
      // for later — that slot can be recycled by a later arrow well before
      // this loop ends.
      int eventsSeen = 0;
      for (int t = 0; t < 300 && bleedFlags.length < 5; t++) {
        a.world.tick(idle);
        for (int e = eventsSeen; e < a.world.events.count; e++) {
          if (a.world.events.typeAt(e) == SimEventType.arrowFired) {
            final int slot = a.world.events.entityAAt(e);
            bleedFlags.add(a.world.projectiles.willBleed[slot]);
          }
        }
        eventsSeen = a.world.events.count;
      }
      expect(bleedFlags.length, greaterThanOrEqualTo(5));
      for (int idx = 0; idx < bleedFlags.length; idx++) {
        final bool shouldBleed = (idx + 1) % 4 == 0;
        expect(bleedFlags[idx], shouldBleed ? 1 : 0, reason: 'arrow #${idx + 1}');
      }
    });

    test('the 4th arrow applies a bleed stack and its 3s duration to the target', () {
      final ({SimWorld world, int target}) a = kestrelArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'b'},
      );
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 300; t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.bleedStacks[a.target], 1);
      expect(a.world.enemies.bleedRemaining[a.target], greaterThan(0));
      expect(a.world.enemies.bleedRemaining[a.target], lessThanOrEqualTo(3.0));
    });

    test('without the talent, no arrow is ever tagged to bleed', () {
      final ({SimWorld world, int target}) a = kestrelArena();
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 300; t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.bleedStacks[a.target], 0);
    });

    test("a bleed stack deals damage at Burn's own 4%/s rate", () {
      final ({SimWorld world, int target}) a = kestrelArena()
        ..world.autoFire = false;
      a.world.enemies.bleedStacks[a.target] = 1;
      a.world.enemies.bleedRemaining[a.target] = 3.0;
      final double maxHp = a.world.entities.maxHealth[a.target];
      final double before = a.world.entities.health[a.target];

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60; t++) {
        a.world.tick(idle);
      }
      final double lost = before - a.world.entities.health[a.target];
      expect(lost, closeTo(maxHp * 0.04, maxHp * 0.04 * 0.15));
    });

    test('bleed expires after its duration and stops dealing damage', () {
      final ({SimWorld world, int target}) a = kestrelArena()
        ..world.autoFire = false;
      a.world.enemies.bleedStacks[a.target] = 1;
      a.world.enemies.bleedRemaining[a.target] = 0.05;

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 10; t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.bleedStacks[a.target], 0);

      final double afterExpiry = a.world.entities.health[a.target];
      for (int t = 0; t < 30; t++) {
        a.world.tick(idle);
      }
      expect(a.world.entities.health[a.target], afterExpiry);
    });

    test('Freeze suppresses Bleed damage, same as it does Burn', () {
      final ({SimWorld world, int target}) a = kestrelArena()
        ..world.autoFire = false;
      a.world.enemies.bleedStacks[a.target] = 1;
      a.world.enemies.bleedRemaining[a.target] = 3.0;
      a.world.status.frozenRemaining[a.target] = 1.0;
      final double before = a.world.entities.health[a.target];

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 30; t++) {
        a.world.tick(idle);
      }
      expect(a.world.entities.health[a.target], before);
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

    /// The player near the west wall and a stationary target 11 u away —
    /// beyond Marked's 8 u threshold, still inside `SimConfig.arenaWidth`'s
    /// 16 u — an out-of-bounds target is never actually hit at all
    /// (ProjectileSystem discards any arrow whose flight leaves
    /// `arena.containsPoint`), which the Weave group's own arena ran into
    /// first.
    ({SimWorld world, int target}) markedArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 46, content: content)
        ..autoFire = true;
      world.spawnPlayer(1.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        vane,
        HeroState(heroId: 'vane', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int target = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[target] = 0;
      world.entities.maxHealth[target] = 1e9;
      world.entities.health[target] = 1e9;
      return (world: world, target: target);
    }

    /// The `valueA` of the world's own first `damageDealt` event.
    double? firstDamageDealt(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 400; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.damageDealt) {
            return world.events.valueAAt(e);
          }
        }
      }
      return null;
    }

    test('a mark on the target adds +25 % damage', () {
      // Two separate worlds' own *first* hit, rather than a second hit in
      // the same one: standing still for longer between two sequential
      // hits also escalates Draw tier, which would confound the ratio with
      // a second, unrelated multiplier.
      final ({SimWorld world, int target}) unmarked = markedArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
      );
      final double? plain = firstDamageDealt(unmarked.world);

      final ({SimWorld world, int target}) marked = markedArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
      );
      marked.world.enemies.markedRemaining[marked.target] = 5.0;
      final double? boosted = firstDamageDealt(marked.world);

      expect(plain, isNotNull);
      expect(boosted, isNotNull);
      // Marked's own +25 % is additive with Vane's own Distance term
      // (docs/04 §4.1 rule 1 — every boonSum term sums within one source),
      // not a clean 1.25x on its own: at ~11 u, Distance alone already
      // contributes 0.06 * 11 = 0.66, so the ratio is
      // (1 + 0.66 + 0.25) / (1 + 0.66).
      expect(boosted! / plain!, closeTo(1.91 / 1.66, 0.02));
    });

    test('a hit beyond 8 u marks the target', () {
      final ({SimWorld world, int target}) a = markedArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
      );
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0;
          t < 200 && a.world.enemies.markedRemaining[a.target] == 0;
          t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.markedRemaining[a.target], greaterThan(0));
    });

    test('a hit from within 8 u does not mark the target', () {
      final SimWorld world = SimWorld(seed: 48, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        vane,
        const HeroState(
            heroId: 'vane', stars: 3, talentChoices: <String, String>{'3': 'a'}),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int target = world.spawnEnemy(EnemyArchetype.mote, 10.0, 4.5);
      world.enemies.speedScale[target] = 0;
      world.entities.maxHealth[target] = 1e9;
      world.entities.health[target] = 1e9;

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        world.tick(idle);
      }
      expect(world.enemies.markedRemaining[target], 0);
    });

    test('the mark expires after 5 s once nothing keeps refreshing it', () {
      final ({SimWorld world, int target}) a = markedArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
      );
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0;
          t < 120 && a.world.enemies.markedRemaining[a.target] == 0;
          t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.markedRemaining[a.target], greaterThan(0));

      // Stop landing new beyond-8 u hits, or every one would refresh it.
      a.world.autoFire = false;
      for (int t = 0; t < 400; t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.markedRemaining[a.target], 0);
    });
  });

  group('Verdict and Judgment Spear', () {
    ({SimWorld world, int target}) haldenArena({
      bool elite = false,
      ContentLibrary? contentOverride,
    }) {
      final SimWorld world =
          SimWorld(seed: 51, content: contentOverride ?? content)
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

    // ── Verdict's boss half, plus Zealot/Warded/Sentence/Swift Judgment ──
    // (docs/07 §7.3). Reachable now that `EnemyStore.isBoss` exists
    // (Phase 11) — see ADR 0069. `bossIndex` is set directly on an
    // ordinary mote, using `bossContent` (which, unlike `content` above,
    // carries a real boss catalogue — every boss system's own per-tick
    // scan indexes `content.bosses.all[bossIndex]` unconditionally, which
    // crashes against an empty catalogue). Umbral Twin's own real
    // catalogue index is used deliberately: its own system (`UmbralTwin
    // System.update`, ADR 0066) is a confirmed no-op, so nothing else
    // reacts to this mote suddenly looking like a boss's own primary.
    final int fakeBossIndex =
        bossContent.bosses.indexOfArchetype(BossArchetype.umbralTwin);

    test('Verdict: +40 % damage to a boss target too', () {
      final ({SimWorld world, int target}) common = haldenArena();
      final ({SimWorld world, int target}) boss =
          haldenArena(contentOverride: bossContent);
      boss.world.enemies.bossIndex[boss.target] = fakeBossIndex;

      final double? commonDamage = firstDamageDealt(common.world);
      final double? bossDamage = firstDamageDealt(boss.world);
      expect(commonDamage, isNotNull);
      expect(bossDamage, isNotNull);
      expect(bossDamage! / commonDamage!, closeTo(1.40, 0.01));
    });

    test('Zealot (★1a): raises the boss bonus to +55 %, leaves the elite '
        'bonus at +40 %', () {
      final ({SimWorld world, int target}) common = haldenArena();
      final ({SimWorld world, int target}) boss =
          haldenArena(contentOverride: bossContent);
      boss.world.enemies.bossIndex[boss.target] = fakeBossIndex;
      final ({SimWorld world, int target}) elite = haldenArena(elite: true);

      // `Curves.heroStat` scales with `stars`, so `common` is levelled to
      // the identical star 1 too — with no talent chosen for node 1 — to
      // isolate Zealot's own effect from the stat growth that would
      // otherwise contaminate every ratio below.
      HeroLoadoutResolver.apply(
        common.world,
        halden,
        const HeroState(heroId: 'halden', stars: 1),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      for (final ({SimWorld world, int target}) a in <({SimWorld world, int target})>[
        boss,
        elite,
      ]) {
        HeroLoadoutResolver.apply(
          a.world,
          halden,
          const HeroState(
            heroId: 'halden',
            stars: 1,
            talentChoices: <String, String>{'1': 'a'},
          ),
          ashShaft,
          const ArrowInstance(arrowId: 'ash_shaft'),
        );
      }

      final double? commonDamage = firstDamageDealt(common.world);
      final double? bossDamage = firstDamageDealt(boss.world);
      final double? eliteDamage = firstDamageDealt(elite.world);
      expect(bossDamage! / commonDamage!, closeTo(1.55, 0.01));
      expect(eliteDamage! / commonDamage, closeTo(1.40, 0.01));
    });

    test('Verdict: boss attacks deal -15 % to Halden', () {
      final ({SimWorld world, int target}) a =
          haldenArena(contentOverride: bossContent);
      a.world.enemies.bossIndex[a.target] = fakeBossIndex;
      final int p = a.world.player.index;
      a.world.tick(InputSnapshot());

      final double dealt =
          EnemyAttack.damagePlayer(a.world.ai, 0.20, source: a.target);

      expect(dealt, closeTo(a.world.entities.maxHealth[p] * 0.20 * 0.85, 1e-6));
    });

    test('Warded (★1b): raises the boss damage-taken reduction to -28 %',
        () {
      final ({SimWorld world, int target}) a =
          haldenArena(contentOverride: bossContent);
      a.world.enemies.bossIndex[a.target] = fakeBossIndex;
      HeroLoadoutResolver.apply(
        a.world,
        halden,
        const HeroState(
          heroId: 'halden',
          stars: 1,
          talentChoices: <String, String>{'1': 'b'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int p = a.world.player.index;
      a.world.tick(InputSnapshot());

      final double dealt =
          EnemyAttack.damagePlayer(a.world.ai, 0.20, source: a.target);

      expect(dealt, closeTo(a.world.entities.maxHealth[p] * 0.20 * 0.72, 1e-6));
    });

    test('Verdict\'s boss damage-taken reduction does not apply to a '
        'common enemy\'s attack', () {
      final ({SimWorld world, int target}) a = haldenArena();
      // `a.target` is left an ordinary mote — no `bossIndex` set.
      final int p = a.world.player.index;
      a.world.tick(InputSnapshot());

      final double dealt =
          EnemyAttack.damagePlayer(a.world.ai, 0.20, source: a.target);

      expect(dealt, closeTo(a.world.entities.maxHealth[p] * 0.20, 1e-6));
    });

    test('Sentence (★3a): Judgment Spear marks the boss it strikes for '
        '10 s', () {
      final ({SimWorld world, int target}) a =
          haldenArena(contentOverride: bossContent)..world.autoFire = false;
      a.world.enemies.bossIndex[a.target] = fakeBossIndex;
      // A real boss-sized pool — the Spear's own multi-thousand-percent
      // share would otherwise kill this 1000-HP mote outright, wiping the
      // mark this test means to observe along with the rest of its state.
      a.world.entities.maxHealth[a.target] = 1.0e7;
      a.world.entities.health[a.target] = 1.0e7;
      HeroLoadoutResolver.apply(
        a.world,
        halden,
        const HeroState(
          heroId: 'halden',
          stars: 3,
          talentChoices: <String, String>{'3': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      // `autoFire` never turns on in this test — the only arrow that ever
      // flies is the Spear's own, so whichever hit lands is unambiguously
      // its own.
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      final double? spearDamage = firstDamageDealt(a.world);

      expect(spearDamage, isNotNull);
      // One tick's worth of decay already elapsed within the same tick the
      // mark was set, the identical "set mid-tick, decremented later that
      // same tick" shape every other timed field in this pipeline has.
      expect(a.world.enemies.markedRemaining[a.target], closeTo(10.0, 0.02));
    });

    test('Sentence\'s own +20 % mark stacks additively on Verdict\'s own '
        '+40 % boss bonus', () {
      final ({SimWorld world, int target}) baseline =
          haldenArena(contentOverride: bossContent);
      baseline.world.enemies.bossIndex[baseline.target] = fakeBossIndex;

      final ({SimWorld world, int target}) marked =
          haldenArena(contentOverride: bossContent);
      marked.world.enemies.bossIndex[marked.target] = fakeBossIndex;
      // Set directly rather than by firing the Ultimate — this test is
      // about what the mark itself is worth, not the Spear's own travel;
      // the Spear landing the mark is already covered above.
      marked.world.enemies.markedRemaining[marked.target] = 10.0;

      for (final ({SimWorld world, int target}) a in <({SimWorld world, int target})>[
        baseline,
        marked,
      ]) {
        HeroLoadoutResolver.apply(
          a.world,
          halden,
          const HeroState(
            heroId: 'halden',
            stars: 3,
            talentChoices: <String, String>{'3': 'a'},
          ),
          ashShaft,
          const ArrowInstance(arrowId: 'ash_shaft'),
        );
      }

      final double? baselineDamage = firstDamageDealt(baseline.world);
      final double? markedDamage = firstDamageDealt(marked.world);
      expect(markedDamage! / baselineDamage!, closeTo(1.60 / 1.40, 0.02));
    });

    test('Sentence never marks a common target the Spear happens to hit',
        () {
      final ({SimWorld world, int target}) a = haldenArena()
        ..world.autoFire = false;
      // `a.target` is left an ordinary mote.
      HeroLoadoutResolver.apply(
        a.world,
        halden,
        const HeroState(
          heroId: 'halden',
          stars: 3,
          talentChoices: <String, String>{'3': 'a'},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.enemies.markedRemaining[a.target], 0);
    });

    test('Swift Judgment (★3b): the Ultimate charges 40 % faster from a '
        'boss hit', () {
      final ({SimWorld world, int target}) common = haldenArena();
      final ({SimWorld world, int target}) boss =
          haldenArena(contentOverride: bossContent);
      boss.world.enemies.bossIndex[boss.target] = fakeBossIndex;

      for (final ({SimWorld world, int target}) a in <({SimWorld world, int target})>[
        common,
        boss,
      ]) {
        HeroLoadoutResolver.apply(
          a.world,
          halden,
          const HeroState(
            heroId: 'halden',
            stars: 3,
            talentChoices: <String, String>{'3': 'b'},
          ),
          ashShaft,
          const ArrowInstance(arrowId: 'ash_shaft'),
        );
        // Let a real hit land — a single tick's own arrow is still in
        // flight, and no charge accrues until it actually connects.
        firstDamageDealt(a.world);
      }

      expect(boss.world.hero.ultimateCharge,
          closeTo(common.world.hero.ultimateCharge * 1.40, 0.02));
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

  group('Overheal', () {
    /// Health pinned just under max — any heal at all overflows almost
    /// entirely, so a single lifesteal tick or Bloom pulse is enough to
    /// observe the shield forming.
    ({SimWorld world, int target}) nearMaxHealthArena({
      required bool talent,
      bool autoFire = true,
    }) {
      final SimWorld world = SimWorld(seed: 65, content: content)
        ..autoFire = autoFire;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        lira,
        HeroState(
          heroId: 'lira',
          stars: talent ? 3 : 0,
          talentChoices: talent ? const <String, String>{'3': 'a'} : const {},
        ),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int p = world.player.index;
      world.entities.health[p] = world.entities.maxHealth[p] - 0.5;
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;
      return (world: world, target: mote);
    }

    test("Lifebound's own lifesteal overflow becomes a shield", () {
      final ({SimWorld world, int target}) a =
          nearMaxHealthArena(talent: true);
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        a.world.tick(idle);
        if (a.world.hero.overhealShield > 0) break;
      }
      expect(a.world.hero.overhealShield, greaterThan(0));
      expect(
        a.world.entities.health[a.world.player.index],
        closeTo(a.world.entities.maxHealth[a.world.player.index], 1e-6),
      );
    });

    test('without the talent, lifesteal overflow forms no shield', () {
      final ({SimWorld world, int target}) a =
          nearMaxHealthArena(talent: false);
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120; t++) {
        a.world.tick(idle);
      }
      expect(a.world.hero.overhealShield, 0);
    });

    test("Verdant Bloom's own regen overflow becomes a shield too", () {
      final ({SimWorld world, int target}) a =
          nearMaxHealthArena(talent: true, autoFire: false);
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      // One tick's own heal pulse (~maxHp * 0.10 / 60) is smaller than the
      // 0.5 HP gap the arena starts with — several ticks' worth of pulses
      // are needed before the accumulated heal actually overflows.
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 30; t++) {
        a.world.tick(idle);
      }
      expect(a.world.hero.overhealShield, greaterThan(0));
    });

    test('the shield caps at 30% max HP no matter how much overflows', () {
      final ({SimWorld world, int target}) a =
          nearMaxHealthArena(talent: true, autoFire: false);
      final int p = a.world.player.index;
      final double maxHp = a.world.entities.maxHealth[p];
      a.world.entities.health[p] = maxHp; // already full — every drop of heal overflows
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 300; t++) {
        a.world.tick(idle);
      }
      expect(a.world.hero.overhealShield, closeTo(maxHp * 0.30, 1e-6));
    });

    test('the shield absorbs damage before HP, independent of Shieldweave', () {
      final ({SimWorld world, int target}) a = nearMaxHealthArena(
        talent: true,
        autoFire: false,
      );
      final int p = a.world.player.index;
      final double maxHp = a.world.entities.maxHealth[p];
      a.world.entities.health[p] = maxHp;
      a.world.hero.overhealShield = maxHp * 0.10;
      a.world.boons.shield = 0; // Shieldweave's own pool, untouched

      final double dealt =
          EnemyAttack.damagePlayer(a.world.ai, 0.05, source: -1);

      expect(dealt, closeTo(0, 1e-6),
          reason: 'a hit smaller than the shield should cost no HP at all');
      expect(a.world.entities.health[p], closeTo(maxHp, 1e-6));
      expect(a.world.hero.overhealShield, closeTo(maxHp * 0.05, 1e-6));
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

  group('Hall of Mirrors', () {
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

    /// Every tick's own `arrowFired` events, grouped by the tick that
    /// produced them — a duplicate (guaranteed or Reflection's own) always
    /// spawns synchronously within the same tick as the shot that made it,
    /// so grouping by tick is what lets a per-shot guarantee be checked
    /// exactly rather than only on average.
    List<List<({double damage, double angle})>> arrowsPerTick(
        SimWorld world, int ticks) {
      final List<List<({double damage, double angle})>> out =
          <List<({double damage, double angle})>>[];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < ticks; t++) {
        world.tick(idle);
        final List<({double damage, double angle})> thisTick =
            <({double damage, double angle})>[];
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) != SimEventType.arrowFired) continue;
          final int slot = world.events.entityAAt(e);
          thisTick.add((
            damage: world.projectiles.damage[slot],
            angle: math.atan2(
                world.entities.velY[slot], world.entities.velX[slot]),
          ));
        }
        world.events.clear();
        out.add(thisTick);
      }
      return out;
    }

    List<int> companionsOf(SimWorld world) {
      final List<int> found = <int>[];
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 1 &&
            world.entities.kindOf(i) == EntityKind.companion) {
          found.add(i);
        }
      }
      return found;
    }

    test('every arrow guarantees 3 more at full damage while the window runs',
        () {
      final ({SimWorld world, int target}) a = mirelleArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      // The ultimate-press tick can itself carry a leftover ordinary shot,
      // fired by `_updateFiring` (earlier in `tick()`) before `_fireUltimate`
      // (later in the same tick) ever sets the window — discarding its event
      // here is what keeps that pre-window arrow out of the first tick this
      // test actually samples.
      a.world.events.clear();

      final double fullDamage = a.world.playerAttack;
      final List<List<({double damage, double angle})>> ticks =
          arrowsPerTick(a.world, 7 * 60);
      bool sawAShot = false;
      for (final List<({double damage, double angle})> tick in ticks) {
        final int originals = tick
            .where((({double damage, double angle}) x) =>
                (x.damage - fullDamage).abs() < 1e-6)
            .length;
        if (originals == 0) continue;
        sawAShot = true;
        // 1 original + 3 guaranteed duplicates, all at full damage — a hard
        // floor regardless of whether Reflection's own probabilistic
        // cascade (reduced-share duplicates) also fires this tick.
        expect(originals, greaterThanOrEqualTo(4));
      }
      expect(sawAShot, isTrue);
    });

    test('the guarantee stops once the 8 s window expires', () {
      final ({SimWorld world, int target}) a = mirelleArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      for (int t = 0; t < 9 * 60; t++) {
        a.world.tick(InputSnapshot());
      }
      expect(a.world.hero.hallOfMirrorsRemaining, 0);

      final double fullDamage = a.world.playerAttack;
      final List<List<({double damage, double angle})>> ticks =
          arrowsPerTick(a.world, 3000);
      final bool sawAnUnaugmentedShot = ticks.any(
          (List<({double damage, double angle})> tick) =>
              tick
                  .where((({double damage, double angle}) x) =>
                      (x.damage - fullDamage).abs() < 1e-6)
                  .length ==
              1);
      expect(sawAnUnaugmentedShot, isTrue);
    });

    test('spawns a mirror clone at 60 % stats for 8 s', () {
      final ({SimWorld world, int target}) a = mirelleArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final List<int> clones = companionsOf(a.world);
      expect(clones, hasLength(1));
      final int clone = clones.single;
      expect(a.world.companions.damageShare[clone], closeTo(0.60, 1e-9));
      expect(a.world.companions.fireIntervalSeconds[clone],
          closeTo(1.0 / (0.60 * 2.20), 1e-6));
      expect(a.world.companions.remaining[clone], closeTo(8.0, 0.02));
    });

    test('Endless Hall (★5a): the duplication window runs 14 s instead of 8',
        () {
      final ({SimWorld world, int target}) a = mirelleArena(
        stars: 5,
        talentChoices: const <String, String>{'5': 'a'},
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.hallOfMirrorsRemaining, closeTo(14.0, 0.02));
    });

    test(
        'Twin Warden (★5b): the clone rises to 80 % stats and outlasts the '
        'ordinary window, which stays at 8 s', () {
      final ({SimWorld world, int target}) a = mirelleArena(
        stars: 5,
        talentChoices: const <String, String>{'5': 'b'},
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.hallOfMirrorsRemaining, closeTo(8.0, 0.02));
      final List<int> clones = companionsOf(a.world);
      expect(clones, hasLength(1));
      final int clone = clones.single;
      expect(a.world.companions.damageShare[clone], closeTo(0.80, 1e-9));
      expect(a.world.companions.fireIntervalSeconds[clone],
          closeTo(1.0 / (0.80 * 2.20), 1e-6));
      expect(a.world.companions.remaining[clone], greaterThan(60.0));
    });
  });

  group('Aegis Pin and Riposte', () {
    ({SimWorld world, int target}) ovrinArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 103, content: content)
        ..autoFire = false;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        ovrin,
        HeroState(heroId: 'ovrin', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[mote] = 0;
      world.entities.maxHealth[mote] = 1e9;
      world.entities.health[mote] = 1e9;
      return (world: world, target: mote);
    }

    test(
        'Aegis Pin blocks a hit entirely and reflects 30 % of it back at '
        'the attacker', () {
      final ({SimWorld world, int target}) a = ovrinArena();
      a.world.tick(InputSnapshot());
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final int p = a.world.player.index;
      final double raw = a.world.entities.maxHealth[p] * 0.20;
      final double before = a.world.entities.health[a.target];

      final double dealt =
          EnemyAttack.damagePlayer(a.world.ai, 0.20, source: a.target);

      expect(dealt, 0);
      final double reflected = before - a.world.entities.health[a.target];
      expect(reflected, closeTo(raw * 0.30, 1e-6));
    });

    test('without Aegis Pin active, the same hit lands normally', () {
      final ({SimWorld world, int target}) a = ovrinArena();
      a.world.tick(InputSnapshot());
      final int p = a.world.player.index;
      final double raw = a.world.entities.maxHealth[p] * 0.20;

      final double dealt =
          EnemyAttack.damagePlayer(a.world.ai, 0.20, source: a.target);

      expect(dealt, closeTo(raw, 1e-6));
    });

    test('Long Wall (★5a): Aegis Pin lasts 10 s instead of 6', () {
      final ({SimWorld world, int target}) a = ovrinArena(
        stars: 5,
        talentChoices: const <String, String>{'5': 'a'},
      );
      a.world.tick(InputSnapshot());
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.aegisPinRemaining, closeTo(10.0, 0.02));
    });

    test('Mirror Wall (★5b): reflects 100 % for a shorter 3 s', () {
      final ({SimWorld world, int target}) a = ovrinArena(
        stars: 5,
        talentChoices: const <String, String>{'5': 'b'},
      );
      a.world.tick(InputSnapshot());
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.aegisPinRemaining, closeTo(3.0, 0.02));

      final int p = a.world.player.index;
      final double raw = a.world.entities.maxHealth[p] * 0.20;
      final double before = a.world.entities.health[a.target];
      EnemyAttack.damagePlayer(a.world.ai, 0.20, source: a.target);
      final double reflected = before - a.world.entities.health[a.target];
      expect(reflected, closeTo(raw, 1e-6));
    });

    test("Riposte (★3b): breaking Ovrin's own shield deals 200 % AoE", () {
      final ({SimWorld world, int target}) a = ovrinArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'b'},
      );
      a.world.tick(InputSnapshot());
      a.world.boons.shield = 5.0;

      final int nearby = a.world.spawnEnemy(EnemyArchetype.mote, 4.0, 6.0);
      a.world.enemies.speedScale[nearby] = 0;
      a.world.entities.maxHealth[nearby] = 1e9;
      a.world.entities.health[nearby] = 1e9;

      // A big hit, guaranteed to exceed the 5.0 shield and break it.
      EnemyAttack.damagePlayer(a.world.ai, 1.0, source: a.target);
      expect(a.world.hero.riposteNovaPending, isTrue);

      final double before = a.world.entities.health[nearby];
      a.world.tick(InputSnapshot());
      final double dealt = before - a.world.entities.health[nearby];
      expect(dealt, closeTo(a.world.playerAttack * 2.00, 1e-6));
    });

    test('without Riposte, breaking the shield does nothing extra', () {
      final ({SimWorld world, int target}) a = ovrinArena();
      a.world.tick(InputSnapshot());
      a.world.boons.shield = 5.0;

      EnemyAttack.damagePlayer(a.world.ai, 1.0, source: a.target);
      expect(a.world.hero.riposteNovaPending, isFalse);
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

    test('Overload (★3b): a chain hit marks its targets for 4 s', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = torvArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'b'},
      );
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 400; t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.markedRemaining[a.nearby[0]], greaterThan(0));
    });

    test('without Overload, chains never mark their targets', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = torvArena();
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 400; t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.markedRemaining[a.nearby[0]], 0);
    });

    test("Overload's own mark adds +20 % damage to the marked target's next hit",
        () {
      final ({SimWorld world, int primary, List<int> nearby}) base =
          torvArena(stars: 3, talentChoices: <String, String>{'3': 'b'});
      final double? plain = firstDamageDealt(base.world);

      final ({SimWorld world, int primary, List<int> nearby}) marked =
          torvArena(stars: 3, talentChoices: <String, String>{'3': 'b'});
      marked.world.enemies.markedRemaining[marked.primary] = 5.0;
      final double? boosted = firstDamageDealt(marked.world);

      expect(plain, isNotNull);
      expect(boosted, isNotNull);
      expect(boosted! / plain!, closeTo(1.20, 0.01));
    });

    test('Thunderhead (★5b): Tempest Nock chains also stun for 0.5 s', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = torvArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'b'},
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      bool sawFrozen = false;
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 200; t++) {
        a.world.tick(idle);
        if (a.world.status.isFrozen(a.nearby[0])) {
          sawFrozen = true;
          break;
        }
      }
      expect(sawFrozen, isTrue);
    });

    test('without Thunderhead, Tempest Nock chains do not stun', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = torvArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 200; t++) {
        a.world.tick(idle);
        expect(a.world.status.isFrozen(a.nearby[0]), isFalse);
      }
    });

    test(
        'the base Arc passive never stuns, even with Thunderhead, outside '
        "Tempest Nock's own window", () {
      final ({SimWorld world, int primary, List<int> nearby}) a = torvArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'b'},
      );
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 400; t++) {
        a.world.tick(idle);
        expect(a.world.status.isFrozen(a.nearby[0]), isFalse);
      }
    });
  });

  group('Pull', () {
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

    test('Anchor (★3b): a crit pull roots the target for 0.6 s', () {
      final ({SimWorld world, int primary, List<int> grouped}) a = rookArena(
        forceCrit: true,
        stars: 3,
        talentChoices: const <String, String>{'3': 'b'},
      );

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

      // One tick's worth of decay has already elapsed within the same
      // tick the root was set — the same "set mid-tick" shape every other
      // timed field in this pipeline has.
      expect(a.world.status.frozenRemaining[a.primary], closeTo(0.6, 0.02));

      // A rooted enemy is a frozen one, structurally — the same hard stop
      // `AiSystem._freeze` already gives Sela's own Frost freeze, not a
      // second, narrower primitive invented for this talent.
      expect(a.world.status.isFrozen(a.primary), isTrue);
    });

    test('without Anchor, a crit pull never roots the target', () {
      final ({SimWorld world, int primary, List<int> grouped}) a = rookArena(
        forceCrit: true,
      );

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
      expect(a.world.status.frozenRemaining[a.primary], 0);
    });

    test('Anchor never shortens a longer Frost freeze already running',
        () {
      final ({SimWorld world, int primary, List<int> grouped}) a = rookArena(
        forceCrit: true,
        stars: 3,
        talentChoices: const <String, String>{'3': 'b'},
      );
      a.world.status.frozenRemaining[a.primary] = 5.0;

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
      // The pre-set freeze decays for real across however many ticks the
      // crit's own travel takes, so this only needs to confirm Anchor's
      // own briefer 0.6 s never overwrote it — comfortable margin above
      // that, not an exact figure.
      expect(a.world.status.frozenRemaining[a.primary], greaterThan(3.5));
    });
  });

  group('Crush', () {
    test('does not bleed an enemy with nothing else grouped around it', () {
      final ({SimWorld world, int primary, List<int> grouped}) a = rookArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'a'},
      );
      a.world.autoFire = false;
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60; t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.bleedStacks[a.primary], 0);
    });

    test('grouped enemies pick up stacking bleed within one recheck interval',
        () {
      final ({SimWorld world, int primary, List<int> grouped}) a = rookArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'a'},
        groupedCount: 2,
      );
      a.world.autoFire = false;
      final InputSnapshot idle = InputSnapshot();
      // Crush rechecks 4x/second (every 15 ticks at 60 Hz) — 20 ticks
      // comfortably covers the first recheck.
      for (int t = 0; t < 20; t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.bleedStacks[a.primary], 2);
      expect(a.world.enemies.bleedStacks[a.grouped[0]], greaterThan(0));
    });

    test('the drain scales with grouped count, capped at 4', () {
      // All three at ★3 — matched, so Curves.heroStat's own +12 %/star
      // scaling (which touches nothing about Crush, but does touch every
      // enemy's shared maxHealth = 1e9 baseline the same way regardless)
      // never leaks into this comparison.
      final ({SimWorld world, int primary, List<int> grouped}) a2 = rookArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'a'},
        groupedCount: 2,
      );
      final ({SimWorld world, int primary, List<int> grouped}) a4 = rookArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'a'},
        groupedCount: 4,
      );
      final ({SimWorld world, int primary, List<int> grouped}) a5 = rookArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'a'},
        groupedCount: 5,
        groupedSpacing: 0.2,
      );
      for (final SimWorld w in <SimWorld>[a2.world, a4.world, a5.world]) {
        w.autoFire = false;
      }

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60; t++) {
        a2.world.tick(idle);
        a4.world.tick(idle);
        a5.world.tick(idle);
      }

      final double lost2 = 1e9 - a2.world.entities.health[a2.primary];
      final double lost4 = 1e9 - a4.world.entities.health[a4.primary];
      final double lost5 = 1e9 - a5.world.entities.health[a5.primary];

      expect(lost2, greaterThan(0));
      expect(lost4 / lost2, closeTo(2.0, 0.05));
      expect(lost5 / lost4, closeTo(1.0, 0.05),
          reason: 'a 5th grouped enemy must add nothing past the cap of 4');
    });

    test('without the talent, no enemy ever bleeds from grouping', () {
      final ({SimWorld world, int primary, List<int> grouped}) a =
          rookArena(groupedCount: 4);
      a.world.autoFire = false;
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60; t++) {
        a.world.tick(idle);
      }
      expect(a.world.enemies.bleedStacks[a.primary], 0);
    });
  });

  group('Singularity', () {
    test('fires at the nearest target and pulls a nearby enemy toward it',
        () {
      final ({SimWorld world, int primary, List<int> grouped}) a =
          rookArena(groupedCount: 1, groupedSpacing: 2.0);
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      // `_tickRookSingularity` runs later in the same tick that fires the
      // Ultimate, so one dt of decay has already elapsed by the time this
      // reads — the same same-tick-decay slack every other timed window in
      // this file already needs right after casting.
      expect(a.world.hero.singularityRemaining, closeTo(4.0, 0.02));
      expect(a.world.hero.singularityX, closeTo(12.0, 1e-6));
      expect(a.world.hero.singularityY, closeTo(4.5, 1e-6));

      final int pulled = a.grouped[0];
      final double before =
          (a.world.entities.posX[pulled] - a.world.hero.singularityX).abs();
      a.world.tick(InputSnapshot());
      final double after =
          (a.world.entities.posX[pulled] - a.world.hero.singularityX).abs();
      expect(after, lessThan(before));
    });

    test('detonates for 400 % of playerAttack once the 4 s window ends', () {
      final ({SimWorld world, int primary, List<int> grouped}) a =
          rookArena();
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final double before = a.world.entities.health[a.primary];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 5 * 60; t++) {
        a.world.tick(idle);
      }
      expect(a.world.hero.singularityRemaining, 0);
      final double dealt = before - a.world.entities.health[a.primary];
      expect(dealt, closeTo(a.world.playerAttack * 4.00, 1e-3));
    });

    test('an enemy outside the 6 u radius is never pulled or hit', () {
      final ({SimWorld world, int primary, List<int> grouped}) a =
          rookArena();
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      // Confirms the well locked onto the primary (the only enemy that
      // existed at cast time) before the bystander below is even spawned —
      // spawning it first would risk it being closer to the player than
      // the primary is and becoming the well's own target instead.
      expect(a.world.hero.singularityX, closeTo(12.0, 1e-6));

      // ~10.6 u from the well (12.0/4.5) — safely outside the 6 u radius
      // while staying inside the 16x9 arena, which a point 6+ u further
      // east of the primary alone could not.
      final int far = a.world.spawnEnemy(EnemyArchetype.mote, 2.0, 8.0);
      a.world.enemies.speedScale[far] = 0;
      a.world.entities.maxHealth[far] = 1e9;
      a.world.entities.health[far] = 1e9;

      final double startX = a.world.entities.posX[far];
      final double startHealth = a.world.entities.health[far];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 5 * 60; t++) {
        a.world.tick(idle);
      }
      expect(a.world.entities.posX[far], closeTo(startX, 1e-6));
      expect(a.world.entities.health[far], closeTo(startHealth, 1e-6));
    });

    test('Twin Singularity (★5a): a second well forms at the second-nearest '
        'enemy', () {
      final ({SimWorld world, int primary, List<int> grouped}) a = rookArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'a'},
        groupedCount: 1,
        groupedSpacing: 2.0,
      );
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.singularityRemaining, closeTo(4.0, 0.02));
      expect(a.world.hero.singularityX, closeTo(12.0, 1e-6));
      expect(a.world.hero.singularity2Remaining, closeTo(4.0, 0.02));
      expect(a.world.hero.singularity2X, closeTo(14.0, 1e-6));
    });

    test('without Twin Singularity, only one well ever forms', () {
      final ({SimWorld world, int primary, List<int> grouped}) a = rookArena(
        groupedCount: 1,
        groupedSpacing: 2.0,
      );
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.singularity2Remaining, 0);
    });

    test('Collapsing Singularity (★5b): one well, 6 s, 900 % detonation', () {
      final ({SimWorld world, int primary, List<int> grouped}) a = rookArena(
        stars: 5,
        talentChoices: <String, String>{'5': 'b'},
      );
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.hero.singularityRemaining, closeTo(6.0, 0.02));
      expect(a.world.hero.singularity2Remaining, 0);

      final double before = a.world.entities.health[a.primary];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 7 * 60; t++) {
        a.world.tick(idle);
      }
      final double dealt = before - a.world.entities.health[a.primary];
      expect(dealt, closeTo(a.world.playerAttack * 9.00, 1e-3));
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

    /// Kills [target] with one real arrow (`maxHealth` set to 1 so whatever
    /// lands overkills it outright), stopping the instant it is reaped —
    /// autoFire would otherwise retarget onto the bystander the moment
    /// [target] is gone, contaminating a "the bystander took no damage"
    /// measurement with ordinary, unrelated arrow hits.
    void killWithOneHit(SimWorld world, int target) {
      world.entities.maxHealth[target] = 1;
      world.entities.health[target] = 1;
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 120 && world.entities.alive[target] == 1; t++) {
        world.tick(idle);
      }
    }

    test('Shatter (★3a): killing a frozen enemy deals 250 % in 2 u', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = selaArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
        nearbyOffsets: <double>[1.0], // 1 u from primary, inside the 2 u burst
      );
      a.world.status.frozenRemaining[a.primary] = 10.0;
      final double before = a.world.entities.health[a.nearby[0]];

      killWithOneHit(a.world, a.primary);

      final double dealt = before - a.world.entities.health[a.nearby[0]];
      expect(dealt, closeTo(a.world.playerAttack * 2.50, 1e-6));
    });

    test('killing an un-frozen enemy does not trigger Shatter', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = selaArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
        nearbyOffsets: <double>[1.0],
      );
      final double before = a.world.entities.health[a.nearby[0]];

      killWithOneHit(a.world, a.primary);

      expect(a.world.entities.health[a.nearby[0]], closeTo(before, 1e-6));
    });

    test('without Shatter, killing a frozen enemy does nothing extra', () {
      final ({SimWorld world, int primary, List<int> nearby}) a =
          selaArena(nearbyOffsets: <double>[1.0]);
      a.world.status.frozenRemaining[a.primary] = 10.0;
      final double before = a.world.entities.health[a.nearby[0]];

      killWithOneHit(a.world, a.primary);

      expect(a.world.entities.health[a.nearby[0]], closeTo(before, 1e-6));
    });

    test('Shatter does not reach a bystander outside the 2 u burst', () {
      final ({SimWorld world, int primary, List<int> nearby}) a = selaArena(
        stars: 3,
        talentChoices: <String, String>{'3': 'a'},
        nearbyOffsets: <double>[3.0], // outside the 2 u radius
      );
      a.world.status.frozenRemaining[a.primary] = 10.0;
      final double before = a.world.entities.health[a.nearby[0]];

      killWithOneHit(a.world, a.primary);

      expect(a.world.entities.health[a.nearby[0]], closeTo(before, 1e-6));
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

  group('Rekindle and Rebirth Nova', () {
    ({SimWorld world, int target}) ashlinArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 201, content: content)
        ..autoFire = true;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        ashlin,
        HeroState(heroId: 'ashlin', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int target = world.spawnEnemy(EnemyArchetype.mote, 6.0, 4.5);
      world.enemies.speedScale[target] = 0;
      world.entities.maxHealth[target] = 1e9;
      world.entities.health[target] = 1e9;
      return (world: world, target: target);
    }

    /// Drives the player to a known, low HP, refreshes `world.ai` so it
    /// reflects that, and returns the player's own entity index.
    int setUpForLethalHit(SimWorld world, {double maxHealth = 100}) {
      final int p = world.player.index;
      world.entities.maxHealth[p] = maxHealth;
      world.entities.health[p] = maxHealth * 0.10;
      world.tick(InputSnapshot());
      return p;
    }

    test('Rekindle revives once at 45 % HP with 3 s invulnerability and an AoE nova',
        () {
      final ({SimWorld world, int target}) a = ashlinArena();
      final int p = setUpForLethalHit(a.world);

      final double dealt = EnemyAttack.damagePlayer(a.world.ai, 2.0, source: -1);
      expect(dealt, greaterThan(0));
      expect(a.world.entities.health[p], closeTo(45.0, 1e-6));
      expect(a.world.hero.ashlinInvulnRemaining, closeTo(3.0, 1e-9));
      expect(a.world.hero.rekindlesUsed, 1);
      expect(a.world.hero.rekindleNovaPending, isTrue);

      // The nova itself resolves on the next tick, in SimWorld — see the
      // field's own doc comment for why it can't resolve inside
      // EnemyAttack.damagePlayer directly.
      final double before = a.world.entities.health[a.target];
      a.world.tick(InputSnapshot());
      expect(a.world.hero.rekindleNovaPending, isFalse);
      expect(a.world.entities.health[a.target], lessThan(before));
    });

    test('without a lethal hit, Rekindle never triggers', () {
      final ({SimWorld world, int target}) a = ashlinArena();
      final int p = a.world.player.index;
      a.world.tick(InputSnapshot());
      EnemyAttack.damagePlayer(a.world.ai, 0.05, source: -1);
      expect(a.world.hero.rekindlesUsed, 0);
      expect(a.world.entities.health[p], greaterThan(0));
    });

    test('Bright Rekindle (★1a): revives at 70 % HP instead of 45 %', () {
      final ({SimWorld world, int target}) a =
          ashlinArena(stars: 1, talentChoices: <String, String>{'1': 'a'});
      final int p = setUpForLethalHit(a.world);
      EnemyAttack.damagePlayer(a.world.ai, 2.0, source: -1);
      expect(a.world.entities.health[p], closeTo(70.0, 1e-6));
    });

    test('Twice Kindled (★1b): 2 revives at 30 % each, then death', () {
      final ({SimWorld world, int target}) a =
          ashlinArena(stars: 1, talentChoices: <String, String>{'1': 'b'});
      final int p = setUpForLethalHit(a.world);
      final InputSnapshot idle = InputSnapshot();

      EnemyAttack.damagePlayer(a.world.ai, 2.0, source: -1);
      expect(a.world.entities.health[p], closeTo(30.0, 1e-6));
      expect(a.world.hero.rekindlesUsed, 1);

      // The revive's own invulnerability blocks a hit outright, so it has
      // to expire before a second lethal hit can even reach the "refuse to
      // die" check at all.
      for (int t = 0; t < 200; t++) {
        a.world.tick(idle);
      }
      expect(a.world.hero.ashlinInvulnRemaining, 0);

      EnemyAttack.damagePlayer(a.world.ai, 2.0, source: -1);
      expect(a.world.entities.health[p], closeTo(30.0, 1e-6));
      expect(a.world.hero.rekindlesUsed, 2);

      for (int t = 0; t < 200; t++) {
        a.world.tick(idle);
      }
      EnemyAttack.damagePlayer(a.world.ai, 2.0, source: -1);
      // `EnemyAttack.damagePlayer` despawns the entity itself and clears
      // `ai.player` directly; `world.player` is a separate cached
      // reference, only ever resynced the next time `SimWorld` itself
      // walks this path (`AiSystem.update`), so the entity store is the
      // one source of truth reachable from a direct call like this test's.
      expect(a.world.entities.alive[p], 0,
          reason: 'no charges left — the third lethal hit must actually kill');
      expect(a.world.hero.rekindlesUsed, 2,
          reason: 'the cap must hold — no third revive');
    });

    test('Rebirth Nova: 500 % AoE, heals 25 %, and refreshes Rekindle', () {
      final ({SimWorld world, int target}) a = ashlinArena();
      final int p = setUpForLethalHit(a.world);
      EnemyAttack.damagePlayer(a.world.ai, 2.0, source: -1);
      expect(a.world.hero.rekindlesUsed, 1);
      a.world.tick(InputSnapshot()); // let the pending nova resolve and clear

      final double playerHealthBefore = a.world.entities.health[p];
      final double targetHealthBefore = a.world.entities.health[a.target];
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(a.world.entities.health[a.target], lessThan(targetHealthBefore));
      expect(a.world.entities.health[p], greaterThan(playerHealthBefore));
      expect(a.world.hero.rekindlesUsed, 0);
    });

    test(
        'Supernova (★5b): deals 2.4x the base cast (1,200 % vs 500 %) and '
        'does not refresh Rekindle', () {
      // Both ★5 so heroAtk's own star scaling matches on both sides.
      final ({SimWorld world, int target}) base = ashlinArena(stars: 5);
      base.world.hero.ultimateCharge = 1.0;
      final double beforeBase = base.world.entities.health[base.target];
      base.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      final double baseDamage = beforeBase - base.world.entities.health[base.target];

      final ({SimWorld world, int target}) a =
          ashlinArena(stars: 5, talentChoices: <String, String>{'5': 'b'});
      setUpForLethalHit(a.world);
      EnemyAttack.damagePlayer(a.world.ai, 2.0, source: -1);
      expect(a.world.hero.rekindlesUsed, 1);
      a.world.tick(InputSnapshot());

      a.world.hero.ultimateCharge = 1.0;
      final double beforeSupernova = a.world.entities.health[a.target];
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      final double supernovaDamage =
          beforeSupernova - a.world.entities.health[a.target];

      expect(supernovaDamage / baseDamage, closeTo(2.4, 0.02));
      expect(a.world.hero.rekindlesUsed, 1,
          reason: 'Supernova trades the refresh away for a bigger cast');
    });

    test('Ember Body (★3a): 3 s invulnerability after any room clear', () {
      final SimWorld world = SimWorld(seed: 4004, content: content)
        ..autoFire = false;
      world.spawnPlayer(8.0, 4.5);
      world.entities.health[world.player.index] = 1e12;
      world.entities.maxHealth[world.player.index] = 1e12;
      HeroLoadoutResolver.apply(
        world,
        ashlin,
        const HeroState(
            heroId: 'ashlin', stars: 3, talentChoices: <String, String>{'3': 'a'}),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      world.beginRoom(RoomComposer.compose(
        content: content,
        rng: Rng(4004),
        chapter: 2,
        globalStage: 25,
      ));

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60 * 60 && world.hero.ashlinInvulnRemaining == 0; t++) {
        world.tick(idle);
        // Kill everything the moment it appears, so the room drains and
        // reports itself cleared — the same technique
        // spawn_system_test.dart's own "a cleared room says so" test uses.
        for (int i = 0; i < world.entities.highWater; i++) {
          if (world.entities.alive[i] == 1 &&
              world.entities.kind[i] == EntityKind.enemy.index) {
            world.entities.health[i] = 0;
          }
        }
      }
      expect(world.spawnState.roomClearedEmitted, isTrue);
      expect(world.hero.ashlinInvulnRemaining, greaterThan(0));
    });

    test('Phoenix Trail (★3b): lays a damaging Windline segment while invulnerable',
        () {
      final ({SimWorld world, int target}) a =
          ashlinArena(stars: 3, talentChoices: <String, String>{'3': 'b'});
      a.world.hero.ashlinInvulnRemaining = 3.0;

      final InputSnapshot idle = InputSnapshot();
      bool sawPhoenixTrailSegment = false;
      for (int t = 0; t < 60 && !sawPhoenixTrailSegment; t++) {
        a.world.tick(idle);
        for (int s = 0; s < a.world.windlines.capacity; s++) {
          if (a.world.windlines.isAlive(s) &&
              a.world.windlines.isPhoenixTrailAt(s)) {
            sawPhoenixTrailSegment = true;
            break;
          }
        }
      }
      expect(sawPhoenixTrailSegment, isTrue);
    });

    test('a Phoenix-Trail-tagged segment damages an enemy standing on it', () {
      final SimWorld world = SimWorld(seed: 205, content: content);
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        ashlin,
        const HeroState(
            heroId: 'ashlin', stars: 3, talentChoices: <String, String>{'3': 'b'}),
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
        trailId: 777,
        isPhoenixTrail: true,
      );

      final double before = world.entities.health[target];
      world.tick(InputSnapshot());
      expect(world.entities.health[target], lessThan(before));
    });
  });

  group('Bounce and Caroms', () {
    test('Bounce grants an ordinary arrow one ricochet off a wall', () {
      final Arena arena =
          Arena.standard(walls: <Rect>[const Rect(5.0, 3.0, 5.3, 6.0)]);
      final ({SimWorld world, int target}) a =
          corvinArena(arena: arena, playerX: 2.0);

      a.world.tick(InputSnapshot());
      int? slot;
      for (int e = 0; e < a.world.events.count; e++) {
        if (a.world.events.typeAt(e) == SimEventType.arrowFired) {
          slot = a.world.events.entityAAt(e);
        }
      }
      expect(slot, isNotNull);
      expect(a.world.projectiles.ricochetsLeft[slot!], 1);
    });

    test('a ricocheted arrow lays a new Windline segment', () {
      final Arena arena =
          Arena.standard(walls: <Rect>[const Rect(5.0, 3.0, 5.3, 6.0)]);
      final ({SimWorld world, int target}) a =
          corvinArena(arena: arena, playerX: 2.0);

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 20; t++) {
        a.world.tick(idle);
      }
      int aliveSegments = 0;
      for (int s = 0; s < a.world.windlines.capacity; s++) {
        if (a.world.windlines.isAlive(s)) aliveSegments++;
      }
      expect(aliveSegments, greaterThan(0),
          reason: 'the ricochet point itself should have cut a segment, '
              'not just the arrow\'s own periodic trail');
    });

    test('Caroms grants 4 ricochets to arrows fired during it', () {
      final ({SimWorld world, int target}) a = corvinArena();
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.caromsRemaining,
          closeTo(HeroRuntime.caromsDuration, 1e-9));

      a.world.autoFire = true;
      a.world.tick(InputSnapshot());
      int? slot;
      for (int e = 0; e < a.world.events.count; e++) {
        if (a.world.events.typeAt(e) == SimEventType.arrowFired) {
          slot = a.world.events.entityAAt(e);
        }
      }
      expect(slot, isNotNull);
      expect(a.world.projectiles.ricochetsLeft[slot!], 4);
    });

    test(
        'True Bounce (★1a) redirects a wall ricochet toward the nearest enemy',
        () {
      final Arena arena =
          Arena.standard(walls: <Rect>[const Rect(5.0, 3.0, 5.3, 6.0)]);
      final ({SimWorld world, int target}) a = corvinArena(
        arena: arena,
        playerX: 2.0,
        stars: 1,
        talentChoices: const <String, String>{'1': 'a'},
      );

      a.world.tick(InputSnapshot());
      int? slot;
      for (int e = 0; e < a.world.events.count; e++) {
        if (a.world.events.typeAt(e) == SimEventType.arrowFired) {
          slot = a.world.events.entityAAt(e);
        }
      }
      expect(slot, isNotNull);

      // Spawned only *after* the shot fires, so it plays no part in
      // auto-fire's own initial target choice (`corvinArena`'s far mote is
      // what sends this shot due east into the wall) — only in which
      // enemy True Bounce redirects the ricochet toward. Off the
      // reflection axis: a plain angle-reflection off this vertical wall
      // only flips velX, leaving velY at ~0 (the shot travels due east).
      // Redirecting toward this enemy instead means velY turns positive.
      final int seek = a.world.spawnEnemy(EnemyArchetype.mote, 3.0, 7.5);
      a.world.enemies.speedScale[seek] = 0;

      final InputSnapshot idle = InputSnapshot();
      bool bounced = false;
      for (int t = 0; t < 20; t++) {
        a.world.tick(idle);
        if (a.world.entities.alive[slot!] == 1 &&
            a.world.entities.velX[slot] < 0) {
          bounced = true;
          break;
        }
      }
      expect(bounced, isTrue);
      expect(a.world.entities.velY[slot!], greaterThan(0));
    });

    test('Hard Bounce (★1b) adds +20% damage to a ricocheted hit', () {
      ({SimWorld world, int primary, int secondary}) build(
          {required bool hardBounce}) {
        final SimWorld world = SimWorld(seed: 21, content: content)
          ..autoFire = true;
        world.spawnPlayer(4.0, 4.5);
        HeroLoadoutResolver.apply(
          world,
          corvin,
          HeroState(
            // Both builds sit at ★1 — matched so Curves.heroStat's own
            // +12%/star (attack, fire rate, everything) never leaks into
            // this comparison, only the talent choice differs. Bare ★1
            // with no talent picked leaves the T1 node inert, which is
            // exactly the "no Hard Bounce" baseline this test wants.
            heroId: 'corvin',
            stars: 1,
            talentChoices:
                hardBounce ? const <String, String>{'1': 'b'} : const {},
          ),
          ashShaft,
          const ArrowInstance(arrowId: 'ash_shaft'),
        );
        final int primary = world.spawnEnemy(EnemyArchetype.mote, 8.0, 4.5);
        world.enemies.speedScale[primary] = 0;
        world.entities.maxHealth[primary] = 1e9;
        world.entities.health[primary] = 1e9;
        final int secondary = world.spawnEnemy(EnemyArchetype.mote, 8.0, 6.0);
        world.enemies.speedScale[secondary] = 0;
        world.entities.maxHealth[secondary] = 1e9;
        world.entities.health[secondary] = 1e9;
        return (world: world, primary: primary, secondary: secondary);
      }

      final ({SimWorld world, int primary, int secondary}) base =
          build(hardBounce: false);
      final ({SimWorld world, int primary, int secondary}) hard =
          build(hardBounce: true);

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 200; t++) {
        base.world.tick(idle);
        hard.world.tick(idle);
      }

      // Every hit `secondary` takes is a ricocheted one — it is never the
      // first enemy in line — so its whole damage total isolates Hard
      // Bounce's own bonus cleanly.
      final double baseDamage = 1e9 - base.world.entities.health[base.secondary];
      final double hardDamage = 1e9 - hard.world.entities.health[hard.secondary];
      expect(baseDamage, greaterThan(0));
      expect(hardDamage / baseDamage, closeTo(1.20, 0.05));
    });

    test('Double Bounce (★3b) raises the base ricochet grant to 2', () {
      final ({SimWorld world, int target}) a = corvinArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'b'},
      );
      a.world.tick(InputSnapshot());
      int? slot;
      for (int e = 0; e < a.world.events.count; e++) {
        if (a.world.events.typeAt(e) == SimEventType.arrowFired) {
          slot = a.world.events.entityAAt(e);
        }
      }
      expect(slot, isNotNull);
      expect(a.world.projectiles.ricochetsLeft[slot!], 2);
    });

    test('Endless Carom (★5a) extends Caroms from 6s to 10s', () {
      final ({SimWorld world, int target}) a = corvinArena(
        stars: 5,
        talentChoices: const <String, String>{'5': 'a'},
      );
      a.world.autoFire = false;
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));
      expect(a.world.hero.caromsRemaining, closeTo(10.0, 1e-9));
    });

    test(
        'Perfect Carom (★5b) skips pierce falloff on a ricocheted hit during Caroms',
        () {
      ({SimWorld world, int primary, int secondary}) build(
          {required bool perfectCarom}) {
        final SimWorld world = SimWorld(seed: 23, content: content)
          ..autoFire = false;
        world.spawnPlayer(4.0, 4.5);
        HeroLoadoutResolver.apply(
          world,
          corvin,
          HeroState(
            // Both builds sit at ★5 — matched for the same reason the Hard
            // Bounce comparison above matches its own pair: Curves.heroStat
            // scales attack, fire rate, everything by star count, and an
            // unmatched pair would size this ratio off that instead of off
            // Perfect Carom itself.
            heroId: 'corvin',
            stars: 5,
            talentChoices:
                perfectCarom ? const <String, String>{'5': 'b'} : const {},
          ),
          ashShaft,
          const ArrowInstance(arrowId: 'ash_shaft'),
        );
        final int primary = world.spawnEnemy(EnemyArchetype.mote, 8.0, 4.5);
        world.enemies.speedScale[primary] = 0;
        world.entities.maxHealth[primary] = 1e9;
        world.entities.health[primary] = 1e9;
        final int secondary = world.spawnEnemy(EnemyArchetype.mote, 8.0, 6.0);
        world.enemies.speedScale[secondary] = 0;
        world.entities.maxHealth[secondary] = 1e9;
        world.entities.health[secondary] = 1e9;
        // Caroms is the Ultimate itself — every Corvin has it regardless of
        // talents — so both builds fire it, and only Perfect Carom's own
        // talent differs between them.
        world.hero.ultimateCharge = 1.0;
        world.tick(InputSnapshot()..set(0, 0, ultimate: true));
        world.autoFire = true;
        return (world: world, primary: primary, secondary: secondary);
      }

      final ({SimWorld world, int primary, int secondary}) base =
          build(perfectCarom: false);
      final ({SimWorld world, int primary, int secondary}) perfect =
          build(perfectCarom: true);

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 200; t++) {
        base.world.tick(idle);
        perfect.world.tick(idle);
      }

      final double baseDamage = 1e9 - base.world.entities.health[base.secondary];
      final double perfectDamage =
          1e9 - perfect.world.entities.health[perfect.secondary];
      expect(baseDamage, greaterThan(0));
      // Without Perfect Carom, the ricocheted hit still eats the ordinary
      // pierce-falloff curve (0.85^1); with it, that hit is exempt — the
      // same ~1/0.85 gap Deadeye's own crit exemption produces elsewhere.
      expect(perfectDamage / baseDamage, closeTo(1 / 0.85, 0.08));
    });
  });

  group('Skyhawk', () {
    ({SimWorld world, int primary}) zeaArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 91, content: content)
        ..autoFire = false;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        zea,
        HeroState(heroId: 'zea', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int primary = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[primary] = 0;
      world.entities.maxHealth[primary] = 1e9;
      world.entities.health[primary] = 1e9;
      return (world: world, primary: primary);
    }

    List<int> hawksOf(SimWorld world) {
      final List<int> found = <int>[];
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 1 &&
            world.entities.kindOf(i) == EntityKind.companion) {
          found.add(i);
        }
      }
      return found;
    }

    test('the passive grants exactly one permanent companion', () {
      final ({SimWorld world, int primary}) a = zeaArena();
      final List<int> hawks = hawksOf(a.world);
      expect(hawks, hasLength(1));
      expect(a.world.companions.remaining[hawks.single], double.infinity);
    });

    test('a hero with no Skyhawk grants no companion at all', () {
      final SimWorld world = SimWorld(seed: 91, content: content);
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        corvin,
        const HeroState(heroId: 'corvin'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      expect(hawksOf(world), isEmpty);
    });

    test('the hawk deals 35 % of hero ATK at 1.5/s, independently of the '
        'player\'s own arrows', () {
      final ({SimWorld world, int primary}) a = zeaArena();
      final double share = a.world.companions.damageShare[hawksOf(a.world).single];
      final double interval =
          a.world.companions.fireIntervalSeconds[hawksOf(a.world).single];
      expect(share, closeTo(0.35, 1e-9));
      expect(interval, closeTo(1.0 / 1.5, 1e-9));

      final double before = a.world.entities.health[a.primary];
      for (int t = 0; t < 90; t++) {
        a.world.tick(InputSnapshot());
      }
      expect(a.world.entities.health[a.primary], lessThan(before));
    });

    test('Sharper Talons (★1a): the hawk\'s damage share rises to 50 %',
        () {
      final ({SimWorld world, int primary}) a = zeaArena(
        stars: 1,
        talentChoices: const <String, String>{'1': 'a'},
      );
      expect(a.world.companions.damageShare[hawksOf(a.world).single],
          closeTo(0.50, 1e-9));
    });

    test('Swift Hawk (★1b): the hawk fires at 2.4/s instead of 1.5/s', () {
      final ({SimWorld world, int primary}) a = zeaArena(
        stars: 1,
        talentChoices: const <String, String>{'1': 'b'},
      );
      expect(a.world.companions.fireIntervalSeconds[hawksOf(a.world).single],
          closeTo(1.0 / 2.4, 1e-9));
    });

    test('Flock (★3b): replaces the single 35 % hawk with two permanent '
        'hawks at 25 % each', () {
      final ({SimWorld world, int primary}) a = zeaArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'b'},
      );
      final List<int> hawks = hawksOf(a.world);
      expect(hawks, hasLength(2));
      for (final int hawk in hawks) {
        expect(a.world.companions.damageShare[hawk], closeTo(0.25, 1e-9));
        expect(a.world.companions.remaining[hawk], double.infinity);
      }
    });

    test('Bonded (★3a): the hawk crits only while the player is at Tier '
        'III', () {
      final ({SimWorld world, int primary}) a = zeaArena(
        stars: 3,
        talentChoices: const <String, String>{'3': 'a'},
      );
      expect(a.world.companions.alwaysCrit[hawksOf(a.world).single], 1);
    });

    test('re-applying the loadout (a level-up mid-run) replaces the hawk '
        'rather than accumulating a second one', () {
      final ({SimWorld world, int primary}) a = zeaArena();
      expect(hawksOf(a.world), hasLength(1));

      HeroLoadoutResolver.apply(
        a.world,
        zea,
        const HeroState(heroId: 'zea', level: 5),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      expect(hawksOf(a.world), hasLength(1));
    });

    test('re-applying with a different hero entirely removes the hawk', () {
      final ({SimWorld world, int primary}) a = zeaArena();
      expect(hawksOf(a.world), hasLength(1));

      HeroLoadoutResolver.apply(
        a.world,
        corvin,
        const HeroState(heroId: 'corvin'),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );

      expect(hawksOf(a.world), isEmpty);
    });
  });

  group('Falconry', () {
    ({SimWorld world, int primary}) zeaArena({
      Map<String, String> talentChoices = const <String, String>{},
      int stars = 0,
    }) {
      final SimWorld world = SimWorld(seed: 92, content: content)
        ..autoFire = false;
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        zea,
        HeroState(heroId: 'zea', stars: stars, talentChoices: talentChoices),
        ashShaft,
        const ArrowInstance(arrowId: 'ash_shaft'),
      );
      final int primary = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[primary] = 0;
      world.entities.maxHealth[primary] = 1e9;
      world.entities.health[primary] = 1e9;
      return (world: world, primary: primary);
    }

    List<int> hawksOf(SimWorld world) {
      final List<int> found = <int>[];
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 1 &&
            world.entities.kindOf(i) == EntityKind.companion) {
          found.add(i);
        }
      }
      return found;
    }

    List<int> temporaryHawksOf(SimWorld world) => hawksOf(world)
        .where((int i) => world.companions.remaining[i] < double.infinity)
        .toList();

    test('summons 4 temporary hawks for 12 s, alongside the permanent one',
        () {
      final ({SimWorld world, int primary}) a = zeaArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(hawksOf(a.world), hasLength(5)); // 1 permanent + 4 temporary
      final List<int> temporary = temporaryHawksOf(a.world);
      expect(temporary, hasLength(4));
      for (final int hawk in temporary) {
        expect(a.world.companions.remaining[hawk], closeTo(12.0, 0.02));
        expect(a.world.companions.damageShare[hawk], closeTo(0.35, 1e-9));
      }
    });

    test('the summoned hawks expire after 12 s; the permanent one does not',
        () {
      final ({SimWorld world, int primary}) a = zeaArena();
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      for (int t = 0; t < 13 * 60; t++) {
        a.world.tick(InputSnapshot());
      }

      expect(hawksOf(a.world), hasLength(1));
      expect(temporaryHawksOf(a.world), isEmpty);
    });

    test('Skydarken (★5a): summons 8 hawks instead of 4', () {
      final ({SimWorld world, int primary}) a = zeaArena(
        stars: 5,
        talentChoices: const <String, String>{'5': 'a'},
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      expect(temporaryHawksOf(a.world), hasLength(8));
    });

    test('Great Hawk (★5b): one hawk at 250 % ATK for 20 s, replacing the '
        'ordinary flock', () {
      final ({SimWorld world, int primary}) a = zeaArena(
        stars: 5,
        talentChoices: const <String, String>{'5': 'b'},
      );
      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      final List<int> temporary = temporaryHawksOf(a.world);
      expect(temporary, hasLength(1));
      expect(a.world.companions.damageShare[temporary.single],
          closeTo(2.50, 1e-9));
      expect(a.world.companions.remaining[temporary.single],
          closeTo(20.0, 0.02));
    });

    test('Sharper Talons and Bonded apply to the summoned flock too', () {
      final ({SimWorld world, int primary}) a = zeaArena(
        stars: 3,
        talentChoices: const <String, String>{'1': 'a', '3': 'a'},
      );

      a.world.hero.ultimateCharge = 1.0;
      a.world.tick(InputSnapshot()..set(0, 0, ultimate: true));

      for (final int hawk in temporaryHawksOf(a.world)) {
        expect(a.world.companions.damageShare[hawk], closeTo(0.50, 1e-9));
        expect(a.world.companions.alwaysCrit[hawk], 1);
      }
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
      // Burn/Long Pyre/Twin Pyre), Iris's Weave, Nyx's Umbral
      // Step/Deeper Shadow/Shadowline/Chain Kill/Perfect Step, Ashlin's
      // Rekindle/Rebirth Nova/Bright Rekindle/Twice Kindled/Ember
      // Body/Phoenix Trail/Supernova, Vane's Marked, Corvin's whole kit
      // (Bounce/Caroms/True Bounce/Hard Bounce/Double Bounce/Endless
      // Carom/Perfect Carom), Kestrel's Bleed, Rook's Crush and Anchor,
      // Lira's Overheal, Halden's own boss half — Zealot/Warded/
      // Sentence/Swift Judgment (ADR 0069, unblocked by Phase 11's own
      // `isBoss`), Zea's whole kit (ADR 0071/0072/0073, the new
      // companion-entity primitive), Mirelle's Hall of
      // Mirrors/Endless Hall/Twin Warden (ADR 0074, the same companion
      // primitive plus a new guaranteed-duplication timer), and Ovrin's
      // Aegis Pin/Riposte/Long Wall/Mirror Wall (ADR 0075, a new
      // reflect-damage-to-attacker primitive that also fixed the
      // long-dead Thorns Boon), Sela's Shatter (ADR 0076, an on-kill AoE
      // hook centred on the kill rather than the player), and Torv's
      // Overload/Thunderhead (ADR 0077, both reusing existing per-enemy
      // timers built for other heroes), Wren's own ★5 pair (ADR 0078, a
      // new per-arrow "fired by the Ultimate" tag), and Rook's Singularity
      // trio (ADR 0079, a sustained fixed-zone Ultimate — the same shape
      // Miasma/Pyre Line already established, not a new primitive).
      expect(
        pendingHeroBehaviourWork.length,
        lessThanOrEqualTo(16),
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
  // Wren's own ★5 pair — wrenWardensLattice and wrenWardensFury — are both
  // implemented now, in the "Warden's Lattice and Warden's Fury" group (ADR
  // 0078). Lattice bakes an extended Windline duration into each Ultimate
  // arrow at spawn (`ProjectileStore.windlineDurationOverride`), read at
  // both lay sites instead of the ambient `windlineDuration`. Fury tags
  // whichever kind of arrow struck an enemy last
  // (`ProjectileStore.isUltimateArrow` copied onto
  // `EnemyStore.lastHitWasUltimate` on every hit), read at `AiSystem`'s own
  // death pass.

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
  // implemented — see hero_behaviour_test.dart's Flurry group. kestrelBleed
  // is implemented too — see the "Bleed" group. ADR 0015 covers the fifth-
  // DoT primitive it needed (EnemyStore.bleedStacks/bleedRemaining, ticked
  // in ElementSystem alongside Burn/Toxin rather than living on StatusStore,
  // which is deliberately elemental-only) and the two numbers docs/07 never
  // states for it.

  // ovrinAegisPin, ovrinRiposte, ovrinLongWall and ovrinMirrorWall are all
  // implemented — see the "Aegis Pin and Riposte" group. Aegis Pin reads
  // "blocks all enemy projectiles" as "blocks the hit outright," the sim
  // having no standalone enemy-projectile entity to intercept — the same
  // shape as Umbral Step/Ashlin's own invulnerability. Riposte needed a
  // new "the shield broke this hit" detection inside the existing
  // Shieldweave-spend block, resolved through the same pending-nova
  // hand-off Ashlin's Rekindle already uses (only `SimWorld` has
  // playerAttack/spatial/entities together). Building the "reflect damage
  // at the attacker" primitive this needed also fixed *Thorns* (Boon #31),
  // a card that had set `world.thornsReflect` since Phase 9 with no reader
  // anywhere — see ADR 0075 and boon_effects_test.dart's own new test.

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
  // selaCascadingNail are implemented — see that same group. Shatter is
  // implemented too, in the same group: an on-kill AoE hook, built inside
  // `AiSystem._reap` right where Contagion/Wildfire already read a
  // corpse's own status before `clearSlot` erases it — centred on the
  // kill's own position rather than the player, the one thing every
  // existing player AoE (Ashlin's nova, Ovrin's Riposte) never needed
  // (ADR 0076). Lingering Frost stays pending: it needs a real "timed slow
  // zone independent of Windlines" primitive — the sim's only existing
  // slow mechanism (`EnemyStore.slowRemaining`/`windlineSlowFactor`) is
  // Windline- and Boon-specific by construction (`BoonSystem`'s own pass
  // only reads the *player's* live trail and a Boon's own `slow` stat), so
  // faking a zone by dropping a zero-length Windline segment would
  // silently depend on whatever slow-related Boon the player happens to
  // hold, not on Sela at all.
  HeroBehaviour.selaLingeringFrost,

  // torvArc, torvTempestNock, torvFrequentArc, torvWideArc,
  // torvLongTempest, torvOverload and torvThunderhead are all implemented —
  // see the "Arc and Tempest Nock" group (ADR 0077). Overload reuses
  // `EnemyStore.markedRemaining`, the same shared per-enemy timer Vane's
  // Marked and Halden's Sentence already read (only one hero equipped at a
  // time, so a third reader is unambiguous); Thunderhead reuses
  // `StatusStore.frozenRemaining`, the same hard-stop Rook's own Anchor
  // already borrows from Frost. Chains still hit the nearest enemies by
  // distance rather than genuinely travelling along Windlines, which
  // nothing in the sim indexes (see `_applyTorvChain`'s own doc comment) —
  // Conductive Lines specifically rewards the Windline-travel case and
  // stays pending until that relationship exists to reward.
  HeroBehaviour.torvConductiveLines,

  // sableToxin is implemented — see the "three innate elements" group.
  // sableMiasma, sableVirulence, sableFastActing, sableContagion,
  // sableCorrosion, sableLastingMiasma and sableConcentratedMiasma are all
  // implemented too — see the "Toxin and Miasma" group. Sable is the first
  // hero whose entire kit is reachable with nothing deferred.

  // liraLifebound, liraVerdantBloom, liraEndlessBloom and liraBloodBloom are
  // implemented — see the "Lifebound and Verdant Bloom" group. liraOverheal
  // is implemented too — see the "Overheal" group; ADR 0016 covers which
  // heal sources it catches (Lira's own two) and which it deliberately
  // does not (Boon-granted healing — the same unaudited-surface reasoning
  // Thane's own Tempered was deferred over). Lira is the fourth hero (after
  // Sable, Kade, Corvin) with nothing deferred.
  // liraDeepRoots never joined this enum — one StatModifier on lifesteal.

  // corvinBounce, corvinCaroms, corvinTrueBounce, corvinHardBounce,
  // corvinDoubleBounce, corvinEndlessCarom and corvinPerfectCarom are all
  // implemented — see the "Bounce and Caroms" group. Corvin is the third
  // hero (after Sable and Kade) whose entire kit is reachable with nothing
  // deferred. The reflection primitive itself — wall/enemy ricochet, and
  // the forced Windline segment it lays — is entirely Skimmer's own code
  // from Task 5 part 1; ADR 0012 already named Corvin as the reason that
  // primitive was built shared rather than Skimmer-specific.

  // vaneDistance, vaneSteady, vanePiercingHorizon, vaneTwinHorizon,
  // vaneSunderingHorizon and vaneMarked are all implemented — see the
  // "Distance and Piercing Horizon" group. Marked needed a genuinely new
  // per-enemy timed field (`EnemyStore.markedRemaining`) rather than reuse
  // of `slowRemaining`/`enrageRemaining`'s own shape, since it is a damage
  // multiplier, not a speed one. vaneFarsight never joined this enum — one
  // StatModifier on damagePerDistanceCap.

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

  // Zea's whole kit is implemented now — zeaSkyhawk, zeaSharperTalons,
  // zeaSwiftHawk, zeaBonded and zeaFlock in the "Skyhawk" group (ADR
  // 0071/0072); zeaFalconry, zeaSkydarken and zeaGreatHawk in the
  // "Falconry" group (ADR 0073) — temporary companions through the same
  // primitive, dispatched from `_fireUltimate` the identical way every
  // other hero's own Ultimate already is. Great Hawk's own "taunts" is
  // not built (ADR 0071's own flagged gap: no enemy AI in this roster
  // targets anything but the player). Zea is the sixth hero (after
  // Sable, Kade, Corvin, Lira, Halden) with nothing deferred.

  // rookPull, rookStrongerPull and rookDenserGrouping are implemented — see
  // the "Pull" group. rookCrush is implemented too — see the "Crush" group;
  // ADR 0015's own update covers how it reuses Kestrel's Bleed storage at
  // its own stated 5 %/s, re-evaluated a few times a second from each
  // enemy's live neighbours rather than a fire-and-forget timed DoT.
  // rookAnchor is implemented too, also in the "Pull" group — a per-enemy
  // root/stun timer already existed under Frost's own name
  // (`StatusStore.frozenRemaining`), found by looking closer rather than
  // building a second one; see ADR 0070. rookSingularity,
  // rookTwinSingularity and rookCollapsingSingularity are all implemented
  // now too — see the "Singularity" group (ADR 0079). Rook is the ninth
  // hero (after Sable, Kade, Corvin, Lira, Halden, Zea, Mirelle, Ovrin)
  // with nothing deferred. The well is the same fixed-zone shape Miasma's
  // cloud and Pyre Line's own wall already established — pinned at cast
  // time, ticked every frame, no new primitive needed to make a sustained
  // multi-tick Ultimate real.

  // haldenVerdict, haldenJudgmentSpear, haldenFinalVerdict, haldenTwinSpear,
  // haldenZealot, haldenWarded, haldenSentence and haldenSwiftJudgment are
  // all implemented now — see the "Verdict and Judgment Spear" group.
  // Verdict's own boss half (and every one of these four talents) was
  // blocked on an `isBoss` check `EnemyStore` did not have before Phase 11;
  // `EnemyStore.isBoss` (`bossIndex >= 0`) exists now that Phase 11's own
  // boss roster is built, so this was the first ledger entry Phase 11's
  // own completion actually unblocked. Halden is the fifth hero (after
  // Sable, Kade, Corvin, Lira) with nothing deferred. See ADR 0069.

  // ashlinRekindle, ashlinRebirthNova, ashlinBrightRekindle,
  // ashlinTwiceKindled, ashlinEmberBody, ashlinPhoenixTrail and
  // ashlinSupernova are all implemented — see the "Rekindle and Rebirth
  // Nova" group. The revive itself is the hero-side counterpart to
  // Guardian Angel/Phoenix Heart (same "refuse to die" spot in
  // EnemyAttack.damagePlayer); Phoenix Trail reuses the same per-segment
  // Windline tagging Nyx's own Shadowline needed, kept as its own field
  // rather than shared since the two hero's triggers and rates differ.
  // ADR 0011 covers the AoE nova's own radius, which docs/07 never states
  // for any of the three cards that need it.
  //
  // Eternal (T5a, "Ultimate refresh has no cooldown") stays pending: the
  // base Ultimate's own "refreshes Rekindle if already used" clause has no
  // stated restriction anywhere for Eternal to remove, so implementing it
  // would mean inventing a cooldown docs/07 never describes just to have
  // something to lift — a bigger risk than a hero-local addition with a
  // genuine anchor.
  HeroBehaviour.ashlinEternal,

  // Mirelle's entire kit — Reflection, Hall of Mirrors and every ★1/★3/★5
  // variant of both — is implemented. See the "Reflection" and "Hall of
  // Mirrors" groups.

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
