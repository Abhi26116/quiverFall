import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';
import 'enemy_test_support.dart';

/// `BossPhaseSystem` — the one piece of docs/06 §6.0 true of every boss
/// regardless of what its own fight does: "three phases minimum, with a hard
/// visual and musical transition at 66% and 33% HP." Each boss's own bespoke
/// attacks get their own test file alongside their implementation, the same
/// split `hero_behaviour_test.dart` draws per hero; this file is only the
/// generic threshold machine every one of them will sit on top of.
void main() {
  final ContentLibrary content = loadContentWithBosses();

  const double maxHealth = 1000.0;

  int spawnCinderChoir(SimWorld world, {double healthFraction = 1.0}) {
    final int slot = world.spawnBoss(
      BossArchetype.cinderChoir,
      10.0,
      4.5,
      radius: 1.0,
      health: maxHealth,
    );
    world.entities.health[slot] = maxHealth * healthFraction;
    return slot;
  }

  group('phase transitions', () {
    test('a fresh boss starts at phase 0', () {
      final SimWorld world = enemyWorld(content: content);
      final int boss = spawnCinderChoir(world);
      world.tick(InputSnapshot());
      expect(world.enemies.bossPhase[boss], 0);
      expect(world.events.countOf(SimEventType.bossPhaseChanged), 0);
    });

    test('dropping to 65% HP advances to phase 1 and emits the event', () {
      final SimWorld world = enemyWorld(content: content);
      final int boss = spawnCinderChoir(world, healthFraction: 0.65);
      world.tick(InputSnapshot());
      expect(world.enemies.bossPhase[boss], 1);
      expect(world.events.countOf(SimEventType.bossPhaseChanged), 1);

      final int i = _firstIndexOf(world.events, SimEventType.bossPhaseChanged);
      expect(world.events.entityAAt(i), boss);
      expect(world.events.valueAAt(i), 1.0);
      expect(world.events.valueBAt(i), closeTo(0.65, 1e-9));
    });

    test('exactly 66% HP already counts as crossed', () {
      // docs/06 §6.0 rule 1: the transition happens "at 66% HP", so a boss
      // sitting exactly on the boundary is already past it, not the tail end
      // of phase 0 — the threshold check is `<=`, not `<`.
      final SimWorld world = enemyWorld(content: content);
      final int boss = spawnCinderChoir(world, healthFraction: 0.66);
      world.tick(InputSnapshot());
      expect(world.enemies.bossPhase[boss], 1);
    });

    test('staying above 66% HP keeps phase 0', () {
      final SimWorld world = enemyWorld(content: content);
      final int boss = spawnCinderChoir(world, healthFraction: 0.70);
      world.tick(InputSnapshot());
      expect(world.enemies.bossPhase[boss], 0);
      expect(world.events.countOf(SimEventType.bossPhaseChanged), 0);
    });

    test('a later drop past 33% advances to phase 2', () {
      final SimWorld world = enemyWorld(content: content);
      final int boss = spawnCinderChoir(world, healthFraction: 0.65);
      world.tick(InputSnapshot());
      world.events.clear();
      expect(world.enemies.bossPhase[boss], 1);

      world.entities.health[boss] = maxHealth * 0.30;
      world.tick(InputSnapshot());
      expect(world.enemies.bossPhase[boss], 2);
      expect(world.events.countOf(SimEventType.bossPhaseChanged), 1);
    });

    test('a single hit crossing both thresholds fires both transitions', () {
      final SimWorld world = enemyWorld(content: content);
      final int boss = spawnCinderChoir(world);
      world.entities.health[boss] = maxHealth * 0.10;
      world.tick(InputSnapshot());
      expect(world.enemies.bossPhase[boss], 2);
      expect(world.events.countOf(SimEventType.bossPhaseChanged), 2);
    });

    test('phase never regresses even if health is topped back up', () {
      final SimWorld world = enemyWorld(content: content);
      final int boss = spawnCinderChoir(world, healthFraction: 0.65);
      world.tick(InputSnapshot());
      expect(world.enemies.bossPhase[boss], 1);

      world.entities.health[boss] = maxHealth;
      world.tick(InputSnapshot());
      expect(world.enemies.bossPhase[boss], 1);
    });

    test('an ordinary enemy is untouched — bossIndex -1 is a no-op', () {
      final SimWorld world = enemyWorld(content: content);
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 10.0, 4.5);
      world.entities.health[mote] = world.entities.maxHealth[mote] * 0.10;
      world.tick(InputSnapshot());
      expect(world.enemies.bossPhase[mote], 0);
      expect(world.events.countOf(SimEventType.bossPhaseChanged), 0);
    });
  });

  group('The Last Warden — the one 5-phase boss', () {
    test('all four thresholds fire in sequence as HP drains', () {
      final SimWorld world = enemyWorld(content: content);
      final int boss = world.spawnBoss(
        BossArchetype.lastWarden,
        10.0,
        4.5,
        radius: 1.0,
        health: maxHealth,
      );
      final BossDefinition def =
          content.bosses.byArchetype(BossArchetype.lastWarden)!;
      expect(def.phaseCount, 5);

      for (int p = 0; p < def.phaseThresholds.length; p++) {
        world.entities.health[boss] = maxHealth * def.phaseThresholds[p];
        world.tick(InputSnapshot());
        expect(world.enemies.bossPhase[boss], p + 1, reason: 'phase ${p + 1}');
      }
    });
  });
}

int _firstIndexOf(SimEventBuffer events, SimEventType type) {
  for (int i = 0; i < events.count; i++) {
    if (events.typeAt(i) == type) return i;
  }
  throw StateError('no ${type.name} event found');
}
