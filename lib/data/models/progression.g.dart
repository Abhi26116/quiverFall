// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progression.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SpireStateImpl _$$SpireStateImplFromJson(Map<String, dynamic> json) =>
    _$SpireStateImpl(
      nodeLevels: (json['nodeLevels'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      tierGatesUnlocked:
          (json['tierGatesUnlocked'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toInt()),
              ) ??
              const <String, int>{},
      totalGoldSpent: (json['totalGoldSpent'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$SpireStateImplToJson(_$SpireStateImpl instance) =>
    <String, dynamic>{
      'nodeLevels': instance.nodeLevels,
      'tierGatesUnlocked': instance.tierGatesUnlocked,
      'totalGoldSpent': instance.totalGoldSpent,
    };

_$ResearchStateImpl _$$ResearchStateImplFromJson(Map<String, dynamic> json) =>
    _$ResearchStateImpl(
      completedIds: (json['completedIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
      insightSpent: (json['insightSpent'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ResearchStateImplToJson(_$ResearchStateImpl instance) =>
    <String, dynamic>{
      'completedIds': instance.completedIds.toList(),
      'insightSpent': instance.insightSpent,
    };

_$AscensionStateImpl _$$AscensionStateImplFromJson(Map<String, dynamic> json) =>
    _$AscensionStateImpl(
      count: (json['count'] as num?)?.toInt() ?? 0,
      emberdustRanks: (json['emberdustRanks'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      lastAscendedAt: const NullableUtcDateTimeConverter()
          .fromJson(json['lastAscendedAt'] as String?),
      highestChapterEver: (json['highestChapterEver'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$AscensionStateImplToJson(
        _$AscensionStateImpl instance) =>
    <String, dynamic>{
      'count': instance.count,
      'emberdustRanks': instance.emberdustRanks,
      'lastAscendedAt':
          const NullableUtcDateTimeConverter().toJson(instance.lastAscendedAt),
      'highestChapterEver': instance.highestChapterEver,
    };

_$MarkStateImpl _$$MarkStateImplFromJson(Map<String, dynamic> json) =>
    _$MarkStateImpl(
      progress: (json['progress'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      unlockedIds: (json['unlockedIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
    );

Map<String, dynamic> _$$MarkStateImplToJson(_$MarkStateImpl instance) =>
    <String, dynamic>{
      'progress': instance.progress,
      'unlockedIds': instance.unlockedIds.toList(),
    };

_$HeroStateImpl _$$HeroStateImplFromJson(Map<String, dynamic> json) =>
    _$HeroStateImpl(
      heroId: json['heroId'] as String,
      unlocked: json['unlocked'] as bool? ?? false,
      level: (json['level'] as num?)?.toInt() ?? 1,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      talentChoices: (json['talentChoices'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const <String, String>{},
      shardsSpent: (json['shardsSpent'] as num?)?.toInt() ?? 0,
      firstUnlockedAt: const NullableUtcDateTimeConverter()
          .fromJson(json['firstUnlockedAt'] as String?),
    );

Map<String, dynamic> _$$HeroStateImplToJson(_$HeroStateImpl instance) =>
    <String, dynamic>{
      'heroId': instance.heroId,
      'unlocked': instance.unlocked,
      'level': instance.level,
      'stars': instance.stars,
      'talentChoices': instance.talentChoices,
      'shardsSpent': instance.shardsSpent,
      'firstUnlockedAt':
          const NullableUtcDateTimeConverter().toJson(instance.firstUnlockedAt),
    };

_$StageRecordImpl _$$StageRecordImplFromJson(Map<String, dynamic> json) =>
    _$StageRecordImpl(
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      bestTime: json['bestTime'] == null
          ? Duration.zero
          : const DurationConverter()
              .fromJson((json['bestTime'] as num).toInt()),
      clearCount: (json['clearCount'] as num?)?.toInt() ?? 0,
      bestConfluenceCount: (json['bestConfluenceCount'] as num?)?.toInt() ?? 0,
      firstClearedAt: const NullableUtcDateTimeConverter()
          .fromJson(json['firstClearedAt'] as String?),
      enemiesSeen: (json['enemiesSeen'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
    );

Map<String, dynamic> _$$StageRecordImplToJson(_$StageRecordImpl instance) =>
    <String, dynamic>{
      'stars': instance.stars,
      'bestTime': const DurationConverter().toJson(instance.bestTime),
      'clearCount': instance.clearCount,
      'bestConfluenceCount': instance.bestConfluenceCount,
      'firstClearedAt':
          const NullableUtcDateTimeConverter().toJson(instance.firstClearedAt),
      'enemiesSeen': instance.enemiesSeen.toList(),
    };

_$CampaignStateImpl _$$CampaignStateImplFromJson(Map<String, dynamic> json) =>
    _$CampaignStateImpl(
      currentChapter: (json['currentChapter'] as num?)?.toInt() ?? 1,
      currentStage: (json['currentStage'] as num?)?.toInt() ?? 1,
      records: (json['records'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, StageRecord.fromJson(e as Map<String, dynamic>)),
          ) ??
          const <String, StageRecord>{},
      bossesDefeated: (json['bossesDefeated'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
      bossKillCounts: (json['bossKillCounts'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      endlessBestFloor: (json['endlessBestFloor'] as num?)?.toInt() ?? 0,
      endlessSeasonId: (json['endlessSeasonId'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$CampaignStateImplToJson(_$CampaignStateImpl instance) =>
    <String, dynamic>{
      'currentChapter': instance.currentChapter,
      'currentStage': instance.currentStage,
      'records': instance.records,
      'bossesDefeated': instance.bossesDefeated.toList(),
      'bossKillCounts': instance.bossKillCounts,
      'endlessBestFloor': instance.endlessBestFloor,
      'endlessSeasonId': instance.endlessSeasonId,
    };
