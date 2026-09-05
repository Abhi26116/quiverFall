import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/status_store.dart';
import 'package:quiverfall/game/sim/systems/element_system.dart';
import 'package:test/test.dart';

void main() {
  const double dt = SimConfig.fixedStep;

  late EntityStore store;
  late StatusStore status;
  late SimEventBuffer events;

  setUp(() {
    store = EntityStore(capacity: 32);
    status = StatusStore(capacity: 32);
    events = SimEventBuffer();
  });

  int spawnEnemy({required double health}) {
    final EntityId id = store.spawn(EntityKind.enemy);
    store.health[id.index] = health;
    store.maxHealth[id.index] = health;
    return id.index;
  }

  void run(int ticks) {
    for (int i = 0; i < ticks; i++) {
      ElementSystem.update(
          store: store, status: status, events: events, dt: dt);
    }
  }

  group('Ember', () {
    test('burns for a fraction of max HP per second', () {
      final int e = spawnEnemy(health: 1000);
      status.apply(e, SimElement.ember);

      run(60); // 1 second

      // 4% of 1000 = 40 per second, one stack.
      expect(1000 - store.health[e], closeTo(40, 1.0));
    });

    test('scales off target max HP, so it is a boss-killer', () {
      final int small = spawnEnemy(health: 100);
      final int big = spawnEnemy(health: 10000);
      status.apply(small, SimElement.ember);
      status.apply(big, SimElement.ember);

      run(60);

      final double smallLoss = 100 - store.health[small];
      final double bigLoss = 10000 - store.health[big];
      expect(bigLoss, greaterThan(smallLoss * 50));
    });

    test('stacks to the documented cap', () {
      final int e = spawnEnemy(health: 1000);
      for (int i = 0; i < 5; i++) {
        status.apply(e, SimElement.ember);
      }
      expect(status.burnStacks[e], ElementTuning.burnMaxStacks);
    });

    test('expires', () {
      final int e = spawnEnemy(health: 1000);
      status.apply(e, SimElement.ember);
      run((ElementTuning.burnDuration * 60).ceil() + 2);
      expect(status.burnStacks[e], 0);
    });

    test('can kill, and reports the death', () {
      final int e = spawnEnemy(health: 10);
      store.maxHealth[e] = 1000; // heavy burn relative to current HP
      status.apply(e, SimElement.ember);

      run(60);

      expect(store.alive[e], 0);
      expect(events.countOf(SimEventType.entityDied), 1);
    });

    test('durationMultiplier extends how long Burn lasts (Oriel\'s own '
        'Saturation)', () {
      final int e = spawnEnemy(health: 1000);
      status.apply(e, SimElement.ember, durationMultiplier: 2.0);

      // Still burning past the ordinary 4 s duration...
      run((ElementTuning.burnDuration * 60).ceil() + 2);
      expect(status.burnStacks[e], greaterThan(0));

      // ...but gone by twice it.
      run((ElementTuning.burnDuration * 60).ceil());
      expect(status.burnStacks[e], 0);
    });
  });

  group('Frost', () {
    test('accumulates chill and freezes at the threshold', () {
      final int e = spawnEnemy(health: 1000);
      final int hitsNeeded =
          (ElementTuning.chillToFreeze / ElementTuning.chillPerHit).ceil();

      for (int i = 0; i < hitsNeeded - 1; i++) {
        status.apply(e, SimElement.frost);
      }
      expect(status.isFrozen(e), isFalse);

      status.apply(e, SimElement.frost);
      expect(status.isFrozen(e), isTrue);
      expect(status.chill[e], 0, reason: 'chill discharges into the freeze');
    });

    test('chill decays when not reinforced', () {
      // Without decay a single Rimeshaft would freeze everything eventually,
      // regardless of sustained pressure.
      final int e = spawnEnemy(health: 1000);
      status.apply(e, SimElement.frost);
      status.apply(e, SimElement.frost);
      final double before = status.chill[e];

      run(60);

      expect(status.chill[e], lessThan(before));
    });

    test('frozen targets take extra damage', () {
      final int e = spawnEnemy(health: 1000);
      for (int i = 0; i < 10; i++) {
        status.apply(e, SimElement.frost);
      }
      expect(status.isFrozen(e), isTrue);
      expect(status.damageTakenBonus(e), ElementTuning.frozenDamageBonus);
    });

    test('freeze suppresses damage-over-time while it lasts', () {
      final int e = spawnEnemy(health: 1000);
      status.apply(e, SimElement.ember);
      for (int i = 0; i < 10; i++) {
        status.apply(e, SimElement.frost);
      }
      expect(status.isFrozen(e), isTrue);

      final double before = store.health[e];
      run(30); // half a second, still frozen
      expect(store.health[e], before, reason: 'freeze halts other ticking');
    });

    test('freeze expires', () {
      final int e = spawnEnemy(health: 1000);
      for (int i = 0; i < 10; i++) {
        status.apply(e, SimElement.frost);
      }
      run((ElementTuning.freezeDuration * 60).ceil() + 2);
      expect(status.isFrozen(e), isFalse);
    });

    test('durationMultiplier extends the freeze itself, not the '
        'accumulation toward it (Oriel\'s own Saturation)', () {
      final int e = spawnEnemy(health: 1000);
      final int hitsNeeded =
          (ElementTuning.chillToFreeze / ElementTuning.chillPerHit).ceil();
      // The multiplier only matters once discharged into a freeze, so
      // reaching the threshold itself takes no more hits than usual.
      for (int i = 0; i < hitsNeeded; i++) {
        status.apply(e, SimElement.frost, durationMultiplier: 2.0);
      }
      expect(status.isFrozen(e), isTrue);

      // Still frozen past the ordinary freeze duration...
      run((ElementTuning.freezeDuration * 60).ceil() + 2);
      expect(status.isFrozen(e), isTrue);

      // ...but thawed by twice it.
      run((ElementTuning.freezeDuration * 60).ceil());
      expect(status.isFrozen(e), isFalse);
    });
  });

  group('Toxin', () {
    test('stacks and compounds', () {
      final int a = spawnEnemy(health: 5000);
      final int b = spawnEnemy(health: 5000);

      status.apply(a, SimElement.toxin);
      for (int i = 0; i < 5; i++) {
        status.apply(b, SimElement.toxin);
      }

      run(60);

      final double oneStack = 5000 - store.health[a];
      final double fiveStacks = 5000 - store.health[b];
      expect(fiveStacks, closeTo(oneStack * 5, oneStack * 0.1));
    });

    test('caps at the documented maximum', () {
      final int e = spawnEnemy(health: 1000);
      for (int i = 0; i < 30; i++) {
        status.apply(e, SimElement.toxin);
      }
      expect(status.toxinStacks[e], ElementTuning.toxinMaxStacks);
    });

    test('reduces healing, never inverting it', () {
      final int e = spawnEnemy(health: 1000);
      for (int i = 0; i < 30; i++) {
        status.apply(e, SimElement.toxin);
      }
      final double m = status.healingMultiplier(e);
      expect(m, lessThan(1.0));
      expect(m, greaterThanOrEqualTo(0.0),
          reason: 'healing must never become damage');
    });

    test('does not expire on its own', () {
      // Investment that compounds — the shape that makes Toxin feel different
      // from Ember.
      final int e = spawnEnemy(health: 1000);
      status.apply(e, SimElement.toxin);
      run(600);
      expect(status.toxinStacks[e], 1);
    });

    test('durationMultiplier does nothing — Toxin has no duration to '
        'extend (Oriel\'s own Saturation)', () {
      final int e = spawnEnemy(health: 1000);
      status.apply(e, SimElement.toxin, durationMultiplier: 2.0);
      run(600);
      expect(status.toxinStacks[e], 1, reason: 'stacks, does not expire');
    });
  });

  group('Storm', () {
    test('leaves no lingering state', () {
      final int e = spawnEnemy(health: 1000);
      status.apply(e, SimElement.storm);
      expect(status.burnStacks[e], 0);
      expect(status.chill[e], 0);
      expect(status.toxinStacks[e], 0);
    });
  });

  group('reactions', () {
    test('fire only from a Confluence carrying a different element', () {
      final int e = spawnEnemy(health: 1000);

      final double same = ElementSystem.resolveReaction(
        status: status,
        events: events,
        target: e,
        elementMask: 1 << SimElement.ember.index,
        incoming: SimElement.ember,
        x: 0,
        y: 0,
      );
      expect(same, 1.0, reason: 'matching elements do not react');

      final double different = ElementSystem.resolveReaction(
        status: status,
        events: events,
        target: e,
        elementMask: 1 << SimElement.frost.index,
        incoming: SimElement.ember,
        x: 0,
        y: 0,
      );
      expect(different, Reaction.steamburst.damageMultiplier);
    });

    test('respect the per-enemy cooldown', () {
      // Without this, a high-fire-rate hero turns reactions into a continuous
      // stream rather than a punctuated payoff.
      final int e = spawnEnemy(health: 1000);

      final double first = ElementSystem.resolveReaction(
        status: status, events: events, target: e,
        elementMask: 1 << SimElement.frost.index,
        incoming: SimElement.ember, x: 0, y: 0,
      );
      expect(first, greaterThan(1.0));

      final double second = ElementSystem.resolveReaction(
        status: status, events: events, target: e,
        elementMask: 1 << SimElement.frost.index,
        incoming: SimElement.ember, x: 0, y: 0,
      );
      expect(second, 1.0, reason: 'still on cooldown');

      run((Reactions.perEnemyCooldown * 60).ceil() + 2);

      final double third = ElementSystem.resolveReaction(
        status: status, events: events, target: e,
        elementMask: 1 << SimElement.frost.index,
        incoming: SimElement.ember, x: 0, y: 0,
      );
      expect(third, greaterThan(1.0), reason: 'cooldown elapsed');
    });

    test('three distinct elements collapse to Prismbreak', () {
      final int e = spawnEnemy(health: 1000);
      final double m = ElementSystem.resolveReaction(
        status: status,
        events: events,
        target: e,
        elementMask: (1 << SimElement.frost.index) |
            (1 << SimElement.storm.index) |
            (1 << SimElement.toxin.index),
        incoming: SimElement.ember,
        x: 0,
        y: 0,
      );
      expect(m, Reaction.prismbreak.damageMultiplier);
    });

    test('emit an event the view layer can render', () {
      final int e = spawnEnemy(health: 1000);
      ElementSystem.resolveReaction(
        status: status, events: events, target: e,
        elementMask: 1 << SimElement.storm.index,
        incoming: SimElement.toxin, x: 3, y: 4,
      );
      expect(events.countOf(SimEventType.reactionTriggered), 1);
    });

    test('no reaction without a Confluence element', () {
      final int e = spawnEnemy(health: 1000);
      final double m = ElementSystem.resolveReaction(
        status: status, events: events, target: e,
        elementMask: 0,
        incoming: SimElement.ember, x: 0, y: 0,
      );
      expect(m, 1.0);
    });
  });
}
