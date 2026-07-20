import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// docs/09 §9.1. Rarity drives weight, colour, and the power budget the
/// balance harness holds each card to.
enum BoonRarity {
  common(weight: 0.58, targetPowerScore: 3.0, tolerance: 1.0),
  rare(weight: 0.27, targetPowerScore: 7.5, tolerance: 2.0),
  epic(weight: 0.11, targetPowerScore: 15.0, tolerance: 3.5),
  legendary(weight: 0.035, targetPowerScore: 28.0, tolerance: 6.0),
  mythic(weight: 0.005, targetPowerScore: 45.0, tolerance: 12.0);

  const BoonRarity({
    required this.weight,
    required this.targetPowerScore,
    required this.tolerance,
  });

  /// Base draw weight at room 1. Depth scaling moves these — see [BoonPool].
  final double weight;

  /// docs/09 §9.5. The win-rate delta this card is budgeted for, measured by
  /// the Phase 12 harness. Held here so the gate has one place to read from.
  final double targetPowerScore;

  final double tolerance;

  /// Legendary and Mythic cannot appear before this room. docs/09 §9.1.
  bool get isLateOnly => this == legendary || this == mythic;

  /// Whether the card renders with the Rare+ treatment, which several
  /// modifiers key off.
  bool get isRarePlus => index >= BoonRarity.rare.index;
}

/// The seven catalogue sections of docs/09 §9.2.
///
/// Category is not cosmetic: the anti-frustration rule that forces an offence
/// card after four offence-free draws reads [offence] directly, and the Cursed
/// border treatment is a promise to the player rather than a style choice.
enum BoonCategory {
  offence,
  defence,
  mobility,
  windline,
  elemental,
  economy,
  cursed;

  /// Cursed cards always render a crimson border and an explicit downside line.
  /// docs/09 §9.2 G: a Cursed Boon that surprises the player is a broken
  /// promise.
  bool get showsDownside => this == cursed;
}

/// A property of the player's current build that a Boon can depend on.
///
/// This is the mechanism behind docs/09 §9.1's third anti-frustration rule —
/// "at least one card in every set must be usable by the current build". A set
/// of three pure Ember Boons offered to a player with no elemental source is
/// not a choice, it is three blanks.
enum BuildTag {
  /// Any elemental source at all, from the arrow, a hero, or a Boon.
  anyElement,
  ember,
  frost,
  storm,
  toxin,

  /// A dash exists to be modified.
  dash,

  /// The build can crit often enough for crit riders to matter.
  crit,

  /// The build pierces, so pierce riders are live.
  pierce;
}

/// One numeric contribution: a channel and how much per copy.
class BoonModifier {
  const BoonModifier(this.channel, this.value);

  final StatChannel channel;

  /// Per copy. A ×5 Common at three copies contributes `value * 3`.
  final double value;

  @override
  String toString() => '${channel.name} ${value >= 0 ? '+' : ''}$value';
}

/// One of the 112 cards.
///
/// Definitions are immutable and shared; what a *player* holds is a copy count
/// in [BoonInventory]. That split is what makes recomposing a loadout between
/// rooms allocation-free.
class BoonDefinition {
  const BoonDefinition({
    required this.id,
    required this.key,
    required this.name,
    required this.category,
    required this.rarity,
    required this.maxCopies,
    required this.description,
    this.modifiers = const <BoonModifier>[],
    this.behaviour,
    this.requires = const <BuildTag>[],
    this.excludes = const <BuildTag>[],
    this.grants = const <BuildTag>[],
    this.downside,
    this.stacksByCopies = false,
  });

  /// 1–112, matching the catalogue numbering in docs/09 §9.2 exactly. Synergy
  /// sets and evolution paths are authored against these numbers, so they are
  /// the stable identity — [key] is for humans and logs.
  final int id;

  final String key;
  final String name;
  final BoonCategory category;
  final BoonRarity rarity;

  /// docs/09 §9.2's `×n`. A Boon at max copies leaves the pool entirely.
  final int maxCopies;

  /// The card text, exactly as the player reads it.
  final String description;

  /// The stat contribution, per copy.
  final List<BoonModifier> modifiers;

  /// The coded part, if any. Most cards have none.
  final BoonBehaviour? behaviour;

  /// Build properties this card needs to do anything.
  final List<BuildTag> requires;

  /// Build properties that make this card pointless. *Elemental Tips* grants an
  /// element only to a player who has none, so offering it to an Ember build is
  /// a blank.
  final List<BuildTag> excludes;

  /// Build properties this card confers on the build once taken. Taking
  /// *Elemental Tips* makes every elemental rider live, and the pool must know
  /// that on the very next draw.
  final List<BuildTag> grants;

  /// The explicit cost line shown under a Cursed card. Required for
  /// [BoonCategory.cursed] and forbidden elsewhere — validated at load.
  final String? downside;

  /// Declares that [behaviour] reads its own copy count.
  ///
  /// A behaviour is normally on or off, so a second copy of a pure-behaviour
  /// card would do nothing and waste a slot in a draw — the catalogue validator
  /// rejects that. A few behaviours genuinely scale (*Echo Thread*'s line grows
  /// with copies), and this flag is how an author says so on purpose rather
  /// than by leaving `maxCopies` high and hoping.
  final bool stacksByCopies;

  /// Whether this card is safe to offer to any build whatsoever.
  ///
  /// The fallback used when the tag-match filter cannot find a usable card. A
  /// safe card is an unconditional Common with no requirements — "+8 % damage"
  /// is never a blank for anybody.
  bool get isUniversallyUseful =>
      requires.isEmpty && excludes.isEmpty && rarity == BoonRarity.common;

  @override
  String toString() => '#$id $name (${rarity.name})';
}
