import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/boon_inventory.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// Why a card ended up in a set. Recorded per draw so the balance harness can
/// tell a natural offer from a rule firing — a Boon that only ever appears
/// because the drought rule forced it is dead content wearing a disguise.
enum OfferReason {
  /// Rolled normally.
  natural,

  /// docs/09 §9.1: forced because the player has taken no offence card in
  /// [BoonInventory.offenceDroughtLimit] draws.
  forcedOffence,

  /// docs/09 §9.1: the set contained nothing the build could use, so a safe
  /// unconditional Common was substituted.
  usabilityFallback,

  /// The pool ran out of cards at the rolled rarity and fell to another.
  rarityFallback,
}

/// One card in an offer.
class BoonOffer {
  const BoonOffer(this.definition, this.reason);

  final BoonDefinition definition;
  final OfferReason reason;

  @override
  String toString() => reason == OfferReason.natural
      ? definition.toString()
      : '$definition [${reason.name}]';
}

/// Everything that shifts a single draw away from the base weights.
///
/// Passed per draw rather than held on the pool, because two of the three are
/// one-shot: an Elite clear boosts only the *next* draw, and a Shrine purchase
/// only the draw it paid for.
class DrawContext {
  const DrawContext({
    required this.roomIndex,
    this.spireBoonInsight = 0,
    this.afterEliteClear = false,
    this.guaranteeRarePlus = false,
  });

  /// 1-based room index within the stage. Drives depth scaling — docs/09 §9.1.
  final int roomIndex;

  /// Spire node 21, up to +0.32. docs/04 §4.2 Wing IV.
  final double spireBoonInsight;

  /// +40 % Rare+ weight for this draw only.
  final bool afterEliteClear;

  /// A Shrine purchase. The draw must contain no Commons at all.
  final bool guaranteeRarePlus;
}

/// The Boon draw.
///
/// docs/09 §9.1 in one class: rarity weights, depth scaling, and all five
/// anti-frustration rules. The exit criterion for Phase 9 is that these rules
/// hold over 100,000 simulated draws, which is what
/// `test/game/boon_pool_test.dart` runs.
///
/// **Every rule here exists because its absence is a known way to lose a
/// player**, not because it makes the maths tidy. They are listed on
/// [drawSet] in the order they are enforced, and the order matters: usability
/// is checked after the drought rule, so a forced offence card still has to be
/// one the build can actually use.
class BoonPool {
  BoonPool({required this.catalogue, required this.inventory});

  final BoonCatalogue catalogue;
  final BoonInventory inventory;

  /// Base cards per draw. *Curator* (#106) raises it to 5; *Lucky Find* (#97)
  /// rolls for a 4th.
  static const int baseCardCount = 3;

  /// docs/09 §9.1: Legendary and Mythic cannot appear before this room.
  ///
  /// Handing a run-defining card out in room 1 removes every decision that
  /// follows it — the build is settled before the player has learned anything
  /// about the run.
  static const int lateRarityFromRoom = 3;

  /// Per-room weight growth, docs/09 §9.1. Runs escalate: by room 9 a draw is
  /// ~35 % Common and ~19 % Epic, so the build gets loud near the end, which is
  /// where the power fantasy belongs.
  static const double rarePerRoom = 0.018;
  static const double epicPerRoom = 0.014;
  static const double legendaryPerRoom = 0.006;
  static const double mythicPerRoom = 0.0015;

  /// An Elite clear multiplies Rare+ weight by this, for the next draw only.
  static const double eliteRarePlusBonus = 1.40;

  /// Scratch buffers. A draw happens after every room clear, so it runs
  /// hundreds of times per session; reusing these keeps it off the allocator.
  final List<BoonDefinition> _candidates = <BoonDefinition>[];

