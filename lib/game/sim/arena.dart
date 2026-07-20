import 'dart:typed_data';

import 'package:quiverfall/game/sim/sim_config.dart';

/// The static geometry of a room.
///
/// Walls are axis-aligned rectangles. That is a real constraint, chosen for two
/// reasons: circle-vs-AABB resolution is cheap and exact (no iterative solver,
/// no tunnelling), and ricochet normals are trivially correct — which matters
/// because Corvin, Skimmer arrows, and every Windline that clips a wall depend
/// on reflection behaving predictably.
///
/// See docs/14-level-design.md §14.1.
class Arena {
  Arena({
    required this.width,
    required this.height,
    List<Rect> walls = const <Rect>[],
    List<Rect> cover = const <Rect>[],
  })  : _wallData = _pack(walls),
        _coverData = _pack(cover),
        wallCount = walls.length,
        coverCount = cover.length;

  Arena.standard({
    List<Rect> walls = const <Rect>[],
    List<Rect> cover = const <Rect>[],
  }) : this(
          width: SimConfig.arenaWidth,
          height: SimConfig.arenaHeight,
          walls: walls,
          cover: cover,
        );

  final double width;
  final double height;

  /// Blocks movement and projectiles.
  final Float64List _wallData;
  final int wallCount;

  /// Blocks projectiles but not movement — the counter to Longeye and the
  /// reason "break line of sight" is a real tactic.
  final Float64List _coverData;
  final int coverCount;

  static Float64List _pack(List<Rect> rects) {
    final Float64List out = Float64List(rects.length * 4);
    for (int i = 0; i < rects.length; i++) {
      out[i * 4] = rects[i].left;
      out[i * 4 + 1] = rects[i].top;
      out[i * 4 + 2] = rects[i].right;
      out[i * 4 + 3] = rects[i].bottom;
    }
    return out;
  }

  double wallLeft(int i) => _wallData[i * 4];

  double wallTop(int i) => _wallData[i * 4 + 1];

  double wallRight(int i) => _wallData[i * 4 + 2];

  double wallBottom(int i) => _wallData[i * 4 + 3];

  double coverLeft(int i) => _coverData[i * 4];

  double coverTop(int i) => _coverData[i * 4 + 1];

  double coverRight(int i) => _coverData[i * 4 + 2];

  double coverBottom(int i) => _coverData[i * 4 + 3];

  bool containsPoint(double x, double y) =>
      x >= 0 && y >= 0 && x <= width && y <= height;

  /// Index of the first wall a circle overlaps, or -1.
  ///
  /// Used by the slide resolution, which needs to know *which* obstacle it is
  /// pressed against in order to go round it the short way.
  int wallHitBy(double x, double y, double r) {
    for (int i = 0; i < wallCount; i++) {
      final double cx = _clamp(x, _wallData[i * 4], _wallData[i * 4 + 2]);
      final double cy = _clamp(y, _wallData[i * 4 + 1], _wallData[i * 4 + 3]);
      final double dx = x - cx;
      final double dy = y - cy;
      if (dx * dx + dy * dy < r * r) return i;
    }
    return -1;
  }

  /// True if a circle overlaps any wall.
  bool circleHitsWall(double x, double y, double r) {
    for (int i = 0; i < wallCount; i++) {
      final double cx = _clamp(x, _wallData[i * 4], _wallData[i * 4 + 2]);
      final double cy = _clamp(y, _wallData[i * 4 + 1], _wallData[i * 4 + 3]);
      final double dx = x - cx;
      final double dy = y - cy;
      if (dx * dx + dy * dy < r * r) return true;
    }
    return false;
  }

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);
}

/// An axis-aligned rectangle in world units.
///
/// Deliberately not `dart:ui`'s Rect — the simulation may not import Flutter.
/// See docs/12-architecture.md §12.0.
class Rect {
  const Rect(this.left, this.top, this.right, this.bottom);

  const Rect.fromLTWH(this.left, this.top, double w, double h)
      : right = left + w,
        bottom = top + h;

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;

  double get height => bottom - top;
}
