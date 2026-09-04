import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/balance/shrine_pricing.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/boon_inventory.dart';
import 'package:quiverfall/game/boons/boon_pool.dart';
import 'package:quiverfall/game/boons/loadout_resolver.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/room_blueprint.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spawn/boss_room_composer.dart';

/// Where a stage is.
enum StageStatus {
  /// A room is in progress.
  fighting,

  /// A room just cleared and the run is paused on a Boon draw. docs/11 §11.1:
  /// `RoomClear --> Boon Choice --> Game`.
  awaitingBoonChoice,

  /// A Shrine room just cleared. docs/11 §11.1: `RoomClear --> Shrine --> Game`.
  awaitingShrine,

  /// The last room is cleared. The stage is won.
  complete,

  /// The player died.
  failed,
}

/// Plays a stage, one room at a time.
///
/// The generator produces a whole stage up front — that is what makes a stage
/// reproducible from its seed, and what lets the room after this one be
/// validated before the player reaches it. This walks that plan: it loads a
/// room into the world, notices when the room is cleared, and loads the next.
///
/// Deliberately not a widget and not a Flame component. Room progression is
/// run state, not presentation, and Phase 13's Shrine, Phase 9's Boon choice
/// and Phase 11's boss entrances all need to interrupt it without owning it.
class StageRunner {
  StageRunner({
    required this.world,
    required this.content,
    required this.plan,
    BoonCatalogue? boonCatalogue,
    SynergyCatalogue synergies = SynergyCatalogue.empty,
  }) : boons = BoonInventory(
          catalogue: boonCatalogue ?? BoonCatalogue.empty(),
          synergies: synergies,
        );

  final SimWorld world;
  final ContentLibrary content;
  final StagePlan plan;

  /// The run's Boon build. Empty (no catalogue) by default, in which case
  /// [update] behaves exactly as it did before Phase 9: a room clear advances
  /// immediately, with no interstitial. Every seeded test that predates the
  /// Boon system constructs a [StageRunner] this way, and none of them should
  /// have to change to keep passing.
  final BoonInventory boons;

  late final BoonPool _boonPool =
      BoonPool(catalogue: boons.catalogue, inventory: boons);

  /// Split off [SimWorld]'s seed stream **lazily**, on first real use, so a
  /// run with no Boon catalogue never advances `world`'s RNG cursor at all.
  /// Splitting unconditionally in the constructor would reseed every other
  /// subsystem that lazily derives from the same parent afterward — the crit
  /// roll's own stream among them — for tests that never touch a Boon.
  late final Rng _boonRng = world.rngFor(_boonRngLabel);

  static const int _boonRngLabel = 0x800B;

  int _roomIndex = -1;
  StageStatus _status = StageStatus.fighting;

  /// Rooms fully cleared this stage. Drives partial credit on defeat.
  int _roomsCleared = 0;

  int get roomIndex => _roomIndex;

  int get roomsCleared => _roomsCleared;

  int get roomTotal => plan.roomCount;

  StageStatus get status => _status;

  RoomBlueprint get room => plan.rooms[_roomIndex];

  bool get isLastRoom => _roomIndex >= plan.roomCount - 1;

  // ── Boon Choice ────────────────────────────────────────────────────────────

  /// The current draw, while [status] is [StageStatus.awaitingBoonChoice].
  /// Empty otherwise.
  List<BoonOffer> get pendingBoonOffers => _pendingOffers;
  List<BoonOffer> _pendingOffers = const <BoonOffer>[];

  /// The context the current draw used, kept so a reroll repeats it rather
  /// than silently dropping an Elite clear's bonus weight or a Shrine
  /// purchase's Rare+ guarantee.
  DrawContext? _lastDrawContext;

  /// True while the pending draw was bought at the Shrine rather than reached
  /// by clearing a room — see [pickBoon].
  bool _boonChoiceFromShrine = false;

  int _rerollsSpent = 0;

  /// *Second Choice* (#102) grants rerolls as a stat; a Shrine purchase grants
  /// one directly. Both spend from the same budget.
  int _shrineRerollCredits = 0;

  /// Rerolls this run has left. 0 with no Boon catalogue, since nothing grants
  /// any.
  int get rerollsRemaining =>
      boons.stats.countFor(StatChannel.boonRerolls) +
      _shrineRerollCredits -
      _rerollsSpent;

  /// Takes a card from [pendingBoonOffers].
  ///
  /// A card bought at the Shrine returns to the Shrine afterward rather than
  /// resuming the fight — the player may still have gold to spend on a heal or
  /// a reroll, and one purchase should not end the visit for them.
  void pickBoon(BoonDefinition def) {
    assert(_status == StageStatus.awaitingBoonChoice);
    boons.take(def, rng: _boonRng);
    LoadoutResolver.applyBuild(
      world,
      boons,
      baseAttack: lawfulAttackFor(plan.blueprint.globalStage),
    );
    _pendingOffers = const <BoonOffer>[];

    if (_boonChoiceFromShrine) {
      _boonChoiceFromShrine = false;
      _status = StageStatus.awaitingShrine;
    } else {
      _status = StageStatus.fighting;
      _advance();
    }
  }

