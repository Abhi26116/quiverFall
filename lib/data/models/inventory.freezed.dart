// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inventory.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Affix _$AffixFromJson(Map<String, dynamic> json) {
  return _Affix.fromJson(json);
}

/// @nodoc
mixin _$Affix {
  String get affixId => throw _privateConstructorUsedError;

  /// Rolled within the affix's defined range at refine time.
  double get value => throw _privateConstructorUsedError;
  int get tier => throw _privateConstructorUsedError;

  /// Serializes this Affix to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Affix
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AffixCopyWith<Affix> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AffixCopyWith<$Res> {
  factory $AffixCopyWith(Affix value, $Res Function(Affix) then) =
      _$AffixCopyWithImpl<$Res, Affix>;
  @useResult
  $Res call({String affixId, double value, int tier});
}

/// @nodoc
class _$AffixCopyWithImpl<$Res, $Val extends Affix>
    implements $AffixCopyWith<$Res> {
  _$AffixCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Affix
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? affixId = null,
    Object? value = null,
    Object? tier = null,
  }) {
    return _then(_value.copyWith(
      affixId: null == affixId
          ? _value.affixId
          : affixId // ignore: cast_nullable_to_non_nullable
              as String,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      tier: null == tier
          ? _value.tier
          : tier // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AffixImplCopyWith<$Res> implements $AffixCopyWith<$Res> {
  factory _$$AffixImplCopyWith(
          _$AffixImpl value, $Res Function(_$AffixImpl) then) =
      __$$AffixImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String affixId, double value, int tier});
}

/// @nodoc
class __$$AffixImplCopyWithImpl<$Res>
    extends _$AffixCopyWithImpl<$Res, _$AffixImpl>
    implements _$$AffixImplCopyWith<$Res> {
  __$$AffixImplCopyWithImpl(
      _$AffixImpl _value, $Res Function(_$AffixImpl) _then)
      : super(_value, _then);

  /// Create a copy of Affix
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? affixId = null,
    Object? value = null,
    Object? tier = null,
  }) {
    return _then(_$AffixImpl(
      affixId: null == affixId
          ? _value.affixId
          : affixId // ignore: cast_nullable_to_non_nullable
              as String,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      tier: null == tier
          ? _value.tier
          : tier // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AffixImpl implements _Affix {
  const _$AffixImpl(
      {required this.affixId, required this.value, this.tier = 1});

  factory _$AffixImpl.fromJson(Map<String, dynamic> json) =>
      _$$AffixImplFromJson(json);

  @override
  final String affixId;

  /// Rolled within the affix's defined range at refine time.
  @override
  final double value;
  @override
  @JsonKey()
  final int tier;

  @override
  String toString() {
    return 'Affix(affixId: $affixId, value: $value, tier: $tier)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AffixImpl &&
            (identical(other.affixId, affixId) || other.affixId == affixId) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.tier, tier) || other.tier == tier));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, affixId, value, tier);

  /// Create a copy of Affix
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AffixImplCopyWith<_$AffixImpl> get copyWith =>
      __$$AffixImplCopyWithImpl<_$AffixImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AffixImplToJson(
      this,
    );
  }
}

abstract class _Affix implements Affix {
  const factory _Affix(
      {required final String affixId,
      required final double value,
      final int tier}) = _$AffixImpl;

  factory _Affix.fromJson(Map<String, dynamic> json) = _$AffixImpl.fromJson;

  @override
  String get affixId;

  /// Rolled within the affix's defined range at refine time.
  @override
  double get value;
  @override
  int get tier;

