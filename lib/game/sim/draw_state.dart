/// The three Draw tiers.
///
/// The bow winds while the player is stationary. This is half of the game's core
/// trade — see docs/01-vision.md §1.1.
enum DrawTier {
  /// 0.00 - 0.45 s stationary.
  one(damageMultiplier: 1.00, fireRate: 2.2, bonusPierce: 0),

  /// 0.45 - 1.10 s.
  two(damageMultiplier: 1.45, fireRate: 2.0, bonusPierce: 1),

  /// 1.10 s+. Guaranteed element proc, 1.5x arrow hitbox.
  three(damageMultiplier: 2.10, fireRate: 1.7, bonusPierce: 2);

  const DrawTier({
    required this.damageMultiplier,
    required this.fireRate,
    required this.bonusPierce,
  });

  final double damageMultiplier;

  /// Shots per second. Note it *falls* as the tier rises: heavier shots come
  /// slower, so Tier III is not strictly better DPS against a swarm. That is
  /// what keeps Tier I relevant instead of making the whole game "stand still".
  final double fireRate;

  final int bonusPierce;

  /// Tier III guarantees an elemental application and widens the hitbox.
  bool get guaranteesElementProc => this == DrawTier.three;

  double get hitboxScale => this == DrawTier.three ? 1.5 : 1.0;
}

/// Draw and Momentum state for one combatant.
///
/// **This is the most important object in the game.** It encodes the trade the
/// whole design rests on: standing still ramps damage through [DrawTier];
/// moving builds [momentumStacks], which grant speed and mitigation. Both states
/// are rewarded, so the player is choosing between two *good* options every
/// couple of seconds rather than between a good one and a loss.
///
/// That inversion is the central difference from Archero, where standing still
/// is simply correct — see docs/01-vision.md §1.4 (USP 1).
///
/// A class rather than arrays because there are very few of these: the player,
/// and later the Hollow Warden (docs/06 §6.1, boss 4) which mirrors the
/// player's kit and therefore needs its own instance.
class DrawState {
  DrawState({this.maxMomentum = baseMaxMomentum});

  // ── Draw thresholds, from docs/01 §1.1 ────────────────────────────────────
  static const double tierTwoAt = 0.45;
  static const double tierThreeAt = 1.10;

  // ── Momentum, from docs/01 §1.1 ───────────────────────────────────────────
  static const int baseMaxMomentum = 5;
  static const double secondsPerMomentumStack = 0.35;

  /// All stacks are lost this long after stopping — not decayed one at a time.
  /// An all-or-nothing cliff makes the trade legible: the player can feel
  /// exactly when they have spent their Momentum.
  static const double momentumGraceSeconds = 0.6;

  static const double moveSpeedPerStack = 0.03;
  static const double damageReductionPerStack = 0.02;

  /// Seconds held stationary. Reset to zero the instant the player moves.
  double drawSeconds = 0;

  /// Raised by the Spire's *Momentum Mastery* node and by Boons.
  int maxMomentum;

  int momentumStacks = 0;

  /// Progress toward the next stack while moving.
  double momentumChargeSeconds = 0;

  /// Time since the player stopped. Stacks drop when this passes
  /// [momentumGraceSeconds].
  double sinceStoppedSeconds = 0;

  bool wasMovingLastTick = false;

  /// Multiplier on the time needed to reach each tier.
  ///
  /// Below 1.0 means faster. Kestrel's *Hummingbird* passive sets 0.70, and the
  /// Spire's *Quickdraw* node reduces it further.
  double drawSpeedMultiplier = 1.0;

  /// Suppresses tier gain entirely — the Screecher's Draw-lock and Silversong's
  /// phase 3 (docs/05 §5.4, docs/06 §6.1). Momentum still works, which is
  /// precisely why Momentum builds exist as a genuine alternative rather than a
  /// fallback.
  double drawLockRemaining = 0;

  bool get isDrawLocked => drawLockRemaining > 0;

  DrawTier get tier {
    if (drawSeconds >= tierThreeAt * drawSpeedMultiplier) return DrawTier.three;
    if (drawSeconds >= tierTwoAt * drawSpeedMultiplier) return DrawTier.two;
    return DrawTier.one;
  }

  /// Fill fraction of the current tier, in `[0, 1)`. Drives the Draw arc around
  /// the player's feet.
  double get tierProgress {
    final double t2 = tierTwoAt * drawSpeedMultiplier;
    final double t3 = tierThreeAt * drawSpeedMultiplier;
    if (drawSeconds >= t3) return 1.0;
    if (drawSeconds >= t2) return (drawSeconds - t2) / (t3 - t2);
    return drawSeconds / t2;
  }

  double get moveSpeedBonus => momentumStacks * moveSpeedPerStack;

  double get damageReduction => momentumStacks * damageReductionPerStack;

  bool get isAtMaxMomentum => momentumStacks >= maxMomentum;

  void reset() {
    drawSeconds = 0;
    momentumStacks = 0;
    momentumChargeSeconds = 0;
    sinceStoppedSeconds = 0;
    wasMovingLastTick = false;
    drawLockRemaining = 0;
  }

  void applyDrawLock(double seconds) {
    if (seconds > drawLockRemaining) drawLockRemaining = seconds;
    drawSeconds = 0;
  }
}
