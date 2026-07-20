// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SettingsStateImpl _$$SettingsStateImplFromJson(Map<String, dynamic> json) =>
    _$SettingsStateImpl(
      musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 0.7,
      sfxVolume: (json['sfxVolume'] as num?)?.toDouble() ?? 1.0,
      uiVolume: (json['uiVolume'] as num?)?.toDouble() ?? 1.0,
      haptics: json['haptics'] as bool? ?? true,
      screenShake: json['screenShake'] as bool? ?? true,
      damageNumbers: json['damageNumbers'] as bool? ?? true,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      graphicsQuality: $enumDecodeNullable(
              _$GraphicsQualityEnumMap, json['graphicsQuality']) ??
          GraphicsQuality.auto,
      fpsCap: (json['fpsCap'] as num?)?.toInt() ?? 60,
      particleDensity: (json['particleDensity'] as num?)?.toDouble() ?? 1.0,
      autoAim: $enumDecodeNullable(_$AutoAimStrengthEnumMap, json['autoAim']) ??
          AutoAimStrength.standard,
      leftHanded: json['leftHanded'] as bool? ?? false,
      oneHandedMode: json['oneHandedMode'] as bool? ?? false,
      autoUltimate: json['autoUltimate'] as bool? ?? false,
      joystickScale: (json['joystickScale'] as num?)?.toDouble() ?? 1.0,
      locale: json['locale'] as String? ?? 'en',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      colorBlindMode: json['colorBlindMode'] as bool? ?? false,
      analyticsOptOut: json['analyticsOptOut'] as bool? ?? false,
    );

Map<String, dynamic> _$$SettingsStateImplToJson(_$SettingsStateImpl instance) =>
    <String, dynamic>{
      'musicVolume': instance.musicVolume,
      'sfxVolume': instance.sfxVolume,
      'uiVolume': instance.uiVolume,
      'haptics': instance.haptics,
      'screenShake': instance.screenShake,
      'damageNumbers': instance.damageNumbers,
      'reduceMotion': instance.reduceMotion,
      'graphicsQuality': _$GraphicsQualityEnumMap[instance.graphicsQuality]!,
      'fpsCap': instance.fpsCap,
      'particleDensity': instance.particleDensity,
      'autoAim': _$AutoAimStrengthEnumMap[instance.autoAim]!,
      'leftHanded': instance.leftHanded,
      'oneHandedMode': instance.oneHandedMode,
      'autoUltimate': instance.autoUltimate,
      'joystickScale': instance.joystickScale,
      'locale': instance.locale,
      'notificationsEnabled': instance.notificationsEnabled,
      'colorBlindMode': instance.colorBlindMode,
      'analyticsOptOut': instance.analyticsOptOut,
    };

const _$GraphicsQualityEnumMap = {
  GraphicsQuality.auto: 'auto',
  GraphicsQuality.battery: 'battery',
  GraphicsQuality.balanced: 'balanced',
  GraphicsQuality.high: 'high',
};

const _$AutoAimStrengthEnumMap = {
  AutoAimStrength.off: 'off',
  AutoAimStrength.light: 'light',
  AutoAimStrength.standard: 'standard',
  AutoAimStrength.strong: 'strong',
};

_$StatsStateImpl _$$StatsStateImplFromJson(Map<String, dynamic> json) =>
    _$StatsStateImpl(
      runsStarted: (json['runsStarted'] as num?)?.toInt() ?? 0,
      runsWon: (json['runsWon'] as num?)?.toInt() ?? 0,
      runsLost: (json['runsLost'] as num?)?.toInt() ?? 0,
      enemiesKilled: (json['enemiesKilled'] as num?)?.toInt() ?? 0,
      bossesKilled: (json['bossesKilled'] as num?)?.toInt() ?? 0,
      elitesKilled: (json['elitesKilled'] as num?)?.toInt() ?? 0,
      confluencesTriggered:
          (json['confluencesTriggered'] as num?)?.toInt() ?? 0,
      maxConfluenceStack: (json['maxConfluenceStack'] as num?)?.toInt() ?? 0,
      tierThreeShotsLanded:
          (json['tierThreeShotsLanded'] as num?)?.toInt() ?? 0,
      maxMomentumReached: (json['maxMomentumReached'] as num?)?.toInt() ?? 0,
      totalPlayTime: json['totalPlayTime'] == null
          ? Duration.zero
          : const DurationConverter()
              .fromJson((json['totalPlayTime'] as num).toInt()),
      goldEarnedLifetime: (json['goldEarnedLifetime'] as num?)?.toInt() ?? 0,
      gemsEarnedLifetime: (json['gemsEarnedLifetime'] as num?)?.toInt() ?? 0,
      heroUsageSeconds:
          (json['heroUsageSeconds'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toInt()),
              ) ??
              const <String, int>{},
      deathsByEnemyId: (json['deathsByEnemyId'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
    );

Map<String, dynamic> _$$StatsStateImplToJson(_$StatsStateImpl instance) =>
    <String, dynamic>{
      'runsStarted': instance.runsStarted,
      'runsWon': instance.runsWon,
      'runsLost': instance.runsLost,
      'enemiesKilled': instance.enemiesKilled,
      'bossesKilled': instance.bossesKilled,
      'elitesKilled': instance.elitesKilled,
      'confluencesTriggered': instance.confluencesTriggered,
      'maxConfluenceStack': instance.maxConfluenceStack,
      'tierThreeShotsLanded': instance.tierThreeShotsLanded,
      'maxMomentumReached': instance.maxMomentumReached,
      'totalPlayTime': const DurationConverter().toJson(instance.totalPlayTime),
      'goldEarnedLifetime': instance.goldEarnedLifetime,
      'gemsEarnedLifetime': instance.gemsEarnedLifetime,
      'heroUsageSeconds': instance.heroUsageSeconds,
      'deathsByEnemyId': instance.deathsByEnemyId,
    };
