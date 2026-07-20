// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_ops.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RewardsState _$RewardsStateFromJson(Map<String, dynamic> json) {
  return _RewardsState.fromJson(json);
}

/// @nodoc
mixin _$RewardsState {
  /// 1–28. Missing a day does not reset this — it simply does not advance.
  /// Streak-loss punishment is a dark pattern and is banned by Design Law 6.
  int get dailyCycleDay => throw _privateConstructorUsedError;
  @NullableUtcDateTimeConverter()
  DateTime? get lastDailyClaimAt => throw _privateConstructorUsedError;

  /// chestId -> when its free timer completes.
  Map<String, String> get chestTimers => throw _privateConstructorUsedError;

  /// chestType -> pulls since last guaranteed drop. Displayed in the UI, never
  /// hidden — see docs/02-economy.md §2.8.
  Map<String, int> get chestPityCounters => throw _privateConstructorUsedError;
  int get battlePassTier => throw _privateConstructorUsedError;
  int get battlePassXp => throw _privateConstructorUsedError;
  bool get battlePassPremium => throw _privateConstructorUsedError;
  int get battlePassSeasonId => throw _privateConstructorUsedError;
  Set<String> get claimedTierIds => throw _privateConstructorUsedError;

  /// Serializes this RewardsState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RewardsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RewardsStateCopyWith<RewardsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RewardsStateCopyWith<$Res> {
  factory $RewardsStateCopyWith(
          RewardsState value, $Res Function(RewardsState) then) =
      _$RewardsStateCopyWithImpl<$Res, RewardsState>;
  @useResult
  $Res call(
      {int dailyCycleDay,
      @NullableUtcDateTimeConverter() DateTime? lastDailyClaimAt,
      Map<String, String> chestTimers,
      Map<String, int> chestPityCounters,
      int battlePassTier,
      int battlePassXp,
      bool battlePassPremium,
      int battlePassSeasonId,
      Set<String> claimedTierIds});
}

