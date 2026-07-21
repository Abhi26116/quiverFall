import 'package:quiverfall/game/arrows/arrow_refinement.dart';
import 'package:test/test.dart';

/// docs/08-arrows.md §8.4's refinement table, checked against the exact
/// formula rather than against the doc's own rounded display numbers — see
/// [ArrowRefinement.goldCost]'s doc comment for why the two differ slightly
/// at III→IV and IV→V.
void main() {
  group('gold cost follows refineCost(t) = 800 * 4.2^(t-1)', () {
    test('I to V, against the formula computed independently', () {
      expect(ArrowRefinement.goldCost(0), 800); // I -> II
      expect(ArrowRefinement.goldCost(1), 3360); // II -> III
      expect(ArrowRefinement.goldCost(2), 14112); // III -> IV
      expect(ArrowRefinement.goldCost(3), 59270); // IV -> V
    });

    test('matches docs/08 §8.4\'s table within its own rounding', () {
      // The doc's displayed numbers (800 / 3,360 / 14,100 / 59,300) are a
      // rounded restatement of the same formula, not a second source of
      // truth — this asserts they are close, not identical.
      const List<int> documented = <int>[800, 3360, 14100, 59300];
      for (int level = 0; level < ArrowRefinement.maxLevel; level++) {
        final int actual = ArrowRefinement.goldCost(level);
        expect(
          (actual - documented[level]).abs(),
          lessThan(50),
          reason: 'refine step $level: formula gives $actual, doc table '
              'says ${documented[level]}',
        );
      }
    });

    test('cumulative cost from unrefined to V', () {
      final int total = ArrowRefinement.cumulativeGoldCost(4);
      expect(total, 800 + 3360 + 14112 + 59270);
    });
  });

  group('materials follow 3*t of tier ceil(t*0.8)', () {
    test('count and tier at each step', () {
      expect(ArrowRefinement.materialCount(0), 3); // t=1
      expect(ArrowRefinement.materialTier(0), 1);
      expect(ArrowRefinement.materialCount(1), 6); // t=2
      expect(ArrowRefinement.materialTier(1), 2);
      expect(ArrowRefinement.materialCount(2), 9); // t=3
      expect(ArrowRefinement.materialTier(2), 3);
      expect(ArrowRefinement.materialCount(3), 12); // t=4
      expect(ArrowRefinement.materialTier(3), 4);
    });
  });

  group('baseMult bonus and affix slots match the table', () {
    test('cumulative baseMult bonus: 0, +8%, +17%, +27%, +40%', () {
      expect(ArrowRefinement.baseMultMultiplier(0), closeTo(1.00, 1e-9));
      expect(ArrowRefinement.baseMultMultiplier(1), closeTo(1.08, 1e-9));
      expect(ArrowRefinement.baseMultMultiplier(2), closeTo(1.17, 1e-9));
      expect(ArrowRefinement.baseMultMultiplier(3), closeTo(1.27, 1e-9));
      expect(ArrowRefinement.baseMultMultiplier(4), closeTo(1.40, 1e-9));
    });

    test('affix slots: 0, 1, 2, 3, 4', () {
      for (int level = 0; level <= ArrowRefinement.maxLevel; level++) {
        expect(ArrowRefinement.affixSlots(level), level);
      }
    });

    test('an unrefined arrow (level 0) has no bonus and no slots', () {
      expect(ArrowRefinement.baseMultMultiplier(0), 1.0);
      expect(ArrowRefinement.affixSlots(0), 0);
    });
  });
}
