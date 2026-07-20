import 'package:quiverfall/game/sim/sim_config.dart';

/// One tick's worth of player input.
///
/// A plain value with no Flutter types, so the simulation can be driven equally
/// by a real joystick, by a recorded input tape during replay, or by a scripted
/// bot in the balance harness. That substitutability is the whole reason the
/// sim takes input as data rather than reading a gesture recogniser.
///
/// Mutable and reused: the game loop owns exactly one instance and overwrites it
/// each tick, because allocating a fresh input object 60 times a second is
/// precisely the steady-state allocation docs/19-performance.md §19.2 forbids.
class InputSnapshot {
  double stickX = 0;
  double stickY = 0;
  bool ultimatePressed = false;

  /// True on the tick a dash gesture was recognised.
  ///
  /// *Dash* (#49) says "double-tap the stick", but double-tap detection is a
  /// gesture question for whatever produces this snapshot — a touch layer, a
  /// recorded tape, or a scripted bot — not a simulation question. The
  /// simulation's contract is only this flag: true for exactly one tick means
  /// exactly one dash attempt, regardless of what recognised the gesture.
  bool dashRequested = false;

  /// Squared magnitude of stick deflection. Squared to avoid a sqrt on a value
  /// that is only ever compared against a threshold.
  double get magnitudeSquared => stickX * stickX + stickY * stickY;

  /// True when the stick is deflected past the dead zone.
  ///
  /// This is the single most consequential boolean in the game: it decides
  /// whether the player is Drawing (stationary, damage ramps) or building
  /// Momentum (moving, speed and mitigation ramp). See docs/01-vision.md §1.1.
  bool get isMoving =>
      magnitudeSquared > SimConfig.stickDeadZone * SimConfig.stickDeadZone;

  void set(double x, double y, {bool ultimate = false, bool dash = false}) {
    stickX = x;
    stickY = y;
    ultimatePressed = ultimate;
    dashRequested = dash;
  }

  void clear() {
    stickX = 0;
    stickY = 0;
    ultimatePressed = false;
    dashRequested = false;
  }

  void copyFrom(InputSnapshot other) {
    stickX = other.stickX;
    stickY = other.stickY;
    ultimatePressed = other.ultimatePressed;
    dashRequested = other.dashRequested;
  }

  /// Quantises to a single byte for the replay input tape.
  ///
  /// 4 bits per axis (16 levels) plus the ultimate flag. Coarse on purpose:
  /// a full run's tape must stay small enough to sit inside the ~2 KB room
  /// snapshot, and 16 deflection levels is finer than a thumb can reliably
  /// hit on a 5.5" screen. Quantising on *record* also means playback receives
  /// exactly what was recorded, so a replay cannot desync from rounding.
  int toTapeByte() {
    final int qx = _quantise(stickX);
    final int qy = _quantise(stickY);
    return (qx << 4) | qy;
  }

  void fromTapeByte(int byte, {bool ultimate = false}) {
    stickX = _dequantise((byte >> 4) & 0xF);
    stickY = _dequantise(byte & 0xF);
    ultimatePressed = ultimate;
  }

  static int _quantise(double v) {
    final double clamped = v < -1 ? -1 : (v > 1 ? 1 : v);
    return (((clamped + 1) * 0.5) * 15).round() & 0xF;
  }

  static double _dequantise(int q) => (q / 15) * 2 - 1;
}
