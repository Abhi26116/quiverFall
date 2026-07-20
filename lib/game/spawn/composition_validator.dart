import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';

/// A composition rule a room plan broke.
class CompositionViolation {
  const CompositionViolation(this.rule, this.detail);

  /// The rule's name, matching docs/05 §5.7.
  final String rule;

  final String detail;

  @override
  String toString() => '$rule — $detail';
}

/// The room-composition rules from docs/05 §5.7.
///
/// **These exist to stop the procedural system producing unfair or boring
/// rooms**, which is a failure mode every generated-content game in this
/// category ships at least once. Encoding them as a validator rather than as
/// care inside the generator means they are testable, they are checked on every
/// generated room in debug, and Phase 8's level generator inherits them for free
/// rather than reimplementing them slightly differently.
abstract final class CompositionValidator {
  /// Elite rooms may spend this much of the normal budget on support, *on top
  /// of* their single Riftborn.
  static const double eliteSupportShare = 0.30;

  /// At least this share of a room's threat must be Drift or Rush.
  static const double minSafeThreatShare = 0.40;

  static const int maxChoirPerRoom = 2;

  /// The Screecher/Longeye ban lifts here. Draw-lock into a 22 % hitscan is an
  /// unfair combination for a learning player, and a fair one for a practised
  /// one.
  static const int screecherLongeyeChapter = 8;

  /// Floating-point slack on the budget check. The composer packs greedily and
  /// a plan sitting a hair over its budget is not a design failure.
  static const double budgetTolerance = 1e-6;

  static List<CompositionViolation> validate(
    RoomPlan plan,
    ContentLibrary content,
  ) {
    final List<CompositionViolation> out = <CompositionViolation>[];

    _checkBudget(plan, content, out);
    _checkChoirCap(plan, content, out);
    _checkScreecherLongeye(plan, content, out);
    _checkSafeShare(plan, content, out);
    _checkElite(plan, content, out);
    _checkRoster(plan, content, out);
    _checkDensity(plan, out);

    return out;
  }

  static void _checkBudget(
    RoomPlan plan,
    ContentLibrary content,
    List<CompositionViolation> out,
  ) {
    final double spent = plan.threatIn(content);
    final double allowed = plan.isElite
        ? plan.threatBudget * (1.0 + eliteSupportShare)
        : plan.threatBudget;

    if (spent > allowed + budgetTolerance) {
      out.add(
        CompositionViolation(
          'threat budget',
          'spent ${spent.toStringAsFixed(1)} of '
              '${allowed.toStringAsFixed(1)} available',
        ),
      );
    }
  }

  /// Three healers is not difficulty, it is a wall.
  static void _checkChoirCap(
    RoomPlan plan,
    ContentLibrary content,
    List<CompositionViolation> out,
  ) {
    final int choir = plan.countOfFamily(content, EnemyFamily.choir);
    if (choir > maxChoirPerRoom) {
      out.add(
        CompositionViolation(
          'max $maxChoirPerRoom Choir units',
          'room contains $choir',
        ),
      );
    }
  }

  static void _checkScreecherLongeye(
    RoomPlan plan,
    ContentLibrary content,
    List<CompositionViolation> out,
  ) {
    if (plan.chapter >= screecherLongeyeChapter) return;
    if (!plan.contains(content, EnemyArchetype.screecher)) return;
    if (!plan.contains(content, EnemyArchetype.longeye)) return;

    out.add(
      CompositionViolation(
        'no Screecher + Longeye before chapter $screecherLongeyeChapter',
        'both present in a chapter ${plan.chapter} room',
      ),
    );
  }

  static void _checkSafeShare(
    RoomPlan plan,
    ContentLibrary content,
    List<CompositionViolation> out,
  ) {
    if (plan.totalEnemies == 0) return;
    // An Elite room is one Riftborn plus scraps by definition, so the safe-share
    // rule is measured against its support only — applying it to the whole room
    // would make Elite rooms structurally impossible.
    if (plan.isElite) return;

    final double share = plan.safeThreatShare(content);
    if (share < minSafeThreatShare - budgetTolerance) {
      out.add(
        CompositionViolation(
          '>= ${(minSafeThreatShare * 100).round()}% Drift or Rush threat',
          'only ${(share * 100).toStringAsFixed(1)}%',
        ),
      );
    }
  }

  static void _checkElite(
    RoomPlan plan,
    ContentLibrary content,
    List<CompositionViolation> out,
  ) {
    final int riftborn = plan.countOfFamily(content, EnemyFamily.riftborn);

    if (!plan.isElite) {
      if (riftborn > 0) {
        out.add(
          CompositionViolation(
            'Riftborn only in Elite rooms',
            'normal room contains $riftborn',
          ),
        );
      }
      return;
    }

    if (riftborn != 1) {
      out.add(
        CompositionViolation(
          'Elite rooms contain exactly one Riftborn',
          'found $riftborn',
        ),
      );
    }

    double support = 0;
    for (final WavePlan wave in plan.waves) {
      for (final PlannedEnemy e in wave.enemies) {
        if (e.definitionIn(content).family == EnemyFamily.riftborn) continue;
        support += e.threatIn(content);
      }
    }

    final double allowance = plan.threatBudget * eliteSupportShare;
    if (support > allowance + budgetTolerance) {
      out.add(
        CompositionViolation(
          'Elite support <= ${(eliteSupportShare * 100).round()}% of budget',
          'support ${support.toStringAsFixed(1)} of '
              '${allowance.toStringAsFixed(1)}',
        ),
      );
    }
  }

  /// Nothing may appear before the chapter that introduces it (docs/05 §5.8).
  ///
  /// The schedule is front-loaded so that all 26 base types are seen by chapter
  /// 8 and the second half of the campaign is about combinations rather than
  /// memorising new sprites. A generator that leaked a Null into chapter 2 would
  /// quietly undo that.
  static void _checkRoster(
    RoomPlan plan,
    ContentLibrary content,
    List<CompositionViolation> out,
  ) {
    for (final WavePlan wave in plan.waves) {
      for (final PlannedEnemy e in wave.enemies) {
        final EnemyDefinition def = e.definitionIn(content);
        if (def.introducedInChapter > plan.chapter) {
          out.add(
            CompositionViolation(
              'chapter introduction schedule',
              '${def.name} is chapter ${def.introducedInChapter}, '
                  'room is chapter ${plan.chapter}',
            ),
          );
        }
        if (e.variant != EnemyVariant.none &&
            plan.chapter < EnemyVariant.firstChapter) {
          out.add(
            CompositionViolation(
              'variants from chapter ${EnemyVariant.firstChapter}',
              '${e.variant.name} ${def.name} in chapter ${plan.chapter}',
            ),
          );
        }
      }
    }
  }

  /// Beyond the contact-enemy cap a phone screen is unreadable regardless of
  /// frame rate (docs/19 §19.1). Checked per wave, because that is the number
  /// that can be on screen at once.
  static void _checkDensity(RoomPlan plan, List<CompositionViolation> out) {
    for (int i = 0; i < plan.waves.length; i++) {
      if (plan.waves[i].size > SimConfig.maxContactEnemies) {
        out.add(
          CompositionViolation(
            'wave size <= ${SimConfig.maxContactEnemies}',
            'wave $i has ${plan.waves[i].size}',
          ),
        );
      }
    }
  }
}
