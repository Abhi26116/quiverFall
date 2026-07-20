// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_save.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Loadout _$LoadoutFromJson(Map<String, dynamic> json) {
  return _Loadout.fromJson(json);
}

/// @nodoc
mixin _$Loadout {
  String get name => throw _privateConstructorUsedError;
  String get heroId => throw _privateConstructorUsedError;
  String get arrowId => throw _privateConstructorUsedError;
  List<String> get markIds => throw _privateConstructorUsedError;

  /// Serializes this Loadout to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Loadout
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LoadoutCopyWith<Loadout> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LoadoutCopyWith<$Res> {
  factory $LoadoutCopyWith(Loadout value, $Res Function(Loadout) then) =
      _$LoadoutCopyWithImpl<$Res, Loadout>;
  @useResult
  $Res call({String name, String heroId, String arrowId, List<String> markIds});
}

/// @nodoc
class _$LoadoutCopyWithImpl<$Res, $Val extends Loadout>
    implements $LoadoutCopyWith<$Res> {
  _$LoadoutCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Loadout
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? heroId = null,
    Object? arrowId = null,
    Object? markIds = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      heroId: null == heroId
          ? _value.heroId
          : heroId // ignore: cast_nullable_to_non_nullable
              as String,
      arrowId: null == arrowId
          ? _value.arrowId
          : arrowId // ignore: cast_nullable_to_non_nullable
              as String,
      markIds: null == markIds
          ? _value.markIds
          : markIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LoadoutImplCopyWith<$Res> implements $LoadoutCopyWith<$Res> {
  factory _$$LoadoutImplCopyWith(
          _$LoadoutImpl value, $Res Function(_$LoadoutImpl) then) =
      __$$LoadoutImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String heroId, String arrowId, List<String> markIds});
}

