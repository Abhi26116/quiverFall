import 'package:quiverfall/core/clock.dart';
import 'package:test/test.dart';

void main() {
  final DateTime origin = DateTime.utc(2026, 7, 19, 12);

  group('FakeClock', () {
    test('advance moves wall-clock and monotonic together', () {
      final FakeClock clock = FakeClock(origin);
      clock.advance(const Duration(hours: 2));
      expect(clock.nowUtc(), origin.add(const Duration(hours: 2)));
      expect(clock.elapsed(), const Duration(hours: 2));
    });

    test('setWallClock moves only wall-clock', () {
      final FakeClock clock = FakeClock(origin);
      clock.advance(const Duration(minutes: 5));
      clock.setWallClock(origin.add(const Duration(days: 30)));

      expect(clock.nowUtc(), origin.add(const Duration(days: 30)));
      expect(clock.elapsed(), const Duration(minutes: 5));
    });
  });

  group('TrustedClock — server time', () {
    test('projects server time forward monotonically', () {
      final FakeClock device = FakeClock(origin);
      final TrustedClock trusted = TrustedClock(device);

      // Device clock is an hour fast; server says otherwise.
      final DateTime serverNow = origin.subtract(const Duration(hours: 1));
      trusted.syncServerTime(serverNow);

      device.advance(const Duration(minutes: 10));

      expect(trusted.hasServerTime, isTrue);
      expect(trusted.nowUtc(), serverNow.add(const Duration(minutes: 10)));
    });

    test('falls back to device time when unsynced', () {
      final FakeClock device = FakeClock(origin);
      final TrustedClock trusted = TrustedClock(device);
      expect(trusted.hasServerTime, isFalse);
      expect(trusted.nowUtc(), origin);
    });
  });

  group('TrustedClock — Vigor anti-tamper', () {
    // The rule from docs/13-database.md §13.2: a player who moves their device
    // clock forward must not mint Vigor.

    test('credits real elapsed time normally', () {
      final FakeClock device = FakeClock(origin);
      final TrustedClock trusted = TrustedClock(device);

      final Duration anchorElapsed = device.elapsed();
      device.advance(const Duration(minutes: 30));

      final Duration credited = trusted.creditedSince(
        origin,
        sessionElapsedAtAnchor: anchorElapsed,
      );

      expect(credited, const Duration(minutes: 30));
    });

    test('refuses to credit a forward clock jump during a live session', () {
      final FakeClock device = FakeClock(origin);
      final TrustedClock trusted = TrustedClock(device);

      final Duration anchorElapsed = device.elapsed();

      // 2 real minutes pass...
      device.advance(const Duration(minutes: 2));
      // ...then the player sets their clock a week ahead.
      device.setWallClock(origin.add(const Duration(days: 7)));

      final Duration credited = trusted.creditedSince(
        origin,
        sessionElapsedAtAnchor: anchorElapsed,
      );

      // Only the 2 genuinely-elapsed minutes are credited.
      expect(credited, const Duration(minutes: 2));
    });

    test('credits wall-clock on a fresh launch, where offline time is real', () {
      // With no monotonic anchor (the app was not running), wall-clock is the
      // only signal available and genuine offline time must be honoured — or
      // closing the app would stop Vigor regen entirely.
      final FakeClock device =
          FakeClock(origin.add(const Duration(hours: 8)));
      final TrustedClock trusted = TrustedClock(device);

      final Duration credited = trusted.creditedSince(origin);

      expect(credited, const Duration(hours: 8));
    });

    test('credits nothing when the clock moves backwards', () {
      final FakeClock device =
          FakeClock(origin.subtract(const Duration(days: 1)));
      final TrustedClock trusted = TrustedClock(device);

      expect(trusted.creditedSince(origin), Duration.zero);
    });

    test('a full Vigor bar cannot be minted by clock manipulation', () {
      // End-to-end shape of the exploit: 30 Vigor at 1 per 6 minutes is 3 hours.
      final FakeClock device = FakeClock(origin);
      final TrustedClock trusted = TrustedClock(device);
      final Duration anchor = device.elapsed();

      device.advance(const Duration(seconds: 30));
      device.setWallClock(origin.add(const Duration(hours: 5)));

      final Duration credited =
          trusted.creditedSince(origin, sessionElapsedAtAnchor: anchor);
      final int vigorGained =
          credited.inMinutes ~/ VigorRegen.minutesPerPoint;

      expect(vigorGained, 0);
    });
  });
}

/// Mirrors the regen constant so the test reads as the rule it protects.
abstract final class VigorRegen {
  static const int minutesPerPoint = 6;
}
