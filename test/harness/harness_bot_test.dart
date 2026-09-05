import 'dart:io';

import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/harness/harness_bot.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:test/test.dart';

/// The "average Boon draw" half of Phase 12's harness (ADR 0091).
void main() {
  late HeroCatalogue heroes;
  late ArrowCatalogue arrows;
  late ContentLibrary content;
  late BoonCatalogue boons;
  late SynergyCatalogue synergies;

  setUpAll(() {
    heroes =
        HeroCatalogue.parse(File('assets/data/heroes.json').readAsStringSync())
            .$1!;
    arrows = ArrowCatalogue.parse(
            File('assets/data/arrows.json').readAsStringSync())
        .$1!;
    content = ContentLibrary.parse(
      enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
      arenasJson: File('assets/data/arenas.json').readAsStringSync(),
    ).$1!;
    boons =
        BoonCatalogue.parse(File('assets/data/boons.json').readAsStringSync())
            .$1!;
    synergies = SynergyCatalogue.parse(
      File('assets/data/synergies.json').readAsStringSync(),
      boons: boons,
    ).$1!;
  });

  ({StageRunner runner, StageBlueprint blueprint}) buildAndApply({
    required int chapter,
    required int stage,
    required int seed,
  }) {
    final StageBlueprint blueprint =
        StageBlueprint.forStage(chapter: chapter, stage: stage, seed: seed);
    final StagePlan plan = generateStage(
      generator: LevelGenerator(content: content, arenas: content.arenas),
      blueprint: blueprint,
    );
    final world =
        buildStageWorld(blueprint: blueprint, content: content, plan: plan);
    final StageRunner runner = StageRunner(
      world: world,
      content: content,
      plan: plan,
      boonCatalogue: boons,
      synergies: synergies,
    )..start();

    final HeroDefinition wren = heroes.byArchetype(HeroArchetype.wren)!;
    final ArrowDefinition ashShaft =
        arrows.byArchetype(ArrowArchetype.ashShaft)!;
    final base = HeroLoadoutResolver.apply(
      world,
      wren,
      const HeroState(heroId: 'wren', level: 40, stars: 3),
      ashShaft,
      const ArrowInstance(arrowId: 'ash_shaft', crafted: true),
    );
    runner.setBaseLoadout(
      baseAttack: base.baseAttack,
      baseFireRateMultiplier: base.baseFireRateMultiplier,
      baseMaxHealth: base.baseMaxHealth,
      baseMoveSpeed: base.baseMoveSpeed,
    );
    return (runner: runner, blueprint: blueprint);
  }

  test('reaches the target room on an easy early chapter, picking real Boons',
      () {
    final s = buildAndApply(chapter: 1, stage: 10, seed: 11);
    HarnessBot.playToRoom(s.runner, s.runner.world, targetRoomIndex: 5);

    expect(s.runner.status, StageStatus.fighting,
        reason: 'chapter 1 at Wren ★3/lvl40 should comfortably reach room 5');
    expect(s.runner.roomIndex, greaterThanOrEqualTo(5));
    expect(s.runner.boons.pickOrder, isNotEmpty,
        reason: 'a 6+ room stage must offer at least one real Boon Choice '
            'before room 5');
  });

  test('never stalls on a Shrine room', () {
    // Chapter 9's own stage 1 is `stage_runner_boons_test.dart`'s own
    // deliberately-chosen Shrine-and-Elite-in-different-rooms stage.
    final s = buildAndApply(chapter: 9, stage: 1, seed: 4242);
    HarnessBot.playToRoom(s.runner, s.runner.world, targetRoomIndex: 5);

    expect(
      s.runner.status,
      isNot(anyOf(StageStatus.awaitingBoonChoice, StageStatus.awaitingShrine)),
      reason: 'the bot must resolve every interstitial it meets, not pause '
          'on one',
    );
  });

  test('is deterministic for a fixed seed', () {
    final s1 = buildAndApply(chapter: 1, stage: 10, seed: 99);
    HarnessBot.playToRoom(s1.runner, s1.runner.world, targetRoomIndex: 4);

    final s2 = buildAndApply(chapter: 1, stage: 10, seed: 99);
    HarnessBot.playToRoom(s2.runner, s2.runner.world, targetRoomIndex: 4);

    expect(s1.runner.roomIndex, s2.runner.roomIndex);
    expect(s1.runner.status, s2.runner.status);
    expect(s1.runner.boons.pickOrder, s2.runner.boons.pickOrder);
    expect(s1.runner.world.playerAttack, s2.runner.world.playerAttack);
  });

  test('returns promptly once the target room is already reached', () {
    // targetRoomIndex 0 is satisfied before the very first tick — this
    // must not spend any of the (large) maxSeconds budget.
    final s = buildAndApply(chapter: 1, stage: 10, seed: 1);
    final stopwatch = Stopwatch()..start();
    HarnessBot.playToRoom(s.runner, s.runner.world, targetRoomIndex: 0);
    stopwatch.stop();

    expect(s.runner.roomIndex, 0);
    expect(stopwatch.elapsedMilliseconds, lessThan(1000));
  });
}
