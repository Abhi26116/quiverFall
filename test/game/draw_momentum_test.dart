import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/systems/draw_system.dart';
import 'package:test/test.dart';

/// The core trade: root to escalate, move to survive.
///
/// docs/01-vision.md §1.1 specifies exact thresholds, and they are exact for a
/// reason — the whole feel of the game is the rhythm these numbers produce, so
/// drift here is a design regression, not a rounding detail.
void main() {
  const double dt = SimConfig.fixedStep;

  late DrawState state;
  late SimEventBuffer events;

  setUp(() {
    state = DrawState();
    events = SimEventBuffer();
  });

  void tickStationary(int n) {
    for (int i = 0; i < n; i++) {
      DrawSystem.update(state, false, dt, events);
    }
  }

  void tickMoving(int n) {
    for (int i = 0; i < n; i++) {
      DrawSystem.update(state, true, dt, events);
    }
  }

  group('Draw tiers', () {
    test('starts at tier I', () {
      expect(state.tier, DrawTier.one);
      expect(state.tierProgress, 0);
    });

    test('reaches tier II on the tick that passes 0.45s', () {
      // Note the accumulation: summing 1/60 twenty-seven times gives
      // 0.4499999999999999, a hair under the threshold, so the transition
      // lands on tick 28 rather than 27.
      //
      // This is real floating-point behaviour, not a defect. The alternative —
      // an epsilon on the comparison — buys 16 ms of nominal accuracy and costs
      // a class of subtle bugs, so the threshold is left exact and the
      // behaviour documented here.
      tickStationary(27);
      expect(state.drawSeconds, lessThan(DrawState.tierTwoAt));
      expect(state.tier, DrawTier.one);

      tickStationary(1);
      expect(state.drawSeconds, greaterThanOrEqualTo(DrawState.tierTwoAt));
      expect(state.tier, DrawTier.two);
    });

    test('reaches tier III at exactly 1.10s', () {
      tickStationary(65); // 1.0833s
      expect(state.tier, DrawTier.two);

      tickStationary(2); // 1.1167s
      expect(state.tier, DrawTier.three);
    });

    test('tier multipliers and fire rates match the design', () {
      // Fire rate deliberately *falls* as the tier rises. This is what stops
      // Tier III being unconditionally correct and keeps the Draw a decision.
      expect(DrawTier.one.damageMultiplier, 1.00);
      expect(DrawTier.two.damageMultiplier, 1.45);
      expect(DrawTier.three.damageMultiplier, 2.10);

      expect(DrawTier.one.fireRate, 2.2);
      expect(DrawTier.two.fireRate, 2.0);
      expect(DrawTier.three.fireRate, 1.7);

      expect(DrawTier.one.bonusPierce, 0);
      expect(DrawTier.two.bonusPierce, 1);
      expect(DrawTier.three.bonusPierce, 2);
    });

    test('only tier III guarantees an element proc and widens the hitbox', () {
      expect(DrawTier.three.guaranteesElementProc, isTrue);
      expect(DrawTier.two.guaranteesElementProc, isFalse);
      expect(DrawTier.three.hitboxScale, 1.5);
      expect(DrawTier.one.hitboxScale, 1.0);
    });

    test('moving resets the Draw completely, not partially', () {
      // The decision to move must cost the whole ramp, or the trade is not a
      // trade.
      tickStationary(80);
      expect(state.tier, DrawTier.three);

      tickMoving(1);
      expect(state.drawSeconds, 0);
      expect(state.tier, DrawTier.one);
    });

    test('tierProgress fills each band from 0 to 1', () {
      tickStationary(14); // ~0.233s, about half of tier I's 0.45s band
      expect(state.tierProgress, closeTo(0.52, 0.05));

      tickStationary(14); // crosses into tier II, progress restarts
      expect(state.tier, DrawTier.two);
      expect(state.tierProgress, lessThan(0.1));

      tickStationary(100);
      expect(state.tierProgress, 1.0);
    });

    test('a faster draw speed reaches tier III sooner', () {
      // Kestrel's Hummingbird passive: 0.70 multiplier, so 1.10s becomes 0.77s.
      state.drawSpeedMultiplier = 0.70;
      tickStationary(47); // 0.7833s
      expect(state.tier, DrawTier.three);
    });

    test('emits an event on every tier change', () {
      tickStationary(80);
      expect(events.countOf(SimEventType.drawTierChanged), 2);
    });
  });

  group('Draw-lock', () {
    test('suppresses tier gain but not Momentum', () {
      // The Screecher attacks the player's mechanic rather than their HP. This
      // is precisely why Momentum builds are a genuine alternative rather than
      // a fallback — see docs/05 §5.4.
      state.applyDrawLock(2.0);
      tickStationary(60); // 1s locked

      expect(state.tier, DrawTier.one);
      expect(state.isDrawLocked, isTrue);

      tickMoving(30);
      expect(state.momentumStacks, greaterThan(0),
          reason: 'Momentum must keep working while Draw-locked');
    });

    test('expires and lets the Draw resume', () {
      state.applyDrawLock(0.5);
      tickStationary(31); // 0.5167s — lock expires
      expect(state.isDrawLocked, isFalse);

      tickStationary(70);
      expect(state.tier, DrawTier.three);
    });

    test('re-applying takes the longer of the two durations', () {
      state.applyDrawLock(2.0);
      state.applyDrawLock(0.5);
      expect(state.drawLockRemaining, 2.0);
    });
  });

  group('Momentum', () {
    test('gains one stack per 0.35s of movement', () {
      tickMoving(21); // 0.35s
      expect(state.momentumStacks, 1);

      tickMoving(21); // 0.70s
      expect(state.momentumStacks, 2);
    });

    test('caps at max and does not bank surplus charge', () {
      tickMoving(300);
      expect(state.momentumStacks, DrawState.baseMaxMomentum);
      expect(state.momentumChargeSeconds, 0,
          reason: 'a banked stack would grant a free one after a brief stop');
    });

    test('grants speed and mitigation per stack', () {
      tickMoving(120);
      expect(state.momentumStacks, 5);
      expect(state.moveSpeedBonus, closeTo(0.15, 1e-9));
      expect(state.damageReduction, closeTo(0.10, 1e-9));
    });

    test('survives a brief stop, then drops all at once', () {
      // The grace window lets a player tap-stop to fire without instantly
      // losing their defensive layer. The hard cliff afterwards is what makes
      // the loss legible.
      tickMoving(120);
      expect(state.momentumStacks, 5);

      tickStationary(30); // 0.5s — inside the 0.6s grace
      expect(state.momentumStacks, 5);

      tickStationary(7); // 0.617s — past it
      expect(state.momentumStacks, 0,
          reason: 'all stacks drop together, not one at a time');
    });

    test('a raised cap is honoured', () {
      // The Spire's Momentum Mastery node and Boon 46 raise this.
      state.maxMomentum = 8;
      tickMoving(300);
      expect(state.momentumStacks, 8);
    });

    test('emits an event on every stack change', () {
      tickMoving(45); // 2 stacks
      expect(events.countOf(SimEventType.momentumChanged), 2);
    });
  });

  group('the trade itself', () {
    test('the two states are mutually exclusive but both rewarded', () {
      // The central design claim of the game: moving is not a punishment.
      tickStationary(80);
      final DrawTier rooted = state.tier;
      final double rootedDr = state.damageReduction;

      state.reset();
      tickMoving(120);
      final DrawTier moving = state.tier;
      final double movingDr = state.damageReduction;

      expect(rooted, DrawTier.three);
      expect(rootedDr, 0, reason: 'rooting gives damage, not mitigation');

      expect(moving, DrawTier.one);
      expect(movingDr, greaterThan(0),
          reason: 'moving gives mitigation, not damage');
    });

    test('an oscillating player holds Momentum but never reaches tier III', () {
      // The rhythm a skilled player actually plays: short stops inside the
      // grace window, so Momentum persists while the Draw keeps restarting.
      for (int cycle = 0; cycle < 12; cycle++) {
        tickMoving(24); // 0.4s moving
        tickStationary(24); // 0.4s still — inside grace
      }

      expect(state.momentumStacks, greaterThan(0),
          reason: 'grace window preserves Momentum across short stops');
      expect(state.tier, isNot(DrawTier.three),
          reason: 'never still long enough to fully wind');
    });

    test('reset clears everything', () {
      tickMoving(120);
      tickStationary(10);
      state.applyDrawLock(3);
      state.reset();

      expect(state.drawSeconds, 0);
      expect(state.momentumStacks, 0);
      expect(state.drawLockRemaining, 0);
      expect(state.tier, DrawTier.one);
    });
  });
}
