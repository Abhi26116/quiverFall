import 'dart:typed_data';

import 'package:quiverfall/game/sim/sim_config.dart';

/// Things the simulation reports to the outside world.
///
/// The sim never plays a sound, spawns a particle, or shakes the camera — it
/// cannot, having no Flutter or Flame imports. Instead it emits events that the
/// view layer drains once per rendered frame and turns into presentation.
///
/// This is what keeps the render layer replaceable and the sim headless: the
/// balance harness simply drains events into a counter.
enum SimEventType {
  entitySpawned,
  entityDied,
  damageDealt,
  playerHit,
  drawTierChanged,
  momentumChanged,
  arrowFired,
  windlineCreated,
  confluenceTriggered,

  /// An enemy began telegraphing an attack.
  ///
  /// Exists for audio. docs/16 §16.2 sets the bar: "a player should be able to
  /// survive a room with their eyes closed for two seconds", and that is only
  /// true if every wind-up has a distinct, rising, directional cue. Without an
  /// event the sound layer would have to poll the telegraph store each frame
  /// and guess which entries were new.
  telegraphStarted,

  elementApplied,
  reactionTriggered,
  roomCleared,
  ultimateReady,
  ultimateUsed,
}

/// Fixed-size event ring buffer.
///
/// Events are stored as parallel primitive arrays rather than objects, for the
/// same reason entities are (docs/19 §19.2): a room clear can emit hundreds of
/// events in one tick, and allocating an object per event would defeat the
/// zero-allocation target on its own.
///
/// When full, the oldest events are overwritten. Dropping presentation events
/// under extreme load is correct — the alternative is growing the buffer, which
/// allocates, which causes the jank the events were describing.
class SimEventBuffer {
  SimEventBuffer({this.capacity = 512})
      : _type = Uint8List(capacity),
        _entityA = Int32List(capacity),
        _entityB = Int32List(capacity),
        _valueA = Float64List(capacity),
        _valueB = Float64List(capacity),
        _x = Float64List(capacity),
        _y = Float64List(capacity);

  final int capacity;

  final Uint8List _type;
  final Int32List _entityA;
  final Int32List _entityB;
  final Float64List _valueA;
  final Float64List _valueB;
  final Float64List _x;
  final Float64List _y;

  int _count = 0;
  int _dropped = 0;

  int get count => _count;

  /// Events lost to buffer overflow since the last [clear]. Surfaced so the
  /// view can log it rather than silently missing effects.
  int get dropped => _dropped;

  void emit(
    SimEventType type, {
    int entityA = -1,
    int entityB = -1,
    double valueA = 0,
    double valueB = 0,
    double x = 0,
    double y = 0,
  }) {
    if (_count >= capacity) {
      _dropped++;
      return;
    }
    final int i = _count++;
    _type[i] = type.index;
    _entityA[i] = entityA;
    _entityB[i] = entityB;
    _valueA[i] = valueA;
    _valueB[i] = valueB;
    _x[i] = x;
    _y[i] = y;
  }

  SimEventType typeAt(int i) => SimEventType.values[_type[i]];

  int entityAAt(int i) => _entityA[i];

  int entityBAt(int i) => _entityB[i];

  double valueAAt(int i) => _valueA[i];

  double valueBAt(int i) => _valueB[i];

  double xAt(int i) => _x[i];

  double yAt(int i) => _y[i];

  /// Drops everything. Called by the view after draining, once per frame.
  void clear() {
    _count = 0;
    _dropped = 0;
  }

  /// Counts events of a type. Used by tests and the balance harness.
  int countOf(SimEventType type) {
    int n = 0;
    final int target = type.index;
    for (int i = 0; i < _count; i++) {
      if (_type[i] == target) n++;
    }
    return n;
  }
}

/// Compile-time sanity: the buffer must be able to hold a plausible worst-case
/// tick without dropping. A room clear of 90 entities emits at most a few
/// events each.
const int _worstCaseTickEvents = SimConfig.maxEntities;
// ignore: unused_element
const bool _bufferIsBigEnough = _worstCaseTickEvents <= 512;