  /// Create a copy of Affix
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AffixImplCopyWith<_$AffixImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ArrowInstance _$ArrowInstanceFromJson(Map<String, dynamic> json) {
  return _ArrowInstance.fromJson(json);
}

/// @nodoc
mixin _$ArrowInstance {
  String get arrowId => throw _privateConstructorUsedError;
  bool get crafted => throw _privateConstructorUsedError;
  int get refineLevel => throw _privateConstructorUsedError;
  List<Affix> get affixes => throw _privateConstructorUsedError;

  /// Up to 2 slots may be locked against a reroll. This is the honest version
  /// of the reroll sink: a player is never forced to gamble away a good roll
  /// in order to fix a bad one.
  Set<int> get lockedAffixSlots => throw _privateConstructorUsedError;

  /// Serializes this ArrowInstance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ArrowInstance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ArrowInstanceCopyWith<ArrowInstance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ArrowInstanceCopyWith<$Res> {
  factory $ArrowInstanceCopyWith(
          ArrowInstance value, $Res Function(ArrowInstance) then) =
      _$ArrowInstanceCopyWithImpl<$Res, ArrowInstance>;
  @useResult
  $Res call(
      {String arrowId,
      bool crafted,
      int refineLevel,
      List<Affix> affixes,
      Set<int> lockedAffixSlots});
}

/// @nodoc
class _$ArrowInstanceCopyWithImpl<$Res, $Val extends ArrowInstance>
    implements $ArrowInstanceCopyWith<$Res> {
  _$ArrowInstanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ArrowInstance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? arrowId = null,
    Object? crafted = null,
    Object? refineLevel = null,
    Object? affixes = null,
    Object? lockedAffixSlots = null,
  }) {
    return _then(_value.copyWith(
      arrowId: null == arrowId
          ? _value.arrowId
          : arrowId // ignore: cast_nullable_to_non_nullable
              as String,
      crafted: null == crafted
          ? _value.crafted
          : crafted // ignore: cast_nullable_to_non_nullable
              as bool,
      refineLevel: null == refineLevel
          ? _value.refineLevel
          : refineLevel // ignore: cast_nullable_to_non_nullable
              as int,
      affixes: null == affixes
          ? _value.affixes
          : affixes // ignore: cast_nullable_to_non_nullable
              as List<Affix>,
      lockedAffixSlots: null == lockedAffixSlots
          ? _value.lockedAffixSlots
          : lockedAffixSlots // ignore: cast_nullable_to_non_nullable
              as Set<int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ArrowInstanceImplCopyWith<$Res>
    implements $ArrowInstanceCopyWith<$Res> {
  factory _$$ArrowInstanceImplCopyWith(
          _$ArrowInstanceImpl value, $Res Function(_$ArrowInstanceImpl) then) =
      __$$ArrowInstanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String arrowId,
      bool crafted,
      int refineLevel,
      List<Affix> affixes,
      Set<int> lockedAffixSlots});
}

/// @nodoc
class __$$ArrowInstanceImplCopyWithImpl<$Res>
    extends _$ArrowInstanceCopyWithImpl<$Res, _$ArrowInstanceImpl>
    implements _$$ArrowInstanceImplCopyWith<$Res> {
  __$$ArrowInstanceImplCopyWithImpl(
      _$ArrowInstanceImpl _value, $Res Function(_$ArrowInstanceImpl) _then)
      : super(_value, _then);

  /// Create a copy of ArrowInstance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? arrowId = null,
    Object? crafted = null,
    Object? refineLevel = null,
    Object? affixes = null,
    Object? lockedAffixSlots = null,
  }) {
    return _then(_$ArrowInstanceImpl(
      arrowId: null == arrowId
          ? _value.arrowId
          : arrowId // ignore: cast_nullable_to_non_nullable
              as String,
      crafted: null == crafted
          ? _value.crafted
          : crafted // ignore: cast_nullable_to_non_nullable
              as bool,
      refineLevel: null == refineLevel
          ? _value.refineLevel
          : refineLevel // ignore: cast_nullable_to_non_nullable
              as int,
      affixes: null == affixes
          ? _value._affixes
          : affixes // ignore: cast_nullable_to_non_nullable
              as List<Affix>,
      lockedAffixSlots: null == lockedAffixSlots
          ? _value._lockedAffixSlots
          : lockedAffixSlots // ignore: cast_nullable_to_non_nullable
              as Set<int>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ArrowInstanceImpl extends _ArrowInstance {
  const _$ArrowInstanceImpl(
      {required this.arrowId,
      this.crafted = false,
      this.refineLevel = 0,
      final List<Affix> affixes = const <Affix>[],
      final Set<int> lockedAffixSlots = const <int>{}})
      : _affixes = affixes,
        _lockedAffixSlots = lockedAffixSlots,
        super._();

  factory _$ArrowInstanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$ArrowInstanceImplFromJson(json);

  @override
  final String arrowId;
  @override
  @JsonKey()
  final bool crafted;
  @override
  @JsonKey()
  final int refineLevel;
  final List<Affix> _affixes;
  @override
  @JsonKey()
  List<Affix> get affixes {
    if (_affixes is EqualUnmodifiableListView) return _affixes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_affixes);
  }

  /// Up to 2 slots may be locked against a reroll. This is the honest version
  /// of the reroll sink: a player is never forced to gamble away a good roll
  /// in order to fix a bad one.
  final Set<int> _lockedAffixSlots;

  /// Up to 2 slots may be locked against a reroll. This is the honest version
  /// of the reroll sink: a player is never forced to gamble away a good roll
  /// in order to fix a bad one.
  @override
  @JsonKey()
  Set<int> get lockedAffixSlots {
    if (_lockedAffixSlots is EqualUnmodifiableSetView) return _lockedAffixSlots;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_lockedAffixSlots);
  }

  @override
  String toString() {
    return 'ArrowInstance(arrowId: $arrowId, crafted: $crafted, refineLevel: $refineLevel, affixes: $affixes, lockedAffixSlots: $lockedAffixSlots)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ArrowInstanceImpl &&
            (identical(other.arrowId, arrowId) || other.arrowId == arrowId) &&
            (identical(other.crafted, crafted) || other.crafted == crafted) &&
            (identical(other.refineLevel, refineLevel) ||
                other.refineLevel == refineLevel) &&
            const DeepCollectionEquality().equals(other._affixes, _affixes) &&
            const DeepCollectionEquality()
                .equals(other._lockedAffixSlots, _lockedAffixSlots));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      arrowId,
      crafted,
      refineLevel,
      const DeepCollectionEquality().hash(_affixes),
      const DeepCollectionEquality().hash(_lockedAffixSlots));

  /// Create a copy of ArrowInstance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ArrowInstanceImplCopyWith<_$ArrowInstanceImpl> get copyWith =>
      __$$ArrowInstanceImplCopyWithImpl<_$ArrowInstanceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ArrowInstanceImplToJson(
      this,
    );
  }
}

