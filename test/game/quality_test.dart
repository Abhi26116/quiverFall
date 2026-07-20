import 'package:quiverfall/game/device/quality_tier.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/windline_store.dart';
import 'package:quiverfall/services/device/device_benchmark.dart';
import 'package:quiverfall/services/device/quality_controller.dart';
import 'package:test/test.dart';

/// Quality tiers, the boot benchmark, and the two things allowed to change a
/// tier after boot.
void main() {
  group('the tier table matches docs/19 §19.4', () {
    test('every tier is internally consistent', () {
      for (final QualityTier tier in QualityTier.values) {
        expect(tier.targetFps, greaterThanOrEqualTo(30));
        expect(tier.particleDensity, inInclusiveRange(0.0, 1.0));
        expect(tier.parallaxLayers, greaterThanOrEqualTo(1));
        expect(
          tier.windlineBudget,
          lessThanOrEqualTo(SimConfig.maxWindlineSegments),
          reason: 'a budget above the buffer would index past the end of it',
        );
      }
    });

    test('tiers are monotonic — higher is never cheaper', () {
      const List<QualityTier> ascending = <QualityTier>[
        QualityTier.battery,
        QualityTier.balanced,
        QualityTier.high,
      ];

      for (int i = 1; i < ascending.length; i++) {
        final QualityTier lower = ascending[i - 1];
        final QualityTier higher = ascending[i];
        expect(higher.particleDensity, greaterThan(lower.particleDensity));
        expect(higher.windlineBudget, greaterThan(lower.windlineBudget));
        expect(
          higher.parallaxLayers,
          greaterThanOrEqualTo(lower.parallaxLayers),
        );
        expect(higher.enemyCap, greaterThanOrEqualTo(lower.enemyCap));
      }
    });

    test('Battery degrades to itself rather than off the bottom', () {
      expect(QualityTier.high.degraded, QualityTier.balanced);
      expect(QualityTier.balanced.degraded, QualityTier.battery);
      expect(QualityTier.battery.degraded, QualityTier.battery);
      expect(QualityTier.battery.isLowest, isTrue);
    });

    test('Battery turns shake off entirely', () {
      // Both a performance tier and the Reduce Motion accessibility setting
      // want zero, so they read the same number.
      expect(QualityTier.battery.shake.scale, 0);
      expect(QualityTier.high.shake.scale, 1.0);
    });
  });

  group('the boot benchmark', () {
    test('measures something and picks a tier', () {
      final BenchmarkResult result = const DeviceBenchmark().run();

      expect(result.ticksPerSecond, greaterThan(0));
      expect(result.millisPerTick, greaterThan(0));
      expect(QualityTier.values, contains(result.tier));
      // A developer machine should be comfortably inside the sim budget.
      expect(result.simBudgetHeadroom, greaterThan(1.0));
    });

    test('maps throughput to tiers at the documented thresholds', () {
      const double reference = DeviceBenchmark.referenceTicksPerSecond;

      expect(DeviceBenchmark.tierFor(reference * 3), QualityTier.high);
      expect(DeviceBenchmark.tierFor(reference), QualityTier.balanced);
      expect(DeviceBenchmark.tierFor(reference * 0.4), QualityTier.battery);
    });

    test('reports itself in a shape analytics can take', () {
      final BenchmarkResult result = const DeviceBenchmark().run();
      final Map<String, Object?> event = result.toAnalytics();
      expect(event['tier'], result.tier.name);
      expect(event.containsKey('ms_per_tick'), isTrue);
    });
  });

  group('the quality controller', () {
    test('the benchmark proposes and the player disposes', () {
      final QualityController controller = QualityController()
        ..applyBenchmark(QualityTier.battery);
      expect(controller.tier, QualityTier.battery);

      controller.setByPlayer(QualityTier.high);
      expect(controller.tier, QualityTier.high);

      // A later benchmark must not undo a deliberate choice.
      controller.applyBenchmark(QualityTier.battery);
      expect(controller.tier, QualityTier.high);
    });

    test('a player override outranks the thermal watchdog', () {
      // Someone who chose High on a phone that runs warm has made a trade. A
      // game that silently undoes their setting every eight minutes is arguing
      // with its user.
      final QualityController controller = QualityController()
        ..setByPlayer(QualityTier.high);

      expect(controller.degrade('thermal'), isFalse);
      expect(controller.tier, QualityTier.high);
      expect(controller.degradations, 0);
    });

    test('degradation is one-way and stops at the floor', () {
      final QualityController controller =
          QualityController(initial: QualityTier.high);

      expect(controller.degrade('thermal'), isTrue);
      expect(controller.tier, QualityTier.balanced);
      expect(controller.degrade('memory'), isTrue);
      expect(controller.tier, QualityTier.battery);
      expect(controller.degrade('thermal'), isFalse);
      expect(controller.degradations, 2);
    });
  });

  group('the thermal watchdog', () {
    ThermalWatchdog watchdogAt(QualityController controller) =>
        ThermalWatchdog(controller: controller);

    /// Feeds [seconds] of frames at a fixed frame time.
    void feed(ThermalWatchdog watchdog, double frameMs, double seconds) {
      final double dt = frameMs / 1000;
      final int frames = (seconds / dt).round();
      for (int i = 0; i < frames; i++) {
        watchdog.recordFrame(dt);
      }
    }

    test('a consistently slow device is not throttling', () {
      // Always-20 ms is the boot benchmark's problem, not the watchdog's. This
      // only catches a device that *was* fine.
      final QualityController controller =
          QualityController(initial: QualityTier.high);
      final ThermalWatchdog watchdog = watchdogAt(controller);

      feed(watchdog, 20, 12 * 60);
      expect(controller.tier, QualityTier.high);
    });

    test('a device that degrades past the threshold drops one tier', () {
      final QualityController controller =
          QualityController(initial: QualityTier.high);
      final ThermalWatchdog watchdog = watchdogAt(controller);

      // Two minutes healthy, establishing the baseline.
      feed(watchdog, 16, 120);
      expect(watchdog.baselineP95, isNotNull);
      expect(controller.tier, QualityTier.high);

      // Then well past the eight-minute mark, 60 % slower.
      feed(watchdog, 26, 9 * 60);
      expect(controller.tier, QualityTier.balanced);
      expect(controller.degradations, 1);
    });

    test('it fires at most once', () {
      final QualityController controller =
          QualityController(initial: QualityTier.high);
      final ThermalWatchdog watchdog = watchdogAt(controller);

      feed(watchdog, 16, 120);
      feed(watchdog, 40, 20 * 60);

      // One drop, not a slide to the floor: repeated degradation on a single
      // sustained session would end with every long player on Battery.
      expect(controller.degradations, 1);
    });
  });

  group('the Windline budget', () {
    test('wraps the ring at the budget, not at the buffer', () {
      final WindlineStore lines = WindlineStore()..budget = 32;

      for (int i = 0; i < 200; i++) {
        lines.add(
          fromX: i % 15 + 0.1,
          fromY: 1,
          toX: i % 15 + 1.0,
          toY: 2,
          expiresAt: 1e9,
          ownerIndex: 0,
          trailId: i,
        );
      }

      expect(lines.liveCount, lessThanOrEqualTo(32));
      // Everything above the budget must be dead, or a consumer scanning only
      // the active prefix would miss live geometry.
      for (int i = 32; i < lines.capacity; i++) {
        expect(lines.isAlive(i), isFalse);
      }
    });

    test('lowering the budget retires stranded segments', () {
      final WindlineStore lines = WindlineStore();
      for (int i = 0; i < 500; i++) {
        lines.add(
          fromX: 1,
          fromY: 1,
          toX: 2,
          toY: 2,
          expiresAt: 1e9,
          ownerIndex: 0,
          trailId: i,
        );
      }
      expect(lines.liveCount, 500);

      // A segment above a lowered ceiling would never expire — a permanent
      // Confluence target the player cannot see fading.
      lines.budget = QualityTier.battery.windlineBudget;
      expect(lines.liveCount, lessThanOrEqualTo(320));
      for (int i = 320; i < lines.capacity; i++) {
        expect(lines.isAlive(i), isFalse);
      }
    });

    test('the budget never exceeds the allocated buffer', () {
      final WindlineStore lines = WindlineStore()..budget = 99999;
      expect(lines.budget, lines.capacity);
    });

    test('duration is untouched by the budget', () {
      // The compromise in docs/19 §19.4: the *global* budget scales, per-player
      // Windline duration does not. Capping duration instead would break the
      // mechanic rather than scale it.
      final WindlineStore lines = WindlineStore()..budget = 32;
      final int slot = lines.add(
        fromX: 1,
        fromY: 1,
        toX: 2,
        toY: 2,
        expiresAt: 12.5,
        ownerIndex: 0,
        trailId: 1,
      );
      expect(lines.expiryAt(slot), 12.5);
    });
  });
}
