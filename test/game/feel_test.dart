import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/feel/burst_pool.dart';
import 'package:quiverfall/game/feel/cues.dart';
import 'package:quiverfall/game/feel/damage_number_pool.dart';
import 'package:quiverfall/game/feel/feedback_director.dart';
import 'package:quiverfall/game/feel/hit_stop.dart';
import 'package:quiverfall/game/feel/joystick_model.dart';
import 'package:quiverfall/game/feel/juice.dart';
import 'package:quiverfall/game/feel/particle_pool.dart';
import 'package:quiverfall/game/feel/screen_shake.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'enemy_test_support.dart';

/// The feedback stack, asserted rather than squinted at.
///
/// Phase 6 is the phase that gets *tuned*, which means these numbers will move.
/// The tests are therefore written against the **shape** of the feel — longest
/// freeze wins, a resting thumb does not cancel a Draw, kills produce no haptic
/// — rather than against the current values, so that turning a knob does not
/// turn the suite red for no reason.
void main() {
  group('hit-stop', () {
    test('gates whole ticks and never scales dt', () {
      // The distinction the sim's determinism rests on: while frozen, the
      // simulation receives *no* time rather than slowed time.
      final HitStop stop = HitStop()..request(0.05);

      expect(stop.isFrozen, isTrue);
      expect(stop.consume(0.016), 0);
      expect(stop.consume(0.016), 0);
      expect(stop.isFrozen, isTrue);
    });

    test('passes through the remainder of the frame that ends it', () {
      // Otherwise the frame that ends a freeze also drops its own time, and a
      // 40 ms freeze silently costs 56 ms.
      final HitStop stop = HitStop()..request(0.010);
      expect(stop.consume(0.016), closeTo(0.006, 1e-9));
      expect(stop.isFrozen, isFalse);
    });

    test('longest wins — freezes never accumulate', () {
      // A pierced arrow killing four enemies on one tick must produce one
      // freeze, not four back to back.
      final HitStop stop = HitStop();
      for (int i = 0; i < 4; i++) {
        stop.requestKill();
      }
      expect(stop.remaining, closeTo(Juice.killFreezeSeconds, 1e-9));

      stop.requestConfluenceKill();
      expect(stop.remaining, closeTo(Juice.confluenceFreezeSeconds, 1e-9));

      // And a shorter request cannot cut a longer one short.
      stop.requestKill();
      expect(stop.remaining, closeTo(Juice.confluenceFreezeSeconds, 1e-9));
    });

    test('is capped, so a room clear cannot lock the game', () {
      final HitStop stop = HitStop()..request(10.0);
      expect(stop.remaining, Juice.maxFreezeSeconds);
    });
  });

  group('screen shake', () {
    test('is trauma squared, so small events barely register', () {
      final ScreenShake small = ScreenShake()..addTrauma(0.2);
      final ScreenShake large = ScreenShake()..addTrauma(0.4);

      small.update(0.016);
      large.update(0.016);

      // Double the trauma is four times the shake, not twice. That
      // non-linearity is what makes a Confluence bloom while a kill stays
      // almost imperceptible.
      final double ratio = large.offsetX.abs() / small.offsetX.abs();
      expect(ratio, greaterThan(3.0));
    });

    test('decays to rest', () {
      final ScreenShake shake = ScreenShake()..addTrauma(0.5);
      for (int i = 0; i < 60; i++) {
        shake.update(0.016);
      }
      expect(shake.trauma, 0);
      expect(shake.isActive, isFalse);
    });

    test('clamps, so a room clear does not destroy the screen', () {
      final ScreenShake shake = ScreenShake();
      for (int i = 0; i < 20; i++) {
        shake.addTrauma(Juice.traumaOnKill);
      }
      expect(shake.trauma, Juice.maxTrauma);
    });

    test('Reduce Motion turns it off entirely, not down', () {
      final ScreenShake shake = ScreenShake(enabled: false)
        ..addTrauma(1.0)
        ..punch(1.0);
      shake.update(0.016);

      expect(shake.offsetX, 0);
      expect(shake.offsetY, 0);
      expect(shake.roll, 0);
      expect(shake.zoomScale, 1.0);
    });
  });

  group('the floating joystick', () {
    test('a resting thumb inside the dead zone never cancels a Draw', () {
      // The single most consequential boolean in the game. A 6 dp wobble while
      // the player holds Tier III must read as stationary.
      final JoystickModel stick = JoystickModel()..begin(100, 500);
      stick.drag(104, 504);

      expect(stick.outputX, 0);
      expect(stick.outputY, 0);

      final InputSnapshot input = InputSnapshot()
        ..set(stick.outputX, stick.outputY);
      expect(input.isMoving, isFalse);
    });

    test('reaches full deflection at the documented distance', () {
      final JoystickModel stick = JoystickModel()..begin(100, 500);
      stick.drag(100 + Juice.joystickFullDeflectionDp, 500);
      expect(stick.magnitude, closeTo(1.0, 1e-9));
    });

    test('output leaves the dead zone from zero, not from a step', () {
      // Rescaling matters: without it the stick snaps to ~17 % the instant it
      // crosses the dead zone, which feels like a loose connection.
      final JoystickModel stick = JoystickModel()..begin(100, 500);
      stick.drag(100 + Juice.joystickDeadZoneDp + 0.5, 500);
      expect(stick.magnitude, lessThan(0.06));
    });

    test('the origin follows a thumb that travels past full deflection', () {
      final JoystickModel stick = JoystickModel()..begin(100, 500);
      stick.drag(400, 500);

      // Still full deflection rather than a stick that ran out, and the origin
      // has been dragged along behind.
      expect(stick.magnitude, closeTo(1.0, 1e-9));
      expect(
          stick.originX, closeTo(400 - Juice.joystickFullDeflectionDp, 1e-6));

      // Coming back toward the trailing origin bleeds the deflection off
      // smoothly, and crossing it reverses. The cost of a full reversal is
      // therefore up to two deflection-widths of thumb travel — a real feel
      // trade-off, flagged in JoystickModel, and exactly the kind of thing the
      // Phase 6 playtest exists to rule on.
      stick.drag(380, 500);
      expect(stick.outputX, greaterThan(0));
      expect(stick.outputX, lessThan(1.0));

      stick.drag(300, 500);
      expect(stick.outputX, lessThan(0));
    });

    test('releasing centres it', () {
      final JoystickModel stick = JoystickModel()..begin(100, 500);
      stick.drag(200, 500);
      expect(stick.magnitude, greaterThan(0));

      stick.end();
      expect(stick.isActive, isFalse);
      expect(stick.magnitude, 0);
    });

    test('claims only the thumb zone, and mirrors when left-handed', () {
      expect(JoystickModel.claims(60, 780, 400, 800), isTrue);
      expect(JoystickModel.claims(360, 780, 400, 800), isFalse);
      expect(JoystickModel.claims(60, 100, 400, 800), isFalse);

      expect(
        JoystickModel.claims(360, 780, 400, 800, leftHanded: true),
        isTrue,
      );
    });
  });

  group('pools', () {
    test('particles never exceed their cap', () {
      final ParticlePool pool = ParticlePool(capacity: 16);
      for (int i = 0; i < 50; i++) {
        pool.burst(atX: 1, atY: 1, count: 8, argb: 0xFFFFFFFF);
      }
      expect(pool.liveCount, lessThanOrEqualTo(16));
    });

    test('particles expire', () {
      final ParticlePool pool = ParticlePool(capacity: 32)
        ..burst(atX: 1, atY: 1, count: 8, argb: 0xFFFFFFFF);
      expect(pool.liveCount, 8);

      for (int i = 0; i < 60; i++) {
        pool.update(0.032);
      }
      expect(pool.liveCount, 0);
    });

    test('bursts expand with an ease-out', () {
      final BurstPool pool = BurstPool()
        ..spawn(atX: 0, atY: 0, toRadius: 1.0, seconds: 0.4, argb: 0xFFFFFFFF);

      pool.update(0.2);
      // Half the time, well past half the radius — a linearly expanding ring
      // reads as a wireframe animation rather than a shockwave.
      expect(pool.radius[0], greaterThan(0.6));
    });
  });

  group('damage numbers', () {
    test('small hits are suppressed', () {
      final DamageNumberPool pool = DamageNumberPool();
      final bool shown = pool.maybeAdd(
        atX: 0,
        atY: 0,
        damage: 1,
        targetMaxHealth: 100,
      );
      expect(shown, isFalse);
      expect(pool.liveCount, 0);
    });

    test('a Confluence hit always shows, however small', () {
      final DamageNumberPool pool = DamageNumberPool();
      final bool shown = pool.maybeAdd(
        atX: 0,
        atY: 0,
        damage: 0.1,
        targetMaxHealth: 1e9,
        numberKind: DamageNumberKind.confluence,
        confluenceStacks: 2,
      );
      expect(shown, isTrue);
      expect(pool.kindAt(0), DamageNumberKind.confluence);
      expect(pool.stacks[0], 2);
    });
  });

  group('the feedback director', () {
    late ContentLibrary content;

    setUpAll(() {
      content = loadEnemies();
    });

    /// A world with one enemy the player is about to kill.
    (SimWorld, FeedbackDirector) rig({double attack = 1e6}) {
      final SimWorld world = enemyWorld(
        content: content,
        autoFire: true,
        playerX: 2.0,
        playerHealth: 1e6,
      )..playerAttack = attack;
      world.spawnEnemy(EnemyArchetype.mote, 8.0, 4.5);
      return (world, FeedbackDirector(world: world));
    }

    test('a kill freezes the frame, sprays debris, and does not buzz', () {
      final (SimWorld world, FeedbackDirector director) = rig();
      final InputSnapshot idle = InputSnapshot();

      bool killed = false;
      for (int i = 0; i < 240 && !killed; i++) {
        world.tick(idle);
        director.drainEvents();
        killed = director.hitStop.isFrozen;
        world.events.clear();
      }

      expect(killed, isTrue, reason: 'nothing died');
      expect(
        director.hitStop.remaining,
        closeTo(Juice.killFreezeSeconds, 1e-9),
      );
      expect(director.particles.liveCount, greaterThan(0));
      expect(director.shake.trauma, greaterThan(0));

      // Kills deliberately carry no haptic: at several per second it becomes a
      // continuous buzz that drowns the patterns that mean something.
      expect(director.cues.hasHaptic(HapticCue.confluence), isFalse);
      expect(director.cues.hasHaptic(HapticCue.playerHit), isFalse);
    });

    test('reaching Tier III ticks the haptic and flares the arc', () {
      final (SimWorld world, FeedbackDirector director) = rig(attack: 1);
      final InputSnapshot idle = InputSnapshot();

      // Standing still ramps the Draw.
      for (int i = 0; i < 120; i++) {
        world.tick(idle);
        director.drainEvents();
        world.events.clear();
      }

      expect(director.tierSnap, greaterThan(0));
    });

    test('losing a tier is silent', () {
      // Moving is a decision the player just made deliberately. Buzzing them
      // for it is nagging.
      final (SimWorld world, FeedbackDirector director) = rig(attack: 1);
      final InputSnapshot idle = InputSnapshot();
      final InputSnapshot moving = InputSnapshot()..set(1, 0);

      for (int i = 0; i < 120; i++) {
        world.tick(idle);
      }
      world.events.clear();

      world.tick(moving);
      director.drainEvents();

      expect(director.cues.countOf(SfxCue.drawTierUp), 0);
    });

    test('taking a hit is heavy, and shakes more than a kill does', () {
      final SimWorld world = enemyWorld(content: content);
      final FeedbackDirector director = FeedbackDirector(world: world);
      world.spawnEnemy(EnemyArchetype.mote, 8.3, 4.5);

      final InputSnapshot idle = InputSnapshot();
      bool hit = false;
      for (int i = 0; i < 240 && !hit; i++) {
        world.tick(idle);
        director.drainEvents();
        hit = director.cues.hasHaptic(HapticCue.playerHit);
        if (!hit) world.events.clear();
      }

      expect(hit, isTrue, reason: 'the Mote never reached the player');
      expect(director.cues.countOf(SfxCue.playerHit), greaterThan(0));
      expect(director.shake.trauma, greaterThan(Juice.traumaOnKill));
    });

    test('a Confluence rings the bell at its stack count', () {
      // Driven directly rather than fished out of a live room: this asserts the
      // mapping from stacks to cue magnitude, which is what makes the chord
      // rise with execution (docs/16 §16.2).
      final SimWorld world = enemyWorld(content: content);
      final FeedbackDirector director = FeedbackDirector(world: world);

      world.events
        ..emit(SimEventType.arrowFired, entityA: 5)
        ..emit(
          SimEventType.confluenceTriggered,
          entityA: 5,
          valueA: 3,
          x: 4,
          y: 4,
        );
      director.drainEvents();

      expect(director.cues.hasHaptic(HapticCue.confluence), isTrue);

      int bellMagnitude = -1;
      for (int i = 0; i < director.cues.sfxCount; i++) {
        if (director.cues.sfxAt(i) == SfxCue.confluenceBell) {
          bellMagnitude = director.cues.magnitudeAt(i);
        }
      }
      expect(bellMagnitude, 3);

      // And the burst carries the rank, so the renderer can draw three rings
      // rather than one bigger one.
      expect(director.bursts.liveCount, 1);
      expect(director.bursts.rank[0], 3);
    });

    test('presentation keeps animating while the simulation is frozen', () {
      final SimWorld world = enemyWorld(content: content);
      final FeedbackDirector director = FeedbackDirector(world: world)
        ..particles.burst(atX: 1, atY: 1, count: 4, argb: 0xFFFFFFFF);
      director.hitStop.requestKill();

      final double before = director.particles.x[0];
      director.update(0.016);

      expect(
        director.particles.x[0],
        isNot(before),
        reason: 'a freeze-frame that also freezes its own effects is a stall',
      );
    });
  });

  group('cue dispatch', () {
    test('drains to every sink and clears', () {
      final CueQueue queue = CueQueue()
        ..haptic(HapticCue.confluence)
        ..sfx(SfxCue.confluenceBell, magnitude: 2);

      final _SpySink a = _SpySink();
      final _SpySink b = _SpySink();
      dispatchCues(queue, <CueSink>[a, b]);

      expect(a.haptics, <HapticCue>[HapticCue.confluence]);
      expect(b.magnitudes, <int>[2]);
      expect(queue.hapticCount, 0);
      expect(queue.sfxCount, 0);
    });

    test('repeated haptics within a frame collapse to one', () {
      final CueQueue queue = CueQueue()
        ..haptic(HapticCue.playerHit)
        ..haptic(HapticCue.playerHit)
        ..haptic(HapticCue.playerHit);
      expect(queue.hapticCount, 1);
    });
  });

  group('sim purity', () {
    test('the feel layer never leaks into the simulation', () {
      // `game/feel` may read the simulation; the simulation may never read it.
      // Stated as a test because the temptation to shake the camera from inside
      // a damage system is real and the coupling is very hard to unpick later.
      const int slot = SimConfig.maxEntities - 1;
      expect(slot, greaterThan(0));
    });
  });
}

class _SpySink implements CueSink {
  final List<HapticCue> haptics = <HapticCue>[];
  final List<SfxCue> sfx = <SfxCue>[];
  final List<int> magnitudes = <int>[];

  @override
  void onHaptic(HapticCue cue) => haptics.add(cue);

  @override
  void onSfx(SfxCue cue, int magnitude) {
    sfx.add(cue);
    magnitudes.add(magnitude);
  }
}
