/// The hero passives, ultimates, and talent branches that change a rule
/// rather than a number.
///
/// The Boon-side split applies here too, and for the same reason: a talent
/// branch that says "+10 % move speed" is one [StatModifier] and needs no
/// entry here. This enum exists only for the minority — here, the majority —
/// that change *how a rule works*: Wren's homing, Bram's splash, Torv's
/// Windline-travelling chains, each a switch arm somewhere in the simulation.
///
/// **Deliberately a closed list**, for the same reason [BoonBehaviour] is:
/// every entry costs a branch in a hot path, and a hero kit that needs
/// behaviour not on this list needs a design conversation about what the kit
/// actually does, not an ad-hoc flag.
///
/// **Talent variants get their own entry rather than a shared parameter.** A
/// node like Bram's T1 — *Wider Blast* (radius 2.2 u) vs *Denser Blast*
/// (65 % splash, radius 1.2 u) — could instead be modelled as named numeric
/// fields on a hero-specific runtime, swapped at loadout time. That would be
/// less enum, but it would mean two different mechanisms for "which variant
/// of this ability is active" depending on whether the variant happens to be
/// expressible as a plain number — and the split between the two is not
/// obvious from the card text. One flag per variant, checked by the ability's
/// own implementation, is more entries but exactly one mechanism.
///
/// Grouped by hero rather than by shape — unlike Boons, which are catalogue
/// entries any run might hold in any combination, exactly one hero is ever
/// equipped at a time, so there is no cross-hero interaction to reason about
/// and no benefit to grouping by mechanic instead.
///
/// Names are the storage contract with `heroes.json`. Append freely, rename
/// never.
enum HeroBehaviour {
  // ── 1 · Wren, the First Warden · Generalist ──────────────────────────────

  /// Trueshot: Tier III shots gain mild homing (12°) onto a moving target.
  wrenTrueshot,

  /// Volley Fan: 7 arrows in a 90° arc, 80 % each, each laying a full
  /// Windline.
  wrenVolleyFan,

  /// T3a Wide Fan: the Ultimate widens to 11 arrows at 60 % each.
  wrenWideFan,

  /// T3b Focused Fan: the Ultimate narrows to 3 arrows at 220 %, pierce 3.
  wrenFocusedFan,

  /// T5a Warden's Lattice: the Ultimate's Windlines last 4 s.
  wrenWardensLattice,

  /// T5b Warden's Fury: the Ultimate refunds 30 % charge per kill.
  wrenWardensFury,

  // ── 2 · Bram, the Siegewright · Area damage ──────────────────────────────

  /// Heavy Ordnance: arrows detonate for splash damage. Splash never applies
  /// elements — it would trivialise every elemental interaction otherwise.
  bramHeavyOrdnance,

  /// Mortar Rain: shells land over time across the arena, telegraphed.
  bramMortarRain,

  /// T1a Wider Blast: splash radius widens to 2.2 u.
  bramWiderBlast,

  /// T1b Denser Blast: splash rises to 65 % in a tighter 1.2 u.
  bramDenserBlast,

  /// T3a Concussion: splash staggers Rush-family enemies.
  bramConcussion,

  /// T3b Incendiary: splash applies Burn.
  bramIncendiary,

  /// T5a Saturation: Mortar Rain becomes 20 shells.
  bramSaturation,

  /// T5b Precision Strike: Mortar Rain becomes 4 shells, 500 %,
  /// boss-seeking.
  bramPrecisionStrike,

  // ── 3 · Kestrel, the Quickstring · Speed ─────────────────────────────────
  // Her passive, Hummingbird, is +25 % fire rate, -15 % damage, and the Draw
  // running 30 % faster — three existing StatChannels, no behaviour needed.

  /// Flurry: 4 s of x3 fire rate at forced Tier III; movement no longer drops
  /// the tier for the duration.
  kestrelFlurry,

  /// T1b Sharper Nock: Hummingbird's -15 % penalty is waived at Tier III.
  kestrelSharperNock,

  /// T3b Bleed: every 4th arrow applies a 3 s bleed.
  kestrelBleed,

  /// T5a Endless Flurry: Flurry becomes 7 s at x2.2 rate.
  kestrelEndlessFlurry,

