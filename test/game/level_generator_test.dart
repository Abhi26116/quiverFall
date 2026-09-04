import 'dart:io';

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/clear_time.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/level/arena_definition.dart';
import 'package:quiverfall/game/level/blueprint_validator.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/room_blueprint.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/spawn/composition_validator.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';
import 'package:test/test.dart';

/// The Phase 8 exit criterion, and the rules that make it meaningful.
///
/// > Generator produces 10,000 valid blueprints with zero constraint violations
/// > and zero fallbacks in normal conditions.
///
/// The fallback half matters as much as the violation half. A generator that
/// reached its fallback constantly would *also* produce zero violations — and
/// would be shipping the same conservative room over and over.
void main() {
  late ContentLibrary content;
  late ContentLibrary bossContent;

  setUpAll(() {
    content = ContentLibrary.parse(
      enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
      arenasJson: File('assets/data/arenas.json').readAsStringSync(),
    ).$1!;
    bossContent = ContentLibrary.parse(
      enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
      arenasJson: File('assets/data/arenas.json').readAsStringSync(),
      bossesJson: File('assets/data/bosses.json').readAsStringSync(),
    ).$1!;
  });

  LevelGenerator generator() =>
      LevelGenerator(content: content, arenas: content.arenas);

  group('the authored arenas', () {
    test('load, and there are 20 of them', () {
      expect(content.arenas, hasLength(20));
    });

    test('every chapter has at least four arenas to draw from', () {
      // docs/14 §14.1 distributes 4-6 per chapter. Fewer means visible
      // repetition inside a single stage.
      for (int chapter = 1; chapter <= 12; chapter++) {
        expect(
          content.arenasForChapter(chapter).length,
          greaterThanOrEqualTo(4),
          reason: 'chapter $chapter is short of arenas',
        );
      }
    });

    test('every family has somewhere legal to stand in every arena', () {
      // Otherwise a room that draws that family is unplaceable, and the
      // generator burns all eight attempts discovering it.
      for (final ArenaDefinition arena in content.arenas) {
        for (final EnemyFamily family in EnemyFamily.values) {
          expect(
            arena.pointsFor(family),
            isNotEmpty,
            reason: '${arena.id} has no point accepting ${family.name}',
          );
        }
      }
    });

    test('enough arenas carry lattice hints to bias toward', () {
      // The bias from chapter 5 is meaningless if almost nothing qualifies.
      final int withHints =
          content.arenas.where((ArenaDefinition a) => a.hasLatticeHints).length;
      expect(withHints, greaterThanOrEqualTo(8));
    });

    test('a bad arena fails the load rather than a player', () {
      // A spawn point on top of the player start is unavoidable damage. It must
      // be impossible to ship, not merely unlikely to be drawn.
      const String broken = '''
      {"arenas": [{
        "id": "bad", "tags": ["open"], "chapters": [1],
        "playerStart": {"x": 8.0, "y": 4.5},
        "spawnPoints": [
          {"x": 8.5, "y": 4.5, "kind": "edge", "families": ["drift"]}
        ]
      }]}
      ''';

      final List<ContentError> errors = ContentLibrary.parse(
        enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
        arenasJson: broken,
      ).$2;

      expect(errors, isNotEmpty);
      expect(
        errors.any((ContentError e) => e.message.contains('player start')),
        isTrue,
      );
    });
  });

  group('the stage template', () {
    test('matches docs/14 §14.2', () {
      expect(StageBlueprint.roomCount(1), 6);
      expect(StageBlueprint.roomCount(3), 7);
      expect(StageBlueprint.roomCount(12), 10);
    });

    test('elites appear from chapter 3, shrines from chapter 2', () {
      final StageBlueprint ch1 =
          StageBlueprint.forStage(chapter: 1, stage: 1, seed: 1);
      expect(ch1.rooms.any((RoomSlot r) => r.kind == RoomKind.elite), isFalse);
      expect(ch1.rooms.any((RoomSlot r) => r.kind == RoomKind.shrine), isFalse);

      final StageBlueprint ch2 =
          StageBlueprint.forStage(chapter: 2, stage: 1, seed: 1);
      expect(ch2.rooms.any((RoomSlot r) => r.kind == RoomKind.shrine), isTrue);
      expect(ch2.rooms.any((RoomSlot r) => r.kind == RoomKind.elite), isFalse);

      final StageBlueprint ch3 =
          StageBlueprint.forStage(chapter: 3, stage: 1, seed: 1);
      expect(ch3.rooms.any((RoomSlot r) => r.kind == RoomKind.elite), isTrue);
    });

    test('a boss replaces the last room of stage 20, and only stage 20', () {
      expect(
        StageBlueprint.forStage(chapter: 1, stage: 20, seed: 1).hasBoss,
        isTrue,
      );
      expect(
        StageBlueprint.forStage(chapter: 1, stage: 19, seed: 1).hasBoss,
        isFalse,
      );

      // Replaces rather than appends, so every other room's gold share and the
      // stage's Vigor cost stay consistent across stages.
      expect(
        StageBlueprint.forStage(chapter: 1, stage: 20, seed: 1).roomTotal,
        StageBlueprint.roomCount(1),
      );
    });

    test('a retry is a different stage, but a repeat of it is identical', () {
      // The reason attemptSalt exists: replaying an identical failed room is
      // demoralising, replaying a fresh version of the same challenge is a
      // second chance.
      final int first = StageBlueprint.seedFor(
        playerId: 'abc',
        chapter: 4,
        stage: 7,
        attemptSalt: 0,
      );
      final int retry = StageBlueprint.seedFor(
        playerId: 'abc',
        chapter: 4,
        stage: 7,
        attemptSalt: 1,
      );
      final int again = StageBlueprint.seedFor(
        playerId: 'abc',
        chapter: 4,
        stage: 7,
        attemptSalt: 0,
      );

      expect(first, isNot(retry));
      expect(first, again);
    });

    test('two players on the same stage get different rooms', () {
      expect(
        StageBlueprint.seedFor(
          playerId: 'player-one',
          chapter: 3,
          stage: 3,
          attemptSalt: 0,
        ),
        isNot(
          StageBlueprint.seedFor(
            playerId: 'player-two',
            chapter: 3,
            stage: 3,
            attemptSalt: 0,
          ),
        ),
      );
    });
  });

  group('generated rooms', () {
    test('10,000 blueprints, zero violations, zero fallbacks', () {
      final LevelGenerator gen = generator();
      final Rng rng = Rng(20260720);

      final List<String> failures = <String>[];
      int fallbacks = 0;
      int extraAttempts = 0;

      for (int i = 0; i < 10000; i++) {
        final int chapter = 1 + i % 12;
        final int stage = 1 + i % 20;
        final int globalStage = (chapter - 1) * 20 + stage;
        final RoomKind kind =
            i % 9 == 0 && chapter >= 3 ? RoomKind.elite : RoomKind.normal;

        final RoomBlueprint room = gen.generate(
          rng: rng,
          slot: RoomSlot(index: i % 7, kind: kind),
          chapter: chapter,
          globalStage: globalStage,
        );

        if (room.usedFallback) fallbacks++;
        extraAttempts += room.attempts - 1;

        final List<CompositionViolation> violations =
            BlueprintValidator.validate(room, content);
        if (violations.isNotEmpty) {
          failures.add('ch$chapter s$stage ${room.arena.id}: $violations');
        }
      }

      expect(failures, isEmpty, reason: failures.take(5).join('\n'));
      expect(
        fallbacks,
        0,
        reason: 'the generator fell back $fallbacks times; the fallback is a '
            'safety net, not a code path',
      );
      // A generator needing many rerolls is one whose composer and validator
      // disagree about what a good room is.
      expect(
        extraAttempts / 10000,
        lessThan(0.5),
        reason: 'rerolled ${extraAttempts / 10000} times per room on average',
      );
    });

    test('every enemy lands on a point its family may use', () {
      final LevelGenerator gen = generator();
      final Rng rng = Rng(5);

      for (int i = 0; i < 400; i++) {
        final int chapter = 1 + i % 12;
        final RoomBlueprint room = gen.generate(
          rng: rng,
          slot: const RoomSlot(index: 0, kind: RoomKind.normal),
          chapter: chapter,
          globalStage: (chapter - 1) * 20 + 5,
        );

        for (final PlannedEnemy enemy in room.enemies) {
          expect(enemy.isPlaced, isTrue);
          final EnemyFamily family = enemy.definitionIn(content).family;
          // Jitter means the placement will not sit exactly on the authored
          // point, so this asks the weaker, real question: was there a legal
          // point nearby for this family?
          final bool nearLegal =
              room.arena.pointsFor(family).any((SpawnPoint p) {
            final double dx = p.x - enemy.spawnX!;
            final double dy = p.y - enemy.spawnY!;
            return dx * dx + dy * dy <= 1.0;
          });
          expect(
            nearLegal,
            isTrue,
            reason: '${family.name} placed away from any legal point in '
                '${room.arena.id}',
          );
        }
      }
    });

    test('clear-time estimates land in the documented band', () {
      final LevelGenerator gen = generator();
      final Rng rng = Rng(11);

      for (int chapter = 1; chapter <= 12; chapter++) {
        for (int i = 0; i < 40; i++) {
          final RoomBlueprint room = gen.generate(
            rng: rng,
            slot: const RoomSlot(index: 0, kind: RoomKind.normal),
            chapter: chapter,
            globalStage: (chapter - 1) * 20 + 10,
          );
          expect(
            ClearTimeModel.isWithinBand(room.estimatedSeconds),
            isTrue,
            reason: 'ch$chapter: ${room.estimatedSeconds}s',
          );
        }
      }
    });

    test('the same arena is not drawn twice in a row', () {
      final LevelGenerator gen = generator();
      final Rng rng = Rng(3);

      String? previous;
      for (int i = 0; i < 200; i++) {
        final RoomBlueprint room = gen.generate(
          rng: rng,
          slot: const RoomSlot(index: 0, kind: RoomKind.normal),
          chapter: 6,
          globalStage: 110,
        );
        expect(room.arena.id, isNot(previous));
        previous = room.arena.id;
      }
    });

    test('lattice geometry is favoured from chapter 5', () {
      int hintsAt(int chapter) {
        final LevelGenerator gen = generator();
        final Rng rng = Rng(97);
        int withHints = 0;
        for (int i = 0; i < 300; i++) {
          final RoomBlueprint room = gen.generate(
            rng: rng,
            slot: const RoomSlot(index: 0, kind: RoomKind.normal),
            chapter: chapter,
            globalStage: (chapter - 1) * 20 + 10,
          );
          if (room.arena.hasLatticeHints) withHints++;
        }
        return withHints;
      }

      // Chapters 4 and 6 have comparable arena pools, so the difference is the
      // bias rather than the content.
      expect(hintsAt(6), greaterThan(hintsAt(4)));
    });
  });

  group('whole stages', () {
    test('a full stage generates cleanly, end to end', () {
      final StageBlueprint blueprint = StageBlueprint.forStage(
        chapter: 4,
        stage: 7,
        seed: StageBlueprint.seedFor(
          playerId: 'test-player',
          chapter: 4,
          stage: 7,
          attemptSalt: 0,
        ),
      );

      final StagePlan plan = generateStage(
        generator: generator(),
        blueprint: blueprint,
      );

      expect(plan.roomCount, StageBlueprint.roomCount(4));
      expect(plan.usedAnyFallback, isFalse);
      expect(plan.validate(content), isEmpty);

      // A stage should be a few minutes of fighting, not thirty seconds and not
      // half an hour.
      expect(plan.totalEstimatedSeconds, greaterThan(60));
      expect(plan.totalEstimatedSeconds, lessThan(60 * 8));
    });

    test('the same seed regenerates the same stage', () {
      StagePlan build() => generateStage(
            generator: generator(),
            blueprint: StageBlueprint.forStage(
              chapter: 7,
              stage: 12,
              seed: 4242,
            ),
          );

      final StagePlan a = build();
      final StagePlan b = build();

      expect(a.roomCount, b.roomCount);
      for (int i = 0; i < a.roomCount; i++) {
        expect(a.rooms[i].arena.id, b.rooms[i].arena.id);
        expect(a.rooms[i].enemyCount, b.rooms[i].enemyCount);
        expect(
          a.rooms[i].estimatedSeconds,
          b.rooms[i].estimatedSeconds,
        );
      }
    });

    test('every chapter produces a clean stage', () {
      for (int chapter = 1; chapter <= 12; chapter++) {
        final StagePlan plan = generateStage(
          generator: generator(),
          blueprint: StageBlueprint.forStage(
            chapter: chapter,
            stage: 20,
            seed: 1000 + chapter,
          ),
        );
        expect(
          plan.validate(content),
          isEmpty,
          reason: 'chapter $chapter stage 20',
        );
        expect(plan.usedAnyFallback, isFalse, reason: 'chapter $chapter');
      }
    });
  });

  group('boss rooms', () {
    LevelGenerator bossGenerator() =>
        LevelGenerator(content: bossContent, arenas: bossContent.arenas);

    RoomBlueprint bossSlot(int chapter) => bossGenerator().generate(
          rng: Rng(1),
          slot: const RoomSlot(index: 0, kind: RoomKind.boss),
          chapter: chapter,
          globalStage: StageBlueprint.forStage(
            chapter: chapter,
            stage: 20,
            seed: 1,
          ).globalStage,
        );

    test('chapter 1 spawns no ordinary composition — Cinder Choir instead',
        () {
      final RoomBlueprint room = bossSlot(1);

      expect(room.bossArchetype, BossArchetype.cinderChoir);
      expect(room.enemyCount, 0);
      // docs/06 §1: "55 s".
      expect(room.estimatedSeconds, 55);
      expect(BlueprintValidator.validate(room, bossContent), isEmpty);
    });

    test('a chapter with no fight built yet still composes an ordinary room',
        () {
      final RoomBlueprint room = bossSlot(4);

      expect(room.bossArchetype, isNull);
      expect(room.enemyCount, greaterThan(0));
      expect(BlueprintValidator.validate(room, bossContent), isEmpty);
    });

    test('a chapter 1 stage 20 stage generates cleanly end to end', () {
      final StagePlan plan = generateStage(
        generator: bossGenerator(),
        blueprint: StageBlueprint.forStage(chapter: 1, stage: 20, seed: 2024),
      );

      expect(plan.validate(bossContent), isEmpty);
      expect(plan.usedAnyFallback, isFalse);
      expect(plan.rooms.last.kind, RoomKind.boss);
      expect(plan.rooms.last.bossArchetype, BossArchetype.cinderChoir);
    });
  });
}
