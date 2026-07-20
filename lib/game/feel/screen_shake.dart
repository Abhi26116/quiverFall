import 'dart:math' as math;

import 'package:quiverfall/game/feel/juice.dart';

/// Trauma-based screen shake and camera punch.
///
/// **Trauma, not offset.** Events add *trauma* in `[0, 1]`; the shake applied is
/// proportional to trauma **squared**. That non-linearity is the whole trick:
/// with a linear model every small event produces a visible nudge and the
/// screen never sits still, so nothing reads as impactful. Squared, a kill is
/// almost imperceptible and a Confluence detonation blooms.
///
/// Pure Dart and driven by an explicit clock, so a playtest can assert "a kill
/// shakes less than taking a hit" without rendering a frame.
///
/// Shake is disabled wholesale by the Reduce Motion accessibility setting
/// (docs/10 §10.0), which is why [enabled] is a field rather than a caller's
/// responsibility — one flag, checked in one place.
class ScreenShake {
  ScreenShake({this.enabled = true, int seed = 0x5EED})
      : _noiseSeedX = seed,
        _noiseSeedY = seed * 2654435761 & 0x7FFFFFFF,
        _noiseSeedRoll = seed * 40503 & 0x7FFFFFFF;

  /// Reduce Motion turns this off entirely — not down.
  bool enabled;

  final int _noiseSeedX;
  final int _noiseSeedY;
  final int _noiseSeedRoll;

  double _trauma = 0;
  double _elapsed = 0;

  /// Zoom impulse, as a fraction of base zoom. Decays independently of trauma
  /// because a punch is a single push-and-return, not a vibration.
  double _punch = 0;

  double get trauma => _trauma;

  /// Current camera offset in world units.
  double get offsetX =>
      _shakeAmount * Juice.shakeMaxOffset * _noise(_noiseSeedX);

  double get offsetY =>
      _shakeAmount * Juice.shakeMaxOffset * _noise(_noiseSeedY);

  /// Current camera roll in radians.
  double get roll => _shakeAmount * Juice.shakeMaxRoll * _noise(_noiseSeedRoll);

  /// Zoom multiplier to apply to the camera. 1.0 when at rest.
  ///
  /// Punches zoom *in*, which reads as the world flinching toward the player;
  /// zooming out reads as the player being pushed away, which is the wrong
  /// story for a hit they just landed.
  double get zoomScale => 1.0 + _punch;

  bool get isActive => _trauma > 0 || _punch.abs() > 1e-4;

  /// Squared trauma, which is what actually drives the amplitude.
  double get _shakeAmount {
    if (!enabled) return 0;
    return _trauma * _trauma;
  }

  void addTrauma(double amount) {
    if (!enabled || amount <= 0) return;
    _trauma += amount;
    if (_trauma > Juice.maxTrauma) _trauma = Juice.maxTrauma;
  }

  void punch(double amount) {
    if (!enabled || amount <= 0) return;
    // Largest wins rather than summing: two impacts in one tick are one flinch.
    if (amount > _punch) _punch = amount;
  }

  void update(double dt) {
    _elapsed += dt;

    if (_trauma > 0) {
      _trauma -= dt / Juice.shakeDecaySeconds;
      if (_trauma < 0) _trauma = 0;
    }

    if (_punch.abs() > 1e-4) {
      _punch -= _punch * (dt / Juice.punchRecoverySeconds);
      if (_punch.abs() <= 1e-4) _punch = 0;
    }
  }

  void reset() {
    _trauma = 0;
    _punch = 0;
    _elapsed = 0;
  }

  /// Deterministic pseudo-noise in `[-1, 1]`.
  ///
  /// A sum of two incommensurable sines rather than a random sample per frame:
  /// random shake is white noise and reads as static, whereas a wandering
  /// quasi-periodic signal reads as a camera on a spring. It is also
  /// reproducible, which is what makes this testable at all.
  double _noise(int seed) {
    final double phase = seed % 1000 / 1000.0 * math.pi * 2;
    final double t = _elapsed * Juice.shakeFrequency;
    return 0.62 * math.sin(t + phase) + 0.38 * math.sin(t * 1.7 + phase * 2.3);
  }
}
