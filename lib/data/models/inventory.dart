import 'package:freezed_annotation/freezed_annotation.dart';

part 'inventory.freezed.dart';
part 'inventory.g.dart';

/// A rolled modifier on an arrow. See docs/08-arrows.md §8.4.
@freezed
class Affix with _$Affix {
  const factory Affix({
    required String affixId,

    /// Rolled within the affix's defined range at refine time.
    required double value,
    @Default(1) int tier,
  }) = _Affix;

  factory Affix.fromJson(Map<String, dynamic> json) => _$AffixFromJson(json);
}

/// One owned arrow.
///
/// Only one arrow is equipped at a time, so arrows are a build decision rather
/// than a stat stack.
@freezed
class ArrowInstance with _$ArrowInstance {
  const factory ArrowInstance({
    required String arrowId,
    @Default(false) bool crafted,
    @Default(0) int refineLevel,
    @Default(<Affix>[]) List<Affix> affixes,

    /// Up to 2 slots may be locked against a reroll. This is the honest version
    /// of the reroll sink: a player is never forced to gamble away a good roll
    /// in order to fix a bad one.
    @Default(<int>{}) Set<int> lockedAffixSlots,
  }) = _ArrowInstance;

  factory ArrowInstance.fromJson(Map<String, dynamic> json) =>
      _$ArrowInstanceFromJson(json);

  const ArrowInstance._();

  static const int maxLockedSlots = 2;

  bool get canLockMore => lockedAffixSlots.length < maxLockedSlots;
}

@freezed
class InventoryState with _$InventoryState {
  const factory InventoryState({
    /// arrowId -> instance.
    @Default(<String, ArrowInstance>{}) Map<String, ArrowInstance> arrows,
    @Default(<String>{}) Set<String> cosmeticIds,
    @Default(<String>{}) Set<String> windlineSkinIds,

    /// Reroll cost escalates +15% per use within a session, then resets daily.
    /// This is the uncapped drain that scales with how rich the player is —
    /// see docs/02-economy.md §2.11.
    @Default(0) int rerollCountThisSession,
  }) = _InventoryState;

  factory InventoryState.fromJson(Map<String, dynamic> json) =>
      _$InventoryStateFromJson(json);
}
