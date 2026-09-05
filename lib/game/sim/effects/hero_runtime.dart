import 'dart:typed_data';

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

  /// The *Echoing* affix's own chance to fire one extra arrow per shot —
  /// summed across whichever rolled affix slots carry it, by
  /// `HeroLoadoutResolver.apply`. A per-build number read directly, the
  /// same shape as [chargePerDamage], rather than a `StatChannel`: nothing
  /// else in the game currently grants an echo chance, so there is no
  /// composed pool to add it to yet.
  double echoChance = 0;

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

  /// *Chain Kill* (T3b) — how many kills' worth of [firstBloodSpeedBonus]
  /// are currently stacked (cap 3), rather than the base card's flat
  /// refresh. Only ever touched when the talent is held; irrelevant
  /// otherwise, since the speed read site ignores it without the talent.
  int firstBloodSpeedStacks = 0;

  /// Seconds left on Nyx's *Umbral Step* untargetable window. Zero means
  /// inactive — checked by [EnemyAttack.damagePlayer], the one place an
  /// enemy hit is allowed to land, the same way Covenant/Ghost Step/Immortal
  /// Draw already ignore a hit outright.
  double umbralStepRemaining = 0;

  /// Arrows left that are guaranteed crits at a fixed multiplier (300%, or
  /// 600% for Perfect Step's single shot) rather than the player's own
  /// composed crit chance/damage — consumed at fire time in
  /// `SimWorld._applyArrowBoons`, since this is a guarantee, not odds.
  int umbralStepGuaranteedCritShots = 0;

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

  /// Lira's *Overheal* (T3a) — a shield sourced from her own excess
  /// healing (Lifebound's lifesteal, Verdant Bloom's own regen), capped at
  /// 30 % max HP. Kept separate from `BoonRuntime.shield` (Shieldweave's
  /// own Momentum-based pool) rather than sharing it: that pool's own
  /// capacity-shrink rule is about Momentum, has nothing to do with Lira's
  /// heals, and would silently eat this shield the moment Momentum
  /// dropped. Consumed the same way in `EnemyAttack`'s own damage path,
  /// as a second, independent pool.
  double overhealShield = 0;

  /// Seconds left on Thane's *Red Draw*. Zero means inactive.
  double redDrawRemaining = 0;

  double redDrawDamageBonus = 0;
  double redDrawFireRateMultiplier = 1.0;

  /// Seconds left on Torv's *Tempest Nock* — every arrow chains for the
  /// duration, not just the periodic one *Arc* marks. Zero means inactive.
  double tempestNockRemaining = 0;

  /// Seconds left on Corvin's *Caroms* — every arrow fired while this reads
  /// above zero ricochets 4× instead of Bounce's own 1 (or Double Bounce's
  /// 2), read at spawn time in `SimWorld._spawnArrow` the same way
  /// [tempestNockRemaining] is read at spawn for Torv's own chain count.
  /// Zero means inactive.
  double caromsRemaining = 0;

  static const double caromsDuration = 6.0;

  /// Seconds left on Mirelle's *Hall of Mirrors* — every arrow fired while
  /// this reads above zero also fires the guaranteed triple-duplicate in
  /// `SimWorld._applyHallOfMirrorsDuplication`, read at spawn time the
  /// same way [tempestNockRemaining]/[caromsRemaining] are above. Distinct
  /// from the mirror clone itself, which is an ordinary temporary
  /// `CompanionSystem` entity with its own separate lifetime — this field
  /// only ever gates the arrow-duplication half. Zero means inactive.
  double hallOfMirrorsRemaining = 0;

  /// Seconds left on Sable's *Miasma* cloud. Zero means inactive. Unlike
  /// every other timed self-buff above, this one is a fixed zone rather
  /// than a buff on the player — [miasmaX]/[miasmaY] pin where it was cast,
  /// read every tick alongside this by whoever applies its stacks.
  double miasmaRemaining = 0;
  double miasmaX = 0;
  double miasmaY = 0;

  /// Counts down to the cloud's next stack application — Miasma applies in
  /// discrete pulses (2/s base, 5/s for Concentrated Miasma) rather than a
  /// continuous rate, since Toxin stacks are whole numbers.
  double miasmaTickTimer = 0;

  /// Counts down to Rook's *Crush* (T3a) next re-check of who is currently
  /// grouped — the same "discrete pulses, not a continuous rate" shape
  /// [miasmaTickTimer] already uses, for the same reason (ADR 0015's own
  /// update on Crush).
  double crushTickTimer = 0;

  /// Seconds left on Kade's *Pyre Line* wall. Zero means inactive. Endpoints
  /// pinned at cast time, the same shape as Miasma's own fixed zone.
  double pyreLineRemaining = 0;
  double pyreLineX0 = 0;
  double pyreLineY0 = 0;
  double pyreLineX1 = 0;
  double pyreLineY1 = 0;

  /// *Twin Pyre* (T5b)'s second, perpendicular wall — only ever non-zero
  /// alongside [pyreLineRemaining], and only when that talent is held.
  double pyreLine2X0 = 0;
  double pyreLine2Y0 = 0;
  double pyreLine2X1 = 0;
  double pyreLine2Y1 = 0;

  /// Seconds left on Rook's own *Singularity* well. Zero means inactive.
  /// The same fixed-zone shape Miasma's own cloud and Pyre Line's own wall
  /// already use — pinned at cast time, ticked every frame to pull whoever
  /// stands within range, then detonates once this reaches zero.
  double singularityRemaining = 0;
  double singularityX = 0;
  double singularityY = 0;

  /// *Twin Singularity* (T5a)'s second well — only ever non-zero alongside
  /// [singularityRemaining], and only when that talent is held. The same
  /// "second independent instance of the same fixed zone" shape
  /// [pyreLine2X0] already established for Kade's own Twin Pyre.
  double singularity2Remaining = 0;
  double singularity2X = 0;
  double singularity2Y = 0;

  /// Seconds left on Iris's own *The Lattice*. Zero means inactive. The
  /// same fixed-zone shape as the fields above — pinned at cast time
  /// (recentred every tick instead for *Living Lattice*, T5b).
  double latticeRemaining = 0;
  double latticeX = 0;
  double latticeY = 0;

  /// The Lattice's own spokes, `[x0, y0, x1, y1]` per line, recomputed
  /// every tick by `SimWorld._tickIrisLattice` — the trig lives there,
  /// since `ProjectileSystem` deliberately imports no `dart:math` in its
  /// own hot loop (see `_length`'s own doc comment). Sized for the larger
  /// of the two ★5 branches (10 lines, *Grand Lattice*); only the first
  /// `latticeLineCount * 4` entries are meaningful. The one array-shaped
  /// field on this class — everything else here is a single hero's own
  /// scalar state, but a fixed, small bundle of line endpoints is exactly
  /// what a flat numeric buffer is for, and 10 named quadruplets would be
  /// worse to read and to update in a loop than this one array is.
  final Float64List latticeLines = Float64List(40);
  int latticeLineCount = 0;

  /// Bram's own *Mortar Rain* — up to [bramMaxShells] independent falling
  /// shells, each just a countdown to its own impact point, ticked by
  /// `SimWorld._tickBramMortarRain`. Sized for the largest variant
  /// (*Saturation*, T5a: 20); the base cast (12) and *Precision Strike*
  /// (T5b: 4) simply leave the rest inert, tracked by [bramShellCount] —
  /// the same "one array-shaped bundle, sized for the biggest branch"
  /// shape [latticeLines] above already establishes.
  /// [bramShellTelegraphSlot]/[bramShellTelegraphSerial] let each shell
  /// release its own warning
  /// telegraph the instant it detonates, the `(slot, serial)` pair every
  /// other telegraph owner in this game already holds.
  static const int bramMaxShells = 20;
  final Float64List bramShellRemaining = Float64List(bramMaxShells);
  final Float64List bramShellX = Float64List(bramMaxShells);
  final Float64List bramShellY = Float64List(bramMaxShells);
  final Int32List bramShellTelegraphSlot = Int32List(bramMaxShells);
  final Int32List bramShellTelegraphSerial = Int32List(bramMaxShells);
  int bramShellCount = 0;
  double bramShellDamageShare = 0;

  // ── Once-per-run counters ─────────────────────────────────────────────────
  // Counted per run rather than per room, same as BoonRuntime.arrowsFired —
  // a counter that silently reset at every door would make the card read as
  // random rather than building toward a felt payoff.

  /// Arrows fired since this hero was equipped. Torv's *Arc* triggers when
  /// this hits every 5th (or 3rd, with Frequent Arc) — checked and reset by
  /// whoever increments it, not by this class.
  int arrowsFired = 0;

  // ── Once-per-run state ────────────────────────────────────────────────────
  // The hero-side counterpart to Guardian Angel/Phoenix Heart — Ashlin's
  // Rekindle is the same shape, extended with an AoE nova.

  /// How many times Rekindle has revived the player this run. Capped at 1
  /// (or 2, with Twice Kindled) in `EnemyAttack.damagePlayer` — a count
  /// rather than the flag an earlier part left here, since Twice Kindled
  /// needs more than one revive to be possible at all.
  int rekindlesUsed = 0;

  /// Whether Rebirth Nova's own Rekindle-refresh has already fired this
  /// room — a per-*room* flag, not once-per-run, cleared in [beginRoom].
  /// The restriction *Eternal* (T5a) removes; see ADR 0081 and
  /// `SimWorld._fireAshlinRebirthNova`'s own doc comment for why the base
  /// kit needed one authored at all.
  bool rebirthNovaRefreshedThisRoom = false;

  /// Set the instant Rekindle's revive triggers, inside
  /// `EnemyAttack.damagePlayer`; read and cleared by `SimWorld.tick` right
  /// after `AiSystem` runs. The nova itself is resolved there rather than
  /// in `EnemyAttack` because only `SimWorld` has `playerAttack`, `spatial`
  /// and `entities` together to apply an AoE burst.
  bool rekindleNovaPending = false;

  /// Seconds left on Ashlin's own invulnerability — Rekindle's revive and
  /// Ember Body's room-clear window both set this, rather than each
  /// getting a separate field, since only one is ever live for a single
  /// hero. Checked in `EnemyAttack.damagePlayer` the same way
  /// `umbralStepRemaining` already is.
  double ashlinInvulnRemaining = 0;

  /// Seconds left on Ovrin's *Aegis Pin* — while this reads above zero,
  /// `EnemyAttack.damagePlayer` blocks the hit outright (the same "ignore
  /// it entirely" shape as [umbralStepRemaining]/[ashlinInvulnRemaining]
  /// above) and reflects a share of it back at the attacker as Storm
  /// damage. Zero means inactive.
  double aegisPinRemaining = 0;

  /// Set the instant Ovrin's *Riposte* (T3b) triggers — his own shield
  /// (Shieldweave's `BoonRuntime.shield` pool, which `shieldPerMomentum`
  /// refills) hitting zero from a hit that found it above zero — inside
  /// `EnemyAttack.damagePlayer`; read and cleared by `SimWorld.tick` right
  /// after `AiSystem` runs, the identical hand-off [rekindleNovaPending]
  /// above already uses for the same reason: only `SimWorld` has
  /// `playerAttack`/`spatial`/`entities` together to resolve an AoE burst.
  bool riposteNovaPending = false;

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
    echoChance = 0;
    _readyAnnounced = false;
    flurryRemaining = 0;
    flurryRateMultiplier = 1.0;
    firstBloodSpeedRemaining = 0;
    firstBloodSpeedStacks = 0;
    umbralStepRemaining = 0;
    umbralStepGuaranteedCritShots = 0;
    prismRemaining = 0;
    bloomRemaining = 0;
    bloomHealPerSecond = 0;
    bloomDamageBonus = 0;
    overhealShield = 0;
    redDrawRemaining = 0;
    redDrawDamageBonus = 0;
    redDrawFireRateMultiplier = 1.0;
    tempestNockRemaining = 0;
    caromsRemaining = 0;
    hallOfMirrorsRemaining = 0;
    miasmaRemaining = 0;
    miasmaX = 0;
    miasmaY = 0;
    miasmaTickTimer = 0;
    crushTickTimer = 0;
    pyreLineRemaining = 0;
    pyreLineX0 = 0;
    pyreLineY0 = 0;
    pyreLineX1 = 0;
    pyreLineY1 = 0;
    pyreLine2X0 = 0;
    pyreLine2Y0 = 0;
    pyreLine2X1 = 0;
    pyreLine2Y1 = 0;
    singularityRemaining = 0;
    singularityX = 0;
    singularityY = 0;
    singularity2Remaining = 0;
    singularity2X = 0;
    singularity2Y = 0;
    latticeRemaining = 0;
    latticeX = 0;
    latticeY = 0;
    latticeLineCount = 0;
    bramShellCount = 0;
    arrowsFired = 0;
    rekindlesUsed = 0;
    rebirthNovaRefreshedThisRoom = false;
    rekindleNovaPending = false;
    ashlinInvulnRemaining = 0;
    aegisPinRemaining = 0;
    riposteNovaPending = false;
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
    firstBloodSpeedStacks = 0;
    umbralStepRemaining = 0;
    umbralStepGuaranteedCritShots = 0;
    prismRemaining = 0;
    bloomRemaining = 0;
    redDrawRemaining = 0;
    tempestNockRemaining = 0;
    caromsRemaining = 0;
    hallOfMirrorsRemaining = 0;
    miasmaRemaining = 0;
    pyreLineRemaining = 0;
    ashlinInvulnRemaining = 0;
    aegisPinRemaining = 0;
    singularityRemaining = 0;
    singularity2Remaining = 0;
    latticeRemaining = 0;
    latticeLineCount = 0;
    bramShellCount = 0;
    rebirthNovaRefreshedThisRoom = false;
  }
}
