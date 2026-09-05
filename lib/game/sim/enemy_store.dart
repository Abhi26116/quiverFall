import 'dart:typed_data';

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/sim_config.dart';

/// Where an enemy is in its behaviour cycle.
///
/// Every enemy in the game runs this same nine-state machine; the family tree
/// decides which states it uses and what happens inside them. That uniformity
/// is what makes the telegraph rule enforceable — [windUp] is the only state
/// from which damage may be scheduled, so an attack without a wind-up is
/// structurally impossible rather than merely discouraged.
enum AiState {
  /// No player to chase, or deliberately dormant.
  idle,

  /// Closing on the player.
  seek,

  /// Holding a stand-off, orbiting, or retreating.
  reposition,

  /// Telegraphing. The attack is committed; the player is being told.
  windUp,

  /// Executing — a dash, a beam, a scream. Usually brief.
  attack,

  /// Vulnerable. The player's window, and the reason every heavy attack in the
  /// game is worth baiting.
  recover,

  /// Interrupted mid-wind-up. The Ripper's parry window resolves here.
  staggered,

  /// Mid-leap. Untargetable and immune to the Windline slow, which is the only
  /// time in the game auto-aim cannot help the player.
  airborne,

  /// A corpse awaiting revival. Killable in this window by any AoE.
  downed,
}

/// Per-enemy runtime state, indexed by entity slot.
///
/// Held apart from [EntityStore] for the same reason [ProjectileStore] is: most
/// entities are not enemies, and mixing rarely-touched arrays into the hot
/// component set costs the cache locality that struct-of-arrays exists to buy.
///
/// Everything here is *runtime* state. An enemy's *definition* — how fast it is,
/// what it does, what it costs — lives in the content table and is reached
/// through `EntityStore.contentIndex`.
class EnemyStore {
  EnemyStore({int capacity = SimConfig.maxEntities})
      : _capacity = capacity,
        state = Uint8List(capacity),
        stateTimer = Float64List(capacity),
        attackCooldown = Float64List(capacity),
        contactCooldown = Float64List(capacity),
        comboStep = Uint8List(capacity),
        damageDuringWindUp = Float64List(capacity),
        plateHealth = Float64List(capacity),
        plateHalfArc = Float64List(capacity),
        plateRegen = Float64List(capacity),
        plateJustBroke = Uint8List(capacity),
        plateFlatFactor = Float64List(capacity),
        adaptSeconds = Float64List(capacity),
        shield = Float64List(capacity),
        armourShred = Float64List(capacity),
        elite = Uint8List(capacity),
        windlineSlowFactor = Float64List(capacity),
        blindRemaining = Float64List(capacity),
        shieldedBy = Int32List(capacity),
        attackBuff = Float64List(capacity),
        elementSuppressed = Uint8List(capacity),
        immuneElement = Int8List(capacity),
        immuneRemaining = Float64List(capacity),
        revivesLeft = Uint8List(capacity),
        targetX = Float64List(capacity),
        targetY = Float64List(capacity),
        phase = Float64List(capacity),
        liveAdds = Int32List(capacity),
        spawnerSlot = Int32List(capacity),
        speedScale = Float64List(capacity),
        enrageRemaining = Float64List(capacity),
        slowRemaining = Float64List(capacity),
        untargetable = Uint8List(capacity),
        variant = Uint8List(capacity),
        telegraphSlot = Int32List(capacity),
        telegraphSerial = Int32List(capacity),
        markedRemaining = Float64List(capacity),
        bleedStacks = Uint8List(capacity),
        bleedRemaining = Float64List(capacity),
        bossIndex = Int32List(capacity),
        bossPhase = Uint8List(capacity),
        linkedHealthSlot = Int32List(capacity),
        bossChildIndex = Uint8List(capacity),
        bossTimer = Float64List(capacity),
        bossActiveChildIndex = Uint8List(capacity),
        bossSweepAngle = Float64List(capacity),
        bossParent = Int32List(capacity),
        bossLastHitAgo = Float64List(capacity),
        lastHitWasUltimate = Uint8List(capacity);

  final int _capacity;

  final Uint8List state;

  /// Seconds left in the current state. Counts down.
  final Float64List stateTimer;

