/// Cross-cutting enemy and AI constants.
///
/// **The split with `assets/data/enemies.json` is deliberate.** The JSON table
/// holds the shared stat vocabulary every enemy speaks — HP, speed, damage,
/// ranges, cadences — because those are what live-ops retunes through the
/// remote-config overlay. This file holds the numbers that describe *how a
/// behaviour is shaped* rather than how strong it is: flocking weights, the
/// Wisp's oscillation, the Ripper's stagger threshold. Those are shape, not
/// balance, and shipping them as remote-tunable data would let a config change
/// alter what an enemy fundamentally does.
///
/// Nothing in `game/sim/ai/` may declare a magic number — the balance harness
/// (Phase 12) sweeps these, and a constant buried in a behaviour tree is a
/// constant nobody can tune.
abstract final class EnemyTuning {
  // ── Spawning ──────────────────────────────────────────────────────────────

  /// No enemy may appear closer than this to the player (docs/05 §5.7). A
  /// spawn on top of the player is unavoidable damage, which is the one thing
  /// a fair action game may never do.
  static const double minSpawnDistanceFromPlayer = 3.5;

  /// Off-screen spawns are announced by an edge-flash at the spawn location
  /// this long before the enemy exists.
  static const double spawnTelegraphSeconds = 0.4;

  /// Attempts to find a legal spawn point before falling back to the furthest
  /// arena corner. Bounded because a spawn search must never be able to stall a
  /// tick, however pathological the room.
  static const int spawnPlacementAttempts = 24;

  /// A wave releases when the previous one is down to this share of its
  /// members, rather than waiting for a full clear. A completely empty arena
  /// between waves reads as the room being over.
  static const double waveReleaseThreshold = 0.35;

  /// Minimum seconds between waves, so two waves cannot land on one frame.
  static const double waveIntervalSeconds = 1.2;

  // ── Steering ──────────────────────────────────────────────────────────────

  /// Enemies push apart at this radius multiple of their own size, so a pack
  /// converging on the player spreads into a readable arc instead of stacking
  /// into one silhouette.
  static const double separationRadiusScale = 2.2;

  static const double separationWeight = 1.35;

  /// Flocking (Swarmling only), from docs/05 §5.1.
  static const double flockRadius = 1.2;
  static const double flockSeparationWeight = 1.6;
  static const double flockAlignmentWeight = 0.5;
  static const double flockCohesionWeight = 0.35;

  /// How many neighbours a flocking unit considers. The flock must read as one
  /// moving shape, and past a handful of neighbours the averages stop changing
  /// while the cost keeps rising.
  static const int flockMaxNeighbours = 8;

  /// Wisp oscillation: a genuine 2.4 Hz sine perpendicular to travel, not a
  /// random walk. The distinction matters — a random walk is unreadable and
  /// therefore unfair, whereas a sine can be predicted and led.
  static const double wispSineHz = 2.4;
  static const double wispSineAmplitude = 1.5;

  /// Kiters hold their stand-off within this band before correcting, so they
  /// do not jitter forward and back on the boundary.
  static const double keepDistanceTolerance = 0.6;

  // ── Contact ───────────────────────────────────────────────────────────────

  /// Slack added to the touching test, so a graze registers rather than
  /// requiring exact circle overlap on a 60 Hz sample.
  static const double contactSlack = 0.06;

  // ── Windline slow ─────────────────────────────────────────────────────────

  /// Once slowed, an enemy stays slowed this long after leaving the line, so
  /// the effect is legible instead of flickering on and off frame by frame.
  static const double windlineSlowLinger = 0.25;

  // ── Sela: Lingering Frost ─────────────────────────────────────────────────

  /// Sela's own *Lingering Frost* (T3b) — "frozen enemies leave a slow
  /// field." docs/07 states the field's own 3 s duration but no magnitude;
  /// authored fresh here rather than reusing the ambient
  /// `SimConfig.windlineSlow` (8%, deliberately small since it applies
  /// everywhere a Windline exists, all the time) — this is a rare, targeted
  /// zone that only exists near a freshly-frozen enemy, so a heavier number
  /// reads as the dedicated crowd-control pick a T3 talent is meant to be.
  static const double lingeringFrostSlow = 0.30;

  // ── Carapace ──────────────────────────────────────────────────────────────

  /// Fraction of an enemy's max HP the plate absorbs before breaking. Damage
  /// past the plate is what reduces it, so a Tier-I plinker chips it down
  /// eventually — slowly, which is the lesson.
  static const double plateHealthFraction = 0.45;

