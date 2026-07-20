import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/room_blueprint.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';

/// Where a stage is.
enum StageStatus {
  /// A room is in progress.
  fighting,

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
  });

  final SimWorld world;
  final ContentLibrary content;
  final StagePlan plan;

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

  /// Gold banked if the run ended right now.
  ///
  /// **There is no zero-reward run.** The 0.7 factor is the entire penalty for
  /// dying (docs/14 §14.6), and it is small on purpose — it is what lets the
  /// game have permadeath runs without the churn that usually comes with them.
  double get bankedGold => Curves.partialGold(
        plan.blueprint.chapter,
        plan.blueprint.stage,
        _roomsCleared,
        plan.roomCount,
      );

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

    _advance();
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

  /// Phase 10 computes real player HP from the hero and the Spire. Until then
  /// every enemy's damage is a *fraction* of max HP, so the absolute number
  /// changes nothing about the fight.
  static const double _defaultMaxHealth = 100;
}

/// Player HP used until Phase 10 supplies a real loadout.
const double kDefaultPlayerHealth = 100;

/// Attack that lands TTK inside the 0.8–1.6 s band of Design Law 1.
///
/// Two Tier-III arrows kill a x1.0 common enemy. Phase 10 replaces this with
/// the composed hero/arrow/Spire value.
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
