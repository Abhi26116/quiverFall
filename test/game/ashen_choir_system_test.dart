import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Ashen Choir — "Elite remix of #1. All three effigies lit
/// permanently; tethers are lethal from the start; a fourth invisible
/// effigy exists, revealed only by Windline contact" (docs/06 §13). Most
/// tests here confirm the *differences* from Cinder Choir directly, rather
/// than re-proving machinery `cinder_choir_system_test.dart` already
/// covers.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary, List<int> spokes, int hidden}) spawnChoir({
    double playerX = centerX + 0.05,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 130130, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnAshenChoir(centerX, centerY, health: health);

    final List<int> spokes = <int>[];
    int hidden = -1;
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.bossParent[j] != primary) continue;
      if (world.enemies.bossChildIndex[j] < 3) {
        spokes.add(j);
      } else {
        hidden = j;
      }
    }
    spokes.sort(
        (int a, int b) => world.enemies.bossChildIndex[a] - world.enemies.bossChildIndex[b]);
    return (world: world, primary: primary, spokes: spokes, hidden: hidden);
  }

  group('spawn', () {
    test('three permanently-lit effigies sharing the pool, plus a hidden '
        'fourth that does not', () {
      final (:world, :primary, :spokes, :hidden) = spawnChoir();
      expect(world.entities.health[primary], health);
      expect(world.enemies.untargetable[primary], 1);

      expect(spokes.length, 3);
      for (final int s in spokes) {
        expect(world.enemies.linkedHealthSlot[s], primary);
        expect(world.enemies.plateHealth[s], 0.0,
            reason: 'lit permanently — no plate at all, ever');
      }

      expect(hidden, greaterThanOrEqualTo(0));
      expect(world.enemies.untargetable[hidden], 1);
      expect(world.enemies.linkedHealthSlot[hidden], -1,
          reason: 'not sharing the pool until revealed');
      expect(world.entities.radius[hidden], closeTo(0.01, 1e-9));
    });
  });

  group('the tether sweep', () {
    test('is lethal from the very first tick — no warning window at all',
        () {
      final (:world, :primary, :spokes, :hidden) = spawnChoir();
      expect(primary, greaterThanOrEqualTo(0));

      world.tick(InputSnapshot());

      final int telegraphSlot = world.enemies.telegraphSlot[spokes[0]];
      expect(telegraphSlot, greaterThanOrEqualTo(0));
      expect(world.telegraphs.severityAt(telegraphSlot), TelegraphSeverity.lethal);
      // A handful more ticks — the cooldown gate, not a warning window,
      // is the only thing between this and the first hit landing.
      for (int i = 0; i < 5; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[world.player.index], lessThan(100.0));
    });

    test('keeps running even once bossPhase would freeze every other boss',
        () {
      final (:world, :primary, :spokes, :hidden) = spawnChoir();
      world.enemies.bossPhase[primary] = 2;

      final double angleBefore = world.enemies.bossSweepAngle[primary];
      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.bossSweepAngle[primary], greaterThan(angleBefore));
      expect(world.enemies.telegraphSlot[spokes[0]], greaterThanOrEqualTo(0));
    });
  });

  group('the hidden fourth effigy', () {
    test('stays hidden until a Windline actually passes near it', () {
      final (:world, :primary, :spokes, :hidden) = spawnChoir();

      // Nowhere near the effigy, which sits at the triangle's own centre.
      world.windlines.add(
        fromX: centerX + 6,
        fromY: centerY + 3,
        toX: centerX + 6,
        toY: centerY - 3,
        expiresAt: 100.0,
        ownerIndex: world.player.index,
        trailId: 0,
      );
      world.tick(InputSnapshot());

      expect(world.enemies.linkedHealthSlot[hidden], -1);
      expect(world.enemies.untargetable[hidden], 1);
    });

    test('is revealed the instant a Windline passes within reach', () {
      final (:world, :primary, :spokes, :hidden) = spawnChoir();

      // Straight through the triangle's own centre, where the hidden
      // effigy sits.
      world.windlines.add(
        fromX: centerX - 1,
        fromY: centerY,
        toX: centerX + 1,
        toY: centerY,
        expiresAt: 100.0,
        ownerIndex: world.player.index,
        trailId: 0,
      );
      world.tick(InputSnapshot());

      expect(world.enemies.linkedHealthSlot[hidden], primary);
      expect(world.enemies.untargetable[hidden], 0);
      expect(world.entities.radius[hidden], closeTo(0.5, 1e-9));
    });
  });

  group('the primary\'s own death', () {
    test('despawns all four children, revealed or not', () {
      final (:world, :primary, :spokes, :hidden) = spawnChoir();
      // Reveal the fourth first, so this covers both states.
      world.windlines.add(
        fromX: centerX - 1,
        fromY: centerY,
        toX: centerX + 1,
        toY: centerY,
        expiresAt: 100.0,
        ownerIndex: world.player.index,
        trailId: 0,
      );
      world.tick(InputSnapshot());
      expect(world.enemies.linkedHealthSlot[hidden], primary);

      world.entities.health[primary] = 0;
      world.tick(InputSnapshot());

      for (final int s in spokes) {
        expect(world.entities.alive[s], 0);
      }
      expect(world.entities.alive[hidden], 0);
    });
  });
}
