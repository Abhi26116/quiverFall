import 'package:quiverfall/game/balance/curves.dart';
import 'package:test/test.dart';

/// docs/04-upgrades.md §4.3's hero leveling formulas.
///
/// `Curves.heroLevelCost`, `heroStat` and `heroLevelCap` predate Phase 10 —
/// they were already in `curves.dart` before this phase touched it — but had
/// no test beyond two `heroLevelCap` assertions in `sim_core_test.dart`. This
/// is the exit criterion Phase 10 actually needs ("all 20 heroes playable")
/// leaning on formulas nobody had checked yet.
void main() {
  group('level cost: cost = 90 * 1.11^(lvl-1)', () {
    test('level 1 costs the base 90 gold', () {
      expect(Curves.heroLevelCost(1), closeTo(90.0, 1e-9));
    });

    test('grows by exactly 11% per level', () {
      for (int lvl = 1; lvl < 20; lvl++) {
        final double ratio =
            Curves.heroLevelCost(lvl + 1) / Curves.heroLevelCost(lvl);
        expect(ratio, closeTo(1.11, 1e-9), reason: 'level $lvl -> ${lvl + 1}');
      }
    });
  });

  group('stat scaling: heroBase(lvl) = statAtL1 * (1 + 0.085*(lvl-1)), '
      '+12% per star', () {
    test('level 1, star 0 returns the bare stat', () {
      expect(Curves.heroStat(100, 1, 0), closeTo(100.0, 1e-9));
    });

    test('level scaling alone, at star 0', () {
      // docs/07 §7.0's own example: a reference stat of 100 at level 1.
      expect(Curves.heroStat(100, 11, 0), closeTo(100 * 1.85, 1e-9));
    });

    test('star scaling alone, at level 1', () {
      expect(Curves.heroStat(100, 1, 3), closeTo(100 * 1.36, 1e-9));
    });

    test('level and star combine multiplicatively, not additively', () {
      // (1 + 0.085*4) * (1 + 0.12*2) = 1.34 * 1.24
      const double expected = 100 * 1.34 * 1.24;
      expect(Curves.heroStat(100, 5, 2), closeTo(expected, 1e-9));
    });

    test('a level-1, star-0 Wren matches the reference baseline exactly', () {
      // docs/07 §7.0: "ATK 100 · HP 100 · Move 3.20 u/s · Fire rate 2.20 /s"
      // is the level-1, star-0 baseline every other hero is indexed against.
      expect(Curves.heroStat(100, 1, 0), 100.0);
      expect(Curves.heroStat(3.20, 1, 0), closeTo(3.20, 1e-9));
    });
  });

  group('level cap rises 8 per chapter cleared', () {
    test('a fresh account (0 chapters cleared) caps at 8', () {
      expect(Curves.heroLevelCap(0), 8);
    });

    test('cap scales linearly with chapters cleared', () {
      expect(Curves.heroLevelCap(1), 16);
      expect(Curves.heroLevelCap(5), 48);
      expect(Curves.heroLevelCap(11), 96);
    });

    test('the cap never regresses as chapters increase', () {
      int previous = 0;
      for (int c = 0; c < 30; c++) {
        final int cap = Curves.heroLevelCap(c);
        expect(cap, greaterThan(previous));
        previous = cap;
      }
    });
  });

  group('star cost — docs/04 §4.3: "40 to unlock, then 30/80/180/400/900"', () {
    test('the six costs match the doc exactly, in order', () {
      expect(
        <int>[for (int s = 1; s <= 6; s++) Curves.heroStarCost(s)],
        <int>[40, 30, 80, 180, 400, 900],
      );
    });

    test('star 1 is the unlock cost', () {
      expect(Curves.heroStarCost(1), 40);
    });

    test('the sequence is not monotonic — 40 drops to 30 before climbing', () {
      // A reader's first assumption about a cost table is "always goes up".
      // This one does not, and a formula-based reimplementation later would
      // very plausibly get this specific wrinkle wrong.
      expect(Curves.heroStarCost(2), lessThan(Curves.heroStarCost(1)));
      expect(Curves.heroStarCost(3), greaterThan(Curves.heroStarCost(2)));
    });
  });
}
