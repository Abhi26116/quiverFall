import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/fixed_step_driver.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/spatial_hash.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

void main() {
  group('EntityStore', () {
    test('spawns and despawns', () {
      final EntityStore store = EntityStore(capacity: 16);
      expect(store.liveCount, 0);

      final EntityId a = store.spawn(EntityKind.enemy);
      expect(store.isAlive(a), isTrue);
      expect(store.liveCount, 1);

      store.despawn(a);
      expect(store.isAlive(a), isFalse);
      expect(store.liveCount, 0);
    });

    test('a stale handle does not address the slot that replaced it', () {
      // The bug this prevents: a projectile homing onto a corpse's replacement.
      // Nearly impossible to diagnose from a player report, so it is designed
      // out via generation counters.
      final EntityStore store = EntityStore(capacity: 4);

      final EntityId first = store.spawn(EntityKind.enemy);
      store.despawn(first);
      final EntityId reused = store.spawn(EntityKind.enemy);

      expect(reused.index, first.index, reason: 'slot should be recycled');
      expect(reused.raw, isNot(first.raw), reason: 'handle must differ');
      expect(store.isAlive(first), isFalse);
      expect(store.isAlive(reused), isTrue);
    });

    test('returns none when full rather than growing', () {
      // Growing would allocate mid-combat, which is the thing the whole storage
      // design exists to avoid.
      final EntityStore store = EntityStore(capacity: 3);
      expect(store.spawn(EntityKind.enemy).isNone, isFalse);
      expect(store.spawn(EntityKind.enemy).isNone, isFalse);
      expect(store.spawn(EntityKind.enemy).isNone, isFalse);
      expect(store.spawn(EntityKind.enemy).isNone, isTrue);
    });

    test('highWater tracks live slots so systems iterate less', () {
      final EntityStore store = EntityStore(capacity: 64);
      final List<EntityId> ids = <EntityId>[
        for (int i = 0; i < 10; i++) store.spawn(EntityKind.enemy),
      ];
      expect(store.highWater, 10);

      for (int i = 9; i >= 5; i--) {
        store.despawn(ids[i]);
      }
      expect(store.highWater, 5, reason: 'trailing dead slots are trimmed');
      expect(store.liveCount, 5);
    });

    test('freshly spawned slots carry no stale component data', () {
      final EntityStore store = EntityStore(capacity: 4);
      final EntityId a = store.spawn(EntityKind.enemy);
      store.posX[a.index] = 12.0;
      store.health[a.index] = 999.0;
      store.despawn(a);

      final EntityId b = store.spawn(EntityKind.projectile);
      expect(store.posX[b.index], 0.0);
      expect(store.health[b.index], 0.0);
      expect(store.kindOf(b.index), EntityKind.projectile);
    });

    test('clear resets everything', () {
      final EntityStore store = EntityStore(capacity: 8);
      for (int i = 0; i < 5; i++) {
        store.spawn(EntityKind.enemy);
      }
      store.clear();
      expect(store.liveCount, 0);
      expect(store.highWater, 0);
      expect(store.spawn(EntityKind.enemy).isNone, isFalse);
    });
  });

  group('SpatialHash', () {
    test('finds neighbours within a radius', () {
      final SpatialHash hash = SpatialHash();
      hash.insert(1, 2.0, 2.0);
      hash.insert(2, 2.4, 2.1);
      hash.insert(3, 12.0, 7.0);

      final int n = hash.queryRadius(2.0, 2.0, 1.0);
      final Set<int> found = <int>{
        for (int i = 0; i < n; i++) hash.resultAt(i),
      };

      expect(found, containsAll(<int>[1, 2]));
      expect(found, isNot(contains(3)));
    });

    test('drops overflow instead of growing a bucket', () {
      final SpatialHash hash = SpatialHash();
      // Pile far more than maxPerCell into one cell.
      for (int i = 0; i < SimConfig.maxPerCell + 12; i++) {
        hash.insert(i, 0.5, 0.5);
      }
      expect(hash.countInCell(0), SimConfig.maxPerCell);
      expect(hash.overflowCount, 12);
    });

    test('clamps queries at the arena edges', () {
      final SpatialHash hash = SpatialHash();
      hash.insert(7, 0.1, 0.1);
      // A query straddling the boundary must not index out of range.
      final int n = hash.queryRadius(-5.0, -5.0, 6.0);
      expect(n, greaterThan(0));
    });

    test('rebuild reflects current entity positions', () {
      final SimWorld world = SimWorld(seed: 1);
      world.spawnAt(EntityKind.enemy, 3.0, 3.0, radius: 0.3, health: 10);
      world.spatial.rebuild(world.entities);

      final int before = world.spatial.queryRadius(3.0, 3.0, 0.5);
      expect(before, 1);

      world.entities.posX[0] = 14.0;
      world.spatial.rebuild(world.entities);

      expect(world.spatial.queryRadius(3.0, 3.0, 0.5), 0);
      expect(world.spatial.queryRadius(14.0, 3.0, 0.5), 1);
    });

    test('segment query covers the swept path', () {
      final SpatialHash hash = SpatialHash();
      hash.insert(1, 5.0, 4.0);
      final int n = hash.querySegment(1.0, 4.0, 9.0, 4.0, 0.2);
      final Set<int> found = <int>{
        for (int i = 0; i < n; i++) hash.resultAt(i),
      };
      expect(found, contains(1));
    });
  });

  group('SimEventBuffer', () {
    test('records and counts by type', () {
      final SimEventBuffer buffer = SimEventBuffer(capacity: 8);
      buffer.emit(SimEventType.damageDealt, entityA: 1, valueA: 12.5);
      buffer.emit(SimEventType.damageDealt, entityA: 2, valueA: 3.0);
      buffer.emit(SimEventType.entityDied, entityA: 2);

      expect(buffer.count, 3);
      expect(buffer.countOf(SimEventType.damageDealt), 2);
      expect(buffer.valueAAt(0), 12.5);
      expect(buffer.typeAt(2), SimEventType.entityDied);
    });

    test('drops rather than growing when full', () {
      final SimEventBuffer buffer = SimEventBuffer(capacity: 2);
      buffer.emit(SimEventType.damageDealt);
      buffer.emit(SimEventType.damageDealt);
      buffer.emit(SimEventType.damageDealt);

      expect(buffer.count, 2);
      expect(buffer.dropped, 1);
    });
  });

  group('FixedStepDriver', () {
    test('a 60Hz frame produces exactly one step', () {
      final SimWorld world = SimWorld(seed: 1);
      final FixedStepDriver driver = FixedStepDriver(world);
      expect(driver.advance(1 / 60, InputSnapshot()), 1);
    });

    test('a 120Hz device still simulates at 60Hz', () {
      final SimWorld world = SimWorld(seed: 1);
      final FixedStepDriver driver = FixedStepDriver(world);
      final InputSnapshot input = InputSnapshot();

      // 120 rendered frames of 1/120s = 1 second of wall time.
      for (int i = 0; i < 120; i++) {
        driver.advance(1 / 120, input);
      }

      expect(world.tickCount, 60, reason: 'one second is 60 simulation steps');
    });

    test('catch-up is capped, so a slow device does not death-spiral', () {
      final SimWorld world = SimWorld(seed: 1);
      final FixedStepDriver driver = FixedStepDriver(world);

      // A 1-second stall would be 60 steps if uncapped.
      final int steps = driver.advance(1.0, InputSnapshot());

      expect(steps, SimConfig.maxCatchUpTicks);
    });

    test('a long stall is clamped rather than simulated', () {
      final SimWorld world = SimWorld(seed: 1);
      final FixedStepDriver driver = FixedStepDriver(world);

      // App backgrounded for 30 seconds.
      driver.advance(30.0, InputSnapshot());

      expect(world.tickCount, lessThanOrEqualTo(SimConfig.maxCatchUpTicks));
    });

    test('alpha stays in [0,1) for interpolation', () {
      final SimWorld world = SimWorld(seed: 1);
      final FixedStepDriver driver = FixedStepDriver(world);
      final InputSnapshot input = InputSnapshot();

      for (int i = 0; i < 200; i++) {
        driver.advance(1 / 144, input);
        expect(driver.alpha, greaterThanOrEqualTo(0.0));
        expect(driver.alpha, lessThan(1.0));
      }
    });
  });

  group('Curves', () {
    test('enemy HP steps down its growth rate at chapter 5', () {
      // Early chapters must feel like fast power gain; late chapters need a
      // curve flat enough that a session of Spire levels is still perceptible.
      final double g80 = Curves.enemyHp(80);
      final double g81 = Curves.enemyHp(81);
      final double g100 = Curves.enemyHp(100);

      expect(g81 / g80, closeTo(Curves.lateGrowth, 1e-9));
      expect(Curves.enemyHp(2) / Curves.enemyHp(1),
          closeTo(Curves.earlyGrowth, 1e-9));
      expect(g100, greaterThan(g81));
    });

    test('enemy HP is monotonic across the whole campaign', () {
      double previous = 0;
      for (int g = 1; g <= 240; g++) {
        final double hp = Curves.enemyHp(g);
        expect(hp, greaterThan(previous), reason: 'regressed at g=$g');
        previous = hp;
      }
    });

    test('there is no zero-reward run', () {
      // Design commitment from docs/10-ui-ux.md §10.9 — dying in room 2 of 7
      // still banks something, and the defeat screen says the number aloud.
      expect(Curves.partialGold(3, 5, 1, 7), greaterThan(0));
      expect(Curves.partialGold(3, 5, 0, 7), 0);
      expect(
        Curves.partialGold(3, 5, 7, 7),
        closeTo(Curves.stageGold(3, 5) * 0.7, 1e-9),
      );
    });

    test('gold multipliers are hard-capped', () {
      expect(Curves.clampGoldMultiplier(99.0), Curves.maxGoldMultiplier);
      expect(Curves.clampGoldMultiplier(2.5), 2.5);
    });

    test('Spire cumulative cost matches summing the terms', () {
      const double base = 60.0;
      double sum = 0;
      for (int n = 1; n <= 40; n++) {
        sum += Curves.spireNodeCost(base, n);
      }
      expect(Curves.spireCumulativeCost(base, 40), closeTo(sum, 1e-6));
    });

    test('Ascension pays nothing below the gate and scales above it', () {
      expect(Curves.emberdustFor(8, 0), 0);
      expect(Curves.emberdustFor(10, 0), greaterThan(0));
      // Pushing further before ascending must be worth meaningfully more, or
      // the "ascend now or push on" decision is not a decision.
      expect(
        Curves.emberdustFor(14, 0),
        greaterThan(Curves.emberdustFor(10, 0) * 3),
      );
    });

    test('boss HP scales with repeat kills but damage never does', () {
      final double first = Curves.bossHp(20, 22.0, 0);
      final double fifth = Curves.bossHp(20, 22.0, 5);
      expect(fifth, closeTo(first * 1.3, 1e-6));
    });

    test('hero level cap tracks campaign progress', () {
      expect(Curves.heroLevelCap(0), 8);
      expect(Curves.heroLevelCap(5), 48);
    });

    test('Vigor regen is one point per six minutes', () {
      expect(Curves.vigorRegenerated(const Duration(minutes: 5)), 0);
      expect(Curves.vigorRegenerated(const Duration(minutes: 6)), 1);
      expect(Curves.vigorRegenerated(const Duration(hours: 3)), 30);
    });

    test('TTK bounds are ordered sanely', () {
      expect(Curves.ttkHardMin, lessThan(Curves.ttkTargetMin));
      expect(Curves.ttkTargetMax, lessThan(Curves.ttkHardMax));
      expect(Curves.ttkWithinTarget(1.2), isTrue);
      expect(Curves.ttkWithinTarget(0.5), isFalse);
      expect(Curves.ttkWithinHardBounds(2.0), isTrue);
    });
  });
}
