import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spire/spire_catalogue.dart';
import 'package:test/test.dart';

import 'arrow_test_support.dart';
import 'enemy_test_support.dart';
import 'hero_test_support.dart';
import 'spire_test_support.dart';

/// The fourteen Spire nodes ADR 0092 wires to a real combat effect, each
/// measured in isolation the same way a hero passive already is in
/// `hero_behaviour_test.dart` — a maxed (L80) node, checked against its own
/// docs/04 cap, with every other node at 0.
void main() {
  late HeroCatalogue heroes;
  late ArrowCatalogue arrows;
  late ContentLibrary content;
  late SpireCatalogue spire;
  late HeroDefinition wren;
  late ArrowDefinition ashShaft;

  setUpAll(() {
    heroes = loadHeroes();
    arrows = loadArrows();
    content = loadEnemies();
    spire = loadSpire();
    wren = heroes.byArchetype(HeroArchetype.wren)!;
    ashShaft = arrows.byArchetype(ArrowArchetype.ashShaft)!;
  });

  /// A bare world with Wren + Ash Shaft, [nodeLevels] fed straight into the
  /// resolver — bypassing `SpireWorkshop` entirely, since the workshop's own
  /// account-level and tier-gate checks gate *purchasing*, not the combat
  /// effect this file measures.
  SimWorld arena({Map<int, int> nodeLevels = const <int, int>{}}) {
    final SimWorld world = SimWorld(seed: 1, content: content);
    world.spawnPlayer(4.0, 4.5);
    HeroLoadoutResolver.apply(
      world,
      wren,
      const HeroState(heroId: 'wren'),
      ashShaft,
      const ArrowInstance(arrowId: 'ash_shaft', crafted: true),
      spire: spire,
      spireState: SpireState(
        nodeLevels: nodeLevels.map((k, v) => MapEntry('$k', v)),
      ),
    );
    return world;
  }

  double baseAttackNoSpire() => arena().playerAttack;

  test('Warden\'s Might (#1): +160% attack at L80', () {
    final double base = baseAttackNoSpire();
    final double withNode =
        arena(nodeLevels: {1: 80}).playerAttack;
    expect(withNode, closeTo(base * 2.60, 1e-6));
  });

  test('Keen Edge (#2): +28% crit chance at L80', () {
    // Wren's own Trueshot passive already grants +8% crit chance, so this
    // is a delta against that baseline, not against zero.
    final double baseline = arena().combat.critChance;
    final w = arena(nodeLevels: {2: 80});
    expect(w.combat.critChance - baseline, closeTo(0.28, 1e-9));
  });

  test('Executioner (#3): +120% crit damage at L80', () {
    final double baseline = arena().combat.critMultiplier;
    final w = arena(nodeLevels: {3: 80});
    expect(w.combat.critMultiplier, closeTo(baseline + 1.20, 1e-9));
  });

  test('Quickdraw (#4): -48% Draw tier time at L80', () {
    final w = arena(nodeLevels: {4: 80});
    expect(w.playerDraw.drawSpeedMultiplier, closeTo(0.52, 1e-9));
  });

  test('Piercing Study (#5): +5 pierce at L80, 0 below the first 16 levels',
      () {
    expect(arena(nodeLevels: {5: 15}).basePierce, 0);
    expect(arena(nodeLevels: {5: 80}).basePierce, 5);
  });

  test('Elemental Focus (#6): +160% elemental damage at L80', () {
    final w = arena(nodeLevels: {6: 80});
    expect(w.combat.allElementDamage, closeTo(1.60, 1e-9));
  });

  test('Vitality (#7): +200% max HP at L80', () {
    final int p = arena().player.index;
    final double baseline = arena().entities.maxHealth[p];
    final w = arena(nodeLevels: {7: 80});
    expect(
      w.entities.maxHealth[w.player.index],
      closeTo(baseline * 3.0, 1e-6),
    );
  });

  test('Warded Hide (#8): +36% damage reduction at L80', () {
    final w = arena(nodeLevels: {8: 80});
    expect(w.boonDamageReduction, closeTo(0.36, 1e-9));
  });

  test('Second Wind (#10): +28% heal on room clear at L80', () {
    final w = arena(nodeLevels: {10: 80});
    expect(w.healOnRoomClear, closeTo(0.28, 1e-9));
  });

  test('Swiftshot (#13): +40% fire rate at L80', () {
    final double baseline = arena().fireRateMultiplier;
    final w = arena(nodeLevels: {13: 80});
    expect(w.fireRateMultiplier, closeTo(baseline * 1.40, 1e-6));
  });

  test('Windline Weaving (#14): +1.44s Windline duration at L80', () {
    final double baseline = arena().windlineDuration;
    final w = arena(nodeLevels: {14: 80});
    expect(w.windlineDuration, closeTo(baseline + 1.44, 1e-9));
  });

  test('Confluence Study (#15): +96% Confluence damage at L80', () {
    // confluenceDamageMultiplier is read via BoonStats.multiplierFor, which
    // returns `1 + sum` for a non-multiplicative channel like this one.
    final w = arena(nodeLevels: {15: 80});
    expect(w.confluenceDamageMultiplier, closeTo(1.96, 1e-9));
  });

  test('Arrow Velocity (#16): +64% projectile speed at L80', () {
    final double baseline = arena().projectileSpeed;
    final w = arena(nodeLevels: {16: 80});
    expect(w.projectileSpeed, closeTo(baseline * 1.64, 1e-6));
  });

  test('Wide Nock (#18): +24% arrow hitbox at L80', () {
    final double baseline = arena().arrowRadius;
    final w = arena(nodeLevels: {18: 80});
    expect(w.arrowRadius, closeTo(baseline * 1.24, 1e-6));
  });

  test('a deferred node (Iron Resolve, #11) has no measurable effect', () {
    final double baseline = baseAttackNoSpire();
    final w = arena(nodeLevels: {11: 80});
    expect(w.playerAttack, closeTo(baseline, 1e-9));
    expect(w.boonDamageReduction, 0);
  });

  test('two implemented nodes compose independently', () {
    final SimWorld baseline = arena();
    final w = arena(nodeLevels: {2: 40, 3: 40});
    expect(
      w.combat.critChance - baseline.combat.critChance,
      closeTo(0.0035 * 40, 1e-9),
    );
    expect(
      w.combat.critMultiplier - baseline.combat.critMultiplier,
      closeTo(0.015 * 40, 1e-9),
    );
  });
}
