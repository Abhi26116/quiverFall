import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/arena.dart';
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
    // *Tangle* (#63) and *Sunthread* (#73) deepen the Windline slow. Recomputed
    // every tick by the Windline field pass, so it lapses the moment the enemy
    // steps off the line and needs no timer of its own.
    speed *= ctx.enemies.windlineSlowFactor[slot];
    // Sela's own *Lingering Frost* (T3b) — a slow entirely independent of
    // any live Windline, so it stacks as its own separate multiplier
    // rather than folding into either field above.
    if (ctx.enemies.lingeringFrostSlowRemaining[slot] > 0) {
      speed *= 1.0 - EnemyTuning.lingeringFrostSlow;
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

    // Route around a wall standing between here and the goal.
    //
    // There is no pathfinding in this game and there should not be: arenas are
    // one screen with a handful of convex blocks, and A* would be a large,
    // allocating system to solve a problem that is two probes wide. But a pure
    // seek has local minima — a body pressed flat against a wall, with the goal
    // directly beyond it, has nowhere to go and stays there for the rest of the
    // room, which deadlocks the stage behind it.
    //
    // So: if the straight line is blocked, aim past whichever *edge of the
    // blocking wall* leaves the shorter total trip. That is a goal-directed
    // choice, which is why it lives here and not in collision resolution, and
    // it terminates because the edge is a fixed point rather than a direction
    // that flips as the target moves.
    final (double, double)? detour = _detourAround(ctx, slot, toX, toY);
    if (detour != null) {
      dx = detour.$1 - ctx.entities.posX[slot];
      dy = detour.$2 - ctx.entities.posY[slot];
      final double len2 = math.sqrt(dx * dx + dy * dy);
      if (len2 > 1e-9) {
        dx /= len2;
        dy /= len2;
      }
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
      // Closing, so it needs the same wall avoidance a seeking enemy gets. A
      // Salvo unit that cannot find its way round a pillar simply never enters
      // the fight, and the room waits for it forever.
      seekDirection(ctx, slot, atX, atY);
      _applyVelocity(ctx, slot, dirX, dirY, speed);
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
    //
    // **The sign here is load-bearing.** `radialError` is negative when the
    // unit is outside its ring, and `rx`/`ry` point *away* from the centre, so
    // the radial term must be added: a negative error times an outward vector
    // is inward travel. Subtracting it — which reads just as plausibly — makes
    // a unit that starts outside its ring accelerate away from the player and
    // pin itself in a corner forever, which is exactly what a Stalker spawned
    // at an arena edge did.
    final double radialError = (radius - dist) / radius;
    final double rx = math.cos(current);
    final double ry = math.sin(current);
    final double tx = -ry * direction;
    final double ty = rx * direction;

    _applyVelocity(
      ctx,
      slot,
      tx * EnemyTuning.stalkerOrbitBias + rx * radialError,
      ty * EnemyTuning.stalkerOrbitBias + ry * radialError,
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

  /// The unit direction to travel to reach a goal, routed around any wall in
  /// the way.
  ///
  /// Exposed because not every behaviour steers through [moveToward] — the
  /// Swarmling's flocking builds its own vector — and an enemy without
  /// avoidance is an enemy that can wedge itself behind a wall and stall the
  /// room. Writes the result to [dirX] / [dirY].
  static void seekDirection(
    AiContext ctx,
    int slot,
    double toX,
    double toY,
  ) {
    double gx = toX;
    double gy = toY;

    final (double, double)? detour = _detourAround(ctx, slot, toX, toY);
    if (detour != null) {
      gx = detour.$1;
      gy = detour.$2;
    }

    double dx = gx - ctx.entities.posX[slot];
    double dy = gy - ctx.entities.posY[slot];
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len > 1e-9) {
      dx /= len;
      dy /= len;
    } else {
      dx = 0;
      dy = 0;
    }
    dirX = dx;
    dirY = dy;
  }

  /// Result of the last [seekDirection]. Static scratch rather than a returned
  /// record, for the same reason the rest of the simulation avoids them: this
  /// runs once per enemy per tick and must not allocate.
  static double dirX = 0;
  static double dirY = 0;

  /// A point to aim at instead of the goal, when a wall is in the way.
  ///
  /// Returns null when the straight line is clear, which is the common case and
  /// costs one loop over a handful of walls.
  static (double, double)? _detourAround(
    AiContext ctx,
    int slot,
    double toX,
    double toY,
  ) {
    final Arena arena = ctx.arena;
    if (arena.wallCount == 0) return null;

    final double x = ctx.entities.posX[slot];
    final double y = ctx.entities.posY[slot];
    final double r = ctx.entities.radius[slot];

    final int wall = _wallOnPath(arena, x, y, toX, toY, r);
    if (wall < 0) return null;

    // Four ways past a box. Aim just outside the corner nearest each edge,
    // and take whichever makes the whole journey shortest.
    final double pad = r + _detourPad;
    final double left = arena.wallLeft(wall) - pad;
    final double right = arena.wallRight(wall) + pad;
    final double top = arena.wallTop(wall) - pad;
    final double bottom = arena.wallBottom(wall) + pad;

    double bestX = 0;
    double bestY = 0;
    double bestCost = double.infinity;

    void consider(double cx, double cy) {
      if (cx < r || cy < r || cx > arena.width - r || cy > arena.height - r) {
        return;
      }
      if (arena.circleHitsWall(cx, cy, r)) return;

      final double toCorner =
          math.sqrt((cx - x) * (cx - x) + (cy - y) * (cy - y));
      final double onward =
          math.sqrt((toX - cx) * (toX - cx) + (toY - cy) * (toY - cy));
      final double cost = toCorner + onward;
      if (cost < bestCost) {
        bestCost = cost;
        bestX = cx;
        bestY = cy;
      }
    }

    consider(left, top);
    consider(left, bottom);
    consider(right, top);
    consider(right, bottom);

    return bestCost.isFinite ? (bestX, bestY) : null;
  }

  /// The first wall a straight line from here to the goal would hit, or -1.
  ///
  /// Sampled rather than solved. A handful of points along a line inside a
  /// one-screen arena is cheaper than an exact segment-versus-box test and is
  /// wrong only for walls thinner than the sample spacing — which no authored
  /// arena has, because a wall thinner than a body is not a wall.
  static int _wallOnPath(
    Arena arena,
    double x,
    double y,
    double toX,
    double toY,
    double r,
  ) {
    final double dx = toX - x;
    final double dy = toY - y;
    final double distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= 1e-6) return -1;

    final int steps = (distance / _pathSampleStep).ceil().clamp(1, 48);
    for (int i = 1; i <= steps; i++) {
      final double t = i / steps;
      final int wall = arena.wallHitBy(x + dx * t, y + dy * t, r);
      if (wall >= 0) return wall;
    }
    return -1;
  }

  /// Clearance beyond a wall corner when aiming past it. Enough that the body
  /// rounds the corner instead of grazing it and re-blocking.
  static const double _detourPad = 0.30;

  static const double _pathSampleStep = 0.35;

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