/// @nodoc
class __$$LoadoutImplCopyWithImpl<$Res>
    extends _$LoadoutCopyWithImpl<$Res, _$LoadoutImpl>
    implements _$$LoadoutImplCopyWith<$Res> {
  __$$LoadoutImplCopyWithImpl(
      _$LoadoutImpl _value, $Res Function(_$LoadoutImpl) _then)
      : super(_value, _then);

  /// Create a copy of Loadout
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? heroId = null,
    Object? arrowId = null,
    Object? markIds = null,
  }) {
    return _then(_$LoadoutImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      heroId: null == heroId
          ? _value.heroId
          : heroId // ignore: cast_nullable_to_non_nullable
              as String,
      arrowId: null == arrowId
          ? _value.arrowId
          : arrowId // ignore: cast_nullable_to_non_nullable
              as String,
      markIds: null == markIds
          ? _value._markIds
          : markIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LoadoutImpl implements _Loadout {
  const _$LoadoutImpl(
      {required this.name,
      required this.heroId,
      required this.arrowId,
      final List<String> markIds = const <String>[]})
      : _markIds = markIds;

  factory _$LoadoutImpl.fromJson(Map<String, dynamic> json) =>
      _$$LoadoutImplFromJson(json);

  @override
  final String name;
  @override
  final String heroId;
  @override
  final String arrowId;
  final List<String> _markIds;
  @override
  @JsonKey()
  List<String> get markIds {
    if (_markIds is EqualUnmodifiableListView) return _markIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_markIds);
  }

  @override
  String toString() {
    return 'Loadout(name: $name, heroId: $heroId, arrowId: $arrowId, markIds: $markIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LoadoutImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.heroId, heroId) || other.heroId == heroId) &&
            (identical(other.arrowId, arrowId) || other.arrowId == arrowId) &&
            const DeepCollectionEquality().equals(other._markIds, _markIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, heroId, arrowId,
      const DeepCollectionEquality().hash(_markIds));

  /// Create a copy of Loadout
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LoadoutImplCopyWith<_$LoadoutImpl> get copyWith =>
      __$$LoadoutImplCopyWithImpl<_$LoadoutImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LoadoutImplToJson(
      this,
    );
  }
}

abstract class _Loadout implements Loadout {
  const factory _Loadout(
      {required final String name,
      required final String heroId,
      required final String arrowId,
      final List<String> markIds}) = _$LoadoutImpl;

  factory _Loadout.fromJson(Map<String, dynamic> json) = _$LoadoutImpl.fromJson;

  @override
  String get name;
  @override
  String get heroId;
  @override
  String get arrowId;
  @override
  List<String> get markIds;

  /// Create a copy of Loadout
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LoadoutImplCopyWith<_$LoadoutImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlayerProfile _$PlayerProfileFromJson(Map<String, dynamic> json) {
  return _PlayerProfile.fromJson(json);
}

/// @nodoc
mixin _$PlayerProfile {
  int get accountLevel => throw _privateConstructorUsedError;
  int get accountXp => throw _privateConstructorUsedError;
  String get equippedHeroId => throw _privateConstructorUsedError;
  String get equippedArrowId => throw _privateConstructorUsedError;

  /// Max 6, unlocked at account levels 12/20/30/45/65/90.
  List<String> get equippedMarkIds => throw _privateConstructorUsedError;
  List<Loadout> get loadouts => throw _privateConstructorUsedError;
  String? get avatarId => throw _privateConstructorUsedError;
  String? get titleId => throw _privateConstructorUsedError;

  /// 'low' | 'mid' | 'high', assigned by the boot benchmark.
  String get deviceTier => throw _privateConstructorUsedError;

  /// Serializes this PlayerProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlayerProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlayerProfileCopyWith<PlayerProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlayerProfileCopyWith<$Res> {
  factory $PlayerProfileCopyWith(
          PlayerProfile value, $Res Function(PlayerProfile) then) =
      _$PlayerProfileCopyWithImpl<$Res, PlayerProfile>;
  @useResult
  $Res call(
      {int accountLevel,
      int accountXp,
      String equippedHeroId,
      String equippedArrowId,
      List<String> equippedMarkIds,
      List<Loadout> loadouts,
      String? avatarId,
      String? titleId,
      String deviceTier});
}

/// @nodoc
class _$PlayerProfileCopyWithImpl<$Res, $Val extends PlayerProfile>
    implements $PlayerProfileCopyWith<$Res> {
  _$PlayerProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlayerProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accountLevel = null,
    Object? accountXp = null,
    Object? equippedHeroId = null,
    Object? equippedArrowId = null,
    Object? equippedMarkIds = null,
    Object? loadouts = null,
    Object? avatarId = freezed,
    Object? titleId = freezed,
    Object? deviceTier = null,
  }) {
    return _then(_value.copyWith(
      accountLevel: null == accountLevel
          ? _value.accountLevel
          : accountLevel // ignore: cast_nullable_to_non_nullable
              as int,
      accountXp: null == accountXp
          ? _value.accountXp
          : accountXp // ignore: cast_nullable_to_non_nullable
              as int,
      equippedHeroId: null == equippedHeroId
          ? _value.equippedHeroId
          : equippedHeroId // ignore: cast_nullable_to_non_nullable
              as String,
      equippedArrowId: null == equippedArrowId
          ? _value.equippedArrowId
          : equippedArrowId // ignore: cast_nullable_to_non_nullable
              as String,
      equippedMarkIds: null == equippedMarkIds
          ? _value.equippedMarkIds
          : equippedMarkIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      loadouts: null == loadouts
          ? _value.loadouts
          : loadouts // ignore: cast_nullable_to_non_nullable
              as List<Loadout>,
      avatarId: freezed == avatarId
          ? _value.avatarId
          : avatarId // ignore: cast_nullable_to_non_nullable
              as String?,
      titleId: freezed == titleId
          ? _value.titleId
          : titleId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceTier: null == deviceTier
          ? _value.deviceTier
          : deviceTier // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlayerProfileImplCopyWith<$Res>
    implements $PlayerProfileCopyWith<$Res> {
  factory _$$PlayerProfileImplCopyWith(
          _$PlayerProfileImpl value, $Res Function(_$PlayerProfileImpl) then) =
      __$$PlayerProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int accountLevel,
      int accountXp,
      String equippedHeroId,
      String equippedArrowId,
      List<String> equippedMarkIds,
      List<Loadout> loadouts,
      String? avatarId,
      String? titleId,
      String deviceTier});
}

/// @nodoc
class __$$PlayerProfileImplCopyWithImpl<$Res>
    extends _$PlayerProfileCopyWithImpl<$Res, _$PlayerProfileImpl>
    implements _$$PlayerProfileImplCopyWith<$Res> {
  __$$PlayerProfileImplCopyWithImpl(
      _$PlayerProfileImpl _value, $Res Function(_$PlayerProfileImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlayerProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accountLevel = null,
    Object? accountXp = null,
    Object? equippedHeroId = null,
    Object? equippedArrowId = null,
    Object? equippedMarkIds = null,
    Object? loadouts = null,
    Object? avatarId = freezed,
    Object? titleId = freezed,
    Object? deviceTier = null,
  }) {
    return _then(_$PlayerProfileImpl(
      accountLevel: null == accountLevel
          ? _value.accountLevel
          : accountLevel // ignore: cast_nullable_to_non_nullable
              as int,
      accountXp: null == accountXp
          ? _value.accountXp
          : accountXp // ignore: cast_nullable_to_non_nullable
              as int,
      equippedHeroId: null == equippedHeroId
          ? _value.equippedHeroId
          : equippedHeroId // ignore: cast_nullable_to_non_nullable
              as String,
      equippedArrowId: null == equippedArrowId
          ? _value.equippedArrowId
          : equippedArrowId // ignore: cast_nullable_to_non_nullable
              as String,
      equippedMarkIds: null == equippedMarkIds
          ? _value._equippedMarkIds
          : equippedMarkIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      loadouts: null == loadouts
          ? _value._loadouts
          : loadouts // ignore: cast_nullable_to_non_nullable
              as List<Loadout>,
      avatarId: freezed == avatarId
          ? _value.avatarId
          : avatarId // ignore: cast_nullable_to_non_nullable
              as String?,
      titleId: freezed == titleId
          ? _value.titleId
          : titleId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceTier: null == deviceTier
          ? _value.deviceTier
          : deviceTier // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlayerProfileImpl extends _PlayerProfile {
  const _$PlayerProfileImpl(
      {this.accountLevel = 1,
      this.accountXp = 0,
      this.equippedHeroId = 'wren',
      this.equippedArrowId = 'ash_shaft',
      final List<String> equippedMarkIds = const <String>[],
      final List<Loadout> loadouts = const <Loadout>[],
      this.avatarId,
      this.titleId,
      this.deviceTier = 'mid'})
      : _equippedMarkIds = equippedMarkIds,
        _loadouts = loadouts,
        super._();

  factory _$PlayerProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlayerProfileImplFromJson(json);

  @override
  @JsonKey()
  final int accountLevel;
  @override
  @JsonKey()
  final int accountXp;
  @override
  @JsonKey()
  final String equippedHeroId;
  @override
  @JsonKey()
  final String equippedArrowId;

  /// Max 6, unlocked at account levels 12/20/30/45/65/90.
  final List<String> _equippedMarkIds;

  /// Max 6, unlocked at account levels 12/20/30/45/65/90.
  @override
  @JsonKey()
  List<String> get equippedMarkIds {
    if (_equippedMarkIds is EqualUnmodifiableListView) return _equippedMarkIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_equippedMarkIds);
  }

  final List<Loadout> _loadouts;
  @override
  @JsonKey()
  List<Loadout> get loadouts {
    if (_loadouts is EqualUnmodifiableListView) return _loadouts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_loadouts);
  }

  @override
  final String? avatarId;
  @override
  final String? titleId;

  /// 'low' | 'mid' | 'high', assigned by the boot benchmark.
  @override
  @JsonKey()
  final String deviceTier;

  @override
  String toString() {
    return 'PlayerProfile(accountLevel: $accountLevel, accountXp: $accountXp, equippedHeroId: $equippedHeroId, equippedArrowId: $equippedArrowId, equippedMarkIds: $equippedMarkIds, loadouts: $loadouts, avatarId: $avatarId, titleId: $titleId, deviceTier: $deviceTier)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayerProfileImpl &&
            (identical(other.accountLevel, accountLevel) ||
                other.accountLevel == accountLevel) &&
            (identical(other.accountXp, accountXp) ||
                other.accountXp == accountXp) &&
            (identical(other.equippedHeroId, equippedHeroId) ||
                other.equippedHeroId == equippedHeroId) &&
            (identical(other.equippedArrowId, equippedArrowId) ||
                other.equippedArrowId == equippedArrowId) &&
            const DeepCollectionEquality()
                .equals(other._equippedMarkIds, _equippedMarkIds) &&
            const DeepCollectionEquality().equals(other._loadouts, _loadouts) &&
            (identical(other.avatarId, avatarId) ||
                other.avatarId == avatarId) &&
            (identical(other.titleId, titleId) || other.titleId == titleId) &&
            (identical(other.deviceTier, deviceTier) ||
                other.deviceTier == deviceTier));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      accountLevel,
      accountXp,
      equippedHeroId,
      equippedArrowId,
      const DeepCollectionEquality().hash(_equippedMarkIds),
      const DeepCollectionEquality().hash(_loadouts),
      avatarId,
      titleId,
      deviceTier);

  /// Create a copy of PlayerProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayerProfileImplCopyWith<_$PlayerProfileImpl> get copyWith =>
      __$$PlayerProfileImplCopyWithImpl<_$PlayerProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlayerProfileImplToJson(
      this,
    );
  }
}

abstract class _PlayerProfile extends PlayerProfile {
  const factory _PlayerProfile(
      {final int accountLevel,
      final int accountXp,
      final String equippedHeroId,
      final String equippedArrowId,
      final List<String> equippedMarkIds,
      final List<Loadout> loadouts,
      final String? avatarId,
      final String? titleId,
      final String deviceTier}) = _$PlayerProfileImpl;
  const _PlayerProfile._() : super._();

  factory _PlayerProfile.fromJson(Map<String, dynamic> json) =
      _$PlayerProfileImpl.fromJson;

  @override
  int get accountLevel;
  @override
  int get accountXp;
  @override
  String get equippedHeroId;
  @override
  String get equippedArrowId;

  /// Max 6, unlocked at account levels 12/20/30/45/65/90.
  @override
  List<String> get equippedMarkIds;
  @override
  List<Loadout> get loadouts;
  @override
  String? get avatarId;
  @override
  String? get titleId;

  /// 'low' | 'mid' | 'high', assigned by the boot benchmark.
  @override
  String get deviceTier;

  /// Create a copy of PlayerProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayerProfileImplCopyWith<_$PlayerProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Wallet _$WalletFromJson(Map<String, dynamic> json) {
  return _Wallet.fromJson(json);
}

/// @nodoc
mixin _$Wallet {
  int get gold => throw _privateConstructorUsedError;
  int get gems => throw _privateConstructorUsedError;

  /// Unpurchasable at any price. Gates Spire tier bands.
  int get insight => throw _privateConstructorUsedError;

  /// Unpurchasable at any price. Prestige currency.
  int get emberdust => throw _privateConstructorUsedError;
  Map<String, int> get materials => throw _privateConstructorUsedError;
  Map<String, int> get heroShards => throw _privateConstructorUsedError;
  Map<String, int> get eventTokens => throw _privateConstructorUsedError;

  /// Serializes this Wallet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WalletCopyWith<Wallet> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WalletCopyWith<$Res> {
  factory $WalletCopyWith(Wallet value, $Res Function(Wallet) then) =
      _$WalletCopyWithImpl<$Res, Wallet>;
  @useResult
  $Res call(
      {int gold,
      int gems,
      int insight,
      int emberdust,
      Map<String, int> materials,
      Map<String, int> heroShards,
      Map<String, int> eventTokens});
}

/// @nodoc
class _$WalletCopyWithImpl<$Res, $Val extends Wallet>
    implements $WalletCopyWith<$Res> {
  _$WalletCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gold = null,
    Object? gems = null,
    Object? insight = null,
    Object? emberdust = null,
    Object? materials = null,
    Object? heroShards = null,
    Object? eventTokens = null,
  }) {
    return _then(_value.copyWith(
      gold: null == gold
          ? _value.gold
          : gold // ignore: cast_nullable_to_non_nullable
              as int,
      gems: null == gems
          ? _value.gems
          : gems // ignore: cast_nullable_to_non_nullable
              as int,
      insight: null == insight
          ? _value.insight
          : insight // ignore: cast_nullable_to_non_nullable
              as int,
      emberdust: null == emberdust
          ? _value.emberdust
          : emberdust // ignore: cast_nullable_to_non_nullable
              as int,
      materials: null == materials
          ? _value.materials
          : materials // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      heroShards: null == heroShards
          ? _value.heroShards
          : heroShards // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      eventTokens: null == eventTokens
          ? _value.eventTokens
          : eventTokens // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WalletImplCopyWith<$Res> implements $WalletCopyWith<$Res> {
  factory _$$WalletImplCopyWith(
          _$WalletImpl value, $Res Function(_$WalletImpl) then) =
      __$$WalletImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int gold,
      int gems,
      int insight,
      int emberdust,
      Map<String, int> materials,
      Map<String, int> heroShards,
      Map<String, int> eventTokens});
}

