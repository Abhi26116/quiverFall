import 'package:meta/meta.dart';

/// Source of the current time.
///
/// Nothing in Quiverfall calls [DateTime.now] directly. Time is injected so
/// that:
///
///  - Vigor regen, daily resets, quest rotation, and chest timers are testable
///    without waiting or sleeping.
///  - The simulation stays deterministic ([docs/12-architecture.md] §12.0).
///  - Clock skew is detectable. A player who sets their device clock forward
///    must not mint Vigor, so the economy reads time through
///    [TrustedClock], which prefers a server timestamp and refuses to go
///    backwards.
abstract interface class Clock {
  DateTime nowUtc();

  /// Monotonic elapsed time since an arbitrary origin.
  ///
  /// Unlike [nowUtc] this cannot be moved by the user or by NTP, so it is the
  /// correct basis for measuring durations.
  Duration elapsed();
}

/// The real clock. Registered in production.
final class SystemClock implements Clock {
  SystemClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  Duration elapsed() => _stopwatch.elapsed;
}

/// A clock the test controls completely.
final class FakeClock implements Clock {
  FakeClock(this._now, {Duration elapsed = Duration.zero}) : _elapsed = elapsed;

  DateTime _now;
  Duration _elapsed;

  @override
  DateTime nowUtc() => _now;

  @override
  Duration elapsed() => _elapsed;

  /// Moves both wall-clock and monotonic time forward.
  void advance(Duration by) {
    _now = _now.add(by);
    _elapsed += by;
  }

  /// Moves wall-clock time only — simulating a user changing their device
  /// clock. Monotonic time is deliberately unaffected, which is exactly how
  /// [TrustedClock] detects the tamper.
  void setWallClock(DateTime to) => _now = to;
}

/// Wraps a [Clock] with server-time preference and a monotonic tamper guard.
///
/// Used by every system that grants a resource over time (Vigor regen, daily
/// login, chest timers). The rule, from [docs/13-database.md] §13.2: elapsed
/// time is credited as the *smaller* of wall-clock elapsed and monotonic
/// elapsed. Moving the device clock forward therefore grants nothing, while
/// legitimate offline time (where the app was not running, so monotonic time
/// did not advance either) is credited from the persisted anchor.
final class TrustedClock {
  TrustedClock(this._clock);

  final Clock _clock;

  DateTime? _serverNow;
  Duration? _serverSyncedAtElapsed;

  /// Records a trusted timestamp, typically from a server response header.
  void syncServerTime(DateTime serverUtc) {
    _serverNow = serverUtc;
    _serverSyncedAtElapsed = _clock.elapsed();
  }

  bool get hasServerTime => _serverNow != null;

  /// Best available "now": server time projected forward monotonically if we
  /// have it, device wall-clock otherwise.
  DateTime nowUtc() {
    final DateTime? server = _serverNow;
    final Duration? syncedAt = _serverSyncedAtElapsed;
    if (server != null && syncedAt != null) {
      return server.add(_clock.elapsed() - syncedAt);
    }
    return _clock.nowUtc();
  }

  /// Credits elapsed time since [anchor], resistant to forward clock changes.
  ///
  /// [sessionElapsedAtAnchor] is the monotonic reading taken when [anchor] was
  /// written. When it is available and the app has been running continuously,
  /// wall-clock movement beyond monotonic movement is treated as tampering and
  /// discarded. When it is absent (a fresh launch, so genuine offline time has
  /// passed), wall-clock is trusted, since that is the only signal available.
  @useResult
  Duration creditedSince(
    DateTime anchor, {
    Duration? sessionElapsedAtAnchor,
  }) {
    final Duration wall = nowUtc().difference(anchor);
    if (wall.isNegative) {
      // Clock moved backwards — credit nothing rather than going negative.
      return Duration.zero;
    }
    if (sessionElapsedAtAnchor == null) {
      return wall;
    }
    final Duration monotonic = _clock.elapsed() - sessionElapsedAtAnchor;
    return wall <= monotonic ? wall : monotonic;
  }

  Duration elapsed() => _clock.elapsed();
}
