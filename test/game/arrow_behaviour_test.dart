import 'dart:math' as math;

import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'affix_test_support.dart';
import 'arrow_test_support.dart';
import 'enemy_test_support.dart';
import 'hero_test_support.dart';

/// Task 5's arrow-behaviour half — mirrors what `hero_behaviour_test.dart`
/// is for heroes. Only 4 of the 12 arrows carry an [ArrowBehaviour] (the
/// rest are plain StatModifiers, already exercised by `arrow_catalogue_test`
/// and `HeroLoadoutResolver`'s own tests), and all 4 are implemented here —
/// unlike the hero ledger, there is currently nothing left pending. The
/// "Affixes" group at the end is the same story for the one affix
/// (Echoing) that needed code rather than a rolled value into an existing
/// channel.
void main() {
  final HeroCatalogue heroes = loadHeroes();
  final ArrowCatalogue arrows = loadArrows();
  final AffixCatalogue affixes = loadAffixes();
  final ContentLibrary content = loadEnemies();

  // A hero with no passive that touches elements, Confluence, or damage —
  // Wren's Trueshot (crit chance, Tier-III homing) never interferes with
  // any of the four arrows under test here.
  final HeroDefinition wren = heroes.byArchetype(HeroArchetype.wren)!;

  final ArrowDefinition ashShaft = arrows.byArchetype(ArrowArchetype.ashShaft)!;
  final ArrowDefinition skimmer = arrows.byArchetype(ArrowArchetype.skimmer)!;
  final ArrowDefinition twinfang = arrows.byArchetype(ArrowArchetype.twinfang)!;
  final ArrowDefinition ghostshaft = arrows.byArchetype(ArrowArchetype.ghostshaft)!;
  final ArrowDefinition prismshaft = arrows.byArchetype(ArrowArchetype.prismshaft)!;

  SimWorld buildWorld(
    ArrowDefinition arrow, {
    Arena? arena,
    double playerX = 4.0,
    List<Affix> instanceAffixes = const <Affix>[],
  }) {
    final SimWorld world = SimWorld(seed: 301, content: content, arena: arena)
      ..autoFire = true;
    world.spawnPlayer(playerX, 4.5);
    HeroLoadoutResolver.apply(
      world,
      wren,
      const HeroState(heroId: 'wren'),
      arrow,
      ArrowInstance(arrowId: arrow.key, affixes: instanceAffixes),
      affixes: affixes,
    );
    return world;
  }

  int spawnTarget(SimWorld world, double x, {double y = 4.5}) {
    final int target = world.spawnEnemy(EnemyArchetype.mote, x, y);
    world.enemies.speedScale[target] = 0;
    world.entities.maxHealth[target] = 1e9;
    world.entities.health[target] = 1e9;
    return target;
  }

  double? firstDamageDealt(SimWorld world, {int ticks = 200}) {
    final InputSnapshot idle = InputSnapshot();
    for (int t = 0; t < ticks; t++) {
      world.tick(idle);
      for (int e = 0; e < world.events.count; e++) {
        if (world.events.typeAt(e) == SimEventType.damageDealt) {
          return world.events.valueAAt(e);
        }
      }
    }
    return null;
  }

  group('Prismshaft', () {
    test('cycles all four elements, one per shot', () {
      final SimWorld world = buildWorld(prismshaft);
      spawnTarget(world, 12.0);

      final List<int> elements = <int>[];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 400 && elements.length < 4; t++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.arrowFired) {
            elements.add(world.projectiles.element[world.events.entityAAt(e)]);
          }
        }
        world.events.clear();
      }
      expect(elements, hasLength(4));
      expect(elements, <int>[
        SimElement.ember.index,
        SimElement.frost.index,
        SimElement.storm.index,
        SimElement.toxin.index,
      ]);
    });
  });

  group('Twinfang', () {
    test('fires 2 arrows, each starting with a guaranteed Confluence stack', () {
      final SimWorld world = buildWorld(twinfang);
      spawnTarget(world, 12.0);

      world.tick(InputSnapshot());
      final List<int> slots = <int>[
        for (int e = 0; e < world.events.count; e++)
          if (world.events.typeAt(e) == SimEventType.arrowFired)
            world.events.entityAAt(e),
      ];
      expect(slots, hasLength(2));
      for (final int slot in slots) {
        expect(world.projectiles.confluenceStacks[slot], 1);
        expect(world.projectiles.confluenceBonus[slot], closeTo(0.40, 1e-9));
      }
    });

    test('the two arrows start apart and converge to cross ~6 u ahead', () {
      final SimWorld world = buildWorld(twinfang);
      spawnTarget(world, 12.0); // due east, so the aim line is ~horizontal

      world.tick(InputSnapshot());
      final List<int> slots = <int>[
        for (int e = 0; e < world.events.count; e++)
          if (world.events.typeAt(e) == SimEventType.arrowFired)
            world.events.entityAAt(e),
      ];
      expect(slots, hasLength(2));

      final double y0 = world.entities.posY[slots[0]];
      final double y1 = world.entities.posY[slots[1]];
      expect((y0 - 4.5).abs(), greaterThan(0.05),
          reason: 'the two arrows must not spawn from the same point');
      expect(y0 + y1, closeTo(9.0, 0.05),
          reason: 'the two spawn points must be symmetric about the aim line');

      // Each path, extended out to x = playerX + 6, should land near the
      // aim line's own y — the crossing point both arrows are aimed at.
      for (final int slot in slots) {
        final double x0 = world.entities.posX[slot];
        final double sy0 = world.entities.posY[slot];
        final double vx = world.entities.velX[slot];
        final double vy = world.entities.velY[slot];
        final double t = (10.0 - x0) / vx;
        expect(sy0 + vy * t, closeTo(4.5, 0.05));
      }
    });
  });

  group('Skimmer', () {
    test('ricochets off an interior wall instead of despawning', () {
      final Arena arena = Arena.standard(
        walls: <Rect>[const Rect(5.0, 3.0, 5.3, 6.0)],
      );
      final SimWorld world = buildWorld(skimmer, arena: arena, playerX: 2.0);
      spawnTarget(world, 12.0);

      world.tick(InputSnapshot());
      int? slot;
      for (int e = 0; e < world.events.count; e++) {
        if (world.events.typeAt(e) == SimEventType.arrowFired) {
          slot = world.events.entityAAt(e);
        }
      }
      expect(slot, isNotNull);
      expect(world.projectiles.ricochetsLeft[slot!], 2);

      final InputSnapshot idle = InputSnapshot();
      bool bounced = false;
      for (int t = 0; t < 60; t++) {
        world.tick(idle);
        if (world.entities.alive[slot] == 1 && world.entities.velX[slot] < 0) {
          bounced = true;
          break;
        }
      }
      expect(bounced, isTrue,
          reason: 'the arrow must still be alive, now heading back west');
      expect(world.projectiles.ricochetsLeft[slot], 1);
    });

    test('ricochets to the nearest other enemy after landing a hit', () {
      final SimWorld world = buildWorld(skimmer);
      final int primary = spawnTarget(world, 8.0);
      final int secondary = spawnTarget(world, 8.0, y: 6.0);

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 200; t++) {
        world.tick(idle);
      }
      expect(world.entities.health[primary], lessThan(1e9));
      expect(world.entities.health[secondary], lessThan(1e9));
    });

    test('a plain arrow does not ricochet off the same wall', () {
      final Arena arena = Arena.standard(
        walls: <Rect>[const Rect(5.0, 3.0, 5.3, 6.0)],
      );
      final SimWorld world = buildWorld(ashShaft, arena: arena, playerX: 2.0);
      spawnTarget(world, 12.0);

      world.tick(InputSnapshot());
      int? slot;
      for (int e = 0; e < world.events.count; e++) {
        if (world.events.typeAt(e) == SimEventType.arrowFired) {
          slot = world.events.entityAAt(e);
        }
      }
      expect(slot, isNotNull);

      // A short window, checked right around when this specific arrow
      // should reach the wall (~13 ticks at 14 u/s over 3 u) — waiting long
      // enough for a *later* auto-fired arrow to claim the same recycled
      // slot would make this pass for the wrong reason.
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 20; t++) {
        world.tick(idle);
      }
      expect(world.entities.alive[slot!], 0,
          reason: 'an ordinary arrow is retired by the wall, not bounced');
    });
  });

  group('Ghostshaft', () {
    test('passes through an interior wall', () {
      final Arena arena = Arena.standard(
        walls: <Rect>[const Rect(3.0, 3.0, 3.3, 6.0)],
      );
      final SimWorld world = buildWorld(ghostshaft, arena: arena, playerX: 1.0);
      final int target = spawnTarget(world, 6.0); // 5 u, within the 8 u range

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60; t++) {
        world.tick(idle);
      }
      expect(world.entities.health[target], lessThan(1e9));
    });

    test('ignores plating entirely', () {
      SimWorld buildPlated({required bool plated}) {
        final SimWorld world = buildWorld(ghostshaft);
        final int target = spawnTarget(world, 6.0);
        if (plated) {
          world.enemies.plateHealth[target] = 1e9;
          // Covers every angle, so this test does not also depend on the
          // enemy's own facing.
          world.enemies.plateHalfArc[target] = math.pi;
        }
        return world;
      }

      final double? unplated = firstDamageDealt(buildPlated(plated: false));
      final double? withPlate = firstDamageDealt(buildPlated(plated: true));
      expect(unplated, isNotNull);
      expect(withPlate, isNotNull);
      expect(withPlate! / unplated!, closeTo(1.0, 0.02));
    });

    test('ignores shields entirely', () {
      final SimWorld world = buildWorld(ghostshaft);
      final int target = spawnTarget(world, 6.0);
      world.enemies.shield[target] = 1e9;

      final double before = world.entities.health[target];
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60; t++) {
        world.tick(idle);
      }
      expect(world.entities.health[target], lessThan(before));
      expect(world.enemies.shield[target], 1e9,
          reason: 'the shield must never be touched');
    });

    test('has an 8 u range — a target beyond it is never hit', () {
      final SimWorld world = buildWorld(ghostshaft, playerX: 1.0);
      final int target = spawnTarget(world, 12.0); // 11 u

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 200; t++) {
        world.tick(idle);
      }
      expect(world.entities.health[target], 1e9);
    });

    test('a target within 8 u is still hit normally', () {
      final SimWorld world = buildWorld(ghostshaft, playerX: 1.0);
      final int target = spawnTarget(world, 6.0); // 5 u

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 60; t++) {
        world.tick(idle);
      }
      expect(world.entities.health[target], lessThan(1e9));
    });
  });

  group('Affixes', () {
    Affix rolled(String key, double value) => Affix(affixId: key, value: value);

    test('a channel affix composes exactly like an arrow\'s own modifier', () {
      final SimWorld plainWorld = buildWorld(ashShaft);
      spawnTarget(plainWorld, 12.0);
      final double? plain = firstDamageDealt(plainWorld);

      final SimWorld sharpWorld = buildWorld(
        ashShaft,
        instanceAffixes: <Affix>[rolled('sharpened', 0.06)],
      );
      spawnTarget(sharpWorld, 12.0);
      final double? sharp = firstDamageDealt(sharpWorld);

      expect(plain, isNotNull);
      expect(sharp, isNotNull);
      expect(sharp! / plain!, closeTo(1.06, 0.02));
    });

    test('Piercing adds +1 pierce, reaching a second enemy in line', () {
      final SimWorld world = buildWorld(
        ashShaft,
        instanceAffixes: <Affix>[rolled('piercing', 1.0)],
      );
      final int primary = spawnTarget(world, 8.0);
      final int secondary = spawnTarget(world, 9.0);

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 200; t++) {
        world.tick(idle);
      }
      expect(world.entities.health[primary], lessThan(1e9));
      expect(world.entities.health[secondary], lessThan(1e9));
    });

    test('without an AffixCatalogue, an arrow instance\'s affixes are ignored',
        () {
      final SimWorld world = SimWorld(seed: 302, content: content);
      world.spawnPlayer(4.0, 4.5);
      HeroLoadoutResolver.apply(
        world,
        wren,
        const HeroState(heroId: 'wren'),
        ashShaft,
        ArrowInstance(
          arrowId: 'ash_shaft',
          affixes: <Affix>[rolled('keen', 0.05)],
        ),
        // No `affixes:` catalogue passed.
      );
      // Wren's own Trueshot already grants +8 % crit chance on its own;
      // Keen's own +5 % must not also land without a catalogue to resolve
      // "keen" against.
      expect(world.combat.critChance, closeTo(0.08, 1e-6));
    });

    test('Echoing sums its own chance across every rolled slot that carries it',
        () {
      final SimWorld world = buildWorld(
        ashShaft,
        instanceAffixes: <Affix>[rolled('echoing', 0.10), rolled('echoing', 0.05)],
      );
      expect(world.hero.echoChance, closeTo(0.15, 1e-9));
    });

    test('Echoing fires roughly its own extra share of arrows', () {
      final SimWorld baseline = buildWorld(ashShaft);
      spawnTarget(baseline, 12.0);
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0; t < 600; t++) {
        baseline.tick(idle);
      }
      final int baseArrows = baseline.events.countOf(SimEventType.arrowFired);

      final SimWorld echoing = buildWorld(
        ashShaft,
        instanceAffixes: <Affix>[rolled('echoing', 0.50)],
      );
      spawnTarget(echoing, 12.0);
      for (int t = 0; t < 600; t++) {
        echoing.tick(idle);
      }
      final int echoArrows = echoing.events.countOf(SimEventType.arrowFired);

      expect(baseArrows, greaterThan(0));
      // ~1.5x as many arrows at a 50 % echo chance — a generous tolerance,
      // since this is one seeded sample rather than a driven RNG check.
      expect(echoArrows / baseArrows, closeTo(1.5, 0.25));
    });
  });
}
