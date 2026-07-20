# 13 — Database Structure

## 13.0 Two stores, one direction

| Store | Tech | Role |
|---|---|---|
| **Local** | Embedded key-document store (Hive CE or Isar — benchmarked in Phase 0) | **Source of truth.** Full game state. Works offline forever. |
| **Cloud** | Firestore (pending the iOS check in [12 §12.1](12-architecture.md)) | Backup, cross-device restore, leaderboards, remote config. |

**Data flows local → cloud.** The cloud never silently overwrites local state; conflicts go to
the player ([11 §11.4](11-screen-flow.md)).

**Static content** (enemies, bosses, heroes, boons, arrows, chapters) is **not** in either store.
It ships as versioned JSON in `assets/data/` and is overlaid by remote config. Content is
read-only; player state is read-write. Keeping them in separate systems is what makes live
balance tuning safe.

All models are `freezed` + `json_serializable` immutable classes with `schemaVersion`.

---

## 13.1 PlayerSave (root document)

```dart
@freezed
class PlayerSave {
  const factory PlayerSave({
    required int schemaVersion,          // migration key
    required String playerId,            // uuid v4, local, survives sign-out
    String? accountId,                   // set on sign-in
    required String displayName,
    required DateTime createdAt,
    required DateTime lastSeenAt,

    required PlayerProfile profile,
    required Wallet wallet,
    required VigorState vigor,
    required SpireState spire,
    required Map<String, HeroState> heroes,      // heroId -> state
    required InventoryState inventory,
    required CampaignState campaign,
    required AscensionState ascension,
    required ResearchState research,
    required MarkState marks,
    required QuestState quests,
    required RewardsState rewards,
    required AchievementState achievements,
    required PurchaseState purchases,
    required SettingsState settings,
    required StatsState stats,
    RunSnapshot? activeRun,              // crash recovery, null when idle
    required String integrityHmac,
  }) = _PlayerSave;
}
```

## 13.2 Profile, Wallet, Vigor

```dart
class PlayerProfile {
  int accountLevel;          // 1..120
  int accountXp;
  String equippedHeroId;
  String equippedArrowId;
  List<String> equippedMarkIds;   // max 6
  List<Loadout> loadouts;         // saved sets, 1 free + research/gem unlocks
  String? avatarId;
  String? titleId;
  String deviceTier;              // 'low'|'mid'|'high', from the boot benchmark
}

class Wallet {
  int gold;
  int gems;
  int insight;
  int emberdust;
  Map<String,int> materials;      // 'ashwood','ironhead','skyfeather','prismcore'
  Map<String,int> heroShards;     // heroId -> count
  Map<String,int> eventTokens;    // eventId -> count, expires with the event
}

class VigorState {
  int current;
  int max;                        // 30..50
  DateTime lastTickAt;            // regen anchor; server time when available
  int refillsToday;               // drives the escalating gem price
  DateTime refillWindowStart;
  bool freeAdRefillUsed;
}
```

**Vigor regen is computed, never stored as a ticking value.** On read:
`current = min(max, stored + floor((now − lastTickAt) / 6min))`. `now` prefers a trusted server
timestamp and falls back to device time with a monotonic guard, so setting the clock forward does
not mint Vigor.

## 13.3 Spire, Research, Ascension, Marks

```dart
class SpireState {
  Map<int,int> nodeLevels;        // nodeId(1..24) -> level(0..80)
  Map<int,int> tierGatesUnlocked; // nodeId -> highest band unlocked (0/20/40/60)
  int totalGoldSpent;             // analytics + Ascension projection
}

class ResearchState {
  Set<String> completedIds;
  int insightSpent;
}

class AscensionState {
  int count;
  Map<String,int> emberdustRanks; // branchNodeId -> rank
  DateTime? lastAscendedAt;
  int highestChapterEver;         // never resets — drives the Emberdust formula
}

class MarkState {
  Map<String,int> progress;       // markId -> counter (e.g. confluences: 4,182)
  Set<String> unlockedIds;
}
```

## 13.4 HeroState

