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
        adaptSeconds = Float64List(capacity),
        shield = Float64List(capacity),
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
        telegraphSerial = Int32List(capacity);

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

  // ── Choir effects, recomputed every tick ──────────────────────────────────

  /// Absorbs damage before health does. Granted by a Weaver.
  final Float64List shield;

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

  final Uint8List variant;

  final Int32List telegraphSlot;
  final Int32List telegraphSerial;

  int get capacity => _capacity;

  AiState stateOf(int slot) => AiState.values[state[slot]];

  EnemyVariant variantOf(int slot) => EnemyVariant.values[variant[slot]];

  bool isPlated(int slot) => plateHealth[slot] > 0;

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