  final Float64List attackCooldown;
  final Float64List contactCooldown;

  /// Which swing of a multi-hit combo is next.
  final Uint8List comboStep;

  /// Damage taken since the current wind-up began. The Ripper staggers when
  /// this passes [EnemyTuning.ripperStaggerFraction] of its max HP — the game's
  /// parry, expressed as a number rather than a button.
  final Float64List damageDuringWindUp;

  // ── Carapace ──────────────────────────────────────────────────────────────

  /// Remaining plate integrity, in HP. Zero means broken.
  final Float64List plateHealth;

  /// Half the plate's arc, in radians, cached from the definition at spawn.
  ///
  /// Cached rather than looked up because the projectile system tests it on
  /// every hit, and that is the hottest path in the game — it must not touch
  /// the content table.
  final Float64List plateHalfArc;

  /// Seconds until a broken plate returns. Shellback only, in the base roster.
  final Float64List plateRegen;

  /// One-shot latch: the plate broke since this enemy last acted.
  ///
  /// A latch rather than a state comparison because *two* archetypes react to
  /// the same instant in different ways — the Shellback retreats, the Ironmaw
  /// enrages — and both reactions must fire exactly once from a break that
  /// happens in the projectile system, several systems earlier in the tick.
  final Uint8List plateJustBroke;

  /// Overrides `_armourFor`'s own Tier I/II/III switch with one flat factor,
  /// applied regardless of Draw tier — 0 (the default) means "use the
  /// ordinary tiered plate". Every base-roster Carapace enemy leaves this at
  /// 0; Gaunt, the Iron Tide is the first consumer (docs/06 §2: "Frontal
  /// 180° arc takes 5% damage", stated with no Tier caveat at all, unlike
  /// Cinder Choir's own "Tier III breaks plate") — a shield meant to test
  /// *flanking*, not the Draw, must stay just as strong against a fully
  /// charged shot as a snap one. See ADR 0023.
  final Float64List plateFlatFactor;

  // ── Choir effects, recomputed every tick ──────────────────────────────────

  /// Absorbs damage before health does. Granted by a Weaver.
  final Float64List shield;

  /// How much of this enemy's armour *Rend* (#14) has worn away, as a fraction
  /// in [0, 1].
  ///
  /// Per enemy and persistent for its life, which is why Rend cannot be a plain
  /// stat channel: the shred belongs to the target, not to the build.
  final Float64List armourShred;

  /// Speed multiplier from standing on a Windline, in (0, 1].
  ///
  /// Reset to 1.0 every tick and re-applied by the Windline field pass, so it
  /// expires the moment the enemy steps off rather than needing its own timer.
  final Float64List windlineSlowFactor;

  /// Seconds this enemy cannot aim, from *Sunthread* (#73).
  final Float64List blindRemaining;

  /// Whether this enemy is an elite (the Riftborn family).
  ///
  /// Denormalised from the content table at spawn. The hit loop asks this
  /// question on every hit, and threading a [ContentLibrary] into the projectile
  /// system to answer it would drag content lookups onto the hottest path in
  /// the game.
  final Uint8List elite;

  /// Entity slot of the Weaver maintaining [shield], or -1. Kept so a Weaver
  /// does not double-shield and so the tether can be drawn — the tether is a
  /// bright cyan line pointing at the answer, which is the game *telling* the
  /// player what to kill.
  final Int32List shieldedBy;

  /// Additive attack bonus from Chanter auras. Recomputed from scratch each
  /// tick, so it disappears the instant the Chanter dies with no bookkeeping.
  final Float64List attackBuff;

  /// Inside a Warden-Fell aura: elemental *application* is suppressed.
  /// Confluence still works, and existing statuses are not stripped.
  final Uint8List elementSuppressed;

  // ── Riftborn ──────────────────────────────────────────────────────────────

  /// [SimElement] index this enemy is currently immune to, or -1.
  final Int8List immuneElement;

  /// Seconds of immunity left. [double.infinity] for the Voidtouched variant,
  /// whose immunity is permanent.
  final Float64List immuneRemaining;

  /// How long this enemy's adaptation lasts when something elemental hits it.
  /// Zero for everything except the Null — cached at spawn so the damage path
  /// can decide without a content lookup.
  final Float64List adaptSeconds;

