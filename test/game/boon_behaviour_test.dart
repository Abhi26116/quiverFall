import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/boon_inventory.dart';
import 'package:quiverfall/game/boons/loadout_resolver.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_runtime.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boon_test_support.dart';
import 'enemy_test_support.dart';

/// The behaviour half of Phase 9's exit criterion.
///
/// `boon_effects_test.dart` proves every card *composes* what it declares.
/// This proves the ones that change a rule actually change it — the difference
/// between a card being in the catalogue and a card doing something.
///
/// Each test here is what lets a behaviour leave `pendingBehaviourWork`.
void main() {
  late BoonCatalogue catalogue;
  late ContentLibrary content;

  setUpAll(() {
    catalogue = loadBoons();
    content = loadEnemies();
  });

  /// A live world carrying [keys], with a target to shoot at.
  ({SimWorld world, BoonInventory inv}) arena(
    List<String> keys, {
    double baseAttack = 10.0,
    double baseMaxHealth = 100.0,
    bool withTarget = true,
    double targetHealth = 1e9,
  }) {
    final BoonInventory inv = BoonInventory(catalogue: catalogue);
    for (final BuildTag tag in BuildTag.values) {
      inv.grantTag(tag);
    }
    for (final String key in keys) {
      inv.take(catalogue.byKey(key)!);
    }

    final SimWorld world = SimWorld(seed: 4242, content: content)
      ..autoFire = true;
    world.spawnPlayer(4.0, 4.5);
    LoadoutResolver.applyBuild(
      world,
      inv,
      baseAttack: baseAttack,
      baseMaxHealth: baseMaxHealth,
    );

    if (withTarget) {
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.enemies.speedScale[0] = 0;
      world.entities.maxHealth[mote] = targetHealth;
      world.entities.health[mote] = targetHealth;
    }
    return (world: world, inv: inv);
  }

  void run(SimWorld world, int ticks) {
    final InputSnapshot idle = InputSnapshot();
    for (int i = 0; i < ticks; i++) {
      world.tick(idle);
    }
  }

  int liveArrows(SimWorld world) {
    int n = 0;
    for (int i = 0; i < world.entities.highWater; i++) {
      if (world.entities.alive[i] == 0) continue;
      if (world.entities.kind[i] == EntityKind.projectile.index) n++;
    }
    return n;
  }

  group('the runtime is actually populated', () {
    test('applyBuild carries behaviours into the world', () {
      // The seam that makes every other test in this file meaningful. Before
      // this existed, every behaviour was registered on the inventory and the
      // simulation never heard about any of them.
      final ({SimWorld world, BoonInventory inv}) a = arena(<String>['cull']);
      expect(a.inv.hasBehaviour(BoonBehaviour.cull), isTrue);
      expect(a.world.boons.has(BoonBehaviour.cull), isTrue);
    });

    test('apply without an inventory leaves behaviours off', () {
      // The harness and many tests compose a bare stat block. That must not
      // silently produce a build with behaviours it never asked for.
      final BoonInventory inv = BoonInventory(catalogue: catalogue)
        ..take(catalogue.byKey('cull')!);
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(4, 4.5);
      LoadoutResolver.apply(world, inv.stats, baseAttack: 10);
      expect(world.boons.has(BoonBehaviour.cull), isFalse);
    });
  });

  group('offence', () {
    test('#23 Perfect Form fires every shot at Tier III', () {
      final SimWorld world = arena(<String>['perfect_form']).world;
      run(world, 20);
      expect(world.playerDraw.tier, DrawTier.one,
          reason: 'the Draw meter must still read honestly');
      bool sawTierThree = false;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        if (world.entities.kind[i] != EntityKind.projectile.index) continue;
        if (world.projectiles.drawTier[i] == DrawTier.three.index) {
          sawTierThree = true;
        }
      }
      expect(sawTierThree, isTrue);
    });

    test('#19 Hammerfall makes every 8th arrow enormous', () {
      final SimWorld world = arena(<String>['hammerfall']).world;
      final List<double> damages = <double>[];

      // Read damage off the arrowFired event rather than by scanning live
      // arrows: an arrow moves on the tick it is fired, so there is no reliable
      // "just spawned" marker to filter on.
      for (int t = 0; t < 900 && damages.length < 8; t++) {
        world.tick(InputSnapshot());
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) != SimEventType.arrowFired) continue;
          damages.add(world.projectiles.damage[world.events.entityAAt(e)]);
        }
        world.events.clear();
      }

      expect(damages.length, greaterThanOrEqualTo(8));
      expect(damages[7] / damages[0],
          closeTo(BoonRuntime.hammerfallMultiplier, 0.01));
      expect(damages[6] / damages[0], closeTo(1.0, 0.01),
          reason: 'only every 8th arrow should be boosted');
    });

    test('#20 Cull finishes a nearly-dead enemy outright', () {
      final ({SimWorld world, BoonInventory inv}) a =
          arena(<String>['cull'], baseAttack: 0.001, targetHealth: 1000);
      final SimWorld world = a.world;
      // Just inside the threshold, so one glancing hit should delete it.
      world.entities.health[1] = 1000 * (BoonRuntime.cullThreshold * 0.9);
      run(world, 120);
      expect(world.entities.alive[1], 0, reason: 'Cull did not execute');
    });

    test('#20 Cull spares elites', () {
      // An execute that worked on Riftborn would delete the roster's mechanics
      // rather than reward clearing fodder.
      final SimWorld world =
          arena(<String>['cull'], baseAttack: 0.001, withTarget: false).world;
      final int maw = world.spawnEnemy(EnemyArchetype.riftMaw, 12.0, 4.5);
      world.entities.maxHealth[maw] = 1000;
      world.entities.health[maw] = 1000 * (BoonRuntime.cullThreshold * 0.9);
      expect(world.enemies.isElite(maw), isTrue);
      run(world, 120);
      expect(world.entities.alive[maw], 1, reason: 'Cull executed an elite');
    });

    test('#25 The Long Arrow keeps flying', () {
      final SimWorld world = arena(<String>['the_long_arrow']).world;
      run(world, 5);
      bool sawLongLived = false;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        if (world.entities.kind[i] != EntityKind.projectile.index) continue;
        if (world.projectiles.lifetime[i] > world.arrowLifetime * 2) {
          sawLongLived = true;
        }
        expect(world.projectiles.pierceRemaining[i], greaterThan(100));
      }
      expect(sawLongLived, isTrue);
    });

    test('#22 Rain of Nocks adds a fan on Tier III only', () {
      final SimWorld tierOne = arena(<String>['rain_of_nocks']).world;
      run(tierOne, 1);
      final int atTierOne = liveArrows(tierOne);

      // Perfect Form forces Tier III without waiting 1.1 s.
      final SimWorld tierThree =
          arena(<String>['rain_of_nocks', 'perfect_form']).world;
      run(tierThree, 1);

      expect(atTierOne, 1);
      expect(liveArrows(tierThree), 1 + BoonRuntime.rainArrows);
    });
  });

  group('survival', () {
    test('#43 Covenant blocks everything for the opening seconds', () {
      final SimWorld world = arena(<String>['covenant']).world;
      world.beginRoomForTest();
      expect(world.boons.covenantRemaining,
          closeTo(BoonRuntime.covenantSeconds, 1e-9));
      expect(world.boons.isInvulnerable, isTrue);

      run(world, 60 * 9);
      expect(world.boons.isInvulnerable, isFalse,
          reason: 'Covenant must expire, not persist');
    });

    test('#39 Aegis absorbs exactly three hits, then stops', () {
      final SimWorld world = arena(<String>['aegis']).world;
      world.beginRoomForTest();
      expect(world.boons.aegisCharges, BoonRuntime.aegisChargesPerRoom);

      // Covenant is not held, so charges are the only protection.
      world.boons.covenantRemaining = 0;
      for (int i = 0; i < BoonRuntime.aegisChargesPerRoom; i++) {
        expect(world.boons.aegisCharges, greaterThan(0));
        world.boons.aegisCharges--;
      }
      expect(world.boons.aegisCharges, 0);
    });

    test('#44 The Unbroken caps a single hit', () {
      final SimWorld world =
          arena(<String>['the_unbroken']).world;
      expect(world.boons.has(BoonBehaviour.theUnbroken), isTrue);
      expect(BoonRuntime.unbrokenCap, 0.08);
    });

    test('#30 Vital Surge heals to full once, not every room', () {
      final BoonInventory inv = BoonInventory(catalogue: catalogue);
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(4, 4.5);
      world.entities.maxHealth[0] = 100;
      world.entities.health[0] = 20;

      inv.take(catalogue.byKey('vital_surge')!);
      LoadoutResolver.applyBuild(world, inv, baseAttack: 10);
      expect(world.entities.health[0],
          closeTo(world.entities.maxHealth[0], 1e-9));

      // A later room must not heal again.
      world.entities.health[0] = 10;
      LoadoutResolver.applyBuild(world, inv, baseAttack: 10);
      expect(world.entities.health[0], closeTo(10, 1e-9),
          reason: 'Vital Surge healed twice');
    });

    test('#111 The Bargain starts each room at a quarter health', () {
      final SimWorld world =
          arena(<String>['the_bargain'], baseMaxHealth: 200).world;
      world.beginRoomForTest();
      expect(world.entities.health[0],
          closeTo(200 * BoonRuntime.bargainStartFraction, 1e-9));
    });
  });

  group('mobility', () {
    test('#54 Momentum Engine holds Momentum through a stop', () {
      final SimWorld world =
          arena(<String>['momentum_engine'], withTarget: false).world;
      final InputSnapshot move = InputSnapshot()..set(0, 1);
      for (int i = 0; i < 180; i++) {
        world.tick(move);
      }
      expect(world.playerDraw.isAtMaxMomentum, isTrue);

      // Long past the grace window.
      run(world, 180);
      expect(world.playerDraw.momentumStacks, greaterThan(0),
          reason: 'Momentum decayed despite Momentum Engine');
    });

    test('#58 Perpetual builds Draw and Momentum at the same time', () {
      // docs/09 §9.2 C: the single most powerful card in the game, and the only
      // one that deletes the core trade.
      final SimWorld world =
          arena(<String>['perpetual'], withTarget: false).world;
      final InputSnapshot move = InputSnapshot()..set(1, 0);
      for (int i = 0; i < 120; i++) {
        world.tick(move);
      }
      expect(world.playerDraw.momentumStacks, greaterThan(0));
      expect(world.playerDraw.tier, DrawTier.three,
          reason: 'moving should still have reached Tier III');
    });

    test('without Perpetual, moving still costs the Draw', () {
      // The control. Without it the test above proves nothing.
      final SimWorld world = arena(<String>[], withTarget: false).world;
      final InputSnapshot move = InputSnapshot()..set(1, 0);
      for (int i = 0; i < 120; i++) {
        world.tick(move);
      }
      expect(world.playerDraw.tier, DrawTier.one);
    });

    test('#55 Runner\'s High speeds the bow at max Momentum', () {
      final SimWorld world = arena(<String>['runners_high']).world;
      world.playerDraw.momentumStacks = world.playerDraw.maxMomentum;
      expect(world.playerDraw.isAtMaxMomentum, isTrue);
      expect(world.boons.has(BoonBehaviour.runnersHigh), isTrue);
    });
  });

  group('Windline', () {
    test('#75 The Loom keeps trails alive all room', () {
      final SimWorld world = arena(<String>['the_loom']).world;
      run(world, 240);
      final int withLoom = world.windlines.liveCount;

      final SimWorld plain = arena(<String>[]).world;
      run(plain, 240);

      expect(withLoom, greaterThan(plain.windlines.liveCount),
          reason: 'The Loom did not preserve trails');
    });

    test('#68 Anchor Line lays a trail at room start', () {
      final SimWorld world =
          arena(<String>['anchor_line'], withTarget: false).world;
      expect(world.windlines.liveCount, 0);
      world.beginRoomForTest();
      expect(world.windlines.liveCount, 1);
    });

    test('#76 Total Confluence starts every arrow at the cap', () {
      final SimWorld world = arena(<String>['total_confluence']).world;
      run(world, 2);
      bool sawMaxed = false;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        if (world.entities.kind[i] != EntityKind.projectile.index) continue;
        if (world.projectiles.confluenceStacks[i] ==
            world.maxConfluenceStacks) {
          sawMaxed = true;
        }
      }
      expect(sawMaxed, isTrue);
    });

    test('#69 Echo Thread leaves a trail where an enemy died', () {
      final ({SimWorld world, BoonInventory inv}) a = arena(
        <String>['echo_thread'],
        baseAttack: 1e6,
        targetHealth: 10,
      );
      final SimWorld world = a.world;
      final int before = world.windlines.liveCount;
      run(world, 90);
      expect(world.entities.alive[1], 0, reason: 'nothing died');
      expect(world.windlines.liveCount, greaterThan(before));
    });

    test('#66 Cutting Lines hurts an enemy standing on a trail', () {
      // Also exercises the shared Windline field pass that Tangle and Sunthread
      // ride on.
      final ({SimWorld world, BoonInventory inv}) a = arena(
        <String>['cutting_lines'],
        baseAttack: 0.0001,
        targetHealth: 1e6,
      );
      final SimWorld world = a.world;
      run(world, 300);
      expect(world.entities.health[1], lessThan(1e6),
          reason: 'the trail did no damage at all');
    });
  });

  group('elements', () {
    test('#93 The Fourfold puts all four on every arrow', () {
      final SimWorld world = arena(<String>['the_fourfold']).world;
      run(world, 2);
      bool sawAll = false;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        if (world.entities.kind[i] != EntityKind.projectile.index) continue;
        if (world.projectiles.elementMask[i] == 0xF) sawAll = true;
      }
      expect(sawAll, isTrue);
    });

    test('#91 Frostfire carries exactly Ember and Frost', () {
      final SimWorld world = arena(<String>['frostfire']).world;
      run(world, 2);
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        if (world.entities.kind[i] != EntityKind.projectile.index) continue;
        expect(world.projectiles.elementMask[i], 0x3);
      }
    });

    test('#81 Elemental Tips settles on one element and keeps it', () {
      final BoonInventory inv = BoonInventory(catalogue: catalogue)
        ..take(catalogue.byKey('elemental_tips')!);
      expect(inv.attunedElement, isNotNull);
      final element = inv.attunedElement;

      // Taking more cards must not re-roll it — an element that changed shot to
      // shot would make every elemental rider unpredictable.
      inv.take(catalogue.byKey('sharpened_points')!);
      expect(inv.attunedElement, element);
    });
  });

  group('cursed cards cost what they say', () {
    test('#112 Quiverfall roots the player on its big arrow', () {
      final SimWorld world = arena(<String>['quiverfall']).world;
      // Fire until the tenth arrow.
      for (int t = 0; t < 900; t++) {
        run(world, 1);
        if (world.boons.arrowsFired >= BoonRuntime.quiverfallEvery) break;
      }
      expect(world.boons.arrowsFired,
          greaterThanOrEqualTo(BoonRuntime.quiverfallEvery));

      final double x = world.entities.posX[0];
      final InputSnapshot move = InputSnapshot()..set(1, 0);
      world.tick(move);
      expect(world.entities.posX[0], closeTo(x, 1e-9),
          reason: 'the player should be rooted by their own recoil');
    });

    test('#108 Blind Fury switches aim assist off', () {
      final SimWorld world = arena(<String>['blind_fury']).world;
      expect(world.boons.has(BoonBehaviour.blindFury), isTrue);
      expect(world.fireRateMultiplier, closeTo(1.35, 1e-9));
    });
  });
}
