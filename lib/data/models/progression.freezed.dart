// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'progression.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SpireState _$SpireStateFromJson(Map<String, dynamic> json) {
  return _SpireState.fromJson(json);
}

/// @nodoc
mixin _$SpireState {
  /// nodeId (1–24) -> level (0–80). Keys are strings because JSON object keys
  /// must be strings; parsed on read.
  Map<String, int> get nodeLevels => throw _privateConstructorUsedError;

  /// nodeId -> highest tier band unlocked (0 / 20 / 40 / 60). Advancing a band
  /// costs Insight, which is unpurchasable — this is the structural brake on
  /// pay-to-win described in docs/02-economy.md §2.11.
  Map<String, int> get tierGatesUnlocked => throw _privateConstructorUsedError;
  int get totalGoldSpent => throw _privateConstructorUsedError;

  /// Serializes this SpireState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SpireState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SpireStateCopyWith<SpireState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpireStateCopyWith<$Res> {
  factory $SpireStateCopyWith(
          SpireState value, $Res Function(SpireState) then) =
      _$SpireStateCopyWithImpl<$Res, SpireState>;
  @useResult
  $Res call(
      {Map<String, int> nodeLevels,
      Map<String, int> tierGatesUnlocked,
      int totalGoldSpent});
}

/// @nodoc
class _$SpireStateCopyWithImpl<$Res, $Val extends SpireState>
    implements $SpireStateCopyWith<$Res> {
  _$SpireStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SpireState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeLevels = null,
    Object? tierGatesUnlocked = null,
    Object? totalGoldSpent = null,
  }) {
    return _then(_value.copyWith(
      nodeLevels: null == nodeLevels
          ? _value.nodeLevels
          : nodeLevels // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      tierGatesUnlocked: null == tierGatesUnlocked
          ? _value.tierGatesUnlocked
          : tierGatesUnlocked // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      totalGoldSpent: null == totalGoldSpent
          ? _value.totalGoldSpent
          : totalGoldSpent // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SpireStateImplCopyWith<$Res>
    implements $SpireStateCopyWith<$Res> {
  factory _$$SpireStateImplCopyWith(
          _$SpireStateImpl value, $Res Function(_$SpireStateImpl) then) =
      __$$SpireStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Map<String, int> nodeLevels,
      Map<String, int> tierGatesUnlocked,
      int totalGoldSpent});
}

/// @nodoc
class __$$SpireStateImplCopyWithImpl<$Res>
    extends _$SpireStateCopyWithImpl<$Res, _$SpireStateImpl>
    implements _$$SpireStateImplCopyWith<$Res> {
  __$$SpireStateImplCopyWithImpl(
      _$SpireStateImpl _value, $Res Function(_$SpireStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SpireState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeLevels = null,
    Object? tierGatesUnlocked = null,
    Object? totalGoldSpent = null,
  }) {
    return _then(_$SpireStateImpl(
      nodeLevels: null == nodeLevels
          ? _value._nodeLevels
          : nodeLevels // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      tierGatesUnlocked: null == tierGatesUnlocked
          ? _value._tierGatesUnlocked
          : tierGatesUnlocked // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      totalGoldSpent: null == totalGoldSpent
          ? _value.totalGoldSpent
          : totalGoldSpent // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SpireStateImpl extends _SpireState {
  const _$SpireStateImpl(
      {final Map<String, int> nodeLevels = const <String, int>{},
      final Map<String, int> tierGatesUnlocked = const <String, int>{},
      this.totalGoldSpent = 0})
      : _nodeLevels = nodeLevels,
        _tierGatesUnlocked = tierGatesUnlocked,
        super._();

  factory _$SpireStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SpireStateImplFromJson(json);

  /// nodeId (1–24) -> level (0–80). Keys are strings because JSON object keys
  /// must be strings; parsed on read.
  final Map<String, int> _nodeLevels;

  /// nodeId (1–24) -> level (0–80). Keys are strings because JSON object keys
  /// must be strings; parsed on read.
  @override
  @JsonKey()
  Map<String, int> get nodeLevels {
    if (_nodeLevels is EqualUnmodifiableMapView) return _nodeLevels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_nodeLevels);
  }

  /// nodeId -> highest tier band unlocked (0 / 20 / 40 / 60). Advancing a band
  /// costs Insight, which is unpurchasable — this is the structural brake on
  /// pay-to-win described in docs/02-economy.md §2.11.
  final Map<String, int> _tierGatesUnlocked;

  /// nodeId -> highest tier band unlocked (0 / 20 / 40 / 60). Advancing a band
  /// costs Insight, which is unpurchasable — this is the structural brake on
  /// pay-to-win described in docs/02-economy.md §2.11.
  @override
  @JsonKey()
  Map<String, int> get tierGatesUnlocked {
    if (_tierGatesUnlocked is EqualUnmodifiableMapView)
      return _tierGatesUnlocked;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_tierGatesUnlocked);
  }

  @override
  @JsonKey()
  final int totalGoldSpent;

  @override
  String toString() {
    return 'SpireState(nodeLevels: $nodeLevels, tierGatesUnlocked: $tierGatesUnlocked, totalGoldSpent: $totalGoldSpent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SpireStateImpl &&
            const DeepCollectionEquality()
                .equals(other._nodeLevels, _nodeLevels) &&
            const DeepCollectionEquality()
                .equals(other._tierGatesUnlocked, _tierGatesUnlocked) &&
            (identical(other.totalGoldSpent, totalGoldSpent) ||
                other.totalGoldSpent == totalGoldSpent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_nodeLevels),
      const DeepCollectionEquality().hash(_tierGatesUnlocked),
      totalGoldSpent);

  /// Create a copy of SpireState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SpireStateImplCopyWith<_$SpireStateImpl> get copyWith =>
      __$$SpireStateImplCopyWithImpl<_$SpireStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SpireStateImplToJson(
      this,
    );
  }
}

abstract class _SpireState extends SpireState {
  const factory _SpireState(
      {final Map<String, int> nodeLevels,
      final Map<String, int> tierGatesUnlocked,
      final int totalGoldSpent}) = _$SpireStateImpl;
  const _SpireState._() : super._();

  factory _SpireState.fromJson(Map<String, dynamic> json) =
      _$SpireStateImpl.fromJson;

  /// nodeId (1–24) -> level (0–80). Keys are strings because JSON object keys
  /// must be strings; parsed on read.
  @override
  Map<String, int> get nodeLevels;

  /// nodeId -> highest tier band unlocked (0 / 20 / 40 / 60). Advancing a band
  /// costs Insight, which is unpurchasable — this is the structural brake on
  /// pay-to-win described in docs/02-economy.md §2.11.
  @override
  Map<String, int> get tierGatesUnlocked;
  @override
  int get totalGoldSpent;

  /// Create a copy of SpireState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SpireStateImplCopyWith<_$SpireStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ResearchState _$ResearchStateFromJson(Map<String, dynamic> json) {
  return _ResearchState.fromJson(json);
}

/// @nodoc
mixin _$ResearchState {
  Set<String> get completedIds => throw _privateConstructorUsedError;
  int get insightSpent => throw _privateConstructorUsedError;

  /// Serializes this ResearchState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ResearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ResearchStateCopyWith<ResearchState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ResearchStateCopyWith<$Res> {
  factory $ResearchStateCopyWith(
          ResearchState value, $Res Function(ResearchState) then) =
      _$ResearchStateCopyWithImpl<$Res, ResearchState>;
  @useResult
  $Res call({Set<String> completedIds, int insightSpent});
}

/// @nodoc
class _$ResearchStateCopyWithImpl<$Res, $Val extends ResearchState>
    implements $ResearchStateCopyWith<$Res> {
  _$ResearchStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ResearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? completedIds = null,
    Object? insightSpent = null,
  }) {
    return _then(_value.copyWith(
      completedIds: null == completedIds
          ? _value.completedIds
          : completedIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      insightSpent: null == insightSpent
          ? _value.insightSpent
          : insightSpent // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ResearchStateImplCopyWith<$Res>
    implements $ResearchStateCopyWith<$Res> {
  factory _$$ResearchStateImplCopyWith(
          _$ResearchStateImpl value, $Res Function(_$ResearchStateImpl) then) =
      __$$ResearchStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Set<String> completedIds, int insightSpent});
}

/// @nodoc
class __$$ResearchStateImplCopyWithImpl<$Res>
    extends _$ResearchStateCopyWithImpl<$Res, _$ResearchStateImpl>
    implements _$$ResearchStateImplCopyWith<$Res> {
  __$$ResearchStateImplCopyWithImpl(
      _$ResearchStateImpl _value, $Res Function(_$ResearchStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ResearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? completedIds = null,
    Object? insightSpent = null,
  }) {
    return _then(_$ResearchStateImpl(
      completedIds: null == completedIds
          ? _value._completedIds
          : completedIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      insightSpent: null == insightSpent
          ? _value.insightSpent
          : insightSpent // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ResearchStateImpl implements _ResearchState {
  const _$ResearchStateImpl(
      {final Set<String> completedIds = const <String>{},
      this.insightSpent = 0})
      : _completedIds = completedIds;

  factory _$ResearchStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$ResearchStateImplFromJson(json);

  final Set<String> _completedIds;
  @override
  @JsonKey()
  Set<String> get completedIds {
    if (_completedIds is EqualUnmodifiableSetView) return _completedIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_completedIds);
  }

  @override
  @JsonKey()
  final int insightSpent;

  @override
  String toString() {
    return 'ResearchState(completedIds: $completedIds, insightSpent: $insightSpent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ResearchStateImpl &&
            const DeepCollectionEquality()
                .equals(other._completedIds, _completedIds) &&
            (identical(other.insightSpent, insightSpent) ||
                other.insightSpent == insightSpent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_completedIds), insightSpent);

  /// Create a copy of ResearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ResearchStateImplCopyWith<_$ResearchStateImpl> get copyWith =>
      __$$ResearchStateImplCopyWithImpl<_$ResearchStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ResearchStateImplToJson(
      this,
    );
  }
}

abstract class _ResearchState implements ResearchState {
  const factory _ResearchState(
      {final Set<String> completedIds,
      final int insightSpent}) = _$ResearchStateImpl;

  factory _ResearchState.fromJson(Map<String, dynamic> json) =
      _$ResearchStateImpl.fromJson;

  @override
  Set<String> get completedIds;
  @override
  int get insightSpent;

  /// Create a copy of ResearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ResearchStateImplCopyWith<_$ResearchStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AscensionState _$AscensionStateFromJson(Map<String, dynamic> json) {
  return _AscensionState.fromJson(json);
}

/// @nodoc
mixin _$AscensionState {
  int get count => throw _privateConstructorUsedError;

  /// Emberdust tree: branchNodeId -> rank. Never resets.
  Map<String, int> get emberdustRanks => throw _privateConstructorUsedError;
  @NullableUtcDateTimeConverter()
  DateTime? get lastAscendedAt => throw _privateConstructorUsedError;

  /// Never resets, even across Ascensions — it is the input to the Emberdust
  /// award formula, so resetting it would make each cycle pay less than the
  /// last.
  int get highestChapterEver => throw _privateConstructorUsedError;

  /// Serializes this AscensionState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AscensionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AscensionStateCopyWith<AscensionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AscensionStateCopyWith<$Res> {
  factory $AscensionStateCopyWith(
          AscensionState value, $Res Function(AscensionState) then) =
      _$AscensionStateCopyWithImpl<$Res, AscensionState>;
  @useResult
  $Res call(
      {int count,
      Map<String, int> emberdustRanks,
      @NullableUtcDateTimeConverter() DateTime? lastAscendedAt,
      int highestChapterEver});
}

/// @nodoc
class _$AscensionStateCopyWithImpl<$Res, $Val extends AscensionState>
    implements $AscensionStateCopyWith<$Res> {
  _$AscensionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AscensionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? count = null,
    Object? emberdustRanks = null,
    Object? lastAscendedAt = freezed,
    Object? highestChapterEver = null,
  }) {
    return _then(_value.copyWith(
      count: null == count
          ? _value.count
          : count // ignore: cast_nullable_to_non_nullable
              as int,
      emberdustRanks: null == emberdustRanks
          ? _value.emberdustRanks
          : emberdustRanks // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      lastAscendedAt: freezed == lastAscendedAt
          ? _value.lastAscendedAt
          : lastAscendedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      highestChapterEver: null == highestChapterEver
          ? _value.highestChapterEver
          : highestChapterEver // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AscensionStateImplCopyWith<$Res>
    implements $AscensionStateCopyWith<$Res> {
  factory _$$AscensionStateImplCopyWith(_$AscensionStateImpl value,
          $Res Function(_$AscensionStateImpl) then) =
      __$$AscensionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int count,
      Map<String, int> emberdustRanks,
      @NullableUtcDateTimeConverter() DateTime? lastAscendedAt,
      int highestChapterEver});
}

/// @nodoc
class __$$AscensionStateImplCopyWithImpl<$Res>
    extends _$AscensionStateCopyWithImpl<$Res, _$AscensionStateImpl>
    implements _$$AscensionStateImplCopyWith<$Res> {
  __$$AscensionStateImplCopyWithImpl(
      _$AscensionStateImpl _value, $Res Function(_$AscensionStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AscensionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? count = null,
    Object? emberdustRanks = null,
    Object? lastAscendedAt = freezed,
    Object? highestChapterEver = null,
  }) {
    return _then(_$AscensionStateImpl(
      count: null == count
          ? _value.count
          : count // ignore: cast_nullable_to_non_nullable
              as int,
      emberdustRanks: null == emberdustRanks
          ? _value._emberdustRanks
          : emberdustRanks // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      lastAscendedAt: freezed == lastAscendedAt
          ? _value.lastAscendedAt
          : lastAscendedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      highestChapterEver: null == highestChapterEver
          ? _value.highestChapterEver
          : highestChapterEver // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AscensionStateImpl implements _AscensionState {
  const _$AscensionStateImpl(
      {this.count = 0,
      final Map<String, int> emberdustRanks = const <String, int>{},
      @NullableUtcDateTimeConverter() this.lastAscendedAt,
      this.highestChapterEver = 0})
      : _emberdustRanks = emberdustRanks;

  factory _$AscensionStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$AscensionStateImplFromJson(json);

  @override
  @JsonKey()
  final int count;

  /// Emberdust tree: branchNodeId -> rank. Never resets.
  final Map<String, int> _emberdustRanks;

  /// Emberdust tree: branchNodeId -> rank. Never resets.
  @override
  @JsonKey()
  Map<String, int> get emberdustRanks {
    if (_emberdustRanks is EqualUnmodifiableMapView) return _emberdustRanks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_emberdustRanks);
  }

  @override
  @NullableUtcDateTimeConverter()
  final DateTime? lastAscendedAt;

  /// Never resets, even across Ascensions — it is the input to the Emberdust
  /// award formula, so resetting it would make each cycle pay less than the
  /// last.
  @override
  @JsonKey()
  final int highestChapterEver;

  @override
  String toString() {
    return 'AscensionState(count: $count, emberdustRanks: $emberdustRanks, lastAscendedAt: $lastAscendedAt, highestChapterEver: $highestChapterEver)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AscensionStateImpl &&
            (identical(other.count, count) || other.count == count) &&
            const DeepCollectionEquality()
                .equals(other._emberdustRanks, _emberdustRanks) &&
            (identical(other.lastAscendedAt, lastAscendedAt) ||
                other.lastAscendedAt == lastAscendedAt) &&
            (identical(other.highestChapterEver, highestChapterEver) ||
                other.highestChapterEver == highestChapterEver));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      count,
      const DeepCollectionEquality().hash(_emberdustRanks),
      lastAscendedAt,
      highestChapterEver);

  /// Create a copy of AscensionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AscensionStateImplCopyWith<_$AscensionStateImpl> get copyWith =>
      __$$AscensionStateImplCopyWithImpl<_$AscensionStateImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AscensionStateImplToJson(
      this,
    );
  }
}

abstract class _AscensionState implements AscensionState {
  const factory _AscensionState(
      {final int count,
      final Map<String, int> emberdustRanks,
      @NullableUtcDateTimeConverter() final DateTime? lastAscendedAt,
      final int highestChapterEver}) = _$AscensionStateImpl;

  factory _AscensionState.fromJson(Map<String, dynamic> json) =
      _$AscensionStateImpl.fromJson;

  @override
  int get count;

  /// Emberdust tree: branchNodeId -> rank. Never resets.
  @override
  Map<String, int> get emberdustRanks;
  @override
  @NullableUtcDateTimeConverter()
  DateTime? get lastAscendedAt;

  /// Never resets, even across Ascensions — it is the input to the Emberdust
  /// award formula, so resetting it would make each cycle pay less than the
  /// last.
  @override
  int get highestChapterEver;

  /// Create a copy of AscensionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AscensionStateImplCopyWith<_$AscensionStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MarkState _$MarkStateFromJson(Map<String, dynamic> json) {
  return _MarkState.fromJson(json);
}

/// @nodoc
mixin _$MarkState {
  /// markId -> progress counter (e.g. confluences triggered).
  Map<String, int> get progress => throw _privateConstructorUsedError;
  Set<String> get unlockedIds => throw _privateConstructorUsedError;

  /// Serializes this MarkState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MarkState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MarkStateCopyWith<MarkState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MarkStateCopyWith<$Res> {
  factory $MarkStateCopyWith(MarkState value, $Res Function(MarkState) then) =
      _$MarkStateCopyWithImpl<$Res, MarkState>;
  @useResult
  $Res call({Map<String, int> progress, Set<String> unlockedIds});
}

/// @nodoc
class _$MarkStateCopyWithImpl<$Res, $Val extends MarkState>
    implements $MarkStateCopyWith<$Res> {
  _$MarkStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MarkState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? progress = null,
    Object? unlockedIds = null,
  }) {
    return _then(_value.copyWith(
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      unlockedIds: null == unlockedIds
          ? _value.unlockedIds
          : unlockedIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MarkStateImplCopyWith<$Res>
    implements $MarkStateCopyWith<$Res> {
  factory _$$MarkStateImplCopyWith(
          _$MarkStateImpl value, $Res Function(_$MarkStateImpl) then) =
      __$$MarkStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<String, int> progress, Set<String> unlockedIds});
}

/// @nodoc
class __$$MarkStateImplCopyWithImpl<$Res>
    extends _$MarkStateCopyWithImpl<$Res, _$MarkStateImpl>
    implements _$$MarkStateImplCopyWith<$Res> {
  __$$MarkStateImplCopyWithImpl(
      _$MarkStateImpl _value, $Res Function(_$MarkStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of MarkState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? progress = null,
    Object? unlockedIds = null,
  }) {
    return _then(_$MarkStateImpl(
      progress: null == progress
          ? _value._progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      unlockedIds: null == unlockedIds
          ? _value._unlockedIds
          : unlockedIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MarkStateImpl implements _MarkState {
  const _$MarkStateImpl(
      {final Map<String, int> progress = const <String, int>{},
      final Set<String> unlockedIds = const <String>{}})
      : _progress = progress,
        _unlockedIds = unlockedIds;

  factory _$MarkStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$MarkStateImplFromJson(json);

  /// markId -> progress counter (e.g. confluences triggered).
  final Map<String, int> _progress;

  /// markId -> progress counter (e.g. confluences triggered).
  @override
  @JsonKey()
  Map<String, int> get progress {
    if (_progress is EqualUnmodifiableMapView) return _progress;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_progress);
  }

  final Set<String> _unlockedIds;
  @override
  @JsonKey()
  Set<String> get unlockedIds {
    if (_unlockedIds is EqualUnmodifiableSetView) return _unlockedIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_unlockedIds);
  }

  @override
  String toString() {
    return 'MarkState(progress: $progress, unlockedIds: $unlockedIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MarkStateImpl &&
            const DeepCollectionEquality().equals(other._progress, _progress) &&
            const DeepCollectionEquality()
                .equals(other._unlockedIds, _unlockedIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_progress),
      const DeepCollectionEquality().hash(_unlockedIds));

  /// Create a copy of MarkState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MarkStateImplCopyWith<_$MarkStateImpl> get copyWith =>
      __$$MarkStateImplCopyWithImpl<_$MarkStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MarkStateImplToJson(
      this,
    );
  }
}

abstract class _MarkState implements MarkState {
  const factory _MarkState(
      {final Map<String, int> progress,
      final Set<String> unlockedIds}) = _$MarkStateImpl;

  factory _MarkState.fromJson(Map<String, dynamic> json) =
      _$MarkStateImpl.fromJson;

  /// markId -> progress counter (e.g. confluences triggered).
  @override
  Map<String, int> get progress;
  @override
  Set<String> get unlockedIds;

  /// Create a copy of MarkState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MarkStateImplCopyWith<_$MarkStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

HeroState _$HeroStateFromJson(Map<String, dynamic> json) {
  return _HeroState.fromJson(json);
}

/// @nodoc
mixin _$HeroState {
  String get heroId => throw _privateConstructorUsedError;
  bool get unlocked => throw _privateConstructorUsedError;
  int get level => throw _privateConstructorUsedError;
  int get stars => throw _privateConstructorUsedError;

  /// starTier (1 / 3 / 5) -> chosen branch ('a' or 'b').
  Map<String, String> get talentChoices => throw _privateConstructorUsedError;
  int get shardsSpent => throw _privateConstructorUsedError;
  @NullableUtcDateTimeConverter()
  DateTime? get firstUnlockedAt => throw _privateConstructorUsedError;

  /// Serializes this HeroState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HeroState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HeroStateCopyWith<HeroState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HeroStateCopyWith<$Res> {
  factory $HeroStateCopyWith(HeroState value, $Res Function(HeroState) then) =
      _$HeroStateCopyWithImpl<$Res, HeroState>;
  @useResult
  $Res call(
      {String heroId,
      bool unlocked,
      int level,
      int stars,
      Map<String, String> talentChoices,
      int shardsSpent,
      @NullableUtcDateTimeConverter() DateTime? firstUnlockedAt});
}

/// @nodoc
class _$HeroStateCopyWithImpl<$Res, $Val extends HeroState>
    implements $HeroStateCopyWith<$Res> {
  _$HeroStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HeroState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? heroId = null,
    Object? unlocked = null,
    Object? level = null,
    Object? stars = null,
    Object? talentChoices = null,
    Object? shardsSpent = null,
    Object? firstUnlockedAt = freezed,
  }) {
    return _then(_value.copyWith(
      heroId: null == heroId
          ? _value.heroId
          : heroId // ignore: cast_nullable_to_non_nullable
              as String,
      unlocked: null == unlocked
          ? _value.unlocked
          : unlocked // ignore: cast_nullable_to_non_nullable
              as bool,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      stars: null == stars
          ? _value.stars
          : stars // ignore: cast_nullable_to_non_nullable
              as int,
      talentChoices: null == talentChoices
          ? _value.talentChoices
          : talentChoices // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      shardsSpent: null == shardsSpent
          ? _value.shardsSpent
          : shardsSpent // ignore: cast_nullable_to_non_nullable
              as int,
      firstUnlockedAt: freezed == firstUnlockedAt
          ? _value.firstUnlockedAt
          : firstUnlockedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HeroStateImplCopyWith<$Res>
    implements $HeroStateCopyWith<$Res> {
  factory _$$HeroStateImplCopyWith(
          _$HeroStateImpl value, $Res Function(_$HeroStateImpl) then) =
      __$$HeroStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String heroId,
      bool unlocked,
      int level,
      int stars,
      Map<String, String> talentChoices,
      int shardsSpent,
      @NullableUtcDateTimeConverter() DateTime? firstUnlockedAt});
}

/// @nodoc
class __$$HeroStateImplCopyWithImpl<$Res>
    extends _$HeroStateCopyWithImpl<$Res, _$HeroStateImpl>
    implements _$$HeroStateImplCopyWith<$Res> {
  __$$HeroStateImplCopyWithImpl(
      _$HeroStateImpl _value, $Res Function(_$HeroStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of HeroState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? heroId = null,
    Object? unlocked = null,
    Object? level = null,
    Object? stars = null,
    Object? talentChoices = null,
    Object? shardsSpent = null,
    Object? firstUnlockedAt = freezed,
  }) {
    return _then(_$HeroStateImpl(
      heroId: null == heroId
          ? _value.heroId
          : heroId // ignore: cast_nullable_to_non_nullable
              as String,
      unlocked: null == unlocked
          ? _value.unlocked
          : unlocked // ignore: cast_nullable_to_non_nullable
              as bool,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      stars: null == stars
          ? _value.stars
          : stars // ignore: cast_nullable_to_non_nullable
              as int,
      talentChoices: null == talentChoices
          ? _value._talentChoices
          : talentChoices // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      shardsSpent: null == shardsSpent
          ? _value.shardsSpent
          : shardsSpent // ignore: cast_nullable_to_non_nullable
              as int,
      firstUnlockedAt: freezed == firstUnlockedAt
          ? _value.firstUnlockedAt
          : firstUnlockedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$HeroStateImpl implements _HeroState {
  const _$HeroStateImpl(
      {required this.heroId,
      this.unlocked = false,
      this.level = 1,
      this.stars = 0,
      final Map<String, String> talentChoices = const <String, String>{},
      this.shardsSpent = 0,
      @NullableUtcDateTimeConverter() this.firstUnlockedAt})
      : _talentChoices = talentChoices;

  factory _$HeroStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$HeroStateImplFromJson(json);

  @override
  final String heroId;
  @override
  @JsonKey()
  final bool unlocked;
  @override
  @JsonKey()
  final int level;
  @override
  @JsonKey()
  final int stars;

  /// starTier (1 / 3 / 5) -> chosen branch ('a' or 'b').
  final Map<String, String> _talentChoices;

  /// starTier (1 / 3 / 5) -> chosen branch ('a' or 'b').
  @override
  @JsonKey()
  Map<String, String> get talentChoices {
    if (_talentChoices is EqualUnmodifiableMapView) return _talentChoices;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_talentChoices);
  }

  @override
  @JsonKey()
  final int shardsSpent;
  @override
  @NullableUtcDateTimeConverter()
  final DateTime? firstUnlockedAt;

  @override
  String toString() {
    return 'HeroState(heroId: $heroId, unlocked: $unlocked, level: $level, stars: $stars, talentChoices: $talentChoices, shardsSpent: $shardsSpent, firstUnlockedAt: $firstUnlockedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HeroStateImpl &&
            (identical(other.heroId, heroId) || other.heroId == heroId) &&
            (identical(other.unlocked, unlocked) ||
                other.unlocked == unlocked) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.stars, stars) || other.stars == stars) &&
            const DeepCollectionEquality()
                .equals(other._talentChoices, _talentChoices) &&
            (identical(other.shardsSpent, shardsSpent) ||
                other.shardsSpent == shardsSpent) &&
            (identical(other.firstUnlockedAt, firstUnlockedAt) ||
                other.firstUnlockedAt == firstUnlockedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      heroId,
      unlocked,
      level,
      stars,
      const DeepCollectionEquality().hash(_talentChoices),
      shardsSpent,
      firstUnlockedAt);

  /// Create a copy of HeroState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HeroStateImplCopyWith<_$HeroStateImpl> get copyWith =>
      __$$HeroStateImplCopyWithImpl<_$HeroStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HeroStateImplToJson(
      this,
    );
  }
}

abstract class _HeroState implements HeroState {
  const factory _HeroState(
          {required final String heroId,
          final bool unlocked,
          final int level,
          final int stars,
          final Map<String, String> talentChoices,
          final int shardsSpent,
          @NullableUtcDateTimeConverter() final DateTime? firstUnlockedAt}) =
      _$HeroStateImpl;

  factory _HeroState.fromJson(Map<String, dynamic> json) =
      _$HeroStateImpl.fromJson;

  @override
  String get heroId;
  @override
  bool get unlocked;
  @override
  int get level;
  @override
  int get stars;

  /// starTier (1 / 3 / 5) -> chosen branch ('a' or 'b').
  @override
  Map<String, String> get talentChoices;
  @override
  int get shardsSpent;
  @override
  @NullableUtcDateTimeConverter()
  DateTime? get firstUnlockedAt;

  /// Create a copy of HeroState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HeroStateImplCopyWith<_$HeroStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StageRecord _$StageRecordFromJson(Map<String, dynamic> json) {
  return _StageRecord.fromJson(json);
}

/// @nodoc
mixin _$StageRecord {
  int get stars => throw _privateConstructorUsedError;
  @DurationConverter()
  Duration get bestTime => throw _privateConstructorUsedError;
  int get clearCount => throw _privateConstructorUsedError;
  int get bestConfluenceCount => throw _privateConstructorUsedError;
  @NullableUtcDateTimeConverter()
  DateTime? get firstClearedAt => throw _privateConstructorUsedError;

  /// Drives both the bestiary and the threat preview on Level Select. A
  /// player only ever sees named threats for enemies they have actually met.
  Set<String> get enemiesSeen => throw _privateConstructorUsedError;

  /// Serializes this StageRecord to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StageRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StageRecordCopyWith<StageRecord> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StageRecordCopyWith<$Res> {
  factory $StageRecordCopyWith(
          StageRecord value, $Res Function(StageRecord) then) =
      _$StageRecordCopyWithImpl<$Res, StageRecord>;
  @useResult
  $Res call(
      {int stars,
      @DurationConverter() Duration bestTime,
      int clearCount,
      int bestConfluenceCount,
      @NullableUtcDateTimeConverter() DateTime? firstClearedAt,
      Set<String> enemiesSeen});
}

/// @nodoc
class _$StageRecordCopyWithImpl<$Res, $Val extends StageRecord>
    implements $StageRecordCopyWith<$Res> {
  _$StageRecordCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StageRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stars = null,
    Object? bestTime = null,
    Object? clearCount = null,
    Object? bestConfluenceCount = null,
    Object? firstClearedAt = freezed,
    Object? enemiesSeen = null,
  }) {
    return _then(_value.copyWith(
      stars: null == stars
          ? _value.stars
          : stars // ignore: cast_nullable_to_non_nullable
              as int,
      bestTime: null == bestTime
          ? _value.bestTime
          : bestTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      clearCount: null == clearCount
          ? _value.clearCount
          : clearCount // ignore: cast_nullable_to_non_nullable
              as int,
      bestConfluenceCount: null == bestConfluenceCount
          ? _value.bestConfluenceCount
          : bestConfluenceCount // ignore: cast_nullable_to_non_nullable
              as int,
      firstClearedAt: freezed == firstClearedAt
          ? _value.firstClearedAt
          : firstClearedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      enemiesSeen: null == enemiesSeen
          ? _value.enemiesSeen
          : enemiesSeen // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StageRecordImplCopyWith<$Res>
    implements $StageRecordCopyWith<$Res> {
  factory _$$StageRecordImplCopyWith(
          _$StageRecordImpl value, $Res Function(_$StageRecordImpl) then) =
      __$$StageRecordImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int stars,
      @DurationConverter() Duration bestTime,
      int clearCount,
      int bestConfluenceCount,
      @NullableUtcDateTimeConverter() DateTime? firstClearedAt,
      Set<String> enemiesSeen});
}

/// @nodoc
class __$$StageRecordImplCopyWithImpl<$Res>
    extends _$StageRecordCopyWithImpl<$Res, _$StageRecordImpl>
    implements _$$StageRecordImplCopyWith<$Res> {
  __$$StageRecordImplCopyWithImpl(
      _$StageRecordImpl _value, $Res Function(_$StageRecordImpl) _then)
      : super(_value, _then);

  /// Create a copy of StageRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stars = null,
    Object? bestTime = null,
    Object? clearCount = null,
    Object? bestConfluenceCount = null,
    Object? firstClearedAt = freezed,
    Object? enemiesSeen = null,
  }) {
    return _then(_$StageRecordImpl(
      stars: null == stars
          ? _value.stars
          : stars // ignore: cast_nullable_to_non_nullable
              as int,
      bestTime: null == bestTime
          ? _value.bestTime
          : bestTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      clearCount: null == clearCount
          ? _value.clearCount
          : clearCount // ignore: cast_nullable_to_non_nullable
              as int,
      bestConfluenceCount: null == bestConfluenceCount
          ? _value.bestConfluenceCount
          : bestConfluenceCount // ignore: cast_nullable_to_non_nullable
              as int,
      firstClearedAt: freezed == firstClearedAt
          ? _value.firstClearedAt
          : firstClearedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      enemiesSeen: null == enemiesSeen
          ? _value._enemiesSeen
          : enemiesSeen // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StageRecordImpl implements _StageRecord {
  const _$StageRecordImpl(
      {this.stars = 0,
      @DurationConverter() this.bestTime = Duration.zero,
      this.clearCount = 0,
      this.bestConfluenceCount = 0,
      @NullableUtcDateTimeConverter() this.firstClearedAt,
      final Set<String> enemiesSeen = const <String>{}})
      : _enemiesSeen = enemiesSeen;

  factory _$StageRecordImpl.fromJson(Map<String, dynamic> json) =>
      _$$StageRecordImplFromJson(json);

  @override
  @JsonKey()
  final int stars;
  @override
  @JsonKey()
  @DurationConverter()
  final Duration bestTime;
  @override
  @JsonKey()
  final int clearCount;
  @override
  @JsonKey()
  final int bestConfluenceCount;
  @override
  @NullableUtcDateTimeConverter()
  final DateTime? firstClearedAt;

  /// Drives both the bestiary and the threat preview on Level Select. A
  /// player only ever sees named threats for enemies they have actually met.
  final Set<String> _enemiesSeen;

  /// Drives both the bestiary and the threat preview on Level Select. A
  /// player only ever sees named threats for enemies they have actually met.
  @override
  @JsonKey()
  Set<String> get enemiesSeen {
    if (_enemiesSeen is EqualUnmodifiableSetView) return _enemiesSeen;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_enemiesSeen);
  }

  @override
  String toString() {
    return 'StageRecord(stars: $stars, bestTime: $bestTime, clearCount: $clearCount, bestConfluenceCount: $bestConfluenceCount, firstClearedAt: $firstClearedAt, enemiesSeen: $enemiesSeen)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StageRecordImpl &&
            (identical(other.stars, stars) || other.stars == stars) &&
            (identical(other.bestTime, bestTime) ||
                other.bestTime == bestTime) &&
            (identical(other.clearCount, clearCount) ||
                other.clearCount == clearCount) &&
            (identical(other.bestConfluenceCount, bestConfluenceCount) ||
                other.bestConfluenceCount == bestConfluenceCount) &&
            (identical(other.firstClearedAt, firstClearedAt) ||
                other.firstClearedAt == firstClearedAt) &&
            const DeepCollectionEquality()
                .equals(other._enemiesSeen, _enemiesSeen));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      stars,
      bestTime,
      clearCount,
      bestConfluenceCount,
      firstClearedAt,
      const DeepCollectionEquality().hash(_enemiesSeen));

  /// Create a copy of StageRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StageRecordImplCopyWith<_$StageRecordImpl> get copyWith =>
      __$$StageRecordImplCopyWithImpl<_$StageRecordImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StageRecordImplToJson(
      this,
    );
  }
}

abstract class _StageRecord implements StageRecord {
  const factory _StageRecord(
      {final int stars,
      @DurationConverter() final Duration bestTime,
      final int clearCount,
      final int bestConfluenceCount,
      @NullableUtcDateTimeConverter() final DateTime? firstClearedAt,
      final Set<String> enemiesSeen}) = _$StageRecordImpl;

  factory _StageRecord.fromJson(Map<String, dynamic> json) =
      _$StageRecordImpl.fromJson;

  @override
  int get stars;
  @override
  @DurationConverter()
  Duration get bestTime;
  @override
  int get clearCount;
  @override
  int get bestConfluenceCount;
  @override
  @NullableUtcDateTimeConverter()
  DateTime? get firstClearedAt;

  /// Drives both the bestiary and the threat preview on Level Select. A
  /// player only ever sees named threats for enemies they have actually met.
  @override
  Set<String> get enemiesSeen;

  /// Create a copy of StageRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StageRecordImplCopyWith<_$StageRecordImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CampaignState _$CampaignStateFromJson(Map<String, dynamic> json) {
  return _CampaignState.fromJson(json);
}

/// @nodoc
mixin _$CampaignState {
  int get currentChapter => throw _privateConstructorUsedError;
  int get currentStage => throw _privateConstructorUsedError;

  /// StageRef.key -> record.
  Map<String, StageRecord> get records => throw _privateConstructorUsedError;
  Set<String> get bossesDefeated => throw _privateConstructorUsedError;

  /// Drives the +6% per-kill boss HP scaling, so farming a known boss stays
  /// engaging rather than becoming free.
  Map<String, int> get bossKillCounts => throw _privateConstructorUsedError;
  int get endlessBestFloor => throw _privateConstructorUsedError;
  int get endlessSeasonId => throw _privateConstructorUsedError;

  /// Serializes this CampaignState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CampaignState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CampaignStateCopyWith<CampaignState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CampaignStateCopyWith<$Res> {
  factory $CampaignStateCopyWith(
          CampaignState value, $Res Function(CampaignState) then) =
      _$CampaignStateCopyWithImpl<$Res, CampaignState>;
  @useResult
  $Res call(
      {int currentChapter,
      int currentStage,
      Map<String, StageRecord> records,
      Set<String> bossesDefeated,
      Map<String, int> bossKillCounts,
      int endlessBestFloor,
      int endlessSeasonId});
}

/// @nodoc
class _$CampaignStateCopyWithImpl<$Res, $Val extends CampaignState>
    implements $CampaignStateCopyWith<$Res> {
  _$CampaignStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CampaignState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentChapter = null,
    Object? currentStage = null,
    Object? records = null,
    Object? bossesDefeated = null,
    Object? bossKillCounts = null,
    Object? endlessBestFloor = null,
    Object? endlessSeasonId = null,
  }) {
    return _then(_value.copyWith(
      currentChapter: null == currentChapter
          ? _value.currentChapter
          : currentChapter // ignore: cast_nullable_to_non_nullable
              as int,
      currentStage: null == currentStage
          ? _value.currentStage
          : currentStage // ignore: cast_nullable_to_non_nullable
              as int,
      records: null == records
          ? _value.records
          : records // ignore: cast_nullable_to_non_nullable
              as Map<String, StageRecord>,
      bossesDefeated: null == bossesDefeated
          ? _value.bossesDefeated
          : bossesDefeated // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      bossKillCounts: null == bossKillCounts
          ? _value.bossKillCounts
          : bossKillCounts // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      endlessBestFloor: null == endlessBestFloor
          ? _value.endlessBestFloor
          : endlessBestFloor // ignore: cast_nullable_to_non_nullable
              as int,
      endlessSeasonId: null == endlessSeasonId
          ? _value.endlessSeasonId
          : endlessSeasonId // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CampaignStateImplCopyWith<$Res>
    implements $CampaignStateCopyWith<$Res> {
  factory _$$CampaignStateImplCopyWith(
          _$CampaignStateImpl value, $Res Function(_$CampaignStateImpl) then) =
      __$$CampaignStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int currentChapter,
      int currentStage,
      Map<String, StageRecord> records,
      Set<String> bossesDefeated,
      Map<String, int> bossKillCounts,
      int endlessBestFloor,
      int endlessSeasonId});
}

/// @nodoc
class __$$CampaignStateImplCopyWithImpl<$Res>
    extends _$CampaignStateCopyWithImpl<$Res, _$CampaignStateImpl>
    implements _$$CampaignStateImplCopyWith<$Res> {
  __$$CampaignStateImplCopyWithImpl(
      _$CampaignStateImpl _value, $Res Function(_$CampaignStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of CampaignState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentChapter = null,
    Object? currentStage = null,
    Object? records = null,
    Object? bossesDefeated = null,
    Object? bossKillCounts = null,
    Object? endlessBestFloor = null,
    Object? endlessSeasonId = null,
  }) {
    return _then(_$CampaignStateImpl(
      currentChapter: null == currentChapter
          ? _value.currentChapter
          : currentChapter // ignore: cast_nullable_to_non_nullable
              as int,
      currentStage: null == currentStage
          ? _value.currentStage
          : currentStage // ignore: cast_nullable_to_non_nullable
              as int,
      records: null == records
          ? _value._records
          : records // ignore: cast_nullable_to_non_nullable
              as Map<String, StageRecord>,
      bossesDefeated: null == bossesDefeated
          ? _value._bossesDefeated
          : bossesDefeated // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      bossKillCounts: null == bossKillCounts
          ? _value._bossKillCounts
          : bossKillCounts // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      endlessBestFloor: null == endlessBestFloor
          ? _value.endlessBestFloor
          : endlessBestFloor // ignore: cast_nullable_to_non_nullable
              as int,
      endlessSeasonId: null == endlessSeasonId
          ? _value.endlessSeasonId
          : endlessSeasonId // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CampaignStateImpl extends _CampaignState {
  const _$CampaignStateImpl(
      {this.currentChapter = 1,
      this.currentStage = 1,
      final Map<String, StageRecord> records = const <String, StageRecord>{},
      final Set<String> bossesDefeated = const <String>{},
      final Map<String, int> bossKillCounts = const <String, int>{},
      this.endlessBestFloor = 0,
      this.endlessSeasonId = 0})
      : _records = records,
        _bossesDefeated = bossesDefeated,
        _bossKillCounts = bossKillCounts,
        super._();

  factory _$CampaignStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$CampaignStateImplFromJson(json);

  @override
  @JsonKey()
  final int currentChapter;
  @override
  @JsonKey()
  final int currentStage;

  /// StageRef.key -> record.
  final Map<String, StageRecord> _records;

  /// StageRef.key -> record.
  @override
  @JsonKey()
  Map<String, StageRecord> get records {
    if (_records is EqualUnmodifiableMapView) return _records;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_records);
  }

  final Set<String> _bossesDefeated;
  @override
  @JsonKey()
  Set<String> get bossesDefeated {
    if (_bossesDefeated is EqualUnmodifiableSetView) return _bossesDefeated;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_bossesDefeated);
  }

  /// Drives the +6% per-kill boss HP scaling, so farming a known boss stays
  /// engaging rather than becoming free.
  final Map<String, int> _bossKillCounts;

  /// Drives the +6% per-kill boss HP scaling, so farming a known boss stays
  /// engaging rather than becoming free.
  @override
  @JsonKey()
  Map<String, int> get bossKillCounts {
    if (_bossKillCounts is EqualUnmodifiableMapView) return _bossKillCounts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_bossKillCounts);
  }

  @override
  @JsonKey()
  final int endlessBestFloor;
  @override
  @JsonKey()
  final int endlessSeasonId;

  @override
  String toString() {
    return 'CampaignState(currentChapter: $currentChapter, currentStage: $currentStage, records: $records, bossesDefeated: $bossesDefeated, bossKillCounts: $bossKillCounts, endlessBestFloor: $endlessBestFloor, endlessSeasonId: $endlessSeasonId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CampaignStateImpl &&
            (identical(other.currentChapter, currentChapter) ||
                other.currentChapter == currentChapter) &&
            (identical(other.currentStage, currentStage) ||
                other.currentStage == currentStage) &&
            const DeepCollectionEquality().equals(other._records, _records) &&
            const DeepCollectionEquality()
                .equals(other._bossesDefeated, _bossesDefeated) &&
            const DeepCollectionEquality()
                .equals(other._bossKillCounts, _bossKillCounts) &&
            (identical(other.endlessBestFloor, endlessBestFloor) ||
                other.endlessBestFloor == endlessBestFloor) &&
            (identical(other.endlessSeasonId, endlessSeasonId) ||
                other.endlessSeasonId == endlessSeasonId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      currentChapter,
      currentStage,
      const DeepCollectionEquality().hash(_records),
      const DeepCollectionEquality().hash(_bossesDefeated),
      const DeepCollectionEquality().hash(_bossKillCounts),
      endlessBestFloor,
      endlessSeasonId);

  /// Create a copy of CampaignState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CampaignStateImplCopyWith<_$CampaignStateImpl> get copyWith =>
      __$$CampaignStateImplCopyWithImpl<_$CampaignStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CampaignStateImplToJson(
      this,
    );
  }
}

abstract class _CampaignState extends CampaignState {
  const factory _CampaignState(
      {final int currentChapter,
      final int currentStage,
      final Map<String, StageRecord> records,
      final Set<String> bossesDefeated,
      final Map<String, int> bossKillCounts,
      final int endlessBestFloor,
      final int endlessSeasonId}) = _$CampaignStateImpl;
  const _CampaignState._() : super._();

  factory _CampaignState.fromJson(Map<String, dynamic> json) =
      _$CampaignStateImpl.fromJson;

  @override
  int get currentChapter;
  @override
  int get currentStage;

  /// StageRef.key -> record.
  @override
  Map<String, StageRecord> get records;
  @override
  Set<String> get bossesDefeated;

  /// Drives the +6% per-kill boss HP scaling, so farming a known boss stays
  /// engaging rather than becoming free.
  @override
  Map<String, int> get bossKillCounts;
  @override
  int get endlessBestFloor;
  @override
  int get endlessSeasonId;

  /// Create a copy of CampaignState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CampaignStateImplCopyWith<_$CampaignStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
