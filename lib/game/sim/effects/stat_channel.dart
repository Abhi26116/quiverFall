/// Every numeric quantity a Boon, Spire node, or piece of gear may move.
///
/// **The point of this enum is that 112 Boons are mostly data.** A Boon that
/// says "+8 % damage" is one channel and one number; it needs no code, no
/// switch arm, and no test beyond "the number arrived". That is what makes a
/// catalogue this size tractable — see [BoonBehaviour] for the minority that
/// genuinely need logic.
///
/// **Additive within a source, multiplicative across sources** (docs/04 §4.1
/// rule 1). Everything here sums into one term per channel. Two copies of
/// *Sharpened Points* give +16 %, not +16.64 %, and that is deliberate: it is
/// the rule that stops a twenty-Boon run producing a five-figure multiplier.
///
/// Order is a storage contract. [BoonStats] indexes a `Float64List` by
/// `channel.index`, and `boons.json` refers to channels by *name*, so channels
/// may be appended freely but never reordered or removed without a migration.
enum StatChannel {
  // ── Offence ───────────────────────────────────────────────────────────────

  /// Feeds `DamageResolver.boonDamageSum` directly. The unconditional term.
  damage,

  critChance,

  /// Added to `DamageResolver.baseCritMultiplier`'s bonus part, so +15 % takes
  /// a 1.80x crit to 1.95x rather than to 2.07x.
  critDamage,

  fireRate,

  /// Multiplier on `DrawTier.three.damageMultiplier`, clamped by
  /// `DamageResolver.maxDrawTierMultiplier` like every other draw term.
  tierThreeDamage,

  /// *Overdraw* pays for its Tier III bonus here. Negative values are normal.
  tierOneDamage,

  /// Arrows added to the base shot. Each arrow's damage is scaled by
  /// [splitDamagePenalty], which is how Split Shot and Twin Nock stay honest.
  extraArrows,

  /// Summed with [extraArrows]' penalties. Always negative in practice.
  splitDamagePenalty,

  pierce,

  projectileSpeed,

  /// Fraction of the arrow's own hitbox radius. *Wide Nock*, and Tier III's
  /// 1.5x, are the other two contributors.
  arrowRadius,

  // ── Conditional offence ───────────────────────────────────────────────────
  // Each of these is a separate channel rather than a flag on [damage] because
  // the condition is evaluated per hit, and a hit that fails the condition must
  // not pay for the bonus. They are summed into `boonDamageSum` at resolve
  // time, so they still obey rule 1 against each other.

  /// Target below 50 % HP. *Barbed Tips*.
  damageVsWounded,

  /// Target below 25 % HP. *Executioner*.
  damageVsDying,

  /// The player has not moved this tick. *Steady Aim*.
  damageWhileStationary,

  /// The same enemy the previous arrow struck. *Follow Through*.
  damageVsLastHit,

  /// Target is burning, poisoned or frozen. *Bloodgroove*.
  damageVsAfflicted,

  /// Target has a live plate or shield. *Siege Draw*.
  damageVsArmoured,

  /// Per consecutive hit without a miss. *Crescendo*.
  damagePerHitStreak,

  /// Ceiling on [damagePerHitStreak]'s accumulated total.
  damagePerHitStreakCap,

  /// Per world unit between shooter and target. *Marksman*.
  damagePerDistance,

  /// Ceiling on [damagePerDistance]'s accumulated total.
  damagePerDistanceCap,

  /// Per live Momentum stack. *Slipstream*.
  damagePerMomentum,

  /// For a short window after covering ground. *Kiting*.
  damageAfterMoving,

  /// Armour removed per hit, and the floor it converges to. *Rend*.
  armourShredPerHit,
  armourShredMax,

  // ── Defence ───────────────────────────────────────────────────────────────

  maxHealth,

  /// One contributor to the multiplicative DR product. Never summed with the
  /// others into a single subtraction — see `DamageResolver`'s
  /// `applyDamageReduction`, and docs/04 §4.1 rule 2.
  damageReduction,

  /// Applies only while the player is not moving. *Bulwark Stance*.
  damageReductionStationary,

  /// Fraction of max HP restored when a room ends.
  healOnRoomClear,

