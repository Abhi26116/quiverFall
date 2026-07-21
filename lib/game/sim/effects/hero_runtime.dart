import 'package:quiverfall/game/sim/effects/arrow_behaviour.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';

/// Which hero and arrow behaviours are live, and the state they keep.
///
/// The Boon-side split applies here too: `lib/game/heroes/` and
/// `lib/game/arrows/` import `lib/game/sim/`, so the reverse would be
/// circular, and this is how a hero reaches the simulation without the
/// simulation depending on the hero system. `HeroLoadoutResolver` writes
/// flags here; every system reads plain booleans and numbers that happen to
/// have been set by whichever hero and arrow are equipped.
///
/// **Exactly one hero and one arrow are ever active** — unlike
/// [BoonRuntime], which tracks a whole run's accumulated build, this tracks a
/// single loadout, replaced whole whenever the loadout changes rather than
/// accumulated over a run.
class HeroRuntime {
  HeroRuntime()
      : _heroActive = List<bool>.filled(HeroBehaviour.values.length, false),
        _arrowActive = List<bool>.filled(ArrowBehaviour.values.length, false);

  final List<bool> _heroActive;
  final List<bool> _arrowActive;

  bool has(HeroBehaviour behaviour) => _heroActive[behaviour.index];

  bool hasArrow(ArrowBehaviour behaviour) => _arrowActive[behaviour.index];

  /// Replaces the live hero behaviour set. Called only by
  /// [HeroLoadoutResolver].
  void setHeroActive(List<bool> active) {
    for (int i = 0; i < _heroActive.length; i++) {
      _heroActive[i] = i < active.length && active[i];
    }
  }

  void setArrowActive(ArrowBehaviour? behaviour) {
    for (int i = 0; i < _arrowActive.length; i++) {
      _arrowActive[i] = false;
    }
    if (behaviour != null) _arrowActive[behaviour.index] = true;
  }

  // ── Ultimate charge ────────────────────────────────────────────────────────
  // docs/07 §7.0: `charge% = 100 * damageDealt / (14 * heroATK * fireRate)`.
  // Manual — a single large button, right thumb, never auto-cast.

  /// 0.0 to 1.0. Reaching 1.0 means the button is live; firing it resets to 0.
  double ultimateCharge = 0;

  bool get ultimateReady => ultimateCharge >= 1.0;

  /// The denominator's fixed numbers from docs/07 §7.0's formula, held here
  /// so `charge% = damageDealt / (14 * heroATK * fireRate)` reads as the
  /// formula rather than a bare `/14`.
  static const double ultimateChargeDivisor = 14.0;

  /// `1 / (14 * heroATK * fireRate)` — set by `HeroLoadoutResolver.apply`
  /// from the hero's own base stat block, per ADR 0006. Zero (the resting
  /// value) means no hero is loaded and damage charges nothing, rather than
  /// dividing by zero.
  double chargePerDamage = 0;

  /// Adds this hit's share of Ultimate charge. [rawDamage] is the damage the
  /// hit actually dealt — pre-mitigation makes an armoured target charge the
  /// Ultimate slower than a fodder one, which is backwards for a resource
  /// meant to reward landing hits at all.
  void chargeFromDamage(double rawDamage) {
    if (chargePerDamage <= 0) return;
    final double next = ultimateCharge + rawDamage * chargePerDamage;
    ultimateCharge = next > 1.0 ? 1.0 : next;
  }

  bool _readyAnnounced = false;

  /// True exactly once per charge-up — the tick charge first reaches 1.0.
  /// [SimWorld] uses this to emit `SimEventType.ultimateReady` once rather
  /// than every tick the button sits full.
  bool consumeJustBecameReady() {
    if (!ultimateReady) {
      _readyAnnounced = false;
      return false;
    }
    if (_readyAnnounced) return false;
    _readyAnnounced = true;
    return true;
  }

