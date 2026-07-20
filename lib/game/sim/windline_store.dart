import 'dart:typed_data';

import 'package:quiverfall/game/sim/sim_config.dart';

/// The trails arrows leave behind.
///
/// Every arrow lays a Windline along its flight path, alive for ~1.2 s. Firing a
/// *new* arrow through an *older* Windline produces Confluence — the mechanic
/// the whole game is built around (docs/01-vision.md §1.1).
///
/// **A ring buffer, not a growable list.** The capacity is a hard cap: when full,
/// the oldest segment is evicted regardless of its remaining lifetime. That is a
/// correctness requirement rather than an optimisation. With *The Loom* (Boon 75,
/// Windlines never expire) plus Iris plus Mirelle's duplication, a player can
/// genuinely create segments faster than they expire; an unbounded store would
/// grow until the device died. See docs/19-performance.md §19.2.
///
/// Segments are stored newest-last in insertion order, which is what makes the
/// age filter in [ConfluenceSystem] a cheap index comparison instead of a
/// timestamp sort.
class WindlineStore {
  WindlineStore({this.capacity = SimConfig.maxWindlineSegments})
      : _x0 = Float64List(capacity),
        _y0 = Float64List(capacity),
        _x1 = Float64List(capacity),
        _y1 = Float64List(capacity),
        _expiry = Float64List(capacity),
        _element = Int8List(capacity),
        _owner = Int32List(capacity),
        _serial = Int32List(capacity),
        _trail = Int32List(capacity),
        _alive = Uint8List(capacity);

  final int capacity;

  final Float64List _x0;
  final Float64List _y0;
  final Float64List _x1;
  final Float64List _y1;

  /// World time at which this segment disappears.
  final Float64List _expiry;

  /// [SimElement] index, or -1 for a plain arrow.
  final Int8List _element;

  /// Entity slot of whoever laid it. Confluence only ever considers the
  /// player's own lines — an enemy's trail must never buff the player, and the
  /// Hollow Warden's trails (docs/06, boss 4) interact through a separate
  /// Discord rule.
  final Int32List _owner;

  /// Monotonically increasing id. Survives ring wrap-around, so "older than"
  /// stays meaningful after the buffer has cycled — a raw slot index would not.
  final Int32List _serial;

  /// Which arrow's trail this segment belongs to.
  ///
  /// Confluence dedupes by *trail*, not by segment: threading one arrow's trail
  /// is one crossing, however many segments that trail happens to be made of.
  /// Without this a single trail would grant a full stack of Confluence on its
  /// own, which is not the mechanic — the mechanic is threading *distinct*
  /// lines.
  final Int32List _trail;

  final Uint8List _alive;

  int _head = 0;
  int _liveCount = 0;
  int _nextSerial = 1;

  /// Segments evicted while still alive, since the last [clear]. Non-zero means
  /// the player is generating lines faster than the cap allows; surfaced rather
  /// than hidden because it changes how the mechanic feels.
  int evictedWhileAlive = 0;

  int get liveCount => _liveCount;

  int get nextSerial => _nextSerial;

  double x0(int i) => _x0[i];

  double y0(int i) => _y0[i];

  double x1(int i) => _x1[i];

  double y1(int i) => _y1[i];

  double expiryAt(int i) => _expiry[i];

  int serialAt(int i) => _serial[i];

  int trailAt(int i) => _trail[i];

  int ownerAt(int i) => _owner[i];

  bool isAlive(int i) => _alive[i] == 1;

  /// -1 when the segment carries no element.
  int elementAt(int i) => _element[i];

  /// Adds a segment and returns its slot, or -1 if the segment is degenerate.
  ///
  /// Zero-length segments are rejected outright: they can never be crossed, and
  /// admitting them would put a division-by-zero case into the hottest
  /// intersection loop in the game.
  int add({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    required double expiresAt,
    required int ownerIndex,
    required int trailId,
    int elementIndex = -1,
  }) {
    final double dx = toX - fromX;
    final double dy = toY - fromY;
    if (dx * dx + dy * dy < _minLengthSquared) return -1;

    final int slot = _head;
    if (_alive[slot] == 1) {
      evictedWhileAlive++;
    } else {
      _liveCount++;
    }

    _x0[slot] = fromX;
    _y0[slot] = fromY;
    _x1[slot] = toX;
    _y1[slot] = toY;
    _expiry[slot] = expiresAt;
    _owner[slot] = ownerIndex;
    _element[slot] = elementIndex;
    _serial[slot] = _nextSerial++;
    _trail[slot] = trailId;
    _alive[slot] = 1;

    _head = (_head + 1) % capacity;
    return slot;
  }

  /// Retires segments whose lifetime has run out.
  void expire(double now) {
    for (int i = 0; i < capacity; i++) {
      if (_alive[i] == 1 && _expiry[i] <= now) {
        _alive[i] = 0;
        _liveCount--;
      }
    }
  }

  /// Extends every live segment's lifetime.
  ///
  /// Used by Boon 62 (*Lingering*) at a room transition and by research
  /// *Windline Memory*. Applied in bulk rather than per-segment at creation
  /// because the modifier can be gained mid-room, after lines already exist.
  void extendAll(double bySeconds) {
    for (int i = 0; i < capacity; i++) {
      if (_alive[i] == 1) _expiry[i] += bySeconds;
    }
  }

  void clear() {
    for (int i = 0; i < capacity; i++) {
      _alive[i] = 0;
    }
    _head = 0;
    _liveCount = 0;
    evictedWhileAlive = 0;
    // Serials deliberately keep counting. Resetting them would make a
    // post-clear segment compare as "older than" a pre-clear one in any handle
    // that outlived the room.
  }

  /// Below this a segment is treated as a point and rejected.
  static const double _minLengthSquared = 1e-8;
}
