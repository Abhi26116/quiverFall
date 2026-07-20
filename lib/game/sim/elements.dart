/// The four elements, as the simulation sees them.
///
/// Deliberately **not** `ElementType` from `core/theme/tokens.dart`: that one
/// carries a `Color` and therefore imports Flutter, which the simulation may
/// never do (docs/12-architecture.md §12.0). The view layer maps this enum to
/// that one. Two small enums are a far better price than a Flutter dependency
/// in the sim.
///
/// Declaration order is the cycle order used by Prismshaft and by Oriel's
/// Spectrum passive, so it is load-bearing rather than cosmetic.
enum SimElement {
  ember,
  frost,
  storm,
  toxin;

  /// Whether this element's damage scales off the *target's* max HP rather than
  /// the player's attack.
  ///
  /// Two of the four scale each way, which is what keeps element choice
  /// meaningful across the whole game instead of one dominating late
  /// (docs/08-arrows.md §8.2). Ember and Toxin are boss-killers and weak against
  /// fodder; Frost and Storm are the reverse.
  bool get scalesOffTargetHp =>
      this == SimElement.ember || this == SimElement.toxin;
}

/// The seven reactions, from docs/08-arrows.md §8.2.
///
/// **Reactions can only be produced by Confluence** — by threading an arrow of
/// one element through a Windline of another. They are never produced by
/// passively stacking two elemental items. That single restriction is what turns
/// build-crafting into an execution problem and is the deepest idea in the game.
enum Reaction {
  /// Ember + Frost. AoE plus an armour shred.
  steamburst,

  /// Ember + Storm. Chains ignite, chain count rises.
  firestorm,

  /// Ember + Toxin. Both DoTs tick at double rate.
  blightfire,

  /// Frost + Storm. Chains cannot miss; frozen targets take double.
  superconduct,

  /// Frost + Toxin. Freeze extended, Toxin stacks survive the freeze.
  rimeRot,

  /// Storm + Toxin. Chains spread Toxin stacks.
  corrosiveArc,

  /// Three or more elements at once — Oriel's Prism, or Boon 90.
  prismbreak;

  /// Damage multiplier applied to the triggering hit.
  double get damageMultiplier => switch (this) {
        Reaction.steamburst => 1.80,
        Reaction.firestorm => 1.40,
        Reaction.blightfire => 1.30,
        Reaction.superconduct => 1.60,
        Reaction.rimeRot => 1.25,
        Reaction.corrosiveArc => 1.45,
        Reaction.prismbreak => 4.00,
      };

  /// Radius of the reaction's area effect, in world units. Zero means the
  /// reaction is single-target.
  double get areaRadius => switch (this) {
        Reaction.steamburst => 2.5,
        Reaction.prismbreak => 4.0,
        _ => 0.0,
      };
}

/// Resolves which reaction two elements produce.
abstract final class Reactions {
  /// Minimum seconds between reactions on the same enemy.
  ///
  /// Without this, a high-fire-rate hero (Kestrel at ~3 shots/second, Mirelle
  /// with duplication) would turn reactions into a continuous damage stream
  /// rather than a punctuated payoff — both a balance problem and a visual one,
  /// since every reaction is a screen-filling effect.
  static const double perEnemyCooldown = 0.6;

  /// The reaction for an unordered pair, or null if the elements match.
  static Reaction? between(SimElement a, SimElement b) {
    if (a == b) return null;

    // Normalise the pair so the matrix needs one entry per combination rather
    // than two.
    final SimElement lo = a.index < b.index ? a : b;
    final SimElement hi = a.index < b.index ? b : a;

    return switch ((lo, hi)) {
      (SimElement.ember, SimElement.frost) => Reaction.steamburst,
      (SimElement.ember, SimElement.storm) => Reaction.firestorm,
      (SimElement.ember, SimElement.toxin) => Reaction.blightfire,
      (SimElement.frost, SimElement.storm) => Reaction.superconduct,
      (SimElement.frost, SimElement.toxin) => Reaction.rimeRot,
      (SimElement.storm, SimElement.toxin) => Reaction.corrosiveArc,
      _ => null,
    };
  }

  /// Three or more distinct elements on one hit collapse to Prismbreak.
  static Reaction? forElementCount(int distinctElements) =>
      distinctElements >= 3 ? Reaction.prismbreak : null;
}

/// Tuning for the elemental status effects themselves.
///
/// From docs/08-arrows.md §8.2. Kept here rather than in the systems so the
/// balance harness can sweep them.
abstract final class ElementTuning {
  // ── Ember ─────────────────────────────────────────────────────────────────

  /// Burn deals this fraction of the target's max HP per second.
  static const double burnPerSecond = 0.04;
  static const double burnDuration = 4.0;
  static const int burnMaxStacks = 2;

  /// Application chance on a normal hit. Tier III guarantees it regardless.
  static const double emberApplyChance = 0.25;

  // ── Frost ─────────────────────────────────────────────────────────────────

  static const double chillPerHit = 12.0;
  static const double chillToFreeze = 100.0;
  static const double freezeDuration = 1.6;

  /// Extra damage a frozen target takes.
  static const double frozenDamageBonus = 0.30;

  /// Chill bleeds off when not reinforced, or a single Rimeshaft would freeze
  /// everything eventually regardless of pressure.
  static const double chillDecayPerSecond = 8.0;

  // ── Storm ─────────────────────────────────────────────────────────────────

  static const int chainTargets = 3;
  static const double chainDamageFraction = 0.60;

  /// Every Nth arrow chains.
  static const int chainEveryNthArrow = 5;

  // ── Toxin ─────────────────────────────────────────────────────────────────

  /// Each stack deals this fraction of the target's max HP per second.
  static const double toxinPerStackPerSecond = 0.009;
  static const int toxinMaxStacks = 10;

  /// Each stack also reduces healing the target receives.
  static const double toxinHealingReductionPerStack = 0.05;
}
