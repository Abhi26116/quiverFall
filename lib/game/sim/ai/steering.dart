import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/sim_config.dart';

/// Movement primitives shared by every behaviour tree.
///
/// These write **velocity**, never position. [MovementSystem] integrates and
/// resolves walls a step later, so an enemy that steers into a wall slides
/// along it for free and no behaviour tree has to know geometry exists.
///
/// Separation is folded into the seek rather than applied as a second pass.
/// A pack converging on the player is the intended behaviour of half the
/// roster, and without separation the whole pack collapses into one silhouette
/// — which is a readability failure long before it is a physics one.
abstract final class Steering {
  /// Effective move speed, after every multiplier that can touch it.
  static double speedOf(AiContext ctx, int slot, EnemyDefinition def) {
    double speed = def.speed * ctx.enemies.speedScale[slot];
    if (ctx.enemies.slowRemaining[slot] > 0) {
      speed *= 1.0 - SimConfig.windlineSlow;
    }
    return speed;
  }

  static void halt(AiContext ctx, int slot) {
    ctx.entities.velX[slot] = 0;
    ctx.entities.velY[slot] = 0;
  }

  /// Steers toward a point, spreading against nearby allies.
  static void moveToward(
    AiContext ctx,
    int slot,
    double toX,
    double toY,
    double speed, {
    bool separate = true,
  }) {
    double dx = toX - ctx.entities.posX[slot];
    double dy = toY - ctx.entities.posY[slot];
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len > 1e-9) {
      dx /= len;
      dy /= len;
    } else {
      dx = 0;
      dy = 0;
    }

    if (separate) {
      const double sepScale = EnemyTuning.separationWeight;
      final double radius =
          ctx.entities.radius[slot] * EnemyTuning.separationRadiusScale;
      final int found = ctx.spatial.queryRadius(
        ctx.entities.posX[slot],
        ctx.entities.posY[slot],
        radius,
      );
      for (int i = 0; i < found; i++) {
        final int other = ctx.spatial.resultAt(i);
        if (other == slot) continue;
        if (ctx.entities.alive[other] == 0) continue;
        if (ctx.entities.kind[other] != EntityKind.enemy.index) continue;

        final double ox = ctx.entities.posX[slot] - ctx.entities.posX[other];
        final double oy = ctx.entities.posY[slot] - ctx.entities.posY[other];
        final double distSq = ox * ox + oy * oy;
        if (distSq >= radius * radius || distSq <= 1e-9) continue;

        // Inverse-linear falloff: firm at contact, gone at the radius. A
        // constant push makes a crowd vibrate; an inverse-square one launches
        // overlapping spawns across the arena.
        final double dist = math.sqrt(distSq);
        final double push = (1.0 - dist / radius) * sepScale;
        dx += ox / dist * push;
        dy += oy / dist * push;
      }
    }

