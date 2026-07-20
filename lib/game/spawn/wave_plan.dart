import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';

/// One enemy, as planned — not yet as spawned.
///
/// A plain value, deliberately: room plans are built ahead of time, validated,
/// logged with the run seed, and replayed. Nothing here may reference live
/// simulation state.
class PlannedEnemy {
  const PlannedEnemy(this.contentIndex, [this.variant = EnemyVariant.none]);

  /// Index into [ContentLibrary.enemies].
  final int contentIndex;

  final EnemyVariant variant;

  double threatIn(ContentLibrary content) =>
      content.enemies[contentIndex].threatCost * variant.threatMultiplier;

  EnemyDefinition definitionIn(ContentLibrary content) =>
      content.enemies[contentIndex];
}

/// A group that enters together.
///
/// Rooms arrive in waves rather than all at once for a readability reason
/// before a difficulty one: twenty enemies on screen at spawn is an unreadable
/// smear on a 5.5" screen, whereas the same twenty in three waves is a fight
/// with a shape.
class WavePlan {
  const WavePlan(this.enemies);

  final List<PlannedEnemy> enemies;

  int get size => enemies.length;

  double threatIn(ContentLibrary content) {
    double total = 0;
    for (final PlannedEnemy e in enemies) {
      total += e.threatIn(content);
    }
    return total;
  }
}

/// Everything that will be spawned in one room.
class RoomPlan {
  const RoomPlan({
    required this.waves,
    required this.threatBudget,
    required this.chapter,
    required this.globalStage,
    this.isElite = false,
  });

  final List<WavePlan> waves;

  /// `Curves.threatBudget(globalStage)` — what the composer was allowed to
  /// spend, kept so the validator can check the plan against its own budget
  /// rather than recomputing it from a stage index it might get wrong.
  final double threatBudget;

  final int chapter;
  final int globalStage;

  /// Elite rooms contain exactly one Riftborn plus limited support, and are
  /// announced by a crimson arena border and a musical stinger.
  final bool isElite;

  int get totalEnemies {
    int n = 0;
    for (final WavePlan w in waves) {
      n += w.size;
    }
    return n;
  }

  double threatIn(ContentLibrary content) {
    double total = 0;
    for (final WavePlan w in waves) {
      total += w.threatIn(content);
    }
    return total;
  }

  /// Share of the plan's spent threat that is Drift or Rush.
  ///
  /// The player must always have something safe to shoot, or the room stops
  /// feeling like an action game (docs/05 §5.7).
  double safeThreatShare(ContentLibrary content) {
    double total = 0;
    double safe = 0;
    for (final WavePlan w in waves) {
      for (final PlannedEnemy e in w.enemies) {
        final double cost = e.threatIn(content);
        total += cost;
        final EnemyFamily family = e.definitionIn(content).family;
        if (family == EnemyFamily.drift || family == EnemyFamily.rush) {
          safe += cost;
        }
      }
    }
    return total <= 0 ? 1.0 : safe / total;
  }

  int countOfFamily(ContentLibrary content, EnemyFamily family) {
    int n = 0;
    for (final WavePlan w in waves) {
      for (final PlannedEnemy e in w.enemies) {
        if (e.definitionIn(content).family == family) n++;
      }
    }
    return n;
  }

  bool contains(ContentLibrary content, EnemyArchetype archetype) {
    for (final WavePlan w in waves) {
      for (final PlannedEnemy e in w.enemies) {
        if (e.definitionIn(content).archetype == archetype) return true;
      }
    }
    return false;
  }
}
