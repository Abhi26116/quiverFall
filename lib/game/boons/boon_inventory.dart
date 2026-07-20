import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_stats.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/sim/elements.dart';

/// What one run is carrying.
///
/// Copy counts, not a list of taken cards: a run holds at most 112 distinct
/// Boons and up to five copies of some, and a count array answers "how many of
/// #1 do I have" in one read. [stats] and [behaviours] are recomputed only when
/// the inventory changes, so the simulation reads a settled snapshot rather
/// than walking the inventory per tick.
class BoonInventory {
  BoonInventory({required this.catalogue, this.synergies = SynergyCatalogue.empty})
      : _copies = List<int>.filled(catalogue.length + 1, 0),
        _behaviourActive = List<bool>.filled(BoonBehaviour.values.length, false);

  final BoonCatalogue catalogue;

  /// Sets and evolutions. Empty by default, so a test that only cares about
  /// cards need not construct one.
  final SynergyCatalogue synergies;

  /// Sets currently complete. Recomputed on every change; the UI announces the
  /// ones that were not here last time.
  final Set<String> activeSets = <String>{};

  /// Evolutions currently triggered.
  final Set<String> activeEvolutions = <String>{};

  /// `_copies[id]`. Index 0 unused, mirroring the catalogue's 1-based ids.
  final List<int> _copies;

  final List<bool> _behaviourActive;

  /// The composed numeric contribution of everything held. Recomposed on every
  /// change, read every tick.
  final BoonStats stats = BoonStats();

  /// Build properties the run has acquired, from Boons and from the loadout.
  final Set<BuildTag> tags = <BuildTag>{};

  /// The element chosen for *Attunement* (#88), or granted by *Elemental Tips*
  /// (#81). Null until one of those resolves.
  SimElement? attunedElement;

  /// Cards taken in order, for the run summary and the analytics event.
  final List<int> pickOrder = <int>[];

  /// Categories of the last few picks, so the draw can enforce docs/09 §9.1's
  /// "forced offence" rule. Bounded, so it never grows with run length.
  final List<BoonCategory> _recentCategories = <BoonCategory>[];

  /// docs/09 §9.1: if a player has taken zero offence Boons in this many
  /// consecutive draws, one offence card is forced. Players who never take
  /// damage upgrades hit a DPS wall and quit; the game quietly protects them.
  static const int offenceDroughtLimit = 4;

  int copiesOf(int id) => id >= 0 && id < _copies.length ? _copies[id] : 0;

  bool has(int id) => copiesOf(id) > 0;

  bool hasBehaviour(BoonBehaviour behaviour) =>
      _behaviourActive[behaviour.index];

  /// The live behaviour flags, for [BoonRuntime.setActive].
  ///
  /// Exposed as the raw list rather than a Set so the copy into the runtime is
  /// an array walk. Read-only by contract; the inventory owns it.
  List<bool> get behaviourFlags => _behaviourActive;

  /// Whether this card can still be offered. docs/09 §9.1: a Boon at max copies
  /// is removed from the pool entirely.
  bool isExhausted(BoonDefinition def) => copiesOf(def.id) >= def.maxCopies;

  /// True when the last [offenceDroughtLimit] picks contained no offence card
  /// *and* there have been that many picks to judge by.
  bool get isInOffenceDrought =>
      _recentCategories.length >= offenceDroughtLimit &&
      !_recentCategories.contains(BoonCategory.offence);

  /// Whether the build satisfies a card's requirements — docs/09 §9.1's
  /// usability rule.
  bool canUse(BoonDefinition def) {
    for (final BuildTag tag in def.requires) {
      if (!tags.contains(tag)) return false;
    }
    for (final BuildTag tag in def.excludes) {
      if (tags.contains(tag)) return false;
    }
    return true;
  }

  /// Whether this card could be offered at all right now.
  bool isOfferable(BoonDefinition def) => !isExhausted(def) && canUse(def);