  /// T5b Perfect Flurry: Flurry becomes 3 s at x3 rate, +100 % Confluence
  /// damage.
  kestrelPerfectFlurry,

  // ── 4 · Ovrin, the Bulwark · Tank ─────────────────────────────────────────
  // His passive, Aegis, is +55 % max HP and a per-Momentum-stack shield —
  // both existing StatChannels (maxHealth, shieldPerMomentum), reusing the
  // exact mechanism Shieldweave (#33) already built.

  /// Aegis Pin: a wall that blocks enemy projectiles and reflects a share of
  /// what it blocks as Storm damage.
  ovrinAegisPin,

  /// T3b Riposte: a shield breaking deals an AoE burst.
  ovrinRiposte,

  /// T5a Long Wall: Aegis Pin lasts 10 s.
  ovrinLongWall,

  /// T5b Mirror Wall: Aegis Pin reflects 100 % for a shorter 3 s.
  ovrinMirrorWall,

  // ── 5 · Kade, the Emberhand · Ember ───────────────────────────────────────

  /// Kindling: Tier III arrows apply Burn, without needing an Ember arrow.
  kadeKindling,

  /// Pyre Line: a burning wall along the aim vector — area denial and a
  /// standing Windline at once.
  kadePyreLine,

  /// T1a Hot Iron: Kindling's Burn also applies at Tier II.
  kadeHotIron,

  /// T1b Deep Burn: Burn rises to 6 %/s, Tier III only.
  kadeDeepBurn,

  /// T3a Wildfire: Burn spreads to one nearby enemy on death.
  kadeWildfire,

  /// T3b Slow Burn: Burn lasts 8 s and stacks to 3.
  kadeSlowBurn,

  /// T5a Long Pyre: Pyre Line lasts 14 s.
  kadeLongPyre,

  /// T5b Twin Pyre: two crossed walls, an instant Confluence intersection.
  kadeTwinPyre,

  // ── 6 · Sela, the Rimebound · Frost ───────────────────────────────────────

  /// Chill: every hit stacks Chill; at the cap the target freezes and takes
  /// bonus damage while frozen.
  selaChill,

  /// Glacier Nail: an AoE freeze at the target.
  selaGlacierNail,

  /// T1a Deeper Chill: Chill rises to 16 per hit.
  selaDeeperChill,

  /// T1b Brittle: frozen targets take +45 % instead of +30 %.
  selaBrittle,

  /// T3a Shatter: killing a frozen enemy detonates for AoE.
  selaShatter,

  /// T3b Lingering Frost: a frozen enemy leaves a slow field on death.
  selaLingeringFrost,

  /// T5a Absolute Zero: Glacier Nail becomes 5 s, 5 u.
  selaAbsoluteZero,

  /// T5b Cascading Nail: Glacier Nail's freeze chains to 3 more enemies.
  selaCascadingNail,

  // ── 7 · Torv, the Stormcalled · Storm ─────────────────────────────────────
  // The first hero kit to need chain-hit infrastructure, which nothing before
  // it — not even Forked Arc (#85) or Stormfoot (#57) — had built yet.

  /// Arc: periodic arrows chain, travelling along live Windlines to extend
  /// their reach.
  torvArc,

  /// Tempest Nock: every arrow chains, for a window.
  torvTempestNock,

  /// T1a Frequent Arc: Arc triggers every 3rd arrow instead of every 5th.
  torvFrequentArc,

  /// T1b Wide Arc: Arc chains to 5 targets instead of 3.
  torvWideArc,

  /// T3a Conductive Lines: chains travelling along Windlines deal +80 %.
  torvConductiveLines,

  /// T3b Overload: chain targets take +20 % damage for 4 s.
  torvOverload,

  /// T5a Long Tempest: Tempest Nock lasts 8 s.
  torvLongTempest,

  /// T5b Thunderhead: Tempest Nock also stuns per chain link.
  torvThunderhead,

  // ── 8 · Sable, the Wither · Toxin ─────────────────────────────────────────

  /// Toxin: hits stack Toxin, ticking off enemy max HP and reducing healing,
  /// without needing a Toxin arrow.
  sableToxin,

