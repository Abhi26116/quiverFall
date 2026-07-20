import 'dart:typed_data';

/// Expanding rings: Confluence bursts, death pops, reaction blooms.
///
/// Separate from [ParticlePool] because the shape of the data is different — a
/// ring is a radius and a colour, not a position and a velocity — and mixing
/// them would mean the renderer branching per element in its hottest loop.
///
/// Pure Dart with packed ARGB colours, like everything else in `game/feel`.
class BurstPool {
  BurstPool({this.capacity = 48})
      : x = Float64List(capacity),
        y = Float64List(capacity),
        radius = Float64List(capacity),
        maxRadius = Float64List(capacity),
        life = Float64List(capacity),
        maxLife = Float64List(capacity),
        colour = Int32List(capacity),
        rank = Int32List(capacity),
        _alive = Uint8List(capacity);

  final int capacity;

  final Float64List x;
  final Float64List y;
  final Float64List radius;
  final Float64List maxRadius;
  final Float64List life;
  final Float64List maxLife;
  final Int32List colour;

  /// Confluence stack count, or 0. The renderer draws one concentric ring per
  /// stack, so a x3 is legible as *three* rather than merely as bigger — which
  /// matters on a 5.5" screen where size alone is a poor channel.
  final Int32List rank;

  final Uint8List _alive;

  int _cursor = 0;
  int _liveCount = 0;

  int get liveCount => _liveCount;

  bool isAlive(int i) => _alive[i] == 1;

  /// Eased expansion in `[0, 1]`.
  ///
  /// Fast out, slow in. A linearly expanding ring reads as a wireframe
  /// animation; a decelerating one reads as a shockwave.
  double progress(int i) {
    if (maxLife[i] <= 0) return 1;
    final double t = 1.0 - life[i] / maxLife[i];
    final double inv = 1.0 - t;
    return 1.0 - inv * inv * inv;
  }

  double alpha(int i) => maxLife[i] <= 0 ? 0 : life[i] / maxLife[i];

  void spawn({
    required double atX,
    required double atY,
    required double toRadius,
    required double seconds,
    required int argb,
    int stacks = 0,
  }) {
    final int i = _claim();
    x[i] = atX;
    y[i] = atY;
    radius[i] = 0;
    maxRadius[i] = toRadius;
    maxLife[i] = seconds;
    life[i] = seconds;
    colour[i] = argb;
    rank[i] = stacks;
  }

  void update(double dt) {
    for (int i = 0; i < capacity; i++) {
      if (_alive[i] == 0) continue;
      life[i] -= dt;
      if (life[i] <= 0) {
        _alive[i] = 0;
        _liveCount--;
        continue;
      }
      radius[i] = maxRadius[i] * progress(i);
    }
  }

  void clear() {
    for (int i = 0; i < capacity; i++) {
      _alive[i] = 0;
    }
    _liveCount = 0;
    _cursor = 0;
  }

  int _claim() {
    for (int n = 0; n < capacity; n++) {
      final int i = (_cursor + n) % capacity;
      if (_alive[i] == 0) {
        _alive[i] = 1;
        _liveCount++;
        _cursor = (i + 1) % capacity;
        return i;
      }
    }
    final int i = _cursor;
    _cursor = (i + 1) % capacity;
    return i;
  }
}