  final Uint8List revivesLeft;

  // ── Steering scratch ──────────────────────────────────────────────────────

  /// Destination of a charge, a leap, or a shell. Fixed when the attack
  /// commits, never re-solved mid-flight.
  final Float64List targetX;
  final Float64List targetY;

  /// Free-running phase for oscillating and orbiting movement. Seeded per
  /// enemy at spawn so a pack of Wisps does not weave in lockstep.
  final Float64List phase;

  final Int32List liveAdds;

  /// Which summoner spawned this enemy, or -1. Lets a Rift Maw's cap fall as
  /// its adds die.
  final Int32List spawnerSlot;

  /// Multiplier on the definition's speed: enrage, variants, the Gravebound's
  /// post-revival haste.
  final Float64List speedScale;

  final Float64List enrageRemaining;

  /// Windline slow, held briefly after leaving the line so the effect is
  /// legible rather than flickering frame by frame.
  final Float64List slowRemaining;

  /// Auto-aim skips these. Airborne Bounders and Gravebound corpses.
  final Uint8List untargetable;

  /// Vane's *Marked* (T3a) — seconds left on the +25 % damage-taken window
  /// a hit beyond 8 u opens. Read as a plain boonSum term in
  /// `ProjectileSystem._applyHit`, the same shape every other per-target
  /// timed bonus in this file already uses (`slowRemaining`,
  /// `enrageRemaining`).
  final Float64List markedRemaining;

  /// Kestrel's *Bleed* (T3b) — a non-elemental damage-over-time. Deliberately
  /// not on [StatusStore]: that class's own doc comment frames it as
  /// "four elements, four different shapes of state" — Bleed does not react,
  /// does not pair with Confluence, and touches no [SimElement] at all, so
  /// living here (the same "per-enemy timed status that is not an element"
  /// spot [markedRemaining] already established for Vane's own Marked) keeps
  /// that class's stated scope honest rather than smuggling in a fifth kind
  /// under it. `stacks` exists (not just a bool) so a future stacking
  /// consumer (Rook's own *Crush*, "grouped enemies take stacking 5 %/s" —
  /// pending on this exact primitive) has somewhere to grow into; Kestrel's
  /// own trigger only ever sets it to a flat 1, never increments it. Ticked
  /// in `ElementSystem.update` alongside Burn/Toxin — the same shared
  /// damage-then-death routine, not a second copy of it.
  final Uint8List bleedStacks;
  final Float64List bleedRemaining;

  /// Index into `ContentLibrary.bosses.all`, or -1 for an ordinary enemy.
  ///
  /// Mirrors `EntityStore.contentIndex`'s own "pointer into content, not a
  /// string, not a duplicated flag" shape — kept as a second field rather
  /// than repurposing `contentIndex` itself, since an ordinary enemy still
  /// needs its own `EnemyDefinition` looked up the normal way even while a
  /// boss occupies the same slot type. `BossPhaseSystem` is the one reader.
  final Int32List bossIndex;

  /// Current phase, 0-based. Advances only forward, only in
  /// `BossPhaseSystem`, by comparing live HP fraction against
  /// `BossDefinition.phaseThresholds` — see that field's own doc comment for
  /// why the two can never fall out of sync.
  final Uint8List bossPhase;

  /// Points a multi-body boss's child (an effigy, a segment, a sigil) at the
  /// entity holding its *real* health, or -1 for a slot whose own `health`
  /// field is the real one — the ordinary case, and every non-boss enemy.
  ///
  /// Exists because docs/06 keeps re-raising the identical shape: Cinder
  /// Choir's three effigies, Skarn's 1→2→4 split, Coilspine's 24 segments,
  /// Thrall's nine sigils — several bodies, one shared pool. Built generic
  /// against Cinder Choir (`CinderChoirSystem`), the first boss to need it,
  /// on the theory that a second and third consumer are already named in the
  /// GDD rather than hypothetical. `ProjectileSystem._applyHit` is the one
  /// place damage is actually redirected; plate, shield and stagger tracking
  /// stay on the hit slot itself — only the health write follows the link,
  /// because a shared pool with independent armour is the entire point (only
  /// the lit effigy lets damage through at all).
  final Int32List linkedHealthSlot;