  /// Miasma: a standing cloud applying Toxin stacks over time.
  sableMiasma,

  /// T1a Virulence: the Toxin cap rises to 12.
  sableVirulence,

  /// T1b Fast Acting: stacks apply at 2x speed, capped at 8.
  sableFastActing,

  /// T3a Contagion: on death, half of a target's stacks jump to the nearest
  /// enemy.
  sableContagion,

  /// T3b Corrosion: each Toxin stack also reduces enemy damage.
  sableCorrosion,

  /// T5a Lasting Miasma: Miasma lasts 14 s.
  sableLastingMiasma,

  /// T5b Concentrated Miasma: Miasma shrinks to 3 u but applies 5 stacks/s.
  sableConcentratedMiasma,

  // ── 9 · Lira, the Verdant · Sustain ───────────────────────────────────────

  /// Lifebound: lifesteal, with a further bonus while at Tier III — the one
  /// part that reads the Draw and needs a conditional check rather than a
  /// flat channel.
  liraLifebound,

  /// Verdant Bloom: a burst heal plus a damage buff for its duration.
  liraVerdantBloom,

  /// T1a Deep Roots: Lifebound's base lifesteal rises to 6 %.
  liraDeepRoots,

  /// T3a Overheal: healing past full becomes a shield.
  liraOverheal,

  /// T5a Endless Bloom: Verdant Bloom becomes 8 s at 60 % healing.
  liraEndlessBloom,

  /// T5b Blood Bloom: Verdant Bloom converts its heal into +80 % damage
  /// instead.
  liraBloodBloom,

  // ── 10 · Corvin, the Caroms · Ricochet ────────────────────────────────────

  /// Bounce: arrows ricochet once, and the ricochet lays its own Windline.
  corvinBounce,

  /// Caroms: arrows ricochet repeatedly for a window.
  corvinCaroms,

  /// T1a True Bounce: ricochets seek the nearest enemy instead of continuing
  /// straight.
  corvinTrueBounce,

  /// T1b Hard Bounce: a ricochet deals 120 % instead of 100 %.
  corvinHardBounce,

  /// T3b Double Bounce: arrows ricochet twice by default.
  corvinDoubleBounce,

  /// T5a Endless Carom: Caroms lasts 10 s instead of 6.
  corvinEndlessCarom,

  /// T5b Perfect Carom: during Caroms, ricochets never lose damage.
  corvinPerfectCarom,

  // ── 11 · Vane, the Longsight · Sniper ─────────────────────────────────────

  /// Distance: damage scales with range to target, with a close-range
  /// penalty below a threshold.
  vaneDistance,

  /// Piercing Horizon: a full-width, infinite-pierce lance across the arena.
  vanePiercingHorizon,

  /// T1a Farsight: Distance's cap rises to +130 %.
  vaneFarsight,

  /// T1b Steady: the close-range penalty is removed entirely.
  vaneSteady,

  /// T3a Marked: enemies hit beyond 8 u take +25 % for 5 s.
  vaneMarked,

  /// T5a Twin Horizon: two lances at 90°, an instant Confluence cross.
  vaneTwinHorizon,

  /// T5b Sundering Horizon: one lance at 1,400 % instead of two at 600 %.
  vaneSunderingHorizon,

  // ── 12 · Thane, the Bloodtide · Berserker ─────────────────────────────────

  /// Bloodtide: damage scales with missing HP, with a healing cap that keeps
  /// the trade real.
  thaneBloodtide,

  /// Red Draw: spends current HP for a burst of damage and fire rate.
  thaneRedDraw,

  /// T1a Deeper Tide: Bloodtide's cap rises to +120 %.
  thaneDeeperTide,

  /// T1b Tempered: the healing cap rises to 90 %.
  thaneTempered,

  /// T3a Last Stand: below a quarter HP, damage reduction rises.
  thaneLastStand,

  /// T3b Frenzy: below a quarter HP, fire rate rises.
  thaneFrenzy,

  /// T5a Long Red: Red Draw lasts 10 s instead of 6.
  thaneLongRed,

  /// T5b Crimson Draw: Red Draw also forces every shot to Tier III.
  thaneCrimsonDraw,

