import 'package:quiverfall/game/balance/clear_time.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/level/arena_definition.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';

/// One fully-specified room: an arena, a composition, and placed spawns.
///
/// Everything the simulation needs to build a fight, decided before the room
/// loads and validated before it ships. That ordering is the whole safety
/// property of the generator (docs/14 §14.2): **it is allowed to fail; it is
/// not allowed to ship a bad room.**
class RoomBlueprint {
  const RoomBlueprint({
    required this.arena,
    required this.plan,
    required this.slot,
    required this.estimatedSeconds,
    this.attempts = 1,
    this.usedFallback = false,
    this.bossArchetype,
  });

  final ArenaDefinition arena;
  final RoomPlan plan;
  final RoomSlot slot;

  /// Which boss to spawn, for a [RoomKind.boss] slot whose chapter actually
  /// has one built, or a [RoomKind.elite] slot whose exact stage actually
  /// has an Elite-tier boss built (`EliteRoomComposer.eliteFor`) — null for
  /// every other slot, and for a boss/Elite slot with no fight built for
  /// that chapter/stage (`BossRoomComposer.bossFor`), in which case [plan]
  /// is an ordinary composed room like any other, the same "playable rather
  /// than a hole in the stage" fallback a Shrine slot gets before Phase 13.
  /// See ADR 0021/0055.
  final BossArchetype? bossArchetype;

  /// From [ClearTimeModel]. Phase 12's balance harness replaces the model; this
  /// field survives it.
  final double estimatedSeconds;

  /// Generation attempts this room took. One is the healthy case.
  final int attempts;

  /// True if generation gave up and used the authored fallback encounter.
  ///
  /// Not a failure of the *room* — the fallback is known-good — but a failure
  /// of the *generator*, and the Phase 8 exit criterion is zero of these under
  /// normal conditions.
  final bool usedFallback;

  RoomKind get kind => slot.kind;

  int get enemyCount => plan.totalEnemies;

  /// Every planned enemy in wave order.
  Iterable<PlannedEnemy> get enemies =>
      plan.waves.expand((WavePlan w) => w.enemies);

  /// True if every enemy was assigned an authored spawn point.
  bool get isFullyPlaced => enemies.every((PlannedEnemy e) => e.isPlaced);

  double threatIn(ContentLibrary content) => plan.threatIn(content);
}