/// @nodoc
class __$$WalletImplCopyWithImpl<$Res>
    extends _$WalletCopyWithImpl<$Res, _$WalletImpl>
    implements _$$WalletImplCopyWith<$Res> {
  __$$WalletImplCopyWithImpl(
      _$WalletImpl _value, $Res Function(_$WalletImpl) _then)
      : super(_value, _then);

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gold = null,
    Object? gems = null,
    Object? insight = null,
    Object? emberdust = null,
    Object? materials = null,
    Object? heroShards = null,
    Object? eventTokens = null,
  }) {
    return _then(_$WalletImpl(
      gold: null == gold
          ? _value.gold
          : gold // ignore: cast_nullable_to_non_nullable
              as int,
      gems: null == gems
          ? _value.gems
          : gems // ignore: cast_nullable_to_non_nullable
              as int,
      insight: null == insight
          ? _value.insight
          : insight // ignore: cast_nullable_to_non_nullable
              as int,
      emberdust: null == emberdust
          ? _value.emberdust
          : emberdust // ignore: cast_nullable_to_non_nullable
              as int,
      materials: null == materials
          ? _value._materials
          : materials // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      heroShards: null == heroShards
          ? _value._heroShards
          : heroShards // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      eventTokens: null == eventTokens
          ? _value._eventTokens
          : eventTokens // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WalletImpl extends _Wallet {
  const _$WalletImpl(
      {this.gold = 0,
      this.gems = 0,
      this.insight = 0,
      this.emberdust = 0,
      final Map<String, int> materials = const <String, int>{},
      final Map<String, int> heroShards = const <String, int>{},
      final Map<String, int> eventTokens = const <String, int>{}})
      : _materials = materials,
        _heroShards = heroShards,
        _eventTokens = eventTokens,
        super._();

  factory _$WalletImpl.fromJson(Map<String, dynamic> json) =>
      _$$WalletImplFromJson(json);

  @override
  @JsonKey()
  final int gold;
  @override
  @JsonKey()
  final int gems;

  /// Unpurchasable at any price. Gates Spire tier bands.
  @override
  @JsonKey()
  final int insight;

  /// Unpurchasable at any price. Prestige currency.
  @override
  @JsonKey()
  final int emberdust;
  final Map<String, int> _materials;
  @override
  @JsonKey()
  Map<String, int> get materials {
    if (_materials is EqualUnmodifiableMapView) return _materials;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_materials);
  }

  final Map<String, int> _heroShards;
  @override
  @JsonKey()
  Map<String, int> get heroShards {
    if (_heroShards is EqualUnmodifiableMapView) return _heroShards;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_heroShards);
  }

  final Map<String, int> _eventTokens;
  @override
  @JsonKey()
  Map<String, int> get eventTokens {
    if (_eventTokens is EqualUnmodifiableMapView) return _eventTokens;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_eventTokens);
  }

  @override
  String toString() {
    return 'Wallet(gold: $gold, gems: $gems, insight: $insight, emberdust: $emberdust, materials: $materials, heroShards: $heroShards, eventTokens: $eventTokens)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WalletImpl &&
            (identical(other.gold, gold) || other.gold == gold) &&
            (identical(other.gems, gems) || other.gems == gems) &&
            (identical(other.insight, insight) || other.insight == insight) &&
            (identical(other.emberdust, emberdust) ||
                other.emberdust == emberdust) &&
            const DeepCollectionEquality()
                .equals(other._materials, _materials) &&
            const DeepCollectionEquality()
                .equals(other._heroShards, _heroShards) &&
            const DeepCollectionEquality()
                .equals(other._eventTokens, _eventTokens));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      gold,
      gems,
      insight,
      emberdust,
      const DeepCollectionEquality().hash(_materials),
      const DeepCollectionEquality().hash(_heroShards),
      const DeepCollectionEquality().hash(_eventTokens));

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WalletImplCopyWith<_$WalletImpl> get copyWith =>
      __$$WalletImplCopyWithImpl<_$WalletImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WalletImplToJson(
      this,
    );
  }
}

