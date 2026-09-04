import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Quiverfall — "P1 — The First Shard: A vast descending shard fires
/// converging amber lines from the arena edges. Safe space is the
/// intersection gaps" (docs/06 §12). Mechanically Cinder Choir's own P2
/// tether sweep (ADR 0019) at a grander scale — most of these tests mirror
/// `cinder_choir_system_test.dart`'s own P2 group almost line for line.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;
  const double centerX = 8.0;
  const double centerY = 4.5;

  ({SimWorld world, int primary, List<int> spokes}) spawnQuiverfall({
    double playerX = centerX + 4.0,
    double playerY = centerY,
  }) {
    final SimWorld world = SimWorld(seed: 120120, content: content)
      ..autoFire = false;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnTheQuiverfall(centerX, centerY, health: health);
    final List<int> spokes = <int>[];
    for (int j = 0; j < world.entities.highWater; j++) {
      if (world.entities.alive[j] == 0) continue;
      if (world.enemies.bossParent[j] != primary) continue;
      spokes.add(j);
    }
    spokes.sort(
        (int a, int b) => world.enemies.bossChildIndex[a] - world.enemies.bossChildIndex[b]);
    return (world: world, primary: primary, spokes: spokes);
  }

  // Puts a fresh, unstarted echo directly at [index] — bypassing however
  // many 12s windows it would otherwise take to rotate there naturally.
  void jumpToEcho(SimWorld world, int primary, int index) {
    world.enemies.bossPhase[primary] = 1;
    world.enemies.comboStep[primary] = index;
    world.enemies.bossTimer[primary] = 0;
    world.enemies.state[primary] = AiState.idle.index;
    world.enemies.stateTimer[primary] = 0;
    world.enemies.attackCooldown[primary] = 0;
    world.enemies.bossSweepAngle[primary] = 0;
  }

  group('spawn', () {
    test('a single, directly-damageable body plus eight untargetable spoke '
        'anchors', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);
      expect(world.enemies.untargetable[primary], 0);

      expect(spokes.length, 8);
      final Set<int> childIndices = <int>{};
      for (final int s in spokes) {
        expect(world.enemies.untargetable[s], 1);
        childIndices.add(world.enemies.bossChildIndex[s]);
      }
      expect(childIndices, <int>{0, 1, 2, 3, 4, 5, 6, 7});
    });
  });

  group('the converging sweep', () {
    // Right next to the primary's own position — the shared origin of
    // every spoke — so the player is "on" all eight regardless of the
    // live sweep angle, without needing to compute it.
    ({SimWorld world, int primary, List<int> spokes}) spawnAtCenter() =>
        spawnQuiverfall(playerX: centerX + 0.05);

    test('starts as a warning — no damage while it holds', () {
      final (:world, :primary, :spokes) = spawnAtCenter();

      for (int i = 0; i < 20; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[world.player.index], 100.0);
      final int telegraphSlot = world.enemies.telegraphSlot[spokes[0]];
      expect(telegraphSlot, greaterThanOrEqualTo(0));
      expect(world.telegraphs.severityAt(telegraphSlot), TelegraphSeverity.warning);
    });

    test('turns lethal and damages the player once the warning passes', () {
      final (:world, :primary, :spokes) = spawnAtCenter();
      expect(primary, greaterThanOrEqualTo(0));

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      final int player = world.player.index;
      // Reused from the Thresher (ADR 0019, ADR 0032): 9% of max HP.
      expect(world.entities.health[player], closeTo(91.0, 1e-6));
      final int telegraphSlot = world.enemies.telegraphSlot[spokes[0]];
      expect(world.telegraphs.severityAt(telegraphSlot), TelegraphSeverity.lethal);
    });

    test('damage respects its own cooldown, then lands again', () {
      final (:world, :primary, :spokes) = spawnAtCenter();
      expect(primary, greaterThanOrEqualTo(0));
      final int player = world.player.index;
      world.entities.health[player] = 1000;
      world.entities.maxHealth[player] = 1000;

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      final double afterFirst = world.entities.health[player];
      expect(afterFirst, lessThan(1000));

      for (int i = 0; i < 10; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], afterFirst);

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], lessThan(afterFirst));
    });

    test('the sweep angle actually advances', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      expect(spokes.length, 8);

      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.bossSweepAngle[primary], greaterThan(0));
    });
  });

  group('the primary\'s own death', () {
    test('despawns every spoke anchor — the room can still clear', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      expect(spokes, isNotEmpty);

      world.entities.health[primary] = 0;
      world.tick(InputSnapshot());

      for (final int s in spokes) {
        expect(world.entities.alive[s], 0,
            reason: 'a spoke anchor must not outlive the primary it belongs to');
      }
    });
  });

  group('P2: "The Choir Reforms"', () {
    test('the sweep continues seamlessly into P2 as echo 0 — no seam at '
        'the phase boundary', () {
      // Identical setup and math to "turns lethal and damages the player
      // once the warning passes" above, except `bossPhase` is set to 1
      // (P2) from the very start — `comboStep`/`bossTimer` both start at
      // zero by construction (P1's own sweep never touches either), so
      // echo 0 is already the exact same sweep P1 was running.
      final (:world, :primary, :spokes) =
          spawnQuiverfall(playerX: centerX + 0.05);
      world.enemies.bossPhase[primary] = 1;

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      final int player = world.player.index;
      expect(world.entities.health[player], closeTo(91.0, 1e-6));
      expect(world.enemies.comboStep[primary], 0);
    });

    test('rotates to the next boss in chapter order after 12s', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      world.enemies.bossPhase[primary] = 1;
      expect(world.enemies.comboStep[primary], 0);

      // 12.0s is exactly 720 ticks at the fixed 1/60s step; a few extra
      // absorb any floating-point drift from that many small additions.
      for (int i = 0; i < 725; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.comboStep[primary], 1);
    });

    test('Gaunt\'s own echo (1): a circle slam for the derived heavy hit',
        () {
      final (:world, :primary, :spokes) =
          spawnQuiverfall(playerX: centerX + 2.0);
      jumpToEcho(world, primary, 1);
      final int player = world.player.index;

      // 1.8s wind-up plus a little travel margin.
      for (int i = 0; i < 115; i++) {
        world.tick(InputSnapshot());
      }

      // 0.09 * 2.10 == 18.9% of max health — Gaunt's own P2 shockwave
      // anchor, the "derived heavy hit" this roster reaches for by
      // default.
      expect(world.entities.health[player], closeTo(81.1, 0.5));
    });

    test('Silversong\'s own echo (2): a cone that Draw-locks, not damages',
        () {
      final (:world, :primary, :spokes) =
          spawnQuiverfall(playerX: centerX + 2.0);
      jumpToEcho(world, primary, 2);
      final int player = world.player.index;

      for (int i = 0; i < 45; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], 100.0,
          reason: 'Silversong\'s own signature move never deals raw damage');
      expect(world.playerDraw.isDrawLocked, isTrue);
    });

    test('the Hollow Warden\'s own echo (3): an actual fired bolt', () {
      final (:world, :primary, :spokes) =
          spawnQuiverfall(playerX: centerX + 2.0);
      jumpToEcho(world, primary, 3);
      final int player = world.player.index;

      for (int i = 0; i < 90; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], lessThan(100.0));
    });

    test('Vermillion\'s own echo (4): a charge line for the derived heavy '
        'hit', () {
      final (:world, :primary, :spokes) =
          spawnQuiverfall(playerX: centerX + 2.0);
      jumpToEcho(world, primary, 4);
      final int player = world.player.index;

      for (int i = 0; i < 45; i++) {
        world.tick(InputSnapshot());
      }

      // Same derived heavy-hit anchor as Gaunt's own echo above.
      expect(world.entities.health[player], closeTo(81.1, 0.5));
    });

    test('Rimefather\'s own echo (5): a frost cone at the P1 anchor', () {
      final (:world, :primary, :spokes) =
          spawnQuiverfall(playerX: centerX + 2.0);
      jumpToEcho(world, primary, 5);
      final int player = world.player.index;

      for (int i = 0; i < 45; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], closeTo(91.0, 0.5));
    });

    test('Arclight\'s own echo (6): a chain bolt at the P1 anchor', () {
      final (:world, :primary, :spokes) =
          spawnQuiverfall(playerX: centerX + 2.0);
      jumpToEcho(world, primary, 6);
      final int player = world.player.index;

      for (int i = 0; i < 45; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], closeTo(91.0, 0.5));
    });

    test('the Green Mother\'s own echo (7): a real, ticking Toxin stack, '
        'not a direct hit', () {
      final (:world, :primary, :spokes) =
          spawnQuiverfall(playerX: centerX + 2.0);
      jumpToEcho(world, primary, 7);
      final int player = world.player.index;

      for (int i = 0; i < 45; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.status.toxinStacks[player], greaterThan(0));
      final double healthAfterHit = world.entities.health[player];
      expect(healthAfterHit, lessThan(100.0));

      // The DoT keeps ticking on its own, independent of the next line's
      // own wind-up.
      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], lessThan(healthAfterHit));
    });

    test('Thrall\'s own echo (8): its first ability, a cone', () {
      final (:world, :primary, :spokes) =
          spawnQuiverfall(playerX: centerX + 2.0);
      jumpToEcho(world, primary, 8);
      final int player = world.player.index;

      for (int i = 0; i < 45; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], closeTo(91.0, 0.5));
    });

    test('the Weeping Gate\'s own echo (9): a portal that actually spawns '
        'a Riftborn', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      jumpToEcho(world, primary, 9);

      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }

      bool spawnedAnAdd = false;
      for (int j = 0; j < world.entities.highWater; j++) {
        if (world.entities.alive[j] == 0) continue;
        if (world.entities.kind[j] != EntityKind.enemy.index) continue;
        if (world.enemies.spawnerSlot[j] != primary) continue;
        spawnedAnAdd = true;
      }
      expect(spawnedAnAdd, isTrue);
    });

    test("Skarn's own echo (10): a slam with a smaller radius than "
        "Gaunt's own echo", () {
      // 4u out (this fixture's own default player position) — inside
      // Gaunt's own echo radius (5.0) but outside Skarn's own (3.0), so
      // the same setup tells the two echoes apart.
      final (:world, :primary, :spokes) = spawnQuiverfall();
      jumpToEcho(world, primary, 10);
      final int player = world.player.index;

      for (int i = 0; i < 115; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[player], 100.0,
          reason: 'Skarn\'s own echo should whiff at a range Gaunt\'s own '
              'would have hit');
    });
  });

  group('past P2', () {
    test('freezes whatever the current echo left telegraphed', () {
      final (:world, :primary, :spokes) = spawnQuiverfall();
      world.enemies.bossPhase[primary] = 1;
      world.tick(InputSnapshot());
      expect(world.enemies.telegraphSlot[spokes[0]], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());
      for (final int s in spokes) {
        expect(world.enemies.telegraphSlot[s], -1);
      }

      final int player = world.player.index;
      final double healthBefore = world.entities.health[player];
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], healthBefore);
      // Spoke anchors themselves are untouched — still alive, just idle.
      for (final int s in spokes) {
        expect(world.entities.alive[s], 1);
      }
    });
  });
}
