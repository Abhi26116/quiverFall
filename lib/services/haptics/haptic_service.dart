import 'package:flutter/services.dart';
import 'package:quiverfall/game/feel/cues.dart';

/// Turns haptic cues into platform vibrations.
///
/// docs/16 §16.6 treats haptics as **a real information channel, not flavour**.
/// The Draw tier-up tick is how a player feels the ramp without looking at the
/// arc, and the Confluence double-tick is how they know they threaded a shot
/// while their own thumb covers the crossing. That is why this maps cues to
/// distinct patterns rather than buzzing identically at everything.
///
/// Kills are deliberately absent from the mapping. At several per second a kill
/// haptic is a continuous buzz, which is worse than none — it drowns the two
/// patterns that carry meaning.
class HapticService implements CueSink {
  HapticService({this.enabled = true});

  /// Fully disableable, per docs/16 §16.6, and disabled by default on devices
  /// with poor haptic hardware. That detection is a Phase 18 concern; the flag
  /// exists now so nothing has to be rewired when it lands.
  bool enabled;

  /// Guards against re-firing a continuous pattern faster than the hardware can
  /// distinguish. Two buzzes 10 ms apart are felt as one longer, wrong one.
  static const Duration _minGap = Duration(milliseconds: 45);
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void onHaptic(HapticCue cue) {
    if (!enabled) return;

    final DateTime now = DateTime.now();
    if (now.difference(_last) < _minGap) return;
    _last = now;

    switch (cue) {
      case HapticCue.drawTierTwo:
        HapticFeedback.lightImpact();
      case HapticCue.drawTierThree:
        // The reward. Medium rather than light, because Tier III is the thing
        // the player is learning to reach.
        HapticFeedback.mediumImpact();
      case HapticCue.confluence:
        // "Sharp double-tick" (docs/16 §16.6). Selection clicks are the
        // crispest primitive Flutter exposes and read as a tick rather than a
        // thud, which is what distinguishes this from taking a hit.
        HapticFeedback.selectionClick();
        HapticFeedback.selectionClick();
      case HapticCue.playerHit:
        HapticFeedback.heavyImpact();
      case HapticCue.lowHealth:
        HapticFeedback.lightImpact();
    }
  }

  @override
  void onSfx(SfxCue cue, int magnitude) {
    // Sound is somebody else's job.
  }
}
