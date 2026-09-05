import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/sim/effects/boon_stats.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/sim/elements.dart';

/// The parts of a build that can only be resolved at the moment of a hit.
///
/// Most of a loadout composes once per room into a single number — attack, fire
/// rate, max HP. These cannot: "+10 % damage to enemies below 50 % HP" depends
/// on the target, "+6 % while stationary" on the player, "+4 % per unit of
/// distance" on the geometry of this particular shot. Resolving them at fire
/// time would be wrong; resolving them by walking the inventory per hit would
/// be slow.
///
/// So this object is composed once (from [BoonStats]) and read per hit. It
/// holds two kinds of field, and the distinction matters:
///
///  - **Composed** — set by `LoadoutResolver` when the build changes.
///  - **Live** — updated by the simulation each tick or each hit.
///
/// One instance per world, mutated in place. It is passed to the projectile
/// system as a single parameter rather than a dozen, which is the only reason
/// that signature is still readable.
class CombatModifiers {
  // ── Composed: unconditional ───────────────────────────────────────────────

  /// Feeds `DamageResolver.boonDamageSum`. Every conditional term below is
  /// added to this at resolve time, so they sum with each other rather than
  /// multiplying — docs/04 §4.1 rule 1.
  double flatDamage = 0;

  double critChance = 0;

  /// The full multiplier, not the bonus. Rests at
  /// `DamageResolver.baseCritMultiplier`.
  double critMultiplier = DamageResolver.baseCritMultiplier;

  // ── Composed: conditional on the target ───────────────────────────────────

  /// Below [woundedThreshold] of max HP.
  double vsWounded = 0;

  /// Below [dyingThreshold] of max HP.
  double vsDying = 0;

  /// Burning, poisoned, or frozen.
  double vsAfflicted = 0;

  /// A live plate or shield.
  double vsArmoured = 0;

  /// The same enemy the previous arrow struck.
  double vsLastHit = 0;

  // ── Composed: conditional on the player ───────────────────────────────────

  double whileStationary = 0;

  double perMomentumStack = 0;

  /// Applied for [movedRecentlyWindow] after covering [movedRecentlyDistance].
  double afterMoving = 0;

  // ── Composed: conditional on the shot ─────────────────────────────────────

  double perDistanceUnit = 0;
  double perDistanceCap = 0;

  double perHitStreak = 0;
  double perHitStreakCap = 0;

  // ── Composed: conditional on the Draw tier ────────────────────────────────

  double vsTierThree = 0;
  double vsTierOne = 0;

  // ── Composed: armour ──────────────────────────────────────────────────────

  double armourShredPerHit = 0;
  double armourShredMax = 0;

  // ── Composed: elemental / reaction ────────────────────────────────────────
  // `DamageResolver`'s own step 6, "Elemental / reaction bonus" — a second,
  // separate additive-within-a-source term from `boonDamageSum`'s step 5.
  // Every one of these was declared as a `StatChannel` (Oriel's own Attuned/
  // Resonance, the Kindled/Rimed/Charged/Blighted/Resonant affixes, a
  // handful of Boons) with nothing anywhere reading them until now.

  double emberDamage = 0;
  double frostDamage = 0;
  double stormDamage = 0;
  double toxinDamage = 0;

  /// Applies regardless of *which* element a hit carries, on top of that
  /// element's own specific bonus above — "Elemental Focus and set bonuses"
  /// per [StatChannel.allElementDamage]'s own doc comment.
  double allElementDamage = 0;

  /// The reaction's own bonus portion (see [elementalBonusFor]) scales by
  /// this additively, the same way every other conditional term here does —
  /// Resonance/Resonant are a fixed bonus, not a fresh independent one.
  double reactionDamage = 0;

  // ── Live: updated by the simulation ───────────────────────────────────────

  /// True on ticks the player is not moving. Drives [whileStationary].
  bool playerStationary = false;

  /// Live Momentum stacks. Drives [perMomentumStack].
  int momentumStacks = 0;

  /// Seconds remaining on the *Kiting* window. Drives [afterMoving].
  double movedRecentlyRemaining = 0;

  /// Consecutive hits without a miss. Drives [perHitStreak].
  int hitStreak = 0;

  /// The last enemy struck, or -1. Drives [vsLastHit].
  int lastHitTarget = -1;

  // ── Thresholds, from docs/09 §9.2 ─────────────────────────────────────────

  /// *Barbed Tips* (#6).
  static const double woundedThreshold = 0.50;

  /// *Executioner* (#12).
  static const double dyingThreshold = 0.25;

  /// *Kiting* (#51): "+15 % damage for 2 s after moving 3 u".
  static const double movedRecentlyWindow = 2.0;
  static const double movedRecentlyDistance = 3.0;

  /// Whether anything here can change a hit. Lets the hit path skip the whole
  /// conditional block on a build with no relevant Boons, which is every run's
  /// first room.
  bool get isInert =>
      flatDamage == 0 &&
      critChance == 0 &&
      critMultiplier == DamageResolver.baseCritMultiplier &&
      vsWounded == 0 &&
      vsDying == 0 &&
      vsAfflicted == 0 &&
      vsArmoured == 0 &&
      vsLastHit == 0 &&
      whileStationary == 0 &&
      perMomentumStack == 0 &&
      afterMoving == 0 &&
      perDistanceUnit == 0 &&
      perHitStreak == 0 &&
      vsTierThree == 0 &&
      vsTierOne == 0;

