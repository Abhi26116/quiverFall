import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// Umbral Twin — "Fights in near-total darkness; the arena is lit only by
/// the player's own Windlines... Attacks are audible before visible"
/// (docs/06 §6.2, Event boss #14). The card's own differentiating
/// mechanic is a presentation concern outside `lib/game/sim`'s own
/// architectural boundary (ADR 0066) — every test here is about the one
/// thing that IS the sim's job: a correctly-statted, spawnable,
/// non-attacking body.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 4.5e4;
  const double centerX = 8.0;
  const double centerY = 4.5;

  group('spawn', () {
    test('places a single stationary body with the shipping HP number',
        () {
      final SimWorld world = SimWorld(seed: 131313, content: content)
        ..autoFire = false;
      world.spawnPlayer(centerX + 6.0, centerY);
      final int primary = world.spawnUmbralTwin(centerX, centerY, health: health);

      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.entities.alive[primary], 1);
    });
  });

  group('update', () {
    test('never touches player health — no attack is invented', () {
      final SimWorld world = SimWorld(seed: 131313, content: content)
        ..autoFire = false;
      world.spawnPlayer(centerX + 1.0, centerY);
      world.spawnUmbralTwin(centerX, centerY, health: health);

      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[world.player.index], 100.0);
    });

    test('never moves and never crashes across every phase', () {
      final SimWorld world = SimWorld(seed: 131313, content: content)
        ..autoFire = false;
      world.spawnPlayer(centerX + 6.0, centerY);
      final int primary = world.spawnUmbralTwin(centerX, centerY, health: health);
      final double startX = world.entities.posX[primary];
      final double startY = world.entities.posY[primary];

      world.enemies.bossPhase[primary] = 2;
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.posX[primary], startX);
      expect(world.entities.posY[primary], startY);
      expect(world.entities.alive[primary], 1);
    });
  });
}
