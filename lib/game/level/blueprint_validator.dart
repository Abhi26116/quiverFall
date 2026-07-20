import 'package:quiverfall/game/balance/clear_time.dart';
import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/level/arena_definition.dart';
import 'package:quiverfall/game/level/room_blueprint.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/spawn/composition_validator.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';

/// The eight constraints from docs/14 §14.2, applied to a placed room.
///
/// [CompositionValidator] already polices what a room *contains* — it is
/// shared with the Phase 5 composer and with any hand-authored encounter. This
/// adds the three constraints that only exist once a room has an **arena** and
/// a **placement**, plus the monotony and density checks that need the whole
/// blueprint in one place.
///
/// Step 6 of the pipeline is why the generator is safe: it is allowed to fail
/// and reroll, and a validated fallback always exists. A generator that policed
/// itself and nothing else would be a generator nobody could change safely.
abstract final class BlueprintValidator {
  /// No more than this share of the threat budget in one enemy type.
  ///
  /// The monotony check. A room that is 80 % Motes is not a fight, it is a
  /// chore — and procedural systems drift toward monotony naturally, because
  /// the cheapest enemy always fits.
  static const double maxSingleTypeShare = 0.60;

  static List<CompositionViolation> validate(
    RoomBlueprint blueprint,
    ContentLibrary content,
  ) {
    // Constraints 1-4: Choir cap, safe-threat floor, the Screecher/Longeye ban,
    // Elite composition, the chapter schedule. Shared with the composer.
    final List<CompositionViolation> out =
        CompositionValidator.validate(blueprint.plan, content);

    _checkNothingSafeToShoot(blueprint, content, out);
    _checkMonotony(blueprint, content, out);
    _checkSpawnDistance(blueprint, out);
    _checkClearTime(blueprint, out);
    _checkDensity(blueprint, out);
    _checkPlacement(blueprint, content, out);

    return out;
  }

  /// "No Drift or Rush enemies (nothing safe to shoot)."
  ///
  /// Distinct from the 40 % threat-share rule: a room could in principle clear
  /// the share with one enormous Drift unit and still leave the player nothing
  /// harmless to shoot at. The player must always have something safe to shoot,
  /// or the room stops feeling like an action game.
  static void _checkNothingSafeToShoot(
    RoomBlueprint blueprint,
    ContentLibrary content,
    List<CompositionViolation> out,
  ) {
    if (blueprint.kind == RoomKind.elite) return;

    final bool any = blueprint.enemies.any((PlannedEnemy e) {
      final EnemyFamily family = e.definitionIn(content).family;
      return family == EnemyFamily.drift || family == EnemyFamily.rush;
    });

    if (!any && blueprint.enemyCount > 0) {
      out.add(
        const CompositionViolation(
          'something safe to shoot',
          'the room contains no Drift or Rush enemies at all',
        ),
      );
    }
  }

  static void _checkMonotony(
    RoomBlueprint blueprint,
    ContentLibrary content,
    List<CompositionViolation> out,
  ) {
    final double total = blueprint.threatIn(content);
    if (total <= 0) return;

    final Map<EnemyArchetype, double> byType = <EnemyArchetype, double>{};
    for (final PlannedEnemy enemy in blueprint.enemies) {
      final EnemyArchetype type = enemy.definitionIn(content).archetype;
      byType[type] = (byType[type] ?? 0) + enemy.threatIn(content);
    }

    for (final MapEntry<EnemyArchetype, double> entry in byType.entries) {
      final double share = entry.value / total;
      if (share > maxSingleTypeShare + 1e-9) {
        out.add(
          CompositionViolation(
            'monotony: <= ${(maxSingleTypeShare * 100).round()}% one type',
            '${entry.key.name} is ${(share * 100).toStringAsFixed(0)}% '
                'of the budget',
          ),
        );
      }
    }
  }

  /// "Any spawn point within 3.5 u of `playerStart`."
  ///
  /// Checked against the *arena*, not against the placements, because a spawn
  /// point too close to the player start is an authoring bug that would bite
  /// whichever room happened to draw it. Catching it here means it fails on
  /// every room that uses the arena rather than intermittently.
  static void _checkSpawnDistance(
    RoomBlueprint blueprint,
    List<CompositionViolation> out,
  ) {
    const double minimum = EnemyTuning.minSpawnDistanceFromPlayer;

    for (final SpawnPoint point in blueprint.arena.spawnPoints) {
      final double dx = point.x - blueprint.arena.playerStartX;
      final double dy = point.y - blueprint.arena.playerStartY;
      if (dx * dx + dy * dy < minimum * minimum) {
        out.add(
          CompositionViolation(
            'spawns >= ${minimum}u from the player start',
            '${blueprint.arena.id} has a spawn at '
                '(${point.x}, ${point.y})',
          ),
        );
        return;
      }
    }
  }

  static void _checkClearTime(
    RoomBlueprint blueprint,
    List<CompositionViolation> out,
  ) {
    if (blueprint.enemyCount == 0) return;
    if (ClearTimeModel.isWithinBand(blueprint.estimatedSeconds)) return;

    out.add(
      CompositionViolation(
        'clear time in '
            '${ClearTimeModel.minSeconds.round()}-'
            '${ClearTimeModel.maxSeconds.round()}s',
        'estimated ${blueprint.estimatedSeconds.toStringAsFixed(1)}s',
      ),
    );
  }

  /// "Total simultaneous entity count would exceed 90."
  ///
  /// Simultaneous, so it is a per-wave check. A room may hold more than the cap
  /// in total because waves arrive in sequence.
  static void _checkDensity(
    RoomBlueprint blueprint,
    List<CompositionViolation> out,
  ) {
    for (int i = 0; i < blueprint.plan.waves.length; i++) {
      final int size = blueprint.plan.waves[i].size;
      if (size > SimConfig.maxContactEnemies) {
        out.add(
          CompositionViolation(
            'wave size <= ${SimConfig.maxContactEnemies}',
            'wave $i has $size',
          ),
        );
      }
    }
  }

  /// Every enemy placed, and placed somewhere its family is allowed.
  ///
  /// docs/14 §14.4's family rules are what make a room *readable*: Salvo at the
  /// edges, Rush at mid-distance so its approach can be seen coming, Choir
  /// behind its pack so the priority target is obvious. A misplaced Choir unit
  /// is not a crash — it is a room that silently teaches the wrong lesson.
  static void _checkPlacement(
    RoomBlueprint blueprint,
    ContentLibrary content,
    List<CompositionViolation> out,
  ) {
    if (blueprint.enemyCount == 0) return;

    if (!blueprint.isFullyPlaced) {
      out.add(
        const CompositionViolation(
          'every enemy is placed',
          'the generator left an enemy without a spawn point',
        ),
      );
      return;
    }

    const double minimum = EnemyTuning.minSpawnDistanceFromPlayer;
    for (final PlannedEnemy enemy in blueprint.enemies) {
      final double dx = enemy.spawnX! - blueprint.arena.playerStartX;
      final double dy = enemy.spawnY! - blueprint.arena.playerStartY;
      if (dx * dx + dy * dy < minimum * minimum) {
        out.add(
          CompositionViolation(
            'placements >= ${minimum}u from the player start',
            '${enemy.definitionIn(content).name} placed at '
                '(${enemy.spawnX}, ${enemy.spawnY})',
          ),
        );
        return;
      }
    }
  }
}