  /// Recomposes the fixed terms from a build.
  ///
  /// Live fields are deliberately untouched: a Boon taken mid-room must not
  /// reset the player's hit streak or their Kiting window.
  void composeFrom(BoonStats stats) {
    flatDamage = stats[StatChannel.damage];
    critChance = stats[StatChannel.critChance];
    critMultiplier =
        DamageResolver.baseCritMultiplier + stats[StatChannel.critDamage];

    vsWounded = stats[StatChannel.damageVsWounded];
    vsDying = stats[StatChannel.damageVsDying];
    vsAfflicted = stats[StatChannel.damageVsAfflicted];
    vsArmoured = stats[StatChannel.damageVsArmoured];
    vsLastHit = stats[StatChannel.damageVsLastHit];

    whileStationary = stats[StatChannel.damageWhileStationary];
    perMomentumStack = stats[StatChannel.damagePerMomentum];
    afterMoving = stats[StatChannel.damageAfterMoving];

    perDistanceUnit = stats[StatChannel.damagePerDistance];
    perDistanceCap = stats[StatChannel.damagePerDistanceCap];

    perHitStreak = stats[StatChannel.damagePerHitStreak];
    perHitStreakCap = stats[StatChannel.damagePerHitStreakCap];

    armourShredPerHit = stats[StatChannel.armourShredPerHit];
    armourShredMax = stats[StatChannel.armourShredMax];

    vsTierThree = stats[StatChannel.tierThreeDamage];
    vsTierOne = stats[StatChannel.tierOneDamage];

    emberDamage = stats[StatChannel.emberDamage];
    frostDamage = stats[StatChannel.frostEffect];
    stormDamage = stats[StatChannel.stormDamage];
    toxinDamage = stats[StatChannel.toxinDamage];
    allElementDamage = stats[StatChannel.allElementDamage];
    reactionDamage = stats[StatChannel.reactionDamage];
  }

  /// The summed Boon damage term for one specific hit.
  ///
  /// Every applicable condition adds into one sum, which then goes to
  /// `DamageResolver` as a single `boonDamageSum`. That is what makes a
  /// twenty-Boon build linear rather than exponential — see docs/04 §4.1
  /// rule 1.
  ///
  /// [targetHealthFraction] is the target's HP over its max, *before* this hit.
  double damageSumFor({
    required double targetHealthFraction,
    required double shotDistance,
    required int targetId,
    bool targetAfflicted = false,
    bool targetArmoured = false,
    bool isTierThree = false,
    bool isTierOne = false,
  }) {
    double sum = flatDamage;

    if (targetHealthFraction < woundedThreshold) sum += vsWounded;
    if (targetHealthFraction < dyingThreshold) sum += vsDying;
    if (targetAfflicted) sum += vsAfflicted;
    if (targetArmoured) sum += vsArmoured;
    if (targetId == lastHitTarget) sum += vsLastHit;
    if (isTierThree) sum += vsTierThree;
    if (isTierOne) sum += vsTierOne;

    if (playerStationary) sum += whileStationary;
    if (movedRecentlyRemaining > 0) sum += afterMoving;

    if (perMomentumStack != 0) sum += perMomentumStack * momentumStacks;

    if (perDistanceUnit != 0) {
      final double byDistance = perDistanceUnit * shotDistance;
      sum += byDistance > perDistanceCap ? perDistanceCap : byDistance;
    }

    if (perHitStreak != 0) {
      final double byStreak = perHitStreak * hitStreak;
      sum += byStreak > perHitStreakCap ? perHitStreakCap : byStreak;
    }

    return sum;
  }

  /// [DamageResolver]'s own step 6, "Elemental / reaction bonus" — composed
  /// the identical additive-within-a-source way [damageSumFor] composes
  /// step 5, just fed by a different set of channels.
  ///
  /// [elementMask] is whichever element(s) *this specific arrow* carries
  /// (`ProjectileStore.elementMask`, or a single bit from `element`) — not
  /// what it crossed. An arrow with no element contributes nothing here,
  /// same as an arrow with no Boon condition met contributes nothing to
  /// [damageSumFor].
  ///
  /// [reactionBonus] is the reaction this specific hit actually triggered
  /// (docs/08 §8.2), expressed as its own bonus portion —
  /// `Reaction.damageMultiplier - 1.0` — rather than the raw multiplier,
  /// since [reactionDamage] (Resonance, the *Resonant* affix) is itself an
  /// additive bonus *to* that portion, not a second independent one. Zero
  /// when no reaction fired this hit.
  double elementalBonusFor({
    required int elementMask,
    double reactionBonus = 0,
  }) {
    double sum = 0;

    if (elementMask != 0) {
      if (allElementDamage != 0) sum += allElementDamage;
      if (emberDamage != 0 && elementMask & (1 << SimElement.ember.index) != 0) {
        sum += emberDamage;
      }
      if (frostDamage != 0 && elementMask & (1 << SimElement.frost.index) != 0) {
        sum += frostDamage;
      }
      if (stormDamage != 0 && elementMask & (1 << SimElement.storm.index) != 0) {
        sum += stormDamage;
      }
      if (toxinDamage != 0 && elementMask & (1 << SimElement.toxin.index) != 0) {
        sum += toxinDamage;
      }
    }

    if (reactionBonus != 0) {
      sum += reactionBonus + reactionDamage;
    }

    return sum;
  }

  /// Resets the live state. Called when a room begins.
  void resetLive() {
    playerStationary = false;
    momentumStacks = 0;
    movedRecentlyRemaining = 0;
    hitStreak = 0;
    lastHitTarget = -1;
  }

  /// Clears everything, composed and live.
  void reset() {
    composeFrom(BoonStats());
    resetLive();
  }
}
