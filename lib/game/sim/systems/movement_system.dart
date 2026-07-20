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

      final double vx = store.velX[i];
      final double vy = store.velY[i];
      if (vx == 0 && vy == 0) continue;

      final double r = store.radius[i];

      // Axis-separated: attempt X, then Y. Sliding along a wall falls out of
      // this for free — a blocked X does not cancel a legal Y.
      double x = store.posX[i];
      double y = store.posY[i];

      final double nextX = x + vx * dt;
      if (!_blocked(arena, nextX, y, r)) {
        x = nextX;
      }

      final double nextY = y + vy * dt;
      if (!_blocked(arena, x, nextY, r)) {
        y = nextY;
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

  static bool _blocked(Arena arena, double x, double y, double r) =>
      arena.circleHitsWall(x, y, r);
}
