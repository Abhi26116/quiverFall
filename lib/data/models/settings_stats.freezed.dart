// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SettingsState _$SettingsStateFromJson(Map<String, dynamic> json) {
  return _SettingsState.fromJson(json);
}

/// @nodoc
mixin _$SettingsState {
  double get musicVolume => throw _privateConstructorUsedError;
  double get sfxVolume => throw _privateConstructorUsedError;
  double get uiVolume => throw _privateConstructorUsedError;
  bool get haptics => throw _privateConstructorUsedError;
  bool get screenShake => throw _privateConstructorUsedError;
  bool get damageNumbers => throw _privateConstructorUsedError;
  bool get reduceMotion => throw _privateConstructorUsedError;
  GraphicsQuality get graphicsQuality => throw _privateConstructorUsedError;
  int get fpsCap => throw _privateConstructorUsedError;
  double get particleDensity => throw _privateConstructorUsedError;
  AutoAimStrength get autoAim => throw _privateConstructorUsedError;
  bool get leftHanded => throw _privateConstructorUsedError;
  bool get oneHandedMode => throw _privateConstructorUsedError;
  bool get autoUltimate => throw _privateConstructorUsedError;
  double get joystickScale => throw _privateConstructorUsedError;
  String get locale => throw _privateConstructorUsedError;
  bool get notificationsEnabled => throw _privateConstructorUsedError;

  /// Replaces the amber/crimson hue distinction with shape cues (dashed
  /// outlines vs solid hatching), since that distinction carries gameplay
  /// information. See docs/10-ui-ux.md §10.0.
  bool get colorBlindMode => throw _privateConstructorUsedError;

  /// Honoured for real: this stops collection, not just transmission.
  bool get analyticsOptOut => throw _privateConstructorUsedError;

  /// Serializes this SettingsState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SettingsStateCopyWith<SettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SettingsStateCopyWith<$Res> {
  factory $SettingsStateCopyWith(
          SettingsState value, $Res Function(SettingsState) then) =
      _$SettingsStateCopyWithImpl<$Res, SettingsState>;
  @useResult
  $Res call(
      {double musicVolume,
      double sfxVolume,
      double uiVolume,
      bool haptics,
      bool screenShake,
      bool damageNumbers,
      bool reduceMotion,
      GraphicsQuality graphicsQuality,
      int fpsCap,
      double particleDensity,
      AutoAimStrength autoAim,
      bool leftHanded,
      bool oneHandedMode,
      bool autoUltimate,
      double joystickScale,
      String locale,
      bool notificationsEnabled,
      bool colorBlindMode,
      bool analyticsOptOut});
}

