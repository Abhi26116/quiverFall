import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:quiverfall/data/models/converters.dart';

part 'live_ops.freezed.dart';
part 'live_ops.g.dart';

@freezed
class RewardsState with _$RewardsState {
  const factory RewardsState({
    /// 1–28. Missing a day does not reset this — it simply does not advance.
    /// Streak-loss punishment is a dark pattern and is banned by Design Law 6.
    @Default(1) int dailyCycleDay,
    @NullableUtcDateTimeConverter() DateTime? lastDailyClaimAt,

    /// chestId -> when its free timer completes.
    @Default(<String, String>{}) Map<String, String> chestTimers,

    /// chestType -> pulls since last guaranteed drop. Displayed in the UI, never
    /// hidden — see docs/02-economy.md §2.8.
    @Default(<String, int>{}) Map<String, int> chestPityCounters,
    @Default(0) int battlePassTier,
    @Default(0) int battlePassXp,
    @Default(false) bool battlePassPremium,
    @Default(0) int battlePassSeasonId,
    @Default(<String>{}) Set<String> claimedTierIds,
  }) = _RewardsState;

  factory RewardsState.fromJson(Map<String, dynamic> json) =>
      _$RewardsStateFromJson(json);
}

@freezed
class QuestInstance with _$QuestInstance {
  const factory QuestInstance({
    required String questId,
    @Default(0) int progress,
    required int target,
    @Default(false) bool claimed,
  }) = _QuestInstance;

  factory QuestInstance.fromJson(Map<String, dynamic> json) =>
      _$QuestInstanceFromJson(json);

  const QuestInstance._();

  bool get isComplete => progress >= target;
}

@freezed
class QuestState with _$QuestState {
  const factory QuestState({
    @Default(<QuestInstance>[]) List<QuestInstance> daily,
    @Default(<QuestInstance>[]) List<QuestInstance> weekly,
    @NullableUtcDateTimeConverter() DateTime? dailyResetAt,
    @NullableUtcDateTimeConverter() DateTime? weeklyResetAt,
  }) = _QuestState;

  factory QuestState.fromJson(Map<String, dynamic> json) =>
      _$QuestStateFromJson(json);
}

@freezed
class PurchaseRecord with _$PurchaseRecord {
  const factory PurchaseRecord({
    required String sku,
    required String transactionId,
    required String platform,
    @UtcDateTimeConverter() required DateTime purchasedAt,
    @Default(false) bool verified,
  }) = _PurchaseRecord;

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) =>
      _$PurchaseRecordFromJson(json);
}

@freezed
class SubscriptionState with _$SubscriptionState {
  const factory SubscriptionState({
    required String productId,
    @UtcDateTimeConverter() required DateTime startedAt,
    @UtcDateTimeConverter() required DateTime expiresAt,
    @Default(true) bool autoRenewing,
    @Default(false) bool inGracePeriod,
    String? latestReceiptHash,
  }) = _SubscriptionState;

  factory SubscriptionState.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionStateFromJson(json);

  const SubscriptionState._();

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt) || inGracePeriod;
}

@freezed
class PurchaseState with _$PurchaseState {
  const factory PurchaseState({
    @Default(<PurchaseRecord>[]) List<PurchaseRecord> history,
    @Default(false) bool removeAdsOwned,

    /// Warden's Pact.
    SubscriptionState? pact,
    @Default(<String>{}) Set<String> consumedOneTimeSkus,

    /// Local only. Deliberately never synced to the cloud and never sold —
    /// see docs/13-database.md §13.10.
    @Default(0) double lifetimeSpendUsd,
  }) = _PurchaseState;

  factory PurchaseState.fromJson(Map<String, dynamic> json) =>
      _$PurchaseStateFromJson(json);
}

@freezed
class AchievementState with _$AchievementState {
  const factory AchievementState({
    @Default(<String, int>{}) Map<String, int> progress,
    @Default(<String>{}) Set<String> claimedIds,
  }) = _AchievementState;

  factory AchievementState.fromJson(Map<String, dynamic> json) =>
      _$AchievementStateFromJson(json);
}
