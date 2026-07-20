import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/entity.dart';

/// Integrates velocity into position and resolves arena collision.
///
/// Deliberately simple: semi-implicit Euler with axis-separated wall
/// resolution. No solver, no substepping, no restitution.
///
/// That is a design decision, not a shortcut. At 60 Hz with a top speed around
/// 8 u/s (a charging Lancer), the largest per-tick step is ~0.13 u against a
/// 0.35 u radius, so tunnelling is impossible and a more elaborate integrator
/// would buy nothing a player could feel. What players *can* feel is sliding
/// smoothly along a wall instead of sticking to it, which is what the
/// axis-separated resolution below provides.
abstract final class MovementSystem {
  /// Advances every live entity by [dt].
  static void update(EntityStore store, Arena arena, double dt) {
    final int high = store.highWater;

    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;

      // Projectiles are moved by [ProjectileSystem], which sweeps their path
      // against enemies and walls rather than stepping them and asking
      // afterwards. Integrating them here as well advanced every arrow twice
      // per tick — they flew at double the configured speed from Phase 3 until
      // this was found in Phase 8, which is why `projectileSpeed` reads low.
      if (store.kind[i] == EntityKind.projectile.index) continue;

      final double vx = store.velX[i];
      final double vy = store.velY[i];
      if (vx == 0 && vy == 0) continue;

      final double r = store.radius[i];

      // Axis-separated: attempt X, then Y. A blocked X does not cancel a legal
      // Y, which is what makes sliding along a wall possible at all.
      double x = store.posX[i];
      double y = store.posY[i];

      final double stepX = vx * dt;
      final double stepY = vy * dt;

      final bool freeX = !_blocked(arena, x + stepX, y, r);
      final bool freeY = !_blocked(arena, x, y + stepY, r);

      if (freeX && freeY) {
        x += stepX;
        y += stepY;
      } else if (freeX || freeY) {
        // **Blocked on one axis: slide along the wall at full speed.**
        //
        // Taking only the free axis's *residual* looks correct and is not. A
        // body pressed flat against a wall, heading almost straight into it,
        // has a free-axis component near zero — so it creeps along at a few
        // centimetres a second. Spending the blocked axis's speed on the free
        // one makes it travel *along* a wall as fast as it was travelling into
        // it, which is better feel for the player and unsticks the AI.
        //
        // Which *way* to slide is deliberately not decided here. This system
        // resolves collisions; it does not know where anything is trying to go,
        // and guessing produced exactly the bug it was meant to fix — enemies
        // routed neatly around a wall and away from the player. Choosing a way
        // round is [Steering.moveToward]'s job, because that is where the goal
        // is known.
        final double speed = _length(stepX, stepY);
        if (freeX) {
          final double slide = stepX >= 0 ? speed : -speed;
          x += !_blocked(arena, x + slide, y, r) ? slide : stepX;
        } else {
          final double slide = stepY >= 0 ? speed : -speed;
          y += !_blocked(arena, x, y + slide, r) ? slide : stepY;
        }
      } else {
        // **Cornered: both axes blocked.**
        //
        // Doing nothing here is what froze enemies permanently against wall
        // corners — and a room with one frozen enemy never clears, which
        // deadlocks the whole stage behind it. A body wedged in a corner has to
        // be given *some* way out.
        //
        // Four candidates at full speed, in order of preference: the way it
        // wanted to go, then the other axis, then the reverses. The first free
        // one wins. Bounded, deterministic, and it cannot fail to escape a
        // corner that has any opening at all.
        final double speed = _length(stepX, stepY);
        if (speed > 0) {
          final double px = stepX >= 0 ? speed : -speed;
          final double py = stepY >= 0 ? speed : -speed;

          if (!_blocked(arena, x + px, y, r)) {
            x += px;
          } else if (!_blocked(arena, x, y + py, r)) {
            y += py;
          } else if (!_blocked(arena, x - px, y, r)) {
            x -= px;
          } else if (!_blocked(arena, x, y - py, r)) {
            y -= py;
          }
        }
      }

      // Arena bounds. Clamping rather than blocking, so an entity pushed out by
      // a knockback or a spawn overlap is returned to the playfield instead of
      // being stranded outside it.
      if (x < r) x = r;
      if (y < r) y = r;
      if (x > arena.width - r) x = arena.width - r;
      if (y > arena.height - r) y = arena.height - r;

      store.posX[i] = x;
      store.posY[i] = y;
    }
  }

  /// True if a body of radius [r] may not occupy this point.
  ///
  /// **Includes the arena boundary, not just walls.** Without that, a body
  /// against the top edge reads its next step as legal, moves, and is clamped
  /// straight back — burning its one escape attempt every tick and never
  /// leaving the edge. That froze a Swarmling wedged between the boundary and a
  /// wall for the entire run.
  static bool _blocked(Arena arena, double x, double y, double r) {
    if (x < r || y < r || x > arena.width - r || y > arena.height - r) {
      return true;
    }
    return arena.circleHitsWall(x, y, r);
  }

  /// Newton's method rather than `dart:math`, so the result is bit-identical
  /// across platforms and the simulation stays deterministic.
  static double _length(double x, double y) {
    final double sq = x * x + y * y;
    if (sq == 0) return 0;
    double g = sq > 1 ? sq : 1.0;
    for (int i = 0; i < 20; i++) {
      g = 0.5 * (g + sq / g);
    }
    return g;
  }
}
