import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Pale Judge — "Reads the player's build at fight start and gains a
/// matching immunity — an Ember build faces a fire-immune Judge" (docs/06
/// §6.2, Event boss #16). Every test here is about the immunity itself
/// (ADR 0065).
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 6.0e4;
  const double centerX = 8.0;
  const double centerY = 4.5;

  group('spawn', () {
    test('places a single stationary body', () {
      final SimWorld world = SimWorld(seed: 424242, content: content)
        ..autoFire = false;
      world.spawnPlayer(centerX + 6.0, centerY);
      final int primary = world.spawnPaleJudge(centerX, centerY, health: health);

      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
    });

    test('with no element in the player\'s own current build, gains no '
        'immunity at all', () {
      final SimWorld world = SimWorld(seed: 424242, content: content)
        ..autoFire = false;
      world.spawnPlayer(centerX + 6.0, centerY);
      final int primary = world.spawnPaleJudge(centerX, centerY, health: health);

      for (final SimElement element in SimElement.values) {
        expect(world.enemies.resistsElement(primary, element), isFalse);
      }
    });

    test('gains a matching, permanent immunity to the player\'s own '
        'current arrow element', () {
      final SimWorld world = SimWorld(seed: 424242, content: content)
        ..autoFire = false
        ..arrowElement = SimElement.ember;
      world.spawnPlayer(centerX + 6.0, centerY);
      final int primary = world.spawnPaleJudge(centerX, centerY, health: health);

      expect(world.enemies.resistsElement(primary, SimElement.ember), isTrue);
      expect(world.enemies.resistsElement(primary, SimElement.frost), isFalse);
      expect(world.enemies.resistsElement(primary, SimElement.storm), isFalse);
      expect(world.enemies.resistsElement(primary, SimElement.toxin), isFalse);
    });

    test('an attuned Boon\'s own element takes priority over the equipped '
        'arrow\'s, the same rule the sim itself already uses for a fired '
        'shot', () {
      final SimWorld world = SimWorld(seed: 424242, content: content)
        ..autoFire = false
        ..arrowElement = SimElement.ember;
      world.boons.attunedElement = SimElement.frost;
      world.spawnPlayer(centerX + 6.0, centerY);
      final int primary = world.spawnPaleJudge(centerX, centerY, health: health);

      expect(world.enemies.resistsElement(primary, SimElement.frost), isTrue);
      expect(world.enemies.resistsElement(primary, SimElement.ember), isFalse);
    });

    test('the immunity never expires across a long fight', () {
      final SimWorld world = SimWorld(seed: 424242, content: content)
        ..autoFire = false
        ..arrowElement = SimElement.ember;
      world.spawnPlayer(centerX + 6.0, centerY);
      final int primary = world.spawnPaleJudge(centerX, centerY, health: health);

      for (int i = 0; i < 6000; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.resistsElement(primary, SimElement.ember), isTrue);
    });
  });

  group('the immunity end to end', () {
    test('a fired Ember arrow never applies Burn to an Ember-immune Judge',
        () {
      final SimWorld world = SimWorld(seed: 424242, content: content)
        ..arrowElement = SimElement.ember;
      world.spawnPlayer(centerX + 3.0, centerY);
      world.spawnPaleJudge(centerX, centerY, health: health);

      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.events.countOf(SimEventType.elementApplied), 0);
    });

    test('the same fight, firing a DIFFERENT element than the one read at '
        'spawn, applies it normally — the immunity does not update after '
        'the fact', () {
      final SimWorld world = SimWorld(seed: 424242, content: content)
        ..arrowElement = SimElement.ember; // read and locked in at spawn
      world.spawnPlayer(centerX + 3.0, centerY);
      world.spawnPaleJudge(centerX, centerY, health: health);

      world.arrowElement = SimElement.frost; // fired after the fact

      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.events.countOf(SimEventType.elementApplied), greaterThan(0));
    });
  });

  group('update', () {
    test('never touches player health — no attack of its own is invented',
        () {
      final SimWorld world = SimWorld(seed: 424242, content: content)
        ..autoFire = false
        ..arrowElement = SimElement.ember;
      world.spawnPlayer(centerX + 1.5, centerY);
      world.spawnPaleJudge(centerX, centerY, health: health);

      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[world.player.index], 100.0);
    });
  });
}