abstract class _Wallet extends Wallet {
  const factory _Wallet(
      {final int gold,
      final int gems,
      final int insight,
      final int emberdust,
      final Map<String, int> materials,
      final Map<String, int> heroShards,
      final Map<String, int> eventTokens}) = _$WalletImpl;
  const _Wallet._() : super._();

  factory _Wallet.fromJson(Map<String, dynamic> json) = _$WalletImpl.fromJson;

  @override
  int get gold;
  @override
  int get gems;

  /// Unpurchasable at any price. Gates Spire tier bands.
  @override
  int get insight;

  /// Unpurchasable at any price. Prestige currency.
  @override
  int get emberdust;
  @override
  Map<String, int> get materials;
  @override
  Map<String, int> get heroShards;
  @override
  Map<String, int> get eventTokens;

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WalletImplCopyWith<_$WalletImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VigorState _$VigorStateFromJson(Map<String, dynamic> json) {
  return _VigorState.fromJson(json);
}

/// @nodoc
mixin _$VigorState {
  int get current => throw _privateConstructorUsedError;
  int get max => throw _privateConstructorUsedError;

  /// Regen anchor. Vigor is *computed* from this on read, never stored as a
  /// ticking value, so background time is credited without a timer.
  @UtcDateTimeConverter()
  DateTime get lastTickAt => throw _privateConstructorUsedError;

  /// Monotonic reading captured alongside [lastTickAt]. Lets [TrustedClock]
  /// detect a device clock moved forward — see lib/core/clock.dart.
  @DurationConverter()
  Duration get sessionElapsedAtTick => throw _privateConstructorUsedError;
  int get refillsToday => throw _privateConstructorUsedError;
  @NullableUtcDateTimeConverter()
  DateTime? get refillWindowStart => throw _privateConstructorUsedError;
  bool get freeAdRefillUsed => throw _privateConstructorUsedError;

  /// Serializes this VigorState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VigorState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VigorStateCopyWith<VigorState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VigorStateCopyWith<$Res> {
  factory $VigorStateCopyWith(
          VigorState value, $Res Function(VigorState) then) =
      _$VigorStateCopyWithImpl<$Res, VigorState>;
  @useResult
  $Res call(
      {int current,
      int max,
      @UtcDateTimeConverter() DateTime lastTickAt,
      @DurationConverter() Duration sessionElapsedAtTick,
      int refillsToday,
      @NullableUtcDateTimeConverter() DateTime? refillWindowStart,
      bool freeAdRefillUsed});
}

/// @nodoc
class _$VigorStateCopyWithImpl<$Res, $Val extends VigorState>
    implements $VigorStateCopyWith<$Res> {
  _$VigorStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VigorState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? current = null,
    Object? max = null,
    Object? lastTickAt = null,
    Object? sessionElapsedAtTick = null,
    Object? refillsToday = null,
    Object? refillWindowStart = freezed,
    Object? freeAdRefillUsed = null,
  }) {
    return _then(_value.copyWith(
      current: null == current
          ? _value.current
          : current // ignore: cast_nullable_to_non_nullable
              as int,
      max: null == max
          ? _value.max
          : max // ignore: cast_nullable_to_non_nullable
              as int,
      lastTickAt: null == lastTickAt
          ? _value.lastTickAt
          : lastTickAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sessionElapsedAtTick: null == sessionElapsedAtTick
          ? _value.sessionElapsedAtTick
          : sessionElapsedAtTick // ignore: cast_nullable_to_non_nullable
              as Duration,
      refillsToday: null == refillsToday
          ? _value.refillsToday
          : refillsToday // ignore: cast_nullable_to_non_nullable
              as int,
      refillWindowStart: freezed == refillWindowStart
          ? _value.refillWindowStart
          : refillWindowStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      freeAdRefillUsed: null == freeAdRefillUsed
          ? _value.freeAdRefillUsed
          : freeAdRefillUsed // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VigorStateImplCopyWith<$Res>
    implements $VigorStateCopyWith<$Res> {
  factory _$$VigorStateImplCopyWith(
          _$VigorStateImpl value, $Res Function(_$VigorStateImpl) then) =
      __$$VigorStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int current,
      int max,
      @UtcDateTimeConverter() DateTime lastTickAt,
      @DurationConverter() Duration sessionElapsedAtTick,
      int refillsToday,
      @NullableUtcDateTimeConverter() DateTime? refillWindowStart,
      bool freeAdRefillUsed});
}

/// @nodoc
class __$$VigorStateImplCopyWithImpl<$Res>
    extends _$VigorStateCopyWithImpl<$Res, _$VigorStateImpl>
    implements _$$VigorStateImplCopyWith<$Res> {
  __$$VigorStateImplCopyWithImpl(
      _$VigorStateImpl _value, $Res Function(_$VigorStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of VigorState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? current = null,
    Object? max = null,
    Object? lastTickAt = null,
    Object? sessionElapsedAtTick = null,
    Object? refillsToday = null,
    Object? refillWindowStart = freezed,
    Object? freeAdRefillUsed = null,
  }) {
    return _then(_$VigorStateImpl(
      current: null == current
          ? _value.current
          : current // ignore: cast_nullable_to_non_nullable
              as int,
      max: null == max
          ? _value.max
          : max // ignore: cast_nullable_to_non_nullable
              as int,
      lastTickAt: null == lastTickAt
          ? _value.lastTickAt
          : lastTickAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sessionElapsedAtTick: null == sessionElapsedAtTick
          ? _value.sessionElapsedAtTick
          : sessionElapsedAtTick // ignore: cast_nullable_to_non_nullable
              as Duration,
      refillsToday: null == refillsToday
          ? _value.refillsToday
          : refillsToday // ignore: cast_nullable_to_non_nullable
              as int,
      refillWindowStart: freezed == refillWindowStart
          ? _value.refillWindowStart
          : refillWindowStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      freeAdRefillUsed: null == freeAdRefillUsed
          ? _value.freeAdRefillUsed
          : freeAdRefillUsed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VigorStateImpl extends _VigorState {
  const _$VigorStateImpl(
      {this.current = 30,
      this.max = 30,
      @UtcDateTimeConverter() required this.lastTickAt,
      @DurationConverter() this.sessionElapsedAtTick = Duration.zero,
      this.refillsToday = 0,
      @NullableUtcDateTimeConverter() this.refillWindowStart,
      this.freeAdRefillUsed = false})
      : super._();

  factory _$VigorStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$VigorStateImplFromJson(json);

  @override
  @JsonKey()
  final int current;
  @override
  @JsonKey()
  final int max;

  /// Regen anchor. Vigor is *computed* from this on read, never stored as a
  /// ticking value, so background time is credited without a timer.
  @override
  @UtcDateTimeConverter()
  final DateTime lastTickAt;

  /// Monotonic reading captured alongside [lastTickAt]. Lets [TrustedClock]
  /// detect a device clock moved forward — see lib/core/clock.dart.
  @override
  @JsonKey()
  @DurationConverter()
  final Duration sessionElapsedAtTick;
  @override
  @JsonKey()
  final int refillsToday;
  @override
  @NullableUtcDateTimeConverter()
  final DateTime? refillWindowStart;
  @override
  @JsonKey()
  final bool freeAdRefillUsed;

  @override
  String toString() {
    return 'VigorState(current: $current, max: $max, lastTickAt: $lastTickAt, sessionElapsedAtTick: $sessionElapsedAtTick, refillsToday: $refillsToday, refillWindowStart: $refillWindowStart, freeAdRefillUsed: $freeAdRefillUsed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VigorStateImpl &&
            (identical(other.current, current) || other.current == current) &&
            (identical(other.max, max) || other.max == max) &&
            (identical(other.lastTickAt, lastTickAt) ||
                other.lastTickAt == lastTickAt) &&
            (identical(other.sessionElapsedAtTick, sessionElapsedAtTick) ||
                other.sessionElapsedAtTick == sessionElapsedAtTick) &&
            (identical(other.refillsToday, refillsToday) ||
                other.refillsToday == refillsToday) &&
            (identical(other.refillWindowStart, refillWindowStart) ||
                other.refillWindowStart == refillWindowStart) &&
            (identical(other.freeAdRefillUsed, freeAdRefillUsed) ||
                other.freeAdRefillUsed == freeAdRefillUsed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, current, max, lastTickAt,
      sessionElapsedAtTick, refillsToday, refillWindowStart, freeAdRefillUsed);

  /// Create a copy of VigorState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VigorStateImplCopyWith<_$VigorStateImpl> get copyWith =>
      __$$VigorStateImplCopyWithImpl<_$VigorStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VigorStateImplToJson(
      this,
    );
  }
}

abstract class _VigorState extends VigorState {
  const factory _VigorState(
      {final int current,
      final int max,
      @UtcDateTimeConverter() required final DateTime lastTickAt,
      @DurationConverter() final Duration sessionElapsedAtTick,
      final int refillsToday,
      @NullableUtcDateTimeConverter() final DateTime? refillWindowStart,
      final bool freeAdRefillUsed}) = _$VigorStateImpl;
  const _VigorState._() : super._();

  factory _VigorState.fromJson(Map<String, dynamic> json) =
      _$VigorStateImpl.fromJson;

  @override
  int get current;
  @override
  int get max;

  /// Regen anchor. Vigor is *computed* from this on read, never stored as a
  /// ticking value, so background time is credited without a timer.
  @override
  @UtcDateTimeConverter()
  DateTime get lastTickAt;

  /// Monotonic reading captured alongside [lastTickAt]. Lets [TrustedClock]
  /// detect a device clock moved forward — see lib/core/clock.dart.
  @override
  @DurationConverter()
  Duration get sessionElapsedAtTick;
  @override
  int get refillsToday;
  @override
  @NullableUtcDateTimeConverter()
  DateTime? get refillWindowStart;
  @override
  bool get freeAdRefillUsed;

  /// Create a copy of VigorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VigorStateImplCopyWith<_$VigorStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlayerSave _$PlayerSaveFromJson(Map<String, dynamic> json) {
  return _PlayerSave.fromJson(json);
}

/// @nodoc
mixin _$PlayerSave {
  int get schemaVersion => throw _privateConstructorUsedError;

  /// Stable local id. Survives sign-out, so a guest keeps their progress.
  String get playerId => throw _privateConstructorUsedError;

  /// Set on sign-in. Null for guests, who are fully-featured forever.
  String? get accountId => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  @UtcDateTimeConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @UtcDateTimeConverter()
  DateTime get lastSeenAt => throw _privateConstructorUsedError;
  PlayerProfile get profile => throw _privateConstructorUsedError;
  Wallet get wallet => throw _privateConstructorUsedError;
  VigorState get vigor => throw _privateConstructorUsedError;
  SpireState get spire => throw _privateConstructorUsedError;
  Map<String, HeroState> get heroes => throw _privateConstructorUsedError;
  InventoryState get inventory => throw _privateConstructorUsedError;
  CampaignState get campaign => throw _privateConstructorUsedError;
  AscensionState get ascension => throw _privateConstructorUsedError;
  ResearchState get research => throw _privateConstructorUsedError;
  MarkState get marks => throw _privateConstructorUsedError;
  QuestState get quests => throw _privateConstructorUsedError;
  RewardsState get rewards => throw _privateConstructorUsedError;
  AchievementState get achievements => throw _privateConstructorUsedError;
  PurchaseState get purchases => throw _privateConstructorUsedError;
  SettingsState get settings => throw _privateConstructorUsedError;
  StatsState get stats => throw _privateConstructorUsedError;

  /// Non-null only while a run is in progress. Powers crash recovery.
  RunSnapshot? get activeRun => throw _privateConstructorUsedError;

  /// Serializes this PlayerSave to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlayerSaveCopyWith<PlayerSave> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlayerSaveCopyWith<$Res> {
  factory $PlayerSaveCopyWith(
          PlayerSave value, $Res Function(PlayerSave) then) =
      _$PlayerSaveCopyWithImpl<$Res, PlayerSave>;
  @useResult
  $Res call(
      {int schemaVersion,
      String playerId,
      String? accountId,
      String displayName,
      @UtcDateTimeConverter() DateTime createdAt,
      @UtcDateTimeConverter() DateTime lastSeenAt,
      PlayerProfile profile,
      Wallet wallet,
      VigorState vigor,
      SpireState spire,
      Map<String, HeroState> heroes,
      InventoryState inventory,
      CampaignState campaign,
      AscensionState ascension,
      ResearchState research,
      MarkState marks,
      QuestState quests,
      RewardsState rewards,
      AchievementState achievements,
      PurchaseState purchases,
      SettingsState settings,
      StatsState stats,
      RunSnapshot? activeRun});

  $PlayerProfileCopyWith<$Res> get profile;
  $WalletCopyWith<$Res> get wallet;
  $VigorStateCopyWith<$Res> get vigor;
  $SpireStateCopyWith<$Res> get spire;
  $InventoryStateCopyWith<$Res> get inventory;
  $CampaignStateCopyWith<$Res> get campaign;
  $AscensionStateCopyWith<$Res> get ascension;
  $ResearchStateCopyWith<$Res> get research;
  $MarkStateCopyWith<$Res> get marks;
  $QuestStateCopyWith<$Res> get quests;
  $RewardsStateCopyWith<$Res> get rewards;
  $AchievementStateCopyWith<$Res> get achievements;
  $PurchaseStateCopyWith<$Res> get purchases;
  $SettingsStateCopyWith<$Res> get settings;
  $StatsStateCopyWith<$Res> get stats;
  $RunSnapshotCopyWith<$Res>? get activeRun;
}

/// @nodoc
class _$PlayerSaveCopyWithImpl<$Res, $Val extends PlayerSave>
    implements $PlayerSaveCopyWith<$Res> {
  _$PlayerSaveCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? schemaVersion = null,
    Object? playerId = null,
    Object? accountId = freezed,
    Object? displayName = null,
    Object? createdAt = null,
    Object? lastSeenAt = null,
    Object? profile = null,
    Object? wallet = null,
    Object? vigor = null,
    Object? spire = null,
    Object? heroes = null,
    Object? inventory = null,
    Object? campaign = null,
    Object? ascension = null,
    Object? research = null,
    Object? marks = null,
    Object? quests = null,
    Object? rewards = null,
    Object? achievements = null,
    Object? purchases = null,
    Object? settings = null,
    Object? stats = null,
    Object? activeRun = freezed,
  }) {
    return _then(_value.copyWith(
      schemaVersion: null == schemaVersion
          ? _value.schemaVersion
          : schemaVersion // ignore: cast_nullable_to_non_nullable
              as int,
      playerId: null == playerId
          ? _value.playerId
          : playerId // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: freezed == accountId
          ? _value.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastSeenAt: null == lastSeenAt
          ? _value.lastSeenAt
          : lastSeenAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      profile: null == profile
          ? _value.profile
          : profile // ignore: cast_nullable_to_non_nullable
              as PlayerProfile,
      wallet: null == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as Wallet,
      vigor: null == vigor
          ? _value.vigor
          : vigor // ignore: cast_nullable_to_non_nullable
              as VigorState,
      spire: null == spire
          ? _value.spire
          : spire // ignore: cast_nullable_to_non_nullable
              as SpireState,
      heroes: null == heroes
          ? _value.heroes
          : heroes // ignore: cast_nullable_to_non_nullable
              as Map<String, HeroState>,
      inventory: null == inventory
          ? _value.inventory
          : inventory // ignore: cast_nullable_to_non_nullable
              as InventoryState,
      campaign: null == campaign
          ? _value.campaign
          : campaign // ignore: cast_nullable_to_non_nullable
              as CampaignState,
      ascension: null == ascension
          ? _value.ascension
          : ascension // ignore: cast_nullable_to_non_nullable
              as AscensionState,
      research: null == research
          ? _value.research
          : research // ignore: cast_nullable_to_non_nullable
              as ResearchState,
      marks: null == marks
          ? _value.marks
          : marks // ignore: cast_nullable_to_non_nullable
              as MarkState,
      quests: null == quests
          ? _value.quests
          : quests // ignore: cast_nullable_to_non_nullable
              as QuestState,
      rewards: null == rewards
          ? _value.rewards
          : rewards // ignore: cast_nullable_to_non_nullable
              as RewardsState,
      achievements: null == achievements
          ? _value.achievements
          : achievements // ignore: cast_nullable_to_non_nullable
              as AchievementState,
      purchases: null == purchases
          ? _value.purchases
          : purchases // ignore: cast_nullable_to_non_nullable
              as PurchaseState,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as SettingsState,
      stats: null == stats
          ? _value.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as StatsState,
      activeRun: freezed == activeRun
          ? _value.activeRun
          : activeRun // ignore: cast_nullable_to_non_nullable
              as RunSnapshot?,
    ) as $Val);
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PlayerProfileCopyWith<$Res> get profile {
    return $PlayerProfileCopyWith<$Res>(_value.profile, (value) {
      return _then(_value.copyWith(profile: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WalletCopyWith<$Res> get wallet {
    return $WalletCopyWith<$Res>(_value.wallet, (value) {
      return _then(_value.copyWith(wallet: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VigorStateCopyWith<$Res> get vigor {
    return $VigorStateCopyWith<$Res>(_value.vigor, (value) {
      return _then(_value.copyWith(vigor: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SpireStateCopyWith<$Res> get spire {
    return $SpireStateCopyWith<$Res>(_value.spire, (value) {
      return _then(_value.copyWith(spire: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $InventoryStateCopyWith<$Res> get inventory {
    return $InventoryStateCopyWith<$Res>(_value.inventory, (value) {
      return _then(_value.copyWith(inventory: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CampaignStateCopyWith<$Res> get campaign {
    return $CampaignStateCopyWith<$Res>(_value.campaign, (value) {
      return _then(_value.copyWith(campaign: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AscensionStateCopyWith<$Res> get ascension {
    return $AscensionStateCopyWith<$Res>(_value.ascension, (value) {
      return _then(_value.copyWith(ascension: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ResearchStateCopyWith<$Res> get research {
    return $ResearchStateCopyWith<$Res>(_value.research, (value) {
      return _then(_value.copyWith(research: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MarkStateCopyWith<$Res> get marks {
    return $MarkStateCopyWith<$Res>(_value.marks, (value) {
      return _then(_value.copyWith(marks: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuestStateCopyWith<$Res> get quests {
    return $QuestStateCopyWith<$Res>(_value.quests, (value) {
      return _then(_value.copyWith(quests: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RewardsStateCopyWith<$Res> get rewards {
    return $RewardsStateCopyWith<$Res>(_value.rewards, (value) {
      return _then(_value.copyWith(rewards: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AchievementStateCopyWith<$Res> get achievements {
    return $AchievementStateCopyWith<$Res>(_value.achievements, (value) {
      return _then(_value.copyWith(achievements: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PurchaseStateCopyWith<$Res> get purchases {
    return $PurchaseStateCopyWith<$Res>(_value.purchases, (value) {
      return _then(_value.copyWith(purchases: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SettingsStateCopyWith<$Res> get settings {
    return $SettingsStateCopyWith<$Res>(_value.settings, (value) {
      return _then(_value.copyWith(settings: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StatsStateCopyWith<$Res> get stats {
    return $StatsStateCopyWith<$Res>(_value.stats, (value) {
      return _then(_value.copyWith(stats: value) as $Val);
    });
  }

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RunSnapshotCopyWith<$Res>? get activeRun {
    if (_value.activeRun == null) {
      return null;
    }

    return $RunSnapshotCopyWith<$Res>(_value.activeRun!, (value) {
      return _then(_value.copyWith(activeRun: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlayerSaveImplCopyWith<$Res>
    implements $PlayerSaveCopyWith<$Res> {
  factory _$$PlayerSaveImplCopyWith(
          _$PlayerSaveImpl value, $Res Function(_$PlayerSaveImpl) then) =
      __$$PlayerSaveImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int schemaVersion,
      String playerId,
      String? accountId,
      String displayName,
      @UtcDateTimeConverter() DateTime createdAt,
      @UtcDateTimeConverter() DateTime lastSeenAt,
      PlayerProfile profile,
      Wallet wallet,
      VigorState vigor,
      SpireState spire,
      Map<String, HeroState> heroes,
      InventoryState inventory,
      CampaignState campaign,
      AscensionState ascension,
      ResearchState research,
      MarkState marks,
      QuestState quests,
      RewardsState rewards,
      AchievementState achievements,
      PurchaseState purchases,
      SettingsState settings,
      StatsState stats,
      RunSnapshot? activeRun});

  @override
  $PlayerProfileCopyWith<$Res> get profile;
  @override
  $WalletCopyWith<$Res> get wallet;
  @override
  $VigorStateCopyWith<$Res> get vigor;
  @override
  $SpireStateCopyWith<$Res> get spire;
  @override
  $InventoryStateCopyWith<$Res> get inventory;
  @override
  $CampaignStateCopyWith<$Res> get campaign;
  @override
  $AscensionStateCopyWith<$Res> get ascension;
  @override
  $ResearchStateCopyWith<$Res> get research;
  @override
  $MarkStateCopyWith<$Res> get marks;
  @override
  $QuestStateCopyWith<$Res> get quests;
  @override
  $RewardsStateCopyWith<$Res> get rewards;
  @override
  $AchievementStateCopyWith<$Res> get achievements;
  @override
  $PurchaseStateCopyWith<$Res> get purchases;
  @override
  $SettingsStateCopyWith<$Res> get settings;
  @override
  $StatsStateCopyWith<$Res> get stats;
  @override
  $RunSnapshotCopyWith<$Res>? get activeRun;
}

/// @nodoc
class __$$PlayerSaveImplCopyWithImpl<$Res>
    extends _$PlayerSaveCopyWithImpl<$Res, _$PlayerSaveImpl>
    implements _$$PlayerSaveImplCopyWith<$Res> {
  __$$PlayerSaveImplCopyWithImpl(
      _$PlayerSaveImpl _value, $Res Function(_$PlayerSaveImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? schemaVersion = null,
    Object? playerId = null,
    Object? accountId = freezed,
    Object? displayName = null,
    Object? createdAt = null,
    Object? lastSeenAt = null,
    Object? profile = null,
    Object? wallet = null,
    Object? vigor = null,
    Object? spire = null,
    Object? heroes = null,
    Object? inventory = null,
    Object? campaign = null,
    Object? ascension = null,
    Object? research = null,
    Object? marks = null,
    Object? quests = null,
    Object? rewards = null,
    Object? achievements = null,
    Object? purchases = null,
    Object? settings = null,
    Object? stats = null,
    Object? activeRun = freezed,
  }) {
    return _then(_$PlayerSaveImpl(
      schemaVersion: null == schemaVersion
          ? _value.schemaVersion
          : schemaVersion // ignore: cast_nullable_to_non_nullable
              as int,
      playerId: null == playerId
          ? _value.playerId
          : playerId // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: freezed == accountId
          ? _value.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String?,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastSeenAt: null == lastSeenAt
          ? _value.lastSeenAt
          : lastSeenAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      profile: null == profile
          ? _value.profile
          : profile // ignore: cast_nullable_to_non_nullable
              as PlayerProfile,
      wallet: null == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as Wallet,
      vigor: null == vigor
          ? _value.vigor
          : vigor // ignore: cast_nullable_to_non_nullable
              as VigorState,
      spire: null == spire
          ? _value.spire
          : spire // ignore: cast_nullable_to_non_nullable
              as SpireState,
      heroes: null == heroes
          ? _value._heroes
          : heroes // ignore: cast_nullable_to_non_nullable
              as Map<String, HeroState>,
      inventory: null == inventory
          ? _value.inventory
          : inventory // ignore: cast_nullable_to_non_nullable
              as InventoryState,
      campaign: null == campaign
          ? _value.campaign
          : campaign // ignore: cast_nullable_to_non_nullable
              as CampaignState,
      ascension: null == ascension
          ? _value.ascension
          : ascension // ignore: cast_nullable_to_non_nullable
              as AscensionState,
      research: null == research
          ? _value.research
          : research // ignore: cast_nullable_to_non_nullable
              as ResearchState,
      marks: null == marks
          ? _value.marks
          : marks // ignore: cast_nullable_to_non_nullable
              as MarkState,
      quests: null == quests
          ? _value.quests
          : quests // ignore: cast_nullable_to_non_nullable
              as QuestState,
      rewards: null == rewards
          ? _value.rewards
          : rewards // ignore: cast_nullable_to_non_nullable
              as RewardsState,
      achievements: null == achievements
          ? _value.achievements
          : achievements // ignore: cast_nullable_to_non_nullable
              as AchievementState,
      purchases: null == purchases
          ? _value.purchases
          : purchases // ignore: cast_nullable_to_non_nullable
              as PurchaseState,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as SettingsState,
      stats: null == stats
          ? _value.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as StatsState,
      activeRun: freezed == activeRun
          ? _value.activeRun
          : activeRun // ignore: cast_nullable_to_non_nullable
              as RunSnapshot?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlayerSaveImpl extends _PlayerSave {
  const _$PlayerSaveImpl(
      {required this.schemaVersion,
      required this.playerId,
      this.accountId,
      this.displayName = 'Warden',
      @UtcDateTimeConverter() required this.createdAt,
      @UtcDateTimeConverter() required this.lastSeenAt,
      this.profile = const PlayerProfile(),
      this.wallet = const Wallet(),
      required this.vigor,
      this.spire = const SpireState(),
      final Map<String, HeroState> heroes = const <String, HeroState>{},
      this.inventory = const InventoryState(),
      this.campaign = const CampaignState(),
      this.ascension = const AscensionState(),
      this.research = const ResearchState(),
      this.marks = const MarkState(),
      this.quests = const QuestState(),
      this.rewards = const RewardsState(),
      this.achievements = const AchievementState(),
      this.purchases = const PurchaseState(),
      this.settings = const SettingsState(),
      this.stats = const StatsState(),
      this.activeRun})
      : _heroes = heroes,
        super._();

  factory _$PlayerSaveImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlayerSaveImplFromJson(json);

  @override
  final int schemaVersion;

  /// Stable local id. Survives sign-out, so a guest keeps their progress.
  @override
  final String playerId;

  /// Set on sign-in. Null for guests, who are fully-featured forever.
  @override
  final String? accountId;
  @override
  @JsonKey()
  final String displayName;
  @override
  @UtcDateTimeConverter()
  final DateTime createdAt;
  @override
  @UtcDateTimeConverter()
  final DateTime lastSeenAt;
  @override
  @JsonKey()
  final PlayerProfile profile;
  @override
  @JsonKey()
  final Wallet wallet;
  @override
  final VigorState vigor;
  @override
  @JsonKey()
  final SpireState spire;
  final Map<String, HeroState> _heroes;
  @override
  @JsonKey()
  Map<String, HeroState> get heroes {
    if (_heroes is EqualUnmodifiableMapView) return _heroes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_heroes);
  }

  @override
  @JsonKey()
  final InventoryState inventory;
  @override
  @JsonKey()
  final CampaignState campaign;
  @override
  @JsonKey()
  final AscensionState ascension;
  @override
  @JsonKey()
  final ResearchState research;
  @override
  @JsonKey()
  final MarkState marks;
  @override
  @JsonKey()
  final QuestState quests;
  @override
  @JsonKey()
  final RewardsState rewards;
  @override
  @JsonKey()
  final AchievementState achievements;
  @override
  @JsonKey()
  final PurchaseState purchases;
  @override
  @JsonKey()
  final SettingsState settings;
  @override
  @JsonKey()
  final StatsState stats;

  /// Non-null only while a run is in progress. Powers crash recovery.
  @override
  final RunSnapshot? activeRun;

  @override
  String toString() {
    return 'PlayerSave(schemaVersion: $schemaVersion, playerId: $playerId, accountId: $accountId, displayName: $displayName, createdAt: $createdAt, lastSeenAt: $lastSeenAt, profile: $profile, wallet: $wallet, vigor: $vigor, spire: $spire, heroes: $heroes, inventory: $inventory, campaign: $campaign, ascension: $ascension, research: $research, marks: $marks, quests: $quests, rewards: $rewards, achievements: $achievements, purchases: $purchases, settings: $settings, stats: $stats, activeRun: $activeRun)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayerSaveImpl &&
            (identical(other.schemaVersion, schemaVersion) ||
                other.schemaVersion == schemaVersion) &&
            (identical(other.playerId, playerId) ||
                other.playerId == playerId) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastSeenAt, lastSeenAt) ||
                other.lastSeenAt == lastSeenAt) &&
            (identical(other.profile, profile) || other.profile == profile) &&
            (identical(other.wallet, wallet) || other.wallet == wallet) &&
            (identical(other.vigor, vigor) || other.vigor == vigor) &&
            (identical(other.spire, spire) || other.spire == spire) &&
            const DeepCollectionEquality().equals(other._heroes, _heroes) &&
            (identical(other.inventory, inventory) ||
                other.inventory == inventory) &&
            (identical(other.campaign, campaign) ||
                other.campaign == campaign) &&
            (identical(other.ascension, ascension) ||
                other.ascension == ascension) &&
            (identical(other.research, research) ||
                other.research == research) &&
            (identical(other.marks, marks) || other.marks == marks) &&
            (identical(other.quests, quests) || other.quests == quests) &&
            (identical(other.rewards, rewards) || other.rewards == rewards) &&
            (identical(other.achievements, achievements) ||
                other.achievements == achievements) &&
            (identical(other.purchases, purchases) ||
                other.purchases == purchases) &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            (identical(other.stats, stats) || other.stats == stats) &&
            (identical(other.activeRun, activeRun) ||
                other.activeRun == activeRun));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        schemaVersion,
        playerId,
        accountId,
        displayName,
        createdAt,
        lastSeenAt,
        profile,
        wallet,
        vigor,
        spire,
        const DeepCollectionEquality().hash(_heroes),
        inventory,
        campaign,
        ascension,
        research,
        marks,
        quests,
        rewards,
        achievements,
        purchases,
        settings,
        stats,
        activeRun
      ]);

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayerSaveImplCopyWith<_$PlayerSaveImpl> get copyWith =>
      __$$PlayerSaveImplCopyWithImpl<_$PlayerSaveImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlayerSaveImplToJson(
      this,
    );
  }
}

abstract class _PlayerSave extends PlayerSave {
  const factory _PlayerSave(
      {required final int schemaVersion,
      required final String playerId,
      final String? accountId,
      final String displayName,
      @UtcDateTimeConverter() required final DateTime createdAt,
      @UtcDateTimeConverter() required final DateTime lastSeenAt,
      final PlayerProfile profile,
      final Wallet wallet,
      required final VigorState vigor,
      final SpireState spire,
      final Map<String, HeroState> heroes,
      final InventoryState inventory,
      final CampaignState campaign,
      final AscensionState ascension,
      final ResearchState research,
      final MarkState marks,
      final QuestState quests,
      final RewardsState rewards,
      final AchievementState achievements,
      final PurchaseState purchases,
      final SettingsState settings,
      final StatsState stats,
      final RunSnapshot? activeRun}) = _$PlayerSaveImpl;
  const _PlayerSave._() : super._();

  factory _PlayerSave.fromJson(Map<String, dynamic> json) =
      _$PlayerSaveImpl.fromJson;

  @override
  int get schemaVersion;

  /// Stable local id. Survives sign-out, so a guest keeps their progress.
  @override
  String get playerId;

  /// Set on sign-in. Null for guests, who are fully-featured forever.
  @override
  String? get accountId;
  @override
  String get displayName;
  @override
  @UtcDateTimeConverter()
  DateTime get createdAt;
  @override
  @UtcDateTimeConverter()
  DateTime get lastSeenAt;
  @override
  PlayerProfile get profile;
  @override
  Wallet get wallet;
  @override
  VigorState get vigor;
  @override
  SpireState get spire;
  @override
  Map<String, HeroState> get heroes;
  @override
  InventoryState get inventory;
  @override
  CampaignState get campaign;
  @override
  AscensionState get ascension;
  @override
  ResearchState get research;
  @override
  MarkState get marks;
  @override
  QuestState get quests;
  @override
  RewardsState get rewards;
  @override
  AchievementState get achievements;
  @override
  PurchaseState get purchases;
  @override
  SettingsState get settings;
  @override
  StatsState get stats;

  /// Non-null only while a run is in progress. Powers crash recovery.
  @override
  RunSnapshot? get activeRun;

  /// Create a copy of PlayerSave
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayerSaveImplCopyWith<_$PlayerSaveImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