  // ── 13 · Nyx, the Umbral · Assassin ───────────────────────────────────────

  /// First Blood: bonus damage to full-HP targets; a kill grants a brief
  /// speed burst.
  nyxFirstBlood,

  /// Umbral Step: teleport to the furthest enemy, brief untargetability, then
  /// guaranteed crits.
  nyxUmbralStep,

  /// T1a Executioner's Eye: First Blood's bonus also applies below 20 % HP.
  nyxExecutionersEye,

  /// T1b Deeper Shadow: Umbral Step's untargetable window extends to 2.5 s.
  nyxDeeperShadow,

  /// T3a Shadowline: Windlines laid while untargetable still deal damage.
  nyxShadowline,

  /// T3b Chain Kill: First Blood's kill speed buff stacks up to 3 times.
  nyxChainKill,

  /// T5a Twin Step: Umbral Step gains a second charge.
  nyxTwinStep,

  /// T5b Perfect Step: Step's guaranteed shots become one hit at 600 %
  /// instead of three at 300 %.
  nyxPerfectStep,

  // ── 14 · Iris, the Latticeweaver · Confluence specialist ─────────────────
  // Weave's numbers (Windline duration to 2.6 s, Confluence cap to 5) are
  // existing StatChannels; only the 5th-stack AoE needs code.

  /// Weave: the 5th Confluence stack detonates a small AoE, on top of its
  /// already-raised damage bonus.
  irisWeave,

  /// The Lattice: instantly draws a persistent web of lines across the arena;
  /// every shot through it resolves at maximum Confluence.
  irisTheLattice,

  /// T5a Grand Lattice: the Lattice becomes 10 lines and lasts 16 s.
  irisGrandLattice,

  /// T5b Living Lattice: the Lattice follows the player instead of staying
  /// fixed.
  irisLivingLattice,

  // ── 15 · Zea, the Falconer · Summoner ─────────────────────────────────────
  // The first kit to need a companion entity — something that exists, moves,
  // and attacks independently of the player.

  /// Skyhawk: a companion that attacks independently and lays its own
  /// Windlines.
  zeaSkyhawk,

  /// Falconry: summons a flock of hawks for a window.
  zeaFalconry,

  /// T1a Sharper Talons: the hawk's damage share rises to 50 % of hero ATK.
  zeaSharperTalons,

  /// T1b Swift Hawk: the hawk's attack rate rises to 2.4/s.
  zeaSwiftHawk,

  /// T3a Bonded: the hawk crits whenever the player is at Tier III.
  zeaBonded,

  /// T3b Flock: two permanent hawks at a reduced 25 % share each, instead of
  /// one at 35 %.
  zeaFlock,

  /// T5a Skydarken: Falconry summons 8 hawks instead of 4.
  zeaSkydarken,

  /// T5b Great Hawk: one much stronger hawk that taunts, replacing the flock.
  zeaGreatHawk,

  // ── 16 · Rook, the Gravebinder · Control ──────────────────────────────────
  // The first kit to need a pull — displacing an enemy toward a point, the
  // inverse of what a dash does to the player.

  /// Pull: crits pull the target, and grouped enemies take bonus damage each.
  rookPull,

  /// Singularity: a well that pulls everything in range, then detonates.
  rookSingularity,

  /// T1a Stronger Pull: Pull's displacement rises to 2.0 u.
  rookStrongerPull,

  /// T1b Denser Grouping: the per-enemy grouping bonus rises to +18 %.
  rookDenserGrouping,

  /// T3a Crush: grouped enemies take stacking damage over time.
  rookCrush,

  /// T3b Anchor: pulled enemies are briefly rooted.
  rookAnchor,

  /// T5a Twin Singularity: Singularity summons two wells instead of one.
  rookTwinSingularity,

  /// T5b Collapsing Singularity: one well, 6 s, a much larger detonation.
  rookCollapsingSingularity,

  // ── 17 · Halden, the Judgement · Boss-killer ──────────────────────────────
  // Every behaviour on this hero reads an "is this a boss" flag the
  // simulation does not yet have — Phase 11 builds bosses. The *elite* half
  // of Verdict is reachable now; the boss half is not. Declared complete
  // regardless, so the catalogue is correct; see `pendingHeroWork`.

