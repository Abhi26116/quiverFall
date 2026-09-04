import 'dart:io';

import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/level/arena_definition.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

/// The Phase 8 exit criterion's other half:
///
/// > A full 7-room stage plays end to end.
///
/// Played headlessly, by a bot that circles and lets auto-fire work. That is a
/// far weaker player than a real one, which is the point — if a scripted circle
/// can clear a stage, a person can.
void main() {
  late ContentLibrary content;

  setUpAll(() {
    content = ContentLibrary.parse(
      enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
      arenasJson: File('assets/data/arenas.json').readAsStringSync(),
      bossesJson: File('assets/data/bosses.json').readAsStringSync(),
    ).$1!;
  });

  ({StageRunner runner, SimWorld world}) stage({
    int chapter = 3,
    int stage = 5,
    int seed = 4242,
    double attackScale = 1.0,
    bool invulnerable = true,
  }) {
    final StageBlueprint blueprint = StageBlueprint.forStage(
      chapter: chapter,
      stage: stage,
      seed: seed,
    );
    final StagePlan plan = generateStage(
      generator: LevelGenerator(content: content, arenas: content.arenas),
      blueprint: blueprint,
    );
    final SimWorld world = buildStageWorld(
      blueprint: blueprint,
      content: content,
      plan: plan,
    );
    world.playerAttack *= attackScale;

    final StageRunner runner =
        StageRunner(world: world, content: content, plan: plan)..start();
    return (runner: runner, world: world);
  }

  /// Runs the stage with a bot that plays the game's actual rhythm.
  ///
  /// Two things it has to do, and both were learned the hard way:
  ///
  /// **It roots.** A bot that moves constantly sits at Draw Tier I forever,
  /// where an arrow into a Bulwark's plate deals 10 % — one Bulwark then takes
  /// two minutes and the stage never ends. That is the Draw working as designed:
  /// "move to survive, root to escalate" is not optional.
  ///
  /// **It roams.** A bot circling one spot never gets line of sight into the
  /// far side of a walled arena, so a single enemy behind a pillar keeps the
  /// room open indefinitely. Real players walk the room; a bot that does not is
  /// measuring its own myopia rather than the stage.
  double play(
    StageRunner runner,
    SimWorld world, {
    double maxSeconds = 900,
    bool invulnerable = true,
  }) {
    final InputSnapshot input = InputSnapshot();
    final int maxTicks = (maxSeconds * 60).round();

    for (int tick = 0; tick < maxTicks; tick++) {
      if (invulnerable && world.entities.isAlive(world.player)) {
        // Damage is a *fraction* of max HP, so a big pool would not help — the
        // health is topped up instead. This is testing whether a stage can be
        // completed, not whether it can be survived.
        final int p = world.player.index;
        world.entities.health[p] = world.entities.maxHealth[p];
      }

      final double t = tick / 60.0;

      // Walk to a waypoint, stand and shoot, move on. Roughly what a competent
      // player does.
      //
      // The waypoints are the room's own **spawn points**, which the content
      // loader guarantees are inside the arena and clear of walls. Fixed
      // coordinates were tried first and sat inside the corner blocks of
      // `corridor_cross`, so the bot spent the room shoving a wall.
      const double leg = 3.4;
      final List<SpawnPoint> waypoints = runner.room.arena.spawnPoints;
      final int index = (t / leg).floor() % waypoints.length;
      final bool rooting = t % leg > 2.0;

      if (rooting || !world.entities.isAlive(world.player)) {
        input.set(0, 0);
      } else {
        final int p = world.player.index;
        final double dx = waypoints[index].x - world.entities.posX[p];
        final double dy = waypoints[index].y - world.entities.posY[p];
        final double len = _hypot(dx, dy);
        if (len < 0.2) {
          input.set(0, 0);
        } else {
          input.set(dx / len, dy / len);
        }
      }

      world.tick(input);
      world.events.clear();

      runner.update();
      if (runner.status != StageStatus.fighting) return t;
    }
    return maxSeconds;
  }

  group('a full stage', () {
    test('plays end to end', () {
      final ({StageRunner runner, SimWorld world}) s = stage();
      expect(s.runner.roomTotal, StageBlueprint.roomCount(3));
      expect(s.runner.roomIndex, 0);

      final double seconds = play(s.runner, s.world);

      expect(
        s.runner.status,
        StageStatus.complete,
        reason: 'stalled in room ${s.runner.roomIndex} after ${seconds}s',
      );
      expect(s.runner.roomsCleared, s.runner.roomTotal);
    });

    test('every chapter completes', () {
      for (int chapter = 1; chapter <= 12; chapter++) {
        final ({StageRunner runner, SimWorld world}) s =
            stage(chapter: chapter, stage: 10, seed: 900 + chapter);
        play(s.runner, s.world);
        expect(
          s.runner.status,
          StageStatus.complete,
          reason: 'chapter $chapter stalled in room ${s.runner.roomIndex}',
        );
      }
    });

    test('each room loads its own arena geometry', () {
      // Rooms within a stage have different authored arenas. If the world kept
      // the first room's collision geometry, walls would change visually but
      // not physically — a room that looks right and plays wrong.
      final ({StageRunner runner, SimWorld world}) s = stage(seed: 77);

      final Set<String> arenaIds = <String>{};
      final Set<int> wallCounts = <int>{};

      while (s.runner.status == StageStatus.fighting) {
        arenaIds.add(s.runner.room.arena.id);
        wallCounts.add(s.world.arena.wallCount);

        expect(
          s.world.arena.wallCount,
          s.runner.room.arena.walls.length,
          reason: 'the world is using another room\'s geometry',
        );

        // Skip to the next room by killing everything.
        final int before = s.runner.roomIndex;
        while (s.runner.roomIndex == before &&
            s.runner.status == StageStatus.fighting) {
          _killAll(s.world);
          s.world.tick(InputSnapshot());
          s.world.events.clear();
          s.runner.update();
        }
      }

      expect(arenaIds.length, greaterThan(1),
          reason: 'the stage reused one arena');
    });

    test('health carries between rooms', () {
      // A run is a descent, not a series of unrelated fights. Healing between
      // rooms would delete the pressure the Shrine's push-or-bank decision
      // depends on.
      final ({StageRunner runner, SimWorld world}) s = stage(seed: 12);

      final int p = s.world.player.index;
      s.world.entities.health[p] = 41.0;

      final int before = s.runner.roomIndex;
      while (s.runner.roomIndex == before &&
          s.runner.status == StageStatus.fighting) {
        _killAll(s.world);
        s.world.tick(InputSnapshot());
        s.world.events.clear();
        s.runner.update();
      }

      expect(s.runner.roomIndex, before + 1);
      expect(
        s.world.entities.health[s.world.player.index],
        closeTo(41.0, 1e-9),
      );
    });

    test('a death ends the stage and still banks gold', () {
      final ({StageRunner runner, SimWorld world}) s = stage(seed: 31);

      // Clear one room so there is partial credit to bank.
      final int before = s.runner.roomIndex;
      while (s.runner.roomIndex == before &&
          s.runner.status == StageStatus.fighting) {
        _killAll(s.world);
        s.world.tick(InputSnapshot());
        s.world.events.clear();
        s.runner.update();
      }

      s.world.entities.despawn(s.world.player);
      s.runner.update();

      expect(s.runner.status, StageStatus.failed);
      expect(s.runner.roomsCleared, 1);
      // There is no zero-reward run: the 0.7 factor is the entire penalty for
      // dying (docs/14 §14.6).
      expect(s.runner.bankedGold, greaterThan(0));
    });

    test('a stage is a few minutes, not thirty seconds or half an hour', () {
      final ({StageRunner runner, SimWorld world}) s =
          stage(chapter: 6, stage: 10, seed: 5);
      final double seconds = play(s.runner, s.world);

      expect(s.runner.status, StageStatus.complete);
      expect(seconds, greaterThan(45));
      expect(seconds, lessThan(60 * 12));
    });
  });

  group('boss rooms', () {
    /// Skips rooms exactly like the other tests in this file already do —
    /// killing everything and letting `update()` advance — stopping at the
    /// first `RoomKind.boss` slot rather than running the whole stage.
    void advanceToBossRoom(StageRunner runner, SimWorld world) {
      while (runner.room.kind != RoomKind.boss &&
          runner.status == StageStatus.fighting) {
        final int before = runner.roomIndex;
        while (runner.roomIndex == before &&
            runner.status == StageStatus.fighting) {
          _killAll(world);
          world.tick(InputSnapshot());
          world.events.clear();
          runner.update();
        }
      }
    }

    test('chapter 1\'s stage 20 spawns the real Cinder Choir', () {
      final ({StageRunner runner, SimWorld world}) s =
          stage(chapter: 1, stage: 20, seed: 501);
      advanceToBossRoom(s.runner, s.world);

      expect(s.runner.status, StageStatus.fighting);
      expect(s.runner.room.kind, RoomKind.boss);
      expect(s.runner.room.bossArchetype, BossArchetype.cinderChoir);

      final bool spawned = List<int>.generate(s.world.entities.highWater, (i) => i)
          .any((int i) =>
              s.world.entities.alive[i] == 1 && s.world.enemies.bossIndex[i] >= 0);
      expect(spawned, isTrue, reason: 'no Cinder Choir primary found in the room');
    });

    test('chapter 11\'s stage 20 spawns the real Skarn the Unmade', () {
      final ({StageRunner runner, SimWorld world}) s =
          stage(chapter: 11, stage: 20, seed: 504);
      advanceToBossRoom(s.runner, s.world);

      expect(s.runner.status, StageStatus.fighting);
      expect(s.runner.room.kind, RoomKind.boss);
      expect(s.runner.room.bossArchetype, BossArchetype.skarnUnmade);

      final bool spawned = List<int>.generate(s.world.entities.highWater, (i) => i)
          .any((int i) =>
              s.world.entities.alive[i] == 1 && s.world.enemies.bossIndex[i] >= 0);
      expect(spawned, isTrue, reason: 'no Skarn primary found in the room');
    });

    test('chapter 2\'s stage 20 spawns the real Gaunt, the Iron Tide', () {
      final ({StageRunner runner, SimWorld world}) s =
          stage(chapter: 2, stage: 20, seed: 505);
      advanceToBossRoom(s.runner, s.world);

      expect(s.runner.status, StageStatus.fighting);
      expect(s.runner.room.kind, RoomKind.boss);
      expect(s.runner.room.bossArchetype, BossArchetype.gauntIronTide);

      final bool spawned = List<int>.generate(s.world.entities.highWater, (i) => i)
          .any((int i) =>
              s.world.entities.alive[i] == 1 && s.world.enemies.bossIndex[i] >= 0);
      expect(spawned, isTrue, reason: 'no Gaunt primary found in the room');
    });

    test('chapter 3\'s stage 20 spawns the real Silversong', () {
      final ({StageRunner runner, SimWorld world}) s =
          stage(stage: 20, seed: 506);
      advanceToBossRoom(s.runner, s.world);

      expect(s.runner.status, StageStatus.fighting);
      expect(s.runner.room.kind, RoomKind.boss);
      expect(s.runner.room.bossArchetype, BossArchetype.silversong);

      final bool spawned = List<int>.generate(s.world.entities.highWater, (i) => i)
          .any((int i) =>
              s.world.entities.alive[i] == 1 && s.world.enemies.bossIndex[i] >= 0);
      expect(spawned, isTrue, reason: 'no Silversong primary found in the room');
    });

    test('chapter 5\'s stage 20 spawns the real Vermillion', () {
      final ({StageRunner runner, SimWorld world}) s =
          stage(chapter: 5, stage: 20, seed: 507);
      advanceToBossRoom(s.runner, s.world);

      expect(s.runner.status, StageStatus.fighting);
      expect(s.runner.room.kind, RoomKind.boss);
      expect(s.runner.room.bossArchetype, BossArchetype.vermillion);

      final bool spawned = List<int>.generate(s.world.entities.highWater, (i) => i)
          .any((int i) =>
              s.world.entities.alive[i] == 1 && s.world.enemies.bossIndex[i] >= 0);
      expect(spawned, isTrue, reason: 'no Vermillion primary found in the room');
    });

    test('chapter 6\'s stage 20 spawns the real Rimefather', () {
      final ({StageRunner runner, SimWorld world}) s =
          stage(chapter: 6, stage: 20, seed: 508);
      advanceToBossRoom(s.runner, s.world);

      expect(s.runner.status, StageStatus.fighting);
      expect(s.runner.room.kind, RoomKind.boss);
      expect(s.runner.room.bossArchetype, BossArchetype.rimefather);

      final bool spawned = List<int>.generate(s.world.entities.highWater, (i) => i)
          .any((int i) =>
              s.world.entities.alive[i] == 1 && s.world.enemies.bossIndex[i] >= 0);
      expect(spawned, isTrue, reason: 'no Rimefather primary found in the room');
    });

    test('the boss room does not clear until the boss actually dies', () {
      final ({StageRunner runner, SimWorld world}) s =
          stage(chapter: 1, stage: 20, seed: 502);
      advanceToBossRoom(s.runner, s.world);
      final int bossRoomIndex = s.runner.roomIndex;

      // Ticking alone, with the boss untouched, must not clear the room —
      // unlike every other room in this file, there is no wave plan feeding
      // `SpawnState`, only the boss's own live entities.
      for (int i = 0; i < 60; i++) {
        s.world.tick(InputSnapshot());
      }
      s.world.events.clear();
      s.runner.update();
      expect(s.runner.roomIndex, bossRoomIndex);
      expect(s.runner.status, StageStatus.fighting);

      _killAll(s.world);
      s.world.tick(InputSnapshot());
      s.world.events.clear();
      s.runner.update();

      // Chapter 1's boss room is its stage's last room.
      expect(s.runner.status, StageStatus.complete);
    });

    test('a chapter whose boss is not built yet still composes an ordinary room',
        () {
      // Chapters 1, 2, 3, 5, 6 and 11 have fights built — see
      // `BossRoomComposer.bossFor`. Chapter 4's own stage 20 must still be
      // playable, exactly like a Shrine slot is ahead of Phase 13.
      final ({StageRunner runner, SimWorld world}) s =
          stage(chapter: 4, stage: 20, seed: 503);
      advanceToBossRoom(s.runner, s.world);

      expect(s.runner.room.kind, RoomKind.boss);
      expect(s.runner.room.bossArchetype, isNull);
      expect(s.runner.room.enemyCount, greaterThan(0));
    });
  });
}

void _killAll(SimWorld world) {
  for (int i = 0; i < world.entities.highWater; i++) {
    if (world.entities.alive[i] == 0) continue;
    if (world.entities.kind[i] != EntityKind.enemy.index) continue;
    world.entities.health[i] = 0;
  }
}

double _hypot(double x, double y) {
  final double sq = x * x + y * y;
  if (sq <= 0) return 0;
  double g = sq > 1 ? sq : 1.0;
  for (int i = 0; i < 24; i++) {
    g = 0.5 * (g + sq / g);
  }
  return g;
}