/// @nodoc
class _$RewardsStateCopyWithImpl<$Res, $Val extends RewardsState>
    implements $RewardsStateCopyWith<$Res> {
  _$RewardsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RewardsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dailyCycleDay = null,
    Object? lastDailyClaimAt = freezed,
    Object? chestTimers = null,
    Object? chestPityCounters = null,
    Object? battlePassTier = null,
    Object? battlePassXp = null,
    Object? battlePassPremium = null,
    Object? battlePassSeasonId = null,
    Object? claimedTierIds = null,
  }) {
    return _then(_value.copyWith(
      dailyCycleDay: null == dailyCycleDay
          ? _value.dailyCycleDay
          : dailyCycleDay // ignore: cast_nullable_to_non_nullable
              as int,
      lastDailyClaimAt: freezed == lastDailyClaimAt
          ? _value.lastDailyClaimAt
          : lastDailyClaimAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      chestTimers: null == chestTimers
          ? _value.chestTimers
          : chestTimers // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      chestPityCounters: null == chestPityCounters
          ? _value.chestPityCounters
          : chestPityCounters // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      battlePassTier: null == battlePassTier
          ? _value.battlePassTier
          : battlePassTier // ignore: cast_nullable_to_non_nullable
              as int,
      battlePassXp: null == battlePassXp
          ? _value.battlePassXp
          : battlePassXp // ignore: cast_nullable_to_non_nullable
              as int,
      battlePassPremium: null == battlePassPremium
          ? _value.battlePassPremium
          : battlePassPremium // ignore: cast_nullable_to_non_nullable
              as bool,
      battlePassSeasonId: null == battlePassSeasonId
          ? _value.battlePassSeasonId
          : battlePassSeasonId // ignore: cast_nullable_to_non_nullable
              as int,
      claimedTierIds: null == claimedTierIds
          ? _value.claimedTierIds
          : claimedTierIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RewardsStateImplCopyWith<$Res>
    implements $RewardsStateCopyWith<$Res> {
  factory _$$RewardsStateImplCopyWith(
          _$RewardsStateImpl value, $Res Function(_$RewardsStateImpl) then) =
      __$$RewardsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int dailyCycleDay,
      @NullableUtcDateTimeConverter() DateTime? lastDailyClaimAt,
      Map<String, String> chestTimers,
      Map<String, int> chestPityCounters,
      int battlePassTier,
      int battlePassXp,
      bool battlePassPremium,
      int battlePassSeasonId,
      Set<String> claimedTierIds});
}

/// @nodoc
class __$$RewardsStateImplCopyWithImpl<$Res>
    extends _$RewardsStateCopyWithImpl<$Res, _$RewardsStateImpl>
    implements _$$RewardsStateImplCopyWith<$Res> {
  __$$RewardsStateImplCopyWithImpl(
      _$RewardsStateImpl _value, $Res Function(_$RewardsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of RewardsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dailyCycleDay = null,
    Object? lastDailyClaimAt = freezed,
    Object? chestTimers = null,
    Object? chestPityCounters = null,
    Object? battlePassTier = null,
    Object? battlePassXp = null,
    Object? battlePassPremium = null,
    Object? battlePassSeasonId = null,
    Object? claimedTierIds = null,
  }) {
    return _then(_$RewardsStateImpl(
      dailyCycleDay: null == dailyCycleDay
          ? _value.dailyCycleDay
          : dailyCycleDay // ignore: cast_nullable_to_non_nullable
              as int,
      lastDailyClaimAt: freezed == lastDailyClaimAt
          ? _value.lastDailyClaimAt
          : lastDailyClaimAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      chestTimers: null == chestTimers
          ? _value._chestTimers
          : chestTimers // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      chestPityCounters: null == chestPityCounters
          ? _value._chestPityCounters
          : chestPityCounters // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      battlePassTier: null == battlePassTier
          ? _value.battlePassTier
          : battlePassTier // ignore: cast_nullable_to_non_nullable
              as int,
      battlePassXp: null == battlePassXp
          ? _value.battlePassXp
          : battlePassXp // ignore: cast_nullable_to_non_nullable
              as int,
      battlePassPremium: null == battlePassPremium
          ? _value.battlePassPremium
          : battlePassPremium // ignore: cast_nullable_to_non_nullable
              as bool,
      battlePassSeasonId: null == battlePassSeasonId
          ? _value.battlePassSeasonId
          : battlePassSeasonId // ignore: cast_nullable_to_non_nullable
              as int,
      claimedTierIds: null == claimedTierIds
          ? _value._claimedTierIds
          : claimedTierIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RewardsStateImpl implements _RewardsState {
  const _$RewardsStateImpl(
      {this.dailyCycleDay = 1,
      @NullableUtcDateTimeConverter() this.lastDailyClaimAt,
      final Map<String, String> chestTimers = const <String, String>{},
      final Map<String, int> chestPityCounters = const <String, int>{},
      this.battlePassTier = 0,
      this.battlePassXp = 0,
      this.battlePassPremium = false,
      this.battlePassSeasonId = 0,
      final Set<String> claimedTierIds = const <String>{}})
      : _chestTimers = chestTimers,
        _chestPityCounters = chestPityCounters,
        _claimedTierIds = claimedTierIds;

  factory _$RewardsStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$RewardsStateImplFromJson(json);

  /// 1–28. Missing a day does not reset this — it simply does not advance.
  /// Streak-loss punishment is a dark pattern and is banned by Design Law 6.
  @override
  @JsonKey()
  final int dailyCycleDay;
  @override
  @NullableUtcDateTimeConverter()
  final DateTime? lastDailyClaimAt;

  /// chestId -> when its free timer completes.
  final Map<String, String> _chestTimers;

  /// chestId -> when its free timer completes.
  @override
  @JsonKey()
  Map<String, String> get chestTimers {
    if (_chestTimers is EqualUnmodifiableMapView) return _chestTimers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_chestTimers);
  }

  /// chestType -> pulls since last guaranteed drop. Displayed in the UI, never
  /// hidden — see docs/02-economy.md §2.8.
  final Map<String, int> _chestPityCounters;

  /// chestType -> pulls since last guaranteed drop. Displayed in the UI, never
  /// hidden — see docs/02-economy.md §2.8.
  @override
  @JsonKey()
  Map<String, int> get chestPityCounters {
    if (_chestPityCounters is EqualUnmodifiableMapView)
      return _chestPityCounters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_chestPityCounters);
  }

  @override
  @JsonKey()
  final int battlePassTier;
  @override
  @JsonKey()
  final int battlePassXp;
  @override
  @JsonKey()
  final bool battlePassPremium;
  @override
  @JsonKey()
  final int battlePassSeasonId;
  final Set<String> _claimedTierIds;
  @override
  @JsonKey()
  Set<String> get claimedTierIds {
    if (_claimedTierIds is EqualUnmodifiableSetView) return _claimedTierIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_claimedTierIds);
  }

  @override
  String toString() {
    return 'RewardsState(dailyCycleDay: $dailyCycleDay, lastDailyClaimAt: $lastDailyClaimAt, chestTimers: $chestTimers, chestPityCounters: $chestPityCounters, battlePassTier: $battlePassTier, battlePassXp: $battlePassXp, battlePassPremium: $battlePassPremium, battlePassSeasonId: $battlePassSeasonId, claimedTierIds: $claimedTierIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RewardsStateImpl &&
            (identical(other.dailyCycleDay, dailyCycleDay) ||
                other.dailyCycleDay == dailyCycleDay) &&
            (identical(other.lastDailyClaimAt, lastDailyClaimAt) ||
                other.lastDailyClaimAt == lastDailyClaimAt) &&
            const DeepCollectionEquality()
                .equals(other._chestTimers, _chestTimers) &&
            const DeepCollectionEquality()
                .equals(other._chestPityCounters, _chestPityCounters) &&
            (identical(other.battlePassTier, battlePassTier) ||
                other.battlePassTier == battlePassTier) &&
            (identical(other.battlePassXp, battlePassXp) ||
                other.battlePassXp == battlePassXp) &&
            (identical(other.battlePassPremium, battlePassPremium) ||
                other.battlePassPremium == battlePassPremium) &&
            (identical(other.battlePassSeasonId, battlePassSeasonId) ||
                other.battlePassSeasonId == battlePassSeasonId) &&
            const DeepCollectionEquality()
                .equals(other._claimedTierIds, _claimedTierIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      dailyCycleDay,
      lastDailyClaimAt,
      const DeepCollectionEquality().hash(_chestTimers),
      const DeepCollectionEquality().hash(_chestPityCounters),
      battlePassTier,
      battlePassXp,
      battlePassPremium,
      battlePassSeasonId,
      const DeepCollectionEquality().hash(_claimedTierIds));

  /// Create a copy of RewardsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RewardsStateImplCopyWith<_$RewardsStateImpl> get copyWith =>
      __$$RewardsStateImplCopyWithImpl<_$RewardsStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RewardsStateImplToJson(
      this,
    );
  }
}

abstract class _RewardsState implements RewardsState {
  const factory _RewardsState(
      {final int dailyCycleDay,
      @NullableUtcDateTimeConverter() final DateTime? lastDailyClaimAt,
      final Map<String, String> chestTimers,
      final Map<String, int> chestPityCounters,
      final int battlePassTier,
      final int battlePassXp,
      final bool battlePassPremium,
      final int battlePassSeasonId,
      final Set<String> claimedTierIds}) = _$RewardsStateImpl;

  factory _RewardsState.fromJson(Map<String, dynamic> json) =
      _$RewardsStateImpl.fromJson;

  /// 1–28. Missing a day does not reset this — it simply does not advance.
  /// Streak-loss punishment is a dark pattern and is banned by Design Law 6.
  @override
  int get dailyCycleDay;
  @override
  @NullableUtcDateTimeConverter()
  DateTime? get lastDailyClaimAt;

  /// chestId -> when its free timer completes.
  @override
  Map<String, String> get chestTimers;

  /// chestType -> pulls since last guaranteed drop. Displayed in the UI, never
  /// hidden — see docs/02-economy.md §2.8.
  @override
  Map<String, int> get chestPityCounters;
  @override
  int get battlePassTier;
  @override
  int get battlePassXp;
  @override
  bool get battlePassPremium;
  @override
  int get battlePassSeasonId;
  @override
  Set<String> get claimedTierIds;

  /// Create a copy of RewardsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RewardsStateImplCopyWith<_$RewardsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

QuestInstance _$QuestInstanceFromJson(Map<String, dynamic> json) {
  return _QuestInstance.fromJson(json);
}

/// @nodoc
mixin _$QuestInstance {
  String get questId => throw _privateConstructorUsedError;
  int get progress => throw _privateConstructorUsedError;
  int get target => throw _privateConstructorUsedError;
  bool get claimed => throw _privateConstructorUsedError;

  /// Serializes this QuestInstance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuestInstance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestInstanceCopyWith<QuestInstance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestInstanceCopyWith<$Res> {
  factory $QuestInstanceCopyWith(
          QuestInstance value, $Res Function(QuestInstance) then) =
      _$QuestInstanceCopyWithImpl<$Res, QuestInstance>;
  @useResult
  $Res call({String questId, int progress, int target, bool claimed});
}

/// @nodoc
class _$QuestInstanceCopyWithImpl<$Res, $Val extends QuestInstance>
    implements $QuestInstanceCopyWith<$Res> {
  _$QuestInstanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestInstance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questId = null,
    Object? progress = null,
    Object? target = null,
    Object? claimed = null,
  }) {
    return _then(_value.copyWith(
      questId: null == questId
          ? _value.questId
          : questId // ignore: cast_nullable_to_non_nullable
              as String,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
      target: null == target
          ? _value.target
          : target // ignore: cast_nullable_to_non_nullable
              as int,
      claimed: null == claimed
          ? _value.claimed
          : claimed // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuestInstanceImplCopyWith<$Res>
    implements $QuestInstanceCopyWith<$Res> {
  factory _$$QuestInstanceImplCopyWith(
          _$QuestInstanceImpl value, $Res Function(_$QuestInstanceImpl) then) =
      __$$QuestInstanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String questId, int progress, int target, bool claimed});
}

/// @nodoc
class __$$QuestInstanceImplCopyWithImpl<$Res>
    extends _$QuestInstanceCopyWithImpl<$Res, _$QuestInstanceImpl>
    implements _$$QuestInstanceImplCopyWith<$Res> {
  __$$QuestInstanceImplCopyWithImpl(
      _$QuestInstanceImpl _value, $Res Function(_$QuestInstanceImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestInstance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questId = null,
    Object? progress = null,
    Object? target = null,
    Object? claimed = null,
  }) {
    return _then(_$QuestInstanceImpl(
      questId: null == questId
          ? _value.questId
          : questId // ignore: cast_nullable_to_non_nullable
              as String,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
      target: null == target
          ? _value.target
          : target // ignore: cast_nullable_to_non_nullable
              as int,
      claimed: null == claimed
          ? _value.claimed
          : claimed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QuestInstanceImpl extends _QuestInstance {
  const _$QuestInstanceImpl(
      {required this.questId,
      this.progress = 0,
      required this.target,
      this.claimed = false})
      : super._();

  factory _$QuestInstanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuestInstanceImplFromJson(json);

  @override
  final String questId;
  @override
  @JsonKey()
  final int progress;
  @override
  final int target;
  @override
  @JsonKey()
  final bool claimed;

  @override
  String toString() {
    return 'QuestInstance(questId: $questId, progress: $progress, target: $target, claimed: $claimed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestInstanceImpl &&
            (identical(other.questId, questId) || other.questId == questId) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.target, target) || other.target == target) &&
            (identical(other.claimed, claimed) || other.claimed == claimed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, questId, progress, target, claimed);

  /// Create a copy of QuestInstance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestInstanceImplCopyWith<_$QuestInstanceImpl> get copyWith =>
      __$$QuestInstanceImplCopyWithImpl<_$QuestInstanceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuestInstanceImplToJson(
      this,
    );
  }
}

abstract class _QuestInstance extends QuestInstance {
  const factory _QuestInstance(
      {required final String questId,
      final int progress,
      required final int target,
      final bool claimed}) = _$QuestInstanceImpl;
  const _QuestInstance._() : super._();

  factory _QuestInstance.fromJson(Map<String, dynamic> json) =
      _$QuestInstanceImpl.fromJson;

  @override
  String get questId;
  @override
  int get progress;
  @override
  int get target;
  @override
  bool get claimed;

  /// Create a copy of QuestInstance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestInstanceImplCopyWith<_$QuestInstanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

QuestState _$QuestStateFromJson(Map<String, dynamic> json) {
  return _QuestState.fromJson(json);
}

/// @nodoc
mixin _$QuestState {
  List<QuestInstance> get daily => throw _privateConstructorUsedError;
  List<QuestInstance> get weekly => throw _privateConstructorUsedError;
  @NullableUtcDateTimeConverter()
  DateTime? get dailyResetAt => throw _privateConstructorUsedError;
  @NullableUtcDateTimeConverter()
  DateTime? get weeklyResetAt => throw _privateConstructorUsedError;

  /// Serializes this QuestState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuestState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestStateCopyWith<QuestState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestStateCopyWith<$Res> {
  factory $QuestStateCopyWith(
          QuestState value, $Res Function(QuestState) then) =
      _$QuestStateCopyWithImpl<$Res, QuestState>;
  @useResult
  $Res call(
      {List<QuestInstance> daily,
      List<QuestInstance> weekly,
      @NullableUtcDateTimeConverter() DateTime? dailyResetAt,
      @NullableUtcDateTimeConverter() DateTime? weeklyResetAt});
}

/// @nodoc
class _$QuestStateCopyWithImpl<$Res, $Val extends QuestState>
    implements $QuestStateCopyWith<$Res> {
  _$QuestStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? daily = null,
    Object? weekly = null,
    Object? dailyResetAt = freezed,
    Object? weeklyResetAt = freezed,
  }) {
    return _then(_value.copyWith(
      daily: null == daily
          ? _value.daily
          : daily // ignore: cast_nullable_to_non_nullable
              as List<QuestInstance>,
      weekly: null == weekly
          ? _value.weekly
          : weekly // ignore: cast_nullable_to_non_nullable
              as List<QuestInstance>,
      dailyResetAt: freezed == dailyResetAt
          ? _value.dailyResetAt
          : dailyResetAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      weeklyResetAt: freezed == weeklyResetAt
          ? _value.weeklyResetAt
          : weeklyResetAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuestStateImplCopyWith<$Res>
    implements $QuestStateCopyWith<$Res> {
  factory _$$QuestStateImplCopyWith(
          _$QuestStateImpl value, $Res Function(_$QuestStateImpl) then) =
      __$$QuestStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<QuestInstance> daily,
      List<QuestInstance> weekly,
      @NullableUtcDateTimeConverter() DateTime? dailyResetAt,
      @NullableUtcDateTimeConverter() DateTime? weeklyResetAt});
}

/// @nodoc
class __$$QuestStateImplCopyWithImpl<$Res>
    extends _$QuestStateCopyWithImpl<$Res, _$QuestStateImpl>
    implements _$$QuestStateImplCopyWith<$Res> {
  __$$QuestStateImplCopyWithImpl(
      _$QuestStateImpl _value, $Res Function(_$QuestStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? daily = null,
    Object? weekly = null,
    Object? dailyResetAt = freezed,
    Object? weeklyResetAt = freezed,
  }) {
    return _then(_$QuestStateImpl(
      daily: null == daily
          ? _value._daily
          : daily // ignore: cast_nullable_to_non_nullable
              as List<QuestInstance>,
      weekly: null == weekly
          ? _value._weekly
          : weekly // ignore: cast_nullable_to_non_nullable
              as List<QuestInstance>,
      dailyResetAt: freezed == dailyResetAt
          ? _value.dailyResetAt
          : dailyResetAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      weeklyResetAt: freezed == weeklyResetAt
          ? _value.weeklyResetAt
          : weeklyResetAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QuestStateImpl implements _QuestState {
  const _$QuestStateImpl(
      {final List<QuestInstance> daily = const <QuestInstance>[],
      final List<QuestInstance> weekly = const <QuestInstance>[],
      @NullableUtcDateTimeConverter() this.dailyResetAt,
      @NullableUtcDateTimeConverter() this.weeklyResetAt})
      : _daily = daily,
        _weekly = weekly;

  factory _$QuestStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuestStateImplFromJson(json);

  final List<QuestInstance> _daily;
  @override
  @JsonKey()
  List<QuestInstance> get daily {
    if (_daily is EqualUnmodifiableListView) return _daily;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_daily);
  }

  final List<QuestInstance> _weekly;
  @override
  @JsonKey()
  List<QuestInstance> get weekly {
    if (_weekly is EqualUnmodifiableListView) return _weekly;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weekly);
  }

  @override
  @NullableUtcDateTimeConverter()
  final DateTime? dailyResetAt;
  @override
  @NullableUtcDateTimeConverter()
  final DateTime? weeklyResetAt;

  @override
  String toString() {
    return 'QuestState(daily: $daily, weekly: $weekly, dailyResetAt: $dailyResetAt, weeklyResetAt: $weeklyResetAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestStateImpl &&
            const DeepCollectionEquality().equals(other._daily, _daily) &&
            const DeepCollectionEquality().equals(other._weekly, _weekly) &&
            (identical(other.dailyResetAt, dailyResetAt) ||
                other.dailyResetAt == dailyResetAt) &&
            (identical(other.weeklyResetAt, weeklyResetAt) ||
                other.weeklyResetAt == weeklyResetAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_daily),
      const DeepCollectionEquality().hash(_weekly),
      dailyResetAt,
      weeklyResetAt);

  /// Create a copy of QuestState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestStateImplCopyWith<_$QuestStateImpl> get copyWith =>
      __$$QuestStateImplCopyWithImpl<_$QuestStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuestStateImplToJson(
      this,
    );
  }
}

abstract class _QuestState implements QuestState {
  const factory _QuestState(
          {final List<QuestInstance> daily,
          final List<QuestInstance> weekly,
          @NullableUtcDateTimeConverter() final DateTime? dailyResetAt,
          @NullableUtcDateTimeConverter() final DateTime? weeklyResetAt}) =
      _$QuestStateImpl;

  factory _QuestState.fromJson(Map<String, dynamic> json) =
      _$QuestStateImpl.fromJson;

  @override
  List<QuestInstance> get daily;
  @override
  List<QuestInstance> get weekly;
  @override
  @NullableUtcDateTimeConverter()
  DateTime? get dailyResetAt;
  @override
  @NullableUtcDateTimeConverter()
  DateTime? get weeklyResetAt;

  /// Create a copy of QuestState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestStateImplCopyWith<_$QuestStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PurchaseRecord _$PurchaseRecordFromJson(Map<String, dynamic> json) {
  return _PurchaseRecord.fromJson(json);
}

/// @nodoc
mixin _$PurchaseRecord {
  String get sku => throw _privateConstructorUsedError;
  String get transactionId => throw _privateConstructorUsedError;
  String get platform => throw _privateConstructorUsedError;
  @UtcDateTimeConverter()
  DateTime get purchasedAt => throw _privateConstructorUsedError;
  bool get verified => throw _privateConstructorUsedError;

  /// Serializes this PurchaseRecord to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PurchaseRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PurchaseRecordCopyWith<PurchaseRecord> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PurchaseRecordCopyWith<$Res> {
  factory $PurchaseRecordCopyWith(
          PurchaseRecord value, $Res Function(PurchaseRecord) then) =
      _$PurchaseRecordCopyWithImpl<$Res, PurchaseRecord>;
  @useResult
  $Res call(
      {String sku,
      String transactionId,
      String platform,
      @UtcDateTimeConverter() DateTime purchasedAt,
      bool verified});
}

/// @nodoc
class _$PurchaseRecordCopyWithImpl<$Res, $Val extends PurchaseRecord>
    implements $PurchaseRecordCopyWith<$Res> {
  _$PurchaseRecordCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PurchaseRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sku = null,
    Object? transactionId = null,
    Object? platform = null,
    Object? purchasedAt = null,
    Object? verified = null,
  }) {
    return _then(_value.copyWith(
      sku: null == sku
          ? _value.sku
          : sku // ignore: cast_nullable_to_non_nullable
              as String,
      transactionId: null == transactionId
          ? _value.transactionId
          : transactionId // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      purchasedAt: null == purchasedAt
          ? _value.purchasedAt
          : purchasedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      verified: null == verified
          ? _value.verified
          : verified // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PurchaseRecordImplCopyWith<$Res>
    implements $PurchaseRecordCopyWith<$Res> {
  factory _$$PurchaseRecordImplCopyWith(_$PurchaseRecordImpl value,
          $Res Function(_$PurchaseRecordImpl) then) =
      __$$PurchaseRecordImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String sku,
      String transactionId,
      String platform,
      @UtcDateTimeConverter() DateTime purchasedAt,
      bool verified});
}

/// @nodoc
class __$$PurchaseRecordImplCopyWithImpl<$Res>
    extends _$PurchaseRecordCopyWithImpl<$Res, _$PurchaseRecordImpl>
    implements _$$PurchaseRecordImplCopyWith<$Res> {
  __$$PurchaseRecordImplCopyWithImpl(
      _$PurchaseRecordImpl _value, $Res Function(_$PurchaseRecordImpl) _then)
      : super(_value, _then);

  /// Create a copy of PurchaseRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sku = null,
    Object? transactionId = null,
    Object? platform = null,
    Object? purchasedAt = null,
    Object? verified = null,
  }) {
    return _then(_$PurchaseRecordImpl(
      sku: null == sku
          ? _value.sku
          : sku // ignore: cast_nullable_to_non_nullable
              as String,
      transactionId: null == transactionId
          ? _value.transactionId
          : transactionId // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      purchasedAt: null == purchasedAt
          ? _value.purchasedAt
          : purchasedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      verified: null == verified
          ? _value.verified
          : verified // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PurchaseRecordImpl implements _PurchaseRecord {
  const _$PurchaseRecordImpl(
      {required this.sku,
      required this.transactionId,
      required this.platform,
      @UtcDateTimeConverter() required this.purchasedAt,
      this.verified = false});

  factory _$PurchaseRecordImpl.fromJson(Map<String, dynamic> json) =>
      _$$PurchaseRecordImplFromJson(json);

  @override
  final String sku;
  @override
  final String transactionId;
  @override
  final String platform;
  @override
  @UtcDateTimeConverter()
  final DateTime purchasedAt;
  @override
  @JsonKey()
  final bool verified;

  @override
  String toString() {
    return 'PurchaseRecord(sku: $sku, transactionId: $transactionId, platform: $platform, purchasedAt: $purchasedAt, verified: $verified)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PurchaseRecordImpl &&
            (identical(other.sku, sku) || other.sku == sku) &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.purchasedAt, purchasedAt) ||
                other.purchasedAt == purchasedAt) &&
            (identical(other.verified, verified) ||
                other.verified == verified));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, sku, transactionId, platform, purchasedAt, verified);

  /// Create a copy of PurchaseRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PurchaseRecordImplCopyWith<_$PurchaseRecordImpl> get copyWith =>
      __$$PurchaseRecordImplCopyWithImpl<_$PurchaseRecordImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PurchaseRecordImplToJson(
      this,
    );
  }
}

abstract class _PurchaseRecord implements PurchaseRecord {
  const factory _PurchaseRecord(
      {required final String sku,
      required final String transactionId,
      required final String platform,
      @UtcDateTimeConverter() required final DateTime purchasedAt,
      final bool verified}) = _$PurchaseRecordImpl;

  factory _PurchaseRecord.fromJson(Map<String, dynamic> json) =
      _$PurchaseRecordImpl.fromJson;

  @override
  String get sku;
  @override
  String get transactionId;
  @override
  String get platform;
  @override
  @UtcDateTimeConverter()
  DateTime get purchasedAt;
  @override
  bool get verified;

  /// Create a copy of PurchaseRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PurchaseRecordImplCopyWith<_$PurchaseRecordImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SubscriptionState _$SubscriptionStateFromJson(Map<String, dynamic> json) {
  return _SubscriptionState.fromJson(json);
}

/// @nodoc
mixin _$SubscriptionState {
  String get productId => throw _privateConstructorUsedError;
  @UtcDateTimeConverter()
  DateTime get startedAt => throw _privateConstructorUsedError;
  @UtcDateTimeConverter()
  DateTime get expiresAt => throw _privateConstructorUsedError;
  bool get autoRenewing => throw _privateConstructorUsedError;
  bool get inGracePeriod => throw _privateConstructorUsedError;
  String? get latestReceiptHash => throw _privateConstructorUsedError;

  /// Serializes this SubscriptionState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SubscriptionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubscriptionStateCopyWith<SubscriptionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubscriptionStateCopyWith<$Res> {
  factory $SubscriptionStateCopyWith(
          SubscriptionState value, $Res Function(SubscriptionState) then) =
      _$SubscriptionStateCopyWithImpl<$Res, SubscriptionState>;
  @useResult
  $Res call(
      {String productId,
      @UtcDateTimeConverter() DateTime startedAt,
      @UtcDateTimeConverter() DateTime expiresAt,
      bool autoRenewing,
      bool inGracePeriod,
      String? latestReceiptHash});
}

/// @nodoc
class _$SubscriptionStateCopyWithImpl<$Res, $Val extends SubscriptionState>
    implements $SubscriptionStateCopyWith<$Res> {
  _$SubscriptionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SubscriptionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? startedAt = null,
    Object? expiresAt = null,
    Object? autoRenewing = null,
    Object? inGracePeriod = null,
    Object? latestReceiptHash = freezed,
  }) {
    return _then(_value.copyWith(
      productId: null == productId
          ? _value.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      autoRenewing: null == autoRenewing
          ? _value.autoRenewing
          : autoRenewing // ignore: cast_nullable_to_non_nullable
              as bool,
      inGracePeriod: null == inGracePeriod
          ? _value.inGracePeriod
          : inGracePeriod // ignore: cast_nullable_to_non_nullable
              as bool,
      latestReceiptHash: freezed == latestReceiptHash
          ? _value.latestReceiptHash
          : latestReceiptHash // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SubscriptionStateImplCopyWith<$Res>
    implements $SubscriptionStateCopyWith<$Res> {
  factory _$$SubscriptionStateImplCopyWith(_$SubscriptionStateImpl value,
          $Res Function(_$SubscriptionStateImpl) then) =
      __$$SubscriptionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String productId,
      @UtcDateTimeConverter() DateTime startedAt,
      @UtcDateTimeConverter() DateTime expiresAt,
      bool autoRenewing,
      bool inGracePeriod,
      String? latestReceiptHash});
}

/// @nodoc
class __$$SubscriptionStateImplCopyWithImpl<$Res>
    extends _$SubscriptionStateCopyWithImpl<$Res, _$SubscriptionStateImpl>
    implements _$$SubscriptionStateImplCopyWith<$Res> {
  __$$SubscriptionStateImplCopyWithImpl(_$SubscriptionStateImpl _value,
      $Res Function(_$SubscriptionStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SubscriptionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? startedAt = null,
    Object? expiresAt = null,
    Object? autoRenewing = null,
    Object? inGracePeriod = null,
    Object? latestReceiptHash = freezed,
  }) {
    return _then(_$SubscriptionStateImpl(
      productId: null == productId
          ? _value.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      autoRenewing: null == autoRenewing
          ? _value.autoRenewing
          : autoRenewing // ignore: cast_nullable_to_non_nullable
              as bool,
      inGracePeriod: null == inGracePeriod
          ? _value.inGracePeriod
          : inGracePeriod // ignore: cast_nullable_to_non_nullable
              as bool,
      latestReceiptHash: freezed == latestReceiptHash
          ? _value.latestReceiptHash
          : latestReceiptHash // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SubscriptionStateImpl extends _SubscriptionState {
  const _$SubscriptionStateImpl(
      {required this.productId,
      @UtcDateTimeConverter() required this.startedAt,
      @UtcDateTimeConverter() required this.expiresAt,
      this.autoRenewing = true,
      this.inGracePeriod = false,
      this.latestReceiptHash})
      : super._();

  factory _$SubscriptionStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SubscriptionStateImplFromJson(json);

  @override
  final String productId;
  @override
  @UtcDateTimeConverter()
  final DateTime startedAt;
  @override
  @UtcDateTimeConverter()
  final DateTime expiresAt;
  @override
  @JsonKey()
  final bool autoRenewing;
  @override
  @JsonKey()
  final bool inGracePeriod;
  @override
  final String? latestReceiptHash;

  @override
  String toString() {
    return 'SubscriptionState(productId: $productId, startedAt: $startedAt, expiresAt: $expiresAt, autoRenewing: $autoRenewing, inGracePeriod: $inGracePeriod, latestReceiptHash: $latestReceiptHash)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubscriptionStateImpl &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.autoRenewing, autoRenewing) ||
                other.autoRenewing == autoRenewing) &&
            (identical(other.inGracePeriod, inGracePeriod) ||
                other.inGracePeriod == inGracePeriod) &&
            (identical(other.latestReceiptHash, latestReceiptHash) ||
                other.latestReceiptHash == latestReceiptHash));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, productId, startedAt, expiresAt,
      autoRenewing, inGracePeriod, latestReceiptHash);

  /// Create a copy of SubscriptionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubscriptionStateImplCopyWith<_$SubscriptionStateImpl> get copyWith =>
      __$$SubscriptionStateImplCopyWithImpl<_$SubscriptionStateImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SubscriptionStateImplToJson(
      this,
    );
  }
}

abstract class _SubscriptionState extends SubscriptionState {
  const factory _SubscriptionState(
      {required final String productId,
      @UtcDateTimeConverter() required final DateTime startedAt,
      @UtcDateTimeConverter() required final DateTime expiresAt,
      final bool autoRenewing,
      final bool inGracePeriod,
      final String? latestReceiptHash}) = _$SubscriptionStateImpl;
  const _SubscriptionState._() : super._();

  factory _SubscriptionState.fromJson(Map<String, dynamic> json) =
      _$SubscriptionStateImpl.fromJson;

  @override
  String get productId;
  @override
  @UtcDateTimeConverter()
  DateTime get startedAt;
  @override
  @UtcDateTimeConverter()
  DateTime get expiresAt;
  @override
  bool get autoRenewing;
  @override
  bool get inGracePeriod;
  @override
  String? get latestReceiptHash;

  /// Create a copy of SubscriptionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubscriptionStateImplCopyWith<_$SubscriptionStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PurchaseState _$PurchaseStateFromJson(Map<String, dynamic> json) {
  return _PurchaseState.fromJson(json);
}

/// @nodoc
mixin _$PurchaseState {
  List<PurchaseRecord> get history => throw _privateConstructorUsedError;
  bool get removeAdsOwned => throw _privateConstructorUsedError;

  /// Warden's Pact.
  SubscriptionState? get pact => throw _privateConstructorUsedError;
  Set<String> get consumedOneTimeSkus => throw _privateConstructorUsedError;

  /// Local only. Deliberately never synced to the cloud and never sold —
  /// see docs/13-database.md §13.10.
  double get lifetimeSpendUsd => throw _privateConstructorUsedError;

  /// Serializes this PurchaseState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PurchaseState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PurchaseStateCopyWith<PurchaseState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PurchaseStateCopyWith<$Res> {
  factory $PurchaseStateCopyWith(
          PurchaseState value, $Res Function(PurchaseState) then) =
      _$PurchaseStateCopyWithImpl<$Res, PurchaseState>;
  @useResult
  $Res call(
      {List<PurchaseRecord> history,
      bool removeAdsOwned,
      SubscriptionState? pact,
      Set<String> consumedOneTimeSkus,
      double lifetimeSpendUsd});

  $SubscriptionStateCopyWith<$Res>? get pact;
}

/// @nodoc
class _$PurchaseStateCopyWithImpl<$Res, $Val extends PurchaseState>
    implements $PurchaseStateCopyWith<$Res> {
  _$PurchaseStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PurchaseState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? history = null,
    Object? removeAdsOwned = null,
    Object? pact = freezed,
    Object? consumedOneTimeSkus = null,
    Object? lifetimeSpendUsd = null,
  }) {
    return _then(_value.copyWith(
      history: null == history
          ? _value.history
          : history // ignore: cast_nullable_to_non_nullable
              as List<PurchaseRecord>,
      removeAdsOwned: null == removeAdsOwned
          ? _value.removeAdsOwned
          : removeAdsOwned // ignore: cast_nullable_to_non_nullable
              as bool,
      pact: freezed == pact
          ? _value.pact
          : pact // ignore: cast_nullable_to_non_nullable
              as SubscriptionState?,
      consumedOneTimeSkus: null == consumedOneTimeSkus
          ? _value.consumedOneTimeSkus
          : consumedOneTimeSkus // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      lifetimeSpendUsd: null == lifetimeSpendUsd
          ? _value.lifetimeSpendUsd
          : lifetimeSpendUsd // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }

  /// Create a copy of PurchaseState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SubscriptionStateCopyWith<$Res>? get pact {
    if (_value.pact == null) {
      return null;
    }

    return $SubscriptionStateCopyWith<$Res>(_value.pact!, (value) {
      return _then(_value.copyWith(pact: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PurchaseStateImplCopyWith<$Res>
    implements $PurchaseStateCopyWith<$Res> {
  factory _$$PurchaseStateImplCopyWith(
          _$PurchaseStateImpl value, $Res Function(_$PurchaseStateImpl) then) =
      __$$PurchaseStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<PurchaseRecord> history,
      bool removeAdsOwned,
      SubscriptionState? pact,
      Set<String> consumedOneTimeSkus,
      double lifetimeSpendUsd});

  @override
  $SubscriptionStateCopyWith<$Res>? get pact;
}

/// @nodoc
class __$$PurchaseStateImplCopyWithImpl<$Res>
    extends _$PurchaseStateCopyWithImpl<$Res, _$PurchaseStateImpl>
    implements _$$PurchaseStateImplCopyWith<$Res> {
  __$$PurchaseStateImplCopyWithImpl(
      _$PurchaseStateImpl _value, $Res Function(_$PurchaseStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of PurchaseState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? history = null,
    Object? removeAdsOwned = null,
    Object? pact = freezed,
    Object? consumedOneTimeSkus = null,
    Object? lifetimeSpendUsd = null,
  }) {
    return _then(_$PurchaseStateImpl(
      history: null == history
          ? _value._history
          : history // ignore: cast_nullable_to_non_nullable
              as List<PurchaseRecord>,
      removeAdsOwned: null == removeAdsOwned
          ? _value.removeAdsOwned
          : removeAdsOwned // ignore: cast_nullable_to_non_nullable
              as bool,
      pact: freezed == pact
          ? _value.pact
          : pact // ignore: cast_nullable_to_non_nullable
              as SubscriptionState?,
      consumedOneTimeSkus: null == consumedOneTimeSkus
          ? _value._consumedOneTimeSkus
          : consumedOneTimeSkus // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      lifetimeSpendUsd: null == lifetimeSpendUsd
          ? _value.lifetimeSpendUsd
          : lifetimeSpendUsd // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PurchaseStateImpl implements _PurchaseState {
  const _$PurchaseStateImpl(
      {final List<PurchaseRecord> history = const <PurchaseRecord>[],
      this.removeAdsOwned = false,
      this.pact,
      final Set<String> consumedOneTimeSkus = const <String>{},
      this.lifetimeSpendUsd = 0})
      : _history = history,
        _consumedOneTimeSkus = consumedOneTimeSkus;

  factory _$PurchaseStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PurchaseStateImplFromJson(json);

  final List<PurchaseRecord> _history;
  @override
  @JsonKey()
  List<PurchaseRecord> get history {
    if (_history is EqualUnmodifiableListView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_history);
  }

  @override
  @JsonKey()
  final bool removeAdsOwned;

  /// Warden's Pact.
  @override
  final SubscriptionState? pact;
  final Set<String> _consumedOneTimeSkus;
  @override
  @JsonKey()
  Set<String> get consumedOneTimeSkus {
    if (_consumedOneTimeSkus is EqualUnmodifiableSetView)
      return _consumedOneTimeSkus;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_consumedOneTimeSkus);
  }

  /// Local only. Deliberately never synced to the cloud and never sold —
  /// see docs/13-database.md §13.10.
  @override
  @JsonKey()
  final double lifetimeSpendUsd;

  @override
  String toString() {
    return 'PurchaseState(history: $history, removeAdsOwned: $removeAdsOwned, pact: $pact, consumedOneTimeSkus: $consumedOneTimeSkus, lifetimeSpendUsd: $lifetimeSpendUsd)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PurchaseStateImpl &&
            const DeepCollectionEquality().equals(other._history, _history) &&
            (identical(other.removeAdsOwned, removeAdsOwned) ||
                other.removeAdsOwned == removeAdsOwned) &&
            (identical(other.pact, pact) || other.pact == pact) &&
            const DeepCollectionEquality()
                .equals(other._consumedOneTimeSkus, _consumedOneTimeSkus) &&
            (identical(other.lifetimeSpendUsd, lifetimeSpendUsd) ||
                other.lifetimeSpendUsd == lifetimeSpendUsd));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_history),
      removeAdsOwned,
      pact,
      const DeepCollectionEquality().hash(_consumedOneTimeSkus),
      lifetimeSpendUsd);

  /// Create a copy of PurchaseState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PurchaseStateImplCopyWith<_$PurchaseStateImpl> get copyWith =>
      __$$PurchaseStateImplCopyWithImpl<_$PurchaseStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PurchaseStateImplToJson(
      this,
    );
  }
}

abstract class _PurchaseState implements PurchaseState {
  const factory _PurchaseState(
      {final List<PurchaseRecord> history,
      final bool removeAdsOwned,
      final SubscriptionState? pact,
      final Set<String> consumedOneTimeSkus,
      final double lifetimeSpendUsd}) = _$PurchaseStateImpl;

  factory _PurchaseState.fromJson(Map<String, dynamic> json) =
      _$PurchaseStateImpl.fromJson;

  @override
  List<PurchaseRecord> get history;
  @override
  bool get removeAdsOwned;

  /// Warden's Pact.
  @override
  SubscriptionState? get pact;
  @override
  Set<String> get consumedOneTimeSkus;

  /// Local only. Deliberately never synced to the cloud and never sold —
  /// see docs/13-database.md §13.10.
  @override
  double get lifetimeSpendUsd;

  /// Create a copy of PurchaseState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PurchaseStateImplCopyWith<_$PurchaseStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AchievementState _$AchievementStateFromJson(Map<String, dynamic> json) {
  return _AchievementState.fromJson(json);
}

/// @nodoc
mixin _$AchievementState {
  Map<String, int> get progress => throw _privateConstructorUsedError;
  Set<String> get claimedIds => throw _privateConstructorUsedError;

  /// Serializes this AchievementState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AchievementState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AchievementStateCopyWith<AchievementState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AchievementStateCopyWith<$Res> {
  factory $AchievementStateCopyWith(
          AchievementState value, $Res Function(AchievementState) then) =
      _$AchievementStateCopyWithImpl<$Res, AchievementState>;
  @useResult
  $Res call({Map<String, int> progress, Set<String> claimedIds});
}

/// @nodoc
class _$AchievementStateCopyWithImpl<$Res, $Val extends AchievementState>
    implements $AchievementStateCopyWith<$Res> {
  _$AchievementStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AchievementState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? progress = null,
    Object? claimedIds = null,
  }) {
    return _then(_value.copyWith(
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      claimedIds: null == claimedIds
          ? _value.claimedIds
          : claimedIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AchievementStateImplCopyWith<$Res>
    implements $AchievementStateCopyWith<$Res> {
  factory _$$AchievementStateImplCopyWith(_$AchievementStateImpl value,
          $Res Function(_$AchievementStateImpl) then) =
      __$$AchievementStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<String, int> progress, Set<String> claimedIds});
}

/// @nodoc
class __$$AchievementStateImplCopyWithImpl<$Res>
    extends _$AchievementStateCopyWithImpl<$Res, _$AchievementStateImpl>
    implements _$$AchievementStateImplCopyWith<$Res> {
  __$$AchievementStateImplCopyWithImpl(_$AchievementStateImpl _value,
      $Res Function(_$AchievementStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AchievementState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? progress = null,
    Object? claimedIds = null,
  }) {
    return _then(_$AchievementStateImpl(
      progress: null == progress
          ? _value._progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      claimedIds: null == claimedIds
          ? _value._claimedIds
          : claimedIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AchievementStateImpl implements _AchievementState {
  const _$AchievementStateImpl(
      {final Map<String, int> progress = const <String, int>{},
      final Set<String> claimedIds = const <String>{}})
      : _progress = progress,
        _claimedIds = claimedIds;

  factory _$AchievementStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$AchievementStateImplFromJson(json);

  final Map<String, int> _progress;
  @override
  @JsonKey()
  Map<String, int> get progress {
    if (_progress is EqualUnmodifiableMapView) return _progress;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_progress);
  }

  final Set<String> _claimedIds;
  @override
  @JsonKey()
  Set<String> get claimedIds {
    if (_claimedIds is EqualUnmodifiableSetView) return _claimedIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_claimedIds);
  }

  @override
  String toString() {
    return 'AchievementState(progress: $progress, claimedIds: $claimedIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AchievementStateImpl &&
            const DeepCollectionEquality().equals(other._progress, _progress) &&
            const DeepCollectionEquality()
                .equals(other._claimedIds, _claimedIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_progress),
      const DeepCollectionEquality().hash(_claimedIds));

  /// Create a copy of AchievementState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AchievementStateImplCopyWith<_$AchievementStateImpl> get copyWith =>
      __$$AchievementStateImplCopyWithImpl<_$AchievementStateImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AchievementStateImplToJson(
      this,
    );
  }
}

abstract class _AchievementState implements AchievementState {
  const factory _AchievementState(
      {final Map<String, int> progress,
      final Set<String> claimedIds}) = _$AchievementStateImpl;

  factory _AchievementState.fromJson(Map<String, dynamic> json) =
      _$AchievementStateImpl.fromJson;

  @override
  Map<String, int> get progress;
  @override
  Set<String> get claimedIds;

  /// Create a copy of AchievementState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AchievementStateImplCopyWith<_$AchievementStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
