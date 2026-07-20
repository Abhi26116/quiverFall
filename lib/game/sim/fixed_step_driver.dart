import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';

/// Converts variable real frame times into fixed simulation steps.
///
/// The render layer calls [advance] with whatever `dt` the vsync gave it; the
/// simulation only ever sees [SimConfig.fixedStep]. Between steps, the view
/// interpolates by [alpha], so a 120 Hz device renders smooth intermediate
/// frames of a 60 Hz simulation rather than simulating at 120 Hz and producing
/// a different game.
///
/// Three properties this buys, all from docs/12-architecture.md §12.4:
///
///  - **Determinism.** Identical seed + identical inputs = identical run, on
///    every device, at every frame rate.
///  - **No death spiral.** Catch-up is capped; a struggling device runs in slow
///    motion instead of falling further behind each frame.
///  - **No stall simulation.** A frame longer than [SimConfig.maxFrameDelta]
///    (backgrounded app, attached debugger) is clamped, so returning to the app
///    does not simulate the thirty seconds you were away in one frame.
class FixedStepDriver {
  FixedStepDriver(this.world, {this.onTick});

  final SimWorld world;

  /// Called after every simulation step, before the next one runs.
  ///
  /// The presentation layer has to drain [SimWorld.events] *per tick*, not per
  /// frame: a frame may contain two steps, and several events describe state
  /// the following step overwrites — an arrow's Confluence stacks, a dying
  /// enemy's position. Held as a field rather than passed to [advance] so the
  /// hot loop does not allocate a closure every frame.
  final void Function()? onTick;

  double _accumulator = 0;
  int _lastTickCount = 0;

  /// Fraction of the way to the next simulation step, in `[0, 1)`.
  ///
  /// The view multiplies this into its position interpolation. Without it,
  /// motion visibly stutters on any device whose refresh rate is not exactly
  /// 60 Hz — which is most of them.
  double get alpha => _accumulator / SimConfig.fixedStep;

  /// Simulation steps executed by the most recent [advance].
  int get stepsLastFrame => world.tickCount - _lastTickCount;

  /// True when the driver hit its catch-up cap and is now behind real time.
  bool get isBehind => _accumulator > SimConfig.fixedStep * 2;

  /// Advances the world to cover [realDt] seconds of wall time.
  ///
  /// Returns the number of steps taken.
  int advance(double realDt, InputSnapshot input) {
    _lastTickCount = world.tickCount;

    double dt = realDt;
    if (dt > SimConfig.maxFrameDelta) dt = SimConfig.maxFrameDelta;
    if (dt < 0) dt = 0;

    _accumulator += dt;

    int steps = 0;
    while (_accumulator >= SimConfig.fixedStep &&
        steps < SimConfig.maxCatchUpTicks) {
      world.tick(input);
      onTick?.call();
      _accumulator -= SimConfig.fixedStep;
      steps++;
    }

    if (steps == SimConfig.maxCatchUpTicks &&
        _accumulator >= SimConfig.fixedStep) {
      // Cap reached and still behind. Drop the backlog rather than carrying it:
      // carrying it guarantees the next frame is over budget too, which is how
      // a single hitch becomes a permanent stutter.
      _accumulator = _accumulator % SimConfig.fixedStep;
    }

    return steps;
  }

  void reset() {
    _accumulator = 0;
    _lastTickCount = world.tickCount;
  }
}
