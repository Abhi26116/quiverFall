// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_ops.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RewardsStateImpl _$$RewardsStateImplFromJson(Map<String, dynamic> json) =>
    _$RewardsStateImpl(
      dailyCycleDay: (json['dailyCycleDay'] as num?)?.toInt() ?? 1,
      lastDailyClaimAt: const NullableUtcDateTimeConverter()
          .fromJson(json['lastDailyClaimAt'] as String?),
      chestTimers: (json['chestTimers'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const <String, String>{},
      chestPityCounters:
          (json['chestPityCounters'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toInt()),
              ) ??
              const <String, int>{},
      battlePassTier: (json['battlePassTier'] as num?)?.toInt() ?? 0,
      battlePassXp: (json['battlePassXp'] as num?)?.toInt() ?? 0,
      battlePassPremium: json['battlePassPremium'] as bool? ?? false,
      battlePassSeasonId: (json['battlePassSeasonId'] as num?)?.toInt() ?? 0,
      claimedTierIds: (json['claimedTierIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
    );

Map<String, dynamic> _$$RewardsStateImplToJson(_$RewardsStateImpl instance) =>
    <String, dynamic>{
      'dailyCycleDay': instance.dailyCycleDay,
      'lastDailyClaimAt': const NullableUtcDateTimeConverter()
          .toJson(instance.lastDailyClaimAt),
      'chestTimers': instance.chestTimers,
      'chestPityCounters': instance.chestPityCounters,
      'battlePassTier': instance.battlePassTier,
      'battlePassXp': instance.battlePassXp,
      'battlePassPremium': instance.battlePassPremium,
      'battlePassSeasonId': instance.battlePassSeasonId,
      'claimedTierIds': instance.claimedTierIds.toList(),
    };

_$QuestInstanceImpl _$$QuestInstanceImplFromJson(Map<String, dynamic> json) =>
    _$QuestInstanceImpl(
      questId: json['questId'] as String,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num).toInt(),
      claimed: json['claimed'] as bool? ?? false,
    );

Map<String, dynamic> _$$QuestInstanceImplToJson(_$QuestInstanceImpl instance) =>
    <String, dynamic>{
      'questId': instance.questId,
      'progress': instance.progress,
      'target': instance.target,
      'claimed': instance.claimed,
    };

_$QuestStateImpl _$$QuestStateImplFromJson(Map<String, dynamic> json) =>
    _$QuestStateImpl(
      daily: (json['daily'] as List<dynamic>?)
              ?.map((e) => QuestInstance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <QuestInstance>[],
      weekly: (json['weekly'] as List<dynamic>?)
              ?.map((e) => QuestInstance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <QuestInstance>[],
      dailyResetAt: const NullableUtcDateTimeConverter()
          .fromJson(json['dailyResetAt'] as String?),
      weeklyResetAt: const NullableUtcDateTimeConverter()
          .fromJson(json['weeklyResetAt'] as String?),
    );

Map<String, dynamic> _$$QuestStateImplToJson(_$QuestStateImpl instance) =>
    <String, dynamic>{
      'daily': instance.daily,
      'weekly': instance.weekly,
      'dailyResetAt':
          const NullableUtcDateTimeConverter().toJson(instance.dailyResetAt),
      'weeklyResetAt':
          const NullableUtcDateTimeConverter().toJson(instance.weeklyResetAt),
    };

_$PurchaseRecordImpl _$$PurchaseRecordImplFromJson(Map<String, dynamic> json) =>
    _$PurchaseRecordImpl(
      sku: json['sku'] as String,
      transactionId: json['transactionId'] as String,
      platform: json['platform'] as String,
      purchasedAt:
          const UtcDateTimeConverter().fromJson(json['purchasedAt'] as String),
      verified: json['verified'] as bool? ?? false,
    );

Map<String, dynamic> _$$PurchaseRecordImplToJson(
        _$PurchaseRecordImpl instance) =>
    <String, dynamic>{
      'sku': instance.sku,
      'transactionId': instance.transactionId,
      'platform': instance.platform,
      'purchasedAt': const UtcDateTimeConverter().toJson(instance.purchasedAt),
      'verified': instance.verified,
    };

_$SubscriptionStateImpl _$$SubscriptionStateImplFromJson(
        Map<String, dynamic> json) =>
    _$SubscriptionStateImpl(
      productId: json['productId'] as String,
      startedAt:
          const UtcDateTimeConverter().fromJson(json['startedAt'] as String),
      expiresAt:
          const UtcDateTimeConverter().fromJson(json['expiresAt'] as String),
      autoRenewing: json['autoRenewing'] as bool? ?? true,
      inGracePeriod: json['inGracePeriod'] as bool? ?? false,
      latestReceiptHash: json['latestReceiptHash'] as String?,
    );

Map<String, dynamic> _$$SubscriptionStateImplToJson(
        _$SubscriptionStateImpl instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'startedAt': const UtcDateTimeConverter().toJson(instance.startedAt),
      'expiresAt': const UtcDateTimeConverter().toJson(instance.expiresAt),
      'autoRenewing': instance.autoRenewing,
      'inGracePeriod': instance.inGracePeriod,
      'latestReceiptHash': instance.latestReceiptHash,
    };

_$PurchaseStateImpl _$$PurchaseStateImplFromJson(Map<String, dynamic> json) =>
    _$PurchaseStateImpl(
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => PurchaseRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PurchaseRecord>[],
      removeAdsOwned: json['removeAdsOwned'] as bool? ?? false,
      pact: json['pact'] == null
          ? null
          : SubscriptionState.fromJson(json['pact'] as Map<String, dynamic>),
      consumedOneTimeSkus: (json['consumedOneTimeSkus'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
      lifetimeSpendUsd: (json['lifetimeSpendUsd'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$$PurchaseStateImplToJson(_$PurchaseStateImpl instance) =>
    <String, dynamic>{
      'history': instance.history,
      'removeAdsOwned': instance.removeAdsOwned,
      'pact': instance.pact,
      'consumedOneTimeSkus': instance.consumedOneTimeSkus.toList(),
      'lifetimeSpendUsd': instance.lifetimeSpendUsd,
    };

_$AchievementStateImpl _$$AchievementStateImplFromJson(
        Map<String, dynamic> json) =>
    _$AchievementStateImpl(
      progress: (json['progress'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      claimedIds: (json['claimedIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
    );

Map<String, dynamic> _$$AchievementStateImplToJson(
        _$AchievementStateImpl instance) =>
    <String, dynamic>{
      'progress': instance.progress,
      'claimedIds': instance.claimedIds.toList(),
    };