  /// Grants a build property from outside the Boon system — the equipped
  /// arrow's element, a hero passive, a Spire node.
  ///
  /// Called before the first draw. An element that arrives from the loadout
  /// must make elemental riders offerable on room one, or a Frost build would
  /// spend its whole first stage being shown cards it cannot use.
  void grantTag(BuildTag tag) {
    if (tags.add(tag)) _recompose();
  }

  /// Takes a card. Returns false if it was already at max copies.
  ///
  /// [rng] is needed only by the cards that choose something at pickup —
  /// *Elemental Tips* (#81) rolls an element, *Attunement* (#88) picks one.
  /// Both settle **once**, here, rather than per arrow: an element that changed
  /// shot to shot would make every elemental rider unpredictable.
  bool take(BoonDefinition def, {Rng? rng}) {
    if (isExhausted(def)) return false;

    _copies[def.id]++;
    pickOrder.add(def.id);

    _recentCategories.add(def.category);
    if (_recentCategories.length > offenceDroughtLimit) {
      _recentCategories.removeAt(0);
    }

    tags.addAll(def.grants);
    _recompose();
    _resolveOnPickup(def, rng);
    return true;
  }

  /// The three cards that decide something the moment they are taken.
  ///
  /// Kept out of `_recompose`, which runs again on every later pick: healing to
  /// full once is *Vital Surge*, and healing to full on every subsequent pick
  /// is a different and far stronger card.
  void _resolveOnPickup(BoonDefinition def, Rng? rng) {
    switch (def.behaviour) {
      case BoonBehaviour.elementalTips:
        attunedElement ??=
            SimElement.values[(rng ?? Rng(def.id)).nextInt(SimElement.values.length)];
        tags.addAll(<BuildTag>[
          BuildTag.anyElement,
          _tagFor(attunedElement!),
        ]);
      case BoonBehaviour.attunement:
        // Picks whichever element the build already leans on, falling back to a
        // roll. A card that says "choose one" and chooses badly is worse than
        // one that never asked.
        attunedElement ??= _preferredElement(rng);
      case BoonBehaviour.vitalSurge:
        healToFullPending = true;
      default:
        break;
    }
  }

  /// Set by *Vital Surge* (#30). Consumed by whoever owns the player's health,
  /// because an inventory has no business writing to an entity store.
  bool healToFullPending = false;

  SimElement _preferredElement(Rng? rng) {
    for (final SimElement e in SimElement.values) {
      if (tags.contains(_tagFor(e))) return e;
    }
    return SimElement.values[(rng ?? Rng(88)).nextInt(SimElement.values.length)];
  }

  static BuildTag _tagFor(SimElement e) => switch (e) {
        SimElement.ember => BuildTag.ember,
        SimElement.frost => BuildTag.frost,
        SimElement.storm => BuildTag.storm,
        SimElement.toxin => BuildTag.toxin,
      };

  /// Recomputes [stats] and [behaviours] from the copy counts.
  ///
  /// Additive channels sum `value * copies`. Multiplicative channels — the four
  /// flagged by [StatChannel.isMultiplicative] — compose by *repeated
  /// multiplication*, because three copies of "Momentum decays 40 % slower"
  /// must mean 1.4³, not 4.2. Summing them would be silently wrong in a way
  /// that only shows up at three copies.
  void _recompose() {
    stats.reset();
    for (int i = 0; i < _behaviourActive.length; i++) {
      _behaviourActive[i] = false;
    }

    for (final BoonDefinition def in catalogue.all) {
      final int copies = _copies[def.id];
      if (copies == 0) continue;

      for (final BoonModifier mod in def.modifiers) {
        if (mod.channel.isMultiplicative) {
          for (int c = 0; c < copies; c++) {
            stats.multiplyBy(mod.channel, mod.value);
          }
        } else {
          stats.add(mod.channel, mod.value * copies);
        }
      }

      final BoonBehaviour? behaviour = def.behaviour;
      if (behaviour != null) _behaviourActive[behaviour.index] = true;
    }

    _composeEvolutions();
    _composeSets();
  }

