import 'package:quiverfall/core/logger.dart';
import 'package:quiverfall/game/device/quality_tier.dart';

/// Owns the active quality tier for a session.
///
/// Three things can change it, and they are not equal:
///
///  - The **boot benchmark** proposes a starting tier.
///  - The **player** overrides it in Settings, and their choice sticks.
///  - The **thermal watchdog** and **memory warnings** drop it, once each.
///
/// A player override outranks the watchdog. Someone who has deliberately
/// chosen High on a phone that gets warm has made a trade, and a game that
/// silently undoes their setting every eight minutes is a game arguing with
/// its user — so an override is honoured and the degradation is logged instead.
class QualityController {
  QualityController({
    QualityTier initial = QualityTier.balanced,
    this.logger,
  }) : _tier = initial;

  final Logger? logger;

  QualityTier _tier;
  bool _playerOverridden = false;
  int _degradations = 0;

  QualityTier get tier => _tier;

  bool get isPlayerOverridden => _playerOverridden;

  /// How many times this session has been degraded. Reported with the
  /// `device_benchmark` analytics event so a tier that is wrong for a whole
  /// population is visible in aggregate rather than one support ticket at a
  /// time.
  int get degradations => _degradations;

  /// Applies the boot benchmark's verdict. Ignored once the player has chosen.
  void applyBenchmark(QualityTier proposed) {
    if (_playerOverridden) return;
    _tier = proposed;
    logger?.i('quality tier from benchmark: ${proposed.name}', tag: 'device');
  }

  /// The player's explicit choice, which outranks everything after it.
  void setByPlayer(QualityTier chosen) {
    _playerOverridden = true;
    _tier = chosen;
    logger?.i('quality tier set by player: ${chosen.name}', tag: 'device');
  }

  /// Drops one tier. Returns whether anything changed.
  ///
  /// Used by the thermal watchdog and by `memory_warning`. Both are one-way:
  /// there is no automatic recovery, because a device that throttled once will
  /// throttle again and a tier oscillating every few minutes is far more
  /// noticeable than a slightly conservative one.
  bool degrade(String reason) {
    if (_playerOverridden) {
      logger?.w(
        'would degrade for $reason, but the player has chosen ${_tier.name}',
        tag: 'device',
      );
      return false;
    }
    if (_tier.isLowest) return false;

    _tier = _tier.degraded;
    _degradations++;
    logger?.w('quality dropped to ${_tier.name} ($reason)', tag: 'device');
    return true;
  }
}

/// Watches frame times and degrades when the device starts throttling.
///
/// docs/19 §19.6: "after 8 min of sustained load, if p95 frame time degrades
/// >25 %, silently drop one quality tier and log it."
///
/// The comparison is against this session's *own* early baseline rather than
/// against an absolute target. A phone that has always run at 20 ms is not
/// throttling, it is slow, and that is the boot benchmark's problem; what this
/// catches is a device that was fine and then got hot.
class ThermalWatchdog {
  ThermalWatchdog({required this.controller});

  final QualityController controller;

  /// Seconds of play before a baseline is taken, and before degradation is
  /// allowed. Long enough that shader warm-up and the first room's asset reads
  /// are behind us.
  static const double baselineAfterSeconds = 60;

  static const double checkAfterSeconds = 8 * 60;

  /// Fractional frame-time regression that counts as throttling.
  static const double regressionThreshold = 0.25;

  final List<double> _window = <double>[];
  static const int _windowSize = 600;

  double _elapsed = 0;
  double? _baselineP95;
  bool _fired = false;

  double? get baselineP95 => _baselineP95;

  /// Feeds one frame. Returns true on the frame a degradation happens.
  bool recordFrame(double frameSeconds) {
    _elapsed += frameSeconds;

    _window.add(frameSeconds * 1000);
    if (_window.length > _windowSize) _window.removeAt(0);
    if (_window.length < _windowSize) return false;

    if (_baselineP95 == null) {
      if (_elapsed < baselineAfterSeconds) return false;
      _baselineP95 = _p95();
      return false;
    }

    if (_fired || _elapsed < checkAfterSeconds) return false;

    final double now = _p95();
    final double baseline = _baselineP95!;
    if (baseline <= 0) return false;

    if ((now - baseline) / baseline < regressionThreshold) return false;

    _fired = true;
    return controller.degrade(
      'thermal: p95 ${now.toStringAsFixed(1)}ms vs '
      'baseline ${baseline.toStringAsFixed(1)}ms',
    );
  }

  double _p95() {
    final List<double> sorted = List<double>.of(_window)..sort();
    return sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];
  }

  void reset() {
    _window.clear();
    _elapsed = 0;
    _baselineP95 = null;
    _fired = false;
  }
}
