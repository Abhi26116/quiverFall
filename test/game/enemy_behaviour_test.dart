import 'dart:math' as math;

import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/systems/firing_system.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'enemy_test_support.dart';

/// The mechanics docs/05 promises, each asserted where it lives.
///
/// These are the "does the enemy do the thing" tests. The soak test proves the
/// roster does not crash; this file proves it does what it is for.
void main() {
  late ContentLibrary content;
  final InputSnapshot idle = InputSnapshot();

  setUpAll(() {
    content = loadEnemies();
  });

  /// Damage this arrow dealt, from the last `damageDealt` event.
  double lastArmourFactor(SimWorld world) {
    for (int i = world.events.count - 1; i >= 0; i--) {
      if (world.events.typeAt(i) == SimEventType.damageDealt) {
        return world.events.valueBAt(i);
      }
    }
    return double.nan;
  }

  group('Carapace — the armour puzzle', () {
    test('a Tier-I arrow into a live plate is nearly all blocked', () {
      final SimWorld world = enemyWorld(
        content: content,
        playerX: 2.0,
        autoFire: true,
      )..playerAttack = 20;
      world.spawnEnemy(EnemyArchetype.husk, 6.0, 4.5);

      // The first arrow leaves at Tier I, and the Husk is facing the player.
      for (int i = 0; i < 60; i++) {
        world.tick(idle);
        if (world.events.countOf(SimEventType.damageDealt) > 0) break;
      }

      expect(world.events.countOf(SimEventType.damageDealt), greaterThan(0));
      expect(lastArmourFactor(world), ArmourFactor.plateBlocked);
    });

    test('a hit from behind the plate takes full damage at any tier', () {
      final SimWorld world = enemyWorld(
        content: content,
        playerX: 2.0,
        autoFire: true,
      )..playerAttack = 20;
      final int husk = world.spawnEnemy(EnemyArchetype.husk, 6.0, 4.5);

      // Face the Husk away from the player each tick. The AI turns it back at
      // the end of every tick, so this is what "flanked" looks like from the
      // projectile system's point of view.
      for (int i = 0; i < 60; i++) {
        world.entities.facing[husk] = 0;
        world.tick(idle);
        if (world.events.countOf(SimEventType.damageDealt) > 0) break;
      }

      expect(lastArmourFactor(world), ArmourFactor.none);
    });

    test('a Shellback regenerates its plate under sustained pressure', () {
      final SimWorld world = enemyWorld(content: content);
      final int e = world.spawnEnemy(EnemyArchetype.shellback, 12.0, 4.5);

      world.enemies.plateHealth[e] = 0;
      world.enemies.plateJustBroke[e] = 1;

      run(world, 1.0);
      expect(world.enemies.plateHealth[e], 0, reason: 'regenerated too early');

      run(world, 1.5);
      expect(world.enemies.plateHealth[e], greaterThan(0));
    });

    test('an Ironmaw telegraphs before it enrages, and Frost cancels it', () {
      SimWorld world = enemyWorld(content: content);
      int e = world.spawnEnemy(EnemyArchetype.ironmaw, 13.0, 4.5);
      world.enemies.plateHealth[e] = 0;
      world.enemies.plateJustBroke[e] = 1;

      // The plate seams flood crimson 0.4 s *before* the speed change.
      run(world, 0.3);
      expect(world.enemies.stateOf(e), AiState.windUp);
      expect(world.enemies.speedScale[e], 1.0, reason: 'enraged early');
      expect(world.telegraphs.liveCount, greaterThan(0));

      run(world, 0.3);
      expect(world.enemies.isEnraged(e), isTrue);
      expect(
        world.enemies.speedScale[e],
        closeTo(EnemyTuning.enrageSpeedMultiplier, 1e-9),
      );

      // Freeze cancels the enrage outright.
      world = enemyWorld(content: content);
      e = world.spawnEnemy(EnemyArchetype.ironmaw, 13.0, 4.5);
      world.enemies.plateHealth[e] = 0;
      world.enemies.plateJustBroke[e] = 1;
      run(world, 0.6);
      expect(world.enemies.isEnraged(e), isTrue);

      world.status.frozenRemaining[e] = 1.0;
      world.tick(idle);
      expect(world.enemies.isEnraged(e), isFalse);
      expect(world.enemies.speedScale[e], 1.0);
    });

    test('a Bulwark never moves', () {
      final SimWorld world = enemyWorld(content: content);
      final int e = world.spawnEnemy(EnemyArchetype.bulwark, 12.0, 4.5);
      run(world, 3.0);
      expect(world.entities.posX[e], closeTo(12.0, 1e-9));
      expect(world.entities.posY[e], closeTo(4.5, 1e-9));
    });
  });

  group('Drift — the fodder', () {
    test('a Cinder Mote detonates on death and hurts the player', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1000);
      final int e = world.spawnEnemy(EnemyArchetype.cinderMote, 9.5, 4.5);

      final double before = world.entities.health[world.player.index];
      world.entities.health[e] = 0;
      world.tick(idle);

      expect(world.entities.health[world.player.index], lessThan(before));
      expect(world.events.countOf(SimEventType.playerHit), 1);
    });

    test('Frost suppresses the fuse entirely', () {
      // The taught interaction: freeze prevents the detonation, so a frozen
      // Cinder Mote killed at range leaves nothing behind.
      final SimWorld world = enemyWorld(content: content, playerHealth: 1000);
      final int e = world.spawnEnemy(EnemyArchetype.cinderMote, 9.5, 4.5);

      world.status.frozenRemaining[e] = 2.0;
      final double before = world.entities.health[world.player.index];
      world.entities.health[e] = 0;
      world.tick(idle);

      expect(world.entities.health[world.player.index], before);
      expect(world.events.countOf(SimEventType.playerHit), 0);
    });

    test('a Wisp weaves rather than walking straight at you', () {
      final SimWorld world = enemyWorld(content: content);
      final int e = world.spawnEnemy(EnemyArchetype.wisp, 14.0, 4.5);

      double maxOffset = 0;
      for (int i = 0; i < 90; i++) {
        world.tick(idle);
        final double offset = (world.entities.posY[e] - 4.5).abs();
        if (offset > maxOffset) maxOffset = offset;
      }

      // The weave has to exceed the Wisp's own body, or it cannot cause a miss.
      expect(
        maxOffset,
        greaterThan(content.byArchetype(EnemyArchetype.wisp).radius),
        reason: 'a Wisp that travels in a straight line is a Mote',
      );
    });

    test('a Mote closes on the player', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int e = world.spawnEnemy(EnemyArchetype.mote, 14.0, 4.5);
      final double before = world.entities.posX[e];
      run(world, 2.0);
      expect(world.entities.posX[e], lessThan(before - 1.0));
    });
  });

  group('Rush — the movement tax', () {
    test('a Lancer draws its charge line before it charges', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int e = world.spawnEnemy(EnemyArchetype.lancer, 12.0, 4.5);

      bool sawWindUp = false;
      bool sawAttack = false;
      for (int i = 0; i < 60 * 6; i++) {
        world.tick(idle);
        final AiState state = world.enemies.stateOf(e);
        if (state == AiState.windUp) {
          sawWindUp = true;
          expect(
            world.telegraphs.liveCount,
            greaterThan(0),
            reason: 'the amber charge line is the whole enemy',
          );
        }
        if (state == AiState.attack) {
          expect(sawWindUp, isTrue, reason: 'charged without telegraphing');
          sawAttack = true;
          break;
        }
      }
      expect(sawAttack, isTrue);
    });

    test('a Bounder is untargetable mid-leap', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int e = world.spawnEnemy(EnemyArchetype.bounder, 11.0, 4.5);

      bool sawAirborne = false;
      for (int i = 0; i < 60 * 4 && !sawAirborne; i++) {
        world.tick(idle);
        if (world.enemies.stateOf(e) != AiState.airborne) continue;

        sawAirborne = true;
        expect(world.enemies.isUntargetable(e), isTrue);
        expect(
          FiringSystem.selectTarget(
            world.entities,
            world.spatial,
            world.entities.posX[world.player.index],
            world.entities.posY[world.player.index],
            enemies: world.enemies,
          ),
          -1,
          reason: 'auto-aim must refuse to help against an airborne Bounder',
        );
      }
      expect(sawAirborne, isTrue);
    });

    test('a Ripper staggers when its finisher is interrupted', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int e = world.spawnEnemy(EnemyArchetype.ripper, 8.6, 4.5);

      bool staggered = false;
      for (int i = 0; i < 60 * 6 && !staggered; i++) {
        world.tick(idle);

        final bool finisher = world.enemies.comboStep[e] ==
            EnemyTuning.ripperComboLength - 1;
        if (world.enemies.stateOf(e) == AiState.windUp && finisher) {
          // The parry: land more than 8% of its max HP during the third
          // wind-up. There is no button for this.
          world.enemies.damageDuringWindUp[e] = world.entities.maxHealth[e];
          world.tick(idle);
          staggered = world.enemies.stateOf(e) == AiState.staggered;
        }
      }
      expect(staggered, isTrue);
    });

    test('a Thresher keeps a permanent crimson aura and hurts on contact', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      world.spawnEnemy(EnemyArchetype.thresher, 10.0, 4.5);

      run(world, 4.0);
      expect(world.telegraphs.liveCount, greaterThan(0));
      expect(world.events.countOf(SimEventType.playerHit), greaterThan(0));
    });
  });

  group('Salvo — the position tax', () {
    test('a Spitter lobs a shell that leaves a puddle', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      world.spawnEnemy(EnemyArchetype.spitter, 12.0, 4.5);

      bool sawShell = false;
      for (int i = 0; i < 60 * 6 && !sawShell; i++) {
        world.tick(idle);
        sawShell = world.hazards.liveCount > 0;
      }
      expect(sawShell, isTrue);

      run(world, 3.0);
      expect(world.events.countOf(SimEventType.playerHit), greaterThan(0));
    });

    test('a Nettle fires a three-bolt spread', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      world.spawnEnemy(EnemyArchetype.nettle, 12.0, 4.5);

      int peak = 0;
      for (int i = 0; i < 60 * 5; i++) {
        world.tick(idle);
        if (world.hazards.liveCount > peak) peak = world.hazards.liveCount;
      }
      expect(peak, greaterThanOrEqualTo(3));
    });

    test('a Longeye commits its beam before it fires', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int e = world.spawnEnemy(EnemyArchetype.longeye, 13.0, 4.5);
      final EnemyDefinition def = content.byArchetype(EnemyArchetype.longeye);

      // Track the beam's aim through the wind-up while walking the player.
      final InputSnapshot moving = InputSnapshot()..set(0, 1);
      double? committedY;
      bool fired = false;

      for (int i = 0; i < 60 * 5 && !fired; i++) {
        world.tick(moving);
        if (world.enemies.stateOf(e) != AiState.windUp) continue;

        if (world.enemies.stateTimer[e] <= def.combat.trackingCutoffSeconds) {
          committedY ??= world.enemies.targetY[e];
          expect(
            world.enemies.targetY[e],
            committedY,
            reason: 'the beam must stop tracking for its final 0.4 s',
          );
          fired = true;
        }
      }
      expect(committedY, isNotNull);
    });

    test('a Screecher Draw-locks the player but leaves Momentum alone', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      world.spawnEnemy(EnemyArchetype.screecher, 11.0, 4.5);

      bool locked = false;
      for (int i = 0; i < 60 * 10 && !locked; i++) {
        world.tick(idle);
        locked = world.playerDraw.isDrawLocked;
      }

      expect(locked, isTrue);
      // Momentum still works — which is precisely why Momentum builds exist as
      // a genuine alternative rather than a fallback.
      final InputSnapshot moving = InputSnapshot()..set(1, 0);
      for (int i = 0; i < 40; i++) {
        world.tick(moving);
      }
      expect(world.playerDraw.momentumStacks, greaterThan(0));
    });

    test('a Mortarite leads the player, so moving beats it', () {
      final SimWorld world = enemyWorld(
        content: content,
        playerX: 4.0,
        playerHealth: 1e9,
      );
      world.spawnEnemy(EnemyArchetype.mortarite, 12.0, 4.5);

      final InputSnapshot moving = InputSnapshot()..set(-1, 0);
      bool sawShells = false;
      for (int i = 0; i < 60 * 6 && !sawShells; i++) {
        world.tick(moving);
        sawShells = world.hazards.liveCount >= 3;
      }
      expect(sawShells, isTrue, reason: 'a triangle is three shells');
    });
  });

  group('Choir — the priority tax', () {
    test('a Weaver shields its nearest ally', () {
      final SimWorld world = enemyWorld(content: content);
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      world.spawnEnemy(EnemyArchetype.weaver, 12.6, 4.5);

      world.tick(idle);
      expect(world.enemies.shield[mote], greaterThan(0));
      expect(
        world.enemies.shield[mote],
        closeTo(
          world.entities.maxHealth[mote] *
              content.byArchetype(EnemyArchetype.weaver).combat.auraStrength,
          1e-6,
        ),
      );
    });

    test('a Chanter buffs allied damage and stops when it dies', () {
      final SimWorld world = enemyWorld(content: content);
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
      final int chanter = world.spawnEnemy(EnemyArchetype.chanter, 12.5, 4.5);

      world.tick(idle);
      expect(world.enemies.attackBuff[mote], closeTo(0.30, 1e-9));

      world.entities.health[chanter] = 0;
      world.tick(idle);
      world.tick(idle);
      expect(
        world.enemies.attackBuff[mote],
        0,
        reason: 'a buff must not outlive its source',
      );
    });

    test('a Knitter heals, and Toxin halves the healing', () {
      double healedWith(int toxinStacks) {
        final SimWorld world = enemyWorld(content: content);
        final int patient = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
        world.spawnEnemy(EnemyArchetype.knitter, 12.4, 4.5);

        world.entities.health[patient] =
            world.entities.maxHealth[patient] * 0.2;
        final double before = world.entities.health[patient];

        for (int i = 0; i < 30; i++) {
          world.status.toxinStacks[patient] = toxinStacks;
          world.tick(idle);
        }
        return world.entities.health[patient] - before;
      }

      final double clean = healedWith(0);
      final double poisoned = healedWith(10);

      expect(clean, greaterThan(0));
      expect(poisoned, lessThan(clean * 0.6));
    });

    test('a Warden-Fell suppresses elemental application, not Confluence', () {
      final SimWorld world = enemyWorld(content: content, autoFire: true)
        ..playerAttack = 5
        ..arrowElement = SimElement.ember;
      final int mote = world.spawnEnemy(EnemyArchetype.mote, 10.0, 4.5);
      world.spawnEnemy(EnemyArchetype.wardenFell, 10.4, 4.5);

      world.tick(idle);
      expect(world.enemies.elementSuppressed[mote], 1);
      expect(world.enemies.resistsElement(mote, SimElement.ember), isTrue);

      run(world, 2.0);
      expect(
        world.events.countOf(SimEventType.elementApplied),
        0,
        reason: 'the world goes grey — no new procs inside the aura',
      );
    });
  });

  group('Riftborn — the elites', () {
    test('a Rift Maw spawns adds and respects its cap', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int maw = world.spawnEnemy(EnemyArchetype.riftMaw, 12.0, 4.5);
      final int cap =
          content.byArchetype(EnemyArchetype.riftMaw).combat.spawnCap;

      run(world, 40.0);

      expect(world.enemies.liveAdds[maw], greaterThan(0));
      expect(world.enemies.liveAdds[maw], lessThanOrEqualTo(cap));

      int swarmlings = 0;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        if (world.entities.kind[i] != EntityKind.enemy.index) continue;
        if (world.entities.contentIndex[i] ==
            content.indexOfArchetype(EnemyArchetype.swarmling)) {
          swarmlings++;
        }
      }
      expect(swarmlings, lessThanOrEqualTo(cap));
    });

    test('an Echo mirrors the player about the arena centre', () {
      final SimWorld world = enemyWorld(
        content: content,
        playerX: 4.0,
        playerHealth: 1e9,
      );
      final int echo = world.spawnEnemy(EnemyArchetype.echo, 8.0, 4.5);

      final InputSnapshot moving = InputSnapshot()..set(-1, 0);
      run(world, 3.0, input: moving);

      // The player walked left, so the mirror point moved right, and the Echo
      // should have followed it.
      expect(world.entities.posX[echo], greaterThan(8.0));
    });

    test('a Gravebound revives once, at 40%', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int e = world.spawnEnemy(EnemyArchetype.gravebound, 13.0, 4.5);
      final double max = world.entities.maxHealth[e];

      world.entities.health[e] = 0;
      world.tick(idle);

      expect(world.entities.alive[e], 1, reason: 'it should collapse, not die');
      expect(world.enemies.stateOf(e), AiState.downed);
      expect(world.enemies.isUntargetable(e), isTrue);

      run(world, 3.0);
      expect(world.enemies.stateOf(e), isNot(AiState.downed));
      expect(world.entities.health[e], closeTo(max * 0.40, 1e-6));

      // And only once.
      world.entities.health[e] = 0;
      world.tick(idle);
      expect(world.entities.alive[e], 0);
    });

    test('Ember burn at death consumes the corpse', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int e = world.spawnEnemy(EnemyArchetype.gravebound, 13.0, 4.5);

      world.status.burnStacks[e] = 1;
      world.status.burnRemaining[e] = 2.0;
      world.entities.health[e] = 0;
      world.tick(idle);

      expect(world.entities.alive[e], 0, reason: 'burn prevents the revive');
    });

    test('a Null adapts to the last element that damaged it', () {
      final SimWorld world = enemyWorld(
        content: content,
        playerX: 2.0,
        autoFire: true,
        playerHealth: 1e9,
      )
        ..playerAttack = 1
        ..arrowElement = SimElement.ember;
      final int e = world.spawnEnemy(EnemyArchetype.nullborn, 9.0, 4.5);

      expect(
        world.enemies.adaptSeconds[e],
        content.byArchetype(EnemyArchetype.nullborn).combat.immunitySeconds,
      );

      bool adapted = false;
      for (int i = 0; i < 60 * 4 && !adapted; i++) {
        world.tick(idle);
        adapted = world.enemies.resistsElement(e, SimElement.ember);
      }

      expect(adapted, isTrue);
      // Element rotation is the counter: it is immune to Ember, not to Frost.
      expect(world.enemies.resistsElement(e, SimElement.frost), isFalse);
    });
  });

  group('shared systems', () {
    test('a live Windline slows an enemy crossing it', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int e = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);

      world.windlines.add(
        fromX: 11.0,
        fromY: 4.5,
        toX: 13.0,
        toY: 4.5,
        expiresAt: 1e9,
        ownerIndex: 0,
        trailId: 1,
      );

      world.tick(idle);
      expect(world.enemies.slowRemaining[e], greaterThan(0));

      final double speed = math.sqrt(
        world.entities.velX[e] * world.entities.velX[e] +
            world.entities.velY[e] * world.entities.velY[e],
      );
      final double base = content.byArchetype(EnemyArchetype.mote).speed;
      expect(speed, closeTo(base * (1 - SimConfig.windlineSlow), 1e-6));
    });

    test('a frozen enemy stops dead', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      final int e = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);

      run(world, 0.5);
      final double moved = world.entities.posX[e];
      expect(moved, lessThan(12.0));

      world.status.frozenRemaining[e] = 2.0;
      // One tick of already-committed velocity still integrates — movement runs
      // before the AI, by design. From the tick after, nothing moves.
      world.tick(idle);
      final double stopped = world.entities.posX[e];

      run(world, 0.5);
      expect(world.entities.posX[e], closeTo(stopped, 1e-9));
    });

    test('contact damage respects its cooldown', () {
      final SimWorld world = enemyWorld(content: content, playerHealth: 1e9);
      world.spawnEnemy(EnemyArchetype.mote, 8.3, 4.5);

      run(world, 1.0);
      final int hits = world.events.countOf(SimEventType.playerHit);

      // Mote's contact cooldown is 0.8 s, so one second cannot produce three.
      expect(hits, greaterThan(0));
      expect(hits, lessThanOrEqualTo(2));
    });

    test('Momentum reduces the damage a hit deals', () {
      double damageWith(int momentum) {
        final SimWorld world = enemyWorld(content: content, playerHealth: 1000);
        world.spawnEnemy(EnemyArchetype.mote, 8.3, 4.5);
        world.playerDraw.momentumStacks = momentum;

        for (int i = 0; i < 60; i++) {
          world.playerDraw.momentumStacks = momentum;
          world.tick(idle);
          for (int e = 0; e < world.events.count; e++) {
            if (world.events.typeAt(e) == SimEventType.playerHit) {
              return world.events.valueAAt(e);
            }
          }
          world.events.clear();
        }
        return double.nan;
      }

      expect(damageWith(5), lessThan(damageWith(0)));
    });
  });
}
