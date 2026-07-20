import 'dart:typed_data';
import 'dart:ui';

import 'package:quiverfall/game/feel/feel_palette.dart';
import 'package:quiverfall/game/feel/particle_pool.dart';

/// Every live particle in one draw call.
///
/// The Phase 6 renderer drew particles with a `drawCircle` each, which at the
/// 512-particle cap is 512 draw calls in a frame that has a 7.0 ms render
/// budget (docs/19 §19.1). This is the same `drawVertices` treatment
/// [WindlineMesh] gets, and docs/19 §19.3 asks for it in as many words:
/// "particles are a single batched system, same `drawVertices` approach as
/// Windlines".
///
/// Particles are drawn as **diamonds rather than circles**. A quad is two
/// triangles either way, and at this size an axis-aligned square reads as a
/// pixel artefact while a diamond reads as a spark. Approximating a circle
/// properly would cost eight or more triangles each for a shape that is four
/// pixels across.
///
/// Zero steady-state allocation: both buffers are sized for the pool at
/// construction and rewritten in place.
class ParticleMesh {
  ParticleMesh({this.capacity = 2048})
      : _positions = Float32List(capacity * _vertsPerParticle * 2),
        _colours = Int32List(capacity * _vertsPerParticle);

  /// Two triangles.
  static const int _vertsPerParticle = 6;

  final int capacity;

  final Float32List _positions;
  final Int32List _colours;

  int _built = 0;

  int get built => _built;

  /// Rebuilds from the pool. Call once per rendered frame.
  ///
  /// [density] is the quality tier's particle density. It is applied here, at
  /// *render* time, rather than at emission: the pool stays a faithful record
  /// of what happened, so a tier change takes effect on the next frame instead
  /// of on the next fight, and the simulation is never told which phone it is
  /// running on.
  void rebuild(ParticlePool pool, {double density = 1.0}) {
    _built = 0;
    if (density <= 0) return;

    // Deterministic thinning by index rather than a random draw: a random one
    // makes particles flicker in and out between frames as the dice change.
    final int stride = density >= 1.0 ? 1 : (1.0 / density).round();

    for (int i = 0; i < pool.capacity; i++) {
      if (!pool.isAlive(i)) continue;
      if (stride > 1 && i % stride != 0) continue;
      if (_built >= capacity) break;

      final double fade = pool.fade(i);
      // Shrinking as they fade reads as debris settling. Fading alone reads as
      // the renderer running out of something.
      final double half = pool.size[i] * fade;
      if (half <= 0) continue;

      _emit(
        pool.x[i],
        pool.y[i],
        half,
        FeelPalette.withAlpha(pool.colour[i], fade),
      );
    }
  }

  void render(Canvas canvas) {
    if (_built == 0) return;

    final int vertexCount = _built * _vertsPerParticle;

    final Vertices vertices = Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(_positions, 0, vertexCount * 2),
      colors: Int32List.sublistView(_colours, 0, vertexCount),
    );

    // Additive: sparks are light. Overlapping debris should brighten rather
    // than occlude, which is also what keeps a dense burst readable instead of
    // turning into a solid blob.
    final Paint paint = Paint()..blendMode = BlendMode.plus;
    canvas.drawVertices(vertices, BlendMode.modulate, paint);
    vertices.dispose();
  }

  void _emit(double cx, double cy, double half, int argb) {
    final int v = _built * _vertsPerParticle;
    final int p = v * 2;

    final double left = cx - half;
    final double right = cx + half;
    final double top = cy - half;
    final double bottom = cy + half;

    // Diamond: top, right, bottom, left as two triangles.
    // Triangle 1: top, right, bottom
    _positions[p] = cx;
    _positions[p + 1] = top;
    _positions[p + 2] = right;
    _positions[p + 3] = cy;
    _positions[p + 4] = cx;
    _positions[p + 5] = bottom;

    // Triangle 2: bottom, left, top
    _positions[p + 6] = cx;
    _positions[p + 7] = bottom;
    _positions[p + 8] = left;
    _positions[p + 9] = cy;
    _positions[p + 10] = cx;
    _positions[p + 11] = top;

    for (int k = 0; k < _vertsPerParticle; k++) {
      _colours[v + k] = argb;
    }

    _built++;
  }
}