/// @nodoc
class _$SettingsStateCopyWithImpl<$Res, $Val extends SettingsState>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? musicVolume = null,
    Object? sfxVolume = null,
    Object? uiVolume = null,
    Object? haptics = null,
    Object? screenShake = null,
    Object? damageNumbers = null,
    Object? reduceMotion = null,
    Object? graphicsQuality = null,
    Object? fpsCap = null,
    Object? particleDensity = null,
    Object? autoAim = null,
    Object? leftHanded = null,
    Object? oneHandedMode = null,
    Object? autoUltimate = null,
    Object? joystickScale = null,
    Object? locale = null,
    Object? notificationsEnabled = null,
    Object? colorBlindMode = null,
    Object? analyticsOptOut = null,
  }) {
    return _then(_value.copyWith(
      musicVolume: null == musicVolume
          ? _value.musicVolume
          : musicVolume // ignore: cast_nullable_to_non_nullable
              as double,
      sfxVolume: null == sfxVolume
          ? _value.sfxVolume
          : sfxVolume // ignore: cast_nullable_to_non_nullable
              as double,
      uiVolume: null == uiVolume
          ? _value.uiVolume
          : uiVolume // ignore: cast_nullable_to_non_nullable
              as double,
      haptics: null == haptics
          ? _value.haptics
          : haptics // ignore: cast_nullable_to_non_nullable
              as bool,
      screenShake: null == screenShake
          ? _value.screenShake
          : screenShake // ignore: cast_nullable_to_non_nullable
              as bool,
      damageNumbers: null == damageNumbers
          ? _value.damageNumbers
          : damageNumbers // ignore: cast_nullable_to_non_nullable
              as bool,
      reduceMotion: null == reduceMotion
          ? _value.reduceMotion
          : reduceMotion // ignore: cast_nullable_to_non_nullable
              as bool,
      graphicsQuality: null == graphicsQuality
          ? _value.graphicsQuality
          : graphicsQuality // ignore: cast_nullable_to_non_nullable
              as GraphicsQuality,
      fpsCap: null == fpsCap
          ? _value.fpsCap
          : fpsCap // ignore: cast_nullable_to_non_nullable
              as int,
      particleDensity: null == particleDensity
          ? _value.particleDensity
          : particleDensity // ignore: cast_nullable_to_non_nullable
              as double,
      autoAim: null == autoAim
          ? _value.autoAim
          : autoAim // ignore: cast_nullable_to_non_nullable
              as AutoAimStrength,
      leftHanded: null == leftHanded
          ? _value.leftHanded
          : leftHanded // ignore: cast_nullable_to_non_nullable
              as bool,
      oneHandedMode: null == oneHandedMode
          ? _value.oneHandedMode
          : oneHandedMode // ignore: cast_nullable_to_non_nullable
              as bool,
      autoUltimate: null == autoUltimate
          ? _value.autoUltimate
          : autoUltimate // ignore: cast_nullable_to_non_nullable
              as bool,
      joystickScale: null == joystickScale
          ? _value.joystickScale
          : joystickScale // ignore: cast_nullable_to_non_nullable
              as double,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      notificationsEnabled: null == notificationsEnabled
          ? _value.notificationsEnabled
          : notificationsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      colorBlindMode: null == colorBlindMode
          ? _value.colorBlindMode
          : colorBlindMode // ignore: cast_nullable_to_non_nullable
              as bool,
      analyticsOptOut: null == analyticsOptOut
          ? _value.analyticsOptOut
          : analyticsOptOut // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SettingsStateImplCopyWith<$Res>
    implements $SettingsStateCopyWith<$Res> {
  factory _$$SettingsStateImplCopyWith(
          _$SettingsStateImpl value, $Res Function(_$SettingsStateImpl) then) =
      __$$SettingsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double musicVolume,
      double sfxVolume,
      double uiVolume,
      bool haptics,
      bool screenShake,
      bool damageNumbers,
      bool reduceMotion,
      GraphicsQuality graphicsQuality,
      int fpsCap,
      double particleDensity,
      AutoAimStrength autoAim,
      bool leftHanded,
      bool oneHandedMode,
      bool autoUltimate,
      double joystickScale,
      String locale,
      bool notificationsEnabled,
      bool colorBlindMode,
      bool analyticsOptOut});
}

/// @nodoc
class __$$SettingsStateImplCopyWithImpl<$Res>
    extends _$SettingsStateCopyWithImpl<$Res, _$SettingsStateImpl>
    implements _$$SettingsStateImplCopyWith<$Res> {
  __$$SettingsStateImplCopyWithImpl(
      _$SettingsStateImpl _value, $Res Function(_$SettingsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? musicVolume = null,
    Object? sfxVolume = null,
    Object? uiVolume = null,
    Object? haptics = null,
    Object? screenShake = null,
    Object? damageNumbers = null,
    Object? reduceMotion = null,
    Object? graphicsQuality = null,
    Object? fpsCap = null,
    Object? particleDensity = null,
    Object? autoAim = null,
    Object? leftHanded = null,
    Object? oneHandedMode = null,
    Object? autoUltimate = null,
    Object? joystickScale = null,
    Object? locale = null,
    Object? notificationsEnabled = null,
    Object? colorBlindMode = null,
    Object? analyticsOptOut = null,
  }) {
    return _then(_$SettingsStateImpl(
      musicVolume: null == musicVolume
          ? _value.musicVolume
          : musicVolume // ignore: cast_nullable_to_non_nullable
              as double,
      sfxVolume: null == sfxVolume
          ? _value.sfxVolume
          : sfxVolume // ignore: cast_nullable_to_non_nullable
              as double,
      uiVolume: null == uiVolume
          ? _value.uiVolume
          : uiVolume // ignore: cast_nullable_to_non_nullable
              as double,
      haptics: null == haptics
          ? _value.haptics
          : haptics // ignore: cast_nullable_to_non_nullable
              as bool,
      screenShake: null == screenShake
          ? _value.screenShake
          : screenShake // ignore: cast_nullable_to_non_nullable
              as bool,
      damageNumbers: null == damageNumbers
          ? _value.damageNumbers
          : damageNumbers // ignore: cast_nullable_to_non_nullable
              as bool,
      reduceMotion: null == reduceMotion
          ? _value.reduceMotion
          : reduceMotion // ignore: cast_nullable_to_non_nullable
              as bool,
      graphicsQuality: null == graphicsQuality
          ? _value.graphicsQuality
          : graphicsQuality // ignore: cast_nullable_to_non_nullable
              as GraphicsQuality,
      fpsCap: null == fpsCap
          ? _value.fpsCap
          : fpsCap // ignore: cast_nullable_to_non_nullable
              as int,
      particleDensity: null == particleDensity
          ? _value.particleDensity
          : particleDensity // ignore: cast_nullable_to_non_nullable
              as double,
      autoAim: null == autoAim
          ? _value.autoAim
          : autoAim // ignore: cast_nullable_to_non_nullable
              as AutoAimStrength,
      leftHanded: null == leftHanded
          ? _value.leftHanded
          : leftHanded // ignore: cast_nullable_to_non_nullable
              as bool,
      oneHandedMode: null == oneHandedMode
          ? _value.oneHandedMode
          : oneHandedMode // ignore: cast_nullable_to_non_nullable
              as bool,
      autoUltimate: null == autoUltimate
          ? _value.autoUltimate
          : autoUltimate // ignore: cast_nullable_to_non_nullable
              as bool,
      joystickScale: null == joystickScale
          ? _value.joystickScale
          : joystickScale // ignore: cast_nullable_to_non_nullable
              as double,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      notificationsEnabled: null == notificationsEnabled
          ? _value.notificationsEnabled
          : notificationsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      colorBlindMode: null == colorBlindMode
          ? _value.colorBlindMode
          : colorBlindMode // ignore: cast_nullable_to_non_nullable
              as bool,
      analyticsOptOut: null == analyticsOptOut
          ? _value.analyticsOptOut
          : analyticsOptOut // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SettingsStateImpl implements _SettingsState {
  const _$SettingsStateImpl(
      {this.musicVolume = 0.7,
      this.sfxVolume = 1.0,
      this.uiVolume = 1.0,
      this.haptics = true,
      this.screenShake = true,
      this.damageNumbers = true,
      this.reduceMotion = false,
      this.graphicsQuality = GraphicsQuality.auto,
      this.fpsCap = 60,
      this.particleDensity = 1.0,
      this.autoAim = AutoAimStrength.standard,
      this.leftHanded = false,
      this.oneHandedMode = false,
      this.autoUltimate = false,
      this.joystickScale = 1.0,
      this.locale = 'en',
      this.notificationsEnabled = false,
      this.colorBlindMode = false,
      this.analyticsOptOut = false});

  factory _$SettingsStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SettingsStateImplFromJson(json);

  @override
  @JsonKey()
  final double musicVolume;
  @override
  @JsonKey()
  final double sfxVolume;
  @override
  @JsonKey()
  final double uiVolume;
  @override
  @JsonKey()
  final bool haptics;
  @override
  @JsonKey()
  final bool screenShake;
  @override
  @JsonKey()
  final bool damageNumbers;
  @override
  @JsonKey()
  final bool reduceMotion;
  @override
  @JsonKey()
  final GraphicsQuality graphicsQuality;
  @override
  @JsonKey()
  final int fpsCap;
  @override
  @JsonKey()
  final double particleDensity;
  @override
  @JsonKey()
  final AutoAimStrength autoAim;
  @override
  @JsonKey()
  final bool leftHanded;
  @override
  @JsonKey()
  final bool oneHandedMode;
  @override
  @JsonKey()
  final bool autoUltimate;
  @override
  @JsonKey()
  final double joystickScale;
  @override
  @JsonKey()
  final String locale;
  @override
  @JsonKey()
  final bool notificationsEnabled;

  /// Replaces the amber/crimson hue distinction with shape cues (dashed
  /// outlines vs solid hatching), since that distinction carries gameplay
  /// information. See docs/10-ui-ux.md §10.0.
  @override
  @JsonKey()
  final bool colorBlindMode;

  /// Honoured for real: this stops collection, not just transmission.
  @override
  @JsonKey()
  final bool analyticsOptOut;

  @override
  String toString() {
    return 'SettingsState(musicVolume: $musicVolume, sfxVolume: $sfxVolume, uiVolume: $uiVolume, haptics: $haptics, screenShake: $screenShake, damageNumbers: $damageNumbers, reduceMotion: $reduceMotion, graphicsQuality: $graphicsQuality, fpsCap: $fpsCap, particleDensity: $particleDensity, autoAim: $autoAim, leftHanded: $leftHanded, oneHandedMode: $oneHandedMode, autoUltimate: $autoUltimate, joystickScale: $joystickScale, locale: $locale, notificationsEnabled: $notificationsEnabled, colorBlindMode: $colorBlindMode, analyticsOptOut: $analyticsOptOut)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SettingsStateImpl &&
            (identical(other.musicVolume, musicVolume) ||
                other.musicVolume == musicVolume) &&
            (identical(other.sfxVolume, sfxVolume) ||
                other.sfxVolume == sfxVolume) &&
            (identical(other.uiVolume, uiVolume) ||
                other.uiVolume == uiVolume) &&
            (identical(other.haptics, haptics) || other.haptics == haptics) &&
            (identical(other.screenShake, screenShake) ||
                other.screenShake == screenShake) &&
            (identical(other.damageNumbers, damageNumbers) ||
                other.damageNumbers == damageNumbers) &&
            (identical(other.reduceMotion, reduceMotion) ||
                other.reduceMotion == reduceMotion) &&
            (identical(other.graphicsQuality, graphicsQuality) ||
                other.graphicsQuality == graphicsQuality) &&
            (identical(other.fpsCap, fpsCap) || other.fpsCap == fpsCap) &&
            (identical(other.particleDensity, particleDensity) ||
                other.particleDensity == particleDensity) &&
            (identical(other.autoAim, autoAim) || other.autoAim == autoAim) &&
            (identical(other.leftHanded, leftHanded) ||
                other.leftHanded == leftHanded) &&
            (identical(other.oneHandedMode, oneHandedMode) ||
                other.oneHandedMode == oneHandedMode) &&
            (identical(other.autoUltimate, autoUltimate) ||
                other.autoUltimate == autoUltimate) &&
            (identical(other.joystickScale, joystickScale) ||
                other.joystickScale == joystickScale) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.notificationsEnabled, notificationsEnabled) ||
                other.notificationsEnabled == notificationsEnabled) &&
            (identical(other.colorBlindMode, colorBlindMode) ||
                other.colorBlindMode == colorBlindMode) &&
            (identical(other.analyticsOptOut, analyticsOptOut) ||
                other.analyticsOptOut == analyticsOptOut));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        musicVolume,
        sfxVolume,
        uiVolume,
        haptics,
        screenShake,
        damageNumbers,
        reduceMotion,
        graphicsQuality,
        fpsCap,
        particleDensity,
        autoAim,
        leftHanded,
        oneHandedMode,
        autoUltimate,
        joystickScale,
        locale,
        notificationsEnabled,
        colorBlindMode,
        analyticsOptOut
      ]);

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SettingsStateImplCopyWith<_$SettingsStateImpl> get copyWith =>
      __$$SettingsStateImplCopyWithImpl<_$SettingsStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SettingsStateImplToJson(
      this,
    );
  }
}

