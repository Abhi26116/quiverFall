import 'package:flutter/widgets.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/features/gameplay/application/feel_telemetry.dart';
import 'package:quiverfall/game/sim/world.dart';

/// The combat HUD.
///
/// docs/10 §10.6 sets one hard rule: **at most 12 % of the screen area is UI**,
/// and the bottom 96 dp is a no-UI zone because that is where the left thumb
/// lives. Everything here sits in the top strip for that reason.
///
/// Painted rather than composed from widgets, and repainted from a
/// [Listenable] rather than `setState`. docs/19 §19.1 gives the Flutter HUD
/// 1.0 ms of a 16.6 ms frame with "targeted repaints only" — rebuilding a
/// widget subtree at 60 Hz would spend that on layout before drawing anything.
class CombatHud extends StatelessWidget {
  const CombatHud({
    required this.world,
    required this.repaint,
    this.telemetry,
    this.showTelemetry = false,
    super.key,
  });

  final SimWorld world;
  final Listenable repaint;

  /// Shown only in the playtest build. The gate is measured from these numbers,
  /// and the person running the session needs to read them off the device.
  final FeelTelemetry? telemetry;
  final bool showTelemetry;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: CustomPaint(
          painter: _HudPainter(
            world: world,
            repaint: repaint,
            telemetry: showTelemetry ? telemetry : null,
          ),
        ),
      ),
    );
  }
}

class _HudPainter extends CustomPainter {
  _HudPainter({
    required this.world,
    required Listenable repaint,
    this.telemetry,
  }) : super(repaint: repaint);

  final SimWorld world;
  final FeelTelemetry? telemetry;

  /// The delayed white "damage taken" ghost bar (docs/10 §10.6).
  ///
  /// Static because the painter is rebuilt on every frame while the value has
  /// to survive between them. It is per-run state on a per-frame object, which
  /// is a smell — Phase 15's real HUD pass should own this in a controller.
  static double _ghost = 1.0;
  static double _lastFraction = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double fraction = _playerHealthFraction();

    // The ghost chases the real bar down, slowly. A bar that simply drops tells
    // the player they lost health; a ghost that drains behind it tells them how
    // much, and from what — which is the difference between noticing a hit and
    // understanding it.
    if (fraction < _lastFraction) {
      _ghost = _ghost > fraction ? _ghost : fraction;
    } else {
      _ghost = fraction;
    }
    if (_ghost > fraction) {
      _ghost -= 0.012;
      if (_ghost < fraction) _ghost = fraction;
    }
    _lastFraction = fraction;

    _paintHealth(canvas, size, fraction);
    _paintRoomCounter(canvas, size);

    if (telemetry != null) _paintTelemetry(canvas, size);
  }

  double _playerHealthFraction() {
    if (!world.entities.isAlive(world.player)) return 0;
    final int p = world.player.index;
    final double max = world.entities.maxHealth[p];
    if (max <= 0) return 0;
    return (world.entities.health[p] / max).clamp(0.0, 1.0);
  }

  void _paintHealth(Canvas canvas, Size size, double fraction) {
    const double left = Tokens.space4;
    const double top = Tokens.space3;
    const double height = 6; // 6 dp, per docs/10 §10.6.
    final double width = size.width * 0.42;

    final RRect track = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(3),
    );

    final Paint paint = Paint()..color = Tokens.bgPanel.withOpacity(0.85);
    canvas.drawRRect(track, paint);

    if (_ghost > fraction) {
      paint.color = Tokens.ink.withOpacity(0.55);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width * _ghost, height),
          const Radius.circular(3),
        ),
        paint,
      );
    }

    // Crimson below a quarter: the same threshold the low-HP haptic pulse uses,
    // so the two channels agree.
    paint.color = fraction < 0.25 ? Tokens.danger : Tokens.accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width * fraction, height),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  void _paintRoomCounter(Canvas canvas, Size size) {
    final int alive = _aliveEnemies();
    final String text = alive == 0 ? 'CLEAR' : '$alive';

    _text(
      canvas,
      text,
      Offset(size.width / 2, Tokens.space2),
      colour: alive == 0 ? Tokens.accent : Tokens.inkDim,
      size: 13,
      centred: true,
    );
  }

  int _aliveEnemies() {
    int n = 0;
    for (int i = 0; i < world.entities.highWater; i++) {
      if (world.entities.alive[i] == 0) continue;
      if (world.entities.kind[i] == 1) n++; // EntityKind.enemy
    }
    return n;
  }

  void _paintTelemetry(Canvas canvas, Size size) {
    _text(
      canvas,
      telemetry!.summary(),
      const Offset(Tokens.space4, Tokens.space6 + 8),
      colour: Tokens.inkDim,
      size: 11,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required Color colour,
    required double size,
    bool centred = false,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: colour,
          fontSize: size,
          height: 1.35,
          fontWeight: FontWeight.w600,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, centred ? at - Offset(painter.width / 2, 0) : at);
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _HudPainter oldDelegate) => false;
}