  /// This child's fixed ordinal position (0-based) among its boss's other
  /// children, set once at spawn. Meaningless (0) on anything that is not a
  /// linked child. A boss's own system reads this alongside
  /// [bossActiveChildIndex] to know which specific child is the currently
  /// active one, the same way [linkedHealthSlot] answers "which one pool".
  final Uint8List bossChildIndex;

  /// A generic countdown a boss's own system owns and interprets — Cinder
  /// Choir's rotation timer (P1/P2). Meaningless (0) on anything that is not
  /// a boss primary. `EnemyStore.attackCooldown` (the field every ordinary
  /// enemy already has, unused by a bare boss entity) doubles as a *second*
  /// concurrent timer where a boss needs one — Cinder Choir's P2 tether-hit
  /// cadence reads that one, this one keeps rotating, exactly the "two
  /// concurrent cadences" case this comment used to flag as unbuilt.
  final Float64List bossTimer;

  /// Which [bossChildIndex] is currently the "active" one — Cinder Choir's
  /// lit, vulnerable effigy. Meaningless (0) on anything that is not a boss
  /// primary; read and written only by that boss's own system.
  final Uint8List bossActiveChildIndex;

  /// A generic running angle (radians) a boss's own system owns — Cinder
  /// Choir's P2 tether sweep, at 45°/s (docs/06 §1). Zero and inert outside
  /// whatever phase a boss's own system gates it to; doubles as that phase's
  /// own elapsed-time clock (`angle / rate = seconds`), so no separate timer
  /// is needed to know how long the sweep has been running.
  final Float64List bossSweepAngle;

  /// A multi-body boss's child's *permanent* parent — the primary's own
  /// slot, or -1. Set once at spawn and never changed, unlike
  /// [linkedHealthSlot], which starts equal to this and can later be
  /// cleared: Cinder Choir's P3 ("all three light simultaneously... killing
  /// one permanently removes it") un-shares the pool by setting
  /// `linkedHealthSlot = -1` on all three, at which point [linkedHealthSlot]
  /// alone can no longer answer "whose child is this" — a boss's own system
  /// still needs that answer to run its per-child attack logic, find
  /// siblings, or clean up survivors when the primary itself dies. See ADR
  /// 0020.
  final Int32List bossParent;

  /// Seconds since this enemy last took a nonzero hit — reset to 0 by
  /// `ProjectileSystem._applyHit` and `ElementSystem.update` on any damage
  /// that actually lands, incremented by a boss's own system for whichever
  /// entities it cares about. Zero and unread on an ordinary enemy.
  ///
  /// Built generic against Skarn the Unmade's own "damaging only one causes
  /// the other to heal it" (docs/06 §11) — a boss's own system decides what
  /// "too long unhit" means and reacts (`SkarnSystem`'s own neglect-heal);
  /// this field only answers "how long ago", the same "one clock, several
  /// consumers decide what it means" split [bossTimer] already established.
  /// See ADR 0022.
  final Float64List bossLastHitAgo;

  /// Whether the most recent hit to actually reach this enemy's health was
  /// fired by the hero's own Ultimate — `ProjectileStore.isUltimateArrow`
  /// copied over wherever a hit resolves, unconditionally (so a later,
  /// ordinary hit correctly clears it rather than leaving an earlier
  /// Ultimate hit's tag stuck on a target that survived it). Read only by
  /// Wren's own *Warden's Fury* (T5b, "refunds 30 % charge on kill") at
  /// `AiSystem`'s own death pass — a kill needs to know which arrow struck
  /// last, not merely that an Ultimate arrow existed somewhere earlier in
  /// the fight.
  final Uint8List lastHitWasUltimate;

  final Uint8List variant;

  final Int32List telegraphSlot;
  final Int32List telegraphSerial;

  int get capacity => _capacity;

  AiState stateOf(int slot) => AiState.values[state[slot]];

  EnemyVariant variantOf(int slot) => EnemyVariant.values[variant[slot]];

  bool isPlated(int slot) => plateHealth[slot] > 0;

  bool isElite(int slot) => elite[slot] == 1;

