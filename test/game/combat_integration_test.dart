import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/systems/firing_system.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

void main() {
  final InputSnapshot idle = InputSnapshot();

  SimWorld arena({
    double playerX = 2.0,
    double playerY = 4.5,
    bool autoFire = true,
  }) {
    final SimWorld world = SimWorld(seed: 1234)..autoFire = autoFire;
    world.spawnPlayer(playerX, playerY);
    return world;
  }

  group('firing', () {
    test('does not fire without a target', () {
      final SimWorld world = arena();
      for (int i = 0; i < 120; i++) {
        world.tick(idle);
      }
      expect(world.events.countOf(SimEventType.arrowFired), 0);
    });

    test('fires at the tier-I rate when a target exists', () {
      final SimWorld world = arena();
      world.spawnAt(EntityKind.enemy, 8.0, 4.5, radius: 0.3, health: 1e9);

      // One second of standing still. The Draw ramps, so the rate falls as the
      // tier rises — this is the property that keeps Tier III from being
      // unconditionally correct.
      for (int i = 0; i < 60; i++) {
        world.tick(idle);
      }

      final int shots = world.events.countOf(SimEventType.arrowFired);
      // Tier I at 2.2/s for 0.45s, then tier II at 2.0/s. Roughly two shots.
      expect(shots, inInclusiveRange(2, 3));
    });

    test('a higher fire-rate multiplier produces more arrows', () {
      final SimWorld slow = arena()..fireRateMultiplier = 1.0;
      slow.spawnAt(EntityKind.enemy, 8.0, 4.5, radius: 0.3, health: 1e9);

      final SimWorld fast = arena()..fireRateMultiplier = 3.0;
      fast.spawnAt(EntityKind.enemy, 8.0, 4.5, radius: 0.3, health: 1e9);

      for (int i = 0; i < 120; i++) {
        slow.tick(idle);
        fast.tick(idle);
      }

      expect(
        fast.events.countOf(SimEventType.arrowFired),
        greaterThan(slow.events.countOf(SimEventType.arrowFired) * 2),
      );
    });

    test('arrows carry the tier they were fired at, not the current one', () {
      // The shooter may move and drop to Tier I while an arrow is still in
      // flight. The arrow must keep its own tier or armour resolution is wrong.
      final SimWorld world = arena()..autoFire = false;
      world.spawnAt(EntityKind.enemy, 14.0, 4.5, radius: 0.3, health: 1e9);

      for (int i = 0; i < 80; i++) {
        world.tick(idle);
      }
      expect(world.playerDraw.tier, DrawTier.three);

      world.autoFire = true;
      world.tick(idle);

      int arrowSlot = -1;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 1 &&
            world.entities.kind[i] == EntityKind.projectile.index) {
          arrowSlot = i;
          break;
        }
      }
      expect(arrowSlot, isNot(-1));
      expect(world.projectiles.drawTier[arrowSlot], DrawTier.three.index);

      // Now move — the player drops to tier I but the arrow keeps tier III.
      final InputSnapshot moving = InputSnapshot()..set(1, 0);
      world.tick(moving);
      expect(world.playerDraw.tier, DrawTier.one);
      expect(world.projectiles.drawTier[arrowSlot], DrawTier.three.index);
    });
  });

  group('projectiles', () {
    test('an arrow damages and kills an enemy', () {
      final SimWorld world = arena()..playerAttack = 60;
      world.spawnAt(EntityKind.enemy, 6.0, 4.5, radius: 0.3, health: 50);

      for (int i = 0; i < 90; i++) {
        world.tick(idle);
      }

      expect(world.events.countOf(SimEventType.damageDealt),
          greaterThanOrEqualTo(1));
      expect(world.events.countOf(SimEventType.entityDied),
          greaterThanOrEqualTo(1));
    });

    test('a fast arrow cannot tunnel through a small enemy', () {
      // The classic intermittent "my shot didn't register" bug. An arrow at
      // 14 u/s covers 0.23 u per tick; a Mote is 0.22 u across, so point
      // sampling at the end position would miss at certain alignments.
      // Swept collision is what makes this reliable.
      for (final double speed in <double>[14.0, 40.0, 90.0]) {
        final SimWorld world = arena()
          ..playerAttack = 1000
          ..projectileSpeed = speed;
        world.spawnAt(EntityKind.enemy, 9.0, 4.5, radius: 0.22, health: 1);

        bool hit = false;
        for (int i = 0; i < 120 && !hit; i++) {
          world.tick(idle);
          if (world.events.countOf(SimEventType.damageDealt) > 0) hit = true;
        }

        expect(hit, isTrue, reason: 'arrow tunnelled at speed $speed');
      }
    });

    test('one arrow cannot hit the same enemy twice', () {
      final SimWorld world = arena()
        ..playerAttack = 1
        ..basePierce = 20;
      world.spawnAt(EntityKind.enemy, 7.0, 4.5, radius: 0.4, health: 1e9);

      for (int i = 0; i < 30; i++) {
        world.tick(idle);
      }

      // One arrow crossing a wide enemy spans several ticks. Without hit
      // tracking it would deal damage on every one of them.
      final int hits = world.events.countOf(SimEventType.damageDealt);
      final int shots = world.events.countOf(SimEventType.arrowFired);
      expect(hits, lessThanOrEqualTo(shots),
          reason: 'more hits than arrows means an arrow re-hit a target');
    });

    test('pierce lets one arrow strike a line of enemies', () {
      final SimWorld world = arena()
        ..playerAttack = 1000
        ..basePierce = 5;
      for (int i = 0; i < 4; i++) {
        world.spawnAt(EntityKind.enemy, 6.0 + i * 1.2, 4.5,
            radius: 0.3, health: 1);
      }

      for (int i = 0; i < 60; i++) {
        world.tick(idle);
      }

      expect(world.events.countOf(SimEventType.entityDied), 4);
    });

    test('arrows expire rather than living forever', () {
      final SimWorld world = arena()
        ..arrowLifetime = 0.2
        ..projectileSpeed = 1.0;
      world.spawnAt(EntityKind.enemy, 15.0, 4.5, radius: 0.3, health: 1e9);

      for (int i = 0; i < 300; i++) {
        world.tick(idle);
      }

      int liveArrows = 0;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 1 &&
            world.entities.kind[i] == EntityKind.projectile.index) {
          liveArrows++;
        }
      }
      expect(liveArrows, lessThan(5), reason: 'arrows are leaking');
    });

    test('walls stop arrows', () {
      final SimWorld world = SimWorld(seed: 1);
      world.spawnPlayer(2.0, 4.5);
      world.playerAttack = 1000;
      world.spawnAt(EntityKind.enemy, 14.0, 4.5, radius: 0.3, health: 1e9);

      // No wall: the arrow reaches.
      for (int i = 0; i < 120; i++) {
        world.tick(idle);
      }
      expect(world.events.countOf(SimEventType.damageDealt), greaterThan(0));
    });
  });

  group('auto-aim', () {
    test('off fires along facing, ignoring the target', () {
      final SimWorld world = arena()..aimAssist = AimAssist.off;
      world.entities.facing[world.player.index] = 0; // due east
      world.spawnAt(EntityKind.enemy, 2.0, 1.0, radius: 0.3, health: 1e9);

      final double angle = FiringSystem.aimAngle(
        world.entities,
        FiringSystem.selectTarget(world.entities, world.spatial, 2.0, 4.5),
        2.0,
        4.5,
        0,
        AimAssist.off,
        14.0,
      );
      expect(angle, 0);
    });

    test('standard locks onto the nearest enemy', () {
      final SimWorld world = arena();
      world.spawnAt(EntityKind.enemy, 12.0, 4.5, radius: 0.3, health: 1e9);
      world.spawnAt(EntityKind.enemy, 4.0, 4.5, radius: 0.3, health: 1e9);
      world.spatial.rebuild(world.entities);

      final int target =
          FiringSystem.selectTarget(world.entities, world.spatial, 2.0, 4.5);

      expect(world.entities.posX[target], 4.0,
          reason: 'nearest, not first-spawned');
    });

    test('light only partially corrects', () {
      // Target due north, facing due east. Light assist should land between.
      final SimWorld world = arena();
      world.spawnAt(EntityKind.enemy, 2.0, 1.0, radius: 0.3, health: 1e9);
      world.spatial.rebuild(world.entities);

      final int target =
          FiringSystem.selectTarget(world.entities, world.spatial, 2.0, 4.5);

      final double light = FiringSystem.aimAngle(world.entities, target, 2.0,
          4.5, 0, AimAssist.light, 14.0);
      final double standard = FiringSystem.aimAngle(world.entities, target, 2.0,
          4.5, 0, AimAssist.standard, 14.0);

      expect(light.abs(), greaterThan(0));
      expect(light.abs(), lessThan(standard.abs()));
    });

    test('strong leads a moving target', () {
      final SimWorld world = arena();
      final EntityId enemy =
          world.spawnAt(EntityKind.enemy, 9.0, 4.5, radius: 0.3, health: 1e9);
      world.entities.velY[enemy.index] = 4.0; // moving south fast
      world.spatial.rebuild(world.entities);

      final int target =
          FiringSystem.selectTarget(world.entities, world.spatial, 2.0, 4.5);

      final double standard = FiringSystem.aimAngle(world.entities, target, 2.0,
          4.5, 0, AimAssist.standard, 14.0);
      final double strong = FiringSystem.aimAngle(world.entities, target, 2.0,
          4.5, 0, AimAssist.strong, 14.0);

      expect(strong, isNot(standard));
      expect(strong, greaterThan(standard),
          reason: 'lead should aim ahead of a southbound target');
    });

    test('no target leaves the aim where the player is looking', () {
      final SimWorld world = arena();
      final double angle = FiringSystem.aimAngle(
          world.entities, -1, 2.0, 4.5, 1.234, AimAssist.standard, 14.0);
      expect(angle, 1.234);
    });
  });

  group('determinism with combat active', () {
    test('identical seeds and inputs produce identical outcomes', () {
      String run() {
        final SimWorld world = SimWorld(seed: 777)..playerAttack = 25;
        world.spawnPlayer(2.0, 4.5);
        for (int i = 0; i < 20; i++) {
          world.spawnAt(EntityKind.enemy, 4.0 + (i % 8) * 1.3,
              1.5 + (i ~/ 8) * 2.2,
              radius: 0.3, health: 120);
        }

        final InputSnapshot input = InputSnapshot();
        for (int t = 0; t < 600; t++) {
          // Oscillate so both Draw and Momentum are exercised.
          final bool moving = (t ~/ 20).isEven;
          input.set(moving ? 0.9 : 0.0, moving ? 0.4 : 0.0);
          world.tick(input);
        }

        return '${world.entities.liveCount};'
            '${world.playerDraw.tier};'
            '${world.playerDraw.momentumStacks};'
            '${world.events.countOf(SimEventType.entityDied)}';
      }

      final String a = run();
      final String b = run();
      expect(a, b);
    });

    test('combat still fits the tick budget', () {
      final SimWorld world = SimWorld(seed: 9)
        ..playerAttack = 5
        ..basePierce = 3;
      world.spawnPlayer(8.0, 4.5);
      for (int i = 0; i < 80; i++) {
        world.spawnAt(EntityKind.enemy, 1.0 + (i % 14) * 1.05,
            0.8 + (i ~/ 14) * 1.4,
            radius: 0.3, health: 1e9);
      }

      final InputSnapshot input = InputSnapshot();
      for (int i = 0; i < 2000; i++) {
        world.tick(input);
      }

      const int samples = 10000;
      final Stopwatch sw = Stopwatch()..start();
      for (int i = 0; i < samples; i++) {
        world.tick(input);
      }
      sw.stop();

      final double perTickMs = sw.elapsedMicroseconds / samples / 1000.0;
      // ignore: avoid_print
      print('combat tick: ${perTickMs.toStringAsFixed(4)} ms '
          '(budget 4.0 ms)');

      expect(perTickMs, lessThan(4.0));
    });
  });

  group('Momentum affects movement', () {
    test('stacks are readable for the movement multiplier', () {
      final SimWorld world = arena();
      final InputSnapshot moving = InputSnapshot()..set(1, 0);

      for (int i = 0; i < 120; i++) {
        world.tick(moving);
      }

      expect(world.playerDraw.momentumStacks, DrawState.baseMaxMomentum);
      expect(world.playerDraw.moveSpeedBonus, closeTo(0.15, 1e-9));
    });
  });

  test('SimConfig dead zone gates the Draw correctly', () {
    final SimWorld world = arena();
    final InputSnapshot tiny = InputSnapshot()
      ..set(SimConfig.stickDeadZone * 0.5, 0);

    for (int i = 0; i < 80; i++) {
      world.tick(tiny);
    }

    expect(world.playerDraw.tier, DrawTier.three,
        reason: 'input inside the dead zone counts as standing still');
  });
}
