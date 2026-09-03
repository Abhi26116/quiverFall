import 'dart:math' as math;
import 'dart:typed_data';

import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/feel/burst_pool.dart';
import 'package:quiverfall/game/feel/cues.dart';
import 'package:quiverfall/game/feel/damage_number_pool.dart';
import 'package:quiverfall/game/feel/feel_palette.dart';
import 'package:quiverfall/game/feel/hit_stop.dart';
import 'package:quiverfall/game/feel/juice.dart';
import 'package:quiverfall/game/feel/particle_pool.dart';
import 'package:quiverfall/game/feel/screen_shake.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';

/// Turns simulation events into everything the player feels.
///
/// **This class is Phase 6.** The simulation never plays a sound, spawns a
/// particle or shakes a camera — it cannot, having no Flutter imports — so it
/// emits events and something has to translate them. That something is here,
/// and keeping it pure Dart means the entire feedback stack is unit-testable:
/// "a kill produces exactly one freeze-frame, twelve particles and no haptic"
/// is an assertion, not a thing you squint at.
///
/// docs/10 §10.6 specifies the per-hit stack as all four, every time: hit-flash,
/// a directional impact particle, a 40 ms freeze-frame on kills only, and a
/// haptic. They are a set because they only work as one.
class FeedbackDirector {
  FeedbackDirector({
    required this.world,
    ScreenShake? shake,
    HitStop? hitStop,
    ParticlePool? particles,
    BurstPool? bursts,
    DamageNumberPool? damageNumbers,
    CueQueue? cues,
  })  : shake = shake ?? ScreenShake(),
        hitStop = hitStop ?? HitStop(),
        particles = particles ?? ParticlePool(),
        bursts = bursts ?? BurstPool(),
        damageNumbers = damageNumbers ?? DamageNumberPool(),
        cues = cues ?? CueQueue(),
        _flash = Float64List(SimConfig.maxEntities),
        _arrowConfluence = Int32List(SimConfig.maxEntities);

  final SimWorld world;

  final ScreenShake shake;
  final HitStop hitStop;
  final ParticlePool particles;
  final BurstPool bursts;
  final DamageNumberPool damageNumbers;
  final CueQueue cues;

  /// Per-slot hit-flash timers.
  final Float64List _flash;

  /// Confluence stacks carried by each live arrow.
  ///
  /// Tracked here rather than read from [ProjectileStore] at damage time
  /// because the arrow that lands a killing blow is reset in the same tick, so
  /// by the time this drains its stack count is already gone. Seeded on
  /// `arrowFired`, which always precedes any Confluence for that slot and is
  /// also what makes slot reuse safe.
  final Int32List _arrowConfluence;

  /// Seconds remaining on the Tier III snap flare around the player's feet.
  double _tierSnap = 0;

  double get tierSnap => _tierSnap;

  /// Whether the player is below the low-HP pulse threshold.
  bool _lowHealthPulsing = false;

  double _lowHealthTimer = 0;

  /// Hit-flash intensity for an entity slot, in `[0, 1]`.
  double flashAt(int slot) =>
      _flash[slot] <= 0 ? 0 : _flash[slot] / Juice.hitFlashSeconds;

  /// Drains the simulation's events into presentation state.
  ///
  /// **Call once per simulation tick, not once per rendered frame.** Several
  /// events read state that the next tick overwrites — an arrow's Confluence
  /// stacks, a dying enemy's position — and a frame may contain two ticks.
  void drainEvents() {
    final SimEventBuffer events = world.events;

    for (int i = 0; i < events.count; i++) {
      switch (events.typeAt(i)) {
        case SimEventType.arrowFired:
          _onArrowFired(events, i);
        case SimEventType.damageDealt:
          _onDamage(events, i);
        case SimEventType.entityDied:
          _onDeath(events, i);
        case SimEventType.playerHit:
          _onPlayerHit(events, i);
        case SimEventType.drawTierChanged:
          _onDrawTier(events, i);
        case SimEventType.momentumChanged:
          _onMomentum(events, i);
        case SimEventType.confluenceTriggered:
          _onConfluence(events, i);
        case SimEventType.reactionTriggered:
          _onReaction(events, i);
        case SimEventType.roomCleared:
          cues.sfx(SfxCue.roomCleared);
        case SimEventType.telegraphStarted:
          // Highest audio priority alongside Confluence (docs/16 §16.5), and
          // never evicted: this is the sound a player survives a room by.
          cues.sfx(SfxCue.telegraph);
        case SimEventType.entitySpawned:
        case SimEventType.windlineCreated:
        case SimEventType.elementApplied:
        case SimEventType.ultimateReady:
        case SimEventType.ultimateUsed:
        case SimEventType.playerDashed:
          break;
        // docs/06 §6.0 rule 1 wants this "a hard visual and musical
        // transition" — a dedicated boss juice pass (screen-wide flash, its
        // own SfxCue) belongs with the first boss that actually ships a
        // fight, not bolted onto the generic director ahead of any boss
        // having a phase-specific look to cut to.
        case SimEventType.bossPhaseChanged:
          break;
      }
    }
  }