  /// Fraction of contact damage returned to the toucher.
  thornsReflect,

  /// Fraction of damage dealt returned as healing.
  lifesteal,

  /// Shield, as a fraction of max HP, per live Momentum stack.
  shieldPerMomentum,

  /// Reduction applied to elemental damage only, before general DR.
  elementalResist,

  /// Fraction of max HP per second, while moving.
  regenWhileMoving,

  /// Multiplier on incoming damage. *Hollow Bones* pays for its speed here.
  damageTakenMultiplier,

  // ── Mobility & Momentum ───────────────────────────────────────────────────

  moveSpeed,

  maxMomentum,

  /// Scales `DrawState.momentumGraceSeconds`. Above 1.0 means slower decay.
  momentumDecayRate,

  /// Scales `DrawState.secondsPerMomentumStack`. Above 1.0 means faster build.
  momentumBuildRate,

  /// Scales `DrawState.drawSpeedMultiplier`. Below 1.0 means a faster Draw.
  drawSpeed,

  // ── Windline & Confluence ─────────────────────────────────────────────────

  /// Seconds, added to `SimWorld.windlineDuration`.
  windlineDuration,

  /// Fraction, added to `SimWorld.windlineHitWidth`. The accessibility lever on
  /// the whole mechanic.
  windlineWidth,

  /// Added to `SimWorld.maxConfluenceStacks`, then clamped to the table in
  /// `ConfluenceTuning.bonusByStacks`.
  confluenceStacks,

  /// Scales the Confluence bonus. Clamped by
  /// `DamageResolver.maxConfluenceBonus` like every other Confluence term.
  confluenceDamage,

  /// Free stacks every arrow starts with. *Weaver's Grace*.
  confluenceHeadStart,

  /// Movement penalty applied to enemies standing on a Windline.
  windlineSlow,

  /// Fraction of an enemy's max HP per second, while it stands on a line.
  windlineDamage,

  // ── Elemental ─────────────────────────────────────────────────────────────

  emberDamage,
  frostEffect,
  stormDamage,
  toxinDamage,

  /// Applies to all four at once. *Attunement* writes to a single element
  /// instead; this is the Spire's *Elemental Focus* and set bonuses.
  allElementDamage,

  /// Damage of elemental reactions specifically, not of the elements.
  reactionDamage,

  /// Seconds added to a freeze.
  freezeDuration,

  /// Extra targets a Storm arc jumps to.
  stormChainTargets,

  /// Ceiling on Toxin stacks.
  toxinMaxStacks,

  // ── Economy & utility ─────────────────────────────────────────────────────

  goldMultiplier,
  materialMultiplier,
  shardDropRate,

  /// Chance of a fourth card in a Boon draw. *Curator* sets a count instead.
  fourthCardChance,

  /// Cards offered per draw, above the base 3.
  boonCardCount,

  /// Rerolls granted for the whole run.
  boonRerolls,

  /// Fraction off Shrine prices.
  shrineDiscount,

  /// Additive weight bonus toward Rare and above.
  rarePlusWeight,

  /// Insight granted per elite killed.
  insightPerElite,

  /// Vigor refunded when a run completes.
  vigorRefund;

  /// Channels whose natural resting value is 1.0 rather than 0.0.
  ///
  /// Most channels are bonuses that start at zero and are read as `1 + sum`.
  /// A few are outright multipliers where "no Boons" must mean 1.0, and reading
  /// those as `1 + sum` would double them. [BoonStats.multiplierFor] handles
  /// the distinction so no caller has to remember which is which.
  bool get isMultiplicative =>
      this == momentumDecayRate ||
      this == momentumBuildRate ||
      this == drawSpeed ||
      this == damageTakenMultiplier;

  /// Channels that hold a count, not a fraction. Rounded, never interpolated.
  bool get isIntegral =>
      this == extraArrows ||
      this == pierce ||
      this == maxMomentum ||
      this == confluenceStacks ||
      this == confluenceHeadStart ||
      this == stormChainTargets ||
      this == toxinMaxStacks ||
      this == boonCardCount ||
      this == boonRerolls ||
      this == insightPerElite ||
      this == vigorRefund;
}