  /// Redraws the current offer. False if no reroll is left.
  bool rerollBoonOffers() {
    assert(_status == StageStatus.awaitingBoonChoice);
    final DrawContext? context = _lastDrawContext;
    if (rerollsRemaining <= 0 || context == null) return false;
    _rerollsSpent++;
    _drawBoonOffers(context);
    return true;
  }

  void _drawBoonOffers(DrawContext context) {
    _lastDrawContext = context;
    _pendingOffers = _boonPool.drawSet(_boonRng, context);
  }

  // ── The Shrine ─────────────────────────────────────────────────────────────
  // docs/02 §2.4. Gambling is named in the GDD but never specified — no odds,
  // stake, or payout are given anywhere — so it is not implemented; see
  // ShrinePricing's own doc comment.

  double _shrineGoldSpent = 0;

  double get shrineHealPrice => ShrinePricing.healPrice(
        plan.blueprint.chapter,
        plan.blueprint.stage,
        discount: boons.stats[StatChannel.shrineDiscount],
      );

  double get shrineRerollPrice => ShrinePricing.rerollPrice(
        plan.blueprint.chapter,
        plan.blueprint.stage,
        discount: boons.stats[StatChannel.shrineDiscount],
      );

  double get shrineBoonPrice => ShrinePricing.boonPrice(
        plan.blueprint.chapter,
        plan.blueprint.stage,
        discount: boons.stats[StatChannel.shrineDiscount],
      );

  /// Heals 35 % of max HP. False if the run cannot afford it.
  bool buyShrineHeal() {
    assert(_status == StageStatus.awaitingShrine);
    if (!_trySpendShrineGold(shrineHealPrice)) return false;
    if (!world.player.isNone) {
      final int p = world.player.index;
      final double healed = world.entities.health[p] +
          world.entities.maxHealth[p] * ShrinePricing.healFraction;
      world.entities.health[p] =
          healed > world.entities.maxHealth[p] ? world.entities.maxHealth[p] : healed;
    }
    return true;
  }

  /// Buys one reroll, spendable on the next Boon choice. False if the run
  /// cannot afford it.
  bool buyShrineReroll() {
    assert(_status == StageStatus.awaitingShrine);
    if (!_trySpendShrineGold(shrineRerollPrice)) return false;
    _shrineRerollCredits++;
    return true;
  }

  /// Buys a guaranteed-Rare+ Boon draw. False if the run cannot afford it.
  ///
  /// docs/09 §9.1 lists "Shrine purchase" as one of the three ways a draw's
  /// Rare+ weight is raised, alongside the Spire node and an Elite clear — so
  /// this reuses the normal Boon Choice screen with that one modifier, rather
  /// than a separate purchase flow.
  bool buyShrineBoon() {
    assert(_status == StageStatus.awaitingShrine);
    if (!_trySpendShrineGold(shrineBoonPrice)) return false;
    _boonChoiceFromShrine = true;
    _drawBoonOffers(
      DrawContext(roomIndex: _roomIndex + 1, guaranteeRarePlus: true),
    );
    _status = StageStatus.awaitingBoonChoice;
    return true;
  }

  /// Ends the Shrine visit and resumes the fight.
  void leaveShrine() {
    assert(_status == StageStatus.awaitingShrine);
    _status = StageStatus.fighting;
    _advance();
  }

  bool _trySpendShrineGold(double amount) {
    if (amount > bankedGold) return false;
    _shrineGoldSpent += amount;
    return true;
  }

  /// Gold banked if the run ended right now, net of anything already spent at
  /// the Shrine.
  ///
  /// **There is no zero-reward run.** The 0.7 factor is the entire penalty for
  /// dying (docs/14 §14.6), and it is small on purpose — it is what lets the
  /// game have permadeath runs without the churn that usually comes with them.
  double get bankedGold {
    final double raw = Curves.partialGold(
      plan.blueprint.chapter,
      plan.blueprint.stage,
      _roomsCleared,
      plan.roomCount,
    );
    final double net = raw - _shrineGoldSpent;
    return net < 0 ? 0 : net;
  }

  /// Loads the first room. Call once.
  void start() {
    _roomIndex = -1;
    _roomsCleared = 0;
    _status = StageStatus.fighting;
    _advance();
  }

