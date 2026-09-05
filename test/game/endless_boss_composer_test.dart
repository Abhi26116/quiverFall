import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spawn/endless_boss_composer.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// `EndlessBossComposer` — the Endless Descent tier's own floor→boss
/// resolver and placer (docs/06 §6.3, ADR 0068). Pure resolution logic
/// only; the mode itself (floor generation, weekly seeds, Ascension gate)
/// is out of scope here — see the class doc comment.
void main() {
  final ContentLibrary content = loadContentWithBosses();

  group('bossFor', () {
    test('is null for any floor not a multiple of 10', () {
      for (final int floor in <int>[0, -10, 1, 5, 9, 11, 25, 99, 101]) {
        expect(EndlessBossComposer.bossFor(floor), isNull,
            reason: 'floor $floor should have no boss');
      }
    });

    test('matches each card\'s own stated floor pattern, in order, with '
        'The Last Warden superseding the ordinary rotation from floor '
        '100 onward', () {
      const Map<int, BossArchetype> expected = <int, BossArchetype>{
        10: BossArchetype.theLoom,
        20: BossArchetype.coilspine,
        30: BossArchetype.theLoom,
        40: BossArchetype.motherOfMotes,
        50: BossArchetype.theLoom,
        60: BossArchetype.coilspine,
        70: BossArchetype.theLoom,
        80: BossArchetype.motherOfMotes,
        90: BossArchetype.theLoom,
        100: BossArchetype.lastWarden,
        110: BossArchetype.theLoom,
        120: BossArchetype.motherOfMotes,
        130: BossArchetype.theLoom,
        140: BossArchetype.coilspine,
        150: BossArchetype.lastWarden,
        160: BossArchetype.motherOfMotes,
        170: BossArchetype.theLoom,
        180: BossArchetype.coilspine,
        190: BossArchetype.theLoom,
        200: BossArchetype.lastWarden,
      };

      expected.forEach((int floor, BossArchetype archetype) {
        expect(EndlessBossComposer.bossFor(floor), archetype,
            reason: 'floor $floor should be $archetype');
      });
    });
  });

  group('healthFor', () {
    test('is Curves.endlessHp(floor) scaled by the boss\'s own multiplier',
        () {
      final double health = EndlessBossComposer.healthFor(
        floor: 60,
        archetype: BossArchetype.coilspine,
        content: content,
      );
      final double multiplier =
          content.bosses.byArchetype(BossArchetype.coilspine)!.hpMultiplier;

      expect(health, closeTo(Curves.endlessHp(60) * multiplier, 1e-6));
    });

    test('grows with floor depth for the same boss', () {
      final double at10 = EndlessBossComposer.healthFor(
        floor: 10,
        archetype: BossArchetype.theLoom,
        content: content,
      );
      final double at170 = EndlessBossComposer.healthFor(
        floor: 170,
        archetype: BossArchetype.theLoom,
        content: content,
      );

      expect(at170, greaterThan(at10));
    });
  });

  group('spawn', () {
    const double health = 1.0e5;

    test('places the real Loom at floor 10', () {
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(8.0, 4.5);
      final int primary =
          EndlessBossComposer.spawn(world, BossArchetype.theLoom, health);

      expect(primary, greaterThanOrEqualTo(0));
      expect(world.entities.maxHealth[primary], health);
    });

    test('places the real Coilspine at floor 20', () {
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(8.0, 4.5);
      final int primary =
          EndlessBossComposer.spawn(world, BossArchetype.coilspine, health);

      expect(primary, greaterThanOrEqualTo(0));
      expect(world.enemies.untargetable[primary], 1);
    });

    test('places the real Mother of Motes at floor 40', () {
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(8.0, 4.5);
      final int primary = EndlessBossComposer.spawn(
          world, BossArchetype.motherOfMotes, health);

      expect(primary, greaterThanOrEqualTo(0));
      expect(world.entities.maxHealth[primary], health);
    });

    test('places the real Last Warden at floor 100', () {
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(8.0, 4.5);
      final int primary =
          EndlessBossComposer.spawn(world, BossArchetype.lastWarden, health);

      expect(primary, greaterThanOrEqualTo(0));
      expect(world.entities.maxHealth[primary], health);
    });

    test('an archetype not in this tier is not handled', () {
      final SimWorld world = SimWorld(seed: 1, content: content);
      world.spawnPlayer(8.0, 4.5);
      final int primary =
          EndlessBossComposer.spawn(world, BossArchetype.umbralTwin, health);

      expect(primary, -1);
    });
  });
}
