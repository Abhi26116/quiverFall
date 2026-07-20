import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:quiverfall/data/models/converters.dart';

part 'run_snapshot.freezed.dart';
part 'run_snapshot.g.dart';

/// Identifies a stage in the campaign.
@freezed
class StageRef with _$StageRef {
  const factory StageRef({
    required int chapter,
    required int stage,
  }) = _StageRef;

  factory StageRef.fromJson(Map<String, dynamic> json) =>
      _$StageRefFromJson(json);

  const StageRef._();

  /// Global stage index `G` used by every balance curve in the GDD:
  /// `G = (chapter - 1) * 20 + stage`.
  int get globalIndex => (chapter - 1) * 20 + stage;

  /// Stable key for the campaign records map, e.g. `c7s12`.
  String get key => 'c${chapter}s$stage';

  bool get isBossStage => stage == 20;
}

/// A resumable point in an in-progress run.
///
/// Written at every room boundary (~2 KB measured in Phase 0). Two jobs:
///
///  1. Crash recovery — an OOM kill or force-quit costs at most one room.
///  2. Determinism — [seed] plus [inputTape] reproduce the run exactly, which
///     is what makes replays and server-side validation possible later without
///     rewriting the game. See docs/12-architecture.md §12.0.
@freezed
class RunSnapshot with _$RunSnapshot {
  const factory RunSnapshot({
    required String runId,
    required int seed,
    required StageRef stage,
    required String heroId,
    required String arrowId,
    required int roomIndex,

    /// Ordered, with duplicates for stacked copies.
    @Default(<String>[]) List<String> boonIds,
    required int currentHp,
    @Default(0) int runGold,
    @Default(<String, int>{}) Map<String, int> runMaterials,
    @DurationConverter() @Default(Duration.zero) Duration elapsed,
    @UtcDateTimeConverter() required DateTime startedAt,

    /// Quantised input samples. Optional — omitted on low-end devices where the
    /// memory cost is not worth it, since replay is a nice-to-have and crash
    /// recovery is not.
    List<int>? inputTape,
  }) = _RunSnapshot;

  factory RunSnapshot.fromJson(Map<String, dynamic> json) =>
      _$RunSnapshotFromJson(json);
}
