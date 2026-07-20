import 'dart:typed_data';

/// The shape a telegraph describes.
///
/// Three shapes cover the entire roster and every boss in docs/06. That is not
/// an accident of implementation — it is the point. A player learns three
/// shapes once, in chapter 1, and reads every attack in the game for the rest
/// of the campaign.
enum TelegraphShape {
  /// A landing ring or a blast radius. Mortarite shells, Bounder slams,
  /// Cinder Mote fuses.
  circle,

  /// A path something is about to travel. The Lancer's charge line is the
  /// canonical instance and every boss reuses it.
  line,

  /// An arc from a point. Screecher screams, boss sweeps.
  cone,
}

/// What the colour means.
///
/// **This is a two-word vocabulary and it is never violated.** Amber means
/// "this is about to happen"; crimson means "standing here damages you now".
/// A game that uses its warning colour for anything else has taught its players
/// to ignore it.
enum TelegraphSeverity {
  /// Amber. An incoming attack, not yet dangerous.
  warning,

  /// Crimson. A live lethal zone — the Thresher's aura, an acid puddle.
  lethal,
}

/// Active telegraphs, as the simulation sees them.
///
/// The sim owns telegraphs rather than the view because they are *timing*, not
/// decoration: the wind-up duration is the attack's balance, the shape is its
/// hitbox, and the headless balance harness must be able to measure both. The
/// view drains this store each frame and draws it; a run replayed without a
/// renderer behaves identically.
///
/// Fixed capacity, struct-of-arrays, zero allocation — the same discipline as
/// [EntityStore], for the same reason.
class TelegraphStore {
  TelegraphStore({this.capacity = 64})
      : _shape = Uint8List(capacity),
        _severity = Uint8List(capacity),
        _alive = Uint8List(capacity),
        _owner = Int32List(capacity),
        _serial = Int32List(capacity),
        _x = Float64List(capacity),
        _y = Float64List(capacity),
        _toX = Float64List(capacity),
        _toY = Float64List(capacity),
        _radius = Float64List(capacity),
        _angle = Float64List(capacity),
        _halfAngle = Float64List(capacity),
        _startedAt = Float64List(capacity),
        _resolvesAt = Float64List(capacity);

  /// How long a resolved telegraph lingers so the view can play its flash.
  /// Purely presentational; the attack has already landed.
  static const double resolveLinger = 0.12;

  final int capacity;

  final Uint8List _shape;
  final Uint8List _severity;
  final Uint8List _alive;
  final Int32List _owner;

  /// Bumped every time a slot is reused. An AI holds `(slot, serial)` and can
  /// therefore tell "my telegraph" from "somebody else's telegraph that landed
  /// in the slot mine used to occupy" — the same stale-handle problem
  /// [EntityId] solves, and the same solution.
  final Int32List _serial;

  final Float64List _x;
  final Float64List _y;
  final Float64List _toX;
  final Float64List _toY;
  final Float64List _radius;
  final Float64List _angle;
  final Float64List _halfAngle;
  final Float64List _startedAt;
  final Float64List _resolvesAt;

  int _nextSerial = 1;
  int _liveCount = 0;

  int get liveCount => _liveCount;

  /// Telegraphs dropped because the store was full, since the last [clear].
  ///
  /// A dropped telegraph is an *undodgeable attack*, which is the worst class
  /// of bug this game can ship. It is counted rather than ignored so the soak
  /// test can assert it stays zero.
  int dropped = 0;

  bool isAlive(int slot) => _alive[slot] == 1;

  TelegraphShape shapeAt(int slot) => TelegraphShape.values[_shape[slot]];

  TelegraphSeverity severityAt(int slot) =>
      TelegraphSeverity.values[_severity[slot]];

  int ownerAt(int slot) => _owner[slot];

  int serialAt(int slot) => _serial[slot];

  double xAt(int slot) => _x[slot];

  double yAt(int slot) => _y[slot];

  double toXAt(int slot) => _toX[slot];

  double toYAt(int slot) => _toY[slot];

  double radiusAt(int slot) => _radius[slot];

  double angleAt(int slot) => _angle[slot];

  double halfAngleAt(int slot) => _halfAngle[slot];

  double startedAtOf(int slot) => _startedAt[slot];

  double resolvesAtOf(int slot) => _resolvesAt[slot];

  /// Fill fraction in `[0, 1]`. The view sweeps the shape by this; the player
  /// reads time-to-impact off it without a number.
  double progressAt(int slot, double now) {
    final double span = _resolvesAt[slot] - _startedAt[slot];
    if (span <= 0) return 1.0;
    final double t = (now - _startedAt[slot]) / span;
    return t < 0 ? 0 : (t > 1 ? 1 : t);
  }

  /// Claims a slot. Returns -1 when full.
  int add({
    required TelegraphShape shape,
    required TelegraphSeverity severity,
    required int owner,
    required double x,
    required double y,
    required double startedAt,
    required double resolvesAt,
    double toX = 0,
    double toY = 0,
    double radius = 0,
    double angle = 0,
    double halfAngle = 0,
  }) {
    for (int i = 0; i < capacity; i++) {
      if (_alive[i] == 1) continue;
      _alive[i] = 1;
      _shape[i] = shape.index;
      _severity[i] = severity.index;
      _owner[i] = owner;
      _serial[i] = _nextSerial++;
      _x[i] = x;
      _y[i] = y;
      _toX[i] = toX;
      _toY[i] = toY;
      _radius[i] = radius;
      _angle[i] = angle;
      _halfAngle[i] = halfAngle;
      _startedAt[i] = startedAt;
      _resolvesAt[i] = resolvesAt;
      _liveCount++;
      return i;
    }
    dropped++;
    return -1;
  }

  /// Moves a live telegraph. Used by tracking attacks — the Longeye's beam
  /// follows the player until [EnemyCombat.trackingCutoffSeconds] before impact
  /// and then commits.
  void retarget(int slot, int serial, double x, double y) {
    if (!_owns(slot, serial)) return;
    _toX[slot] = x;
    _toY[slot] = y;
  }

  /// Extends a live telegraph's window. Lethal zones that persist (a Thresher's
  /// aura) are refreshed rather than re-added every tick.
  void extend(int slot, int serial, double resolvesAt) {
    if (!_owns(slot, serial)) return;
    _resolvesAt[slot] = resolvesAt;
  }

  /// Follows a moving owner. The Thresher's crimson ring travels with it.
  void move(int slot, int serial, double x, double y) {
    if (!_owns(slot, serial)) return;
    _x[slot] = x;
    _y[slot] = y;
  }

  void release(int slot, int serial) {
    if (!_owns(slot, serial)) return;
    _alive[slot] = 0;
    _liveCount--;
  }

  /// Retires telegraphs whose moment has passed.
  ///
  /// A telegraph outliving its attack is not cosmetic: an amber ring still on
  /// the floor after the shell landed teaches the player to distrust the
  /// warning colour.
  void expire(double now) {
    for (int i = 0; i < capacity; i++) {
      if (_alive[i] == 0) continue;
      if (now >= _resolvesAt[i] + resolveLinger) {
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
    dropped = 0;
  }

  bool _owns(int slot, int serial) =>
      slot >= 0 &&
      slot < capacity &&
      _alive[slot] == 1 &&
      _serial[slot] == serial;
}