abstract class _ArrowInstance extends ArrowInstance {
  const factory _ArrowInstance(
      {required final String arrowId,
      final bool crafted,
      final int refineLevel,
      final List<Affix> affixes,
      final Set<int> lockedAffixSlots}) = _$ArrowInstanceImpl;
  const _ArrowInstance._() : super._();

  factory _ArrowInstance.fromJson(Map<String, dynamic> json) =
      _$ArrowInstanceImpl.fromJson;

  @override
  String get arrowId;
  @override
  bool get crafted;
  @override
  int get refineLevel;
  @override
  List<Affix> get affixes;

  /// Up to 2 slots may be locked against a reroll. This is the honest version
  /// of the reroll sink: a player is never forced to gamble away a good roll
  /// in order to fix a bad one.
  @override
  Set<int> get lockedAffixSlots;

  /// Create a copy of ArrowInstance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ArrowInstanceImplCopyWith<_$ArrowInstanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

InventoryState _$InventoryStateFromJson(Map<String, dynamic> json) {
  return _InventoryState.fromJson(json);
}

/// @nodoc
mixin _$InventoryState {
  /// arrowId -> instance.
  Map<String, ArrowInstance> get arrows => throw _privateConstructorUsedError;
  Set<String> get cosmeticIds => throw _privateConstructorUsedError;
  Set<String> get windlineSkinIds => throw _privateConstructorUsedError;

  /// Reroll cost escalates +15% per use within a session, then resets daily.
  /// This is the uncapped drain that scales with how rich the player is —
  /// see docs/02-economy.md §2.11.
  int get rerollCountThisSession => throw _privateConstructorUsedError;

  /// Serializes this InventoryState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InventoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InventoryStateCopyWith<InventoryState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InventoryStateCopyWith<$Res> {
  factory $InventoryStateCopyWith(
          InventoryState value, $Res Function(InventoryState) then) =
      _$InventoryStateCopyWithImpl<$Res, InventoryState>;
  @useResult
  $Res call(
      {Map<String, ArrowInstance> arrows,
      Set<String> cosmeticIds,
      Set<String> windlineSkinIds,
      int rerollCountThisSession});
}

/// @nodoc
class _$InventoryStateCopyWithImpl<$Res, $Val extends InventoryState>
    implements $InventoryStateCopyWith<$Res> {
  _$InventoryStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InventoryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? arrows = null,
    Object? cosmeticIds = null,
    Object? windlineSkinIds = null,
    Object? rerollCountThisSession = null,
  }) {
    return _then(_value.copyWith(
      arrows: null == arrows
          ? _value.arrows
          : arrows // ignore: cast_nullable_to_non_nullable
              as Map<String, ArrowInstance>,
      cosmeticIds: null == cosmeticIds
          ? _value.cosmeticIds
          : cosmeticIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      windlineSkinIds: null == windlineSkinIds
          ? _value.windlineSkinIds
          : windlineSkinIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      rerollCountThisSession: null == rerollCountThisSession
          ? _value.rerollCountThisSession
          : rerollCountThisSession // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InventoryStateImplCopyWith<$Res>
    implements $InventoryStateCopyWith<$Res> {
  factory _$$InventoryStateImplCopyWith(_$InventoryStateImpl value,
          $Res Function(_$InventoryStateImpl) then) =
      __$$InventoryStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Map<String, ArrowInstance> arrows,
      Set<String> cosmeticIds,
      Set<String> windlineSkinIds,
      int rerollCountThisSession});
}

/// @nodoc
class __$$InventoryStateImplCopyWithImpl<$Res>
    extends _$InventoryStateCopyWithImpl<$Res, _$InventoryStateImpl>
    implements _$$InventoryStateImplCopyWith<$Res> {
  __$$InventoryStateImplCopyWithImpl(
      _$InventoryStateImpl _value, $Res Function(_$InventoryStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of InventoryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? arrows = null,
    Object? cosmeticIds = null,
    Object? windlineSkinIds = null,
    Object? rerollCountThisSession = null,
  }) {
    return _then(_$InventoryStateImpl(
      arrows: null == arrows
          ? _value._arrows
          : arrows // ignore: cast_nullable_to_non_nullable
              as Map<String, ArrowInstance>,
      cosmeticIds: null == cosmeticIds
          ? _value._cosmeticIds
          : cosmeticIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      windlineSkinIds: null == windlineSkinIds
          ? _value._windlineSkinIds
          : windlineSkinIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      rerollCountThisSession: null == rerollCountThisSession
          ? _value.rerollCountThisSession
          : rerollCountThisSession // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InventoryStateImpl implements _InventoryState {
  const _$InventoryStateImpl(
      {final Map<String, ArrowInstance> arrows =
          const <String, ArrowInstance>{},
      final Set<String> cosmeticIds = const <String>{},
      final Set<String> windlineSkinIds = const <String>{},
      this.rerollCountThisSession = 0})
      : _arrows = arrows,
        _cosmeticIds = cosmeticIds,
        _windlineSkinIds = windlineSkinIds;

  factory _$InventoryStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$InventoryStateImplFromJson(json);

  /// arrowId -> instance.
  final Map<String, ArrowInstance> _arrows;

  /// arrowId -> instance.
  @override
  @JsonKey()
  Map<String, ArrowInstance> get arrows {
    if (_arrows is EqualUnmodifiableMapView) return _arrows;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_arrows);
  }

  final Set<String> _cosmeticIds;
  @override
  @JsonKey()
  Set<String> get cosmeticIds {
    if (_cosmeticIds is EqualUnmodifiableSetView) return _cosmeticIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_cosmeticIds);
  }

  final Set<String> _windlineSkinIds;
  @override
  @JsonKey()
  Set<String> get windlineSkinIds {
    if (_windlineSkinIds is EqualUnmodifiableSetView) return _windlineSkinIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_windlineSkinIds);
  }

  /// Reroll cost escalates +15% per use within a session, then resets daily.
  /// This is the uncapped drain that scales with how rich the player is —
  /// see docs/02-economy.md §2.11.
  @override
  @JsonKey()
  final int rerollCountThisSession;

  @override
  String toString() {
    return 'InventoryState(arrows: $arrows, cosmeticIds: $cosmeticIds, windlineSkinIds: $windlineSkinIds, rerollCountThisSession: $rerollCountThisSession)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InventoryStateImpl &&
            const DeepCollectionEquality().equals(other._arrows, _arrows) &&
            const DeepCollectionEquality()
                .equals(other._cosmeticIds, _cosmeticIds) &&
            const DeepCollectionEquality()
                .equals(other._windlineSkinIds, _windlineSkinIds) &&
            (identical(other.rerollCountThisSession, rerollCountThisSession) ||
                other.rerollCountThisSession == rerollCountThisSession));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_arrows),
      const DeepCollectionEquality().hash(_cosmeticIds),
      const DeepCollectionEquality().hash(_windlineSkinIds),
      rerollCountThisSession);

  /// Create a copy of InventoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InventoryStateImplCopyWith<_$InventoryStateImpl> get copyWith =>
      __$$InventoryStateImplCopyWithImpl<_$InventoryStateImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InventoryStateImplToJson(
      this,
    );
  }
}

abstract class _InventoryState implements InventoryState {
  const factory _InventoryState(
      {final Map<String, ArrowInstance> arrows,
      final Set<String> cosmeticIds,
      final Set<String> windlineSkinIds,
      final int rerollCountThisSession}) = _$InventoryStateImpl;

  factory _InventoryState.fromJson(Map<String, dynamic> json) =
      _$InventoryStateImpl.fromJson;

  /// arrowId -> instance.
  @override
  Map<String, ArrowInstance> get arrows;
  @override
  Set<String> get cosmeticIds;
  @override
  Set<String> get windlineSkinIds;

  /// Reroll cost escalates +15% per use within a session, then resets daily.
  /// This is the uncapped drain that scales with how rich the player is —
  /// see docs/02-economy.md §2.11.
  @override
  int get rerollCountThisSession;

  /// Create a copy of InventoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InventoryStateImplCopyWith<_$InventoryStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
