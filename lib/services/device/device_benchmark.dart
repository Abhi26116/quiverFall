import 'package:quiverfall/game/device/quality_tier.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';

/// Picks a graphics tier by measuring the device, at boot.
///
/// docs/19 §19.4 assigns the tier from a boot benchmark, overridable in
/// Settings. The alternative — a device allow-list — is what every shipped
/// mobile game eventually regrets: it is wrong on launch day for hardware that
/// did not exist when it was written, and it says nothing about a phone that is
/// hot, throttled, or sharing the CPU with three other apps.
///
/// **What this measures is the simulation, not the GPU**, and that is a
/// deliberate limitation rather than an oversight. Running a real raster
/// workload at boot would mean building a throwaway render surface, waiting on
/// vsync, and adding 200 ms to a cold start that has a 3.2 s budget
/// (docs/19 §19.7). Sim throughput correlates well enough with the single-core
/// performance that decides frame time on the low-end Android this exists for,
/// and the thermal watchdog corrects a wrong guess within a minute of play.
class DeviceBenchmark {
  const DeviceBenchmark();

  /// Simulation ticks the reference mid-tier device manages per second.
  ///
  /// Calibrated against the CI machine and deliberately conservative: guessing
  /// *low* costs a player some particles, and guessing high costs them frames.
  static const double referenceTicksPerSecond = 12000;

  /// Above this multiple of the reference, the device gets High.
  static const double highThreshold = 2.2;

  /// Below this, Battery.
  static const double batteryThreshold = 0.7;

  /// Ticks to run. Enough to be out of the JIT's warm-up and short enough to
  /// stay invisible inside the splash.
  static const int sampleTicks = 600;

  static const int warmUpTicks = 120;

  /// Runs the probe and returns the result.
  ///
  /// Synchronous and blocking, on purpose: it runs during the splash, where
  /// nothing else needs the frame, and yielding would let the measurement be
  /// interrupted by whatever the framework does next.
  BenchmarkResult run() {
    final SimWorld world = _peakLoadWorld();
    final InputSnapshot input = InputSnapshot()..set(0.6, 0.4);

    for (int i = 0; i < warmUpTicks; i++) {
      world.tick(input);
      world.events.clear();
    }

    final Stopwatch watch = Stopwatch()..start();
    for (int i = 0; i < sampleTicks; i++) {
      world.tick(input);
      world.events.clear();
    }
    watch.stop();

    final double seconds = watch.elapsedMicroseconds / 1e6;
    final double ticksPerSecond = seconds <= 0 ? 0 : sampleTicks / seconds;
    return BenchmarkResult(
      ticksPerSecond: ticksPerSecond,
      tier: tierFor(ticksPerSecond),
      millisPerTick: seconds * 1000 / sampleTicks,
    );
  }

  /// The tier a given throughput earns.
  static QualityTier tierFor(double ticksPerSecond) {
    final double ratio = ticksPerSecond / referenceTicksPerSecond;
    if (ratio >= highThreshold) return QualityTier.high;
    if (ratio < batteryThreshold) return QualityTier.battery;
    return QualityTier.balanced;
  }

  /// A room at the documented peak: the entity cap, moving, colliding.
  ///
  /// Deliberately built from bare entities rather than from the content table.
  /// The benchmark runs before content has necessarily loaded, and it must
  /// measure the *machine* — a probe whose result depended on which chapter
  /// happened to be cached would be measuring the wrong thing.
  SimWorld _peakLoadWorld() {
    final SimWorld world = SimWorld(seed: 0xB0071E)..autoFire = true;
    world.spawnPlayer(SimConfig.arenaWidth / 2, SimConfig.arenaHeight / 2);

    for (int i = 0; i < 89; i++) {
      final int id = world
          .spawnAt(
            EntityKind.enemy,
            0.8 + (i % 14) * 1.05,
            0.7 + (i ~/ 14) * 1.25,
            radius: 0.3,
            health: 1e9,
          )
          .index;
      // Drifting in every direction, so movement, the spatial hash and contact
      // all do real work rather than settling into a static heap.
      world.entities.velX[id] = ((i % 5) - 2) * 0.4;
      world.entities.velY[id] = ((i % 7) - 3) * 0.3;
    }
    return world;
  }
}

/// What the probe found.
class BenchmarkResult {
  const BenchmarkResult({
    required this.ticksPerSecond,
    required this.tier,
    required this.millisPerTick,
  });

  final double ticksPerSecond;
  final QualityTier tier;
  final double millisPerTick;

  /// Headroom against the 4.0 ms sim budget in docs/19 §19.1. Below 1.0 means
  /// the simulation alone cannot hold 60 Hz on this device, which is a finding
  /// worth logging rather than silently absorbing.
  double get simBudgetHeadroom => millisPerTick <= 0 ? 0 : 4.0 / millisPerTick;

  Map<String, Object?> toAnalytics() => <String, Object?>{
        'ticks_per_second': ticksPerSecond.round(),
        'ms_per_tick': double.parse(millisPerTick.toStringAsFixed(4)),
        'tier': tier.name,
      };

  @override
  String toString() => 'device: ${ticksPerSecond.round()} ticks/s, '
      '${millisPerTick.toStringAsFixed(3)} ms/tick -> ${tier.name}';
}
