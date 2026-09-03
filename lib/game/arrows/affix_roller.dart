import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/affix_definition.dart';

/// Rolls one fresh [Affix] from an [AffixCatalogue] — docs/08 §8.4:
/// "Affixes roll from a 17-entry pool on each refine, weighted by tier"
/// (ADR 0012 on the 17-not-18 count).
///
/// [exclude] is required rather than inferred: ADR 0013 §2 decides a roll
/// must never duplicate an affix already live on the same arrow, but *which*
/// affixes count as "already live" differs by call site — a fresh refine
/// excludes everything the arrow carries, a single-slot reroll excludes
/// every slot but the one being rerolled. `ArrowWorkshop` states each rule
/// explicitly at its own call site rather than this roller guessing it.
abstract final class AffixRoller {
  static Affix roll(
    AffixCatalogue catalogue,
    Rng rng, {
    required Set<String> exclude,
  }) {
    final List<AffixDefinition> pool = catalogue.all
        .where((AffixDefinition a) => !exclude.contains(a.key))
        .toList(growable: false);
    assert(
      pool.isNotEmpty,
      'no affix left to roll — every catalogue entry is excluded',
    );

    final List<double> weights =
        pool.map((AffixDefinition a) => a.rarity.weight).toList(growable: false);
    final AffixDefinition def = pool[rng.pickWeightedIndex(weights)];
    final double value = rng.nextDoubleRange(def.minValue, def.maxValue);
    return Affix(affixId: def.key, value: value);
  }
}
