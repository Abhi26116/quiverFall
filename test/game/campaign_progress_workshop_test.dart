import 'dart:io';

import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/campaign/campaign_progress_workshop.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

/// `GameScreen`'s own gap — nothing calls anything like this today. See
/// ADR 0096.
void main() {
  late ContentLibrary content;
  final DateTime now = DateTime.utc(2026, 3);

  setUpAll(() {
    content = ContentLibrary.parse(
      enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
      arenasJson: File('assets/data/arenas.json').readAsStringSync(),
    ).$1!;
  });

  void killAll(SimWorld world) {
    for (int i = 0; i < world.entities.highWater; i++) {
      if (world.entities.alive[i] == 0) continue;
      if (world.entities.kind[i] != EntityKind.enemy.index) continue;
      world.entities.health[i] = 0;
    }
  }

  /// Plays [chapter]/[stage] to completion (killing every room instantly).
  StageRunner completeStage({
    required int chapter,
    required int stage,
    int seed = 4242,
  }) {
    final StageBlueprint blueprint =
        StageBlueprint.forStage(chapter: chapter, stage: stage, seed: seed);
    final StagePlan plan = generateStage(
      generator: LevelGenerator(content: content, arenas: content.arenas),
      blueprint: blueprint,
    );
    final SimWorld world =
        buildStageWorld(blueprint: blueprint, content: content, plan: plan);
    final StageRunner runner =
        StageRunner(world: world, content: content, plan: plan)..start();

    for (int guard = 0; guard < 20000; guard++) {
      if (runner.status == StageStatus.complete) break;
      if (world.entities.isAlive(world.player)) {
        final int p = world.player.index;
        world.entities.health[p] = world.entities.maxHealth[p];
      }
      killAll(world);
      world.tick(InputSnapshot());
      world.events.clear();
      runner.update();
    }
    expect(runner.status, StageStatus.complete,
        reason: 'stage never completed — test setup is wrong, not the '
            'workshop');
    return runner;
  }

  /// Plays [chapter]/[stage] until the player dies, one room short of a
  /// full clear (never kills the enemies in the *last* room).
  StageRunner failStage({
    required int chapter,
    required int stage,
    int seed = 4242,
  }) {
    final StageBlueprint blueprint =
        StageBlueprint.forStage(chapter: chapter, stage: stage, seed: seed);
    final StagePlan plan = generateStage(
      generator: LevelGenerator(content: content, arenas: content.arenas),
      blueprint: blueprint,
    );
    final SimWorld world =
        buildStageWorld(blueprint: blueprint, content: content, plan: plan);
    final StageRunner runner =
        StageRunner(world: world, content: content, plan: plan)..start();

    // Clear every room but the last, then let the player die.
    while (runner.roomIndex < runner.roomTotal - 1 &&
        runner.status == StageStatus.fighting) {
      killAll(world);
      world.tick(InputSnapshot());
      world.events.clear();
      runner.update();
    }
    world.entities.despawn(world.player);
    runner.update();

    expect(runner.status, StageStatus.failed,
        reason: 'stage never failed — test setup is wrong, not the '
            'workshop');
    return runner;
  }

  PlayerSave freshSave({int currentChapter = 1, int currentStage = 1}) =>
      PlayerSave.initial(playerId: 'p1', now: now).copyWith(
        campaign:
            CampaignState(currentChapter: currentChapter, currentStage: currentStage),
      );

  test('a full clear pays the exact full-clear gold, not the death formula',
      () {
    final runner = completeStage(chapter: 1, stage: 1);
    final save = freshSave();
    final updated = CampaignProgressWorkshop.apply(save, runner);

    expect(updated.wallet.gold, runner.finalGold.round());
    // The death formula's own 0.7 factor would read strictly lower — this
    // is the exact bug docs/14's own "0.7 is the entire penalty for dying"
    // line rules out for a genuine clear.
    expect(runner.finalGold, greaterThan(runner.bankedGold));
  });

  test('advances to the next stage within the same chapter', () {
    final runner = completeStage(chapter: 1, stage: 5);
    final updated = CampaignProgressWorkshop.apply(
      freshSave(currentStage: 5),
      runner,
    );
    expect(updated.campaign.currentChapter, 1);
    expect(updated.campaign.currentStage, 6);
  });

  test('advances to the next chapter after the chapter\'s own last stage',
      () {
    final runner =
        completeStage(chapter: 1, stage: StageBlueprint.stagesPerChapter);
    final updated = CampaignProgressWorkshop.apply(
      freshSave(currentStage: StageBlueprint.stagesPerChapter),
      runner,
    );
    expect(updated.campaign.currentChapter, 2);
    expect(updated.campaign.currentStage, 1);
  });

  test('clamps at the campaign\'s own last stage rather than inventing '
      'chapter 13', () {
    final runner =
        completeStage(chapter: 12, stage: StageBlueprint.stagesPerChapter);
    final updated = CampaignProgressWorkshop.apply(
      freshSave(currentChapter: 12, currentStage: StageBlueprint.stagesPerChapter),
      runner,
    );
    expect(updated.campaign.currentChapter, 12);
    expect(updated.campaign.currentStage, StageBlueprint.stagesPerChapter);
  });

  test('replaying an already-cleared stage pays gold but does not move '
      'campaign position', () {
    final runner = completeStage(chapter: 1, stage: 1);
    // The save's own frontier is already well past this stage.
    final updated = CampaignProgressWorkshop.apply(
      freshSave(currentChapter: 3, currentStage: 4),
      runner,
    );
    expect(updated.campaign.currentChapter, 3);
    expect(updated.campaign.currentStage, 4);
    expect(updated.wallet.gold, greaterThan(0));
  });

  test('a failed run pays bankedGold\'s own partial-credit formula and '
      'does not advance', () {
    final runner = failStage(chapter: 1, stage: 3);
    final updated = CampaignProgressWorkshop.apply(
      freshSave(currentStage: 3),
      runner,
    );
    expect(updated.wallet.gold, runner.bankedGold.round());
    expect(updated.campaign.currentChapter, 1);
    expect(updated.campaign.currentStage, 3);
  });

  test('there is no zero-reward run, even on a failure', () {
    final runner = failStage(chapter: 1, stage: 3);
    expect(runner.finalGold, greaterThan(0));
  });

  test('highestChapterEver rises to meet real progress', () {
    final runner = completeStage(chapter: 5, stage: 1);
    final updated = CampaignProgressWorkshop.apply(
      freshSave(currentChapter: 5),
      runner,
    );
    expect(updated.ascension.highestChapterEver, 5);
  });

  test('highestChapterEver never regresses below an earlier peak', () {
    final runner = completeStage(chapter: 2, stage: 1);
    final save = freshSave(currentChapter: 2).copyWith(
      ascension: const AscensionState(highestChapterEver: 9),
    );
    final updated = CampaignProgressWorkshop.apply(save, runner);
    expect(updated.ascension.highestChapterEver, 9);
  });
}