abstract class _SettingsState implements SettingsState {
  const factory _SettingsState(
      {final double musicVolume,
      final double sfxVolume,
      final double uiVolume,
      final bool haptics,
      final bool screenShake,
      final bool damageNumbers,
      final bool reduceMotion,
      final GraphicsQuality graphicsQuality,
      final int fpsCap,
      final double particleDensity,
      final AutoAimStrength autoAim,
      final bool leftHanded,
      final bool oneHandedMode,
      final bool autoUltimate,
      final double joystickScale,
      final String locale,
      final bool notificationsEnabled,
      final bool colorBlindMode,
      final bool analyticsOptOut}) = _$SettingsStateImpl;

  factory _SettingsState.fromJson(Map<String, dynamic> json) =
      _$SettingsStateImpl.fromJson;

  @override
  double get musicVolume;
  @override
  double get sfxVolume;
  @override
  double get uiVolume;
  @override
  bool get haptics;
  @override
  bool get screenShake;
  @override
  bool get damageNumbers;
  @override
  bool get reduceMotion;
  @override
  GraphicsQuality get graphicsQuality;
  @override
  int get fpsCap;
  @override
  double get particleDensity;
  @override
  AutoAimStrength get autoAim;
  @override
  bool get leftHanded;
  @override
  bool get oneHandedMode;
  @override
  bool get autoUltimate;
  @override
  double get joystickScale;
  @override
  String get locale;
  @override
  bool get notificationsEnabled;

