// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_save.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LoadoutImpl _$$LoadoutImplFromJson(Map<String, dynamic> json) =>
    _$LoadoutImpl(
      name: json['name'] as String,
      heroId: json['heroId'] as String,
      arrowId: json['arrowId'] as String,
      markIds: (json['markIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$$LoadoutImplToJson(_$LoadoutImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'heroId': instance.heroId,
      'arrowId': instance.arrowId,
      'markIds': instance.markIds,
    };

_$PlayerProfileImpl _$$PlayerProfileImplFromJson(Map<String, dynamic> json) =>
    _$PlayerProfileImpl(
      accountLevel: (json['accountLevel'] as num?)?.toInt() ?? 1,
      accountXp: (json['accountXp'] as num?)?.toInt() ?? 0,
      equippedHeroId: json['equippedHeroId'] as String? ?? 'wren',
      equippedArrowId: json['equippedArrowId'] as String? ?? 'ash_shaft',
      equippedMarkIds: (json['equippedMarkIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      loadouts: (json['loadouts'] as List<dynamic>?)
              ?.map((e) => Loadout.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Loadout>[],
      avatarId: json['avatarId'] as String?,
      titleId: json['titleId'] as String?,
      deviceTier: json['deviceTier'] as String? ?? 'mid',
    );

Map<String, dynamic> _$$PlayerProfileImplToJson(_$PlayerProfileImpl instance) =>
    <String, dynamic>{
      'accountLevel': instance.accountLevel,
      'accountXp': instance.accountXp,
      'equippedHeroId': instance.equippedHeroId,
      'equippedArrowId': instance.equippedArrowId,
      'equippedMarkIds': instance.equippedMarkIds,
      'loadouts': instance.loadouts,
      'avatarId': instance.avatarId,
      'titleId': instance.titleId,
      'deviceTier': instance.deviceTier,
    };

_$WalletImpl _$$WalletImplFromJson(Map<String, dynamic> json) => _$WalletImpl(
      gold: (json['gold'] as num?)?.toInt() ?? 0,
      gems: (json['gems'] as num?)?.toInt() ?? 0,
      insight: (json['insight'] as num?)?.toInt() ?? 0,
      emberdust: (json['emberdust'] as num?)?.toInt() ?? 0,
      materials: (json['materials'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      heroShards: (json['heroShards'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      eventTokens: (json['eventTokens'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
    );

Map<String, dynamic> _$$WalletImplToJson(_$WalletImpl instance) =>
    <String, dynamic>{
      'gold': instance.gold,
      'gems': instance.gems,
      'insight': instance.insight,
      'emberdust': instance.emberdust,
      'materials': instance.materials,
      'heroShards': instance.heroShards,
      'eventTokens': instance.eventTokens,
    };

_$VigorStateImpl _$$VigorStateImplFromJson(Map<String, dynamic> json) =>
    _$VigorStateImpl(
      current: (json['current'] as num?)?.toInt() ?? 30,
      max: (json['max'] as num?)?.toInt() ?? 30,
      lastTickAt:
          const UtcDateTimeConverter().fromJson(json['lastTickAt'] as String),
      sessionElapsedAtTick: json['sessionElapsedAtTick'] == null
          ? Duration.zero
          : const DurationConverter()
              .fromJson((json['sessionElapsedAtTick'] as num).toInt()),
      refillsToday: (json['refillsToday'] as num?)?.toInt() ?? 0,
      refillWindowStart: const NullableUtcDateTimeConverter()
          .fromJson(json['refillWindowStart'] as String?),
      freeAdRefillUsed: json['freeAdRefillUsed'] as bool? ?? false,
    );

Map<String, dynamic> _$$VigorStateImplToJson(_$VigorStateImpl instance) =>
    <String, dynamic>{
      'current': instance.current,
      'max': instance.max,
      'lastTickAt': const UtcDateTimeConverter().toJson(instance.lastTickAt),
      'sessionElapsedAtTick':
          const DurationConverter().toJson(instance.sessionElapsedAtTick),
      'refillsToday': instance.refillsToday,
      'refillWindowStart': const NullableUtcDateTimeConverter()
          .toJson(instance.refillWindowStart),
      'freeAdRefillUsed': instance.freeAdRefillUsed,
    };

_$PlayerSaveImpl _$$PlayerSaveImplFromJson(Map<String, dynamic> json) =>
    _$PlayerSaveImpl(
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      playerId: json['playerId'] as String,
      accountId: json['accountId'] as String?,
      displayName: json['displayName'] as String? ?? 'Warden',
      createdAt:
          const UtcDateTimeConverter().fromJson(json['createdAt'] as String),
      lastSeenAt:
          const UtcDateTimeConverter().fromJson(json['lastSeenAt'] as String),
      profile: json['profile'] == null
          ? const PlayerProfile()
          : PlayerProfile.fromJson(json['profile'] as Map<String, dynamic>),
      wallet: json['wallet'] == null
          ? const Wallet()
          : Wallet.fromJson(json['wallet'] as Map<String, dynamic>),
      vigor: VigorState.fromJson(json['vigor'] as Map<String, dynamic>),
      spire: json['spire'] == null
          ? const SpireState()
          : SpireState.fromJson(json['spire'] as Map<String, dynamic>),
      heroes: (json['heroes'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, HeroState.fromJson(e as Map<String, dynamic>)),
          ) ??
          const <String, HeroState>{},
      inventory: json['inventory'] == null
          ? const InventoryState()
          : InventoryState.fromJson(json['inventory'] as Map<String, dynamic>),
      campaign: json['campaign'] == null
          ? const CampaignState()
          : CampaignState.fromJson(json['campaign'] as Map<String, dynamic>),
      ascension: json['ascension'] == null
          ? const AscensionState()
          : AscensionState.fromJson(json['ascension'] as Map<String, dynamic>),
      research: json['research'] == null
          ? const ResearchState()
          : ResearchState.fromJson(json['research'] as Map<String, dynamic>),
      marks: json['marks'] == null
          ? const MarkState()
          : MarkState.fromJson(json['marks'] as Map<String, dynamic>),
      quests: json['quests'] == null
          ? const QuestState()
          : QuestState.fromJson(json['quests'] as Map<String, dynamic>),
      rewards: json['rewards'] == null
          ? const RewardsState()
          : RewardsState.fromJson(json['rewards'] as Map<String, dynamic>),
      achievements: json['achievements'] == null
          ? const AchievementState()
          : AchievementState.fromJson(
              json['achievements'] as Map<String, dynamic>),
      purchases: json['purchases'] == null
          ? const PurchaseState()
          : PurchaseState.fromJson(json['purchases'] as Map<String, dynamic>),
      settings: json['settings'] == null
          ? const SettingsState()
          : SettingsState.fromJson(json['settings'] as Map<String, dynamic>),
      stats: json['stats'] == null
          ? const StatsState()
          : StatsState.fromJson(json['stats'] as Map<String, dynamic>),
      activeRun: json['activeRun'] == null
          ? null
          : RunSnapshot.fromJson(json['activeRun'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$PlayerSaveImplToJson(_$PlayerSaveImpl instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'playerId': instance.playerId,
      'accountId': instance.accountId,
      'displayName': instance.displayName,
      'createdAt': const UtcDateTimeConverter().toJson(instance.createdAt),
      'lastSeenAt': const UtcDateTimeConverter().toJson(instance.lastSeenAt),
      'profile': instance.profile,
      'wallet': instance.wallet,
      'vigor': instance.vigor,
      'spire': instance.spire,
      'heroes': instance.heroes,
      'inventory': instance.inventory,
      'campaign': instance.campaign,
      'ascension': instance.ascension,
      'research': instance.research,
      'marks': instance.marks,
      'quests': instance.quests,
      'rewards': instance.rewards,
      'achievements': instance.achievements,
      'purchases': instance.purchases,
      'settings': instance.settings,
      'stats': instance.stats,
      'activeRun': instance.activeRun,
    };
