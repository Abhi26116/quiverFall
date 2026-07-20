import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/sim/effects/boon_stats.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

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

  // ── Composed: armour ──────────────────────────────────────────────────────

  double armourShredPerHit = 0;
  double armourShredMax = 0;

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
      perHitStreak == 0;

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
  }) {
    double sum = flatDamage;

    if (targetHealthFraction < woundedThreshold) sum += vsWounded;
    if (targetHealthFraction < dyingThreshold) sum += vsDying;
    if (targetAfflicted) sum += vsAfflicted;
    if (targetArmoured) sum += vsArmoured;
    if (targetId == lastHitTarget) sum += vsLastHit;

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
