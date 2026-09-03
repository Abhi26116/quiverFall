import 'package:quiverfall/core/routing/route_guards.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:quiverfall/game/balance/curves.dart' as balance;
import 'package:quiverfall/game/heroes/hero_definition.dart';

/// Claims a run and starts it — the one piece of "DESCEND" shared by every
/// place docs/11-screen-flow.md §11.1's nav graph lets a player begin a
/// descent: the Loadout Sheet (a freshly chosen build) and the Menu's own
/// DESCEND button (`Menu -->|DESCEND| Game` — the account's currently
/// equipped build, resuming straight into a run with no picker at all).
///
/// Extracted rather than left inline on `LoadoutScreen` once a second caller
/// needed the identical claim-a-run dance — the same "one routine, every
/// caller shares it" reasoning `ElementSystem`'s own death handling and
/// `ProjectileSystem`'s ricochet code already follow elsewhere in this repo.
abstract final class RunLauncher {
  /// Attempts to claim [runs]' run slot for [heroId]/[arrowId] at
  /// [stageRef], persisting the choice as the account's own equipped
  /// loadout on success.
  ///
  /// Returns `null` on success — the caller should navigate to `/game` next
  /// — or the [GuardRejection] to show otherwise. Only the chapter-lock
  /// guard is checked, the same scope boundary ADR 0014 already recorded
  /// for the Loadout Sheet's own DESCEND: Vigor is not spent here either,
  /// pending a regen service nothing in the codebase provides yet.
  static GuardRejection? launch({
    required PlayerRepository repository,
    required RunCoordinator runs,
    required PlayerSave save,
    required StageRef stageRef,
    required String heroId,
    required String arrowId,
    required HeroDefinition heroDefinition,
    required DateTime now,
  }) {
    final GuardRejection? chapterRejection =
        RouteGuards.chapter(save, stageRef.chapter);
    if (chapterRejection != null) return chapterRejection;

    if (!runs.tryBeginStart()) return GuardRejection.runAlreadyActive;

    final HeroState heroState =
        save.heroes[heroId] ?? HeroState(heroId: heroId);
    final int maxHp = balance.Curves
        .heroStat(heroDefinition.stats.hp, heroState.level, heroState.stars)
        .round();

    final RunSnapshot snapshot = RunSnapshot(
      runId: '${now.microsecondsSinceEpoch}',
      seed: now.microsecondsSinceEpoch,
      stage: stageRef,
      heroId: heroId,
      arrowId: arrowId,
      roomIndex: 0,
      currentHp: maxHp,
      startedAt: now,
    );
    runs.completeStart(snapshot);

    repository.mutate((PlayerSave s) => s.copyWith(
          profile: s.profile.copyWith(
            equippedHeroId: heroId,
            equippedArrowId: arrowId,
          ),
        ));

    return null;
  }
}
