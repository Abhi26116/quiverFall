import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Last Warden — docs/06 §6.3, Endless Descent boss #20. P1-P4 only —
/// see `LastWardenSystem`'s own doc comment for what each phase means and
/// what P5 still needs. P1 (ADR 0059): the Draw ramp, the Momentum-driven
/// speed and damage-reduction trade, and the approach/hold/disengage
/// rhythm. P2 (ADR 0060): mirroring the player's own current flat damage
/// bonus and crit into the heavy shot. P3 (ADR 0061): summoning echoes of
/// up to three other bosses, each its own real, independently-driven
/// fight. P4 (ADR 0062): standing off any live player-owned Windline
/// deals ongoing damage — "the floor is removed," read as a real, working
/// stand-in rather than new fall-through physics.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e5;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary}) spawnLastWarden({
    double playerX = centerX + 6.0,
    double playerY = centerY,
    List<BossArchetype> echoArchetypes = const <BossArchetype>[],
  }) {
    final SimWorld world = SimWorld(seed: 202020, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnLastWarden(
      centerX,
      centerY,
      health: health,
      echoArchetypes: echoArchetypes,
    );
    return (world: world, primary: primary);
  }

  group('spawn', () {
    test('places a single body with the shipping HP/duration numbers', () {
      final (:world, :primary) = spawnLastWarden();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.alive[primary], 1);
    });
  });

  group('movement', () {
    test('closes the distance while the player is far away', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 10.0);
      final double startX = world.entities.posX[primary];

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], greaterThan(startX));
    });

    test('holds still once within engage range, letting Draw ramp', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 2.0);

      for (int i = 0; i < 5; i++) {
        world.tick(InputSnapshot());
      }
      final double x1 = world.entities.posX[primary];
      final double y1 = world.entities.posY[primary];

      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }

      // Never fires within this short a window (Draw needs real time to
      // ramp), so it should simply be holding position, not still closing.
      expect(world.entities.posX[primary], closeTo(x1, 0.05));
      expect(world.entities.posY[primary], closeTo(y1, 0.05));
    });
  });

  group('Draw and the heavy shot', () {
    test('ramps Draw while holding and fires a bolt at Tier III, then '
        'resets and disengages', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 2.0);
      final int startingBolts = world.hazards.liveCount;

      bool fired = false;
      for (int i = 0; i < 600; i++) {
        world.tick(InputSnapshot());
        if (world.hazards.liveCount > startingBolts) {
          fired = true;
          break;
        }
      }

      expect(fired, isTrue, reason: 'the Warden should have Drawn to Tier '
          'Three and fired within 10s of holding range');
      expect(world.lastWardenDraw.drawSeconds, 0);
      // The reposition window just started — it should be moving again
      // (away from the player) rather than immediately re-holding.
      expect(world.enemies.bossTimer[primary], greaterThan(0));
    });

    test('never fires while the player has not been engaged (out of '
        'range, endlessly closing)', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 200.0);
      final int startingBolts = world.hazards.liveCount;

      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.hazards.liveCount, startingBolts);
      expect(world.entities.alive[primary], 1);
    });
  });

  group('Momentum at parity', () {
    test('moving builds Momentum stacks on the Warden\'s own DrawState, '
        'the identical rule the player\'s own Draw runs under', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 10.0);
      expect(world.lastWardenDraw.momentumStacks, 0);

      for (int i = 0; i < 90; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.lastWardenDraw.momentumStacks, greaterThan(0));
      expect(primary, greaterThanOrEqualTo(0));
    });

    test('Momentum stacks reduce the Warden\'s own incoming damage, the '
        'same fraction the player\'s own Momentum grants', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 10.0);

      // Build to max Momentum by staying in motion (the Warden is far
      // enough to keep closing the whole window) — 0.35s per stack, 5
      // stacks, comfortably inside this 2.5s window.
      for (int i = 0; i < 150; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.lastWardenDraw.momentumStacks, DrawState.baseMaxMomentum);

      final double before = world.entities.health[primary];
      world.entities.health[primary] = before - 100.0;
      world.tick(InputSnapshot());

      final double after = world.entities.health[primary];
      final double expectedDrop =
          100.0 * (1.0 - world.lastWardenDraw.damageReduction);
      expect(before - after, closeTo(expectedDrop, 1e-6));
      expect(after, greaterThan(before - 100.0));
    });

    test('with no Momentum, a health drop is not refunded at all', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 2.0);
      // Sit right at spawn — holding range, no movement yet this tick.
      world.tick(InputSnapshot());
      expect(world.lastWardenDraw.momentumStacks, 0);

      final double before = world.entities.health[primary];
      world.entities.health[primary] = before - 50.0;
      world.tick(InputSnapshot());

      expect(world.entities.health[primary], closeTo(before - 50.0, 1e-6));
    });
  });

  group('P2: gains the player\'s own current Boon set, mirrored', () {
    const double baseDamage = 0.09 * 2.10;

    int? fireAndFindHazard(SimWorld world, int primary) {
      for (int i = 0; i < 600; i++) {
        world.tick(InputSnapshot());
        for (int h = 0; h < world.hazards.capacity; h++) {
          if (world.hazards.isAlive(h) && world.hazards.ownerAt(h) == primary) {
            return h;
          }
        }
      }
      return null;
    }

    test('before P2, the player\'s own flat damage bonus is not mirrored '
        'into the heavy shot', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 2.0);
      world.combat.flatDamage = 0.5;

      final int? hazardSlot = fireAndFindHazard(world, primary);
      expect(hazardSlot, isNotNull);
      expect(world.hazards.damage[hazardSlot!], closeTo(baseDamage, 1e-9));
    });

    test('once P2 begins, the player\'s own current flat damage bonus is '
        'mirrored into the heavy shot\'s own damage', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 2.0);
      world.enemies.bossPhase[primary] = 1;
      world.combat.flatDamage = 0.5;

      final int? hazardSlot = fireAndFindHazard(world, primary);
      expect(hazardSlot, isNotNull);
      expect(
        world.hazards.damage[hazardSlot!],
        closeTo(baseDamage * 1.5, 1e-9),
      );
    });

    test('a guaranteed crit is mirrored too, at the player\'s own current '
        'crit multiplier', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 2.0);
      world.enemies.bossPhase[primary] = 1;
      world.combat.critChance = 1.0;
      final double critMult = world.combat.critMultiplier;

      final int? hazardSlot = fireAndFindHazard(world, primary);
      expect(hazardSlot, isNotNull);
      expect(
        world.hazards.damage[hazardSlot!],
        closeTo(baseDamage * critMult, 1e-9),
      );
    });

    test('zero crit chance never crits, even in P2', () {
      final (:world, :primary) = spawnLastWarden(playerX: centerX + 2.0);
      world.enemies.bossPhase[primary] = 1;
      world.combat.critChance = 0;

      final int? hazardSlot = fireAndFindHazard(world, primary);
      expect(hazardSlot, isNotNull);
      expect(world.hazards.damage[hazardSlot!], closeTo(baseDamage, 1e-9));
    });
  });

  group('P3: summons echoes of three bosses, read from telemetry', () {
    List<int> enemiesOfArchetype(SimWorld world, BossArchetype archetype) {
      final List<int> found = <int>[];
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        final int bossIndex = world.enemies.bossIndex[i];
        if (bossIndex < 0) continue;
        if (world.content.bosses.all[bossIndex].archetype == archetype) {
          found.add(i);
        }
      }
      return found;
    }

    test('before P3, no echoes exist even with archetypes given', () {
      final (:world, :primary) = spawnLastWarden(
        echoArchetypes: const <BossArchetype>[
          BossArchetype.gauntIronTide,
          BossArchetype.silversong,
        ],
      );

      for (int i = 0; i < 10; i++) {
        world.tick(InputSnapshot());
      }

      expect(enemiesOfArchetype(world, BossArchetype.gauntIronTide), isEmpty);
      expect(enemiesOfArchetype(world, BossArchetype.silversong), isEmpty);
      expect(primary, greaterThanOrEqualTo(0));
    });

    test('once P3 begins, each given archetype is spawned as its own real '
        'boss, at a fraction of the Warden\'s own max health', () {
      final (:world, :primary) = spawnLastWarden(
        echoArchetypes: const <BossArchetype>[
          BossArchetype.gauntIronTide,
          BossArchetype.silversong,
          BossArchetype.rimefather,
        ],
      );
      world.enemies.bossPhase[primary] = 2;

      world.tick(InputSnapshot());

      for (final BossArchetype archetype in const <BossArchetype>[
        BossArchetype.gauntIronTide,
        BossArchetype.silversong,
        BossArchetype.rimefather,
      ]) {
        final List<int> found = enemiesOfArchetype(world, archetype);
        expect(found.length, 1, reason: '$archetype should have one echo');
        final int echo = found.single;
        expect(world.entities.maxHealth[echo], closeTo(health * 0.08, 1e-6));
        expect(world.entities.alive[echo], 1);
      }
    });

    test('echoes are spawned exactly once, not re-summoned every tick', () {
      final (:world, :primary) = spawnLastWarden(
        echoArchetypes: const <BossArchetype>[BossArchetype.gauntIronTide],
      );
      world.enemies.bossPhase[primary] = 2;

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      expect(enemiesOfArchetype(world, BossArchetype.gauntIronTide).length, 1);
    });

    test('fewer than three archetypes leaves the remaining slots empty, '
        'not guessed at', () {
      final (:world, :primary) = spawnLastWarden(
        echoArchetypes: const <BossArchetype>[BossArchetype.vermillion],
      );
      world.enemies.bossPhase[primary] = 2;

      world.tick(InputSnapshot());

      expect(enemiesOfArchetype(world, BossArchetype.vermillion).length, 1);
      // Total live enemies: the Warden itself plus exactly one echo.
      int liveEnemies = 0;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 1) liveEnemies++;
      }
      // player + Warden + one echo.
      expect(liveEnemies, 3);
    });

    test('an archetype with no spawn case (an unbuilt Elite boss) is '
        'silently skipped, not a crash', () {
      final (:world, :primary) = spawnLastWarden(
        echoArchetypes: const <BossArchetype>[BossArchetype.umbralTwin],
      );
      world.enemies.bossPhase[primary] = 2;

      expect(() => world.tick(InputSnapshot()), returnsNormally);
      expect(enemiesOfArchetype(world, BossArchetype.umbralTwin), isEmpty);
    });
  });

  group('P4: the floor is removed', () {
    test('before P4, standing off any Windline deals no void damage', () {
      final (:world, :primary) = spawnLastWarden();
      world.enemies.bossPhase[primary] = 2;
      final int player = world.player.index;

      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], 100.0);
    });

    test('once P4 begins, standing off any Windline deals void damage on '
        'a cooldown', () {
      final (:world, :primary) = spawnLastWarden();
      world.enemies.bossPhase[primary] = 3;
      final int player = world.player.index;

      world.tick(InputSnapshot());
      expect(world.entities.health[player], closeTo(91.0, 1e-6));

      // Immediately again — still on cooldown, no further damage yet.
      world.tick(InputSnapshot());
      expect(world.entities.health[player], closeTo(91.0, 1e-6));
    });

    test('standing on a live player-owned Windline avoids the damage '
        'entirely', () {
      final (:world, :primary) = spawnLastWarden();
      world.enemies.bossPhase[primary] = 3;
      final int player = world.player.index;

      world.windlines.add(
        fromX: world.entities.posX[player] - 1.0,
        fromY: world.entities.posY[player],
        toX: world.entities.posX[player] + 1.0,
        toY: world.entities.posY[player],
        expiresAt: world.elapsedSeconds + 10.0,
        ownerIndex: 0,
        trailId: 1,
      );

      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], 100.0);
    });

    test('an expired Windline no longer counts as a platform', () {
      final (:world, :primary) = spawnLastWarden();
      world.enemies.bossPhase[primary] = 3;
      final int player = world.player.index;

      world.windlines.add(
        fromX: world.entities.posX[player] - 1.0,
        fromY: world.entities.posY[player],
        toX: world.entities.posX[player] + 1.0,
        toY: world.entities.posY[player],
        expiresAt: world.elapsedSeconds + 0.001,
        ownerIndex: 0,
        trailId: 1,
      );

      // Let the segment expire before the void-floor check ever runs.
      for (int i = 0; i < 5; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], closeTo(91.0, 1e-6));
    });
  });
}
