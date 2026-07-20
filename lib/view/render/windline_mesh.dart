import 'dart:typed_data';
import 'dart:ui';

import 'package:quiverfall/game/feel/feel_palette.dart';
import 'package:quiverfall/game/feel/juice.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/windline_store.dart';

/// The game's signature visual, in one draw call.
///
/// Up to 1,024 additive translucent segments, each with its own colour and
/// fade. Drawn naively that is 1,024 draw calls and the mechanic is
/// unaffordable on the reference device; docs/19-performance.md §19.2 calls for
/// a single batched `drawVertices` mesh instead, and this is it.
///
/// **Zero steady-state allocation.** Both buffers are sized for the segment cap
/// at construction and rewritten in place each frame. `Vertices.raw` is the one
/// unavoidable per-frame object — the engine requires a fresh handle — and it
/// is a thin wrapper over the buffers rather than a copy of them.
///
/// The visual half-width is deliberately wider than
/// [SimConfig.windlineHitWidth]. A line the player can see but cannot reliably
/// thread would be the mechanic lying to them, so the drawn line is the
/// generous one.
class WindlineMesh {
  WindlineMesh({this.capacity = SimConfig.maxWindlineSegments})
      : _positions = Float32List(capacity * _vertsPerSegment * 2),
        _colours = Int32List(capacity * _vertsPerSegment);

  /// Two triangles per segment.
  static const int _vertsPerSegment = 6;

  final int capacity;

  final Float32List _positions;
  final Int32List _colours;

  int _segmentsBuilt = 0;

  int get segmentsBuilt => _segmentsBuilt;

  /// Rebuilds the mesh from the live store. Call once per rendered frame.
  void rebuild(WindlineStore lines, double now, double duration) {
    _segmentsBuilt = 0;

    for (int i = 0; i < lines.capacity; i++) {
      if (!lines.isAlive(i)) continue;
      if (_segmentsBuilt >= capacity) break;

      final double remaining = lines.expiryAt(i) - now;
      if (remaining <= 0) continue;

      // Hold full brightness, then fade over the tail of the life. A trail that
      // starts fading immediately reads as a rendering artefact; one that
      // vanishes at full brightness reads as a bug.
      final double lifeFraction =
          duration <= 0 ? 1.0 : (remaining / duration).clamp(0.0, 1.0);
      final double fade = lifeFraction >= Juice.windlineFadeFraction
          ? 1.0
          : lifeFraction / Juice.windlineFadeFraction;

      final int element = lines.elementAt(i);
      final int base = element >= 0 && element < FeelPalette.byElement.length
          ? FeelPalette.byElement[element]
          : FeelPalette.accent;

      _emit(
        lines.x0(i),
        lines.y0(i),
        lines.x1(i),
        lines.y1(i),
        FeelPalette.withAlpha(base, Juice.windlineAlpha * fade),
      );
    }
  }

  /// Draws the whole mesh. One `drawVertices`, one paint, one blend.
  void render(Canvas canvas) {
    if (_segmentsBuilt == 0) return;

    final int vertexCount = _segmentsBuilt * _vertsPerSegment;

    // `Vertices.raw` takes the whole buffer, so the tail beyond what was built
    // this frame would be drawn as stale geometry. A view onto the live prefix
    // shares the same backing memory — no copy, no allocation of vertex data.
    final Float32List positions =
        Float32List.sublistView(_positions, 0, vertexCount * 2);
    final Int32List colours = Int32List.sublistView(_colours, 0, vertexCount);

    final Vertices vertices = Vertices.raw(
      VertexMode.triangles,
      positions,
      colors: colours,
    );

    // Additive, because Windlines are light rather than paint: where two trails
    // overlap the crossing should be brighter, which is the player's first cue
    // that a lattice is forming.
    final Paint paint = Paint()..blendMode = BlendMode.plus;

    // `modulate` multiplies the vertex colours by the paint colour. With an
    // opaque white paint that passes the vertex colours through unchanged,
    // which is the reliable way to say "use my per-vertex colours".
    canvas.drawVertices(vertices, BlendMode.modulate, paint);
    vertices.dispose();
  }

  void _emit(double x0, double y0, double x1, double y1, int argb) {
    double dx = x1 - x0;
    double dy = y1 - y0;
    final double length = _length(dx, dy);
    if (length <= 1e-9) return;

    dx /= length;
    dy /= length;

    // Left-hand normal, scaled to half the ribbon width.
    final double nx = -dy * Juice.windlineHalfWidth;
    final double ny = dx * Juice.windlineHalfWidth;

    final int v = _segmentsBuilt * _vertsPerSegment;
    final int p = v * 2;

    // Triangle 1: a+, a-, b+
    _positions[p] = x0 + nx;
    _positions[p + 1] = y0 + ny;
    _positions[p + 2] = x0 - nx;
    _positions[p + 3] = y0 - ny;
    _positions[p + 4] = x1 + nx;
    _positions[p + 5] = y1 + ny;

    // Triangle 2: b+, a-, b-
    _positions[p + 6] = x1 + nx;
    _positions[p + 7] = y1 + ny;
    _positions[p + 8] = x0 - nx;
    _positions[p + 9] = y0 - ny;
    _positions[p + 10] = x1 - nx;
    _positions[p + 11] = y1 - ny;

    for (int k = 0; k < _vertsPerSegment; k++) {
      _colours[v + k] = argb;
    }

    _segmentsBuilt++;
  }

  static double _length(double x, double y) {
    final double sq = x * x + y * y;
    if (sq == 0) return 0;
    double g = sq > 1 ? sq : 1.0;
    for (int i = 0; i < 12; i++) {
      g = 0.5 * (g + sq / g);
    }
    return g;
  }
}
