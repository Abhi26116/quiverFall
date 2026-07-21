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
    rekindleSpent = false;
    cycleIndex = 0;
  }

  /// Clears only what a room boundary resets — not the once-per-run flags, not
  /// the loadout itself. Mirrors [BoonRuntime.beginRoom].
  void beginRoom() {
    // Nothing yet reads this per-room; kept as the hook Task #4's per-room
    // mechanics (Aegis Pin's own cooldown, and similar) will use, the same way
    // BoonRuntime.beginRoom existed before every Boon that needed it did.
  }
}
