import 'dart:math' as math;

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spawn/room_composer.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';
import 'package:test/test.dart';

import 'enemy_test_support.dart';

void main() {
  late ContentLibrary content;
  final InputSnapshot idle = InputSnapshot();

  setUpAll(() {
    content = loadEnemies();
  });

  SimWorld roomWorld({
    int seed = 4004,
    int chapter = 2,
    int globalStage = 25,
    bool isElite = false,
  }) {
    final SimWorld world = enemyWorld(
      content: content,
      seed: seed,
      playerHealth: 1e12,
    );
    world.beginRoom(
      RoomComposer.compose(
        content: content,
        rng: Rng(seed),
        chapter: chapter,
        globalStage: globalStage,
        isElite: isElite,
      ),
    );
    return world;
  }

  int aliveEnemies(SimWorld world) {
    int n = 0;
    for (int i = 0; i < world.entities.highWater; i++) {
      if (world.entities.alive[i] == 1 &&
          world.entities.kind[i] == EntityKind.enemy.index) {
        n++;
      }
    }
    return n;
  }

  group('§5.7 no enemy spawns within 3.5 u of the player', () {
    test('across 40 rooms, nothing lands on top of the player', () {
      for (int seed = 0; seed < 40; seed++) {
        final SimWorld world = roomWorld(seed: 5000 + seed);
        final double px = world.entities.posX[world.player.index];
        final double py = world.entities.posY[world.player.index];

        // Drop the player's own spawn event; the rule is about enemies.
        world.events.clear();

        for (int tick = 0; tick < 60 * 30; tick++) {
          world.tick(idle);

          for (int e = 0; e < world.events.count; e++) {
            if (world.events.typeAt(e) != SimEventType.entitySpawned) continue;
            final double dx = world.events.xAt(e) - px;
            final double dy = world.events.yAt(e) - py;
            expect(
              math.sqrt(dx * dx + dy * dy),
              greaterThanOrEqualTo(EnemyTuning.minSpawnDistanceFromPlayer),
              reason: 'seed ${5000 + seed}: a spawn landed on the player',
            );
          }
          world.events.clear();
        }
      }
    });
  });

  group('every spawn is announced', () {
    test('nothing exists during the edge-flash window', () {
      final SimWorld world = roomWorld();

      // The first wave is queued on the opening tick and must not exist yet.
      world.tick(idle);
      expect(world.spawnState.hasPending, isTrue);
      expect(aliveEnemies(world), 0);
      expect(
        world.telegraphs.liveCount,
        greaterThan(0),
        reason: 'the edge-flash is the announcement',
      );

      // Still nothing a fraction before the flash resolves.
      run(world, EnemyTuning.spawnTelegraphSeconds - 0.1);
      expect(aliveEnemies(world), 0);

      run(world, 0.2);
      expect(aliveEnemies(world), greaterThan(0));
    });
  });

  group('waves', () {
    test('a multi-wave room does not release everything at once', () {
      // A late-game room is large enough to be split.
      final SimWorld world = roomWorld(chapter: 10, globalStage: 200);
      final RoomPlan plan = world.spawnState.plan!;
      if (plan.waves.length < 2) {
        markTestSkipped('this seed produced a single-wave room');
        return;
      }

      run(world, 1.0);
      expect(
        aliveEnemies(world),
        lessThan(plan.totalEnemies),
        reason: 'the whole room arrived on wave one',
      );
      expect(world.spawnState.nextWave, 1);
    });

    test('the next wave waits until the last one is nearly cleared', () {
      final SimWorld world = roomWorld(chapter: 10, globalStage: 200);
      final RoomPlan plan = world.spawnState.plan!;
      if (plan.waves.length < 2) {
        markTestSkipped('this seed produced a single-wave room');
        return;
      }

      run(world, 6.0);
      expect(world.spawnState.nextWave, 1, reason: 'wave two released early');
    });

    test('a cleared room says so, once', () {
      final SimWorld world = roomWorld();

      int cleared = 0;
      for (int tick = 0; tick < 60 * 60; tick++) {
        world.tick(idle);

        // Kill everything the moment it appears, so the room drains.
        for (int i = 0; i < world.entities.highWater; i++) {
          if (world.entities.alive[i] == 0) continue;
          if (world.entities.kind[i] != EntityKind.enemy.index) continue;
          world.entities.health[i] = 0;
        }

        cleared += world.events.countOf(SimEventType.roomCleared);
        world.events.clear();
      }

      expect(cleared, 1, reason: 'roomCleared must fire exactly once');
      expect(world.spawnState.roomClearedEmitted, isTrue);
    });

    test('the on-screen enemy cap holds even in the largest rooms', () {
      final SimWorld world = roomWorld(chapter: 12, globalStage: 240);
      for (int tick = 0; tick < 60 * 40; tick++) {
        world.tick(idle);
        expect(
          aliveEnemies(world),
          lessThanOrEqualTo(SimConfig.maxContactEnemies),
        );
        world.events.clear();
      }
    });
  });

  group('room lifecycle', () {
    test('clearRoom leaves nothing behind', () {
      final SimWorld world = roomWorld();
      run(world, 10.0);
      expect(aliveEnemies(world), greaterThan(0));

      world.clearRoom();

      expect(aliveEnemies(world), 0);
      expect(world.telegraphs.liveCount, 0);
      expect(world.hazards.liveCount, 0);
      expect(world.spawnState.plan, isNull);
      expect(world.spawnState.hasPending, isFalse);
    });

    test('an Elite room puts exactly one Riftborn in the arena', () {
      final SimWorld world =
          roomWorld(seed: 88, chapter: 6, globalStage: 110, isElite: true);
      run(world, 20.0);

      int riftborn = 0;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        if (world.entities.kind[i] != EntityKind.enemy.index) continue;
        final int index = world.entities.contentIndex[i];
        if (index < 0) continue;
        // Rift Maw adds are Swarmlings, not Riftborn, so this counts elites
        // rather than bodies.
        if (content.enemies[index].family == EnemyFamily.riftborn) riftborn++;
      }

      expect(riftborn, 1);
    });
  });
}
