import 'dart:math' as math;

/// How much of a hit an armoured target actually takes.
///
/// The Carapace family's frontal plate is the reason the Draw mechanic exists:
/// a Tier-I arrow *plinks* off a Husk with a metallic clang and no damage
/// number, Tier II gets partway through, Tier III breaks it. See
/// docs/05-enemies.md §5.2.
abstract final class ArmourFactor {
  /// Tier-I into a live plate. Deliberately non-zero — a player who refuses to
  /// Draw can still win, just slowly. A hard zero would read as "my weapon is
  /// broken" rather than "I need a heavier shot".
  static const double plateBlocked = 0.10;

  /// Tier-II into a live plate.
  static const double platePartial = 0.55;

  /// Tier III, a flank, or no plate at all.
  static const double none = 1.0;
}

/// The single place damage is computed.
///
/// docs/08-arrows.md §8.1 specifies an exact ordered expression, and this is it.
/// **Nothing else in the codebase may compute damage.** Every ability, Boon,
/// element and boss mechanic feeds this function; a second damage path would
/// silently escape the clamps below and break the balance harness's guarantees.
///
/// Three rules make the formula safe to extend (docs/04-upgrades.md §4.1):
///
///  1. **Additive within a source, multiplicative across sources.** All Boon
///     damage bonuses sum into one term. They do not multiply each other — that
///     is what stops a 20-Boon run from producing a five-figure multiplier.
///  2. **Every multiplier class has its own ceiling**, clamped independently
///     *before* the next term is applied, so an unforeseen combination cannot
///     compound past the cap.
///  3. **Term order is fixed.** Reordering changes results and invalidates every
///     recorded replay and balance measurement, so the sequence below is the
///     contract.
///
/// Allocation-free: plain positional maths, no intermediate objects, safe to
/// call thousands of times per tick.
abstract final class DamageResolver {
  // ── Ceilings, from docs/04 §4.1 ───────────────────────────────────────────

  /// Tier III is 2.10x. Nothing may exceed it.
  static const double maxDrawTierMultiplier = 2.10;

  /// Confluence x3 is +160%. Iris's x5 raises the *stack cap*, not this ceiling
  /// — her extra stacks are granted a higher allowance via [maxConfluenceIris].
  static const double maxConfluenceBonus = 1.60;

  /// Iris (docs/07 §7.3) uniquely reaches 5 stacks, worth +320%.
  static const double maxConfluenceIris = 3.20;

  /// Damage reduction is combined multiplicatively and capped here. Never
  /// additive — additive DR reaches 100% and makes the player invulnerable.
  static const double maxDamageReduction = 0.75;

  static const double pierceFalloffPerHit = 0.85;

  static const double baseCritMultiplier = 1.80;

  /// Resolves one hit.
  ///
  /// [attack] is the attacker's fully-composed ATK (hero base x arrow x Spire x
  /// research x ascension x boons), computed once per shot rather than per hit.
  ///
  /// [pierceIndex] is 0 for the first target this arrow strikes, 1 for the
  /// second, and so on. Falloff converges rather than exploding, so an
  /// infinite-pierce build (Boon 25, *The Long Arrow*) is strong without being
  /// unbounded: the tenth target takes ~23%.
  static double resolve({
    required double attack,
    required double arrowBaseMultiplier,
    required double drawTierMultiplier,
    double confluenceBonus = 0,
    bool isCrit = false,
    double critMultiplier = baseCritMultiplier,
    double boonDamageSum = 0,
    double elementalBonus = 0,
    int pierceIndex = 0,
    double armourFactor = ArmourFactor.none,
    double confluenceCeiling = maxConfluenceBonus,
  }) {
    assert(attack >= 0, 'attack must be non-negative');
    assert(pierceIndex >= 0, 'pierceIndex must be non-negative');

    double damage = attack;

    // 1. Arrow coefficient.
    damage *= arrowBaseMultiplier;

    // 2. Draw tier.
    damage *= _clampUpper(drawTierMultiplier, maxDrawTierMultiplier);

    // 3. Confluence.
    damage *= 1.0 + _clamp(confluenceBonus, 0, confluenceCeiling);

    // 4. Crit.
    if (isCrit) damage *= critMultiplier;

    // 5. Boons — summed, never multiplied against each other.
    damage *= 1.0 + _clampLower(boonDamageSum, -0.95);

    // 6. Elemental / reaction bonus.
    damage *= 1.0 + _clampLower(elementalBonus, -0.95);

    // 7. Pierce falloff.
    if (pierceIndex > 0) {
      damage *= math.pow(pierceFalloffPerHit, pierceIndex).toDouble();
    }

    // 8. Armour.
    damage *= _clamp(armourFactor, 0, 1);

    return damage;
  }

  /// Damage taken after mitigation.
  ///
  /// Sources combine multiplicatively — `1 - product(1 - dr_i)` — and the total
  /// is capped. Additive stacking is the classic mistake here: three 40% sources
  /// would produce 120% and heal the player.
  static double applyDamageReduction(double incoming, List<double> reductions) {
    double remaining = 1.0;
    for (int i = 0; i < reductions.length; i++) {
      final double r = _clamp(reductions[i], 0, 1);
      remaining *= 1.0 - r;
    }
    final double total = _clampUpper(1.0 - remaining, maxDamageReduction);
    return incoming * (1.0 - total);
  }

  /// Two-source variant, allocation-free for the hot path.
  static double applyDamageReduction2(
    double incoming,
    double a,
    double b,
  ) {
    final double remaining =
        (1.0 - _clamp(a, 0, 1)) * (1.0 - _clamp(b, 0, 1));
    final double total = _clampUpper(1.0 - remaining, maxDamageReduction);
    return incoming * (1.0 - total);
  }

  /// Effective damage after pierce falloff, without the rest of the chain.
  /// Exposed for the balance harness's TTK modelling.
  static double pierceFalloff(int pierceIndex) => pierceIndex <= 0
      ? 1.0
      : math.pow(pierceFalloffPerHit, pierceIndex).toDouble();

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  static double _clampUpper(double v, double hi) => v > hi ? hi : v;

  static double _clampLower(double v, double lo) => v < lo ? lo : v;
}
