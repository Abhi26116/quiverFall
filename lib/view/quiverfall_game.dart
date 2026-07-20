import 'dart:ui';

import 'package:flame/game.dart';
import 'package:quiverfall/features/gameplay/application/feel_telemetry.dart';
import 'package:quiverfall/game/feel/cues.dart';
import 'package:quiverfall/game/feel/feedback_director.dart';
import 'package:quiverfall/game/feel/joystick_model.dart';
import 'package:quiverfall/game/sim/fixed_step_driver.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/view/render/world_painter.dart';

/// The arena, as a Flame game.
///
/// Deliberately thin. Flame supplies the game loop, the surface and the
/// lifecycle; it does **not** own any game state, and there is not a single
/// `Component` in here. Everything is drawn in one pass by [WorldPainter]
/// straight out of the simulation's struct-of-arrays.
///
/// That is the right shape for Phase 6 — the roadmap asks for a *minimal*
/// renderer, enough to play — and it is also faster than the component tree
/// would be: docs/19 §19.1 budgets 1.5 ms for "Flame component sync", and
/// reading the arrays directly costs none of it. Phase 7 introduces real
/// components, pools and atlases where they earn their keep.
///
/// **Three loops, three clocks, and they are not the same clock:**
///
///  - The **simulation** advances in fixed 60 Hz steps, always, on every
///    device. Determinism depends on it (docs/12 §12.4).
///  - **Presentation** advances in real time, so particles and screen shake
///    keep animating during a freeze-frame — which is the entire point of a
///    freeze-frame.
///  - **Hit-stop** sits between them, withholding real time from the
///    simulation without ever scaling its step.
class QuiverfallGame extends FlameGame {
  QuiverfallGame({
    required this.sim,
    FeedbackDirector? director,
    List<CueSink>? sinks,
    FeelTelemetry? telemetry,
  })  : director = director ?? FeedbackDirector(world: sim),
        sinks = sinks ?? <CueSink>[],
        telemetry = telemetry ?? FeelTelemetry() {
    painter = WorldPainter(world: sim, director: this.director);
    driver = FixedStepDriver(sim, onTick: _afterTick);
  }

  /// The simulation.
  ///
  /// Named `sim` rather than `world` because [FlameGame] already has a `world`
  /// — its root component container — and the two are entirely different
  /// things. Shadowing it would compile in some places and silently mean the
  /// wrong object in others.
  final SimWorld sim;
  final FeedbackDirector director;

  /// Haptics and audio. Empty is a valid configuration — the game plays fine
  /// with neither, which is what lets the renderer ship before the sound does.
  final List<CueSink> sinks;

  /// What the Phase 6 gate is measured from.
  final FeelTelemetry telemetry;

  late final WorldPainter painter;
  late final FixedStepDriver driver;

  /// The joystick's model. The widget layer feeds it pointer events; this is
  /// the only place its output becomes simulation input.
  final JoystickModel joystick = JoystickModel();

  /// Reused every tick. Allocating an input object 60 times a second is exactly
  /// the steady-state garbage docs/19 §19.2 forbids.
  final InputSnapshot _input = InputSnapshot();

  /// Set while a pause sheet or a Boon choice is up.
  bool halted = false;

  /// Simulation steps taken on the most recent frame. Surfaced for the on-device
  /// bench overlay.
  int get stepsLastFrame => driver.stepsLastFrame;

  @override
  Color backgroundColor() => const Color(0xFF080B12);

  @override
  void update(double dt) {
    super.update(dt);

    // Presentation runs regardless — a frozen frame still animates.
    director.update(dt);

    if (halted) return;

    // Hit-stop withholds whole ticks. It never scales dt: a variable step would
    // make the same seed and inputs produce a different run, silently
    // invalidating every replay and the balance harness with them.
    final double simDt = director.hitStop.consume(dt);
    if (simDt <= 0) return;

    _input.set(joystick.outputX, joystick.outputY);
    driver.advance(simDt, _input);

    // Once per frame, not per tick: a frame containing two steps must not ring
    // the same bell twice, and 16 ms is beneath perception anyway.
    dispatchCues(director.cues, sinks);
  }

  /// Runs after every simulation step, from inside the driver's catch-up loop.
  void _afterTick() {
    director.drainEvents();
    telemetry.recordTick(sim);
    sim.events.clear();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    painter.paint(canvas, Size(size.x, size.y));
  }
}
