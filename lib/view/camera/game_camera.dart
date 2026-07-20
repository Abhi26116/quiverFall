import 'dart:ui';

import 'package:quiverfall/game/device/quality_tier.dart';
import 'package:quiverfall/game/feel/screen_shake.dart';
import 'package:quiverfall/game/sim/sim_config.dart';

/// The camera.
///
/// It does exactly two things — letterbox a fixed 16x9 arena into whatever
/// screen it is given, and shake. **It never tracks the player**, because
/// docs/14 §14.1 makes arenas single-screen: the whole fight is visible at
/// once, on every device, and only the render scale changes. A camera that
/// hunted the player would make the same room a different fight on a tall
/// phone versus a tablet.
///
/// Extracted from the renderer in Phase 7 so that the transform has one owner.
/// Screen-to-world conversion, parallax depth and shake all need the same
/// numbers, and three copies of a letterbox calculation is three chances to
/// disagree about where the player just tapped.
class GameCamera {
  GameCamera({required this.shake});

  final ScreenShake shake;

  /// Scales shake by the quality tier, and to zero on Battery or Reduce Motion.
  QualityTier quality = QualityTier.high;

  double _scale = 1;
  double _originX = 0;
  double _originY = 0;
  Size _viewport = Size.zero;

  /// World units per logical pixel for the most recent frame.
  double get scale => _scale;

  double get originX => _originX;

  double get originY => _originY;

  Size get viewport => _viewport;

  /// Recomputes the letterbox for a viewport. Call once per frame, before any
  /// transform is applied.
  void resize(Size size) {
    if (size == _viewport) return;
    _viewport = size;

    final double sx = size.width / SimConfig.arenaWidth;
    final double sy = size.height / SimConfig.arenaHeight;
    _scale = sx < sy ? sx : sy;
    _originX = (size.width - SimConfig.arenaWidth * _scale) / 2;
    _originY = (size.height - SimConfig.arenaHeight * _scale) / 2;
  }

  /// Applies the world transform to [canvas]. The caller is responsible for the
  /// matching `restore`.
  ///
  /// Order matters: roll and zoom are applied about the *viewport* centre so
  /// the arena pivots around the middle of the screen rather than around its
  /// top-left corner, and the shake offset is applied last, in world units, so
  /// its magnitude means the same thing on every screen size.
  void apply(Canvas canvas) {
    final double cx = _viewport.width / 2;
    final double cy = _viewport.height / 2;
    final double intensity = quality.shake.scale;

    canvas
      ..save()
      ..translate(cx, cy)
      ..rotate(shake.roll * intensity)
      ..scale(1.0 + (shake.zoomScale - 1.0) * intensity)
      ..translate(-cx, -cy)
      ..translate(_originX, _originY)
      ..scale(_scale)
      ..translate(shake.offsetX * intensity, shake.offsetY * intensity);
  }

  /// The parallax offset for a background layer.
  ///
  /// Layer 0 is the furthest and barely moves. Depth is driven by shake alone
  /// — with no camera translation there is nothing else to parallax against —
  /// which makes it a *reaction* effect: the background lags the foreground on
  /// impact, so a hit reads as the world being struck rather than the screen
  /// being jiggled.
  Offset parallaxFor(int layer) {
    if (layer >= quality.parallaxLayers) return Offset.zero;
    final double depth = (layer + 1) / (quality.parallaxLayers + 1);
    final double intensity = quality.shake.scale;
    return Offset(
      -shake.offsetX * depth * intensity,
      -shake.offsetY * depth * intensity,
    );
  }

  /// Screen point to world coordinates.
  ///
  /// Deliberately ignores shake. A tap must land where the player *aimed*, and
  /// they aimed at a screen that was mid-wobble — compensating for the shake
  /// would move the target out from under their thumb.
  Offset toWorld(Offset screen) => Offset(
        (screen.dx - _originX) / _scale,
        (screen.dy - _originY) / _scale,
      );

  Offset toScreen(Offset world) => Offset(
        _originX + world.dx * _scale,
        _originY + world.dy * _scale,
      );
}
