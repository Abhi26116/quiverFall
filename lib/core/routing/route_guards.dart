import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';

/// Why a guard refused a route.
///
/// Guards return a reason rather than a bool so the UI can explain the refusal.
/// A deep link that silently lands on the menu with no explanation reads as a
/// broken app.
enum GuardRejection {
  bootstrapIncomplete,
  chapterLocked,
  stageLocked,
  insufficientVigor,
  runAlreadyActive,
  noActiveRun,
  accountLevelTooLow,
  eventNotLive;

  String get playerMessage => switch (this) {
        GuardRejection.bootstrapIncomplete => 'Still loading…',
        GuardRejection.chapterLocked => 'That chapter is still sealed.',
        GuardRejection.stageLocked => 'Clear the previous stage first.',
        GuardRejection.insufficientVigor => 'Not enough Vigor.',
        GuardRejection.runAlreadyActive => 'A descent is already underway.',
        GuardRejection.noActiveRun => 'No descent in progress.',
        GuardRejection.accountLevelTooLow => 'Unlocks at a higher level.',
        GuardRejection.eventNotLive => 'That event has ended.',
      };
}

/// Route entry preconditions, from docs/11-screen-flow.md §11.5.
///
/// Kept as pure functions of state so they are unit-testable without a
/// navigator, a widget tree, or a running app.
abstract final class RouteGuards {
  /// The Research Lab opens at account level 9.
  static const int researchMinAccountLevel = 9;

  static GuardRejection? chapter(PlayerSave? save, int chapter) {
    if (save == null) return GuardRejection.bootstrapIncomplete;
    if (chapter < 1) return GuardRejection.chapterLocked;
    // A chapter is open once the previous one has been cleared. Chapter 1 is
    // always open.
    if (chapter > save.campaign.currentChapter) {
      return GuardRejection.chapterLocked;
    }
    return null;
  }

  static GuardRejection? research(PlayerSave? save) {
    if (save == null) return GuardRejection.bootstrapIncomplete;
    if (save.profile.accountLevel < researchMinAccountLevel) {
      return GuardRejection.accountLevelTooLow;
    }
    return null;
  }

  /// Entering a stage.
  ///
  /// Encodes the most important economic rule in the game: **a stage the player
  /// has never cleared costs 0 Vigor**, so campaign progression can never be
  /// energy-gated. Vigor only throttles farming. See docs/02-economy.md §2.2.
  static GuardRejection? stage(
    PlayerSave? save,
    StageRef ref, {
    required RunCoordinator runs,
  }) {
    if (save == null) return GuardRejection.bootstrapIncomplete;
    if (runs.isRunActive) return GuardRejection.runAlreadyActive;

    final GuardRejection? chapterCheck = chapter(save, ref.chapter);
    if (chapterCheck != null) return chapterCheck;

    if (ref.chapter == save.campaign.currentChapter &&
        ref.stage > save.campaign.currentStage) {
      return GuardRejection.stageLocked;
    }

    if (vigorCostFor(save, ref) > save.vigor.current) {
      return GuardRejection.insufficientVigor;
    }
    return null;
  }

  /// Vigor cost for one attempt at [ref]. Zero if never cleared.
  static int vigorCostFor(PlayerSave save, StageRef ref) {
    final bool cleared = save.campaign.isStageCleared(ref.key);
    if (!cleared) return 0;
    return ref.isBossStage ? VigorState.bossRerunCost : VigorState.runCost;
  }

  /// Entering the gameplay screen.
  ///
  /// By the time this runs, the caller must already have claimed the run slot
  /// via [RunCoordinator.tryBeginStart] and populated it. So the check is that a
  /// run *is* active — which is what rejects a deep link or a restored
  /// back-stack entry pointing straight at `/game` with no session behind it.
  ///
  /// The "only one run" half of the invariant is enforced earlier, by
  /// [RunCoordinator.tryBeginStart] refusing a second claim.
  static GuardRejection? game(PlayerSave? save, RunCoordinator runs) {
    if (save == null) return GuardRejection.bootstrapIncomplete;
    if (!runs.isRunActive) return GuardRejection.noActiveRun;
    return null;
  }
}