  /// Replaces the amber/crimson hue distinction with shape cues (dashed
  /// outlines vs solid hatching), since that distinction carries gameplay
  /// information. See docs/10-ui-ux.md §10.0.
  @override
  bool get colorBlindMode;

  /// Honoured for real: this stops collection, not just transmission.
  @override
  bool get analyticsOptOut;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SettingsStateImplCopyWith<_$SettingsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StatsState _$StatsStateFromJson(Map<String, dynamic> json) {
  return _StatsState.fromJson(json);
}

/// @nodoc
mixin _$StatsState {
  int get runsStarted => throw _privateConstructorUsedError;
  int get runsWon => throw _privateConstructorUsedError;
  int get runsLost => throw _privateConstructorUsedError;
  int get enemiesKilled => throw _privateConstructorUsedError;
  int get bossesKilled => throw _privateConstructorUsedError;
  int get elitesKilled => throw _privateConstructorUsedError;

  /// Drives Mark of the Thread, and is shown on every Victory screen.
  int get confluencesTriggered => throw _privateConstructorUsedError;
  int get maxConfluenceStack => throw _privateConstructorUsedError;

  /// Drives Mark of Stillness.
  int get tierThreeShotsLanded => throw _privateConstructorUsedError;

  /// Drives Mark of the Gale.
  int get maxMomentumReached => throw _privateConstructorUsedError;
  @DurationConverter()
  Duration get totalPlayTime => throw _privateConstructorUsedError;
  int get goldEarnedLifetime => throw _privateConstructorUsedError;
  int get gemsEarnedLifetime => throw _privateConstructorUsedError;
  Map<String, int> get heroUsageSeconds => throw _privateConstructorUsedError;

  /// Powers the "What got you" coaching on the defeat screen.
  Map<String, int> get deathsByEnemyId => throw _privateConstructorUsedError;

  /// Serializes this StatsState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StatsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatsStateCopyWith<StatsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatsStateCopyWith<$Res> {
  factory $StatsStateCopyWith(
          StatsState value, $Res Function(StatsState) then) =
      _$StatsStateCopyWithImpl<$Res, StatsState>;
  @useResult
  $Res call(
      {int runsStarted,
      int runsWon,
      int runsLost,
      int enemiesKilled,
      int bossesKilled,
      int elitesKilled,
      int confluencesTriggered,
      int maxConfluenceStack,
      int tierThreeShotsLanded,
      int maxMomentumReached,
      @DurationConverter() Duration totalPlayTime,
      int goldEarnedLifetime,
      int gemsEarnedLifetime,
      Map<String, int> heroUsageSeconds,
      Map<String, int> deathsByEnemyId});
}

/// @nodoc
class _$StatsStateCopyWithImpl<$Res, $Val extends StatsState>
    implements $StatsStateCopyWith<$Res> {
  _$StatsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StatsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? runsStarted = null,
    Object? runsWon = null,
    Object? runsLost = null,
    Object? enemiesKilled = null,
    Object? bossesKilled = null,
    Object? elitesKilled = null,
    Object? confluencesTriggered = null,
    Object? maxConfluenceStack = null,
    Object? tierThreeShotsLanded = null,
    Object? maxMomentumReached = null,
    Object? totalPlayTime = null,
    Object? goldEarnedLifetime = null,
    Object? gemsEarnedLifetime = null,
    Object? heroUsageSeconds = null,
    Object? deathsByEnemyId = null,
  }) {
    return _then(_value.copyWith(
      runsStarted: null == runsStarted
          ? _value.runsStarted
          : runsStarted // ignore: cast_nullable_to_non_nullable
              as int,
      runsWon: null == runsWon
          ? _value.runsWon
          : runsWon // ignore: cast_nullable_to_non_nullable
              as int,
      runsLost: null == runsLost
          ? _value.runsLost
          : runsLost // ignore: cast_nullable_to_non_nullable
              as int,
      enemiesKilled: null == enemiesKilled
          ? _value.enemiesKilled
          : enemiesKilled // ignore: cast_nullable_to_non_nullable
              as int,
      bossesKilled: null == bossesKilled
          ? _value.bossesKilled
          : bossesKilled // ignore: cast_nullable_to_non_nullable
              as int,
      elitesKilled: null == elitesKilled
          ? _value.elitesKilled
          : elitesKilled // ignore: cast_nullable_to_non_nullable
              as int,
      confluencesTriggered: null == confluencesTriggered
          ? _value.confluencesTriggered
          : confluencesTriggered // ignore: cast_nullable_to_non_nullable
              as int,
      maxConfluenceStack: null == maxConfluenceStack
          ? _value.maxConfluenceStack
          : maxConfluenceStack // ignore: cast_nullable_to_non_nullable
              as int,
      tierThreeShotsLanded: null == tierThreeShotsLanded
          ? _value.tierThreeShotsLanded
          : tierThreeShotsLanded // ignore: cast_nullable_to_non_nullable
              as int,
      maxMomentumReached: null == maxMomentumReached
          ? _value.maxMomentumReached
          : maxMomentumReached // ignore: cast_nullable_to_non_nullable
              as int,
      totalPlayTime: null == totalPlayTime
          ? _value.totalPlayTime
          : totalPlayTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      goldEarnedLifetime: null == goldEarnedLifetime
          ? _value.goldEarnedLifetime
          : goldEarnedLifetime // ignore: cast_nullable_to_non_nullable
              as int,
      gemsEarnedLifetime: null == gemsEarnedLifetime
          ? _value.gemsEarnedLifetime
          : gemsEarnedLifetime // ignore: cast_nullable_to_non_nullable
              as int,
      heroUsageSeconds: null == heroUsageSeconds
          ? _value.heroUsageSeconds
          : heroUsageSeconds // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      deathsByEnemyId: null == deathsByEnemyId
          ? _value.deathsByEnemyId
          : deathsByEnemyId // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StatsStateImplCopyWith<$Res>
    implements $StatsStateCopyWith<$Res> {
  factory _$$StatsStateImplCopyWith(
          _$StatsStateImpl value, $Res Function(_$StatsStateImpl) then) =
      __$$StatsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int runsStarted,
      int runsWon,
      int runsLost,
      int enemiesKilled,
      int bossesKilled,
      int elitesKilled,
      int confluencesTriggered,
      int maxConfluenceStack,
      int tierThreeShotsLanded,
      int maxMomentumReached,
      @DurationConverter() Duration totalPlayTime,
      int goldEarnedLifetime,
      int gemsEarnedLifetime,
      Map<String, int> heroUsageSeconds,
      Map<String, int> deathsByEnemyId});
}

/// @nodoc
class __$$StatsStateImplCopyWithImpl<$Res>
    extends _$StatsStateCopyWithImpl<$Res, _$StatsStateImpl>
    implements _$$StatsStateImplCopyWith<$Res> {
  __$$StatsStateImplCopyWithImpl(
      _$StatsStateImpl _value, $Res Function(_$StatsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of StatsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? runsStarted = null,
    Object? runsWon = null,
    Object? runsLost = null,
    Object? enemiesKilled = null,
    Object? bossesKilled = null,
    Object? elitesKilled = null,
    Object? confluencesTriggered = null,
    Object? maxConfluenceStack = null,
    Object? tierThreeShotsLanded = null,
    Object? maxMomentumReached = null,
    Object? totalPlayTime = null,
    Object? goldEarnedLifetime = null,
    Object? gemsEarnedLifetime = null,
    Object? heroUsageSeconds = null,
    Object? deathsByEnemyId = null,
  }) {
    return _then(_$StatsStateImpl(
      runsStarted: null == runsStarted
          ? _value.runsStarted
          : runsStarted // ignore: cast_nullable_to_non_nullable
              as int,
      runsWon: null == runsWon
          ? _value.runsWon
          : runsWon // ignore: cast_nullable_to_non_nullable
              as int,
      runsLost: null == runsLost
          ? _value.runsLost
          : runsLost // ignore: cast_nullable_to_non_nullable
              as int,
      enemiesKilled: null == enemiesKilled
          ? _value.enemiesKilled
          : enemiesKilled // ignore: cast_nullable_to_non_nullable
              as int,
      bossesKilled: null == bossesKilled
          ? _value.bossesKilled
          : bossesKilled // ignore: cast_nullable_to_non_nullable
              as int,
      elitesKilled: null == elitesKilled
          ? _value.elitesKilled
          : elitesKilled // ignore: cast_nullable_to_non_nullable
              as int,
      confluencesTriggered: null == confluencesTriggered
          ? _value.confluencesTriggered
          : confluencesTriggered // ignore: cast_nullable_to_non_nullable
              as int,
      maxConfluenceStack: null == maxConfluenceStack
          ? _value.maxConfluenceStack
          : maxConfluenceStack // ignore: cast_nullable_to_non_nullable
              as int,
      tierThreeShotsLanded: null == tierThreeShotsLanded
          ? _value.tierThreeShotsLanded
          : tierThreeShotsLanded // ignore: cast_nullable_to_non_nullable
              as int,
      maxMomentumReached: null == maxMomentumReached
          ? _value.maxMomentumReached
          : maxMomentumReached // ignore: cast_nullable_to_non_nullable
              as int,
      totalPlayTime: null == totalPlayTime
          ? _value.totalPlayTime
          : totalPlayTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      goldEarnedLifetime: null == goldEarnedLifetime
          ? _value.goldEarnedLifetime
          : goldEarnedLifetime // ignore: cast_nullable_to_non_nullable
              as int,
      gemsEarnedLifetime: null == gemsEarnedLifetime
          ? _value.gemsEarnedLifetime
          : gemsEarnedLifetime // ignore: cast_nullable_to_non_nullable
              as int,
      heroUsageSeconds: null == heroUsageSeconds
          ? _value._heroUsageSeconds
          : heroUsageSeconds // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      deathsByEnemyId: null == deathsByEnemyId
          ? _value._deathsByEnemyId
          : deathsByEnemyId // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StatsStateImpl extends _StatsState {
  const _$StatsStateImpl(
      {this.runsStarted = 0,
      this.runsWon = 0,
      this.runsLost = 0,
      this.enemiesKilled = 0,
      this.bossesKilled = 0,
      this.elitesKilled = 0,
      this.confluencesTriggered = 0,
      this.maxConfluenceStack = 0,
      this.tierThreeShotsLanded = 0,
      this.maxMomentumReached = 0,
      @DurationConverter() this.totalPlayTime = Duration.zero,
      this.goldEarnedLifetime = 0,
      this.gemsEarnedLifetime = 0,
      final Map<String, int> heroUsageSeconds = const <String, int>{},
      final Map<String, int> deathsByEnemyId = const <String, int>{}})
      : _heroUsageSeconds = heroUsageSeconds,
        _deathsByEnemyId = deathsByEnemyId,
        super._();

  factory _$StatsStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$StatsStateImplFromJson(json);

  @override
  @JsonKey()
  final int runsStarted;
  @override
  @JsonKey()
  final int runsWon;
  @override
  @JsonKey()
  final int runsLost;
  @override
  @JsonKey()
  final int enemiesKilled;
  @override
  @JsonKey()
  final int bossesKilled;
  @override
  @JsonKey()
  final int elitesKilled;

  /// Drives Mark of the Thread, and is shown on every Victory screen.
  @override
  @JsonKey()
  final int confluencesTriggered;
  @override
  @JsonKey()
  final int maxConfluenceStack;

  /// Drives Mark of Stillness.
  @override
  @JsonKey()
  final int tierThreeShotsLanded;

  /// Drives Mark of the Gale.
  @override
  @JsonKey()
  final int maxMomentumReached;
  @override
  @JsonKey()
  @DurationConverter()
  final Duration totalPlayTime;
  @override
  @JsonKey()
  final int goldEarnedLifetime;
  @override
  @JsonKey()
  final int gemsEarnedLifetime;
  final Map<String, int> _heroUsageSeconds;
  @override
  @JsonKey()
  Map<String, int> get heroUsageSeconds {
    if (_heroUsageSeconds is EqualUnmodifiableMapView) return _heroUsageSeconds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_heroUsageSeconds);
  }

  /// Powers the "What got you" coaching on the defeat screen.
  final Map<String, int> _deathsByEnemyId;

  /// Powers the "What got you" coaching on the defeat screen.
  @override
  @JsonKey()
  Map<String, int> get deathsByEnemyId {
    if (_deathsByEnemyId is EqualUnmodifiableMapView) return _deathsByEnemyId;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_deathsByEnemyId);
  }

  @override
  String toString() {
    return 'StatsState(runsStarted: $runsStarted, runsWon: $runsWon, runsLost: $runsLost, enemiesKilled: $enemiesKilled, bossesKilled: $bossesKilled, elitesKilled: $elitesKilled, confluencesTriggered: $confluencesTriggered, maxConfluenceStack: $maxConfluenceStack, tierThreeShotsLanded: $tierThreeShotsLanded, maxMomentumReached: $maxMomentumReached, totalPlayTime: $totalPlayTime, goldEarnedLifetime: $goldEarnedLifetime, gemsEarnedLifetime: $gemsEarnedLifetime, heroUsageSeconds: $heroUsageSeconds, deathsByEnemyId: $deathsByEnemyId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatsStateImpl &&
            (identical(other.runsStarted, runsStarted) ||
                other.runsStarted == runsStarted) &&
            (identical(other.runsWon, runsWon) || other.runsWon == runsWon) &&
            (identical(other.runsLost, runsLost) ||
                other.runsLost == runsLost) &&
            (identical(other.enemiesKilled, enemiesKilled) ||
                other.enemiesKilled == enemiesKilled) &&
            (identical(other.bossesKilled, bossesKilled) ||
                other.bossesKilled == bossesKilled) &&
            (identical(other.elitesKilled, elitesKilled) ||
                other.elitesKilled == elitesKilled) &&
            (identical(other.confluencesTriggered, confluencesTriggered) ||
                other.confluencesTriggered == confluencesTriggered) &&
            (identical(other.maxConfluenceStack, maxConfluenceStack) ||
                other.maxConfluenceStack == maxConfluenceStack) &&
            (identical(other.tierThreeShotsLanded, tierThreeShotsLanded) ||
                other.tierThreeShotsLanded == tierThreeShotsLanded) &&
            (identical(other.maxMomentumReached, maxMomentumReached) ||
                other.maxMomentumReached == maxMomentumReached) &&
            (identical(other.totalPlayTime, totalPlayTime) ||
                other.totalPlayTime == totalPlayTime) &&
            (identical(other.goldEarnedLifetime, goldEarnedLifetime) ||
                other.goldEarnedLifetime == goldEarnedLifetime) &&
            (identical(other.gemsEarnedLifetime, gemsEarnedLifetime) ||
                other.gemsEarnedLifetime == gemsEarnedLifetime) &&
            const DeepCollectionEquality()
                .equals(other._heroUsageSeconds, _heroUsageSeconds) &&
            const DeepCollectionEquality()
                .equals(other._deathsByEnemyId, _deathsByEnemyId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      runsStarted,
      runsWon,
      runsLost,
      enemiesKilled,
      bossesKilled,
      elitesKilled,
      confluencesTriggered,
      maxConfluenceStack,
      tierThreeShotsLanded,
      maxMomentumReached,
      totalPlayTime,
      goldEarnedLifetime,
      gemsEarnedLifetime,
      const DeepCollectionEquality().hash(_heroUsageSeconds),
      const DeepCollectionEquality().hash(_deathsByEnemyId));

  /// Create a copy of StatsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatsStateImplCopyWith<_$StatsStateImpl> get copyWith =>
      __$$StatsStateImplCopyWithImpl<_$StatsStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StatsStateImplToJson(
      this,
    );
  }
}

abstract class _StatsState extends StatsState {
  const factory _StatsState(
      {final int runsStarted,
      final int runsWon,
      final int runsLost,
      final int enemiesKilled,
      final int bossesKilled,
      final int elitesKilled,
      final int confluencesTriggered,
      final int maxConfluenceStack,
      final int tierThreeShotsLanded,
      final int maxMomentumReached,
      @DurationConverter() final Duration totalPlayTime,
      final int goldEarnedLifetime,
      final int gemsEarnedLifetime,
      final Map<String, int> heroUsageSeconds,
      final Map<String, int> deathsByEnemyId}) = _$StatsStateImpl;
  const _StatsState._() : super._();

  factory _StatsState.fromJson(Map<String, dynamic> json) =
      _$StatsStateImpl.fromJson;

  @override
  int get runsStarted;
  @override
  int get runsWon;
  @override
  int get runsLost;
  @override
  int get enemiesKilled;
  @override
  int get bossesKilled;
  @override
  int get elitesKilled;

  /// Drives Mark of the Thread, and is shown on every Victory screen.
  @override
  int get confluencesTriggered;
  @override
  int get maxConfluenceStack;

  /// Drives Mark of Stillness.
  @override
  int get tierThreeShotsLanded;

  /// Drives Mark of the Gale.
  @override
  int get maxMomentumReached;
  @override
  @DurationConverter()
  Duration get totalPlayTime;
  @override
  int get goldEarnedLifetime;
  @override
  int get gemsEarnedLifetime;
  @override
  Map<String, int> get heroUsageSeconds;

  /// Powers the "What got you" coaching on the defeat screen.
  @override
  Map<String, int> get deathsByEnemyId;

  /// Create a copy of StatsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatsStateImplCopyWith<_$StatsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