  /// Rolls one set of cards.
  ///
  /// The five anti-frustration rules of docs/09 §9.1, in enforcement order:
  ///
  ///  1. **No duplicate card within a set.** Two identical cards is not a
  ///     choice, it is one card and a wasted slot.
  ///  2. **A Boon at max copies leaves the pool.** Handled by
  ///     [BoonInventory.isExhausted].
  ///  3. **Legendary and Mythic cannot appear before room [lateRarityFromRoom].**
  ///  4. **A forced offence card after an offence drought.** Players who never
  ///     take damage upgrades hit a DPS wall and quit, and they never diagnose
  ///     it as their own doing.
  ///  5. **At least one card must be usable by the current build.** Enforced
  ///     last, because it has to see the finished set.
  List<BoonOffer> drawSet(Rng rng, DrawContext context) {
    final int count = _cardCount(rng);
    final List<BoonOffer> set = <BoonOffer>[];

    // Rule 4 first: if the drought is on, the offence card is placed before
    // anything else can occupy the slot. Placing it last would mean discarding
    // an already-rolled card, which biases the rest of the set.
    if (inventory.isInOffenceDrought) {
      final BoonDefinition? forced = _rollOne(
        rng,
        context,
        set,
        restrictToOffence: true,
      );
      if (forced != null) {
        set.add(BoonOffer(forced, OfferReason.forcedOffence));
      }
    }

    while (set.length < count) {
      final BoonDefinition? pick = _rollOne(rng, context, set);
      if (pick == null) break; // Pool genuinely exhausted.
      set.add(BoonOffer(pick, OfferReason.natural));
    }

    _ensureUsable(rng, set);
    return set;
  }

  /// Cards in this draw: 3, plus *Curator*, plus a *Lucky Find* roll.
  int _cardCount(Rng rng) {
    int count = baseCardCount + inventory.stats.countFor(StatChannel.boonCardCount);
    final double luck = inventory.stats[StatChannel.fourthCardChance];
    if (luck > 0 && rng.nextDouble() < luck) count++;
    return count;
  }

  /// Rolls a rarity, then a card of that rarity that is not already in [taken].
  BoonDefinition? _rollOne(
    Rng rng,
    DrawContext context,
    List<BoonOffer> taken, {
    bool restrictToOffence = false,
  }) {
    // Rarity is rolled first and the card second, so weights describe *how
    // often a player sees an Epic*, independent of how many Epics exist. That
    // is what lets the catalogue grow without silently changing the feel of a
    // draw.
    final List<double> weights = _rarityWeights(context);

    // Try each rarity in descending roll order, falling back when a tier has
    // nothing offerable left. A run that has taken every Rare must still get a
    // full set.
    for (int attempt = 0; attempt < BoonRarity.values.length; attempt++) {
      final BoonRarity rarity = _rollRarity(rng, weights);
      final BoonDefinition? pick =
          _pickOfRarity(rng, rarity, taken, restrictToOffence);
      if (pick != null) return pick;
      // Zero this tier's weight and re-roll rather than walking tiers in a
      // fixed direction, which would bias the fallback toward Commons.
      weights[rarity.index] = 0;
      if (weights.every((double w) => w <= 0)) break;
    }

    // Nothing anywhere at any rarity.
    return _pickAny(rng, taken, restrictToOffence);
  }

  /// Depth-scaled weights for this room, with modifiers applied.
  List<double> _rarityWeights(DrawContext context) {
    final int r = context.roomIndex < 1 ? 1 : context.roomIndex;
    final double depth = (r - 1).toDouble();

    double rare = BoonRarity.rare.weight + rarePerRoom * depth;
    double epic = BoonRarity.epic.weight + epicPerRoom * depth;
    double legendary = BoonRarity.legendary.weight + legendaryPerRoom * depth;
    double mythic = BoonRarity.mythic.weight + mythicPerRoom * depth;

    // Rule 3. Zeroing before normalisation matters: the weight has to be
    // redistributed to the tiers that *can* appear, not silently lost, or early
    // rooms would draw fewer cards than late ones from the same roll.
    if (r < lateRarityFromRoom) {
      legendary = 0;
      mythic = 0;
    }

    double rarePlusScale = 1.0 + context.spireBoonInsight;
    if (context.afterEliteClear) rarePlusScale *= eliteRarePlusBonus;
    rarePlusScale *= 1.0 + inventory.stats[StatChannel.rarePlusWeight];

    rare *= rarePlusScale;
    epic *= rarePlusScale;
    legendary *= rarePlusScale;
    mythic *= rarePlusScale;

    final double rarePlusTotal = rare + epic + legendary + mythic;

    // A Shrine purchase promises Rare or better. Not "very likely" — the player
    // paid for it, and a paid guarantee that fails once is remembered forever.
    double common = context.guaranteeRarePlus
        ? 0.0
        : (1.0 - rarePlusTotal).clamp(0.0, 1.0);

    // Modifiers can push Rare+ past 1.0 at high room indices with a full Spire
    // node. Renormalising rather than clamping keeps the *ratios* between
    // Rare, Epic, Legendary and Mythic intact, which is what the escalation
    // curve is actually about.
    final double total = common + rarePlusTotal;
    if (total <= 0) {
      common = 1.0;
      return <double>[1, 0, 0, 0, 0];
    }

    return <double>[
      common / total,
      rare / total,
      epic / total,
      legendary / total,
      mythic / total,
    ];
  }