  /// docs/09 §9.4. An evolution **replaces** its base card.
  ///
  /// Composed before sets, and after the plain cards, so that the base card's
  /// own contribution can be subtracted before anything else reads the totals.
  /// Adding on top instead would let a run hold both halves of the trade —
  /// *Storm of Nocks* is seven arrows at −30 % each, not seven arrows plus the
  /// three Split Shots that paid for it.
  void _composeEvolutions() {
    activeEvolutions.clear();

    for (final BoonEvolution evo in synergies.evolutions) {
      bool met = true;
      for (final EvolutionRequirement req in evo.requirements) {
        if (copiesOf(req.id) < req.copies) {
          met = false;
          break;
        }
      }
      if (!met) continue;

      activeEvolutions.add(evo.id);

      // Undo the base card. Its behaviour stays live where the evolution is a
      // strict upgrade of it, which is why only modifiers are subtracted.
      final BoonDefinition? base = catalogue.byId(evo.replaces);
      if (base != null) {
        final int copies = copiesOf(base.id);
        for (final BoonModifier mod in base.modifiers) {
          if (mod.channel.isMultiplicative) {
            for (int c = 0; c < copies; c++) {
              stats.multiplyBy(mod.channel, 1.0 / mod.value);
            }
          } else {
            stats.add(mod.channel, -mod.value * copies);
          }
        }
      }

      for (final BoonModifier mod in evo.modifiers) {
        if (mod.channel.isMultiplicative) {
          stats.multiplyBy(mod.channel, mod.value);
        } else {
          stats.add(mod.channel, mod.value);
        }
      }
      final BoonBehaviour? behaviour = evo.behaviour;
      if (behaviour != null) _behaviourActive[behaviour.index] = true;
    }
  }

  /// docs/09 §9.3. Three **distinct** members and the set fires.
  ///
  /// Copies deliberately do not count: three Long Weaves is one Weaver member.
  /// Counting them would let a single stacked Common complete a set alone,
  /// which turns "my build became a thing" into "I took the same card thrice".
  void _composeSets() {
    activeSets.clear();

    for (final SynergySet set in synergies.sets) {
      int distinct = 0;
      for (final BoonDefinition def in catalogue.all) {
        if (_copies[def.id] == 0) continue;
        if (set.countsMember(def)) distinct++;
      }
      if (distinct < set.threshold) continue;

      activeSets.add(set.id);
      for (final BoonModifier mod in set.modifiers) {
        if (mod.channel.isMultiplicative) {
          stats.multiplyBy(mod.channel, mod.value);
        } else {
          stats.add(mod.channel, mod.value);
        }
      }
      final BoonBehaviour? behaviour = set.behaviour;
      if (behaviour != null) _behaviourActive[behaviour.index] = true;
    }
  }

  /// Clears the run. The catalogue is kept; everything else resets.
  void reset() {
    for (int i = 0; i < _copies.length; i++) {
      _copies[i] = 0;
    }
    pickOrder.clear();
    _recentCategories.clear();
    tags.clear();
    attunedElement = null;
    healToFullPending = false;
    activeSets.clear();
    activeEvolutions.clear();
    _recompose();
  }

  /// Debug view of the build, newest pick last.
  String describe() {
    if (pickOrder.isEmpty) return '(no Boons)';
    final Map<int, int> counted = <int, int>{};
    for (final int id in pickOrder) {
      counted[id] = (counted[id] ?? 0) + 1;
    }
    return counted.entries
        .map((MapEntry<int, int> e) {
          final BoonDefinition? def = catalogue.byId(e.key);
          final String name = def?.name ?? '#${e.key}';
          return e.value > 1 ? '$name ×${e.value}' : name;
        })
        .join(', ');
  }
}
