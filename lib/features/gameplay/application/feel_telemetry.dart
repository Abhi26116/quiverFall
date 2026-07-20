import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';

/// What the Phase 6 gate actually measures.
///
/// The roadmap is explicit that Phase 6 ends in **a decision gate, not a
/// checklist**: playtest with eight or more people who have not seen the game,
/// and measure two things.
///
///  1. **Does the median tester trigger Confluence within 7 minutes,
///     unprompted?** ADR 0002 made that possible at all; this is what tells us
///     whether it is *discoverable*.
///  2. **Does `draw_tier_distribution` show real Tier II/III usage?** A player
///     who never stops moving has not understood the trade the whole game is
///     built on, and no amount of VFX will fix that.
///
/// Recorded locally and in pure Dart. Phase 17 owns the analytics pipeline;
/// shipping a playtest that depends on it would put the gate behind a phase it
/// precedes.
class FeelTelemetry {
  /// Seconds spent in each Draw tier, indexed by [DrawTier.index].
  final List<double> tierSeconds = <double>[0, 0, 0];

  double sessionSeconds = 0;
  double movingSeconds = 0;

  int shotsFired = 0;

  /// Arrows that threaded at least one line.
  int shotsThreaded = 0;

  /// Confluences by stack count. Index 0 is unused.
  final List<int> confluenceByStacks = <int>[0, 0, 0, 0, 0, 0];

  /// Seconds into the session when Confluence first fired, or null.
  ///
  /// **The single most important number in the phase.** docs/03 §3.1 beat 6:00
  /// expects a first Confluence to fire accidentally by around seven minutes.
  double? firstConfluenceAt;

  int deaths = 0;
  int roomsCleared = 0;
  double damageTaken = 0;

  /// Fraction of the session spent at each tier.
  double tierShare(DrawTier tier) =>
      sessionSeconds <= 0 ? 0 : tierSeconds[tier.index] / sessionSeconds;

  /// Fraction of the session spent moving. The other half of the trade.
  double get movingShare =>
      sessionSeconds <= 0 ? 0 : movingSeconds / sessionSeconds;

  double get threadRate => shotsFired == 0 ? 0 : shotsThreaded / shotsFired;

  int get confluenceTotal =>
      confluenceByStacks.fold(0, (int a, int b) => a + b);

  double get confluencePerMinute =>
      sessionSeconds <= 0 ? 0 : confluenceTotal / (sessionSeconds / 60);

  /// **The gate.** True when this session cleared both bars.
  bool get passesGate =>
      firstConfluenceAt != null &&
      firstConfluenceAt! <= confluenceDiscoveryTarget &&
      tierShare(DrawTier.two) + tierShare(DrawTier.three) >= tierUsageTarget;

  /// Seven minutes, from docs/03 §3.1.
  static const double confluenceDiscoveryTarget = 7 * 60;

  /// A player spending less than this share of their time above Tier I has not
  /// engaged with the Draw. Not a design constant — a *reading* threshold,
  /// chosen so the gate has an unambiguous answer rather than a debate.
  static const double tierUsageTarget = 0.20;

  /// Call once per simulation tick, before the world's events are cleared.
  void recordTick(SimWorld world, {double dt = SimConfig.fixedStep}) {
    sessionSeconds += dt;
    tierSeconds[world.playerDraw.tier.index] += dt;

    if (world.entities.isAlive(world.player)) {
      final int p = world.player.index;
      final double vx = world.entities.velX[p];
      final double vy = world.entities.velY[p];
      if (vx != 0 || vy != 0) movingSeconds += dt;
    }

    final SimEventBuffer events = world.events;
    for (int i = 0; i < events.count; i++) {
      switch (events.typeAt(i)) {
        case SimEventType.arrowFired:
          shotsFired++;

        case SimEventType.confluenceTriggered:
          final int stacks = events.valueAAt(i).round();
          // The event fires once per stack gained, so the zero-to-one
          // transitions are what count *arrows* rather than stacks.
          if (stacks == 1) shotsThreaded++;
          if (stacks >= 0 && stacks < confluenceByStacks.length) {
            confluenceByStacks[stacks]++;
          }
          firstConfluenceAt ??= sessionSeconds;

        case SimEventType.playerHit:
          damageTaken += events.valueAAt(i);

        case SimEventType.roomCleared:
          roomsCleared++;

        case SimEventType.entityDied:
          if (events.entityAAt(i) == world.player.index &&
              !world.entities.isAlive(world.player)) {
            deaths++;
          }

        case SimEventType.entitySpawned:
        case SimEventType.damageDealt:
        case SimEventType.drawTierChanged:
        case SimEventType.momentumChanged:
        case SimEventType.telegraphStarted:
        case SimEventType.windlineCreated:
        case SimEventType.elementApplied:
        case SimEventType.reactionTriggered:
        case SimEventType.ultimateReady:
        case SimEventType.ultimateUsed:
        case SimEventType.playerDashed:
          break;
      }
    }
  }

  void reset() {
    for (int i = 0; i < tierSeconds.length; i++) {
      tierSeconds[i] = 0;
    }
    for (int i = 0; i < confluenceByStacks.length; i++) {
      confluenceByStacks[i] = 0;
    }
    sessionSeconds = 0;
    movingSeconds = 0;
    shotsFired = 0;
    shotsThreaded = 0;
    firstConfluenceAt = null;
    deaths = 0;
    roomsCleared = 0;
    damageTaken = 0;
  }

  /// A one-screen summary for the playtest overlay.
  ///
  /// Written to be read aloud by whoever is running the session, because that
  /// is how these numbers will actually be collected: eight people, one phone,
  /// somebody with a notebook.
  String summary() {
    final String first = firstConfluenceAt == null
        ? 'never'
        : '${firstConfluenceAt!.toStringAsFixed(1)}s';

    return 'session ${sessionSeconds.toStringAsFixed(0)}s  '
        'moving ${(movingShare * 100).toStringAsFixed(0)}%\n'
        'draw  I ${(tierShare(DrawTier.one) * 100).toStringAsFixed(0)}%  '
        'II ${(tierShare(DrawTier.two) * 100).toStringAsFixed(0)}%  '
        'III ${(tierShare(DrawTier.three) * 100).toStringAsFixed(0)}%\n'
        'confluence $confluenceTotal  first $first  '
        '${confluencePerMinute.toStringAsFixed(1)}/min  '
        'thread ${(threadRate * 100).toStringAsFixed(1)}%\n'
        'rooms $roomsCleared  deaths $deaths';
  }
}