```dart
class HeroState {
  String heroId;
  bool unlocked;
  int level;                      // 1..cap (cap = 8 * chaptersCleared)
  int stars;                      // 0..6
  Map<int,String> talentChoices;  // starTier(1,3,5) -> branchId ('a'|'b')
  int shardsSpent;
  DateTime? firstUnlockedAt;
  HeroStats cachedStats;          // recomputed on any mutation, never trusted from disk
}
```

`cachedStats` is a **derived** field written for UI speed and recomputed from
`level/stars/talents` on load. Derived values are never authoritative — a corrupted or edited
cache cannot grant power.

## 13.5 Inventory

```dart
class InventoryState {
  Map<String, ArrowInstance> arrows;   // arrowId -> instance
  Set<String> cosmeticIds;
  Set<String> windlineSkinIds;
  int rerollCountThisSession;          // escalating cost, resets daily
}

class ArrowInstance {
  String arrowId;                 // one of 12 types
  bool crafted;
  int refineLevel;                // 0..5
  List<Affix> affixes;            // up to 4
  Set<int> lockedAffixSlots;      // max 2
}

class Affix {
  String affixId;                 // one of 18
  double value;                   // rolled within the affix's range
  int tier;
}
```

## 13.6 Campaign & level progress

```dart
class CampaignState {
  int currentChapter;
  int currentStage;
  Map<String, StageRecord> records;   // "c7s12" -> record
  Set<String> bossesDefeated;
  Map<String,int> bossKillCounts;     // drives the +6% repeat-scaling
  int endlessBestFloor;
  int endlessSeasonId;
}

class StageRecord {
  int stars;                      // 0..3
  Duration bestTime;
  int clearCount;
  int bestConfluenceCount;
  DateTime firstClearedAt;
  Set<String> enemiesSeen;        // powers the bestiary and threat preview
}
```

## 13.7 RunSnapshot (crash recovery + determinism)

```dart
class RunSnapshot {
  String runId;
  int seed;                       // the whole run is reproducible from this
  StageRef stage;
  String heroId;
  String arrowId;
  int roomIndex;
  List<String> boonIds;           // ordered, with copy counts
  int currentHp;
  int runGold;
  Map<String,int> runMaterials;
  Duration elapsed;
  DateTime startedAt;
  List<int>? inputTape;           // optional; enables replay + server validation
}
```

Written at every room boundary (~2 KB). The `seed` + `inputTape` pair is what makes
[12 §12.0](12-architecture.md)'s determinism promise real and usable.

## 13.8 Rewards, Quests, Purchases, Achievements

```dart
class RewardsState {
  int dailyCycleDay;              // 1..28
  DateTime? lastDailyClaimAt;
  Map<String,DateTime> chestTimers;
  Map<String,int> chestPityCounters;   // shown in the UI, never hidden
  int battlePassTier;
  int battlePassXp;
  bool battlePassPremium;
  int battlePassSeasonId;
  Set<String> claimedTierIds;
}

class QuestState {
  List<QuestInstance> daily;      // 4, rotate at 05:00 local
  List<QuestInstance> weekly;     // 6, rotate Monday
  DateTime dailyResetAt;
  DateTime weeklyResetAt;
}

class QuestInstance {
  String questId; int progress; int target; bool claimed;
}

class PurchaseState {
  List<PurchaseRecord> history;
  bool removeAdsOwned;
  SubscriptionState? pact;        // Warden's Pact
  Set<String> consumedOneTimeSkus; // starter pack etc.
  double lifetimeSpendUsd;         // local only, never synced or sold
}

class SubscriptionState {
  String productId; DateTime startedAt; DateTime expiresAt;
  bool autoRenewing; bool inGracePeriod; String? latestReceiptHash;
}

class AchievementState {
  Map<String,int> progress;       // achievementId -> counter
  Set<String> claimedIds;
}
```

**Purchases are verified before entitlement.** `in_app_purchase` receipt → server validation
endpoint (or, pre-server, local receipt validation with a queued re-check). Entitlement is
written only after a positive result; a failed verification queues a retry rather than granting
or denying silently.

## 13.9 Settings & Stats

