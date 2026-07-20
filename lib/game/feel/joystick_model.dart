import 'dart:math' as math;

import 'package:quiverfall/game/feel/juice.dart';

/// The floating joystick, as maths.
///
/// docs/10 §10.6: it appears wherever the left thumb lands in the bottom-left
/// of the screen, has an 8 dp dead zone and full deflection at 48 dp, and is
/// invisible until touched.
///
/// Pure Dart, with no gesture types anywhere near it, for two reasons. It is
/// the most feel-critical code in the game after the Draw itself — the boolean
/// this produces decides whether the player is Drawing or building Momentum
/// every single frame — and testing "does a 6 dp thumb wobble cancel my Tier
/// III" should not require pumping a widget tree.
///
/// Coordinates are logical pixels in screen space, so **y grows downward**.
/// The sim's arena also has y growing downward, so no flip is needed anywhere;
/// this comment exists because that is a coincidence worth stating rather than
/// rediscovering.
class JoystickModel {
  /// Where the thumb first landed. Null when the stick is untouched, which is
  /// also when it is invisible.
  double? _originX;
  double? _originY;

  double _thumbX = 0;
  double _thumbY = 0;

  double _outX = 0;
  double _outY = 0;

  bool get isActive => _originX != null;

  double get originX => _originX ?? 0;

  double get originY => _originY ?? 0;

  double get thumbX => _thumbX;

  double get thumbY => _thumbY;

  /// Deflection in `[-1, 1]`, after the dead zone and the response curve.
  double get outputX => _outX;

  double get outputY => _outY;

  /// Magnitude of the output vector, in `[0, 1]`. Drives the visual ring fill.
  double get magnitude => math.sqrt(_outX * _outX + _outY * _outY);

  /// True if a touch at this point should claim the joystick rather than the
  /// UI beneath it.
  ///
  /// The zone is generous because a thumb reaching for "somewhere down there"
  /// must never instead press a button. docs/10 §10.0 reserves the bottom 96 dp
  /// of the gameplay screen as a no-UI zone for exactly this reason.
  static bool claims(
    double x,
    double y,
    double screenWidth,
    double screenHeight, {
    bool leftHanded = false,
  }) {
    final double zoneW = screenWidth * Juice.joystickZoneWidth;
    final double zoneH = screenHeight * Juice.joystickZoneHeight;

    if (y < screenHeight - zoneH) return false;
    // Left-handed mode mirrors the HUD (docs/10 §10.0), and the stick with it.
    return leftHanded ? x >= screenWidth - zoneW : x <= zoneW;
  }

  void begin(double x, double y) {
    _originX = x;
    _originY = y;
    _thumbX = x;
    _thumbY = y;
    _outX = 0;
    _outY = 0;
  }

  void drag(double x, double y) {
    if (_originX == null) return;

    _thumbX = x;
    _thumbY = y;

    double dx = x - _originX!;
    double dy = y - _originY!;
    final double distance = math.sqrt(dx * dx + dy * dy);

    if (distance <= Juice.joystickDeadZoneDp) {
      // Inside the dead zone the stick reads as centred — which means the
      // player is *stationary*, which means their Draw is ramping. A resting
      // thumb must never quietly cancel a Tier III.
      _outX = 0;
      _outY = 0;
      return;
    }

    if (Juice.joystickOriginFollows &&
        distance > Juice.joystickFullDeflectionDp) {
      // Drag the origin along behind the thumb, so a long strafe never runs out
      // of stick halfway through.
      //
      // The cost is reversal distance: with a trailing origin, flicking the
      // other way takes up to two deflection-widths of travel before the stick
      // reads negative. That is the standard trade for a floating stick and it
      // is the first thing to re-examine if playtesters report the character
      // feeling slow to turn around.
      final double excess = distance - Juice.joystickFullDeflectionDp;
      _originX = _originX! + dx / distance * excess;
      _originY = _originY! + dy / distance * excess;
      dx = x - _originX!;
      dy = y - _originY!;
    }

    final double live = math.sqrt(dx * dx + dy * dy);
    if (live <= 1e-6) {
      _outX = 0;
      _outY = 0;
      return;
    }

    // Rescale so the dead zone's edge is zero output rather than a jump to
    // 8/48ths. Without this the stick snaps to ~17 % the instant it leaves the
    // dead zone, which feels like a loose connection.
    const double span =
        Juice.joystickFullDeflectionDp - Juice.joystickDeadZoneDp;
    double t = (live - Juice.joystickDeadZoneDp) / span;
    if (t > 1) t = 1;

    // Response curve: finer control near the centre, so small repositioning
    // nudges are possible without giving up full-speed strafes.
    final double shaped = math.pow(t, Juice.joystickCurve).toDouble();

    _outX = dx / live * shaped;
    _outY = dy / live * shaped;
  }

  void end() {
    _originX = null;
    _originY = null;
    _outX = 0;
    _outY = 0;
  }
}
