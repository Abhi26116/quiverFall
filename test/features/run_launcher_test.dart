import 'package:quiverfall/core/routing/route_guards.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:quiverfall/features/gameplay/application/run_launcher.dart';
import 'package:quiverfall/game/balance/curves.dart' as balance;
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:test/test.dart';

import '../game/hero_test_support.dart';
import 'repository_test_support.dart';

/// docs/11-screen-flow.md §11.1: the one claim-a-run routine shared by the
/// Loadout Sheet and the Menu's own DESCEND button.
void main() {
  late HeroCatalogue heroes;

  setUpAll(() {
    heroes = loadHeroes();
  });

  PlayerSave startingSave() =>
      PlayerSave.initial(playerId: 'p1', now: DateTime.utc(2026));

  ({PlayerRepository repository, RunCoordinator runs}) build(PlayerSave save) {
    return (repository: buildTestRepository(save), runs: RunCoordinator());
  }

  test('claims the run, builds a snapshot, and persists the equipped loadout',
      () {
    final PlayerSave save = startingSave();
    final (:repository, :runs) = build(save);
    addTearDown(repository.dispose);
    addTearDown(runs.dispose);
    final HeroDefinition wren = heroes.byArchetype(HeroArchetype.wren)!;

    final GuardRejection? rejection = RunLauncher.launch(
      repository: repository,
      runs: runs,
      save: save,
      stageRef: const StageRef(chapter: 1, stage: 1),
      heroId: 'wren',
      arrowId: 'ash_shaft',
      heroDefinition: wren,
      now: DateTime.utc(2026, 3),
    );

    expect(rejection, isNull);
    expect(runs.activeRun.value, isNotNull);
    expect(runs.activeRun.value!.heroId, 'wren');
    expect(runs.activeRun.value!.arrowId, 'ash_shaft');
    expect(runs.activeRun.value!.stage, const StageRef(chapter: 1, stage: 1));
    expect(repository.save.profile.equippedHeroId, 'wren');
    expect(repository.save.profile.equippedArrowId, 'ash_shaft');
  });

  test("the snapshot's currentHp is the hero's own composed max HP", () {
    final PlayerSave save = startingSave();
    final (:repository, :runs) = build(save);
    addTearDown(repository.dispose);
    addTearDown(runs.dispose);
    final HeroDefinition wren = heroes.byArchetype(HeroArchetype.wren)!;

    RunLauncher.launch(
      repository: repository,
      runs: runs,
      save: save,
      stageRef: const StageRef(chapter: 1, stage: 1),
      heroId: 'wren',
      arrowId: 'ash_shaft',
      heroDefinition: wren,
      now: DateTime.utc(2026, 3),
    );

    // PlayerSave.initial's own starting Wren is level 1, ★1 (granted
    // pre-unlocked at star 1 — the same "unlock is star 1" pairing
    // HeroWorkshop.unlock relies on), not ★0.
    final int expectedHp =
        balance.Curves.heroStat(wren.stats.hp, 1, 1).round();
    expect(runs.activeRun.value!.currentHp, expectedHp);
  });

  test('fails when the target chapter is still locked', () {
    final PlayerSave save = startingSave(); // currentChapter defaults to 1
    final (:repository, :runs) = build(save);
    addTearDown(repository.dispose);
    addTearDown(runs.dispose);
    final HeroDefinition wren = heroes.byArchetype(HeroArchetype.wren)!;

    final GuardRejection? rejection = RunLauncher.launch(
      repository: repository,
      runs: runs,
      save: save,
      stageRef: const StageRef(chapter: 5, stage: 1),
      heroId: 'wren',
      arrowId: 'ash_shaft',
      heroDefinition: wren,
      now: DateTime.utc(2026, 3),
    );

    expect(rejection, GuardRejection.chapterLocked);
    expect(runs.activeRun.value, isNull);
  });

  test('fails when a run is already active', () {
    final PlayerSave save = startingSave();
    final (:repository, :runs) = build(save);
    addTearDown(repository.dispose);
    addTearDown(runs.dispose);
    final HeroDefinition wren = heroes.byArchetype(HeroArchetype.wren)!;
    runs.tryBeginStart(); // claim the slot out from under this launch

    final GuardRejection? rejection = RunLauncher.launch(
      repository: repository,
      runs: runs,
      save: save,
      stageRef: const StageRef(chapter: 1, stage: 1),
      heroId: 'wren',
      arrowId: 'ash_shaft',
      heroDefinition: wren,
      now: DateTime.utc(2026, 3),
    );

    expect(rejection, GuardRejection.runAlreadyActive);
  });
}
