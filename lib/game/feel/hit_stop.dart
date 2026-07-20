import 'package:quiverfall/game/feel/juice.dart';

/// The freeze-frame on a kill.
///
/// Forty milliseconds of held time is the single cheapest piece of game feel
/// available: it converts "the enemy's health reached zero" into "you hit it",
/// which is a different sentence. docs/10 §10.6 lists it as one of the four
/// mandatory parts of the feedback stack.
///
/// **Hit-stop gates whole simulation ticks. It never scales `dt`.**
///
/// That distinction is not stylistic. The simulation runs at a fixed 60 Hz and
/// its determinism depends on that being true on every device — scaling `dt` to
/// slow time down would produce a different game from the same seed and inputs,
/// silently invalidating every replay, the balance harness, and any future
/// server-side validation (docs/12 §12.4). Holding whole ticks changes *when*
/// the world advances in wall-clock time and nothing at all about the sequence
/// of states it passes through.
class HitStop {
  HitStop({this.enabled = true});

  /// Reduce Motion leaves hit-stop on: it is information, not decoration, and
  /// it does not move anything on screen. Exposed for completeness because
  /// accessibility testing may yet decide otherwise.
  bool enabled;

  double _remaining = 0;

  /// True while the simulation should be held.
  bool get isFrozen => _remaining > 0;

  double get remaining => _remaining;

  /// Fraction of the freeze still to run, in `[0, 1]`. The renderer can use
  /// this to hold an impact flash exactly as long as the freeze.
  double get progress =>
      _remaining <= 0 ? 0 : (_remaining / Juice.maxFreezeSeconds).clamp(0, 1);

  /// Requests a freeze. **Longest wins; they never accumulate.**
  ///
  /// A pierced arrow killing four enemies on one tick, or a Steamburst clearing
  /// a pack, would otherwise queue four freezes back to back and read as a
  /// dropped frame rather than as impact.
  void request(double seconds) {
    if (!enabled || seconds <= 0) return;
    final double capped =
        seconds > Juice.maxFreezeSeconds ? Juice.maxFreezeSeconds : seconds;
    if (capped > _remaining) _remaining = capped;
  }

  void requestKill() => request(Juice.killFreezeSeconds);

  void requestConfluenceKill() => request(Juice.confluenceFreezeSeconds);

  /// Consumes real elapsed time. Returns the time the simulation may use.
  ///
  /// While frozen this returns zero, so the caller's fixed-step accumulator
  /// receives nothing and the world simply does not advance. Time not consumed
  /// by the freeze is passed through in the same call, so the frame that ends a
  /// freeze is not also a frame that drops its remainder.
  double consume(double realDt) {
    if (_remaining <= 0) return realDt;

    if (realDt < _remaining) {
      _remaining -= realDt;
      return 0;
    }

    final double leftover = realDt - _remaining;
    _remaining = 0;
    return leftover;
  }

  void reset() => _remaining = 0;
}