  /// Verdict: bonus damage to bosses and elites; reduced damage taken from
  /// boss attacks specifically.
  haldenVerdict,

  /// Judgment Spear: a single huge strike, stronger against a low-HP target.
  haldenJudgmentSpear,

  /// T1a Zealot: Verdict's boss damage bonus rises to +55 %.
  haldenZealot,

  /// T1b Warded: Verdict's boss damage taken reduction rises to -28 %.
  haldenWarded,

  /// T3a Sentence: the Spear marks its target for bonus damage taken.
  haldenSentence,

  /// T3b Swift Judgment: the Ultimate charges 40 % faster against bosses.
  haldenSwiftJudgment,

  /// T5a Final Verdict: below a quarter HP, the Spear becomes an execute.
  haldenFinalVerdict,

  /// T5b Twin Spear: two spears at 600 % each, instead of one at 900 %.
  haldenTwinSpear,

  // ── 18 · Ashlin, the Rekindled · Revival ──────────────────────────────────
  // Rekindle is the same shape Guardian Angel (#34) and Phoenix Heart (#40)
  // already are — prevent one death, once — extended with an AoE nova.

  /// Rekindle: once per run, lethal damage instead revives with a nova and
  /// brief invulnerability.
  ashlinRekindle,

  /// Rebirth Nova: an AoE burst, a heal, and a Rekindle refresh if already
  /// spent.
  ashlinRebirthNova,

  /// T1a Bright Rekindle: Rekindle revives at 70 % HP instead of 45 %.
  ashlinBrightRekindle,

  /// T1b Twice Kindled: Rekindle triggers twice, at 30 % HP each, instead of
  /// once at 45 %.
  ashlinTwiceKindled,

  /// T3a Ember Body: any room clear grants 3 s of invulnerability.
  ashlinEmberBody,

  /// T3b Phoenix Trail: that invulnerability window leaves a burning
  /// Windline behind.
  ashlinPhoenixTrail,

  /// T5a Eternal: Rebirth Nova's Rekindle refresh loses its cooldown.
  ashlinEternal,

  /// T5b Supernova: Rebirth Nova rises to 1,200 % but no longer refreshes
  /// Rekindle.
  ashlinSupernova,

  // ── 19 · Mirelle, the Mirrored · Duplication ──────────────────────────────
  // The first kit to need arrow duplication — spawning a new arrow from an
  // arrow, rather than only from the player.

  /// Reflection: arrows have a chance to duplicate, geometrically, up to a
  /// cap; duplicates lay their own Windlines.
  mirelleReflection,

  /// Hall of Mirrors: every arrow duplicates repeatedly, and a mirror clone
  /// of the player fights alongside.
  mirelleHallOfMirrors,

  /// T1a Truer Mirror: Reflection's duplicate chance rises to 35 %.
  mirelleTruerMirror,

  /// T1b Deeper Mirror: the duplicate cap rises to 6 arrows.
  mirelleDeeperMirror,

  /// T3a Silvered: duplicates deal 100 % instead of 85 %.
  mirelleSilvered,

  /// T3b Fractured: duplicates spread ±20° for wider coverage.
  mirelleFractured,

  /// T5a Endless Hall: Hall of Mirrors lasts 14 s instead of 8.
  mirelleEndlessHall,

  /// T5b Twin Warden: the mirror clone lasts the whole room at 80 % stats,
  /// instead of 8 s at 60 %.
  mirelleTwinWarden,

  // ── 20 · Oriel, the Prism · Elemental mastery ─────────────────────────────

  /// Spectrum: arrows cycle through all four elements, one per shot — built
  /// for Confluence to merge constantly.
  orielSpectrum,

  /// Prism: every arrow carries all four elements at once, for a window.
  orielPrism,

  /// T1a Faster Cycle: Spectrum keeps cycling even through a Tier III
  /// multishot.
  orielFasterCycle,

  /// T3b Saturation: elements persist twice as long on enemies.
  orielSaturation,

  /// T5a Endless Prism: Prism lasts 16 s instead of 10.
  orielEndlessPrism,

  /// T5b White Light: Prism shrinks to 6 s but reactions deal x3.
  orielWhiteLight;
}
