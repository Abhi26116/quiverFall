import 'dart:typed_data';

import 'package:quiverfall/game/feel/juice.dart';

/// Floating damage numbers.
///
/// docs/10 §10.6 is unusually specific here, and the specificity is the point:
/// numbers are **off by default below 5 % of the target's max HP**, while crits
/// and Confluence hits **always** show. A game that prints every number turns
/// its arena into a spreadsheet and buries the two events worth reading.
class DamageNumberPool {
  DamageNumberPool({this.capacity = 24})
      : x = Float64List(capacity),
        y = Float64List(capacity),
        value = Float64List(capacity),
        life = Float64List(capacity),
        kind = Uint8List(capacity),
        stacks = Int32List(capacity),
        _alive = Uint8List(capacity);

  final int capacity;

  final Float64List x;
  final Float64List y;
  final Float64List value;
  final Float64List life;

  /// [DamageNumberKind] index.
  final Uint8List kind;

  /// Confluence stack count, for the `x2 CONFLUENCE` callout.
  final Int32List stacks;

  final Uint8List _alive;

  int _cursor = 0;
  int _liveCount = 0;

  int get liveCount => _liveCount;

  bool isAlive(int i) => _alive[i] == 1;

  DamageNumberKind kindAt(int i) => DamageNumberKind.values[kind[i]];

  double alpha(int i) {
    final double t = life[i] / Juice.damageNumberSeconds;
    // Holds opaque, then fades over the last third — a number that starts
    // fading immediately is unreadable at the moment it matters most.
    return t > 0.66 ? 1.0 : (t / 0.66).clamp(0.0, 1.0);
  }

  /// Vertical rise in world units, eased so it decelerates.
  double rise(int i) {
    final double t = 1.0 - (life[i] / Juice.damageNumberSeconds);
    return Juice.damageNumberRise * (1.0 - (1.0 - t) * (1.0 - t));
  }

  /// Adds a number if it clears the noise floor.
  ///
  /// Returns false when the hit was too small to be worth saying out loud.
  bool maybeAdd({
    required double atX,
    required double atY,
    required double damage,
    required double targetMaxHealth,
    DamageNumberKind numberKind = DamageNumberKind.normal,
    int confluenceStacks = 0,
  }) {
    final bool alwaysShow = numberKind != DamageNumberKind.normal;
    if (!alwaysShow) {
      if (targetMaxHealth <= 0) return false;
      if (damage / targetMaxHealth < Juice.damageNumberThreshold) return false;
    }

    final int i = _claim();
    x[i] = atX;
    y[i] = atY;
    value[i] = damage;
    life[i] = Juice.damageNumberSeconds;
    kind[i] = numberKind.index;
    stacks[i] = confluenceStacks;
    return true;
  }

  void update(double dt) {
    for (int i = 0; i < capacity; i++) {
      if (_alive[i] == 0) continue;
      life[i] -= dt;
      if (life[i] <= 0) {
        _alive[i] = 0;
        _liveCount--;
      }
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

enum DamageNumberKind {
  /// Suppressed below the threshold.
  normal,

  crit,

  /// Shown as `xN CONFLUENCE` in white-hot. Always visible, because this is the
  /// mechanic the whole game is teaching.
  confluence,
}
