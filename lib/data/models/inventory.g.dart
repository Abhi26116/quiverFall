// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AffixImpl _$$AffixImplFromJson(Map<String, dynamic> json) => _$AffixImpl(
      affixId: json['affixId'] as String,
      value: (json['value'] as num).toDouble(),
      tier: (json['tier'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$$AffixImplToJson(_$AffixImpl instance) =>
    <String, dynamic>{
      'affixId': instance.affixId,
      'value': instance.value,
      'tier': instance.tier,
    };

_$ArrowInstanceImpl _$$ArrowInstanceImplFromJson(Map<String, dynamic> json) =>
    _$ArrowInstanceImpl(
      arrowId: json['arrowId'] as String,
      crafted: json['crafted'] as bool? ?? false,
      refineLevel: (json['refineLevel'] as num?)?.toInt() ?? 0,
      affixes: (json['affixes'] as List<dynamic>?)
              ?.map((e) => Affix.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Affix>[],
      lockedAffixSlots: (json['lockedAffixSlots'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          const <int>{},
    );

Map<String, dynamic> _$$ArrowInstanceImplToJson(_$ArrowInstanceImpl instance) =>
    <String, dynamic>{
      'arrowId': instance.arrowId,
      'crafted': instance.crafted,
      'refineLevel': instance.refineLevel,
      'affixes': instance.affixes,
      'lockedAffixSlots': instance.lockedAffixSlots.toList(),
    };

_$InventoryStateImpl _$$InventoryStateImplFromJson(Map<String, dynamic> json) =>
    _$InventoryStateImpl(
      arrows: (json['arrows'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, ArrowInstance.fromJson(e as Map<String, dynamic>)),
          ) ??
          const <String, ArrowInstance>{},
      cosmeticIds: (json['cosmeticIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
      windlineSkinIds: (json['windlineSkinIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
      rerollCountThisSession:
          (json['rerollCountThisSession'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$InventoryStateImplToJson(
        _$InventoryStateImpl instance) =>
    <String, dynamic>{
      'arrows': instance.arrows,
      'cosmeticIds': instance.cosmeticIds.toList(),
      'windlineSkinIds': instance.windlineSkinIds.toList(),
      'rerollCountThisSession': instance.rerollCountThisSession,
    };
