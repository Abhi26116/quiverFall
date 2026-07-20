// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'run_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

StageRef _$StageRefFromJson(Map<String, dynamic> json) {
  return _StageRef.fromJson(json);
}

/// @nodoc
mixin _$StageRef {
  int get chapter => throw _privateConstructorUsedError;
  int get stage => throw _privateConstructorUsedError;

  /// Serializes this StageRef to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StageRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StageRefCopyWith<StageRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StageRefCopyWith<$Res> {
  factory $StageRefCopyWith(StageRef value, $Res Function(StageRef) then) =
      _$StageRefCopyWithImpl<$Res, StageRef>;
  @useResult
  $Res call({int chapter, int stage});
}

/// @nodoc
class _$StageRefCopyWithImpl<$Res, $Val extends StageRef>
    implements $StageRefCopyWith<$Res> {
  _$StageRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StageRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapter = null,
    Object? stage = null,
  }) {
    return _then(_value.copyWith(
      chapter: null == chapter
          ? _value.chapter
          : chapter // ignore: cast_nullable_to_non_nullable
              as int,
      stage: null == stage
          ? _value.stage
          : stage // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StageRefImplCopyWith<$Res>
    implements $StageRefCopyWith<$Res> {
  factory _$$StageRefImplCopyWith(
          _$StageRefImpl value, $Res Function(_$StageRefImpl) then) =
      __$$StageRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int chapter, int stage});
}

/// @nodoc
class __$$StageRefImplCopyWithImpl<$Res>
    extends _$StageRefCopyWithImpl<$Res, _$StageRefImpl>
    implements _$$StageRefImplCopyWith<$Res> {
  __$$StageRefImplCopyWithImpl(
      _$StageRefImpl _value, $Res Function(_$StageRefImpl) _then)
      : super(_value, _then);

  /// Create a copy of StageRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapter = null,
    Object? stage = null,
  }) {
    return _then(_$StageRefImpl(
      chapter: null == chapter
          ? _value.chapter
          : chapter // ignore: cast_nullable_to_non_nullable
              as int,
      stage: null == stage
          ? _value.stage
          : stage // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StageRefImpl extends _StageRef {
  const _$StageRefImpl({required this.chapter, required this.stage})
      : super._();

  factory _$StageRefImpl.fromJson(Map<String, dynamic> json) =>
      _$$StageRefImplFromJson(json);

  @override
  final int chapter;
  @override
  final int stage;

  @override
  String toString() {
    return 'StageRef(chapter: $chapter, stage: $stage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StageRefImpl &&
            (identical(other.chapter, chapter) || other.chapter == chapter) &&
            (identical(other.stage, stage) || other.stage == stage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, chapter, stage);

  /// Create a copy of StageRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StageRefImplCopyWith<_$StageRefImpl> get copyWith =>
      __$$StageRefImplCopyWithImpl<_$StageRefImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StageRefImplToJson(
      this,
    );
  }
}

abstract class _StageRef extends StageRef {
  const factory _StageRef(
      {required final int chapter, required final int stage}) = _$StageRefImpl;
  const _StageRef._() : super._();

  factory _StageRef.fromJson(Map<String, dynamic> json) =
      _$StageRefImpl.fromJson;

  @override
  int get chapter;
  @override
  int get stage;

  /// Create a copy of StageRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StageRefImplCopyWith<_$StageRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RunSnapshot _$RunSnapshotFromJson(Map<String, dynamic> json) {
  return _RunSnapshot.fromJson(json);
}

/// @nodoc
mixin _$RunSnapshot {
  String get runId => throw _privateConstructorUsedError;
  int get seed => throw _privateConstructorUsedError;
  StageRef get stage => throw _privateConstructorUsedError;
  String get heroId => throw _privateConstructorUsedError;
  String get arrowId => throw _privateConstructorUsedError;
  int get roomIndex => throw _privateConstructorUsedError;

  /// Ordered, with duplicates for stacked copies.
  List<String> get boonIds => throw _privateConstructorUsedError;
  int get currentHp => throw _privateConstructorUsedError;
  int get runGold => throw _privateConstructorUsedError;
  Map<String, int> get runMaterials => throw _privateConstructorUsedError;
  @DurationConverter()
  Duration get elapsed => throw _privateConstructorUsedError;
  @UtcDateTimeConverter()
  DateTime get startedAt => throw _privateConstructorUsedError;

  /// Quantised input samples. Optional — omitted on low-end devices where the
  /// memory cost is not worth it, since replay is a nice-to-have and crash
  /// recovery is not.
  List<int>? get inputTape => throw _privateConstructorUsedError;

  /// Serializes this RunSnapshot to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RunSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RunSnapshotCopyWith<RunSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RunSnapshotCopyWith<$Res> {
  factory $RunSnapshotCopyWith(
          RunSnapshot value, $Res Function(RunSnapshot) then) =
      _$RunSnapshotCopyWithImpl<$Res, RunSnapshot>;
  @useResult
  $Res call(
      {String runId,
      int seed,
      StageRef stage,
      String heroId,
      String arrowId,
      int roomIndex,
      List<String> boonIds,
      int currentHp,
      int runGold,
      Map<String, int> runMaterials,
      @DurationConverter() Duration elapsed,
      @UtcDateTimeConverter() DateTime startedAt,
      List<int>? inputTape});

  $StageRefCopyWith<$Res> get stage;
}

/// @nodoc
class _$RunSnapshotCopyWithImpl<$Res, $Val extends RunSnapshot>
    implements $RunSnapshotCopyWith<$Res> {
  _$RunSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RunSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? runId = null,
    Object? seed = null,
    Object? stage = null,
    Object? heroId = null,
    Object? arrowId = null,
    Object? roomIndex = null,
    Object? boonIds = null,
    Object? currentHp = null,
    Object? runGold = null,
    Object? runMaterials = null,
    Object? elapsed = null,
    Object? startedAt = null,
    Object? inputTape = freezed,
  }) {
    return _then(_value.copyWith(
      runId: null == runId
          ? _value.runId
          : runId // ignore: cast_nullable_to_non_nullable
              as String,
      seed: null == seed
          ? _value.seed
          : seed // ignore: cast_nullable_to_non_nullable
              as int,
      stage: null == stage
          ? _value.stage
          : stage // ignore: cast_nullable_to_non_nullable
              as StageRef,
      heroId: null == heroId
          ? _value.heroId
          : heroId // ignore: cast_nullable_to_non_nullable
              as String,
      arrowId: null == arrowId
          ? _value.arrowId
          : arrowId // ignore: cast_nullable_to_non_nullable
              as String,
      roomIndex: null == roomIndex
          ? _value.roomIndex
          : roomIndex // ignore: cast_nullable_to_non_nullable
              as int,
      boonIds: null == boonIds
          ? _value.boonIds
          : boonIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      currentHp: null == currentHp
          ? _value.currentHp
          : currentHp // ignore: cast_nullable_to_non_nullable
              as int,
      runGold: null == runGold
          ? _value.runGold
          : runGold // ignore: cast_nullable_to_non_nullable
              as int,
      runMaterials: null == runMaterials
          ? _value.runMaterials
          : runMaterials // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      elapsed: null == elapsed
          ? _value.elapsed
          : elapsed // ignore: cast_nullable_to_non_nullable
              as Duration,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      inputTape: freezed == inputTape
          ? _value.inputTape
          : inputTape // ignore: cast_nullable_to_non_nullable
              as List<int>?,
    ) as $Val);
  }

  /// Create a copy of RunSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StageRefCopyWith<$Res> get stage {
    return $StageRefCopyWith<$Res>(_value.stage, (value) {
      return _then(_value.copyWith(stage: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RunSnapshotImplCopyWith<$Res>
    implements $RunSnapshotCopyWith<$Res> {
  factory _$$RunSnapshotImplCopyWith(
          _$RunSnapshotImpl value, $Res Function(_$RunSnapshotImpl) then) =
      __$$RunSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String runId,
      int seed,
      StageRef stage,
      String heroId,
      String arrowId,
      int roomIndex,
      List<String> boonIds,
      int currentHp,
      int runGold,
      Map<String, int> runMaterials,
      @DurationConverter() Duration elapsed,
      @UtcDateTimeConverter() DateTime startedAt,
      List<int>? inputTape});

  @override
  $StageRefCopyWith<$Res> get stage;
}

/// @nodoc
class __$$RunSnapshotImplCopyWithImpl<$Res>
    extends _$RunSnapshotCopyWithImpl<$Res, _$RunSnapshotImpl>
    implements _$$RunSnapshotImplCopyWith<$Res> {
  __$$RunSnapshotImplCopyWithImpl(
      _$RunSnapshotImpl _value, $Res Function(_$RunSnapshotImpl) _then)
      : super(_value, _then);

  /// Create a copy of RunSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? runId = null,
    Object? seed = null,
    Object? stage = null,
    Object? heroId = null,
    Object? arrowId = null,
    Object? roomIndex = null,
    Object? boonIds = null,
    Object? currentHp = null,
    Object? runGold = null,
    Object? runMaterials = null,
    Object? elapsed = null,
    Object? startedAt = null,
    Object? inputTape = freezed,
  }) {
    return _then(_$RunSnapshotImpl(
      runId: null == runId
          ? _value.runId
          : runId // ignore: cast_nullable_to_non_nullable
              as String,
      seed: null == seed
          ? _value.seed
          : seed // ignore: cast_nullable_to_non_nullable
              as int,
      stage: null == stage
          ? _value.stage
          : stage // ignore: cast_nullable_to_non_nullable
              as StageRef,
      heroId: null == heroId
          ? _value.heroId
          : heroId // ignore: cast_nullable_to_non_nullable
              as String,
      arrowId: null == arrowId
          ? _value.arrowId
          : arrowId // ignore: cast_nullable_to_non_nullable
              as String,
      roomIndex: null == roomIndex
          ? _value.roomIndex
          : roomIndex // ignore: cast_nullable_to_non_nullable
              as int,
      boonIds: null == boonIds
          ? _value._boonIds
          : boonIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      currentHp: null == currentHp
          ? _value.currentHp
          : currentHp // ignore: cast_nullable_to_non_nullable
              as int,
      runGold: null == runGold
          ? _value.runGold
          : runGold // ignore: cast_nullable_to_non_nullable
              as int,
      runMaterials: null == runMaterials
          ? _value._runMaterials
          : runMaterials // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      elapsed: null == elapsed
          ? _value.elapsed
          : elapsed // ignore: cast_nullable_to_non_nullable
              as Duration,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      inputTape: freezed == inputTape
          ? _value._inputTape
          : inputTape // ignore: cast_nullable_to_non_nullable
              as List<int>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RunSnapshotImpl implements _RunSnapshot {
  const _$RunSnapshotImpl(
      {required this.runId,
      required this.seed,
      required this.stage,
      required this.heroId,
      required this.arrowId,
      required this.roomIndex,
      final List<String> boonIds = const <String>[],
      required this.currentHp,
      this.runGold = 0,
      final Map<String, int> runMaterials = const <String, int>{},
      @DurationConverter() this.elapsed = Duration.zero,
      @UtcDateTimeConverter() required this.startedAt,
      final List<int>? inputTape})
      : _boonIds = boonIds,
        _runMaterials = runMaterials,
        _inputTape = inputTape;

  factory _$RunSnapshotImpl.fromJson(Map<String, dynamic> json) =>
      _$$RunSnapshotImplFromJson(json);

  @override
  final String runId;
  @override
  final int seed;
  @override
  final StageRef stage;
  @override
  final String heroId;
  @override
  final String arrowId;
  @override
  final int roomIndex;

  /// Ordered, with duplicates for stacked copies.
  final List<String> _boonIds;

  /// Ordered, with duplicates for stacked copies.
  @override
  @JsonKey()
  List<String> get boonIds {
    if (_boonIds is EqualUnmodifiableListView) return _boonIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_boonIds);
  }

  @override
  final int currentHp;
  @override
  @JsonKey()
  final int runGold;
  final Map<String, int> _runMaterials;
  @override
  @JsonKey()
  Map<String, int> get runMaterials {
    if (_runMaterials is EqualUnmodifiableMapView) return _runMaterials;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_runMaterials);
  }

  @override
  @JsonKey()
  @DurationConverter()
  final Duration elapsed;
  @override
  @UtcDateTimeConverter()
  final DateTime startedAt;

  /// Quantised input samples. Optional — omitted on low-end devices where the
  /// memory cost is not worth it, since replay is a nice-to-have and crash
  /// recovery is not.
  final List<int>? _inputTape;

  /// Quantised input samples. Optional — omitted on low-end devices where the
  /// memory cost is not worth it, since replay is a nice-to-have and crash
  /// recovery is not.
  @override
  List<int>? get inputTape {
    final value = _inputTape;
    if (value == null) return null;
    if (_inputTape is EqualUnmodifiableListView) return _inputTape;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'RunSnapshot(runId: $runId, seed: $seed, stage: $stage, heroId: $heroId, arrowId: $arrowId, roomIndex: $roomIndex, boonIds: $boonIds, currentHp: $currentHp, runGold: $runGold, runMaterials: $runMaterials, elapsed: $elapsed, startedAt: $startedAt, inputTape: $inputTape)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RunSnapshotImpl &&
            (identical(other.runId, runId) || other.runId == runId) &&
            (identical(other.seed, seed) || other.seed == seed) &&
            (identical(other.stage, stage) || other.stage == stage) &&
            (identical(other.heroId, heroId) || other.heroId == heroId) &&
            (identical(other.arrowId, arrowId) || other.arrowId == arrowId) &&
            (identical(other.roomIndex, roomIndex) ||
                other.roomIndex == roomIndex) &&
            const DeepCollectionEquality().equals(other._boonIds, _boonIds) &&
            (identical(other.currentHp, currentHp) ||
                other.currentHp == currentHp) &&
            (identical(other.runGold, runGold) || other.runGold == runGold) &&
            const DeepCollectionEquality()
                .equals(other._runMaterials, _runMaterials) &&
            (identical(other.elapsed, elapsed) || other.elapsed == elapsed) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            const DeepCollectionEquality()
                .equals(other._inputTape, _inputTape));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      runId,
      seed,
      stage,
      heroId,
      arrowId,
      roomIndex,
      const DeepCollectionEquality().hash(_boonIds),
      currentHp,
      runGold,
      const DeepCollectionEquality().hash(_runMaterials),
      elapsed,
      startedAt,
      const DeepCollectionEquality().hash(_inputTape));

  /// Create a copy of RunSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RunSnapshotImplCopyWith<_$RunSnapshotImpl> get copyWith =>
      __$$RunSnapshotImplCopyWithImpl<_$RunSnapshotImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RunSnapshotImplToJson(
      this,
    );
  }
}

abstract class _RunSnapshot implements RunSnapshot {
  const factory _RunSnapshot(
      {required final String runId,
      required final int seed,
      required final StageRef stage,
      required final String heroId,
      required final String arrowId,
      required final int roomIndex,
      final List<String> boonIds,
      required final int currentHp,
      final int runGold,
      final Map<String, int> runMaterials,
      @DurationConverter() final Duration elapsed,
      @UtcDateTimeConverter() required final DateTime startedAt,
      final List<int>? inputTape}) = _$RunSnapshotImpl;

  factory _RunSnapshot.fromJson(Map<String, dynamic> json) =
      _$RunSnapshotImpl.fromJson;

  @override
  String get runId;
  @override
  int get seed;
  @override
  StageRef get stage;
  @override
  String get heroId;
  @override
  String get arrowId;
  @override
  int get roomIndex;

  /// Ordered, with duplicates for stacked copies.
  @override
  List<String> get boonIds;
  @override
  int get currentHp;
  @override
  int get runGold;
  @override
  Map<String, int> get runMaterials;
  @override
  @DurationConverter()
  Duration get elapsed;
  @override
  @UtcDateTimeConverter()
  DateTime get startedAt;

  /// Quantised input samples. Optional — omitted on low-end devices where the
  /// memory cost is not worth it, since replay is a nice-to-have and crash
  /// recovery is not.
  @override
  List<int>? get inputTape;

  /// Create a copy of RunSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RunSnapshotImplCopyWith<_$RunSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
