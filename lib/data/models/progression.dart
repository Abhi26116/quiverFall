import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:quiverfall/data/models/converters.dart';

part 'progression.freezed.dart';
part 'progression.g.dart';

/// The Spire — 24 permanent upgrade nodes across 4 wings.
///
/// Resets on Ascension. See docs/04-upgrades.md §4.2.
@freezed
class SpireState with _$SpireState {
  const factory SpireState({
    /// nodeId (1–24) -> level (0–80). Keys are strings because JSON object keys
    /// must be strings; parsed on read.
    @Default(<String, int>{}) Map<String, int> nodeLevels,

    /// nodeId -> highest tier band unlocked (0 / 20 / 40 / 60). Advancing a band
    /// costs Insight, which is unpurchasable — this is the structural brake on
    /// pay-to-win described in docs/02-economy.md §2.11.
    @Default(<String, int>{}) Map<String, int> tierGatesUnlocked,
    @Default(0) int totalGoldSpent,
  }) = _SpireState;

  factory SpireState.fromJson(Map<String, dynamic> json) =>
      _$SpireStateFromJson(json);

  const SpireState._();

  int levelOf(int nodeId) => nodeLevels['$nodeId'] ?? 0;

  int bandOf(int nodeId) => tierGatesUnlocked['$nodeId'] ?? 0;
}

@freezed
class ResearchState with _$ResearchState {
  const factory ResearchState({
    @Default(<String>{}) Set<String> completedIds,
    @Default(0) int insightSpent,
  }) = _ResearchState;

  factory ResearchState.fromJson(Map<String, dynamic> json) =>
      _$ResearchStateFromJson(json);
}

/// Prestige. See docs/04-upgrades.md §4.7.
@freezed
class AscensionState with _$AscensionState {
  const factory AscensionState({
    @Default(0) int count,

    /// Emberdust tree: branchNodeId -> rank. Never resets.
    @Default(<String, int>{}) Map<String, int> emberdustRanks,
    @NullableUtcDateTimeConverter() DateTime? lastAscendedAt,

    /// Never resets, even across Ascensions — it is the input to the Emberdust
    /// award formula, so resetting it would make each cycle pay less than the
    /// last.
    @Default(0) int highestChapterEver,
  }) = _AscensionState;

  factory AscensionState.fromJson(Map<String, dynamic> json) =>
      _$AscensionStateFromJson(json);
}

/// Mastery passives. Earned only by play — unpurchasable at any price, which is
/// what makes them a real answer to "what does a skilled player have that a
/// spending player cannot get". See docs/04-upgrades.md §4.5.
@freezed
class MarkState with _$MarkState {
  const factory MarkState({
    /// markId -> progress counter (e.g. confluences triggered).
    @Default(<String, int>{}) Map<String, int> progress,
    @Default(<String>{}) Set<String> unlockedIds,
  }) = _MarkState;

  factory MarkState.fromJson(Map<String, dynamic> json) =>
      _$MarkStateFromJson(json);
}

/// Per-hero progression. Never resets on Ascension.
@freezed
class HeroState with _$HeroState {
  const factory HeroState({
    required String heroId,
    @Default(false) bool unlocked,
    @Default(1) int level,
    @Default(0) int stars,

    /// starTier (1 / 3 / 5) -> chosen branch ('a' or 'b').
    @Default(<String, String>{}) Map<String, String> talentChoices,
    @Default(0) int shardsSpent,
    @NullableUtcDateTimeConverter() DateTime? firstUnlockedAt,
  }) = _HeroState;

  factory HeroState.fromJson(Map<String, dynamic> json) =>
      _$HeroStateFromJson(json);
}

/// Result of one stage attempt, kept as a best-ever record.
@freezed
class StageRecord with _$StageRecord {
  const factory StageRecord({
    @Default(0) int stars,
    @DurationConverter() @Default(Duration.zero) Duration bestTime,
    @Default(0) int clearCount,
    @Default(0) int bestConfluenceCount,
    @NullableUtcDateTimeConverter() DateTime? firstClearedAt,

    /// Drives both the bestiary and the threat preview on Level Select. A
    /// player only ever sees named threats for enemies they have actually met.
    @Default(<String>{}) Set<String> enemiesSeen,
  }) = _StageRecord;

  factory StageRecord.fromJson(Map<String, dynamic> json) =>
      _$StageRecordFromJson(json);
}

@freezed
class CampaignState with _$CampaignState {
  const factory CampaignState({
    @Default(1) int currentChapter,
    @Default(1) int currentStage,

    /// StageRef.key -> record.
    @Default(<String, StageRecord>{}) Map<String, StageRecord> records,
    @Default(<String>{}) Set<String> bossesDefeated,

    /// Drives the +6% per-kill boss HP scaling, so farming a known boss stays
    /// engaging rather than becoming free.
    @Default(<String, int>{}) Map<String, int> bossKillCounts,
    @Default(0) int endlessBestFloor,
    @Default(0) int endlessSeasonId,
  }) = _CampaignState;

  factory CampaignState.fromJson(Map<String, dynamic> json) =>
      _$CampaignStateFromJson(json);

  const CampaignState._();

  bool isStageCleared(String key) => (records[key]?.clearCount ?? 0) > 0;

  int get totalStars =>
      records.values.fold(0, (int sum, StageRecord r) => sum + r.stars);
}