  BoonRarity _rollRarity(Rng rng, List<double> weights) {
    double total = 0;
    for (final double w in weights) {
      total += w;
    }
    double roll = rng.nextDouble() * total;
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return BoonRarity.values[i];
    }
    // Floating-point residue only.
    for (int i = weights.length - 1; i >= 0; i--) {
      if (weights[i] > 0) return BoonRarity.values[i];
    }
    return BoonRarity.common;
  }

  BoonDefinition? _pickOfRarity(
    Rng rng,
    BoonRarity rarity,
    List<BoonOffer> taken,
    bool restrictToOffence,
  ) {
    _candidates.clear();
    for (final BoonDefinition def in catalogue.ofRarity(rarity)) {
      if (!_isEligible(def, taken, restrictToOffence)) continue;
      _candidates.add(def);
    }
    if (_candidates.isEmpty) return null;
    return _candidates[rng.nextInt(_candidates.length)];
  }

  BoonDefinition? _pickAny(
    Rng rng,
    List<BoonOffer> taken,
    bool restrictToOffence,
  ) {
    _candidates.clear();
    for (final BoonDefinition def in catalogue.all) {
      if (!_isEligible(def, taken, restrictToOffence)) continue;
      _candidates.add(def);
    }
    if (_candidates.isEmpty) return null;
    return _candidates[rng.nextInt(_candidates.length)];
  }

  bool _isEligible(
    BoonDefinition def,
    List<BoonOffer> taken,
    bool restrictToOffence,
  ) {
    // Rule 2.
    if (inventory.isExhausted(def)) return false;
    // Rule 1.
    for (final BoonOffer offer in taken) {
      if (offer.definition.id == def.id) return false;
    }
    if (restrictToOffence && def.category != BoonCategory.offence) return false;
    // A card the build cannot use may still appear — rule 5 only guarantees
    // that *one* card is usable, and an unusable card the player can see is how
    // they learn the elemental system exists.
    return true;
  }

  /// Rule 5. If nothing in the set is usable, replace one card with a safe
  /// Common.
  ///
  /// docs/09 §9.1: "a set of three pure Ember Boons cannot be offered to a
  /// player with no elemental source". The replaced slot is the *last* one, so
  /// the rarest card in the set survives — a player who is shown a Legendary
  /// and then has it swapped for "+8 % damage" has been robbed, even if the
  /// Legendary was useless to them.
  void _ensureUsable(Rng rng, List<BoonOffer> set) {
    if (set.isEmpty) return;
    for (final BoonOffer offer in set) {
      if (inventory.canUse(offer.definition)) return;
    }

    _candidates.clear();
    for (final BoonDefinition def in catalogue.safeFallbacks) {
      if (inventory.isExhausted(def)) continue;
      if (set.any((BoonOffer o) => o.definition.id == def.id)) continue;
      _candidates.add(def);
    }
    if (_candidates.isEmpty) return;

    int worst = 0;
    for (int i = 1; i < set.length; i++) {
      if (set[i].definition.rarity.index < set[worst].definition.rarity.index) {
        worst = i;
      }
    }

    set[worst] = BoonOffer(
      _candidates[rng.nextInt(_candidates.length)],
      OfferReason.usabilityFallback,
    );
  }
}