  // ── Timed self-buffs ───────────────────────────────────────────────────────
  // A handful of Ultimates are a window rather than an instant, and share this
  // one countdown-plus-multiplier shape rather than each inventing their own —
  // Kestrel's Flurry is the first; more get their own field only if the
  // duration/multiplier shape genuinely does not fit this one.

  /// Seconds left on Kestrel's *Flurry* — forced Tier III (checked wherever
  /// the effective Draw tier is chosen), a fire-rate multiplier
  /// ([flurryRateMultiplier]), and movement no longer dropping the tier for
  /// as long as this reads above zero. Zero means inactive.
  double flurryRemaining = 0;

  /// Set alongside [flurryRemaining] when Flurry triggers — the *Endless
  /// Flurry* and *Perfect Flurry* talents change both the duration and this
  /// rate together, never one without the other.
  double flurryRateMultiplier = 1.0;

  /// Seconds left on Nyx's *First Blood* kill-speed burst. Zero means
  /// inactive. Set by [AiSystem]'s death pass, the one place a kill is
  /// known; read wherever the player's move speed is resolved.
  double firstBloodSpeedRemaining = 0;

  static const double firstBloodSpeedDuration = 1.5;
  static const double firstBloodSpeedBonus = 0.25;

  /// Seconds left on Oriel's *Prism* — every arrow spawned while this reads
  /// above zero carries all four elements at once, checked wherever an
  /// arrow's element is assigned. Zero means inactive.
  double prismRemaining = 0;

  static const double prismDuration = 10.0;

  /// Seconds left on Lira's *Verdant Bloom*. Zero means inactive.
  double bloomRemaining = 0;

  /// Fraction of max HP healed per second while [bloomRemaining] is active.
  /// Zero for *Blood Bloom*, which converts the heal into damage instead.
  double bloomHealPerSecond = 0;

  /// Damage bonus applied while [bloomRemaining] is active — the base
  /// Bloom's +25 %, or Blood Bloom's +80 % in its place.
  double bloomDamageBonus = 0;

  // ── Once-per-run state ────────────────────────────────────────────────────
  // The hero-side counterpart to Guardian Angel/Phoenix Heart — Ashlin's
  // Rekindle is the same shape, extended with an AoE nova.

  bool rekindleSpent = false;

  // ── Per-arrow assignment ──────────────────────────────────────────────────

  /// Which element the equipped arrow currently fires, for arrows whose
  /// element rotates rather than staying fixed — Prismshaft, and Oriel's
  /// Spectrum passive layered on top of any arrow.
  int cycleIndex = 0;

  /// Clears everything. Called whenever the loadout is replaced wholesale —
  /// a different hero equipped, not merely levelled up.
  void reset() {
    for (int i = 0; i < _heroActive.length; i++) {
      _heroActive[i] = false;
    }
    for (int i = 0; i < _arrowActive.length; i++) {
      _arrowActive[i] = false;
    }
    ultimateCharge = 0;
    chargePerDamage = 0;
    _readyAnnounced = false;
    flurryRemaining = 0;
    flurryRateMultiplier = 1.0;
    firstBloodSpeedRemaining = 0;
    prismRemaining = 0;
    bloomRemaining = 0;
    bloomHealPerSecond = 0;
    bloomDamageBonus = 0;
    rekindleSpent = false;
    cycleIndex = 0;
  }

  /// Clears only what a room boundary resets — not the once-per-run flags, not
  /// the loadout itself. Mirrors [BoonRuntime.beginRoom].
  void beginRoom() {
    // A Flurry window is short and combat-scoped; carrying it through a door
    // for free would make "pop Flurry, then leave" a free rate-multiplier on
    // the next room's opening seconds. Matches `CombatModifiers.resetLive`
    // clearing the Kiting window at the same boundary.
    flurryRemaining = 0;
    firstBloodSpeedRemaining = 0;
    prismRemaining = 0;
    bloomRemaining = 0;
  }
}
