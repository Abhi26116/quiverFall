import 'package:flutter/foundation.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';

/// Guards the invariant that at most one run exists at a time.
///
/// This is load-bearing, not defensive coding. Three real paths can otherwise
/// produce two live sessions:
///
///  - A double-tap on DESCEND before the route transition completes.
///  - A deep link (push notification, share link) arriving mid-run.
///  - The crash-recovery resume prompt racing a fresh launch.
///
/// Two live sessions means two simulations ticking, two sets of rewards banked,
/// and a save whose `activeRun` flips between them. See docs/11-screen-flow.md
/// §11.5, which requires this to be backed by a single-flight lock with a
/// regression test.
class RunCoordinator {
  final ValueNotifier<RunSnapshot?> activeRun =
      ValueNotifier<RunSnapshot?>(null);

  bool _starting = false;

  bool get isRunActive => activeRun.value != null || _starting;

  /// Attempts to claim the run slot.
  ///
  /// Returns false if a run is already active or starting. Callers must respect
  /// a false return and not navigate.
  bool tryBeginStart() {
    if (isRunActive) return false;
    _starting = true;
    return true;
  }

  /// Completes a start claimed by [tryBeginStart].
  void completeStart(RunSnapshot snapshot) {
    assert(_starting, 'completeStart without a matching tryBeginStart');
    _starting = false;
    activeRun.value = snapshot;
  }

  /// Releases a start claim that did not produce a run (validation failed, the
  /// user backed out of the loadout sheet).
  void abandonStart() {
    _starting = false;
  }

  /// Updates the resume point. Called at every room boundary.
  void updateSnapshot(RunSnapshot snapshot) {
    assert(
      activeRun.value != null,
      'updateSnapshot with no active run',
    );
    activeRun.value = snapshot;
  }

  /// Clears the slot on victory, defeat, or abandonment.
  void endRun() {
    _starting = false;
    activeRun.value = null;
  }

  /// Restores a run recovered from a crash.
  ///
  /// Fails rather than clobbering if a run is somehow already live, since that
  /// would mean the recovery path and a fresh start raced.
  bool tryResume(RunSnapshot snapshot) {
    if (isRunActive) return false;
    activeRun.value = snapshot;
    return true;
  }

  void dispose() => activeRun.dispose();
}
