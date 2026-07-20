/// The Boons that genuinely need code.
///
/// About sixty of the 112 are a channel and a number — [StatChannel] handles
/// those, and they need no entry here. The rest change *how a rule works*
/// rather than what a number is, and each one below is a switch arm somewhere
/// in the simulation.
///
/// **This enum is deliberately a closed list.** A Boon that needs behaviour not
/// on it is a Boon that needs a design conversation, not an ad-hoc flag: every
/// entry costs a branch in a hot path and a place where two Boons can interact
/// in ways the balance harness has to reason about.
///
/// Names are the storage contract with `boons.json`. Append freely, rename
/// never.
enum BoonBehaviour {
  // ── Offence ───────────────────────────────────────────────────────────────

  /// Armour shred persists per enemy and converges to a floor. Needs per-enemy
  /// state, so it cannot be a plain channel read.
  rend,

  /// Consecutive hits ramp damage; a miss resets it. Needs a streak counter and
  /// a definition of "miss" that survives multi-arrow volleys.
  crescendo,

  /// Crits gain pierce and skip the pierce-falloff curve entirely.
  deadeye,

  /// Every eighth arrow deals 400 %. A run-scoped counter, not a timer, so the
  /// player can feel it coming.
  hammerfall,

  /// Instantly kills non-elites below a HP fraction.
  cull,

  /// Tier III releases an extra fan of arrows at reduced damage.
  rainOfNocks,

  /// Every shot resolves as Tier III. The Draw meter still animates, because
  /// removing it would make the player think the mechanic broke.
  perfectForm,

  /// Arrows never despawn, never stop, and pierce without limit.
  theLongArrow,

  // ── Defence ───────────────────────────────────────────────────────────────

  /// Heals to full on pickup, once.
  vitalSurge,

  /// Survives one lethal hit at 1 HP, once per run.
  guardianAngel,

  /// Windlines block enemy projectiles. The only Boon that makes a Windline a
  /// defensive object, and the reason Windlines are in the projectile system's
  /// broadphase at all.
  wardingLine,

  /// Absorbs the next few hits outright; recharges each room.
  aegis,

  /// Revives once at a fraction of max HP.
  phoenixHeart,

  /// Part of incoming damage is deferred and dealt over time, cancelled by a
  /// kill.
  bloodPact,

  /// Invulnerable while at Tier III.
  immortalDraw,

  /// Invulnerable for the opening seconds of each room.
  covenant,

  /// No single hit may exceed a fraction of max HP.
  theUnbroken,

  // ── Mobility ──────────────────────────────────────────────────────────────

  /// Double-tap to dash.
  dash,

  /// Immune to slows and roots.
  windwalk,

  /// Dash becomes a two-charge teleport.
  blink,

  /// Momentum never decays inside a room.
  momentumEngine,

  /// Fire rate rises at max Momentum.
  runnersHigh,

  /// Dash grants brief invulnerability.
  ghostStep,

  /// At max Momentum, arrows chain.
  stormfoot,

  /// Draw and Momentum accrue together. Deletes the core trade-off, which is
  /// why it is Mythic and why it is the single most scrutinised card in the
  /// balance harness.
  perpetual,

  // ── Windline & Confluence ─────────────────────────────────────────────────

  /// Windlines survive a room transition.
  lingering,

  /// Confluence also applies the equipped element.
  crossbind,

  /// A Windline exists at the player's position when a room starts.
  anchorLine,

  /// A dying enemy leaves a short Windline.
  echoThread,

  /// Windlines drift toward the nearest enemy.
  livingThread,

  /// Each Confluence detonates a small area.
  resonantWeave,

  /// Windlines damage and blind whatever crosses them.
  sunthread,

  /// Windlines do not expire within a room.
  theLoom,

  /// Every shot is at maximum Confluence, at a flat damage cost.
  totalConfluence,

  // ── Elemental ─────────────────────────────────────────────────────────────

  /// Grants a random element to a player who has none.
  elementalTips,

  /// Burn spreads on death.
  wildfire,

  /// Reactions lose their cooldown and some of their damage.
  reactive,

  /// Boosts one chosen element. The choice is made at pickup and stored on the
  /// inventory, which is why this is behaviour rather than four channels.
  attunement,

  /// Periodically carries all four elements at once.
  elementalOverload,

  /// Carries Ember and Frost together.
  frostfire,

  /// Carries Storm and Toxin together.
  stormblight,

  /// All four elements on every arrow at reduced potency.
  theFourfold,

  /// Reactions chain to nearby enemies.
  prismbreak,

  // ── Economy ───────────────────────────────────────────────────────────────

  /// Reveals room contents and Boon rarities before entry.
  treasureSense,

  /// Arrows occasionally drop gold on hit.
  goldenArrow,

  // ── Cursed ────────────────────────────────────────────────────────────────

  /// Disables aim assist. The downside is the *point*, and it is stated on the
  /// card — docs/09 §9.2 G: a Cursed Boon that surprises the player is a broken
  /// promise.
  blindFury,

  /// Future Boons cost HP and arrive one rarity higher.
  bloodprice,

  /// Each room starts at low HP in exchange for damage.
  theBargain,

  /// A rare arrow deals enormous damage and stuns the player.
  quiverfall,

  // ── Evolutions ────────────────────────────────────────────────────────────
  // docs/09 §9.4. Reachable only mid-run, and only in later rooms, which is
  // what gives a long stage's back half a different texture from its front.

  /// Seven arrows, all of which lay Windlines.
  stormOfNocks,

  /// Windlines persist for the whole stage.
  eternalWeave,

  /// Lifesteal overheals into a shield.
  bloodwell,

  /// Moving leaves a damaging trail.
  windborn,

  /// Burn never expires.
  everburn,

  /// Every shot starts at max Confluence, with no penalty.
  firstLight,

  // ── Synergy set bonuses ───────────────────────────────────────────────────
  // docs/09 §9.3. Granted by holding three members of a set, never by a card,
  // which is why none of these appears in `boons.json` — the catalogue
  // validator would reject an unreachable behaviour, so the test that checks
  // for orphans exempts these explicitly.

  /// *The Furnace* — burn ignites the ground beneath the target.
  furnaceGround,

  /// *The Deep Winter* — frozen enemies shatter for an area hit.
  winterShatter,

  /// *The Conduit* — chains travel along Windlines at full damage.
  conduitChains,

  /// *The Rot* — Toxin stacks are never lost and transfer on death.
  rotPersists,

  /// *The Executioner* — crits below 30 % instantly kill non-elites.
  executionerCrits,

  /// *The Sacrifice* — every Cursed downside is halved.
  sacrificeHalved;

  /// Whether this behaviour fires once at pickup rather than during play.
  ///
  /// Pickup effects must not be re-applied when the loadout is recomposed
  /// between rooms — healing to full every room is a different, much stronger
  /// card than healing to full once.
  bool get isOneShotOnPickup =>
      this == vitalSurge || this == elementalTips || this == attunement;
}
