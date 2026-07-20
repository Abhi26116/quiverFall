import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:quiverfall/data/models/converters.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/live_ops.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/data/models/settings_stats.dart';

part 'player_save.freezed.dart';
part 'player_save.g.dart';

/// A saved hero + arrow + Marks combination.
@freezed
class Loadout with _$Loadout {
  const factory Loadout({
    required String name,
    required String heroId,
    required String arrowId,
    @Default(<String>[]) List<String> markIds,
  }) = _Loadout;

  factory Loadout.fromJson(Map<String, dynamic> json) =>
      _$LoadoutFromJson(json);
}

@freezed
class PlayerProfile with _$PlayerProfile {
  const factory PlayerProfile({
    @Default(1) int accountLevel,
    @Default(0) int accountXp,
    @Default('wren') String equippedHeroId,
    @Default('ash_shaft') String equippedArrowId,

    /// Max 6, unlocked at account levels 12/20/30/45/65/90.
    @Default(<String>[]) List<String> equippedMarkIds,
    @Default(<Loadout>[]) List<Loadout> loadouts,
    String? avatarId,
    String? titleId,

    /// 'low' | 'mid' | 'high', assigned by the boot benchmark.
    @Default('mid') String deviceTier,
  }) = _PlayerProfile;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) =>
      _$PlayerProfileFromJson(json);

  const PlayerProfile._();

  static const int maxMarkSlots = 6;
}

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    @Default(0) int gold,
    @Default(0) int gems,

    /// Unpurchasable at any price. Gates Spire tier bands.
    @Default(0) int insight,

    /// Unpurchasable at any price. Prestige currency.
    @Default(0) int emberdust,
    @Default(<String, int>{}) Map<String, int> materials,
    @Default(<String, int>{}) Map<String, int> heroShards,
    @Default(<String, int>{}) Map<String, int> eventTokens,
  }) = _Wallet;

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);

  const Wallet._();

  int materialCount(String id) => materials[id] ?? 0;

  int shardCount(String heroId) => heroShards[heroId] ?? 0;
}

/// Energy. Throttles farming velocity, never campaign progression — an
/// uncleared stage always costs 0. See docs/02-economy.md §2.2.
@freezed
class VigorState with _$VigorState {
  const factory VigorState({
    @Default(30) int current,
    @Default(30) int max,

    /// Regen anchor. Vigor is *computed* from this on read, never stored as a
    /// ticking value, so background time is credited without a timer.
    @UtcDateTimeConverter() required DateTime lastTickAt,

    /// Monotonic reading captured alongside [lastTickAt]. Lets [TrustedClock]
    /// detect a device clock moved forward — see lib/core/clock.dart.
    @DurationConverter() @Default(Duration.zero) Duration sessionElapsedAtTick,
    @Default(0) int refillsToday,
    @NullableUtcDateTimeConverter() DateTime? refillWindowStart,
    @Default(false) bool freeAdRefillUsed,
  }) = _VigorState;

  factory VigorState.fromJson(Map<String, dynamic> json) =>
      _$VigorStateFromJson(json);

  const VigorState._();

  static const Duration regenInterval = Duration(minutes: 6);
  static const int runCost = 6;
  static const int bossRerunCost = 10;
  static const int hardMax = 50;

  bool get isFull => current >= max;
}

/// The root save document.
///
/// Local is the source of truth; the cloud is a backup. Never the reverse — a
/// network hiccup must never cost progress. See docs/13-database.md §13.0.
@freezed
class PlayerSave with _$PlayerSave {
  const factory PlayerSave({
    required int schemaVersion,

    /// Stable local id. Survives sign-out, so a guest keeps their progress.
    required String playerId,

    /// Set on sign-in. Null for guests, who are fully-featured forever.
    String? accountId,
    @Default('Warden') String displayName,
    @UtcDateTimeConverter() required DateTime createdAt,
    @UtcDateTimeConverter() required DateTime lastSeenAt,
    @Default(PlayerProfile()) PlayerProfile profile,
    @Default(Wallet()) Wallet wallet,
    required VigorState vigor,
    @Default(SpireState()) SpireState spire,
    @Default(<String, HeroState>{}) Map<String, HeroState> heroes,
    @Default(InventoryState()) InventoryState inventory,
    @Default(CampaignState()) CampaignState campaign,
    @Default(AscensionState()) AscensionState ascension,
    @Default(ResearchState()) ResearchState research,
    @Default(MarkState()) MarkState marks,
    @Default(QuestState()) QuestState quests,
    @Default(RewardsState()) RewardsState rewards,
    @Default(AchievementState()) AchievementState achievements,
    @Default(PurchaseState()) PurchaseState purchases,
    @Default(SettingsState()) SettingsState settings,
    @Default(StatsState()) StatsState stats,

    /// Non-null only while a run is in progress. Powers crash recovery.
    RunSnapshot? activeRun,
  }) = _PlayerSave;

  factory PlayerSave.fromJson(Map<String, dynamic> json) =>
      _$PlayerSaveFromJson(json);

  const PlayerSave._();

  /// The schema version this build writes and can read up to.
  ///
  /// A save carrying a *higher* version than this is refused outright rather
  /// than "fixed" — see [MigrationError.futureVersion].
  static const int currentSchemaVersion = 1;

  /// A brand-new player.
  factory PlayerSave.initial({
    required String playerId,
    required DateTime now,
  }) {
    return PlayerSave(
      schemaVersion: currentSchemaVersion,
      playerId: playerId,
      createdAt: now,
      lastSeenAt: now,
      vigor: VigorState(lastTickAt: now),
      heroes: const <String, HeroState>{
        // Wren is granted free as the starting hero.
        'wren': HeroState(heroId: 'wren', unlocked: true, stars: 1),
      },
      inventory: const InventoryState(
        arrows: <String, ArrowInstance>{
          'ash_shaft': ArrowInstance(arrowId: 'ash_shaft', crafted: true),
        },
      ),
    );
  }

  bool get isGuest => accountId == null;

  bool get hasActiveRun => activeRun != null;
}
