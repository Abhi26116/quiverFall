import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Skarn the Unmade — the split/shared-pool half reuses Cinder Choir's own
/// primitives unmodified (already covered by `cinder_choir_system_test
/// .dart`, which is why this file does not re-derive a `linkedHealthSlot`
/// redirect test of its own); this file is the genuinely new part — how
/// many bodies exist at each phase, and the neglect-heal "pressure" math.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnSkarn() {
    final SimWorld world = SimWorld(seed: 909, content: content)
      ..autoFire = false;
    world.spawnPlayer(centerX, centerY - 3.0);
    final int primary = world.spawnSkarn(centerX, centerY, health: health);
    return (world: world, primary: primary);
  }

  List<int> childrenOf(SimWorld world, int primary) {
    final List<int> out = <int>[];
    for (int i = 0; i < world.entities.highWater; i++) {
      if (world.entities.alive[i] == 1 && world.enemies.bossParent[i] == primary) {
        out.add(i);
      }
    }
    return out;
  }

  group('spawn', () {
    test('a single, directly-hittable body', () {
      final (:world, :primary) = spawnSkarn();

      expect(world.enemies.untargetable[primary], 0,
          reason: 'unlike Cinder Choir\'s anchor, Skarn P1 is the fight');
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(childrenOf(world, primary), isEmpty);
    });
  });

  group('splitting', () {
    test('P1 stays a single body no matter how long it runs', () {
      final (:world, :primary) = spawnSkarn();
      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }
      expect(childrenOf(world, primary), isEmpty);
    });

    test('reaching P2 splits into two, sharing the pool', () {
      final (:world, :primary) = spawnSkarn();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());

      final List<int> children = childrenOf(world, primary);
      expect(children, hasLength(1));
      expect(world.enemies.linkedHealthSlot[children.first], primary);
    });

    test('reaching P3 splits into four total', () {
      final (:world, :primary) = spawnSkarn();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());

      final List<int> children = childrenOf(world, primary);
      expect(children, hasLength(3));
      for (final int c in children) {
        expect(world.enemies.linkedHealthSlot[c], primary);
      }
    });

    test('splitting is idempotent — ticking further does not add more bodies',
        () {
      final (:world, :primary) = spawnSkarn();
      world.enemies.bossPhase[primary] = 2;
      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      expect(childrenOf(world, primary), hasLength(3));
    });
  });

  group('the pressure mechanic', () {
    test('P1 never heals even if left alone', () {
      final (:world, :primary) = spawnSkarn();
      // Above the 66% phase-1 threshold — this is testing P1 staying P1,
      // not accidentally triggering `BossPhaseSystem`'s own transition.
      world.entities.health[primary] = health * 0.70;

      for (int i = 0; i < 180; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[primary], health * 0.70,
          reason: 'nothing to neglect with only one body');
      expect(world.enemies.bossPhase[primary], 0);
    });

    test('a body pressured every tick never lets its own timer cross the '
        'threshold', () {
      final (:world, :primary) = spawnSkarn();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      expect(childrenOf(world, primary), hasLength(1));
      world.entities.health[primary] = health * 0.5;

      for (int i = 0; i < 180; i++) {
        world.enemies.bossLastHitAgo[primary] = 0;
        world.tick(InputSnapshot());
      }

      // The child was never pressured — it alone should have healed the
      // pool at 3%/s past the 1.0s grace window.
      expect(world.entities.health[primary], greaterThan(health * 0.5));
      expect(world.entities.health[primary], lessThan(health));
    });

    test('pressuring both bodies prevents any healing at all', () {
      final (:world, :primary) = spawnSkarn();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      final int child = childrenOf(world, primary).first;
      world.entities.health[primary] = health * 0.5;

      for (int i = 0; i < 180; i++) {
        world.enemies.bossLastHitAgo[primary] = 0;
        world.enemies.bossLastHitAgo[child] = 0;
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[primary], health * 0.5);
    });

    test('neglecting both bodies heals roughly twice as fast as neglecting '
        'one', () {
      double healedAfter(bool pressureOneBody) {
        final (:world, :primary) = spawnSkarn();
        world.enemies.bossPhase[primary] = 1;
        world.tick(InputSnapshot());
        world.entities.health[primary] = health * 0.5;

        for (int i = 0; i < 180; i++) {
          if (pressureOneBody) world.enemies.bossLastHitAgo[primary] = 0;
          world.tick(InputSnapshot());
        }
        return world.entities.health[primary] - health * 0.5;
      }

      final double healedOneNeglected = healedAfter(true);
      final double healedBothNeglected = healedAfter(false);

      expect(healedOneNeglected, greaterThan(0));
      expect(healedBothNeglected, closeTo(healedOneNeglected * 2, 1.0));
    });

    test('healing never overshoots max health', () {
      final (:world, :primary) = spawnSkarn();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      world.entities.health[primary] = health - 1.0;

      for (int i = 0; i < 180; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[primary], health);
    });
  });

  group('death', () {
    test('killing the primary despawns every split-off body', () {
      final (:world, :primary) = spawnSkarn();
      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      final List<int> children = childrenOf(world, primary);
      expect(children, hasLength(3));

      world.entities.health[primary] = 0;
      world.tick(InputSnapshot());

      expect(world.entities.isAlive(world.entities.idAt(primary)), isFalse);
      for (final int c in children) {
        expect(world.entities.alive[c], 0);
      }
    });
  });
}
