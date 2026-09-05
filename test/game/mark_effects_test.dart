import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/marks/mark_catalogue.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'arrow_test_support.dart';
import 'enemy_test_support.dart';
import 'hero_test_support.dart';
import 'mark_test_support.dart';

/// The six wired Marks (ADR 0095), composed via `HeroLoadoutResolver.apply`
/// the same way a Spire node already is.
void main() {
  late HeroCatalogue heroes;
  late ArrowCatalogue arrows;
  late ContentLibrary content;
  late MarkCatalogue marks;
  late HeroDefinition wren;
  late ArrowDefinition ashShaft;

  setUpAll(() {
    heroes = loadHeroes();
    arrows = loadArrows();
    content = loadEnemies();
    marks = loadMarks();
    wren = heroes.byArchetype(HeroArchetype.wren)!;
    ashShaft = arrows.byArchetype(ArrowArchetype.ashShaft)!;
  });

  SimWorld arena({List<String> equippedMarkKeys = const <String>[]}) {
    final SimWorld world = SimWorld(seed: 1, content: content);
    world.spawnPlayer(4.0, 4.5);
    HeroLoadoutResolver.apply(
      world,
      wren,
      const HeroState(heroId: 'wren'),
      ashShaft,
      const ArrowInstance(arrowId: 'ash_shaft', crafted: true),
      marks: marks,
      equippedMarkKeys: equippedMarkKeys,
    );
    return world;
  }

  test('no equipped Marks means no Mark contribution', () {
    final baseline = arena();
    final w = arena();
    expect(w.confluenceDamageMultiplier, baseline.confluenceDamageMultiplier);
  });

  test('Mark of the Thread: +5% Confluence damage', () {
    final baseline = arena().confluenceDamageMultiplier;
    final w = arena(equippedMarkKeys: ['mark_of_the_thread']);
    expect(w.confluenceDamageMultiplier - baseline, closeTo(0.05, 1e-9));
  });

  test('Mark of the Thread II: +12% Confluence damage, +0.2s Windline', () {
    final baselineConfluence = arena().confluenceDamageMultiplier;
    final baselineWindline = arena().windlineDuration;
    final w = arena(equippedMarkKeys: ['mark_of_the_thread_2']);
    expect(w.confluenceDamageMultiplier - baselineConfluence,
        closeTo(0.12, 1e-9));
    expect(w.windlineDuration - baselineWindline, closeTo(0.2, 1e-9));
  });

  test('Mark of Stillness: +4% Tier III damage', () {
    final baseline = arena().combat.vsTierThree;
    final w = arena(equippedMarkKeys: ['mark_of_stillness']);
    expect(w.combat.vsTierThree - baseline, closeTo(0.04, 1e-9));
  });

  test('Mark of the Gale: +1 max Momentum', () {
    final baseline = arena().playerDraw.maxMomentum;
    final w = arena(equippedMarkKeys: ['mark_of_the_gale']);
    expect(w.playerDraw.maxMomentum - baseline, 1);
  });

  test('Mark of the Swift: +5% fire rate', () {
    final baseline = arena().fireRateMultiplier;
    final w = arena(equippedMarkKeys: ['mark_of_the_swift']);
    expect(w.fireRateMultiplier / baseline, closeTo(1.05, 1e-9));
  });

  test('Mark of Ruin: +10% all damage', () {
    // StatChannel.damage feeds CombatModifiers.flatDamage directly — the
    // unconditional term every damageSumFor() call starts its own sum from.
    final double baseline = arena().combat.flatDamage;
    final w = arena(equippedMarkKeys: ['mark_of_ruin']);
    expect(w.combat.flatDamage - baseline, closeTo(0.10, 1e-9));
  });

  test('two equipped Marks compose independently', () {
    final w = arena(
        equippedMarkKeys: ['mark_of_the_thread', 'mark_of_the_gale']);
    final baseline = arena();
    expect(w.confluenceDamageMultiplier - baseline.confluenceDamageMultiplier,
        closeTo(0.05, 1e-9));
    expect(w.playerDraw.maxMomentum - baseline.playerDraw.maxMomentum, 1);
  });

  test('an unlisted key is ignored rather than throwing', () {
    expect(() => arena(equippedMarkKeys: ['not_a_real_mark']), returnsNormally);
  });
}
