import 'package:quiverfall/core/logger.dart';
import 'package:quiverfall/game/feel/cues.dart';

/// Where sound would go.
///
/// **There are no audio assets in this repository yet.** docs/16 specifies
/// roughly 400 sounds, including the one that matters most for Phase 6 — the
/// Confluence bell chord, which rises in pitch and richness with stack count so
/// a player hears their own execution improving. Those are an audio-production
/// deliverable, not something code can conjure, and faking them with
/// synthesised beeps would make the Phase 6 playtest measure a different game
/// from the one being shipped.
///
/// So this is the port, complete and wired, with the mapping from cue to asset
/// key already decided. Dropping the files in and swapping [SilentAudioSink]
/// for a real `audioplayers` adapter is then a change in one class, and nothing
/// upstream — not the simulation, not the feedback director, not the renderer —
/// learns that audio has arrived.
///
/// See docs/12-architecture.md on ports: the same arrangement that keeps
/// `AnalyticsPort` from blocking the iOS build keeps missing sound from
/// blocking the game-feel gate.
abstract interface class AudioPort implements CueSink {
  /// Preloads everything a room needs, so the first Confluence of a run is not
  /// the one that stutters. docs/19 §19.3 makes the same point about shaders.
  Future<void> warmUp();

  Future<void> dispose();
}

/// Asset keys for every cue, in one table.
///
/// Named rather than inlined because the Confluence chord is **five files, not
/// one** — x1 is a clear bell, x2 adds a fifth, x3 adds an octave with a
/// reverse-swell, x4/x5 are the full chord (docs/16 §16.2). Resolving stack
/// count to file is a decision, and it belongs somewhere a sound designer can
/// read it.
abstract final class SfxAssets {
  static const String _root = 'audio/sfx';

  /// Resolves a cue to an asset path.
  ///
  /// [magnitude] is the Confluence stack count and is ignored for every other
  /// cue.
  static String pathFor(SfxCue cue, int magnitude) {
    if (cue == SfxCue.confluenceBell) {
      final int stacks = magnitude < 1 ? 1 : (magnitude > 5 ? 5 : magnitude);
      return '$_root/confluence_x$stacks.ogg';
    }
    return '$_root/${_names[cue.index]}.ogg';
  }

  static const List<String> _names = <String>[
    'fire_tier_1',
    'fire_tier_2',
    'fire_tier_3',
    'draw_tier_up',
    'confluence_x1',
    'momentum_gain',
    'momentum_max',
    'enemy_hit',
    'enemy_death',
    'player_hit',
    'player_death',
    'telegraph',
    'reaction',
    'room_cleared',
  ];

  /// Priority for the 24-voice limit in docs/16 §16.5. Confluence and telegraph
  /// sounds hold the highest priority and are **never evicted** — one is the
  /// game's signature payoff and the other is how a player survives a room they
  /// are not looking at.
  static int priorityOf(SfxCue cue) => switch (cue) {
        SfxCue.confluenceBell => 100,
        SfxCue.telegraph => 90,
        SfxCue.playerHit || SfxCue.playerDeath => 80,
        SfxCue.fireTierThree || SfxCue.reaction => 60,
        SfxCue.drawTierUp || SfxCue.momentumMax => 50,
        SfxCue.roomCleared => 40,
        SfxCue.fireTierOne || SfxCue.fireTierTwo => 30,
        SfxCue.enemyDeath => 25,
        SfxCue.enemyHit || SfxCue.momentumGain => 10,
      };
}

/// The audio port until there is audio.
///
/// Not a stub that does nothing silently: in debug it logs what *would* have
/// played, which is how the Phase 6 playtest can still verify that the bell
/// fires on the right stack count even with the speakers off.
class SilentAudioSink implements AudioPort {
  SilentAudioSink({this.logger, this.trace = false});

  final Logger? logger;

  /// Logging every `enemy_hit` would drown the console. Off unless a session is
  /// specifically auditing cue timing.
  final bool trace;

  int _played = 0;

  /// How many sounds this session would have played. Surfaced so a silent build
  /// can still answer "is the audio layer being driven at all".
  int get playedCount => _played;

  @override
  Future<void> warmUp() async {}

  @override
  void onHaptic(HapticCue cue) {
    // Vibration is somebody else's job.
  }

  @override
  void onSfx(SfxCue cue, int magnitude) {
    _played++;
    if (!trace) return;
    logger?.d(SfxAssets.pathFor(cue, magnitude), tag: 'sfx');
  }

  @override
  Future<void> dispose() async {}
}
