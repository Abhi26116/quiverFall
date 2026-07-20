import 'dart:typed_data';

/// Haptic patterns, from docs/16-audio-direction.md §16.6.
///
/// **Haptics carry a real information channel here, not flavour.** The Draw
/// tier-up tick is how a player feels the ramp without looking at the arc, and
/// the Confluence double-tick is how they know they threaded a shot while their
/// own thumb is covering the crossing.
///
/// Kills deliberately have no haptic: at several per second it would be a
/// continuous buzz, which is worse than nothing because it drowns the two
/// patterns that matter.
enum HapticCue {
  /// Draw Tier II. Light tick.
  drawTierTwo,

  /// Draw Tier III. Medium tick — the reward, and the one players learn.
  drawTierThree,

  /// Sharp double-tick, scaling with stacks.
  confluence,

  /// Heavy thud.
  playerHit,

  /// Slow rhythmic pulse below 25 % HP.
  lowHealth,
}

/// Sound cues, from docs/16-audio-direction.md §16.2.
///
/// Named for what happened, not for a filename. The audio layer owns the
/// mapping to assets, so a re-cut of the bell chord is a data change and the
/// simulation never learns that audio exists.
enum SfxCue {
  fireTierOne,
  fireTierTwo,

  /// Heavy thrum with a metallic bloom. The reward sound.
  fireTierThree,

  /// Soft rising pip at each tier.
  drawTierUp,

  /// **The single most important sound in the game.** Rises in pitch and
  /// richness with stack count, so a player hears their own execution
  /// improving: x1 is a clear bell, x2 adds a fifth, x3 adds an octave with a
  /// reverse-swell, x4/x5 are the full chord. The magnitude carried alongside
  /// this cue is the stack count.
  confluenceBell,

  momentumGain,
  momentumMax,

  enemyHit,
  enemyDeath,

  /// Muffled thud, and everything else ducks 6 dB for 180 ms.
  playerHit,

  playerDeath,

  /// Every enemy telegraph has a distinct rising directional cue. A player
  /// should be able to survive a room with their eyes closed for two seconds.
  telegraph,

  reaction,
  roomCleared,
}

/// A fixed-size queue of cues raised this frame.
///
/// The simulation and the feedback director are pure Dart and cannot play a
/// sound or buzz a phone. They raise cues; the platform layer drains this once
/// per frame and turns it into `HapticFeedback` and audio calls. That is the
/// same arrangement [SimEventBuffer] uses to keep the sim headless, applied one
/// layer out — and it is what lets the whole feedback stack be unit-tested.
///
/// Overflow drops the *newest*, unlike the particle pool: a queue this size is
/// only reachable in a pathological frame, and in that frame the sounds already
/// queued are the ones the player is mid-way through hearing.
class CueQueue {
  CueQueue({this.capacity = 32})
      : _haptics = Uint8List(capacity),
        _sfx = Uint8List(capacity),
        _sfxMagnitude = Int32List(capacity);

  final int capacity;

  final Uint8List _haptics;
  final Uint8List _sfx;
  final Int32List _sfxMagnitude;

  int _hapticCount = 0;
  int _sfxCount = 0;

  int get hapticCount => _hapticCount;

  int get sfxCount => _sfxCount;

  HapticCue hapticAt(int i) => HapticCue.values[_haptics[i]];

  SfxCue sfxAt(int i) => SfxCue.values[_sfx[i]];

  /// Stack count for [SfxCue.confluenceBell]; zero for everything else.
  int magnitudeAt(int i) => _sfxMagnitude[i];

  void haptic(HapticCue cue) {
    if (_hapticCount >= capacity) return;
    // Collapse repeats within a frame. Two kills on one tick must not produce
    // two buzzes — the hardware would merge them into one longer one anyway,
    // which feels like a different, wrong pattern.
    for (int i = 0; i < _hapticCount; i++) {
      if (_haptics[i] == cue.index) return;
    }
    _haptics[_hapticCount++] = cue.index;
  }

  void sfx(SfxCue cue, {int magnitude = 0}) {
    if (_sfxCount >= capacity) return;
    _sfx[_sfxCount] = cue.index;
    _sfxMagnitude[_sfxCount] = magnitude;
    _sfxCount++;
  }

  void clear() {
    _hapticCount = 0;
    _sfxCount = 0;
  }

  /// Counts cues of a type. For tests and the feel telemetry.
  int countOf(SfxCue cue) {
    int n = 0;
    for (int i = 0; i < _sfxCount; i++) {
      if (_sfx[i] == cue.index) n++;
    }
    return n;
  }

  bool hasHaptic(HapticCue cue) {
    for (int i = 0; i < _hapticCount; i++) {
      if (_haptics[i] == cue.index) return true;
    }
    return false;
  }
}

/// Something that can act on a cue: a haptic engine, an audio mixer, a test
/// spy.
///
/// The simulation and the feedback director are pure Dart and cannot buzz a
/// phone or play a sound. They raise cues; sinks turn them into platform calls.
/// One small interface is what keeps the whole feedback stack testable and lets
/// the audio layer be absent entirely — which, until the sound files exist, it
/// is.
abstract interface class CueSink {
  void onHaptic(HapticCue cue);

  /// [magnitude] carries the Confluence stack count for
  /// [SfxCue.confluenceBell], and is zero otherwise.
  void onSfx(SfxCue cue, int magnitude);
}

/// Drains a [CueQueue] into every sink, then clears it.
///
/// Called once per rendered frame rather than per tick: a frame containing two
/// simulation steps should not play the same bell twice, and the player cannot
/// perceive the 16 ms difference anyway.
void dispatchCues(CueQueue queue, List<CueSink> sinks) {
  for (int s = 0; s < sinks.length; s++) {
    final CueSink sink = sinks[s];
    for (int i = 0; i < queue.hapticCount; i++) {
      sink.onHaptic(queue.hapticAt(i));
    }
    for (int i = 0; i < queue.sfxCount; i++) {
      sink.onSfx(queue.sfxAt(i), queue.magnitudeAt(i));
    }
  }
  queue.clear();
}
