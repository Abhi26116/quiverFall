import 'package:quiverfall/core/logger.dart';
import 'package:quiverfall/game/pools/pool_report.dart';

/// Every pool in one place, so saturation is visible.
///
/// Pooling is not an optimisation in this project, it is the design: allocation
/// during combat is the primary source of GC jank on low-end Android
/// (docs/12 §12.11). The cost of that decision is that every pool has a ceiling
/// and every ceiling is a guess. This is how the guesses get checked.
class PoolRegistry {
  PoolRegistry({this.logger});

  final Logger? logger;

  final List<PoolReport> _pools = <PoolReport>[];

  void register(PoolReport pool) => _pools.add(pool);

  void registerAll(Iterable<PoolReport> pools) => _pools.addAll(pools);

  int get poolCount => _pools.length;

  Iterable<PoolReport> get pools => _pools;

  /// Total slots reserved. Sized against the 25 MB "sim + pools" line in
  /// docs/19 §19.5.
  int get totalCapacity =>
      _pools.fold(0, (int a, PoolReport p) => a + p.poolCapacity);

  int get totalLive => _pools.fold(0, (int a, PoolReport p) => a + p.poolLive);

  int get totalMisses =>
      _pools.fold(0, (int a, PoolReport p) => a + p.poolMisses);

  /// Pools that refused an allocation. Empty is the only acceptable steady
  /// state; anything else is a cap that needs raising or a leak that needs
  /// finding.
  List<PoolReport> get saturated =>
      _pools.where((PoolReport p) => p.poolMisses > 0).toList();

  /// Highest utilisation across all pools, in `[0, 1]`.
  ///
  /// Useful as a single number to watch during a soak: a pool sitting at 0.95
  /// has not failed yet but is one unlucky room from doing so.
  double get peakUtilisation {
    double peak = 0;
    for (final PoolReport pool in _pools) {
      if (pool.poolCapacity <= 0) continue;
      final double used = pool.poolLive / pool.poolCapacity;
      if (used > peak) peak = used;
    }
    return peak;
  }

  /// Logs anything that ran out. Called at room boundaries, where the cost of
  /// a string is affordable and the information is still actionable.
  void reportSaturation() {
    final List<PoolReport> full = saturated;
    if (full.isEmpty) return;

    for (final PoolReport pool in full) {
      logger?.w(
        '${pool.poolName} exhausted: ${pool.poolMisses} refused '
        '(capacity ${pool.poolCapacity})',
        tag: 'pool',
      );
    }
  }

  String summary() {
    final StringBuffer buffer = StringBuffer();
    for (final PoolReport pool in _pools) {
      final double used =
          pool.poolCapacity <= 0 ? 0 : pool.poolLive / pool.poolCapacity;
      buffer.writeln(
        '${pool.poolName.padRight(18)}'
        '${pool.poolLive.toString().padLeft(5)}/'
        '${pool.poolCapacity.toString().padLeft(5)}'
        '${'${(used * 100).toStringAsFixed(0)}%'.padLeft(6)}'
        '${pool.poolMisses > 0 ? '  MISSES ${pool.poolMisses}' : ''}',
      );
    }
    return buffer.toString();
  }
}
