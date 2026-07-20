import 'dart:math' as math;

import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/spatial_hash.dart';

/// Aim assist strength. A player-facing setting, not a hidden constant.
///
/// `standard` for most players, `off` for those who want the full skill ceiling,
/// `strong` as an accessibility affordance. Exposing this is what lets the
/// Bounder (docs/05 §5.3) be interesting — it is untargetable mid-leap, so
/// assisted players must lead it manually for the only time in the game.
enum AimAssist {
  /// Fire along the player's facing. No correction whatsoever.
  off(correction: 0.0, leads: false),

  /// Nudges toward the target but will not save a bad angle.
  light(correction: 0.35, leads: false),

  /// Locks onto the nearest valid target.
  standard(correction: 1.0, leads: false),

  /// Locks on and leads a moving target.
  strong(correction: 1.0, leads: true);

  const AimAssist({required this.correction, required this.leads});

  /// Fraction of the way from current facing to the ideal angle.
  final double correction;

  /// Whether to solve for the target's future position.
  final bool leads;
}

/// Chooses targets and decides when to release an arrow.
///
/// Fire rate comes from the current [DrawTier] and *falls* as the tier rises:
/// heavier shots come slower. That is what stops Tier III from being
/// unconditionally correct and keeps the Draw a real decision rather than a
/// ramp everyone maximises.
abstract final class FiringSystem {
  /// Beyond this an arrow cannot acquire a target. Roughly the arena diagonal,
  /// so line of sight rather than range is the practical limit.
  static const double acquireRange = 18.0;

  /// Seconds of arrow flight assumed when leading a moving target.
  static const double leadHorizon = 0.35;

  /// Returns the slot index of the best target, or -1.
  ///
  /// "Best" is nearest-first. Deliberately not lowest-HP or highest-threat:
  /// target *priority* is a skill the game asks the player to exercise (Weaver
  /// tethers, Knitter healing, Chanter auras all reward manual selection), and
  /// an auto-aim that solved it would delete that decision.
  static int selectTarget(
    EntityStore store,
    SpatialHash spatial,
    double fromX,
    double fromY, {
    EnemyStore? enemies,
  }) {
    final int candidates = spatial.queryRadius(fromX, fromY, acquireRange);

    int best = -1;
    double bestDistSq = double.infinity;

    for (int i = 0; i < candidates; i++) {
      final int idx = spatial.resultAt(i);
      if (store.alive[idx] == 0) continue;
      if (store.kind[idx] != EntityKind.enemy.index) continue;
      // Airborne Bounders and Gravebound corpses cannot be locked. The Bounder
      // is the only moment in the game a player has to lead a shot themselves,
      // and that only works if auto-aim genuinely refuses to help.
      if (enemies != null && enemies.isUntargetable(idx)) continue;

      final double dx = store.posX[idx] - fromX;
      final double dy = store.posY[idx] - fromY;
      final double distSq = dx * dx + dy * dy;

      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        best = idx;
      }
    }
    return best;
  }

  /// Aim angle in radians for a shot at [targetIndex].
  ///
  /// Returns [currentFacing] unchanged when there is no target, so a player
  /// firing into empty space shoots where they are looking rather than
  /// snapping to some arbitrary default.
  static double aimAngle(
    EntityStore store,
    int targetIndex,
    double fromX,
    double fromY,
    double currentFacing,
    AimAssist assist,
    double projectileSpeed,
  ) {
    if (targetIndex < 0 || assist == AimAssist.off) return currentFacing;

    double targetX = store.posX[targetIndex];
    double targetY = store.posY[targetIndex];

    if (assist.leads) {
      // First-order lead. A full quadratic intercept solve is unnecessary: over
      // a 0.35 s horizon with enemies under 4 u/s, the error is well inside the
      // arrow's own hitbox.
      final double dx = targetX - fromX;
      final double dy = targetY - fromY;
      final double dist = math.sqrt(dx * dx + dy * dy);
      final double flight =
          projectileSpeed > 0 ? dist / projectileSpeed : leadHorizon;
      final double horizon = flight < leadHorizon ? flight : leadHorizon;
      targetX += store.velX[targetIndex] * horizon;
      targetY += store.velY[targetIndex] * horizon;
    }

    final double ideal =
        math.atan2(targetY - fromY, targetX - fromX);

    if (assist.correction >= 1.0) return ideal;

    // Partial correction, interpolated the short way around the circle so a
    // target directly behind does not sweep the aim through 350 degrees.
    return currentFacing + _shortestAngleDelta(currentFacing, ideal) * assist.correction;
  }

  /// Signed shortest rotation from [from] to [to], in `(-pi, pi]`.
  static double _shortestAngleDelta(double from, double to) {
    double delta = (to - from) % (2 * math.pi);
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta <= -math.pi) delta += 2 * math.pi;
    return delta;
  }

  /// Advances the shot cooldown and reports how many arrows to release.
  ///
  /// Returns the number of shots due this tick, and leaves the remainder in
  /// [cooldown] via the returned value. Accumulator-based rather than
  /// "fire if timer <= 0" so that a very high fire rate (Kestrel's Flurry at
  /// x3) can legitimately produce more than one shot in a single 16.6 ms tick
  /// instead of silently capping at 60 shots per second.
  static int shotsDue(double fireRate, double dt, double cooldown) {
    if (fireRate <= 0) return 0;
    final double interval = 1.0 / fireRate;
    if (cooldown > 0) return 0;
    // cooldown has already gone non-positive; count how many intervals fit.
    return 1 + (-cooldown / interval).floor();
  }

  /// Fire interval for a tier, after any rate modifiers.
  static double intervalFor(DrawTier tier, double fireRateMultiplier) {
    final double rate = tier.fireRate * fireRateMultiplier;
    return rate <= 0 ? double.infinity : 1.0 / rate;
  }
}