  /// Advances presentation timers. Driven by *real* time, not simulation time,
  /// so effects keep animating during a freeze-frame — which is the entire
  /// point of a freeze-frame.
  void update(double realDt) {
    shake.update(realDt);
    particles.update(realDt);
    bursts.update(realDt);
    damageNumbers.update(realDt);

    if (_tierSnap > 0) _tierSnap -= realDt;

    for (int i = 0; i < _flash.length; i++) {
      if (_flash[i] > 0) _flash[i] -= realDt;
    }

    _updateLowHealth(realDt);
  }

  void reset() {
    shake.reset();
    hitStop.reset();
    particles.clear();
    bursts.clear();
    damageNumbers.clear();
    cues.clear();
    _tierSnap = 0;
    _lowHealthPulsing = false;
    _lowHealthTimer = 0;
    for (int i = 0; i < _flash.length; i++) {
      _flash[i] = 0;
      _arrowConfluence[i] = 0;
    }
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  void _onArrowFired(SimEventBuffer events, int i) {
    final int slot = events.entityAAt(i);
    if (slot >= 0 && slot < _arrowConfluence.length) {
      _arrowConfluence[slot] = 0;
    }

    // Fire sound is tier-coded, and deliberately so: docs/16 §16.2 makes Tier
    // III "unmistakable, this is the reward sound". A player who can hear their
    // own tier does not have to look at the arc.
    cues.sfx(
      switch (DrawTier.values[events.valueAAt(i).round()]) {
        DrawTier.one => SfxCue.fireTierOne,
        DrawTier.two => SfxCue.fireTierTwo,
        DrawTier.three => SfxCue.fireTierThree,
      },
    );
  }

  void _onDamage(SimEventBuffer events, int i) {
    final int target = events.entityAAt(i);
    final int arrow = events.entityBAt(i);
    final double damage = events.valueAAt(i);
    final double x = events.xAt(i);
    final double y = events.yAt(i);

    if (target >= 0 && target < _flash.length) {
      _flash[target] = Juice.hitFlashSeconds;
    }

    final int stacks = (arrow >= 0 && arrow < _arrowConfluence.length)
        ? _arrowConfluence[arrow]
        : 0;

    // Directional, not radial: the spray points away from where the arrow came
    // from, which tells the player the direction of the hit rather than merely
    // that one happened.
    final double angle = _impactAngle(arrow);
    particles.burst(
      atX: x,
      atY: y,
      count: Juice.particlesPerHit,
      argb: stacks > 0 ? FeelPalette.whiteHot : FeelPalette.accent,
      towardAngle: angle,
      spread: 0.8,
    );

    cues.sfx(SfxCue.enemyHit);

    damageNumbers.maybeAdd(
      atX: x,
      atY: y,
      damage: damage,
      targetMaxHealth: target >= 0 && target < SimConfig.maxEntities
          ? world.entities.maxHealth[target]
          : 0,
      numberKind:
          stacks > 0 ? DamageNumberKind.confluence : DamageNumberKind.normal,
      confluenceStacks: stacks,
    );
  }

  void _onDeath(SimEventBuffer events, int i) {
    final int slot = events.entityAAt(i);
    final double x = events.xAt(i);
    final double y = events.yAt(i);

    // The player's own death is not a kill, and must not read like one.
    if (slot == world.player.index && !world.entities.isAlive(world.player)) {
      cues.sfx(SfxCue.playerDeath);
      shake.addTrauma(Juice.traumaOnPlayerHit);
      return;
    }

    // The freeze is requested, not applied: longest wins, and a pierce that
    // kills four enemies on one tick produces one freeze rather than four.
    hitStop.requestKill();
    shake.addTrauma(Juice.traumaOnKill);

    final int argb = _familyColourOf(slot);
    particles.burst(
      atX: x,
      atY: y,
      count: Juice.particlesPerKill,
      argb: argb,
      speedScale: 1.25,
    );
    bursts.spawn(
      atX: x,
      atY: y,
      toRadius: 0.7,
      seconds: 0.24,
      argb: argb,
    );

    cues.sfx(SfxCue.enemyDeath);
    // No haptic on kills. At several per second it would be a continuous buzz
    // that drowns the two patterns carrying real information.
  }

  void _onPlayerHit(SimEventBuffer events, int i) {
    shake.addTrauma(Juice.traumaOnPlayerHit);
    shake.punch(Juice.punchOnPlayerHit);
    cues
      ..haptic(HapticCue.playerHit)
      ..sfx(SfxCue.playerHit);

    particles.burst(
      atX: events.xAt(i),
      atY: events.yAt(i),
      count: Juice.particlesPerHit,
      argb: FeelPalette.danger,
    );
  }

  void _onDrawTier(SimEventBuffer events, int i) {
    final DrawTier now = DrawTier.values[events.valueAAt(i).round()];
    final DrawTier before = DrawTier.values[events.valueBAt(i).round()];

    // Only on the way up. Losing a tier is the cost of moving, and buzzing the
    // player for a decision they just made deliberately is nagging.
    if (now.index <= before.index) return;

    cues.sfx(SfxCue.drawTierUp);
    switch (now) {
      case DrawTier.two:
        cues.haptic(HapticCue.drawTierTwo);
      case DrawTier.three:
        cues.haptic(HapticCue.drawTierThree);
        _tierSnap = Juice.tierSnapSeconds;
      case DrawTier.one:
        break;
    }
  }

  void _onMomentum(SimEventBuffer events, int i) {
    final int now = events.valueAAt(i).round();
    final int before = events.valueBAt(i).round();
    if (now <= before) return;

    cues.sfx(
      now >= world.playerDraw.maxMomentum
          ? SfxCue.momentumMax
          : SfxCue.momentumGain,
    );
  }

  void _onConfluence(SimEventBuffer events, int i) {
    final int arrow = events.entityAAt(i);
    final int stacks = events.valueAAt(i).round();

    if (arrow >= 0 && arrow < _arrowConfluence.length) {
      _arrowConfluence[arrow] = stacks;
    }

    // The burst is drawn at the crossing point, which is how the player learns
    // *where* they threaded rather than only that they did.
    bursts.spawn(
      atX: events.xAt(i),
      atY: events.yAt(i),
      toRadius: Juice.confluenceBurstRadius +
          Juice.confluenceBurstPerStack * (stacks - 1),
      seconds: Juice.confluenceBurstSeconds,
      argb: FeelPalette.whiteHot,
      stacks: stacks,
    );
    particles.burst(
      atX: events.xAt(i),
      atY: events.yAt(i),
      count: Juice.particlesPerConfluence,
      argb: FeelPalette.whiteHot,
      speedScale: 1.4,
    );

    shake
      ..addTrauma(Juice.traumaOnConfluence * stacks)
      ..punch(Juice.punchOnConfluence * stacks);

    // The bell chord and the double-tick are the two channels a player can read
    // with their thumb over the crossing. Both scale with stacks.
    cues
      ..haptic(HapticCue.confluence)
      ..sfx(SfxCue.confluenceBell, magnitude: stacks);
  }

  void _onReaction(SimEventBuffer events, int i) {
    shake.addTrauma(Juice.traumaOnReaction);
    bursts.spawn(
      atX: events.xAt(i),
      atY: events.yAt(i),
      toRadius: 1.4,
      seconds: 0.36,
      argb: FeelPalette.whiteHot,
    );
    cues.sfx(SfxCue.reaction);
  }

  void _updateLowHealth(double realDt) {
    if (!world.entities.isAlive(world.player)) {
      _lowHealthPulsing = false;
      return;
    }

    final int p = world.player.index;
    final double max = world.entities.maxHealth[p];
    final double fraction = max <= 0 ? 1.0 : world.entities.health[p] / max;

    _lowHealthPulsing = fraction < _lowHealthThreshold;
    if (!_lowHealthPulsing) {
      _lowHealthTimer = 0;
      return;
    }

    // A slow 1 Hz pulse, per docs/16 §16.6. Deliberately not tied to the sim
    // clock: it is a state, not an event, and it should keep beating through a
    // freeze-frame.
    _lowHealthTimer += realDt;
    if (_lowHealthTimer >= 1.0) {
      _lowHealthTimer -= 1.0;
      cues.haptic(HapticCue.lowHealth);
    }
  }

  static const double _lowHealthThreshold = 0.25;

  /// Angle a hit's debris should travel, away from the shooter.
  double _impactAngle(int arrow) {
    if (arrow < 0 || arrow >= SimConfig.maxEntities) return 0;
    // Velocity is the arrow's direction of travel, which is the direction the
    // debris should continue in.
    final double vx = world.entities.velX[arrow];
    final double vy = world.entities.velY[arrow];
    if (vx == 0 && vy == 0) return 0;
    return math.atan2(vy, vx);
  }

  int _familyColourOf(int slot) {
    if (slot < 0 || slot >= SimConfig.maxEntities) return FeelPalette.inkDim;
    if (world.entities.kind[slot] != EntityKind.enemy.index) {
      return FeelPalette.inkDim;
    }
    final int content = world.entities.contentIndex[slot];
    if (content < 0 || content >= world.content.enemies.length) {
      return FeelPalette.inkDim;
    }
    final EnemyFamily family = world.content.enemies[content].family;
    return FeelPalette.byFamily[family.index];
  }
}