  /// Ironmaw's enrage, from docs/05 §5.2. The plate seams flood crimson 0.4 s
  /// *before* the speed change: the telegraph precedes the threat, always.
  static const double enrageSpeedMultiplier = 2.8;

  // ── Rush ──────────────────────────────────────────────────────────────────

  /// A Ripper staggers if it takes more than this share of its max HP during
  /// the third wind-up. This is the game's parry, and it has no button.
  static const double ripperStaggerFraction = 0.08;

  static const double ripperStaggerSeconds = 1.1;

  /// Number of swings in the Ripper's combo. The last one is the tell.
  static const int ripperComboLength = 3;

  /// Arc of a Ripper swing, in degrees. Wide enough that backing straight off
  /// does not beat it — sidestepping does, which is the movement the enemy is
  /// teaching.
  static const double ripperSwingArcDegrees = 100.0;

  /// Fraction of the combo's damage the first two swings deal. The third is the
  /// authored `attackDamage`; the openers are chip.
  static const double ripperOpenerFraction = 0.36;

  /// The rear arc a Stalker must reach before it will lunge, in degrees.
  /// Turning to face it is the entire counter-play.
  static const double stalkerRearArcDegrees = 120.0;

  /// How far around the player a Stalker slides per second while it hunts for
  /// that rear arc, as a fraction of its speed.
  static const double stalkerOrbitBias = 0.75;

  // ── Salvo ─────────────────────────────────────────────────────────────────

  /// Radius of the triangle a Mortarite lays around the player's *predicted*
  /// position. Keeping moving beats it, because prediction always leads.
  static const double mortariteTriangleRadius = 1.35;

  /// Hitbox of an enemy bolt. Generous enough to read at phone size, small
  /// enough that strafing perpendicular to a Nettle spread actually works.
  static const double boltRadius = 0.18;

  /// Seconds ahead a Mortarite predicts. Equal to its shell flight time would
  /// make it unmissable; less makes a direction change beat it, which is the
  /// counter-play the enemy exists to teach.
  static const double mortaritePredictionSeconds = 0.85;

  // ── Choir ─────────────────────────────────────────────────────────────────

  /// A Weaver will not re-shield an ally it has already shielded until the
  /// shield has been down for this long (its `attackCooldown` in the table
  /// carries the authored value; this is the floor).
  static const double weaverMinReapplySeconds = 0.5;

  // ── Riftborn ──────────────────────────────────────────────────────────────

  /// Radius of the ring a Rift Maw places its adds on. Far enough out that the
  /// tear itself stays shootable, close enough that "burn the Maw, ignore the
  /// adds" is a real option rather than a slogan.
  static const double riftMawSpawnRadius = 1.4;

  /// A Gravebound's corpse is killable during the revive window by any AoE.
  /// Ember burn applied at death consumes it outright.
  static const double graveboundCorpseRadiusScale = 0.8;

  /// The Echo mirrors the player's position about the arena centre. This is how
  /// hard it corrects toward that mirrored point, in multiples of its speed —
  /// below 1.0 so it lags visibly, which is what makes walking it into your own
  /// Windlines possible.
  static const double echoMirrorGain = 0.9;
}

/// Late-campaign recombinations of the base 26 (docs/05 §5.8).
///
/// Chapters 9–12 introduce no new base types. Instead, variants multiply the
/// existing roster into ~104 effective encounters with no new art — which is
/// the only affordable way to keep the late game novel in a project with a
/// ~4,000-sprite budget.
enum EnemyVariant {
  none(),
  frenzied(speedBonus: 0.60),
  bloated(healthBonus: 1.20),

  /// Immune to one element, chosen at spawn from the run's seed.
  voidtouched(),

  /// Splits into two half-strength copies on death.
  twinned();

  const EnemyVariant({this.speedBonus = 0, this.healthBonus = 0});

  final double speedBonus;
  final double healthBonus;

  /// Health and threat share of each half a Twinned enemy leaves behind.
  static const double twinFraction = 0.45;

  /// Threat multiplier the composer pays for a variant. Variants are cheaper
  /// than a new enemy of equivalent power, which is what makes late rooms
  /// denser rather than merely tougher.
  double get threatMultiplier => switch (this) {
        EnemyVariant.none => 1.0,
        EnemyVariant.frenzied => 1.35,
        EnemyVariant.bloated => 1.45,
        EnemyVariant.voidtouched => 1.30,
        EnemyVariant.twinned => 1.55,
      };

  /// Variants appear from chapter 9 and never before it.
  static const int firstChapter = 9;
}
