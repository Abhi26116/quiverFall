import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/affix_definition.dart';
import 'package:quiverfall/game/arrows/affix_roller.dart';
import 'package:test/test.dart';

import 'affix_test_support.dart';

void main() {
  late AffixCatalogue catalogue;

  setUpAll(() {
    catalogue = loadAffixes();
  });

  test('a rolled value always lands within the affix\'s own range', () {
    final Rng rng = Rng(7);
    for (int i = 0; i < 500; i++) {
      final Affix rolled =
          AffixRoller.roll(catalogue, rng, exclude: const <String>{});
      final AffixDefinition def = catalogue.byKey(rolled.affixId)!;
      expect(rolled.value, greaterThanOrEqualTo(def.minValue), reason: def.key);
      expect(rolled.value, lessThanOrEqualTo(def.maxValue), reason: def.key);
    }
  });

  test('never rolls an excluded key', () {
    final Rng rng = Rng(11);
    final Set<String> allButOne = catalogue.all
        .map((AffixDefinition a) => a.key)
        .where((String k) => k != 'echoing')
        .toSet();
    for (int i = 0; i < 200; i++) {
      final Affix rolled = AffixRoller.roll(catalogue, rng, exclude: allButOne);
      expect(rolled.affixId, 'echoing');
    }
  });

  test(
      'draws land on each rarity roughly in proportion to '
      '(entries of that rarity) * (that rarity\'s weight)', () {
    final Rng rng = Rng(23);
    const int draws = 6000;
    final Map<AffixRarity, int> counts = <AffixRarity, int>{
      for (final AffixRarity r in AffixRarity.values) r: 0,
    };
    for (int i = 0; i < draws; i++) {
      final Affix rolled =
          AffixRoller.roll(catalogue, rng, exclude: const <String>{});
      final AffixRarity rarity = catalogue.byKey(rolled.affixId)!.rarity;
      counts[rarity] = counts[rarity]! + 1;
    }

    // 5 common / 9 rare / 3 epic entries (docs/08 §8.4; ADR 0012) weighted
    // 0.58 / 0.27 / 0.11 each (ADR 0012) — total weight 5.66, so epic's own
    // overall share is the tightest band worth checking.
    const double totalWeight = 5 * 0.58 + 9 * 0.27 + 3 * 0.11;
    final double epicShare = counts[AffixRarity.epic]! / draws;
    expect(epicShare, closeTo((3 * 0.11) / totalWeight, 0.02));

    final double commonShare = counts[AffixRarity.common]! / draws;
    expect(commonShare, closeTo((5 * 0.58) / totalWeight, 0.03));
  });
}