```dart
class SettingsState {
  double musicVolume, sfxVolume, uiVolume;
  bool haptics, screenShake, damageNumbers, reduceMotion;
  String graphicsQuality;         // 'auto'|'high'|'balanced'|'battery'
  int fpsCap;                     // 30|60|120
  double particleDensity;         // 0.25..1.0
  String autoAim;                 // 'off'|'light'|'standard'|'strong'
  bool leftHanded, oneHandedMode, autoUltimate;
  double joystickScale;
  String locale;
  bool notificationsEnabled;
  bool colorBlindMode;
  bool analyticsOptOut;           // honoured, not cosmetic
}

class StatsState {
  int runsStarted, runsWon, runsLost;
  int enemiesKilled, bossesKilled, elitesKilled;
  int confluencesTriggered;       // -> Mark of the Thread
  int maxConfluenceStack;
  int tierThreeShotsLanded;       // -> Mark of Stillness
  int maxMomentumReached;         // -> Mark of the Gale
  Duration totalPlayTime;
  int goldEarnedLifetime, gemsEarnedLifetime;
  Map<String,int> heroUsageSeconds;
  Map<String,int> deathsByEnemyId;   // powers "What got you" (10 §10.9)
}
```

## 13.10 Cloud schema (Firestore)

```
users/{uid}
  ├─ profile          { displayName, avatarId, titleId, accountLevel, updatedAt }
  ├─ save/current     { compressed PlayerSave blob, schemaVersion, deviceId, savedAt }
  ├─ save/backup_1..3 { rotating slots }
  └─ receipts/{id}    { sku, platform, token, verifiedAt, status }

leaderboards/{boardId}/entries/{uid}
  { score, chapter, floor, heroId, arrowId, buildCode, updatedAt, cohortId }

cohorts/{cohortId}
  { weekId, powerBand, memberUids[50] }

events/{eventId}
  { startAt, endAt, rulesJson, rewardTableJson, active }

config/economy_v1        { every tunable from 02, 04, 08, 09 }
config/content_overlay   { patches to assets/data/*.json }
config/flags             { feature flags, killswitches }
```

**Security rules:** a user may read and write only `users/{uid}` where `uid == request.auth.uid`.
Leaderboard entries are **write-denied to clients** — they are written by a Cloud Function that
validates the submitted run against the seed and input tape. `config/*` is read-only to clients.
Receipts are client-writable but entitlement is granted only by the verifying function.

**PII discipline:** we store a display name and an auth uid. No email in Firestore, no device
advertising ID in the save, no `lifetimeSpendUsd` in the cloud. Account deletion removes
`users/{uid}` and all leaderboard entries within 24 h, and the button is in Settings, not behind
a support ticket.

## 13.11 Static content schemas

Shipped in `assets/data/`, hot-patchable via `config/content_overlay`:

| File | Contains | Rows |
|---|---|---|
| `enemies.json` | Every field in [05](05-enemies.md) | 26 (+4 variants) |
| `bosses.json` | Phases, attack tables, telegraph timings | 20 |
| `heroes.json` | Stats, passives, ultimates, talent branches | 20 |
| `arrows.json` | baseMult, element, modifiers, craft costs | 12 |
| `affixes.json` | Ranges, tier weights | 18 |
| `boons.json` | Effects, rarity, weights, tags, max copies | 112 |
| `synergies.json` | Set definitions and bonuses | 10 |
| `chapters.json` | Stage counts, arena sets, spawn tables, boss refs | 12 |
| `arenas.json` | Layout geometry, cover, spawn points | ~60 |
| `spire.json` | 24 nodes, formulas, gates | 24 |
| `research.json` | Branches, costs, effects | ~30 |
| `marks.json` | Conditions, effects | 25 |
| `quests.json` | Templates and targets | ~40 |
| `achievements.json` | Conditions, rewards | 180 |
| `economy.json` | Every curve constant | — |

**All content JSON is schema-validated at build time** by a Dart script in CI. A malformed
enemy entry fails the build rather than crashing a player's phone in chapter 7.

## 13.12 Migration policy

- Migrations live in `data/local/migrations/`, one file per version, forward-only.
- Each has a test fixture: a real save captured from the previous shipped version.
- A save from a **newer** schema than the running client is never opened or "fixed" — the client
  refuses, keeps the file untouched, and prompts for an app update. Silently downgrading a save
  is how players lose accounts.
- Migrations run before the Menu renders and cannot be interrupted; a failure falls back to a
  backup slot and reports `save_migration_failed`.
