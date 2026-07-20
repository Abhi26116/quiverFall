@Tags(<String>['slow'])
library;

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spawn/room_composer.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';
import 'package:test/test.dart';

import 'enemy_test_support.dart';

/// The Phase 5 exit criterion: a generated room populates, and all 26 AIs
/// execute for 60 s without error.
///
/// "Without error" is stricter than "without throwing". An AI that quietly
/// drops a telegraph has shipped an undodgeable attack; one that walks an enemy
/// out of the arena has shipped an unkillable one. Both are asserted here,
/// because both are invisible in a playtest until the exact moment they are not.
void main() {
  late ContentLibrary content;

  setUpAll(() {
    content = loadEnemies();
  });

  /// Everything that must stay true of a live room, checked every tick.
  void assertInvariants(SimWorld world, String context) {
    expect(
      world.telegraphs.dropped,
      0,
      reason: '$context: a dropped telegraph is an undodgeable attack',
    );
    expect(
      world.hazards.dropped,
      0,
      reason: '$context: a dropped shell is an attack the player dodged for '
          'no reason',
    );
    expect(
      world.spatial.overflowCount,
      0,
      reason: '$context: spatial overflow silently drops collisions',
    );

    int enemies = 0;
    for (int i = 0; i < world.entities.highWater; i++) {
      if (world.entities.alive[i] == 0) continue;
      if (world.entities.kind[i] != EntityKind.enemy.index) continue;
      enemies++;

      final double x = world.entities.posX[i];
      final double y = world.entities.posY[i];
      expect(
        x.isFinite && y.isFinite,
        isTrue,
        reason: '$context: enemy $i left the number line',
      );
      expect(x, inInclusiveRange(-0.01, SimConfig.arenaWidth + 0.01),
          reason: '$context: enemy $i escaped the arena');
      expect(y, inInclusiveRange(-0.01, SimConfig.arenaHeight + 0.01),
          reason: '$context: enemy $i escaped the arena');
      expect(world.entities.health[i].isFinite, isTrue, reason: context);
    }

    expect(
      enemies,
      lessThanOrEqualTo(SimConfig.maxEntities),
      reason: '$context: entity pool exhausted',
    );
  }

  group('every archetype survives a minute of simulation', () {
    for (final EnemyArchetype archetype in EnemyArchetype.values) {
      test(archetype.name, () {
        final SimWorld world = enemyWorld(
          content: content,
          seed: 0x5EED + archetype.index,
          // The player is a punchbag here: this test is about the AI running,
          // not about the fight being survivable.
          playerHealth: 1e12,
        );

        // Four of them, spread out, so flocking, separation, auras and ally
        // queries all have something to work with.
        for (int i = 0; i < 4; i++) {
          world.spawnEnemy(archetype, 11.0 + i % 2 * 2.0, 2.0 + i * 1.8);
        }

        final InputSnapshot idle = InputSnapshot();
        final InputSnapshot moving = InputSnapshot()..set(1, 0.4);

        for (int tick = 0; tick < 60 * 60; tick++) {
          // Alternate standing and moving, so Draw-lock, Momentum mitigation,
          // rear-arc lunges and the Echo's mirror are all exercised.
          world.tick(tick % 180 < 90 ? idle : moving);
          if (tick % 30 == 0) {
            assertInvariants(world, '${archetype.name} at tick $tick');
            world.events.clear();
          }
        }

        assertInvariants(world, '${archetype.name} at the end');
      });
    }
  });

  group('generated rooms', () {
    test('a chapter-8 room populates and runs for 60 s', () {
      final SimWorld world = enemyWorld(
        content: content,
        seed: 991,
        playerHealth: 1e12,
        autoFire: true,
        enemyHpBase: Curves.enemyHp(160),
      )..playerAttack = 40;

      final RoomPlan plan = RoomComposer.compose(
        content: content,
        rng: Rng(991),
        chapter: 8,
        globalStage: 160,
      );
      world.beginRoom(plan);

      final InputSnapshot moving = InputSnapshot()..set(0.6, -0.8);
      int peakEnemies = 0;

      for (int tick = 0; tick < 60 * 60; tick++) {
        world.tick(tick % 120 < 60 ? moving : InputSnapshot());

        int alive = 0;
        for (int i = 0; i < world.entities.highWater; i++) {
          if (world.entities.alive[i] == 1 &&
              world.entities.kind[i] == EntityKind.enemy.index) {
            alive++;
          }
        }
        if (alive > peakEnemies) peakEnemies = alive;

        expect(
          alive,
          lessThanOrEqualTo(SimConfig.maxContactEnemies),
          reason: 'more enemies on screen than a phone can read',
        );

        if (tick % 60 == 0) {
          assertInvariants(world, 'generated room at tick $tick');
          world.events.clear();
        }
      }

      expect(peakEnemies, greaterThan(0), reason: 'the room never populated');
    });

    test('an Elite room runs its Riftborn for 60 s', () {
      final SimWorld world = enemyWorld(
        content: content,
        seed: 7,
        playerHealth: 1e12,
        enemyHpBase: Curves.enemyHp(60),
      );

      world.beginRoom(
        RoomComposer.compose(
          content: content,
          rng: Rng(7),
          chapter: 5,
          globalStage: 60,
          isElite: true,
        ),
      );

      final InputSnapshot idle = InputSnapshot();
      for (int tick = 0; tick < 60 * 60; tick++) {
        world.tick(idle);
        if (tick % 60 == 0) {
          assertInvariants(world, 'elite room at tick $tick');
          world.events.clear();
        }
      }
    });
  });

  group('determinism', () {
    test('the same seed and inputs produce the same room, tick for tick', () {
      SimWorld build() {
        final SimWorld world = enemyWorld(
          content: content,
          seed: 12345,
          playerHealth: 1e12,
          autoFire: true,
          enemyHpBase: Curves.enemyHp(90),
        )..playerAttack = 25;
        world.beginRoom(
          RoomComposer.compose(
            content: content,
            rng: Rng(12345),
            chapter: 6,
            globalStage: 90,
          ),
        );
        return world;
      }

      final SimWorld a = build();
      final SimWorld b = build();
      final InputSnapshot moving = InputSnapshot()..set(0.3, 0.9);
      final InputSnapshot idle = InputSnapshot();

      for (int tick = 0; tick < 60 * 20; tick++) {
        final InputSnapshot input = tick % 90 < 45 ? moving : idle;
        a.tick(input);
        b.tick(input);
      }

      expect(a.entities.liveCount, b.entities.liveCount);
      for (int i = 0; i < a.entities.highWater; i++) {
        expect(a.entities.alive[i], b.entities.alive[i], reason: 'slot $i');
        if (a.entities.alive[i] == 0) continue;
        expect(a.entities.posX[i], b.entities.posX[i], reason: 'slot $i x');
        expect(a.entities.posY[i], b.entities.posY[i], reason: 'slot $i y');
        expect(a.entities.health[i], b.entities.health[i], reason: 'slot $i hp');
        expect(a.enemies.state[i], b.enemies.state[i], reason: 'slot $i state');
      }
    });
  });
}
