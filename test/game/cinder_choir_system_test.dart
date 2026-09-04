import 'dart:math' as math;

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boss_test_support.dart';

/// The Cinder Choir's own fight — P1's rotating-vulnerability puzzle and
/// P2's tether sweep. The generic phase machine has its own tests
/// (`boss_phase_system_test.dart`); this file is the bespoke part: three
/// effigies, a shared pool, the existing plate/armour system reused
/// unmodified, and three sweeping lethal lines built on `EnemyAttack`'s own
/// existing `playerOnLine`/`beginLine` primitives.
void main() {
  final ContentLibrary content = loadContentWithBosses();
  const double health = 1.0e7;

  // Effigy 0 sits due "north" of the centre (angle -90°); 1 and 2 are spaced
  // 120° apart from there. Placing the player due south of the centre makes
  // effigy 0 unambiguously the nearest target for auto-aim; placing it near
  // effigy 1's own position (well outside effigy 0's/2's range) does the same
  // for a plated one. Kept small and centred inside `SimWorld`'s own default
  // 16x9 arena (`SimConfig.arenaWidth`/`arenaHeight`) — no boss arena exists
  // yet (ADR 0017), and an arrow fired from outside it hits the boundary
  // instantly rather than travelling to its target.
  const double centerX = 8.0;
  const double centerY = 4.5;
  const double triangleRadius = 1.0;

  ({SimWorld world, int primary, List<int> children}) spawnChoir({
    double playerX = centerX,
    double playerY = centerY - 3.0,
  }) {
    final SimWorld world = SimWorld(seed: 4242, content: content)
      ..autoFire = false
      ..playerAttack = 1000;
    world.spawnPlayer(playerX, playerY);
    final int primary = world.spawnCinderChoir(
      centerX,
      centerY,
      health: health,
      triangleRadius: triangleRadius,
    );

    final List<int> children = <int>[];
    for (int i = 0; i < world.entities.highWater; i++) {
      if (world.entities.alive[i] == 1 && world.enemies.linkedHealthSlot[i] == primary) {
        children.add(i);
      }
    }
    children.sort(
      (int a, int b) =>
          world.enemies.bossChildIndex[a].compareTo(world.enemies.bossChildIndex[b]),
    );
    return (world: world, primary: primary, children: children);
  }

  /// Holds still long enough to reach [tier], fires exactly one arrow at it,
  /// then lets it fly. Mirrors `combat_integration_test.dart`'s own
  /// "arrows carry the tier they were fired at" pattern.
  void fireOneShotAt(SimWorld world, DrawTier tier) {
    final int chargeTicks = switch (tier) {
      DrawTier.one => 0,
      DrawTier.two => 30,
      DrawTier.three => 80,
    };
    for (int i = 0; i < chargeTicks; i++) {
      world.tick(InputSnapshot());
    }
    world.autoFire = true;
    world.tick(InputSnapshot());
    world.autoFire = false;
    for (int i = 0; i < 150; i++) {
      world.tick(InputSnapshot());
    }
  }

  group('spawn', () {
    test('one primary, three linked children, one lit and two plated', () {
      final (:world, :primary, :children) = spawnChoir();

      expect(children, hasLength(3));
      expect(world.enemies.untargetable[primary], 1);
      expect(world.entities.health[primary], health);
      expect(world.entities.maxHealth[primary], health);

      expect(world.enemies.plateHealth[children[0]], 0);
      for (final int i in <int>[1, 2]) {
        expect(world.enemies.plateHealth[children[i]], greaterThan(0));
        expect(world.enemies.isPlated(children[i]), isTrue);
      }
      expect(world.enemies.bossActiveChildIndex[primary], 0);
    });
  });

  group('damage redirects to the shared pool', () {
    test('hitting the lit effigy drains the primary, not the effigy', () {
      final (:world, :primary, :children) = spawnChoir();
      final double effigyHealthBefore = world.entities.health[children[0]];

      fireOneShotAt(world, DrawTier.one);

      expect(world.entities.health[primary], lessThan(health));
      expect(world.entities.health[children[0]], effigyHealthBefore);
    });

    test('Tier III breaks the plate — far more damage than Tier I', () {
      // Player positioned toward effigy 1 (index 1), which starts plated —
      // same triangle math `CinderChoirSystem.spawn` uses (120° from
      // effigy 0's own -90°), pushed well out so it is unambiguously
      // nearest.
      const double angle1 = -math.pi / 2 + (2 * math.pi / 3);
      final double px = centerX + 2 * triangleRadius * math.cos(angle1);
      final double py = centerY + 2 * triangleRadius * math.sin(angle1);

      final tierOne = spawnChoir(playerX: px, playerY: py);
      expect(tierOne.world.enemies.isPlated(tierOne.children[1]), isTrue);
      fireOneShotAt(tierOne.world, DrawTier.one);
      final double dmgTierOne = health - tierOne.world.entities.health[tierOne.primary];
      expect(dmgTierOne, greaterThan(0));

      final tierThree = spawnChoir(playerX: px, playerY: py);
      expect(tierThree.world.enemies.isPlated(tierThree.children[1]), isTrue);
      fireOneShotAt(tierThree.world, DrawTier.three);
      final double dmgTierThree =
          health - tierThree.world.entities.health[tierThree.primary];

      // Plate lets 10% through at Tier I, 100% through at Tier III (Tier III
      // also hits harder in its own right) — `ArmourFactor`'s own numbers.
      // Both effigies' own health fields stay untouched either way.
      expect(dmgTierThree, greaterThan(dmgTierOne * 5));
      expect(tierOne.world.entities.health[tierOne.children[1]],
          tierOne.world.entities.maxHealth[tierOne.children[1]]);
      expect(tierThree.world.entities.health[tierThree.children[1]],
          tierThree.world.entities.maxHealth[tierThree.children[1]]);
    });
  });

  group('rotation', () {
    test('advances after 6 seconds in P1 and swaps plate state', () {
      final (:world, :primary, :children) = spawnChoir();

      // A safe margin either side of the 360-tick (6.0s) boundary rather
      // than the exact tick, which floating-point `dt` accumulation can
      // land a step either side of.
      for (int i = 0; i < 300; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.bossActiveChildIndex[primary], 0,
          reason: 'not yet at 6.0s');

      for (int i = 0; i < 100; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.bossActiveChildIndex[primary], 1);
      expect(world.enemies.plateHealth[children[0]], greaterThan(0));
      expect(world.enemies.isPlated(children[1]), isFalse);
      expect(world.enemies.isPlated(children[2]), isTrue,
          reason: 'the third effigy is untouched by a rotation');
    });

    test('cadence drops to 4 seconds once phase reaches P2', () {
      final (:world, :primary, :children) = spawnChoir();
      world.enemies.bossPhase[primary] = 1;
      world.enemies.bossTimer[primary] = 4.0;

      for (int i = 0; i < 200; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.bossActiveChildIndex[primary], 0);

      for (int i = 0; i < 100; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.bossActiveChildIndex[primary], 1);
    });

    test('freezes once phase reaches P3', () {
      final (:world, :primary, :children) = spawnChoir();
      world.enemies.bossPhase[primary] = 2;
      final int activeBefore = world.enemies.bossActiveChildIndex[primary];
      final double timerBefore = world.enemies.bossTimer[primary];

      for (int i = 0; i < 600; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.bossActiveChildIndex[primary], activeBefore);
      expect(world.enemies.bossTimer[primary], timerBefore);
    });
  });

  group('death', () {
    test('killing the primary despawns all three effigies', () {
      final (:world, :primary, :children) = spawnChoir();
      world.entities.health[primary] = 0;
      world.tick(InputSnapshot());

      expect(world.entities.isAlive(world.entities.idAt(primary)), isFalse);
      for (final int c in children) {
        expect(world.entities.alive[c], 0);
      }
    });
  });

  group('P2 tether sweep', () {
    // Right next to the primary's own position — the start of every spoke —
    // so the player is "on" all three lines regardless of the live sweep
    // angle, without needing to compute it.
    ({SimWorld world, int primary, List<int> children}) spawnAtCenter() =>
        spawnChoir(playerX: centerX + 0.05, playerY: centerY);

    test('starts as a warning — no damage while it holds', () {
      final (:world, :primary, :children) = spawnAtCenter();
      world.enemies.bossPhase[primary] = 1;

      for (int i = 0; i < 20; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.entities.health[world.player.index], 100.0);
      final int telegraphSlot = world.enemies.telegraphSlot[children[0]];
      expect(telegraphSlot, greaterThanOrEqualTo(0));
      expect(world.telegraphs.severityAt(telegraphSlot), TelegraphSeverity.warning);
    });

    test('turns lethal and damages the player once the warning passes', () {
      final (:world, :primary, :children) = spawnAtCenter();
      world.enemies.bossPhase[primary] = 1;

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }

      final int player = world.player.index;
      // Reused from the Thresher (ADR 0019): 9% of max HP.
      expect(world.entities.health[player], closeTo(91.0, 1e-6));
      final int telegraphSlot = world.enemies.telegraphSlot[children[0]];
      expect(world.telegraphs.severityAt(telegraphSlot), TelegraphSeverity.lethal);
    });

    test('damage respects its own cooldown, then lands again', () {
      final (:world, :primary, :children) = spawnAtCenter();
      world.enemies.bossPhase[primary] = 1;
      final int player = world.player.index;
      // Headroom for two hits without dying.
      world.entities.health[player] = 1000;
      world.entities.maxHealth[player] = 1000;

      for (int i = 0; i < 60; i++) {
        world.tick(InputSnapshot());
      }
      final double afterFirst = world.entities.health[player];
      expect(afterFirst, lessThan(1000));

      // Well inside the 0.6 s cooldown — no second hit yet.
      for (int i = 0; i < 10; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], afterFirst);

      // Past it — a second hit lands.
      for (int i = 0; i < 40; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.entities.health[player], lessThan(afterFirst));
    });

    test('the sweep angle actually advances', () {
      final (:world, :primary, :children) = spawnChoir();
      world.enemies.bossPhase[primary] = 1;

      for (int i = 0; i < 30; i++) {
        world.tick(InputSnapshot());
      }

      expect(world.enemies.bossSweepAngle[primary], greaterThan(0));
    });

    test('entering P3 clears every tether telegraph', () {
      final (:world, :primary, :children) = spawnAtCenter();
      world.enemies.bossPhase[primary] = 1;
      for (int i = 0; i < 20; i++) {
        world.tick(InputSnapshot());
      }
      expect(world.enemies.telegraphSlot[children[0]], greaterThanOrEqualTo(0));

      world.enemies.bossPhase[primary] = 2;
      world.tick(InputSnapshot());

      for (final int c in children) {
        expect(world.enemies.telegraphSlot[c], -1);
      }
    });
  });
}
