import 'dart:typed_data';

import 'package:quiverfall/game/pools/pool_report.dart';

/// What an enemy has put into the world.
enum HazardKind {
  /// Travels in a straight line at a fixed speed and hits the first thing it
  /// touches. Nettle bolts, Echo shots.
  bolt,

  /// Flies for a fixed *time* to a fixed *point*, then detonates. Spitter
  /// globs, Mortarite shells, Bounder landings.
  ///
  /// Time-to-point rather than speed-along-a-path is what lets the landing ring
  /// be drawn accurately from the moment of firing, which is the entire
  /// counter-play to every lobbed attack in the game.
  shell,

  /// A stationary lethal zone that damages continuously. Acid puddles.
  puddle,
}

/// Enemy ordnance and ground hazards.
///
/// Deliberately *not* entities. Hazards never collide with each other, never
/// take damage, and are never targeted, so putting them in [EntityStore] would
/// mean every system in the game filtering them out of every query — and would
/// let a dense Mortarite room exhaust the entity pool that enemies and arrows
/// share.
///
/// Struct-of-arrays with a fixed capacity, like everything else in the sim.
class HazardStore implements PoolReport {
  HazardStore({this.capacity = 96})
      : _kind = Uint8List(capacity),
        _alive = Uint8List(capacity),
        _spent = Uint8List(capacity),
        _owner = Int32List(capacity),
        _telegraphSlot = Int32List(capacity),
        _telegraphSerial = Int32List(capacity),
        x = Float64List(capacity),
        y = Float64List(capacity),
        velX = Float64List(capacity),
        velY = Float64List(capacity),
        fromX = Float64List(capacity),
        fromY = Float64List(capacity),
        toX = Float64List(capacity),
        toY = Float64List(capacity),
        remaining = Float64List(capacity),
        totalFlight = Float64List(capacity),
        radius = Float64List(capacity),
        damage = Float64List(capacity),
        damagePerSecond = Float64List(capacity),
        lingerSeconds = Float64List(capacity),
        lingerDamage = Float64List(capacity);

  final int capacity;

  final Uint8List _kind;
  final Uint8List _alive;

  /// A bolt that has already struck. Kept alive for one tick so the view can
  /// spawn its impact effect at the right place.
  final Uint8List _spent;

  final Int32List _owner;
  final Int32List _telegraphSlot;
  final Int32List _telegraphSerial;

  final Float64List x;
  final Float64List y;
  final Float64List velX;
  final Float64List velY;

  /// Launch point, so a shell's arc can be interpolated for rendering without
  /// storing a path.
  final Float64List fromX;
  final Float64List fromY;

  /// Where a shell will land. Fixed at launch — the ring never moves, which is
  /// what makes it dodgeable.
  final Float64List toX;
  final Float64List toY;

  /// Seconds of flight or of life remaining.
  final Float64List remaining;

  final Float64List totalFlight;

  final Float64List radius;

  /// Impact damage, as a fraction of the player's max HP.
  final Float64List damage;

  /// Continuous damage for puddles, as a fraction of max HP per second.
  final Float64List damagePerSecond;

  /// What a shell leaves behind when it lands. Zero means a clean detonation.
  final Float64List lingerSeconds;
  final Float64List lingerDamage;

  int _liveCount = 0;

  int get liveCount => _liveCount;

  @override
  String get poolName => 'hazards';

  @override
  int get poolCapacity => capacity;

  @override
  int get poolLive => _liveCount;

  @override
  int get poolMisses => dropped;

  /// Hazards dropped because the store was full. Surfaced rather than hidden:
  /// a dropped shell is an attack the player dodged for no reason, which reads
  /// as the game lying to them.
  int dropped = 0;

  bool isAlive(int slot) => _alive[slot] == 1;

  bool isSpent(int slot) => _spent[slot] == 1;

  HazardKind kindAt(int slot) => HazardKind.values[_kind[slot]];

  int ownerAt(int slot) => _owner[slot];

  int telegraphSlotAt(int slot) => _telegraphSlot[slot];

  int telegraphSerialAt(int slot) => _telegraphSerial[slot];

  /// Flight progress in `[0, 1]`, for arc rendering.
  double progressAt(int slot) {
    final double total = totalFlight[slot];
    if (total <= 0) return 1.0;
    final double t = 1.0 - remaining[slot] / total;
    return t < 0 ? 0 : (t > 1 ? 1 : t);
  }

  int add({
    required HazardKind kind,
    required int owner,
    required double atX,
    required double atY,
    double velocityX = 0,
    double velocityY = 0,
    double targetX = 0,
    double targetY = 0,
    double lifetime = 0,
    double hitRadius = 0,
    double impactDamage = 0,
    double perSecondDamage = 0,
    double linger = 0,
    double lingerPerSecond = 0,
    int telegraphSlot = -1,
    int telegraphSerial = 0,
  }) {
    for (int i = 0; i < capacity; i++) {
      if (_alive[i] == 1) continue;
      _alive[i] = 1;
      _spent[i] = 0;
      _kind[i] = kind.index;
      _owner[i] = owner;
      _telegraphSlot[i] = telegraphSlot;
      _telegraphSerial[i] = telegraphSerial;
      x[i] = atX;
      y[i] = atY;
      fromX[i] = atX;
      fromY[i] = atY;
      velX[i] = velocityX;
      velY[i] = velocityY;
      toX[i] = targetX;
      toY[i] = targetY;
      remaining[i] = lifetime;
      totalFlight[i] = lifetime;
      radius[i] = hitRadius;
      damage[i] = impactDamage;
      damagePerSecond[i] = perSecondDamage;
      lingerSeconds[i] = linger;
      lingerDamage[i] = lingerPerSecond;
      _liveCount++;
      return i;
    }
    dropped++;
    return -1;
  }

  void markSpent(int slot) {
    _spent[slot] = 1;
  }

  void release(int slot) {
    if (_alive[slot] == 0) return;
    _alive[slot] = 0;
    _spent[slot] = 0;
    _liveCount--;
  }

  void clear() {
    for (int i = 0; i < capacity; i++) {
      _alive[i] = 0;
      _spent[i] = 0;
    }
    _liveCount = 0;
    dropped = 0;
  }
}