    _applyVelocity(ctx, slot, dx, dy, speed);
  }

  /// Steers directly away from a point. Kiters and Choir units retreat with
  /// this; separation is deliberately off, because a fleeing unit spreading
  /// against its allies walks itself into the player.
  static void moveAway(
    AiContext ctx,
    int slot,
    double fromX,
    double fromY,
    double speed,
  ) {
    final double dx = ctx.entities.posX[slot] - fromX;
    final double dy = ctx.entities.posY[slot] - fromY;
    _applyVelocity(ctx, slot, dx, dy, speed);
  }

  /// Holds a stand-off band around a point, strafing when already inside it.
  ///
  /// The tolerance band is what stops a kiter jittering forward and back on the
  /// exact boundary — which looks broken and, worse, makes its range unreadable.
  static void holdRange(
    AiContext ctx,
    int slot,
    double atX,
    double atY,
    double desired,
    double speed, {
    double strafe = 0,
  }) {
    final double dx = ctx.entities.posX[slot] - atX;
    final double dy = ctx.entities.posY[slot] - atY;
    final double dist = math.sqrt(dx * dx + dy * dy);
    const double eps = 1e-9;

    if (dist < desired - EnemyTuning.keepDistanceTolerance) {
      _applyVelocity(ctx, slot, dx, dy, speed);
      return;
    }
    if (dist > desired + EnemyTuning.keepDistanceTolerance) {
      _applyVelocity(ctx, slot, -dx, -dy, speed);
      return;
    }
    if (strafe == 0 || dist <= eps) {
      halt(ctx, slot);
      return;
    }

    // Perpendicular, so the unit slides around its target rather than in or out.
    _applyVelocity(ctx, slot, -dy / dist * strafe, dx / dist * strafe, speed);
  }

  /// Circles a point at a fixed radius, biased [towardAngle].
  ///
  /// Used by the Stalker, which is always trying to reach the player's rear
  /// 120 degrees. Turning to face it is the entire counter-play, so the orbit
  /// has to be a real, readable slide rather than a teleport.
  static void orbit(
    AiContext ctx,
    int slot,
    double centreX,
    double centreY,
    double radius,
    double speed,
    double towardAngle,
  ) {
    final double px = ctx.entities.posX[slot];
    final double py = ctx.entities.posY[slot];
    final double current = math.atan2(py - centreY, px - centreX);
    final double delta = shortestAngleDelta(current, towardAngle);
    final double direction = delta >= 0 ? 1.0 : -1.0;

    final double dist = math.sqrt(
      (px - centreX) * (px - centreX) + (py - centreY) * (py - centreY),
    );

    // Radial correction plus tangential travel, combined into one vector so the
    // unit spirals onto its ring instead of snapping to it.
    final double radialError = (radius - dist) / radius;
    final double rx = math.cos(current);
    final double ry = math.sin(current);
    final double tx = -ry * direction;
    final double ty = rx * direction;

    _applyVelocity(
      ctx,
      slot,
      tx * EnemyTuning.stalkerOrbitBias - rx * radialError,
      ty * EnemyTuning.stalkerOrbitBias - ry * radialError,
      speed,
    );
  }

  /// Turns toward a point, capped at [turnRateDegrees] per second.
  ///
  /// A zero rate turns instantly. A finite one is a *weakness* wherever it is
  /// set: it is exactly what makes flanking a Bulwark or a Screecher work.
  static void faceToward(
    AiContext ctx,
    int slot,
    double toX,
    double toY,
    double turnRateDegrees,
  ) {
    final double desired = math.atan2(
      toY - ctx.entities.posY[slot],
      toX - ctx.entities.posX[slot],
    );

    if (turnRateDegrees <= 0) {
      ctx.entities.facing[slot] = desired;
      return;
    }

    final double maxStep = turnRateDegrees * _degreesToRadians * ctx.dt;
    final double delta = shortestAngleDelta(ctx.entities.facing[slot], desired);
    if (delta.abs() <= maxStep) {
      ctx.entities.facing[slot] = desired;
      return;
    }
    ctx.entities.facing[slot] += delta.isNegative ? -maxStep : maxStep;
  }

  /// Signed shortest rotation from [from] to [to], in `(-pi, pi]`.
  static double shortestAngleDelta(double from, double to) {
    double delta = (to - from) % (2 * math.pi);
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta <= -math.pi) delta += 2 * math.pi;
    return delta;
  }

  /// True if [px],[py] lies inside a cone of [halfAngle] about [facing],
  /// centred on [x],[y], out to [range].
  static bool insideCone(
    double x,
    double y,
    double facing,
    double halfAngle,
    double range,
    double px,
    double py,
  ) {
    final double dx = px - x;
    final double dy = py - y;
    final double distSq = dx * dx + dy * dy;
    if (distSq > range * range) return false;
    if (distSq <= 1e-12) return true;
    return shortestAngleDelta(facing, math.atan2(dy, dx)).abs() <= halfAngle;
  }

  static const double _degreesToRadians = math.pi / 180.0;

  static double toRadians(double degrees) => degrees * _degreesToRadians;

  static void _applyVelocity(
    AiContext ctx,
    int slot,
    double dx,
    double dy,
    double speed,
  ) {
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len <= 1e-9 || speed <= 0) {
      halt(ctx, slot);
      return;
    }
    ctx.entities.velX[slot] = dx / len * speed;
    ctx.entities.velY[slot] = dy / len * speed;
  }
}
