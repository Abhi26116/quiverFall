import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/boon_inventory.dart';
import 'package:quiverfall/game/boons/loadout_resolver.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/combat_modifiers.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/systems/confluence_system.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boon_test_support.dart';
import 'enemy_test_support.dart';

/// docs/20 Phase 9 exit criterion: **"Every one of the 112 Boons has a test
/// asserting its effect."**
///
/// Three layers, because "its effect" means different things for different
/// cards:
///
///  1. **Every card, without exception.** Taking it moves exactly the channels
///     it declares, by exactly the amounts it declares, and nothing else. For
///     the 63 pure-data cards this *is* the effect — there is nothing else to
///     assert, and this catches a typo'd channel name or a value off by a
///     factor of ten.
///  2. **Every card reaches the simulation.** A channel that composes correctly
///     and is then read by nothing is a card that does nothing. Asserted end to
///     end against a live world for each channel that has a home.
///  3. **Behaviour cards.** The 49 that change a rule rather than a number.
///     Registration is asserted here for all of them; the gameplay assertion
///     lives in `boon_behaviour_test.dart`, beside the implementation.
///
/// [pendingBehaviourWork] is the honest ledger of layer 3. It is a list of
/// cards whose *behaviour* is declared and registered but not yet implemented,
/// and a test below fails if it ever grows.
void main() {
  late BoonCatalogue catalogue;
  late ContentLibrary content;

  setUpAll(() {
    catalogue = loadBoons();
    content = loadEnemies();
  });

  /// A world with a build applied, ready to assert against.
  ({SimWorld world, BoonInventory inv}) build(
    List<String> keys, {
    double baseAttack = 10.0,
    double baseMaxHealth = 100.0,
    int copies = 1,
  }) {
    final BoonInventory inv = BoonInventory(catalogue: catalogue);
    // Every tag granted, so a card's requirements never block the test — this
    // file is about what a card *does*, not about whether it may be offered.
    for (final BuildTag tag in BuildTag.values) {
      inv.grantTag(tag);
    }
    for (final String key in keys) {
      final BoonDefinition def = catalogue.byKey(key)!;
      for (int i = 0; i < copies; i++) {
        inv.take(def);
      }
    }

    final SimWorld world = SimWorld(seed: 99, content: content);
    world.spawnPlayer(8.0, 4.5);
    LoadoutResolver.apply(
      world,
      inv.stats,
      baseAttack: baseAttack,
      baseMaxHealth: baseMaxHealth,
    );
    return (world: world, inv: inv);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Layer 1 — every card composes exactly what it declares
  // ────────────────────────────────────────────────────────────────────────

  group('every Boon composes exactly what it declares', () {
    test('all 112 are covered by this group', () {
      // Guards the guard: if a card is added and this file is not updated, the
      // loop below silently covers it, which is fine — but if the *catalogue*
      // shrinks, the exit criterion quietly stops meaning 112.
      expect(catalogue.length, BoonCatalogue.expectedCount);
    });

    for (int id = 1; id <= BoonCatalogue.expectedCount; id++) {
      test('#$id', () {
        final BoonDefinition def = catalogue.byId(id)!;
        final BoonInventory inv = BoonInventory(catalogue: catalogue);
        for (final BuildTag tag in BuildTag.values) {
          inv.grantTag(tag);
        }

        expect(inv.stats.isEmpty, isTrue, reason: 'dirty before the test');
        inv.take(def);

        // Declared channels landed, at the declared value.
        for (final BoonModifier mod in def.modifiers) {
          expect(
            inv.stats[mod.channel],
            closeTo(mod.value, 1e-12),
            reason: '#$id ${def.name}: ${mod.channel.name} did not arrive',
          );
        }

        // Nothing else moved. This is the half that catches a copy-pasted
        // modifier block left over from the card above.
        final Set<String> declared =
            def.modifiers.map((BoonModifier m) => m.channel.name).toSet();
        final Map<String, double> actual = inv.stats.describe();
        expect(
          actual.keys.toSet().difference(declared),
          isEmpty,
          reason: '#$id ${def.name} moved channels it does not declare: '
              '${actual.keys.toSet().difference(declared)}',
        );

        // A behaviour card registers its behaviour.
        if (def.behaviour != null) {
          expect(
            inv.hasBehaviour(def.behaviour!),
            isTrue,
            reason: '#$id ${def.name} declares ${def.behaviour!.name} but it '
                'is not live after taking the card',
          );
        }

        // Something changed. A card that composes to nothing and registers no
        // behaviour is a blank, whatever the catalogue says.
        expect(
          def.modifiers.isNotEmpty || def.behaviour != null,
          isTrue,
          reason: '#$id ${def.name} is a blank',
        );
      });
    }

    test('copies scale exactly, for every stacking card', () {
      for (final BoonDefinition def in catalogue.all) {
        if (def.maxCopies < 2 || def.modifiers.isEmpty) continue;

        final BoonInventory inv = BoonInventory(catalogue: catalogue);
        for (final BuildTag tag in BuildTag.values) {
          inv.grantTag(tag);
        }
        for (int i = 0; i < def.maxCopies; i++) {
          inv.take(def);
        }

        for (final BoonModifier mod in def.modifiers) {
          if (mod.channel.isMultiplicative) {
            double expected = 1.0;
            for (int i = 0; i < def.maxCopies; i++) {
              expected *= mod.value;
            }
            expect(
              inv.stats[mod.channel],
              closeTo(expected, 1e-9),
              reason: '#${def.id} ${def.name} ×${def.maxCopies}: '
                  '${mod.channel.name} should multiply, not sum',
            );
          } else {
            expect(
              inv.stats[mod.channel],
              closeTo(mod.value * def.maxCopies, 1e-9),
              reason: '#${def.id} ${def.name} ×${def.maxCopies}: '
                  '${mod.channel.name} should sum',
            );
          }
        }
      }
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  // Layer 2 — the channels reach the simulation
  // ────────────────────────────────────────────────────────────────────────

  group('offence reaches the world', () {
    test('#1 Sharpened Points raises dealt damage, and by the right amount', () {
      // The end-to-end one. Everything else in this group asserts a field;
      // this asserts an enemy actually loses more HP.
      double damageDealtWith(List<String> keys) {
        final ({SimWorld world, BoonInventory inv}) b =
            build(keys, baseAttack: 12.0);
        final SimWorld world = b.world..autoFire = true;
        final int mote = world.spawnEnemy(EnemyArchetype.mote, 12.0, 4.5);
        world.enemies.speedScale[0] = 0;
        world.entities.maxHealth[mote] = 1e6;
        world.entities.health[mote] = 1e6;

        for (int i = 0; i < 90; i++) {
          world.tick(InputSnapshot());
        }
        return 1e6 - world.entities.health[mote];
      }

      final double plain = damageDealtWith(<String>[]);
      final double boosted = damageDealtWith(<String>['sharpened_points']);

      expect(plain, greaterThan(0), reason: 'nothing was damaged at all');
      // +8 %, exactly. Not "more" — a test that only asserts direction would
      // pass with the modifier applied twice.
      expect(boosted / plain, closeTo(1.08, 0.01));
    });

    test('#5 Rapid Nock speeds the bow up', () {
      expect(
        build(<String>['rapid_nock']).world.fireRateMultiplier,
        closeTo(1.07, 1e-9),
      );
      expect(
        build(<String>['rapid_nock'], copies: 5).world.fireRateMultiplier,
        closeTo(1.35, 1e-9),
      );
    });

    test('#11 Pierce Study adds pierce', () {
      expect(build(<String>['pierce_study'], copies: 3).world.basePierce, 3);
    });

    test('#10 Split Shot adds an arrow and pays for it', () {
      final SimWorld world = build(<String>['split_shot']).world;
      expect(world.extraArrows, 1);
      expect(world.volleyDamageMultiplier, closeTo(0.85, 1e-9));
    });

    test('#17 Twin Nock adds two, at a steeper cost', () {
      final SimWorld world = build(<String>['twin_nock']).world;
      expect(world.extraArrows, 2);
      expect(world.volleyDamageMultiplier, closeTo(0.75, 1e-9));
    });

    test('a volley actually leaves the bow', () {
      final ({SimWorld world, BoonInventory inv}) b =
          build(<String>['twin_nock']);
      final SimWorld world = b.world..autoFire = true;
      world.spawnEnemy(EnemyArchetype.mote, 14.0, 4.5);
      world.enemies.speedScale[0] = 0;

      world.tick(InputSnapshot());

      int arrows = 0;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        if (world.entities.kind[i] == EntityKind.projectile.index) arrows++;
      }
      expect(arrows, 3, reason: 'Twin Nock should release three arrows');
    });
  });

  group('conditional offence resolves per hit', () {
    CombatModifiers modsFor(List<String> keys) =>
        build(keys).world.combat;

    test('#6 Barbed Tips applies below half HP and not above', () {
      final CombatModifiers c = modsFor(<String>['barbed_tips']);
      expect(
        c.damageSumFor(
            targetHealthFraction: 0.9, shotDistance: 0, targetId: 1),
        closeTo(0, 1e-12),
      );
      expect(
        c.damageSumFor(
            targetHealthFraction: 0.4, shotDistance: 0, targetId: 1),
        closeTo(0.10, 1e-12),
      );
    });

    test('#12 Executioner stacks with Barbed Tips at very low HP', () {
      // Both conditions true at 10 % HP, and they *sum* — docs/04 §4.1 rule 1.
      final CombatModifiers c =
          modsFor(<String>['barbed_tips', 'executioner']);
      expect(
        c.damageSumFor(
            targetHealthFraction: 0.10, shotDistance: 0, targetId: 1),
        closeTo(0.50, 1e-12),
      );
    });

    test('#7 Steady Aim applies only while stationary', () {
      final CombatModifiers c = modsFor(<String>['steady_aim'])
        ..playerStationary = true;
      expect(
        c.damageSumFor(
            targetHealthFraction: 1.0, shotDistance: 0, targetId: 1),
        closeTo(0.06, 1e-12),
      );
      c.playerStationary = false;
      expect(
        c.damageSumFor(
            targetHealthFraction: 1.0, shotDistance: 0, targetId: 1),
        closeTo(0, 1e-12),
      );
    });

    test('#8 Follow Through applies to the last enemy hit', () {
      final CombatModifiers c = modsFor(<String>['follow_through'])
        ..lastHitTarget = 42;
      expect(
        c.damageSumFor(
            targetHealthFraction: 1.0, shotDistance: 0, targetId: 42),
        closeTo(0.09, 1e-12),
      );
      expect(
        c.damageSumFor(
            targetHealthFraction: 1.0, shotDistance: 0, targetId: 43),
        closeTo(0, 1e-12),
      );
    });

    test('#16 Marksman scales with distance and stops at its cap', () {
      final CombatModifiers c = modsFor(<String>['marksman']);
      expect(
        c.damageSumFor(
            targetHealthFraction: 1.0, shotDistance: 5.0, targetId: 1),
        closeTo(0.20, 1e-12),
      );
      // Cap is +60 %, reached at 15 u. A 40 u shot must not pay 160 %.
      expect(
        c.damageSumFor(
            targetHealthFraction: 1.0, shotDistance: 40.0, targetId: 1),
        closeTo(0.60, 1e-12),
      );
    });

    test('#50 Slipstream scales with live Momentum', () {
      final CombatModifiers c = modsFor(<String>['slipstream'])
        ..momentumStacks = 4;
      expect(
        c.damageSumFor(
            targetHealthFraction: 1.0, shotDistance: 0, targetId: 1),
        closeTo(0.12, 1e-12),
      );
    });

    test('#15 Crescendo ramps with the streak and stops at its cap', () {
      final CombatModifiers c = modsFor(<String>['crescendo'])..hitStreak = 5;
      expect(
        c.damageSumFor(
            targetHealthFraction: 1.0, shotDistance: 0, targetId: 1),
        closeTo(0.10, 1e-12),
      );
      c.hitStreak = 500;
      expect(
        c.damageSumFor(
            targetHealthFraction: 1.0, shotDistance: 0, targetId: 1),
        closeTo(0.40, 1e-12),
      );
    });

    test('a missed arrow breaks the Crescendo streak', () {
      // docs/09 §9.2 #15: "resets on a miss". A miss has to be defined, and the
      // definition is "an arrow retired having connected with nothing" — not
      // "a tick with no damage", which would break the streak between two
      // arrows of the same volley.
      //
      // A wall makes this deterministic. Despawning the target instead would
      // depend on an arrow happening to be in flight at that exact tick, which
      // is a coin flip dressed up as a test.
      final BoonInventory inv = BoonInventory(catalogue: catalogue);
      inv.take(catalogue.byKey('crescendo')!);

      final SimWorld world = SimWorld(
        seed: 5,
        content: content,
        arena: Arena.standard(walls: const <Rect>[Rect(9.0, 0.0, 10.0, 9.0)]),
      )..autoFire = true;
      world.spawnPlayer(2.0, 4.5);
      LoadoutResolver.apply(world, inv.stats, baseAttack: 10);

      // A target beyond the wall: auto-aim has something to shoot at, and every
      // arrow stops in the wall short of it.
      world.spawnEnemy(EnemyArchetype.mote, 14.0, 4.5);
      world.enemies.speedScale[0] = 0;

      world.combat.hitStreak = 7;
      for (int i = 0; i < 120; i++) {
        world.tick(InputSnapshot());
      }

      expect(
        world.combat.hitStreak,
        0,
        reason: 'arrows stopping in a wall must count as misses',
      );
    });

    test('#3 Cruel Edge raises the crit multiplier, not the base', () {
      final CombatModifiers c = modsFor(<String>['cruel_edge']);
      expect(c.critMultiplier, closeTo(1.80 + 0.15, 1e-12));
    });
  });

  group('defence reaches the world', () {
    test('#26 Toughened Hide raises max HP', () {
      expect(
        build(<String>['toughened_hide'], baseMaxHealth: 200)
            .world
            .entities
            .maxHealth[0],
        closeTo(220, 1e-9),
      );
    });

    test('raising max HP does not heal, and lowering it does not kill', () {
      // Two forms of the same bug. Taking Toughened Hide at 30 % must leave the
      // player at 30 %; Ruin halving max HP must leave them alive.
      final BoonInventory inv = BoonInventory(catalogue: catalogue);
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(8.0, 4.5);
      world.entities.maxHealth[0] = 100;
      world.entities.health[0] = 30;

      inv.take(catalogue.byKey('toughened_hide')!);
      LoadoutResolver.apply(world, inv.stats,
          baseAttack: 10);
      expect(world.entities.maxHealth[0], closeTo(110, 1e-9));
      expect(world.entities.health[0], closeTo(33, 1e-9),
          reason: 'the fraction must be preserved, not the absolute value');

      inv.take(catalogue.byKey('ruin')!);
      LoadoutResolver.apply(world, inv.stats,
          baseAttack: 10);
      expect(world.entities.maxHealth[0], closeTo(60, 1e-9));
      expect(world.entities.health[0], greaterThan(0),
          reason: 'halving max HP killed the player');
    });

    test('#27 Warded and #29 Bulwark Stance stay separate sources', () {
      // Never summed. docs/04 §4.1 rule 2: additive DR reaches 100 % and heals.
      final SimWorld world =
          build(<String>['warded', 'bulwark_stance'], copies: 3).world;
      expect(world.boonDamageReduction, closeTo(0.12, 1e-9));
      expect(world.stationaryDamageReduction, closeTo(0.24, 1e-9));

      world.combat.playerStationary = true;
      final double factor = LoadoutResolver.incomingDamageFactor(world);
      // Multiplicative: 1 − (1−0.12)(1−0.24) = 0.3312, not 0.36.
      expect(factor, closeTo(1.0 - 0.3312, 1e-9));
    });

    test('damage reduction is capped at 75 % however it is stacked', () {
      final SimWorld world =
          build(<String>['warded', 'bulwark_stance', 'stonewall'], copies: 4)
              .world;
      world.combat.playerStationary = true;
      world.playerDraw.momentumStacks = 5;
      expect(
        LoadoutResolver.incomingDamageFactor(world),
        greaterThanOrEqualTo(0.25 - 1e-9),
        reason: 'mitigation broke the 75 % cap',
      );
    });

    test('#109 Hollow Bones makes the player take more', () {
      final SimWorld world = build(<String>['hollow_bones']).world;
      expect(world.damageTakenMultiplier, closeTo(1.5, 1e-9));
      expect(LoadoutResolver.incomingDamageFactor(world), closeTo(1.5, 1e-9));
    });

    test('#32 Lifedraw, #31 Thorns, #36 Regrowth, #28 Second Skin arrive', () {
      final SimWorld world = build(<String>[
        'lifedraw',
        'thorns',
        'regrowth',
        'second_skin',
      ]).world;
      expect(world.lifesteal, closeTo(0.03, 1e-9));
      expect(world.thornsReflect, closeTo(0.15, 1e-9));
      expect(world.regenWhileMoving, closeTo(0.008, 1e-9));
      expect(world.healOnRoomClear, closeTo(0.04, 1e-9));
    });

    test('#35 Absorption and #33 Shieldweave arrive', () {
      final SimWorld world =
          build(<String>['absorption', 'shieldweave']).world;
      expect(world.elementalResist, closeTo(0.35, 1e-9));
      expect(world.shieldPerMomentum, closeTo(0.02, 1e-9));
    });
  });

  group('mobility reaches the world', () {
    test('#45 Fleetfoot makes the player move faster, measurably', () {
      double distanceIn(List<String> keys, int ticks) {
        final SimWorld world = build(keys).world;
        final double x0 = world.entities.posX[0];
        final InputSnapshot input = InputSnapshot()..set(1, 0);
        for (int i = 0; i < ticks; i++) {
          world.tick(input);
        }
        return world.entities.posX[0] - x0;
      }

      // Few enough ticks that Momentum has not yet built, so this isolates the
      // Boon from the Momentum bonus.
      final double plain = distanceIn(<String>[], 15);
      final double fast = distanceIn(<String>['fleetfoot'], 15);
      expect(fast / plain, closeTo(1.08, 0.02));
    });

    test('Momentum grants its speed bonus — it never used to', () {
      // DrawState.moveSpeedBonus existed from Phase 3 and was read by nothing
      // until Phase 9. Half of Momentum silently did not work.
      final SimWorld world = build(<String>[]).world;

      // Build to max Momentum by pressing *into the left wall*. Momentum counts
      // intent to move, not distance covered, so this banks five stacks without
      // spending any of the arena — measuring from a running start would run
      // the player into the far wall and read zero.
      final InputSnapshot left = InputSnapshot()..set(-1, 0);
      for (int i = 0; i < 180; i++) {
        world.tick(left);
      }
      expect(world.playerDraw.isAtMaxMomentum, isTrue);

      final double before = world.entities.posX[0];
      final InputSnapshot right = InputSnapshot()..set(1, 0);
      const int ticks = 15;
      for (int i = 0; i < ticks; i++) {
        world.tick(right);
      }
      final double moved = world.entities.posX[0] - before;
      const double unboosted =
          SimConfig.playerMoveSpeed * ticks * SimConfig.fixedStep;

      // Five stacks at +3 % each is +15 %.
      expect(moved, closeTo(unboosted * 1.15, unboosted * 0.02));
    });

    test('#46 Gale Step raises the Momentum ceiling', () {
      expect(
        build(<String>['gale_step'], copies: 3).world.playerDraw.maxMomentum,
        DrawState.baseMaxMomentum + 3,
      );
    });

    test('#47 Quick Recovery extends the grace window, multiplying', () {
      final SimWorld world =
          build(<String>['quick_recovery'], copies: 3).world;
      expect(
        world.playerDraw.graceSeconds,
        closeTo(DrawState.momentumGraceSeconds * 1.4 * 1.4 * 1.4, 1e-9),
      );
    });

    test('#48 Light Boots shortens the charge time', () {
      final SimWorld world = build(<String>['light_boots']).world;
      expect(
        world.playerDraw.stackChargeSeconds,
        closeTo(DrawState.secondsPerMomentumStack / 1.25, 1e-9),
      );
    });

    test('#38 Stonewall trades speed for mitigation', () {
      final SimWorld world = build(<String>['stonewall']).world;
      expect(world.boonDamageReduction, closeTo(0.25, 1e-9));
      expect(
        world.playerMoveSpeed,
        closeTo(SimConfig.playerMoveSpeed * 0.85, 1e-9),
      );
    });
  });

  group('Windline and Confluence reach the world', () {
    test('#59 Long Weave extends trails', () {
      expect(
        build(<String>['long_weave'], copies: 5).world.windlineDuration,
        closeTo(SimConfig.windlineDuration + 1.25, 1e-9),
      );
    });

    test('#61 Wide Thread widens the intersection', () {
      expect(
        build(<String>['wide_thread'], copies: 3).world.windlineHitWidth,
        closeTo(SimConfig.windlineHitWidth * 1.6, 1e-9),
      );
    });

    test('#65 Deep Weave and #70 Lattice raise the stack cap', () {
      expect(
        build(<String>['deep_weave']).world.maxConfluenceStacks,
        ConfluenceTuning.defaultMaxStacks + 1,
      );
      expect(
        build(<String>['lattice']).world.maxConfluenceStacks,
        ConfluenceTuning.defaultMaxStacks + 2,
      );
    });

    test('the stack cap is clamped to the bonus table', () {
      // Both cards together is +3 on a base of 3, which would index past the
      // end of ConfluenceTuning.bonusByStacks.
      final SimWorld world =
          build(<String>['deep_weave', 'lattice']).world;
      expect(world.maxConfluenceStacks, ConfluenceTuning.maxStacks);
      expect(
        ConfluenceTuning.bonusByStacks.length,
        greaterThan(ConfluenceTuning.maxStacks),
        reason: 'the clamp and the table have drifted apart',
      );
    });

    test('#60 Bright Thread and #64 Thread Study scale Confluence', () {
      expect(
        build(<String>['bright_thread', 'thread_study'])
            .world
            .confluenceDamageMultiplier,
        closeTo(1.23, 1e-9),
      );
    });

    test('#74 Weaver\'s Grace starts every arrow already threaded', () {
      final ({SimWorld world, BoonInventory inv}) b =
          build(<String>['weavers_grace']);
      final SimWorld world = b.world..autoFire = true;
      expect(world.confluenceHeadStart, 1);

      world.spawnEnemy(EnemyArchetype.mote, 14.0, 4.5);
      world.enemies.speedScale[0] = 0;
      world.tick(InputSnapshot());

      bool sawThreadedArrow = false;
      for (int i = 0; i < world.entities.highWater; i++) {
        if (world.entities.alive[i] == 0) continue;
        if (world.entities.kind[i] != EntityKind.projectile.index) continue;
        if (world.projectiles.confluenceStacks[i] >= 1) sawThreadedArrow = true;
      }
      expect(sawThreadedArrow, isTrue);
    });

    test('#63 Tangle and #66 Cutting Lines arrive', () {
      final SimWorld world =
          build(<String>['tangle', 'cutting_lines']).world;
      expect(world.windlineSlow, closeTo(0.08, 1e-9));
      expect(world.windlineDamageFraction, closeTo(0.015, 1e-9));
    });
  });

  group('applying a build twice changes nothing', () {
    test('LoadoutResolver is idempotent', () {
      // Called at every room start. Reading the world's current values and
      // multiplying would compound the same Boons on every room transition —
      // the classic form of this bug, and one that looks fine for three rooms.
      final ({SimWorld world, BoonInventory inv}) b = build(<String>[
        'sharpened_points',
        'fleetfoot',
        'long_weave',
        'rapid_nock',
        'toughened_hide',
      ]);

      final double attack = b.world.playerAttack;
      final double speed = b.world.playerMoveSpeed;
      final double duration = b.world.windlineDuration;
      final double rate = b.world.fireRateMultiplier;
      final double maxHp = b.world.entities.maxHealth[0];

      for (int i = 0; i < 5; i++) {
        // Same base values the build was composed with. Re-applying must be a
        // no-op, not a compounding.
        LoadoutResolver.apply(b.world, b.inv.stats, baseAttack: 10.0);
      }

      expect(b.world.playerAttack, closeTo(attack, 1e-12));
      expect(b.world.playerMoveSpeed, closeTo(speed, 1e-12));
      expect(b.world.windlineDuration, closeTo(duration, 1e-12));
      expect(b.world.fireRateMultiplier, closeTo(rate, 1e-12));
      expect(b.world.entities.maxHealth[0], closeTo(maxHp, 1e-12));
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  // Layer 3 — the ledger
  // ────────────────────────────────────────────────────────────────────────

  group('the behaviour ledger is honest', () {
    test('every pending entry names a real, registered behaviour', () {
      for (final BoonBehaviour b in pendingBehaviourWork) {
        final Iterable<BoonDefinition> cards = catalogue.all
            .where((BoonDefinition d) => d.behaviour == b);
        expect(
          cards,
          isNotEmpty,
          reason: '${b.name} is listed as pending but no card declares it',
        );
      }
    });

    test('the ledger has not grown', () {
      // The number that must only ever go down. Phase 9 finishes when it is
      // zero; until then this is the honest count of how much of the catalogue
      // is declared but inert.
      expect(
        pendingBehaviourWork.length,
        lessThanOrEqualTo(13),
        reason: 'a behaviour was added without being implemented',
      );
    });
  });
}

/// Behaviours that are declared, parsed, and registered on the inventory — but
/// whose *gameplay* is not implemented yet.
///
/// Kept as an explicit list rather than left implicit, because "the card is in
/// the catalogue" and "the card does something" are different claims and only
/// one of them is currently true for these. Each one moves out of this list
/// when its implementation and its own test land together.
const Set<BoonBehaviour> pendingBehaviourWork = <BoonBehaviour>{
  // ── Needs input plumbing ────────────────────────────────────────────────
  // Double-tap detection is a view concern, and InputSnapshot has no notion of
  // a gesture yet. These three land with the Boon choice UI.
  BoonBehaviour.dash,
  BoonBehaviour.blink,
  BoonBehaviour.ghostStep,

  // ── Needs the element system extended ───────────────────────────────────
  // Reactions exist but have no spread, no chain, and no cooldown switch. All
  // three are edits to ElementSystem rather than new plumbing.
  BoonBehaviour.wildfire,
  BoonBehaviour.reactive,
  BoonBehaviour.prismbreak,

  // ── Needs a Windline mutation pass ──────────────────────────────────────
  // Windlines are immutable once laid. Drifting them and detonating around a
  // crossing both need the store to support moving a segment.
  BoonBehaviour.livingThread,
  BoonBehaviour.resonantWeave,
  BoonBehaviour.wardingLine,

  // ── Needs Momentum-gated chaining ───────────────────────────────────────
  BoonBehaviour.stormfoot,

  // ── Needs systems outside the simulation ────────────────────────────────
  // Gold, room previews, and the draw's own rarity upgrade. All three land
  // with the Shrine and the Boon choice UI.
  BoonBehaviour.goldenArrow,
  BoonBehaviour.treasureSense,
  BoonBehaviour.bloodprice,
};
