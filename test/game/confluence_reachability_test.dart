import 'dart:math' as math;

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spawn/room_composer.dart';
import 'package:test/test.dart';

import 'enemy_test_support.dart';

/// ADR 0002 — Confluence reachability.
///
/// Confluence was implemented correctly in Phase 4 and measured at a **0 %**
/// natural trigger rate. Two things fixed it: Phase 5's enemies, which move and
/// die and so fan the player's fire, and the terminal Windline stub, which
/// stopped every trail ending 0–0.9 u short of whatever the arrow hit.
///
/// This file is the floor those two facts sit on. It guards **both** failure
/// modes the ADR names, because they are opposite and the fix for one is the
/// cause of the other:
///
///  - **Unreachable.** The USP cannot fire, so nobody ever sees it.
///  - **Degenerate.** It fires on nearly every shot, which makes it a flat
///    damage buff with extra steps that teaches players nothing.
///
/// Numbers here are floors and ceilings with real headroom, not the measured
/// values. They are meant to catch a regression, not to freeze tuning — Phase 6
/// is expected to move the middle of this band.
void main() {
  late ContentLibrary content;

  setUpAll(() {
    content = loadEnemies();
  });

  /// Runs a real composed room and reports how many arrows threaded a trail.
  ({int shots, int threaded, double? firstAt}) probe({
    required int chapter,
    required int stage,
    required double Function(double t) inputX,
    required double Function(double t) inputY,
    double seconds = 60.0,
    int seed = 90210,
  }) {
    final SimWorld world = SimWorld(seed: seed, content: content);
    final int player = world.spawnPlayer(4.0, 4.5).index;

    void arm(int roomSeed) {
      // Design Law 1: a common enemy dies in 0.8-1.6 s for a
      // correctly-progressed player, which is two Tier-III arrows.
      world
        ..enemyHpBase = Curves.enemyHp(stage)
        ..playerAttack = Curves.enemyHp(stage) / (2.10 * 2);
      world.beginRoom(
        RoomComposer.compose(
          content: content,
          rng: Rng(roomSeed),
          chapter: chapter,
          globalStage: stage,
        ),
      );
    }

    arm(seed);

    final InputSnapshot input = InputSnapshot();
    int shots = 0;
    int threaded = 0;
    double? firstAt;

    final int ticks = (seconds * 60).round();
    for (int tick = 0; tick < ticks; tick++) {
      // Contact damage is a fraction of max HP, so a big pool would not make
      // the player survive — topping up each tick does.
      world.entities.health[player] = world.entities.maxHealth[player];

      final double t = tick * SimConfig.fixedStep;
      input.set(inputX(t), inputY(t));
      world.tick(input);

      for (int i = 0; i < world.events.count; i++) {
        switch (world.events.typeAt(i)) {
          case SimEventType.arrowFired:
            shots++;
          case SimEventType.confluenceTriggered:
            // The event fires per stack gained; the zero-to-one transitions
            // count arrows rather than stacks.
            if (world.events.valueAAt(i).round() == 1) {
              threaded++;
              firstAt ??= t;
            }
          default:
            break;
        }
      }
      world.events.clear();

      if (world.spawnState.roomClearedEmitted) arm(seed + tick);
    }

    return (shots: shots, threaded: threaded, firstAt: firstAt);
  }

  group('the trail reaches what the arrow hit', () {
    test('an arrow lays its final stretch when it dies', () {
      // Windline segments are emitted per 0.9 u flown. Without a terminal stub
      // the last 0-0.9 u of every trail is never emitted — and that stretch,
      // nearest the target, is exactly where converging fire meets.
      final SimWorld world = SimWorld(seed: 1, content: content)
        ..autoFire = true
        ..playerAttack = 1e6;
      world.spawnPlayer(2.0, 4.5);
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 9.0, 4.5);

      // A Mote walks toward the player, so it dies somewhere left of where it
      // spawned. The assertion has to be "the trail reached the target", not
      // "the trail reached x = 9" — the latter passed only by accident while
      // arrows were travelling at double speed.
      double diedAtX = 0;
      for (int i = 0; i < 120; i++) {
        final double before = world.entities.posX[mote];
        world.tick(InputSnapshot());
        if (world.events.countOf(SimEventType.entityDied) > 0) {
          diedAtX = before;
          break;
        }
      }
      expect(diedAtX, greaterThan(0), reason: 'nothing died');

      double furthest = 0;
      for (int i = 0; i < world.windlines.capacity; i++) {
        if (!world.windlines.isAlive(i)) continue;
        furthest = math.max(furthest, world.windlines.x1(i));
        furthest = math.max(furthest, world.windlines.x0(i));
      }

      // The trail must run to the enemy, not stop a segment-length short of it.
      expect(
        furthest,
        greaterThan(diedAtX - SimConfig.windlineSegmentLength * 0.5),
        reason: 'the trail stopped short of the target it killed '
            '(died at $diedAtX, trail reached $furthest)',
      );
    });

    test('an arrow stopped by a wall leaves its trail outside the wall', () {
      final SimWorld world = SimWorld(
        seed: 1,
        content: content,
        arena: Arena.standard(
          walls: const <Rect>[Rect(9.0, 0.0, 10.0, 9.0)],
        ),
      )..autoFire = true;
      world.spawnPlayer(2.0, 4.5);
      // A target beyond the wall, so every arrow flies into it.
      world.spawnEnemy(EnemyArchetype.mote, 14.0, 4.5);
      world.enemies.speedScale[0] = 0;

      for (int i = 0; i < 180; i++) {
        world.tick(InputSnapshot());
      }

      for (int i = 0; i < world.windlines.capacity; i++) {
        if (!world.windlines.isAlive(i)) continue;
        expect(
          world.windlines.x1(i),
          lessThanOrEqualTo(9.2),
          reason: 'a trail stub was laid inside a wall',
        );
      }
    });
  });

  group('reachable', () {
    test('a moving player threads their own trails in a chapter-1 room', () {
      final ({int shots, int threaded, double? firstAt}) result = probe(
        chapter: 1,
        stage: 1,
        inputX: (double t) => math.cos(t * 1.1),
        inputY: (double t) => math.sin(t * 1.1),
      );

      expect(result.shots, greaterThan(60), reason: 'the probe barely fired');
      expect(
        result.threaded,
        greaterThanOrEqualTo(5),
        reason: 'ADR 0002: the USP must be reachable from the base kit',
      );
      expect(
        result.firstAt,
        isNotNull,
        reason: 'a full minute of circling never produced one Confluence',
      );
      // docs/03 §3.1 beat 6:00 expects a first Confluence to fire accidentally
      // by ~7 minutes of play. A minute of ordinary movement is a hard floor on
      // that, with two orders of magnitude to spare.
      expect(result.firstAt, lessThan(30.0));
    });

    test('it still works deep in the campaign', () {
      final ({int shots, int threaded, double? firstAt}) result = probe(
        chapter: 8,
        stage: 160,
        inputX: (double t) => math.cos(t * 1.1),
        inputY: (double t) => math.sin(t * 1.1),
      );
      expect(result.threaded, greaterThanOrEqualTo(4));
    });
  });

  group('not degenerate', () {
    test('rooting on a single target never threads anything', () {
      // Standing still buys Tier III, not Confluence. Every arrow retraces one
      // line, and retracing a line is not threading it — this is the 96 %
      // failure mode the angle rule exists to prevent, and it must stay closed.
      final SimWorld world = SimWorld(seed: 7, content: content)
        ..autoFire = true
        ..enemyHpBase = 1e9
        ..playerAttack = 1;
      world.spawnPlayer(4.0, 4.5);
      world.spawnEnemy(EnemyArchetype.bulwark, 12.0, 4.5);

      final InputSnapshot idle = InputSnapshot();
      for (int i = 0; i < 60 * 30; i++) {
        world.tick(idle);
      }

      expect(
        world.events.countOf(SimEventType.confluenceTriggered),
        0,
        reason: 'retracing a line must never count as threading it',
      );
    });

    test('a circling player is far from threading every shot', () {
      final ({int shots, int threaded, double? firstAt}) result = probe(
        chapter: 4,
        stage: 70,
        inputX: (double t) => math.cos(t * 1.1),
        inputY: (double t) => math.sin(t * 1.1),
      );

      // A mechanic that fires by default is a flat damage buff with extra
      // steps. The ceiling is deliberately loose — Phase 6 may well raise the
      // rate — but it must stay a long way from "always".
      expect(
        result.threaded / result.shots,
        lessThan(0.40),
        reason: 'Confluence is becoming a constant rather than a skill',
      );
    });
  });
}
