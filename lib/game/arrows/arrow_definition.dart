import 'package:quiverfall/game/sim/effects/arrow_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/sim/elements.dart';

/// The 12 arrows of docs/08-arrows.md §8.3, one value each.
///
/// The same split every content identity enum in this codebase uses:
/// archetype is identity, parsed straight from the table's `id`; numbers live
/// in `assets/data/arrows.json`.
enum ArrowArchetype {
  ashShaft,
  broadhead,
  splitshaft,
  emberhead,
  rimeshaft,
  stormnock,
  blightbarb,
  skimmer,
  lancehead,
  twinfang,
  ghostshaft,
  prismshaft,
}

/// Which chapter an arrow's craft recipe unlocks at. Distinct from
/// [ArrowInstance.refineLevel] (I–V) — this is content progression, the other
/// is a per-copy upgrade axis. docs/08 §8.3 groups arrows by this exact tier.
enum ArrowContentTier { t1, t2, t3, t4 }

/// docs/08 §8.4's craft cost table, by [ArrowContentTier].
class ArrowCraftCost {
  const ArrowCraftCost({
    required this.gold,
    this.materialsByTier = const <int, int>{},
  });

  final int gold;

  /// Material tier -> count required. T1 has none; Ash Shaft is free and
  /// every other T1 arrow is gold-only.
  final Map<int, int> materialsByTier;
}

/// One of the 12 arrows.
class ArrowDefinition {
  const ArrowDefinition({
    required this.archetype,
    required this.id,
    required this.key,
    required this.name,
    required this.contentTier,
    required this.baseMult,
    required this.craftCost,
    required this.description,
    this.element,
    this.elementPotency,
    this.modifiers = const <StatModifier>[],
    this.behaviour,
    this.balanceNote = '',
  });

  final ArrowArchetype archetype;

  /// 1–12, matching docs/08's numbering.
  final int id;

  final String key;
  final String name;

  final ArrowContentTier contentTier;

  /// docs/08 §8.1's `arrow.baseMult` term — the second multiplicative factor
  /// in the master damage formula, applied after ATK and before the Draw
  /// tier.
  final double baseMult;

  final ArrowCraftCost craftCost;

  /// Card text, exactly as the Gear screen shows it.
  final String description;

  /// The element this arrow carries, or null for a plain shaft.
  final SimElement? element;

  /// A single number whose meaning depends on [element] — docs/08 §8.2's
  /// table gives each element a different kind of quantity (Ember: an
  /// application chance; Frost: Chill per hit; Storm: which arrow triggers a
  /// chain; Toxin: stacks per hit). Kept as one field rather than four
  /// element-specific ones because exactly one is ever meaningful at a time,
  /// and which one is determined entirely by [element].
  final double? elementPotency;

  /// Plain stat contributions — Broadhead's fire-rate penalty, Lancehead's
  /// pierce and projectile speed, Splitshaft's extra arrow.
  final List<StatModifier> modifiers;

  /// The coded part, if any. Most arrows have none — see [ArrowBehaviour]'s
  /// own doc comment for why the list is this short.
  final ArrowBehaviour? behaviour;

  /// docs/08 §8.3's per-arrow balance callout, where it has one. Display
  /// text only.
  final String balanceNote;

  @override
  String toString() => '#$id $name';
}