  bool isBoss(int slot) => bossIndex[slot] >= 0;

  bool isUntargetable(int slot) => untargetable[slot] == 1;

  bool isEnraged(int slot) => enrageRemaining[slot] > 0;

  /// True if [element] currently cannot be applied to this enemy — either
  /// adapted to it (Null), born immune (Voidtouched), or standing inside a
  /// Warden-Fell aura.
  bool resistsElement(int slot, SimElement element) {
    if (elementSuppressed[slot] == 1) return true;
    return immuneRemaining[slot] > 0 && immuneElement[slot] == element.index;
  }

  /// Records what just hurt this enemy, for archetypes that adapt.
  ///
  /// [duration] of zero clears any adaptation — the Voidtouched variant passes
  /// [double.infinity] once at spawn and is never touched again.
  void adaptTo(int slot, SimElement element, double duration) {
    if (duration <= 0) return;
    immuneElement[slot] = element.index;
    immuneRemaining[slot] = duration;
  }

  /// Applies damage to the shield first. Returns what is left for health.
  ///
  /// A shield that absorbed *part* of a hit and let the rest through would make
  /// the Weaver's contribution invisible; absorbing whole hits until it breaks
  /// is what makes "kill the Weaver first" a decision with a felt consequence.
  double absorb(int slot, double incoming) {
    final double s = shield[slot];
    if (s <= 0) return incoming;
    if (s >= incoming) {
      shield[slot] = s - incoming;
      return 0;
    }
    shield[slot] = 0;
    shieldedBy[slot] = -1;
    return incoming - s;
  }

  /// Damage the plate soaks, returning what passes through to health.
  ///
  /// The plate itself is worn down by whatever gets through the armour factor,
  /// so a Tier-I plinker does eventually break it — slowly, which is the
  /// lesson the Husk exists to teach (docs/05 §5.2).
  void wearPlate(int slot, double throughArmour) {
    if (plateHealth[slot] <= 0) return;
    plateHealth[slot] -= throughArmour;
    if (plateHealth[slot] <= 0) {
      plateHealth[slot] = 0;
      plateJustBroke[slot] = 1;
    }
  }

  void reset(int slot) {
    armourShred[slot] = 0;
    elite[slot] = 0;
    windlineSlowFactor[slot] = 1.0;
    blindRemaining[slot] = 0;
    state[slot] = AiState.idle.index;
    stateTimer[slot] = 0;
    attackCooldown[slot] = 0;
    contactCooldown[slot] = 0;
    comboStep[slot] = 0;
    damageDuringWindUp[slot] = 0;
    plateHealth[slot] = 0;
    plateHalfArc[slot] = 0;
    plateRegen[slot] = 0;
    plateJustBroke[slot] = 0;
    plateFlatFactor[slot] = 0;
    adaptSeconds[slot] = 0;
    shield[slot] = 0;
    shieldedBy[slot] = -1;
    attackBuff[slot] = 0;
    elementSuppressed[slot] = 0;
    immuneElement[slot] = -1;
    immuneRemaining[slot] = 0;
    revivesLeft[slot] = 0;
    targetX[slot] = 0;
    targetY[slot] = 0;
    phase[slot] = 0;
    liveAdds[slot] = 0;
    spawnerSlot[slot] = -1;
    speedScale[slot] = 1.0;
    enrageRemaining[slot] = 0;
    slowRemaining[slot] = 0;
    markedRemaining[slot] = 0;
    bleedStacks[slot] = 0;
    bleedRemaining[slot] = 0;
    bossIndex[slot] = -1;
    bossPhase[slot] = 0;
    linkedHealthSlot[slot] = -1;
    bossChildIndex[slot] = 0;
    bossTimer[slot] = 0;
    bossActiveChildIndex[slot] = 0;
    bossSweepAngle[slot] = 0;
    bossParent[slot] = -1;
    bossLastHitAgo[slot] = 0;
    lastHitWasUltimate[slot] = 0;
    untargetable[slot] = 0;
    variant[slot] = EnemyVariant.none.index;
    telegraphSlot[slot] = -1;
    telegraphSerial[slot] = 0;
  }

  void clear() {
    for (int i = 0; i < _capacity; i++) {
      reset(i);
    }
  }
}
