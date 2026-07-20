import 'dart:math' as math;
import 'dart:typed_data';

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/feel/juice.dart';
import 'package:quiverfall/game/pools/pool_report.dart';

/// Impact particles, pooled and struct-of-arrays.
///
/// Same discipline as [EntityStore] and for the same reason: this is touched
/// every frame at 60 Hz, and allocating a particle object per hit is exactly
/// the steady-state allocation docs/19 §19.2 forbids. Colours are stored as
/// packed ARGB ints rather than `Color` objects so the pool stays pure Dart and
/// the renderer can hand them straight to a vertex buffer.
///
/// Fixed capacity, oldest-wins on overflow. Beyond [Juice.maxParticles] the
/// arena stops being readable, which is a gameplay failure before it is a
/// performance one — so overflowing is a *design* boundary, not an accident.
class ParticlePool implements PoolReport {
  ParticlePool({this.capacity = Juice.maxParticles, int seed = 0xC0FFEE})
      : x = Float64List(capacity),
        y = Float64List(capacity),
        velX = Float64List(capacity),
        velY = Float64List(capacity),
        life = Float64List(capacity),
        maxLife = Float64List(capacity),
        size = Float64List(capacity),
        colour = Int32List(capacity),
        _alive = Uint8List(capacity),
        _rng = Rng(seed);

  final int capacity;

  final Float64List x;
  final Float64List y;
  final Float64List velX;
  final Float64List velY;
  final Float64List life;
  final Float64List maxLife;
  final Float64List size;

  /// Packed ARGB.
  final Int32List colour;

  final Uint8List _alive;
  final Rng _rng;

  int _cursor = 0;
  int _liveCount = 0;

  int get liveCount => _liveCount;

  /// Live particles overwritten because the pool was full.
  int overwritten = 0;

  @override
  String get poolName => 'particles';

  @override
  int get poolCapacity => capacity;

  @override
  int get poolLive => _liveCount;

  @override
  int get poolMisses => overwritten;

  bool isAlive(int i) => _alive[i] == 1;

  /// Remaining life as a fraction, for the renderer's alpha and scale.
  double fade(int i) => maxLife[i] <= 0 ? 0 : life[i] / maxLife[i];

  /// Emits a directional burst.
  ///
  /// [towardAngle] biases the spray — docs/10 §10.6 asks for a *directional*
  /// impact particle, because a radial puff tells the player something happened
  /// while a directional one tells them where it came from.
  void burst({
    required double atX,
    required double atY,
    required int count,
    required int argb,
    double towardAngle = 0,
    double spread = math.pi,
    double speedScale = 1.0,
  }) {
    for (int n = 0; n < count; n++) {
      final int i = _claim();

      final double angle = towardAngle + _rng.nextDoubleRange(-spread, spread);
      final double speed = _rng.nextDoubleRange(
            Juice.particleSpeedMin,
            Juice.particleSpeedMax,
          ) *
          speedScale;

      x[i] = atX;
      y[i] = atY;
      velX[i] = math.cos(angle) * speed;
      velY[i] = math.sin(angle) * speed;
      maxLife[i] = _rng.nextDoubleRange(
        Juice.particleLifeMin,
        Juice.particleLifeMax,
      );
      life[i] = maxLife[i];
      size[i] = Juice.particleSize;
      colour[i] = argb;
    }
  }

  void update(double dt) {
    // Exponential drag rather than linear: particles should decelerate hard at
    // first and then drift, which reads as debris rather than as fireworks.
    final double damping = 1.0 - Juice.particleDrag * dt;
    final double drag = damping < 0 ? 0 : damping;

    for (int i = 0; i < capacity; i++) {
      if (_alive[i] == 0) continue;

      life[i] -= dt;
      if (life[i] <= 0) {
        _alive[i] = 0;
        _liveCount--;
        continue;
      }

      x[i] += velX[i] * dt;
      y[i] += velY[i] * dt;
      velX[i] *= drag;
      velY[i] *= drag;
    }
  }

  void clear() {
    for (int i = 0; i < capacity; i++) {
      _alive[i] = 0;
    }
    _liveCount = 0;
    _cursor = 0;
    overwritten = 0;
  }

  /// Round-robin allocation. When full, the oldest particle is overwritten —
  /// dropping the *newest* would hide the event the player just caused, which
  /// is the wrong one to lose.
  int _claim() {
    final int start = _cursor;
    for (int n = 0; n < capacity; n++) {
      final int i = (start + n) % capacity;
      if (_alive[i] == 0) {
        _alive[i] = 1;
        _liveCount++;
        _cursor = (i + 1) % capacity;
        return i;
      }
    }
    // Full. The oldest particle is overwritten rather than the newest dropped —
    // losing the event the player just caused is the wrong one to lose.
    overwritten++;
    final int i = _cursor;
    _cursor = (i + 1) % capacity;
    return i;
  }
}
