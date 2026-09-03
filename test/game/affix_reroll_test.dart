import 'package:quiverfall/game/arrows/affix_reroll.dart';
import 'package:test/test.dart';

/// docs/08 §8.4 / docs/02 §2.11 rule 4: "1,200 gold, +15 % per reroll in the
/// same session" — checked against the exact formula, the same style
/// arrow_refinement_test.dart uses for its own cost table.
void main() {
  test('goldCost(0) is the flat base cost', () {
    expect(AffixReroll.goldCost(0), 1200);
  });

  test('goldCost grows +15% per prior reroll this session', () {
    expect(AffixReroll.goldCost(1), 1380); // 1200 * 1.15
    expect(AffixReroll.goldCost(2), 1587); // 1200 * 1.15^2 = 1587.0
    expect(AffixReroll.goldCost(3), 1825); // 1200 * 1.15^3 = 1825.05
  });

  test('is monotonically increasing', () {
    int previous = AffixReroll.goldCost(0);
    for (int i = 1; i < 10; i++) {
      final int cost = AffixReroll.goldCost(i);
      expect(cost, greaterThan(previous), reason: 'reroll #$i');
      previous = cost;
    }
  });
}
