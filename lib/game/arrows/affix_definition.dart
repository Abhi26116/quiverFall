import 'package:quiverfall/game/sim/effects/affix_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// The 17 affixes of docs/08-arrows.md §8.4's own table.
///
/// The doc's prose says "an 18-entry pool"; the table it introduces names
/// exactly 17. ADR 0012 records that as the document's own miscount rather
/// than an 18th affix to invent. The same split every content identity enum
/// in this codebase uses: archetype is identity, parsed straight from the
/// table's `id`; numbers live in `assets/data/affixes.json`.
enum AffixArchetype {
  sharpened,
  keen,
  swift,
  wide,
  fleet,
  weaving,
  confluent,
  piercing,
  kindled,
  rimed,
  charged,
  blighted,
  executioner,
  fortune,
  threaded,
  resonant,
  echoing,
}

/// docs/08 §8.4's three tiers — "Common", "Rare", "Epic" on each row of the
/// affix table.
///
/// No draw-weight numbers are given anywhere ("weighted by tier" is the
/// whole instruction); ADR 0012 reuses `BoonRarity`'s own three shared tiers
/// verbatim (0.58 / 0.27 / 0.11) as the only "Common/Rare/Epic draw weight"
/// numbers already balance-considered anywhere in the game.
enum AffixRarity {
  common(weight: 0.58),
  rare(weight: 0.27),
  epic(weight: 0.11);

  const AffixRarity({required this.weight});

  final double weight;
}

/// One of the 17 affixes.
///
/// [Affix] (`data/models/inventory.dart`) is the *rolled instance* an
/// [ArrowInstance] actually carries — an `affixId` and a `value` settled
/// once, at refine time. This is the catalogue entry that rolled instance
/// points back to: the range it was rolled within, and which
/// [StatChannel] (or, for Echoing alone, which [AffixBehaviour]) that
/// rolled value means something to.
class AffixDefinition {
  const AffixDefinition({
    required this.archetype,
    required this.key,
    required this.name,
    required this.rarity,
    required this.description,
    required this.minValue,
    required this.maxValue,
    this.channel,
    this.behaviour,
  }) : assert(
          (channel != null) != (behaviour != null),
          'an affix needs a channel or a behaviour, never both and never '
          'neither',
        );

  final AffixArchetype archetype;
  final String key;
  final String name;
  final AffixRarity rarity;

  /// Card text, exactly as the Gear screen shows it.
  final String description;

  /// Inclusive roll range every affix has, regardless of whether the
  /// rolled [Affix.value] feeds a [channel] or is read directly by
  /// [behaviour]'s own code (Echoing's own 8-15 % chance rolls exactly
  /// like any other affix; it is only *interpreted* differently). A
  /// flat-value affix (Piercing's +1 pierce, Threaded's Confluence cap +1)
  /// simply has an equal min and max, so a rolled value is always "the
  /// value this affix means", never a separate flat case callers have to
  /// branch on.
  final double minValue;
  final double maxValue;

  /// The channel a rolled [Affix.value] feeds. Null only for [behaviour]
  /// affixes.
  final StatChannel? channel;

  /// The coded part, for Echoing alone — see [AffixBehaviour]'s own doc
  /// comment for why the list is this short.
  final AffixBehaviour? behaviour;

  @override
  String toString() => name;
}