  /// Call once per tick, after the world has ticked.
  ///
  /// Returns true on the tick a room boundary was crossed, which is where the
  /// caller writes a [RunSnapshot] — an OOM kill then costs at most one room
  /// (docs/19 §19.6).
  ///
  /// With no Boon catalogue, a clear advances straight to the next room, as it
  /// always has. With one, the run pauses on [StageStatus.awaitingBoonChoice]
  /// or [StageStatus.awaitingShrine] instead, and the caller resumes it by
  /// calling [pickBoon] or [leaveShrine] — this is the interruption
  /// [StageRunner]'s own class doc names, without [StageRunner] handing over
  /// ownership of room progression to do it.
  bool update() {
    if (_status != StageStatus.fighting) return false;

    if (!world.entities.isAlive(world.player)) {
      _status = StageStatus.failed;
      return true;
    }

    if (!world.spawnState.roomClearedEmitted) return false;

    _roomsCleared++;

    if (isLastRoom) {
      _status = StageStatus.complete;
      return true;
    }

    if (boons.catalogue.isEmpty) {
      _advance();
      return true;
    }

    final RoomKind justCleared = room.kind;
    if (justCleared == RoomKind.shrine) {
      _status = StageStatus.awaitingShrine;
    } else {
      _drawBoonOffers(
        DrawContext(
          roomIndex: _roomIndex + 1,
          afterEliteClear: justCleared == RoomKind.elite,
        ),
      );
      _status = StageStatus.awaitingBoonChoice;
    }
    return true;
  }

  /// Loads the next room into the world.
  ///
  /// The player's *health carries over* — a run is a descent, not a series of
  /// unrelated fights, and healing between rooms would delete the pressure that
  /// makes the Shrine's push-or-bank decision mean anything.
  void _advance() {
    _roomIndex++;
    final RoomBlueprint next = plan.rooms[_roomIndex];

    final double health = _playerHealth();
    final double maxHealth = _playerMaxHealth();

    world
      ..clearRoom()
      ..loadArena(next.arena.toSimArena());

    final int player = world
        .spawnPlayer(next.arena.playerStartX, next.arena.playerStartY)
        .index;
    world.entities.maxHealth[player] = maxHealth;
    world.entities.health[player] = health;

    world
      ..enemyHpBase = Curves.enemyHp(plan.blueprint.globalStage)
      ..globalStage = plan.blueprint.globalStage
      ..beginRoom(next.plan);

    // `next.plan` is deliberately empty for a boss slot (`LevelGenerator
    // ._assemble`) — nothing for `SpawnSystem` to release, so the room stays
    // open exactly as long as the boss's own entities do. `encounterCount`
    // is always 0: this run has no access to how many times the player's
    // own save has beaten this boss before (`PlayerSave`, not something
    // `StageRunner` reads) — a real, deliberate gap, not an oversight; see
    // ADR 0021.
    final BossArchetype? boss = next.bossArchetype;
    if (boss != null) {
      final BossDefinition? def = content.bosses.byArchetype(boss);
      if (def != null) {
        BossRoomComposer.spawn(
          world,
          boss,
          Curves.bossHp(plan.blueprint.globalStage, def.hpMultiplier, 0),
        );
      }
    }
  }

  double _playerHealth() {
    if (!world.entities.isAlive(world.player)) return _defaultMaxHealth;
    final double current = world.entities.health[world.player.index];
    return current > 0 ? current : _defaultMaxHealth;
  }

  double _playerMaxHealth() {
    if (!world.entities.isAlive(world.player)) return _defaultMaxHealth;
    final double max = world.entities.maxHealth[world.player.index];
    return max > 0 ? max : _defaultMaxHealth;
  }

  /// `GameScreen` now calls `HeroLoadoutResolver.apply` once a real hero is
  /// known, which sets the player entity's real max HP directly — this is
  /// only ever read when that never happened (a caller building a
  /// [SimWorld] with no chosen build at all, `stage_runner_test.dart`
  /// included) or the player is not currently alive. Every enemy's damage is
  /// a *fraction* of max HP regardless, so even this placeholder's absolute
  /// number never changes anything about a fight's balance.
  static const double _defaultMaxHealth = 100;
}

/// Attack that lands TTK inside the 0.8–1.6 s band of Design Law 1.
///
/// Two Tier-III arrows kill a x1.0 common enemy. The generic placeholder
/// `buildStageWorld` sets `world.playerAttack` to — `GameScreen` overwrites
/// it with the real composed hero/arrow value via `HeroLoadoutResolver.apply`
/// once a build is actually chosen; callers with no hero to supply (tests,
/// tools) keep this number as-is. Spire is not part of that composed value
/// yet either way — the Spire itself is still Phase 13's own gap, not this
/// one's.
double lawfulAttackFor(int globalStage) =>
    Curves.enemyHp(globalStage) / (2.10 * 2);

/// Convenience for building a world sized to a stage.
SimWorld buildStageWorld({
  required StageBlueprint blueprint,
  required ContentLibrary content,
  required StagePlan plan,
}) {
  final SimWorld world = SimWorld(
    seed: blueprint.seed,
    content: content,
    arena: plan.rooms.first.arena.toSimArena(),
  );

  world
    ..enemyHpBase = Curves.enemyHp(blueprint.globalStage)
    ..globalStage = blueprint.globalStage
    ..playerAttack = lawfulAttackFor(blueprint.globalStage);

  assert(
    SimConfig.arenaWidth == 16 && SimConfig.arenaHeight == 9,
    'arenas are authored against a 16x9 screen',
  );

  return world;
}
