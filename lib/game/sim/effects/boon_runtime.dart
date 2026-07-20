import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/elements.dart';

/// Which behaviours are live, and the state they keep.
///
/// **This is how a Boon reaches the simulation without the simulation
/// depending on the Boon system.** `lib/game/boons/` imports `lib/game/sim/`;
/// the reverse would be circular. So the resolver writes flags and counters
/// here, and every system reads plain booleans and integers that happen to have
/// been set by a card.
///
/// Two kinds of field again, and again the distinction matters:
///
///  - **Flags** — set by `LoadoutResolver` when the build changes, and only
///    then.
///  - **State** — owned by the simulation. Some of it is per-run (a Phoenix
///    Heart is spent once), some per-room (Aegis recharges), and getting that
///    wrong in either direction is a balance change disguised as a bug fix.
class BoonRuntime {
  BoonRuntime() : _active = List<bool>.filled(BoonBehaviour.values.length, false);

  final List<bool> _active;

  bool has(BoonBehaviour behaviour) => _active[behaviour.index];

  /// Replaces the live set. Called only by `LoadoutResolver`.
  void setActive(List<bool> active) {
    for (int i = 0; i < _active.length; i++) {
      _active[i] = i < active.length && active[i];
    }
  }

  // ── Per-run state ─────────────────────────────────────────────────────────
  // Spent once and not restored until the run ends. A Guardian Angel that came
  // back every room would be a different, far stronger card.

  bool guardianAngelSpent = false;
  bool phoenixHeartSpent = false;

  /// *Attunement* (#88) and *Elemental Tips* (#81) both resolve to one element
  /// at pickup. Null until one of them does.
  SimElement? attunedElement;

  /// Arrows released this run. Drives *Hammerfall* (#19) and *Quiverfall*
  /// (#112).
  ///
  /// Run-scoped rather than room-scoped so the player can feel the count
  /// approaching — a counter that silently reset at every door would make both
  /// cards read as random.
  int arrowsFired = 0;

  // ── Per-room state ────────────────────────────────────────────────────────

  /// Hits *Aegis* (#39) will still absorb. Recharges each room, which is what
  /// the card says.
  int aegisCharges = 0;

  /// Seconds of *Covenant* (#43) invulnerability left in this room.
  double covenantRemaining = 0;

  // ── Continuous state ──────────────────────────────────────────────────────

  /// Seconds until *Dash* (#49) is ready.
  double dashCooldown = 0;

  /// *Blink* (#53) charges available.
  int blinkCharges = 0;

  /// Seconds of *Ghost Step* (#56) invulnerability left.
  double invulnerableRemaining = 0;

  /// Damage *Blood Pact* (#41) has deferred, and the time left to pay it.
  double deferredDamage = 0;
  double deferredRemaining = 0;

  /// Shield points from *Shieldweave* (#33), recomputed from live Momentum.
  double shield = 0;

  // ── Tuning, from docs/09 §9.2 ─────────────────────────────────────────────

  /// *Hammerfall*: every 8th arrow deals 400 %.
  static const int hammerfallEvery = 8;
  static const double hammerfallMultiplier = 4.0;

  /// *Quiverfall*: every 10th arrow deals 2,000 % but stuns for 1 s.
  static const int quiverfallEvery = 10;
  static const double quiverfallMultiplier = 20.0;
  static const double quiverfallStunSeconds = 1.0;

  /// *Cull*: instantly kills non-elites below this fraction of max HP.
  static const double cullThreshold = 0.08;

  /// *Deadeye*: crits gain this much pierce.
  static const int deadeyePierce = 2;

  /// *Guardian Angel* and *Phoenix Heart* leave the player here.
  static const double guardianAngelHealth = 1.0;
  static const double phoenixHeartFraction = 0.50;

  /// *Aegis*: hits absorbed per room.
  static const int aegisChargesPerRoom = 3;

  /// *Covenant*: seconds of grace at the start of each room.
  static const double covenantSeconds = 8.0;

  /// *The Unbroken*: no single hit may exceed this fraction of max HP.
  static const double unbrokenCap = 0.08;

  /// *Blood Pact*: this much of a hit is deferred, over this long.
  static const double bloodPactFraction = 0.30;
  static const double bloodPactSeconds = 4.0;

  /// *The Bargain*: each room starts here.
  static const double bargainStartFraction = 0.25;

  /// *Dash*: distance and cooldown.
  static const double dashDistance = 3.0;
  static const double dashCooldownSeconds = 4.0;
  static const int blinkChargeCount = 2;
  static const double ghostStepSeconds = 0.8;

  /// *Runner's High*: fire rate at max Momentum.
  static const double runnersHighFireRate = 1.30;

  /// *Stormfoot*: targets an arrow chains to at max Momentum.
  static const int stormfootChains = 2;

  /// *Resonant Weave*: radius and damage share of the Confluence detonation.
  static const double resonantRadius = 1.5;
  static const double resonantDamageShare = 0.80;

  /// *Echo Thread*: length of the Windline a dying enemy leaves, per copy.
  static const double echoLengthPerCopy = 1.2;

  /// Copies of *Echo Thread* held. The one behaviour authored to scale with
  /// copies — see `BoonDefinition.stacksByCopies`.
  int echoThreadCopies = 0;

  /// *Rain of Nocks*: extra arrows, spread, and their damage share.
  static const int rainArrows = 3;
  static const double rainSpreadRadians = 0.70;
  static const double rainDamageShare = 0.70;

  /// *Elemental Overload*: every 6th arrow carries all four.
  static const int overloadEvery = 6;

  /// *The Fourfold*: potency of each of the four.
  static const double fourfoldPotency = 0.50;

  /// *Golden Arrow*: chance a hit drops gold.
  static const double goldenArrowChance = 0.05;

  /// True while the player cannot be hurt at all.
  bool get isInvulnerable =>
      invulnerableRemaining > 0 || covenantRemaining > 0;

  /// Starts a room. Recharges what recharges, and nothing else.
  void beginRoom() {
    aegisCharges = has(BoonBehaviour.aegis) ? aegisChargesPerRoom : 0;
    covenantRemaining = has(BoonBehaviour.covenant) ? covenantSeconds : 0;
    blinkCharges = has(BoonBehaviour.blink) ? blinkChargeCount : 0;
    dashCooldown = 0;
    deferredDamage = 0;
    deferredRemaining = 0;
    invulnerableRemaining = 0;
  }

  /// Clears everything, per-run state included.
  void reset() {
    for (int i = 0; i < _active.length; i++) {
      _active[i] = false;
    }
    guardianAngelSpent = false;
    phoenixHeartSpent = false;
    attunedElement = null;
    arrowsFired = 0;
    echoThreadCopies = 0;
    shield = 0;
    beginRoom();
  }
}
