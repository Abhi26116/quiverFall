// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StageRefImpl _$$StageRefImplFromJson(Map<String, dynamic> json) =>
    _$StageRefImpl(
      chapter: (json['chapter'] as num).toInt(),
      stage: (json['stage'] as num).toInt(),
    );

Map<String, dynamic> _$$StageRefImplToJson(_$StageRefImpl instance) =>
    <String, dynamic>{
      'chapter': instance.chapter,
      'stage': instance.stage,
    };

_$RunSnapshotImpl _$$RunSnapshotImplFromJson(Map<String, dynamic> json) =>
    _$RunSnapshotImpl(
      runId: json['runId'] as String,
      seed: (json['seed'] as num).toInt(),
      stage: StageRef.fromJson(json['stage'] as Map<String, dynamic>),
      heroId: json['heroId'] as String,
      arrowId: json['arrowId'] as String,
      roomIndex: (json['roomIndex'] as num).toInt(),
      boonIds: (json['boonIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      currentHp: (json['currentHp'] as num).toInt(),
      runGold: (json['runGold'] as num?)?.toInt() ?? 0,
      runMaterials: (json['runMaterials'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      elapsed: json['elapsed'] == null
          ? Duration.zero
          : const DurationConverter()
              .fromJson((json['elapsed'] as num).toInt()),
      startedAt:
          const UtcDateTimeConverter().fromJson(json['startedAt'] as String),
      inputTape: (json['inputTape'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$$RunSnapshotImplToJson(_$RunSnapshotImpl instance) =>
    <String, dynamic>{
      'runId': instance.runId,
      'seed': instance.seed,
      'stage': instance.stage,
      'heroId': instance.heroId,
      'arrowId': instance.arrowId,
      'roomIndex': instance.roomIndex,
      'boonIds': instance.boonIds,
      'currentHp': instance.currentHp,
      'runGold': instance.runGold,
      'runMaterials': instance.runMaterials,
      'elapsed': const DurationConverter().toJson(instance.elapsed),
      'startedAt': const UtcDateTimeConverter().toJson(instance.startedAt),
      'inputTape': instance.inputTape,
    };
