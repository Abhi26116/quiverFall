import 'dart:math' as math;

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/companion_store.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/arrow_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_runtime.dart';
import 'package:quiverfall/game/sim/effects/combat_modifiers.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/hero_runtime.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/hazard_store.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/projectile_store.dart';
import 'package:quiverfall/game/sim/segment_hash.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/spatial_hash.dart';
import 'package:quiverfall/game/sim/status_store.dart';
import 'package:quiverfall/game/sim/systems/ai_system.dart';
import 'package:quiverfall/game/sim/systems/arclight_system.dart';
import 'package:quiverfall/game/sim/systems/ashen_choir_system.dart';
import 'package:quiverfall/game/sim/systems/bellweather_system.dart';
import 'package:quiverfall/game/sim/systems/boon_system.dart';
import 'package:quiverfall/game/sim/systems/boss_phase_system.dart';
import 'package:quiverfall/game/sim/systems/cinder_choir_system.dart';
import 'package:quiverfall/game/sim/systems/coilspine_system.dart';
import 'package:quiverfall/game/sim/systems/companion_system.dart';
import 'package:quiverfall/game/sim/systems/confluence_system.dart';
import 'package:quiverfall/game/sim/systems/draw_system.dart';
import 'package:quiverfall/game/sim/systems/element_system.dart';
import 'package:quiverfall/game/sim/systems/firing_system.dart';
import 'package:quiverfall/game/sim/systems/gaunt_system.dart';
import 'package:quiverfall/game/sim/systems/green_mother_system.dart';
import 'package:quiverfall/game/sim/systems/hazard_system.dart';
import 'package:quiverfall/game/sim/systems/hollow_warden_system.dart';
import 'package:quiverfall/game/sim/systems/last_warden_system.dart';
import 'package:quiverfall/game/sim/systems/mother_of_motes_system.dart';
import 'package:quiverfall/game/sim/systems/movement_system.dart';
import 'package:quiverfall/game/sim/systems/pale_judge_system.dart';
import 'package:quiverfall/game/sim/systems/projectile_system.dart';
import 'package:quiverfall/game/sim/systems/rimefather_system.dart';
import 'package:quiverfall/game/sim/systems/silversong_system.dart';
import 'package:quiverfall/game/sim/systems/skarn_system.dart';
import 'package:quiverfall/game/sim/systems/spawn_system.dart';
import 'package:quiverfall/game/sim/systems/the_loom_system.dart';
import 'package:quiverfall/game/sim/systems/the_quiverfall_system.dart';
import 'package:quiverfall/game/sim/systems/thrall_of_nine_system.dart';
import 'package:quiverfall/game/sim/systems/umbral_twin_system.dart';
import 'package:quiverfall/game/sim/systems/vermillion_system.dart';
import 'package:quiverfall/game/sim/systems/weeping_gate_system.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/windline_store.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';

/// The order systems run in, every tick, without exception.
///
/// This is not documentation — it is asserted by a test. Order changes are
/// behaviour changes: running damage before collision, or spawn before
/// movement, produces a different game from the same inputs, which silently
/// invalidates every recorded replay and every balance measurement.
///
/// Later phases insert their systems at the marked positions rather than
/// appending, so the order stays intentional as it grows.
enum SystemOrder {
  input,
  movement,
  draw,
  collision,
  firing,
  // Phase 10. Right after ordinary firing so an ultimate that spawns arrows
  // (Wren's Volley Fan) has them swept by this same tick's projectile step —
  // exactly the ordering an ordinary volley already gets. No replay or
  // balance number was voided: no world before Phase 10 could ever hold a
  // hero, so `_updateUltimate` returns immediately (`hero.ultimateReady` is
  // false with no loadout applied) for every pre-existing seeded run.
  ultimate,
  // Confluence is resolved inside the projectile step, on each arrow's swept
  // path, so it cannot land a tick late.
  projectile,
  windlineExpiry,
  element,
  // Phase 11. After elements, for the identical "sees this tick's damage,
  // including a DoT tick" reason `element` itself sits after `projectile`;
  // before `ai` so a boss's own family tree reads this tick's phase, not
  // last tick's. No replay or balance number was voided: no world before
  // Phase 11 could ever hold a boss (`EnemyStore.bossIndex` starts at -1 and
  // nothing before now ever sets it), so this slot is a no-op for every
  // pre-existing seeded run.
  bossPhase,
  ai,
  // Ordnance moves after the AI that fired it, so a shell launched this tick
  // starts flying this tick and its landing ring is never a frame's worth of
  // lie.
  hazard,
  spawn,
  boon,
  cleanup,
}

/// The simulation.
///
/// **Pure Dart. No Flutter, no Flame, no Riverpod** — enforced by
/// `test/guards/architecture_guard_test.dart`. See docs/12-architecture.md
/// §12.0 for why this constraint is worth defending: it is what makes the
/// headless balance harness, deterministic replays, and eventual server-side
/// run validation possible.
///
/// A world is driven by [tick], which advances exactly one fixed step. The
/// caller ([FixedStepDriver], or a headless loop) decides how many steps a real
/// frame is worth.
class SimWorld {
  SimWorld({
    required this.seed,
    Arena? arena,
    ContentLibrary? content,
    int entityCapacity = SimConfig.maxEntities,
  })  : arena = arena ?? Arena.standard(),
        entities = EntityStore(capacity: entityCapacity),
        enemies = EnemyStore(capacity: entityCapacity),
        spatial = SpatialHash(),
        events = SimEventBuffer(),
        content = content ?? ContentLibrary.empty(),
        _rng = Rng(seed) {
    enemies.clear();
    // Sub-generators are split once, here, rather than on demand. Splitting
    // advances the parent stream, so a per-tick split would make the AI's
    // consumption depend on how many ticks had elapsed — and two identical runs
    // would diverge the moment one of them dropped a frame.
    ai = AiContext(
      content: this.content,
      entities: entities,
      enemies: enemies,
      status: status,
      spatial: spatial,
      arena: this.arena,
      events: events,
      telegraphs: telegraphs,
      hazards: hazards,
      lines: windlines,
      lineIndex: windlineIndex,
      rng: _rng.split(_aiRngLabel),
    );
  }

  /// Stream label for the AI's sub-generator. Arbitrary but fixed: changing it
  /// changes every seeded run.
  static const int _aiRngLabel = 0x5A1;

  /// Everything random in a run derives from this. Two worlds with the same
  /// seed and the same input sequence are byte-identical.
  final int seed;

  /// The room's collision geometry.
  ///
  /// Swappable, because a stage is several rooms and each has its own authored
  /// arena. Replaced through [loadArena], which keeps the AI's copy in step —
  /// walls that changed visually but not physically would be the worst kind of
  /// bug, because the room would look right and play wrong.
  Arena arena;

  final EntityStore entities;

  /// Per-enemy runtime state — plates, shields, cooldowns, AI state.
  final EnemyStore enemies;

  final SpatialHash spatial;
  final SimEventBuffer events;

  /// The enemy table this world spawns from. Empty by default, so a test can
  /// drive combat with bare entities and no content at all.
  final ContentLibrary content;

  /// Incoming attacks, as shapes with deadlines. The view draws them; the sim
  /// owns them, because a wind-up duration is balance and a telegraph's shape
  /// is a hitbox.
  final TelegraphStore telegraphs = TelegraphStore();

  /// Enemy ordnance and ground hazards.
  final HazardStore hazards = HazardStore();

  /// Progress through the current room's [RoomPlan].
  final SpawnState spawnState = SpawnState();

  /// Everything the behaviour trees read and write. Built once, mutated in
  /// place, never reallocated.
  late final AiContext ai;

  final Rng _rng;

  /// The player's entity. Set by whoever populates the room.
  EntityId player = EntityId.none;

  /// Draw and Momentum state — the game's core trade. See [DrawState].
  final DrawState playerDraw = DrawState();

  /// The Hollow Warden's own Draw state (docs/06 §4, boss 4) — the one
  /// other combatant in the game that Draws, which is why [DrawState] is a
  /// class rather than a row of arrays in the first place (see its own doc
  /// comment). One instance, reused across rooms exactly like [playerDraw]
  /// — reset alongside it in [clearRoom], not reallocated per fight.
  final DrawState hollowWardenDraw = DrawState();

  /// The Last Warden's own Draw state (docs/06 §6.3, Endless boss #20) —
  /// "Draw/Momentum duel at parity" (see `LastWardenSystem`'s own doc
  /// comment). A third live instance, reset alongside the other two in
  /// [clearRoom].
  final DrawState lastWardenDraw = DrawState();

  final ProjectileStore projectiles = ProjectileStore();

  /// Friendly, independently-acting bodies fighting alongside the player —
  /// Zea's own Skyhawk/Falconry, Mirelle's own Hall of Mirrors clone
  /// (docs/07 §7.3). See [CompanionStore]/[CompanionSystem] and ADR 0071.
  final CompanionStore companions = CompanionStore();

  /// The trails arrows leave — the game's signature mechanic. See [WindlineStore].
  final WindlineStore windlines = WindlineStore();

  /// Spatial index over [windlines]. Rebuilt each tick before projectiles move.
  final SegmentHash windlineIndex = SegmentHash();

  /// Elemental status on every entity. See [StatusStore].
  final StatusStore status = StatusStore();

  // ── Loadout inputs ────────────────────────────────────────────────────────
  // Phase 10 populates these from the equipped hero and arrow. Held here rather
  // than read from the save so the simulation stays free of any dependency on
  // the data layer.

  /// Fully-composed attack value, computed once per room.
  double playerAttack = 10.0;

  double fireRateMultiplier = 1.0;
  double projectileSpeed = 14.0;
  double arrowRadius = 0.12;
  double arrowLifetime = 2.5;
  int basePierce = 0;
  AimAssist aimAssist = AimAssist.standard;

  /// The element the equipped arrow carries, or null for a plain shaft.
  ///
  /// Phase 10 sets this from the loadout. It lives here rather than on the
  /// arrow's spawn call because it cannot change mid-room, and resolving it per
  /// shot would be work that can never produce a different answer.
  SimElement? arrowElement;

  /// Windline lifetime. Iris raises this to 2.6s; Boons and the Spire's
  /// Windline Weaving node add to it.
  double windlineDuration = SimConfig.windlineDuration;

  /// How near an arrow must pass a line to thread it. Boon 61 widens this,
  /// which is the accessibility lever on the mechanic.
  double windlineHitWidth = SimConfig.windlineHitWidth;

  /// 3 by default, 5 for Iris. Boons 65 and 70 raise it.
  int maxConfluenceStacks = ConfluenceTuning.defaultMaxStacks;

  /// Distance between Windline segments. See [SimConfig.windlineSegmentLength].
  double windlineSegmentLength = SimConfig.windlineSegmentLength;

  /// Base move speed before Momentum. Boons scale this; Momentum multiplies it
  /// at the point of use.
  double playerMoveSpeed = SimConfig.playerMoveSpeed;

  // ── Boon-composed loadout ─────────────────────────────────────────────────
  // Written only by `LoadoutResolver.apply`, read by the systems. Nothing in
  // `lib/game/sim/` knows a Boon exists — that seam is what lets the balance
  // harness swap a whole build by writing one object, and what keeps "does
  // Boon X apply here?" from becoming a question asked in forty places.

  /// Which Boon behaviours are live, and their state. See [BoonRuntime].
  final BoonRuntime boons = BoonRuntime();

  /// Which hero and arrow behaviours are live, and their state. See
  /// [HeroRuntime].
  final HeroRuntime hero = HeroRuntime();

  /// Per-hit conditional terms — the ones that cannot be resolved until a
  /// target and a distance are known. See [CombatModifiers].
  final CombatModifiers combat = CombatModifiers();

  /// Scales the Confluence bonus. Clamped by
  /// `DamageResolver.maxConfluenceBonus` at resolve time like every other
  /// Confluence term.
  double confluenceDamageMultiplier = 1.0;

  /// Free Confluence stacks every arrow starts with. *Weaver's Grace* (#74).
  int confluenceHeadStart = 0;

  /// Movement penalty applied to enemies standing on a Windline. *Tangle*
  /// (#63) raises the base 8 %.
  double windlineSlow = 0;

  /// Fraction of an enemy's max HP per second while it stands on a Windline.
  /// *Cutting Lines* (#66).
  double windlineDamageFraction = 0;

  /// Mitigation sources, kept separate on purpose. `DamageResolver` combines
  /// them multiplicatively and caps the product; summing them here would reach
  /// 100 % and make the player invulnerable (docs/04 §4.1 rule 2).
  double boonDamageReduction = 0;
  double stationaryDamageReduction = 0;
  double elementalResist = 0;

  /// Added to `DamageResolver.maxDamageReduction`. Only *The Fortress* moves it.
  double damageReductionCapBonus = 0;

  /// Above 1.0 means the player takes *more*. *Hollow Bones* (#109) pays for
  /// its speed here.
  double damageTakenMultiplier = 1.0;

  double thornsReflect = 0;
  double lifesteal = 0;
  double shieldPerMomentum = 0;
  double regenWhileMoving = 0;
  double healOnRoomClear = 0;

  /// Arrows added to each shot by *Split Shot* (#10) and *Twin Nock* (#17).
  int extraArrows = 0;

  /// What each arrow in a multi-arrow volley is worth. Below 1.0 whenever
  /// [extraArrows] is above zero — the volley pays for itself per arrow.
  double volleyDamageMultiplier = 1.0;

  /// Auto-fire is on whenever a target exists — the player never taps to shoot.
  bool autoFire = true;

  /// Incoming damage multiplier from the player's own build, right now.
  ///
  /// Mitigation sources are combined **multiplicatively and capped**, never
  /// summed: three 40 % sources summed would reach 120 % and heal the player
  /// (docs/04 §4.1 rule 2). Momentum and the stationary bonus are live, so this
  /// is a getter rather than a stored field — caching it would go stale the
  /// moment the player moved.
  double get incomingDamageFactor {
    // *Last Stand* (T3a) — below 25 % HP, +40 % damage reduction. Read live
    // here for the same reason Momentum's own bonus is: it changes with
    // every hit taken, not once per room.
    double lastStandReduction = 0;
    if (hero.has(HeroBehaviour.thaneLastStand) && !player.isNone) {
      final int p = player.index;
      final double maxHp = entities.maxHealth[p];
      if (maxHp > 0 && entities.health[p] / maxHp < _thaneLowHealthThreshold) {
        lastStandReduction = _thaneLastStandReduction;
      }
    }

    final double remaining = (1.0 - _clamp01(boonDamageReduction)) *
        (1.0 - _clamp01(combat.playerStationary ? stationaryDamageReduction : 0)) *
        (1.0 - _clamp01(playerDraw.damageReduction)) *
        (1.0 - _clamp01(lastStandReduction));

    double total = 1.0 - remaining;
    // *The Fortress* set is the only thing in the game allowed to lift this,
    // and it lifts it by seven points. docs/04 §4.1 rule 2 exists because
    // additive DR reaches 100 % and heals the player.
    final double cap =
        DamageResolver.maxDamageReduction + damageReductionCapBonus;
    if (total > cap) total = cap;
    return (1.0 - total) * damageTakenMultiplier;
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  // ── Room context ──────────────────────────────────────────────────────────

  /// Absolute HP of a x1.0 enemy in this room, from `Curves.enemyHp`. Resolved
  /// once per room rather than per spawn.
  double enemyHpBase = 44.0;

  /// 1-based global stage index. Set by the run coordinator.
  int globalStage = 1;

  /// Contact-capable enemies allowed on screen at once. Lowered on Battery
  /// tier (docs/19 §19.4).
  int enemyCap = SimConfig.maxContactEnemies;

  /// True on ticks the player released an arrow. The Echo mirrors it.
  bool _playerFiredThisTick = false;

  /// Ceiling on arrows released in a single tick, so a pathological fire-rate
  /// multiplier cannot exhaust the entity pool in one frame.
  static const int _maxShotsPerTick = 4;

  /// Distance covered since the last *Kiting* trigger. See
  /// [CombatModifiers.movedRecentlyDistance].
  double _movedDistance = 0;

  /// Seconds the player is rooted by their own *Quiverfall* (#112) arrow.
  double _stunRemaining = 0;

  double _fireCooldown = 0;

  /// Monotonic per-arrow trail id. Confluence dedupes by trail, so every arrow
  /// needs its own.
  int _nextTrailId = 1;

  int _tickCount = 0;
  double _elapsed = 0;

  int get tickCount => _tickCount;

  double get elapsedSeconds => _elapsed;

  /// Crit rolls draw from their own stream, so adding a Boon that crits never
  /// shifts the enemy compositions a seeded run produces.
  late final Rng _critRng = _rng.split(_critRngLabel);

  static const int _critRngLabel = 0xC217;

  /// Mirelle's Reflection rolls draw from their own stream, for the same
  /// reason crits do — a hero whose kit is entirely "how many extra rolls
  /// happened this shot" must not perturb anything else's seeded sequence.
  late final Rng _mirelleDuplicateRng = _rng.split(_mirelleDuplicateRngLabel);

  static const int _mirelleDuplicateRngLabel = 0x11201E;

  /// The *Echoing* affix's own proc rolls draw from their own stream too —
  /// same reasoning as Mirelle's Reflection, which this otherwise mirrors:
  /// an arrow's own trinkets should not perturb anything else's seeded
  /// sequence.
  late final Rng _echoRng = _rng.split(_echoRngLabel);

  static const int _echoRngLabel = 0xEC40;

  /// Sub-generator access, so each subsystem draws from an independent stream.
  ///
  /// Without this, adding one extra Boon draw would shift every subsequent
  /// enemy composition — making balance changes non-reproducible and replays
  /// fragile. See [Rng.split].
  Rng rngFor(int subsystem) => _rng.split(subsystem);

  /// The shared generator, for systems that are content to consume the main
  /// stream in a fixed order.
  Rng get rng => _rng;

  /// Advances exactly one fixed step.
  ///
  /// [dt] is passed rather than read from [SimConfig] so tests can prove the
  /// systems are dt-correct, but production always passes
  /// [SimConfig.fixedStep].
  void tick(InputSnapshot input, {double dt = SimConfig.fixedStep}) {
    // ── input ──────────────────────────────────────────────────────────────
    final bool wantsToMove = input.isMoving;
    _playerFiredThisTick = false;
    _applyInput(input);
    if (input.dashRequested) _applyDash(input, dt);

    // ── movement ───────────────────────────────────────────────────────────
    MovementSystem.update(entities, arena, dt);

    // ── draw / momentum ────────────────────────────────────────────────────
    // After movement, so the Draw responds to motion that actually happened.
    // A player pinned against a wall is standing still and should ramp.
    //
    // Bellweather's own "Draw inverted so moving charges it" toll (docs/06
    // §6.2, ADR 0064) flips only this call's own `isMoving` — `wantsToMove`
    // itself stays unflipped for every other reader below (Kiting's own
    // distance odometer, First Blood's window), since the card names the
    // Draw specifically, not movement-derived state generally.
    DrawSystem.update(
      playerDraw,
      playerDraw.drawChargesWhileMoving ? !wantsToMove : wantsToMove,
      dt,
      events,
      perpetual: boons.has(BoonBehaviour.perpetual),
    );

    // ── build state that changes every tick ────────────────────────────────
    // Read by the hit path. Updated here, right after Draw, so a hit resolved
    // later this tick sees the movement the player made *this* tick rather
    // than last tick's.
    combat
      ..playerStationary = !wantsToMove
      ..momentumStacks = playerDraw.momentumStacks;

    if (wantsToMove) {
      _movedDistance += playerMoveSpeed * (1.0 + playerDraw.moveSpeedBonus) * dt;
      if (_movedDistance >= CombatModifiers.movedRecentlyDistance) {
        _movedDistance = 0;
        combat.movedRecentlyRemaining = CombatModifiers.movedRecentlyWindow;
      }
    } else {
      // *Kiting* pays for ground covered, so the odometer resets when the
      // player stops rather than banking a part-completed run across a pause.
      _movedDistance = 0;
    }
    if (combat.movedRecentlyRemaining > 0) {
      combat.movedRecentlyRemaining -= dt;
    }
    if (_stunRemaining > 0) _stunRemaining -= dt;
    if (hero.flurryRemaining > 0) {
      hero.flurryRemaining -= dt;
      if (hero.flurryRemaining < 0) hero.flurryRemaining = 0;
    }
    if (hero.firstBloodSpeedRemaining > 0) {
      hero.firstBloodSpeedRemaining -= dt;
      if (hero.firstBloodSpeedRemaining < 0) hero.firstBloodSpeedRemaining = 0;
    }
    if (hero.prismRemaining > 0) {
      hero.prismRemaining -= dt;
      if (hero.prismRemaining < 0) hero.prismRemaining = 0;
    }
    if (hero.bloomRemaining > 0) {
      hero.bloomRemaining -= dt;
      if (hero.bloomRemaining < 0) hero.bloomRemaining = 0;
      if (hero.bloomHealPerSecond > 0 && !player.isNone) {
        final int p = player.index;
        final double cap = entities.maxHealth[p];
        final double healed =
            entities.health[p] + cap * hero.bloomHealPerSecond * dt;
        if (healed > cap) {
          entities.health[p] = cap;
          _applyLiraOverheal(healed - cap, cap);
        } else {
          entities.health[p] = healed;
        }
      }
    }
    if (hero.redDrawRemaining > 0) {
      hero.redDrawRemaining -= dt;
      if (hero.redDrawRemaining < 0) hero.redDrawRemaining = 0;
    }
    if (hero.tempestNockRemaining > 0) {
      hero.tempestNockRemaining -= dt;
      if (hero.tempestNockRemaining < 0) hero.tempestNockRemaining = 0;
    }
    if (hero.caromsRemaining > 0) {
      hero.caromsRemaining -= dt;
      if (hero.caromsRemaining < 0) hero.caromsRemaining = 0;
    }
    if (hero.hallOfMirrorsRemaining > 0) {
      hero.hallOfMirrorsRemaining -= dt;
      if (hero.hallOfMirrorsRemaining < 0) hero.hallOfMirrorsRemaining = 0;
    }
    if (hero.umbralStepRemaining > 0) {
      hero.umbralStepRemaining -= dt;
      if (hero.umbralStepRemaining < 0) hero.umbralStepRemaining = 0;
    }
    if (hero.ashlinInvulnRemaining > 0) {
      hero.ashlinInvulnRemaining -= dt;
      if (hero.ashlinInvulnRemaining < 0) hero.ashlinInvulnRemaining = 0;
    }
    if (hero.aegisPinRemaining > 0) {
      hero.aegisPinRemaining -= dt;
      if (hero.aegisPinRemaining < 0) hero.aegisPinRemaining = 0;
    }

    // ── collision (broad phase) ────────────────────────────────────────────
    // Rebuilt after movement so queries see this tick's positions, not last
    // tick's. Every later system's neighbour lookups depend on that ordering.
    spatial.rebuild(entities);

    // ── firing ─────────────────────────────────────────────────────────────
    _updateFiring(dt);

    // ── ultimate ───────────────────────────────────────────────────────────
    // After ordinary firing, before the projectile step, so an ultimate that
    // spawns arrows (Wren's Volley Fan) has them processed this same tick —
    // exactly the ordering ordinary volleys already get.
    _updateUltimate(input);

    // Sable's *Miasma* — a fixed cloud, not a buff on the player, so it ticks
    // here rather than in the plain countdown block above: it needs a fresh
    // [spatial] (rebuilt just above) to find who is standing in it, exactly
    // like `_fireSelaGlacierNail`'s own target selection does.
    _tickSableMiasma(dt);
    _tickKadePyreLine(dt);
    _tickRookCrush(dt);
    _tickRookSingularity(dt);
    _tickIrisLattice(dt);

    // Index the trails before projectiles move, so Confluence queries see this
    // tick's lines.
    windlineIndex.rebuild(windlines);

    // ── projectiles ────────────────────────────────────────────────────────
    ProjectileSystem.update(
      store: entities,
      projectiles: projectiles,
      spatial: spatial,
      arena: arena,
      events: events,
      lines: windlines,
      lineIndex: windlineIndex,
      now: _elapsed,
      maxConfluenceStacks: maxConfluenceStacks,
      windlineHitWidth: windlineHitWidth,
      windlineDuration: windlineDuration,
      segmentLength: windlineSegmentLength,
      dt: dt,
      enemies: enemies,
      status: status,
      combat: combat,
      boons: boons,
      hero: hero,
      player: player.isNone ? -1 : player.index,
      lifesteal: lifesteal,
      // *Perfect Flurry* doubles Confluence damage for its own window only —
      // read live here rather than baked into the room-scoped
      // confluenceDamageMultiplier field, the same split Flurry's fire-rate
      // multiplier already uses.
      confluenceDamageMultiplier: confluenceDamageMultiplier *
          (hero.flurryRemaining > 0 &&
                  hero.has(HeroBehaviour.kestrelPerfectFlurry)
              ? _kestrelPerfectFlurryConfluenceMultiplier
              : 1.0),
    );

    // ── windline expiry ────────────────────────────────────────────────────
    // *The Loom* (#75) — trails never expire inside a room. Skipping the pass
    // rather than setting an enormous expiry, so lines still clear at the room
    // boundary without needing to be found and fixed up.
    if (!boons.has(BoonBehaviour.theLoom)) {
      windlines.expire(_elapsed);
    }

    // ── elements ───────────────────────────────────────────────────────────
    // Before the AI, so a DoT kills on the tick it should rather than one late,
    // and so it sees damage already applied by projectiles this tick. Corpses
    // are left for the AI's death pass, which is the one place a death can mean
    // a detonation, a revival or a split.
    ElementSystem.update(
      store: entities,
      status: status,
      events: events,
      dt: dt,
      deferDeath: true,
      hero: hero,
      enemies: enemies,
    );

    // ── boss phases ────────────────────────────────────────────────────────
    // After elements, for the identical reason: a DoT tick can cross a phase
    // threshold exactly like a direct hit can, and this needs to see that
    // damage already applied. Before the AI, so a boss's own family tree
    // reads this tick's phase, not last tick's.
    BossPhaseSystem.update(
      store: entities,
      enemies: enemies,
      content: content,
      events: events,
    );

    // ── ai ─────────────────────────────────────────────────────────────────
    _refreshAiContext(dt);

    // Each boss's own bespoke mechanic shares `SystemOrder.bossPhase`'s slot
    // rather than claiming a new entry per archetype — see
    // `CinderChoirSystem`'s own doc comment. After `_refreshAiContext`,
    // because the tether sweep (P2) needs `AiContext`'s player-facing
    // helpers (`EnemyAttack.playerOnLine`, `damagePlayer`), the same object
    // every other enemy's own attack logic already runs on; before
    // `AiSystem.update`, so an ordinary enemy's own tree never reads a boss
    // reaction that hasn't happened yet this tick.
    CinderChoirSystem.update(ai);
    AshenChoirSystem.update(ai);
    BellweatherSystem.update(ai);
    PaleJudgeSystem.update(ai);
    UmbralTwinSystem.update(ai);
    SkarnSystem.update(ai);
    GauntSystem.update(ai);
    SilversongSystem.update(ai);
    VermillionSystem.update(ai);
    RimefatherSystem.update(ai);
    ArclightSystem.update(ai);
    GreenMotherSystem.update(ai);
    ThrallOfNineSystem.update(ai);
    WeepingGateSystem.update(ai);
    HollowWardenSystem.update(ai);
    TheQuiverfallSystem.update(ai);
    MotherOfMotesSystem.update(ai);
    TheLoomSystem.update(ai);
    CoilspineSystem.update(ai);
    LastWardenSystem.update(ai);

    // Not a boss — a friendly companion — but the identical "resolve
    // before the generic death/reap pass" ordering applies: a companion's
    // own hit can kill an enemy this same tick.
    CompanionSystem.update(ai, companions);

    AiSystem.update(ai);

    // *Rekindle* — the revive itself happens inside AiSystem's own call to
    // EnemyAttack.damagePlayer, which has no playerAttack/spatial/entities
    // to resolve an AoE with; the nova is applied here instead, the first
    // point after the revive where all three are available together.
    if (hero.rekindleNovaPending) {
      hero.rekindleNovaPending = false;
      _applyPlayerCenteredNova(_ashlinRekindleNovaMultiplier);
    }

    // *Riposte* — the shield-break itself is detected inside
    // EnemyAttack.damagePlayer's own shield-consumption block, which has
    // the same missing playerAttack/spatial/entities trio; resolved here
    // for the identical reason Rekindle's own nova is, right above.
    if (hero.riposteNovaPending) {
      hero.riposteNovaPending = false;
      _applyPlayerCenteredNova(_ovrinRiposteMultiplier);
    }

    // ── hazards ────────────────────────────────────────────────────────────
    HazardSystem.update(ai);

    // ── spawning ───────────────────────────────────────────────────────────
    final bool wasRoomCleared = spawnState.roomClearedEmitted;
    SpawnSystem.update(ai, spawnState);
    // *Ember Body* (Ashlin, T3a) — 3 s of invulnerability after any room
    // clear, not just Rekindle's own revive. `roomClearedEmitted` only ever
    // flips false → true once per room, so this is the rising edge.
    if (!wasRoomCleared &&
        spawnState.roomClearedEmitted &&
        hero.has(HeroBehaviour.ashlinEmberBody)) {
      hero.ashlinInvulnRemaining = _ashlinInvulnDuration;
    }

    // ── boons ──────────────────────────────────────────────────────────────
    // The Windline field first: Tangle's slow has to land before the AI reads
    // it next tick, and Cutting Lines' damage has to land before the death pass.
    for (int i = 0; i < entities.highWater; i++) {
      enemies.windlineSlowFactor[i] = 1.0;
    }
    BoonSystem.applyWindlineField(
      boons: boons,
      entities: entities,
      enemies: enemies,
      lines: windlines,
      index: windlineIndex,
      slow: windlineSlow,
      damageFraction: windlineDamageFraction,
      dt: dt,
      hasShadowline: hero.has(HeroBehaviour.nyxShadowline),
      hasPhoenixTrail: hero.has(HeroBehaviour.ashlinPhoenixTrail),
    );

    // After everything that could have changed the player's state this frame,
    // so a Momentum shield is sized from this tick's stacks and a Blood Pact
    // instalment lands on health the AI has already touched.
    BoonSystem.update(
      boons: boons,
      entities: entities,
      draw: playerDraw,
      events: events,
      player: player.isNone ? -1 : player.index,
      isMoving: playerDraw.wasMovingLastTick,
      maxHealth: player.isNone ? 1 : entities.maxHealth[player.index],
      shieldPerMomentum: shieldPerMomentum,
      regenWhileMoving: regenWhileMoving,
      dt: dt,
    );

    // ── cleanup ────────────────────────────────────────────────────────────
    telegraphs.expire(_elapsed);
    _tickCount++;
    _elapsed += dt;
  }

  /// Copies this tick's world state into the AI's context.
  ///
  /// One place, once per tick. Behaviour trees read the player's position two
  /// dozen times each; resolving it per read would mean two dozen liveness
  /// checks and two dozen chances to disagree about whether the player exists.
  void _refreshAiContext(double dt) {
    ai
      ..dt = dt
      ..now = _elapsed
      ..enemyHpBase = enemyHpBase
      ..globalStage = globalStage
      ..enemyCap = enemyCap
      ..playerDraw = playerDraw
      ..hollowWardenDraw = hollowWardenDraw
      ..lastWardenDraw = lastWardenDraw
      ..playerFired = _playerFiredThisTick;

    if (player.isNone || !entities.isAlive(player)) {
      ai.player = -1;
      return;
    }

    final int p = player.index;
    ai
      ..player = p
      ..playerX = entities.posX[p]
      ..playerY = entities.posY[p]
      ..playerVelX = entities.velX[p]
      ..playerVelY = entities.velY[p]
      ..playerRadius = entities.radius[p]
      ..playerMaxHealth = entities.maxHealth[p]
      ..playerAttack = playerAttack
      ..boons = boons
      ..combat = combat
      ..hero = hero
      ..incomingDamageFactor = incomingDamageFactor
      ..thornsReflect = thornsReflect
      ..now = _elapsed
      ..echoLineDuration = windlineDuration;
  }

  void _updateFiring(double dt) {
    if (player.isNone || !entities.isAlive(player)) return;
    if (!autoFire) return;

    _fireCooldown -= dt;
    if (_fireCooldown > 0) return;

    final int p = player.index;
    final double fromX = entities.posX[p];
    final double fromY = entities.posY[p];

    final int target = FiringSystem.selectTarget(
      entities,
      spatial,
      fromX,
      fromY,
      enemies: enemies,
    );

    // No target, no shot. The bow is auto-fire, not auto-waste: loosing arrows
    // into an empty room consumes entity slots, emits pointless events, and
    // reads as a bug to anyone watching. It also means a cleared room is
    // visually quiet, which is what makes the next spawn land.
    if (target < 0) {
      // Hold the cooldown at zero so the first arrow at a new target is
      // immediate rather than owing a backlog of missed shots.
      if (_fireCooldown < 0) _fireCooldown = 0;
      return;
    }

    // *Perfect Form* (#23) resolves every shot as Tier III. The Draw meter still
    // animates — removing it would make the player think the mechanic broke.
    // Kestrel's *Flurry* forces the same override for its own duration — that
    // is also the entire mechanism behind "movement no longer drops the tier":
    // the effective tier stops reading `playerDraw.tier` at all while it runs.
    // *Crimson Draw* (T5b) forces the same override for Red Draw's own
    // window — a talent-gated addition on top of the Ultimate, not a
    // property of Red Draw itself, since the base Ultimate never touches
    // the tier.
    final DrawTier tier = boons.has(BoonBehaviour.perfectForm) ||
            hero.flurryRemaining > 0 ||
            (hero.redDrawRemaining > 0 &&
                hero.has(HeroBehaviour.thaneCrimsonDraw))
        ? DrawTier.three
        : playerDraw.tier;

    // *Runner's High* (#55) pays out only at max Momentum, so it is read here
    // rather than composed into fireRateMultiplier — the multiplier is settled
    // once per room and this changes several times a second. Flurry's rate is
    // the same shape: a live multiplier for its own window, not baked into
    // the room-scoped `fireRateMultiplier`.
    double rate = fireRateMultiplier;
    if (boons.has(BoonBehaviour.runnersHigh) && playerDraw.isAtMaxMomentum) {
      rate *= BoonRuntime.runnersHighFireRate;
    }
    if (hero.flurryRemaining > 0) rate *= hero.flurryRateMultiplier;
    if (hero.redDrawRemaining > 0) rate *= hero.redDrawFireRateMultiplier;

    // *Frenzy* (T3b) — below 25 % HP, +50 % fire rate. The player's own
    // health fraction, read live since it changes every hit rather than
    // once per room.
    if (hero.has(HeroBehaviour.thaneFrenzy) && !player.isNone) {
      final int p = player.index;
      final double maxHp = entities.maxHealth[p];
      if (maxHp > 0 &&
          entities.health[p] / maxHp < _thaneLowHealthThreshold) {
        rate *= 1.0 + _thaneFrenzyFireRateBonus;
      }
    }

    final double interval = FiringSystem.intervalFor(tier, rate);

    // Accumulator, not a reset-to-zero timer: at very high fire rates one tick
    // can legitimately owe more than one arrow, and clamping would silently cap
    // Kestrel's Flurry at 60 shots per second.
    int shots = 1 + (-_fireCooldown / interval).floor();
    if (shots > _maxShotsPerTick) shots = _maxShotsPerTick;
    _fireCooldown += interval * shots;

    // *Blind Fury* (#108) buys fire rate by switching aim assist off. The cost
    // is the point and it is printed on the card — docs/09 §9.2 G.
    final AimAssist assist =
        boons.has(BoonBehaviour.blindFury) ? AimAssist.off : aimAssist;

    double angle = FiringSystem.aimAngle(
      entities,
      target,
      fromX,
      fromY,
      entities.facing[p],
      assist,
      projectileSpeed,
    );

    // *Trueshot* — Tier III shots gain a mild homing correction onto a moving
    // target, on top of whatever the base aim assist already resolved.
    if (tier == DrawTier.three && hero.has(HeroBehaviour.wrenTrueshot)) {
      angle = _wrenTrueshotAngle(angle, target, fromX, fromY, entities.facing[p]);
    }

    for (int s = 0; s < shots; s++) {
      _spawnVolley(fromX, fromY, angle, tier);
    }
    _playerFiredThisTick = true;
  }

  /// *Trueshot*'s "mild homing (12°)": leads the target the way
  /// [AimAssist.strong] would, but the correction away from the ordinary
  /// aim angle is capped at 12° rather than applied in full — a nudge, not a
  /// lock.
  double _wrenTrueshotAngle(
    double standardAngle,
    int target,
    double fromX,
    double fromY,
    double facing,
  ) {
    final double leadAngle = FiringSystem.aimAngle(
      entities,
      target,
      fromX,
      fromY,
      facing,
      AimAssist.strong,
      projectileSpeed,
    );

    double delta = leadAngle - standardAngle;
    // Normalise to (-pi, pi] first, so a wraparound near +-180 deg is read as
    // the short turn rather than the long way around.
    while (delta > math.pi) {
      delta -= math.pi * 2;
    }
    while (delta < -math.pi) {
      delta += math.pi * 2;
    }
    if (delta > _wrenTrueshotMaxCorrection) delta = _wrenTrueshotMaxCorrection;
    if (delta < -_wrenTrueshotMaxCorrection) delta = -_wrenTrueshotMaxCorrection;
    return standardAngle + delta;
  }

  /// 12°, in radians — docs/07 §7.0's own figure for Trueshot's homing cone.
  static const double _wrenTrueshotMaxCorrection = math.pi / 15;

  /// The manual Ultimate button. Charges from damage dealt
  /// ([HeroRuntime.chargeFromDamage], called from [ProjectileSystem]); firing
  /// it is entirely this method's concern.
  ///
  /// Never auto-casts — docs/07 §7.0 is explicit that this is "a single large
  /// button, right thumb", not a payoff the sim decides to spend on the
  /// player's behalf.
  void _updateUltimate(InputSnapshot input) {
    if (hero.consumeJustBecameReady()) {
      events.emit(
        SimEventType.ultimateReady,
        entityA: player.isNone ? -1 : player.index,
      );
    }

    if (!input.ultimatePressed) return;
    if (!hero.ultimateReady) return;
    if (player.isNone || !entities.isAlive(player)) return;

    _fireUltimate();
    hero.ultimateCharge = 0;
    events.emit(SimEventType.ultimateUsed, entityA: player.index);
  }

  /// Dispatches to whichever hero's ultimate behaviour is live. Exactly one
  /// hero is ever equipped, so exactly one branch below ever fires for a
  /// given world — this is a switch on identity, not a stack of effects.
  void _fireUltimate() {
    if (hero.has(HeroBehaviour.wrenVolleyFan)) {
      _fireWrenVolleyFan();
    } else if (hero.has(HeroBehaviour.kestrelFlurry)) {
      _fireKestrelFlurry();
    } else if (hero.has(HeroBehaviour.orielPrism)) {
      // *White Light* (T5b) is not handled here: its duration change is free,
      // but "reactions deal x3" needs Reaction/elementalBonus damage wiring
      // that does not exist anywhere yet (see the ledger's own note on
      // orielAttuned/orielResonance), and shipping the duration half alone
      // would be a card that promises x3 and does not deliver it.
      hero.prismRemaining = hero.has(HeroBehaviour.orielEndlessPrism)
          ? _orielEndlessPrismDuration
          : HeroRuntime.prismDuration;
    } else if (hero.has(HeroBehaviour.vanePiercingHorizon)) {
      _fireVanePiercingHorizon();
    } else if (hero.has(HeroBehaviour.haldenJudgmentSpear)) {
      _fireHaldenJudgmentSpear();
    } else if (hero.has(HeroBehaviour.liraVerdantBloom)) {
      _fireLiraVerdantBloom();
    } else if (hero.has(HeroBehaviour.thaneRedDraw)) {
      _fireThaneRedDraw();
    } else if (hero.has(HeroBehaviour.torvTempestNock)) {
      hero.tempestNockRemaining = hero.has(HeroBehaviour.torvLongTempest)
          ? _torvLongTempestDuration
          : _torvTempestNockDuration;
    } else if (hero.has(HeroBehaviour.selaGlacierNail)) {
      _fireSelaGlacierNail();
    } else if (hero.has(HeroBehaviour.sableMiasma)) {
      _fireSableMiasma();
    } else if (hero.has(HeroBehaviour.kadePyreLine)) {
      _fireKadePyreLine();
    } else if (hero.has(HeroBehaviour.nyxUmbralStep)) {
      _fireNyxUmbralStep();
    } else if (hero.has(HeroBehaviour.ashlinRebirthNova)) {
      _fireAshlinRebirthNova();
    } else if (hero.has(HeroBehaviour.corvinCaroms)) {
      // A pure timed self-buff, the same shape as Tempest Nock above:
      // every arrow spawned while `caromsRemaining` reads above zero picks
      // up the raised ricochet count in `_spawnArrow`.
      hero.caromsRemaining = hero.has(HeroBehaviour.corvinEndlessCarom)
          ? _corvinEndlessCaromDuration
          : HeroRuntime.caromsDuration;
    } else if (hero.has(HeroBehaviour.zeaFalconry)) {
      _fireZeaFalconry();
    } else if (hero.has(HeroBehaviour.mirelleHallOfMirrors)) {
      _fireMirelleHallOfMirrors();
    } else if (hero.has(HeroBehaviour.ovrinAegisPin)) {
      _fireOvrinAegisPin();
    } else if (hero.has(HeroBehaviour.rookSingularity)) {
      _fireRookSingularity();
    } else if (hero.has(HeroBehaviour.irisTheLattice)) {
      _fireIrisTheLattice();
    }
  }

  /// *Aegis Pin* — "plants a shield wall that blocks all enemy projectiles
  /// for 6 s and reflects 30 % of blocked damage as Storm" (docs/07 §7.3).
  /// The sim has no standalone enemy-projectile entity to intercept, so
  /// this reads "blocks all enemy projectiles" as "blocks every hit that
  /// would otherwise land" — the identical "ignore the hit outright" shape
  /// already used for Umbral Step and Ashlin's own invulnerability — and
  /// resolves entirely as a timed flag plus a reflect share, both read in
  /// `EnemyAttack.damagePlayer`. *Long Wall* (T5a) and *Mirror Wall* (T5b)
  /// are this Ultimate's own two mutually-exclusive ★5 branches.
  void _fireOvrinAegisPin() {
    hero.aegisPinRemaining = hero.has(HeroBehaviour.ovrinLongWall)
        ? _ovrinLongWallDuration
        : hero.has(HeroBehaviour.ovrinMirrorWall)
            ? _ovrinMirrorWallDuration
            : _ovrinAegisPinDuration;
  }

  static const double _ovrinAegisPinDuration = 6.0;
  static const double _ovrinLongWallDuration = 10.0;
  static const double _ovrinMirrorWallDuration = 3.0;
  static const double _ovrinRiposteMultiplier = 2.00;

  /// *Falconry* — "summons 4 hawks for 12 s" (docs/07 §7.3). Temporary
  /// companions, the same primitive Zea's own passive Skyhawk already
  /// uses (`CompanionSystem`, ADR 0071) — these simply carry a finite
  /// `lifetimeSeconds` instead of the passive's own permanent one, so
  /// `HeroLoadoutResolver`'s own despawn-and-resync sweep (ADR 0072) never
  /// touches them.
  ///
  /// *Sharper Talons*/*Swift Hawk*/*Bonded* all read as blanket "your
  /// hawks are better" rules (ADR 0072's own reasoning), so they apply to
  /// these summoned hawks too. *Skydarken* (★5a) and *Great Hawk* (★5b)
  /// are this Ultimate's own two branches, never both active. Great
  /// Hawk's own "taunts" is not built — nothing in this roster has ever
  /// redirected enemy targeting away from the player (ADR 0071's own
  /// flagged gap); its stat half (1 hawk, 250 % ATK, 20 s) is real.
  void _fireZeaFalconry() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    final double x = entities.posX[p];
    final double y = entities.posY[p];

    final bool bonded = hero.has(HeroBehaviour.zeaBonded);
    final double fireRate = hero.has(HeroBehaviour.zeaSwiftHawk)
        ? _zeaSwiftHawkFireRate
        : _zeaBaseFireRate;

    if (hero.has(HeroBehaviour.zeaGreatHawk)) {
      spawnCompanion(
        x,
        y,
        damageShare: _zeaGreatHawkShare,
        fireRate: fireRate,
        lifetimeSeconds: _zeaGreatHawkDuration,
        alwaysCrit: bonded,
      );
      return;
    }

    final double damageShare = hero.has(HeroBehaviour.zeaSharperTalons)
        ? _zeaSharperTalonsShare
        : _zeaBaseDamageShare;
    final int count = hero.has(HeroBehaviour.zeaSkydarken)
        ? _zeaSkydarkenHawkCount
        : _zeaFalconryHawkCount;

    for (int i = 0; i < count; i++) {
      final double angle = 2 * math.pi * i / count;
      final double offsetX = math.cos(angle) * _zeaFalconrySpreadRadius;
      final double offsetY = math.sin(angle) * _zeaFalconrySpreadRadius;
      spawnCompanion(
        x + offsetX,
        y + offsetY,
        damageShare: damageShare,
        fireRate: fireRate,
        lifetimeSeconds: _zeaFalconryDuration,
        alwaysCrit: bonded,
        followOffsetX: offsetX,
        followOffsetY: offsetY,
      );
    }
  }

  /// docs/07's own stated numbers — mirrors `HeroLoadoutResolver`'s own
  /// identical constants (small, independent copies rather than a shared
  /// public surface for four plain doubles, the same posture this
  /// roster's own parametric-math duplicates already take, ADR 0057).
  static const double _zeaBaseDamageShare = 0.35;
  static const double _zeaSharperTalonsShare = 0.50;
  static const double _zeaBaseFireRate = 1.5;
  static const double _zeaSwiftHawkFireRate = 2.4;
  static const int _zeaFalconryHawkCount = 4;
  static const int _zeaSkydarkenHawkCount = 8;
  static const double _zeaFalconryDuration = 12.0;
  static const double _zeaGreatHawkShare = 2.50;
  static const double _zeaGreatHawkDuration = 20.0;

  /// Authored — docs/07 states no formation radius for Falconry's own
  /// flock, so the summoned hawks spread evenly around the player rather
  /// than stacking on one point, the same reasoning the passive Skyhawk's
  /// own follow offset already uses.
  static const double _zeaFalconrySpreadRadius = 1.2;

  static const double _corvinEndlessCaromDuration = 10.0;

  static const double _torvTempestNockDuration = 5.0;
  static const double _torvLongTempestDuration = 8.0;

  static const double _orielEndlessPrismDuration = 16.0;

  /// *Red Draw* — costs a real slice of current HP up front (floored at 1,
  /// the same guard *Bloodprice* uses, so the button is never a literal
  /// suicide press), then a timed self-buff read every tick like Flurry and
  /// Bloom rather than applied once here. *Long Red* (T5a) only changes the
  /// duration; *Crimson Draw* (T5b) is checked separately, in
  /// `_updateFiring`, since it forces the tier rather than changing a number
  /// here.
  void _fireThaneRedDraw() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    final double cost = entities.health[p] * _thaneRedDrawHpCostFraction;
    final double after = entities.health[p] - cost;
    entities.health[p] = after < 1.0 ? 1.0 : after;

    hero.redDrawRemaining = hero.has(HeroBehaviour.thaneLongRed)
        ? _thaneLongRedDuration
        : _thaneRedDrawDuration;
    hero.redDrawDamageBonus = _thaneRedDrawDamageBonus;
    hero.redDrawFireRateMultiplier = 1.0 + _thaneRedDrawFireRateBonus;
  }

  static const double _thaneRedDrawHpCostFraction = 0.20;
  static const double _thaneRedDrawDuration = 6.0;
  static const double _thaneLongRedDuration = 10.0;
  static const double _thaneRedDrawDamageBonus = 1.20;
  static const double _thaneRedDrawFireRateBonus = 0.30;

  /// Below this HP fraction, both T3 talents (Last Stand, Frenzy) kick in.
  static const double _thaneLowHealthThreshold = 0.25;
  static const double _thaneFrenzyFireRateBonus = 0.50;
  static const double _thaneLastStandReduction = 0.40;

  /// *Verdant Bloom* — a timed self-buff like Flurry, not a burst: a heal
  /// rate and a damage bonus, both read every tick rather than applied once
  /// here. *Blood Bloom* (T5b) is a full replacement — no heal at all, its
  /// own higher damage bonus in place of the base +25 % — the same
  /// full-replacement shape Focused Fan and Twin Spear already use for a
  /// mutually exclusive branch.
  void _fireLiraVerdantBloom() {
    if (hero.has(HeroBehaviour.liraBloodBloom)) {
      hero.bloomRemaining = _liraVerdantBloomDuration;
      hero.bloomHealPerSecond = 0;
      hero.bloomDamageBonus = _liraBloodBloomDamageBonus;
    } else if (hero.has(HeroBehaviour.liraEndlessBloom)) {
      hero.bloomRemaining = _liraEndlessBloomDuration;
      hero.bloomHealPerSecond =
          _liraEndlessBloomHealFraction / _liraEndlessBloomDuration;
      hero.bloomDamageBonus = _liraVerdantBloomDamageBonus;
    } else {
      hero.bloomRemaining = _liraVerdantBloomDuration;
      hero.bloomHealPerSecond =
          _liraVerdantBloomHealFraction / _liraVerdantBloomDuration;
      hero.bloomDamageBonus = _liraVerdantBloomDamageBonus;
    }
  }

  static const double _liraVerdantBloomDuration = 4.0;
  static const double _liraVerdantBloomHealFraction = 0.40;
  static const double _liraVerdantBloomDamageBonus = 0.25;
  static const double _liraEndlessBloomDuration = 8.0;
  static const double _liraEndlessBloomHealFraction = 0.60;
  static const double _liraBloodBloomDamageBonus = 0.80;

  /// *Overheal* (T3a) — the healing Bloom's own clamp would otherwise waste
  /// becomes a shield instead, capped at 30 % max HP. `ProjectileSystem`
  /// carries an identical block for Lifebound's own lifesteal — no shared
  /// heal-clamp helper exists anywhere in the sim (see that file's own copy
  /// of this constant for why), so this one covers only what happens inside
  /// `SimWorld`'s own tick. ADR 0016 covers the full scope decision.
  static const double _liraOverhealShieldCap = 0.30;

  void _applyLiraOverheal(double overflow, double maxHealth) {
    if (!hero.has(HeroBehaviour.liraOverheal)) return;
    final double cap = maxHealth * _liraOverhealShieldCap;
    final double newShield = hero.overhealShield + overflow;
    hero.overhealShield = newShield > cap ? cap : newShield;
  }

  /// *Glacier Nail* — a direct freeze at the nearest target (the same
  /// selection [FiringSystem.selectTarget] already uses to aim every other
  /// targeted ultimate), skipping the Chill accumulator entirely rather than
  /// dumping a huge Chill value into it. *Absolute Zero* (T5a) raises both
  /// the radius and the duration; *Cascading Nail* (T5b) is a separate
  /// chain pass to the 3 nearest enemies the initial freeze did not reach,
  /// mirroring Arc's own "nearest N via insertion" shape.
  void _fireSelaGlacierNail() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;

    final int target = FiringSystem.selectTarget(
      entities,
      spatial,
      entities.posX[p],
      entities.posY[p],
      enemies: enemies,
    );
    if (target < 0) return;

    final double cx = entities.posX[target];
    final double cy = entities.posY[target];
    final bool absoluteZero = hero.has(HeroBehaviour.selaAbsoluteZero);
    final double radius =
        absoluteZero ? _selaAbsoluteZeroRadius : _selaGlacierNailRadius;
    final double duration =
        absoluteZero ? _selaAbsoluteZeroDuration : _selaGlacierNailDuration;
    final double radiusSq = radius * radius;

    final int found = spatial.queryRadius(cx, cy, radius);
    for (int i = 0; i < found; i++) {
      final int e = spatial.resultAt(i);
      if (entities.alive[e] == 0) continue;
      if (entities.kind[e] != EntityKind.enemy.index) continue;
      final double dx = entities.posX[e] - cx;
      final double dy = entities.posY[e] - cy;
      if (dx * dx + dy * dy > radiusSq) continue;
      status.frozenRemaining[e] = duration;
      status.chill[e] = 0;
    }

    if (hero.has(HeroBehaviour.selaCascadingNail)) {
      _applySelaCascadingNail(cx, cy, duration);
    }
  }

  static const double _selaGlacierNailRadius = 3.5;
  static const double _selaGlacierNailDuration = 3.0;
  static const double _selaAbsoluteZeroRadius = 5.0;
  static const double _selaAbsoluteZeroDuration = 5.0;
  static const int _selaCascadingNailTargets = 3;

  /// Chains Glacier Nail's freeze to the nearest enemies the initial radius
  /// missed. A linear scan, not a second [spatial] query: this runs once per
  /// Ultimate press rather than per hit, so the cost that matters elsewhere
  /// in this file (the reentrancy hazard a nested query would risk inside
  /// [ProjectileSystem]'s own candidate loop) does not apply here — there is
  /// no outer query active at Ultimate-press time. A plain scan is used
  /// anyway, for the same "nearest N via insertion" shape Arc already
  /// established, rather than mixing two different techniques for one hero.
  void _applySelaCascadingNail(double x, double y, double duration) {
    final List<int> nearest =
        List<int>.filled(_selaCascadingNailTargets, -1);
    final List<double> nearestDistSq =
        List<double>.filled(_selaCascadingNailTargets, double.infinity);

    for (int i = 0; i < entities.highWater; i++) {
      if (entities.alive[i] == 0) continue;
      if (entities.kind[i] != EntityKind.enemy.index) continue;
      if (status.isFrozen(i)) continue;
      final double dx = entities.posX[i] - x;
      final double dy = entities.posY[i] - y;
      final double distSq = dx * dx + dy * dy;

      if (distSq >= nearestDistSq[_selaCascadingNailTargets - 1]) continue;
      int slot = _selaCascadingNailTargets - 1;
      while (slot > 0 && nearestDistSq[slot - 1] > distSq) {
        nearestDistSq[slot] = nearestDistSq[slot - 1];
        nearest[slot] = nearest[slot - 1];
        slot--;
      }
      nearestDistSq[slot] = distSq;
      nearest[slot] = i;
    }

    for (final int e in nearest) {
      if (e < 0) continue;
      status.frozenRemaining[e] = duration;
      status.chill[e] = 0;
    }
  }

  /// *Miasma* — a cloud left at the player's position at cast time (docs/07
  /// names no target, unlike Glacier Nail's own "at the target" wording, so
  /// this reads as something dropped rather than aimed), pulsing Toxin onto
  /// whoever stands in it rather than applying a single lump sum. *Lasting
  /// Miasma* (T5a) only changes the duration; *Concentrated Miasma* (T5b)
  /// shrinks the radius but pulses faster — read every tick from
  /// [_tickSableMiasma], not applied once here.
  void _fireSableMiasma() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    hero.miasmaRemaining = hero.has(HeroBehaviour.sableLastingMiasma)
        ? _sableLastingMiasmaDuration
        : _sableMiasmaDuration;
    hero.miasmaX = entities.posX[p];
    hero.miasmaY = entities.posY[p];
    // Zero rather than the full interval, so the cloud's first pulse lands
    // the instant it is cast rather than making the player wait half a
    // second to see it do anything.
    hero.miasmaTickTimer = 0;
  }

  static const double _sableMiasmaDuration = 8.0;
  static const double _sableLastingMiasmaDuration = 14.0;
  static const double _sableMiasmaRadius = 5.0;
  static const double _sableConcentratedMiasmaRadius = 3.0;
  static const double _sableMiasmaStacksPerSecond = 2.0;
  static const double _sableConcentratedMiasmaStacksPerSecond = 5.0;

  /// Mirrors the same two mutually-exclusive T1 caps
  /// [ProjectileSystem._applyHeroInnateElements] and [AiSystem]'s own
  /// Contagion transfer read for Sable's Toxin — kept alongside rather than
  /// shared, since those copies are private and this is the only other place
  /// that needs to know the current cap.
  static const int _sableFastActingMaxStacks = 8;
  static const int _sableVirulenceMaxStacks = 12;

  /// Applies Miasma's periodic Toxin pulse. A direct [spatial] query, not a
  /// linear scan: this runs at most a few times a second, from `tick()`
  /// itself rather than from inside [ProjectileSystem]'s own hit-resolution
  /// loop, so the reentrancy hazard that rules out `queryRadius` there does
  /// not apply here.
  void _tickSableMiasma(double dt) {
    if (hero.miasmaRemaining <= 0) return;
    hero.miasmaRemaining -= dt;
    if (hero.miasmaRemaining < 0) hero.miasmaRemaining = 0;

    hero.miasmaTickTimer -= dt;
    if (hero.miasmaTickTimer > 0) return;

    final bool concentrated = hero.has(HeroBehaviour.sableConcentratedMiasma);
    final double radius =
        concentrated ? _sableConcentratedMiasmaRadius : _sableMiasmaRadius;
    final double stacksPerSecond = concentrated
        ? _sableConcentratedMiasmaStacksPerSecond
        : _sableMiasmaStacksPerSecond;
    hero.miasmaTickTimer += 1.0 / stacksPerSecond;

    final int? maxStacks = hero.has(HeroBehaviour.sableFastActing)
        ? _sableFastActingMaxStacks
        : hero.has(HeroBehaviour.sableVirulence)
            ? _sableVirulenceMaxStacks
            : null;

    final double radiusSq = radius * radius;
    final int found = spatial.queryRadius(hero.miasmaX, hero.miasmaY, radius);
    for (int i = 0; i < found; i++) {
      final int e = spatial.resultAt(i);
      if (entities.alive[e] == 0) continue;
      if (entities.kind[e] != EntityKind.enemy.index) continue;
      final double dx = entities.posX[e] - hero.miasmaX;
      final double dy = entities.posY[e] - hero.miasmaY;
      if (dx * dx + dy * dy > radiusSq) continue;
      if (enemies.resistsElement(e, SimElement.toxin)) continue;
      status.apply(e, SimElement.toxin, toxinMaxStacksOverride: maxStacks);
    }
  }

  /// Rook's *Crush* (T3a) — "grouped enemies take stacking 5 %/s": a
  /// continuous drain re-evaluated a few times a second from each enemy's
  /// *current* neighbours (the same throttled-spatial-query shape
  /// [_tickSableMiasma] already uses, for the identical reason — a
  /// `queryRadius` call is only reentrancy-safe outside `ProjectileSystem`'s
  /// own hit-resolution loop, and `tick()` itself is outside it), not a
  /// fire-and-forget timed DoT the way Kestrel's own Bleed is.
  ///
  /// Reuses Bleed's own storage (`EnemyStore.bleedStacks`/`bleedRemaining`,
  /// ADR 0015) rather than a parallel one — this only *sets* the stack
  /// count and a short refresh window; `ElementSystem`'s existing Bleed
  /// tick block does the actual damage and death handling, at Crush's own
  /// stated 5 %/s per stack rather than Bleed's borrowed 4 %/s (that rate
  /// switches on which hero is equipped, the same way it already does for
  /// Kade's Deep Burn). The refresh window is twice the recheck interval —
  /// not a designed grace period, only enough slack that
  /// `ElementSystem.update`'s own `-= dt` later this same tick never
  /// immediately expires a stack this pass just set.
  void _tickRookCrush(double dt) {
    if (!hero.has(HeroBehaviour.rookCrush)) return;

    hero.crushTickTimer -= dt;
    if (hero.crushTickTimer > 0) return;
    hero.crushTickTimer += 1.0 / _rookCrushTicksPerSecond;

    const double refreshWindow = 2.0 / _rookCrushTicksPerSecond;
    const double radiusSq = _rookGroupingRadius * _rookGroupingRadius;
    final int high = entities.highWater;
    for (int i = 0; i < high; i++) {
      if (entities.alive[i] == 0) continue;
      if (entities.kind[i] != EntityKind.enemy.index) continue;

      final int found = spatial.queryRadius(
          entities.posX[i], entities.posY[i], _rookGroupingRadius);
      int grouped = 0;
      for (int c = 0; c < found; c++) {
        final int e = spatial.resultAt(c);
        if (e == i) continue;
        if (entities.alive[e] == 0) continue;
        if (entities.kind[e] != EntityKind.enemy.index) continue;
        final double dx = entities.posX[e] - entities.posX[i];
        final double dy = entities.posY[e] - entities.posY[i];
        if (dx * dx + dy * dy > radiusSq) continue;
        grouped++;
      }
      if (grouped <= 0) continue;

      enemies.bleedStacks[i] =
          grouped > _rookCrushStackCap ? _rookCrushStackCap : grouped;
      enemies.bleedRemaining[i] = refreshWindow;
    }
  }

  static const double _rookCrushTicksPerSecond = 4.0;
  static const int _rookCrushStackCap = 4;

  /// ADR 0007's own grouping radius (1.6 u) — matched here, not re-derived;
  /// `ProjectileSystem` carries the identical constant for Pull's own
  /// per-hit damage bonus.
  static const double _rookGroupingRadius = 1.6;

  /// *Singularity* — "a 4 s well pulling everything in 6 u to a point, then
  /// detonating for 400 %" (docs/07 §7.3). The same fixed-zone shape
  /// Miasma's own cloud and Pyre Line's own wall already use: pinned at
  /// cast time on [HeroRuntime], ticked every frame from
  /// [_tickRookSingularity] rather than resolved once here. Centred on the
  /// current target, the same `FiringSystem.selectTarget` every other
  /// targeted Ultimate (Glacier Nail, Pyre Line) already reads, falling
  /// back to the player's own position with nothing in range.
  ///
  /// *Twin Singularity* (T5a) casts a second, independent well at the
  /// *second*-nearest enemy — the same "second independent instance of the
  /// same fixed zone" shape Kade's own Twin Pyre already establishes for
  /// [HeroRuntime.pyreLine2X0] — rather than at the same point as the
  /// first, which would just be one well with a redundant name. *Collapsing
  /// Singularity* (T5b) trades the second well for one that lasts longer
  /// and hits far harder; the two are this Ultimate's own mutually
  /// exclusive ★5 branches, never both active.
  void _fireRookSingularity() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    final double fromX = entities.posX[p];
    final double fromY = entities.posY[p];

    final bool collapsing = hero.has(HeroBehaviour.rookCollapsingSingularity);
    final double duration =
        collapsing ? _rookCollapsingSingularityDuration : _rookSingularityDuration;

    final int target = FiringSystem.selectTarget(
      entities,
      spatial,
      fromX,
      fromY,
      enemies: enemies,
    );
    hero.singularityRemaining = duration;
    hero.singularityX = target >= 0 ? entities.posX[target] : fromX;
    hero.singularityY = target >= 0 ? entities.posY[target] : fromY;

    if (hero.has(HeroBehaviour.rookTwinSingularity)) {
      final int second = _nearestEnemyExcluding(fromX, fromY, target);
      hero.singularity2Remaining = duration;
      hero.singularity2X = second >= 0 ? entities.posX[second] : fromX;
      hero.singularity2Y = second >= 0 ? entities.posY[second] : fromY;
    } else {
      hero.singularity2Remaining = 0;
    }
  }

  /// The nearest living, targetable enemy to ([fromX], [fromY]) other than
  /// [exclude] — [_furthestEnemy]'s own reasoning applies equally here:
  /// unbounded by `FiringSystem.acquireRange`, since summoning a second
  /// well is not an aimed shot either. A linear scan, run once per
  /// Ultimate press.
  int _nearestEnemyExcluding(double fromX, double fromY, int exclude) {
    int nearest = -1;
    double nearestDistSq = double.infinity;
    for (int i = 0; i < entities.highWater; i++) {
      if (i == exclude) continue;
      if (entities.alive[i] == 0) continue;
      if (entities.kind[i] != EntityKind.enemy.index) continue;
      if (enemies.isUntargetable(i)) continue;
      final double dx = entities.posX[i] - fromX;
      final double dy = entities.posY[i] - fromY;
      final double distSq = dx * dx + dy * dy;
      if (distSq < nearestDistSq) {
        nearestDistSq = distSq;
        nearest = i;
      }
    }
    return nearest;
  }

  static const double _rookSingularityDuration = 4.0;
  static const double _rookCollapsingSingularityDuration = 6.0;
  static const double _rookSingularityRadius = 6.0;
  static const double _rookSingularityDetonationShare = 4.00;
  static const double _rookCollapsingSingularityDetonationShare = 9.00;

  /// Units per second an enemy is dragged toward a well's own centre.
  /// Docs/07 states no speed for the pull itself — fast enough that
  /// anything caught at the full 6 u radius still reaches the centre well
  /// before even the base 4 s window ends, so "pulling everything... to a
  /// point" is a promise the well actually keeps rather than a slow drift
  /// that only starts to matter once Collapsing Singularity's own longer
  /// window is picked.
  static const double _rookSingularityPullSpeed = 5.0;

  /// Advances both of Rook's own wells (if either is active) — the pull
  /// each tick it is live, then exactly one detonation the instant its own
  /// timer reaches zero, never resolved twice.
  void _tickRookSingularity(double dt) {
    if (hero.singularityRemaining > 0) {
      _pullTowardWell(hero.singularityX, hero.singularityY, dt);
      hero.singularityRemaining -= dt;
      if (hero.singularityRemaining <= 0) {
        hero.singularityRemaining = 0;
        _detonateAt(
          hero.singularityX,
          hero.singularityY,
          _rookSingularityRadius,
          hero.has(HeroBehaviour.rookCollapsingSingularity)
              ? _rookCollapsingSingularityDetonationShare
              : _rookSingularityDetonationShare,
        );
      }
    }
    if (hero.singularity2Remaining > 0) {
      _pullTowardWell(hero.singularity2X, hero.singularity2Y, dt);
      hero.singularity2Remaining -= dt;
      if (hero.singularity2Remaining <= 0) {
        hero.singularity2Remaining = 0;
        _detonateAt(hero.singularity2X, hero.singularity2Y,
            _rookSingularityRadius, _rookSingularityDetonationShare);
      }
    }
  }

  /// Drags every living enemy within [_rookSingularityRadius] of ([cx],
  /// [cy]) toward that point by [_rookSingularityPullSpeed] this tick,
  /// clamped so a close enemy is placed exactly at the centre rather than
  /// overshooting past it. A linear scan, the same shape
  /// [_tickRookCrush]/[_tickSableMiasma] already use for their own
  /// once-or-twice-a-tick zone effects.
  void _pullTowardWell(double cx, double cy, double dt) {
    const double radiusSq = _rookSingularityRadius * _rookSingularityRadius;
    final double step = _rookSingularityPullSpeed * dt;
    for (int i = 0; i < entities.highWater; i++) {
      if (entities.alive[i] == 0) continue;
      if (entities.kind[i] != EntityKind.enemy.index) continue;
      final double dx = cx - entities.posX[i];
      final double dy = cy - entities.posY[i];
      final double distSq = dx * dx + dy * dy;
      if (distSq > radiusSq || distSq <= 1e-9) continue;
      final double dist = math.sqrt(distSq);
      final double move = step < dist ? step : dist;
      entities.posX[i] += dx / dist * move;
      entities.posY[i] += dy / dist * move;
    }
  }

  /// Flat AoE damage centred on an arbitrary point at an arbitrary radius —
  /// Rook's own Singularity detonation needs both to differ from
  /// [_applyPlayerCenteredNova]'s own fixed player-centred radius (a well
  /// can sit anywhere, and 6 u is Rook's own stated number, not
  /// Ashlin/Ovrin's shared 3.5 u), so this is its own small helper rather
  /// than forcing a second radius parameter onto a nova named for always
  /// using one.
  void _detonateAt(double cx, double cy, double radius, double damageMultiplier) {
    final double damage = playerAttack * damageMultiplier;
    final double radiusSq = radius * radius;
    final int found = spatial.queryRadius(cx, cy, radius);
    for (int i = 0; i < found; i++) {
      final int e = spatial.resultAt(i);
      if (entities.alive[e] == 0) continue;
      if (entities.kind[e] != EntityKind.enemy.index) continue;
      final double dx = entities.posX[e] - cx;
      final double dy = entities.posY[e] - cy;
      if (dx * dx + dy * dy > radiusSq) continue;
      entities.health[e] -= damage;
    }
  }

  /// *The Lattice* (Iris) — "instantly draws a 6-line web across the
  /// arena, persisting 10 s. Every shot through it caps out at 5
  /// Confluence" (docs/07 §7.3). The web itself is authored as spokes
  /// radiating from one centre at evenly spaced angles across 180°
  /// (6, or 10 for *Grand Lattice*) — docs/07 gives a line count and a
  /// duration but no actual geometry, so this is a deliberate choice,
  /// the same kind ADR 0011 already made for Ashlin's own nova radius.
  /// Length reuses [_kadePyreLineLength] ("long enough to reach across
  /// the arena"), the identical reasoning that number already exists for.
  /// *Grand Lattice* (T5a) only changes the line count and duration;
  /// *Living Lattice* (T5b) instead keeps the centre pinned to the
  /// player's own current position every tick — see
  /// [_tickIrisLattice] — rather than fixed at cast time.
  void _fireIrisTheLattice() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    hero.latticeRemaining = hero.has(HeroBehaviour.irisGrandLattice)
        ? _irisGrandLatticeDuration
        : _irisLatticeDuration;
    hero.latticeX = entities.posX[p];
    hero.latticeY = entities.posY[p];
    _computeIrisLatticeLines();
  }

  static const double _irisLatticeDuration = 10.0;
  static const double _irisGrandLatticeDuration = 16.0;
  static const int _irisLatticeLines = 6;
  static const int _irisGrandLatticeLines = 10;
  static const double _irisLatticeLineHalfLength = _kadePyreLineLength / 2;

  /// Recomputes every spoke's own endpoints from [HeroRuntime.latticeX]/
  /// [HeroRuntime.latticeY] — the only place this ever needs `dart:math`,
  /// since [ProjectileSystem] deliberately avoids it in its own hot loop.
  /// Spokes are full diameters through the centre (not radii), so `count`
  /// evenly spaced directions across 180° give `count` genuinely distinct
  /// lines rather than `count / 2` doubled up.
  void _computeIrisLatticeLines() {
    final int count = hero.has(HeroBehaviour.irisGrandLattice)
        ? _irisGrandLatticeLines
        : _irisLatticeLines;
    hero.latticeLineCount = count;
    for (int i = 0; i < count; i++) {
      final double angle = math.pi * i / count;
      final double dx = math.cos(angle) * _irisLatticeLineHalfLength;
      final double dy = math.sin(angle) * _irisLatticeLineHalfLength;
      final int base = i * 4;
      hero.latticeLines[base] = hero.latticeX - dx;
      hero.latticeLines[base + 1] = hero.latticeY - dy;
      hero.latticeLines[base + 2] = hero.latticeX + dx;
      hero.latticeLines[base + 3] = hero.latticeY + dy;
    }
  }

  /// Counts down The Lattice's own duration and, for *Living Lattice*
  /// only, recentres the whole web on the player before recomputing every
  /// spoke — "the Lattice follows the player" reads as the web itself
  /// moving, not merely persisting longer.
  void _tickIrisLattice(double dt) {
    if (hero.latticeRemaining <= 0) return;
    hero.latticeRemaining -= dt;
    if (hero.latticeRemaining < 0) hero.latticeRemaining = 0;
    if (hero.latticeRemaining <= 0) {
      hero.latticeLineCount = 0;
      return;
    }

    if (hero.has(HeroBehaviour.irisLivingLattice) &&
        !player.isNone &&
        entities.isAlive(player)) {
      final int p = player.index;
      hero.latticeX = entities.posX[p];
      hero.latticeY = entities.posY[p];
    }
    _computeIrisLatticeLines();
  }

  /// *Pyre Line* — a straight burning wall along the aim vector, the same
  /// direction [FiringSystem.aimAngle] computes for every other targeted
  /// Ultimate. Endpoints are pinned at cast time on [HeroRuntime], the same
  /// fixed-zone shape Miasma's own cloud uses, and ticked every frame from
  /// [_tickKadePyreLine] rather than applied once here. *Long Pyre* (T5a)
  /// only changes the duration; *Twin Pyre* (T5b) casts a second wall
  /// perpendicular to the first, crossing at the player.
  void _fireKadePyreLine() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    final double fromX = entities.posX[p];
    final double fromY = entities.posY[p];

    final int target = FiringSystem.selectTarget(
      entities,
      spatial,
      fromX,
      fromY,
      enemies: enemies,
    );
    final double angle = target >= 0
        ? FiringSystem.aimAngle(entities, target, fromX, fromY,
            entities.facing[p], aimAssist, projectileSpeed)
        : entities.facing[p];

    hero.pyreLineRemaining = hero.has(HeroBehaviour.kadeLongPyre)
        ? _kadeLongPyreDuration
        : _kadePyreLineDuration;
    hero.pyreLineX0 = fromX;
    hero.pyreLineY0 = fromY;
    hero.pyreLineX1 = fromX + math.cos(angle) * _kadePyreLineLength;
    hero.pyreLineY1 = fromY + math.sin(angle) * _kadePyreLineLength;

    if (hero.has(HeroBehaviour.kadeTwinPyre)) {
      final double perpAngle = angle + math.pi / 2;
      hero.pyreLine2X0 = fromX;
      hero.pyreLine2Y0 = fromY;
      hero.pyreLine2X1 = fromX + math.cos(perpAngle) * _kadePyreLineLength;
      hero.pyreLine2Y1 = fromY + math.sin(perpAngle) * _kadePyreLineLength;
    } else {
      hero.pyreLine2X0 = 0;
      hero.pyreLine2Y0 = 0;
      hero.pyreLine2X1 = 0;
      hero.pyreLine2Y1 = 0;
    }
  }

  static const double _kadePyreLineDuration = 8.0;
  static const double _kadeLongPyreDuration = 14.0;

  /// Long enough to reach across the arena, the same reasoning
  /// [_fireVanePiercingHorizon] already uses for its own line length.
  static const double _kadePyreLineLength = 18.0;

  /// ADR 0008 — docs/07 states no cross-section for the wall; this borrows
  /// the same tolerance every Windline segment already checks against.
  static const double _kadePyreLineHalfWidth = SimConfig.windlineHitWidth;

  static const int _kadeSlowBurnMaxStacks = 3;
  static const double _kadeSlowBurnDuration = 8.0;

  /// Decrements Pyre Line's own timer and re-applies Burn to whoever is
  /// currently standing in the wall — a plain per-tick refresh rather than a
  /// once-per-crossing edge trigger, since nothing in the sim tracks "was
  /// this enemy in the zone last tick" yet. Harmless to reapply every tick:
  /// [StatusStore.apply]'s own stack cap makes this idempotent once an
  /// enemy is already at the ceiling, so standing in the fire simply keeps
  /// Burn topped up rather than stacking indefinitely.
  void _tickKadePyreLine(double dt) {
    if (hero.pyreLineRemaining <= 0) return;
    hero.pyreLineRemaining -= dt;
    if (hero.pyreLineRemaining < 0) hero.pyreLineRemaining = 0;

    _applyPyreWall(
        hero.pyreLineX0, hero.pyreLineY0, hero.pyreLineX1, hero.pyreLineY1);
    if (hero.has(HeroBehaviour.kadeTwinPyre)) {
      _applyPyreWall(hero.pyreLine2X0, hero.pyreLine2Y0, hero.pyreLine2X1,
          hero.pyreLine2Y1);
    }
  }

  void _applyPyreWall(double x0, double y0, double x1, double y1) {
    final int? maxStacks =
        hero.has(HeroBehaviour.kadeSlowBurn) ? _kadeSlowBurnMaxStacks : null;
    final double? duration =
        hero.has(HeroBehaviour.kadeSlowBurn) ? _kadeSlowBurnDuration : null;

    for (int i = 0; i < entities.highWater; i++) {
      if (entities.alive[i] == 0) continue;
      if (entities.kind[i] != EntityKind.enemy.index) continue;
      final double reach = entities.radius[i] + _kadePyreLineHalfWidth;
      if (!_nearSegment(entities.posX[i], entities.posY[i], x0, y0, x1, y1, reach)) {
        continue;
      }
      if (enemies.resistsElement(i, SimElement.ember)) continue;
      status.apply(
        i,
        SimElement.ember,
        burnMaxStacksOverride: maxStacks,
        burnDurationOverride: duration,
      );
    }
  }

  static bool _nearSegment(
    double px,
    double py,
    double x0,
    double y0,
    double x1,
    double y1,
    double reach,
  ) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double lengthSq = dx * dx + dy * dy;

    double t = 0;
    if (lengthSq > 1e-12) {
      t = ((px - x0) * dx + (py - y0) * dy) / lengthSq;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
    }

    final double gapX = px - (x0 + dx * t);
    final double gapY = py - (y0 + dy * t);
    return gapX * gapX + gapY * gapY <= reach * reach;
  }

  /// *Umbral Step* — teleports to the single furthest enemy, becomes
  /// untargetable (checked by [EnemyAttack.damagePlayer], the one place an
  /// enemy hit can land), and loads guaranteed crits for the next 3 shots at
  /// a fixed 300% — consumed in `_applyArrowBoons` rather than rolled,
  /// since this is a guarantee, not odds. *Deeper Shadow* (T1b) only changes
  /// the window's duration. *Perfect Step* (T5b) is a full replacement — 1
  /// shot at 600% instead of 3 at 300%, the same "mutually exclusive branch
  /// swaps every number" shape Wren's Wide/Focused Fan already established.
  void _fireNyxUmbralStep() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;

    final int furthest = _furthestEnemy(entities.posX[p], entities.posY[p]);
    if (furthest >= 0) {
      entities.posX[p] = entities.posX[furthest];
      entities.posY[p] = entities.posY[furthest];
    }

    hero.umbralStepRemaining = hero.has(HeroBehaviour.nyxDeeperShadow)
        ? _nyxDeeperShadowDuration
        : _nyxUmbralStepDuration;
    hero.umbralStepGuaranteedCritShots = hero.has(HeroBehaviour.nyxPerfectStep)
        ? _nyxPerfectStepShots
        : _nyxUmbralStepShots;
  }

  static const double _nyxUmbralStepDuration = 1.5;
  static const double _nyxDeeperShadowDuration = 2.5;
  static const int _nyxUmbralStepShots = 3;
  static const int _nyxPerfectStepShots = 1;
  static const double _nyxUmbralStepCritMultiplier = 3.00;
  static const double _nyxPerfectStepCritMultiplier = 6.00;

  /// The single furthest living, targetable enemy from ([fromX], [fromY]) —
  /// the opposite of [FiringSystem.selectTarget], and unbounded by its own
  /// `acquireRange` since a teleport is not an aimed shot. A linear scan:
  /// this runs once per Ultimate press, not once per hit.
  int _furthestEnemy(double fromX, double fromY) {
    int furthest = -1;
    double furthestDistSq = -1;
    for (int i = 0; i < entities.highWater; i++) {
      if (entities.alive[i] == 0) continue;
      if (entities.kind[i] != EntityKind.enemy.index) continue;
      if (enemies.isUntargetable(i)) continue;
      final double dx = entities.posX[i] - fromX;
      final double dy = entities.posY[i] - fromY;
      final double distSq = dx * dx + dy * dy;
      if (distSq > furthestDistSq) {
        furthestDistSq = distSq;
        furthest = i;
      }
    }
    return furthest;
  }

  /// Flat AoE damage centred on the player — Rekindle's own revive-nova,
  /// Rebirth Nova's Ultimate cast, and Ovrin's own Riposte (T3b, "breaking
  /// a shield deals 200 % AoE") all resolve here, sharing one radius (ADR
  /// 0011 — docs/07 names a damage percentage for each but a radius for
  /// none of them). Named for what it does rather than who first needed
  /// it, now that a second hero shares it. A direct [spatial] query, not a
  /// linear scan: this runs at most once per revive, Ultimate press, or
  /// shield break, never inside [ProjectileSystem]'s own hit-resolution
  /// loop, so the reentrancy hazard that rules out `queryRadius` there
  /// does not apply here.
  void _applyPlayerCenteredNova(double damageMultiplier) {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    final double cx = entities.posX[p];
    final double cy = entities.posY[p];
    final double damage = playerAttack * damageMultiplier;
    const double radiusSq = _playerCenteredNovaRadius * _playerCenteredNovaRadius;

    final int found = spatial.queryRadius(cx, cy, _playerCenteredNovaRadius);
    for (int i = 0; i < found; i++) {
      final int e = spatial.resultAt(i);
      if (entities.alive[e] == 0) continue;
      if (entities.kind[e] != EntityKind.enemy.index) continue;
      final double dx = entities.posX[e] - cx;
      final double dy = entities.posY[e] - cy;
      if (dx * dx + dy * dy > radiusSq) continue;
      entities.health[e] -= damage;
    }
  }

  static const double _playerCenteredNovaRadius = 3.5; // ADR 0011
  static const double _ashlinRekindleNovaMultiplier = 3.50;
  static const double _ashlinRebirthNovaMultiplier = 5.00;
  static const double _ashlinSupernovaMultiplier = 12.00;
  static const double _ashlinRebirthNovaHealFraction = 0.25;
  static const double _ashlinInvulnDuration = 3.0;

  /// *Rebirth Nova* — an AoE burst plus a heal, and (unless *Supernova*, T5b,
  /// traded it away for a bigger burst) resets Rekindle's own charge count
  /// so it can trigger again later in the run.
  void _fireAshlinRebirthNova() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;

    final bool supernova = hero.has(HeroBehaviour.ashlinSupernova);
    _applyPlayerCenteredNova(
      supernova ? _ashlinSupernovaMultiplier : _ashlinRebirthNovaMultiplier,
    );

    final double healed = entities.health[p] +
        entities.maxHealth[p] * _ashlinRebirthNovaHealFraction;
    final double cap = entities.maxHealth[p];
    entities.health[p] = healed > cap ? cap : healed;

    if (!supernova) {
      hero.rekindlesUsed = 0;
    }
  }

  /// *Piercing Horizon* — one arrow (two, for Twin Horizon), Tier III,
  /// enough pierce to never run out before a wall stops it, which combined
  /// with the arena's own diagonal (~18 u) inside the arrow's default reach
  /// (14 u/s x 2.5 s lifetime = 35 u) is what makes it "full-arena-width"
  /// without needing a special lifetime of its own.
  void _fireVanePiercingHorizon() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    final double fromX = entities.posX[p];
    final double fromY = entities.posY[p];

    final int target = FiringSystem.selectTarget(
      entities,
      spatial,
      fromX,
      fromY,
      enemies: enemies,
    );
    final double baseAngle = target >= 0
        ? FiringSystem.aimAngle(entities, target, fromX, fromY,
            entities.facing[p], aimAssist, projectileSpeed)
        : entities.facing[p];

    final double share = hero.has(HeroBehaviour.vaneSunderingHorizon)
        ? _vaneSunderingHorizonDamageShare
        : _vanePiercingHorizonDamageShare;

    _spawnArrow(fromX, fromY, baseAngle, DrawTier.three, share,
        extraPierce: _longArrowPierce);

    // *Twin Horizon* (T5a) trades Sundering's bigger single line for two at
    // 90° — an instant Confluence cross, per its own card text — rather than
    // stacking with Sundering; a hero only ever holds one T5 branch.
    if (hero.has(HeroBehaviour.vaneTwinHorizon)) {
      _spawnArrow(
        fromX,
        fromY,
        baseAngle + _vaneTwinHorizonOffsetRadians,
        DrawTier.three,
        share,
        extraPierce: _longArrowPierce,
      );
    }
  }

  static const double _vanePiercingHorizonDamageShare = 6.00;
  static const double _vaneSunderingHorizonDamageShare = 14.00;
  static const double _vaneTwinHorizonOffsetRadians = math.pi / 2;

  /// *Judgment Spear* — a single Tier III strike, scaled up against a
  /// low-health target rather than at a flat rate. *Final Verdict* (T5a) and
  /// *Twin Spear* (T5b) are the same node's two branches and never both
  /// active; Twin Spear's own card text ("2 spears, 600 % each") is a flat
  /// replacement with no health-tier bonus of its own, the same way Wren's
  /// Wide Fan and Focused Fan fully replace Volley Fan's numbers rather than
  /// layering on top of them.
  void _fireHaldenJudgmentSpear() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    final double fromX = entities.posX[p];
    final double fromY = entities.posY[p];

    final int target = FiringSystem.selectTarget(
      entities,
      spatial,
      fromX,
      fromY,
      enemies: enemies,
    );
    final double baseAngle = target >= 0
        ? FiringSystem.aimAngle(entities, target, fromX, fromY,
            entities.facing[p], aimAssist, projectileSpeed)
        : entities.facing[p];

    // *Sentence* (T3a) — "marks the boss": read once here, since Twin Spear
    // and the base shot are the only two shapes this Ultimate ever fires as,
    // and both should carry the mark when the talent is held.
    final bool marksBoss = hero.has(HeroBehaviour.haldenSentence);

    if (hero.has(HeroBehaviour.haldenTwinSpear)) {
      _spawnArrow(fromX, fromY, baseAngle - _haldenTwinSpearHalfSpread,
          DrawTier.three, _haldenTwinSpearDamageShare, marksBoss: marksBoss);
      _spawnArrow(fromX, fromY, baseAngle + _haldenTwinSpearHalfSpread,
          DrawTier.three, _haldenTwinSpearDamageShare, marksBoss: marksBoss);
      return;
    }

    double share = _haldenJudgmentSpearBaseDamageShare;
    if (target >= 0) {
      final double maxHp = entities.maxHealth[target];
      final double fraction =
          maxHp > 0 ? entities.health[target] / maxHp : 1.0;
      if (hero.has(HeroBehaviour.haldenFinalVerdict) &&
          fraction < _haldenFinalVerdictThreshold) {
        share = _haldenFinalVerdictDamageShare;
      } else if (fraction < _haldenJudgmentSpearLowHealthThreshold) {
        share = _haldenJudgmentSpearBaseDamageShare * 2.0;
      }
    }
    _spawnArrow(fromX, fromY, baseAngle, DrawTier.three, share,
        marksBoss: marksBoss);
  }

  static const double _haldenJudgmentSpearBaseDamageShare = 9.00;
  static const double _haldenJudgmentSpearLowHealthThreshold = 0.40;
  static const double _haldenFinalVerdictThreshold = 0.25;
  static const double _haldenFinalVerdictDamageShare = 30.00;
  static const double _haldenTwinSpearDamageShare = 6.00;

  /// No angle is documented for Twin Spear's pair, unlike Vane's explicit
  /// 90°; reuses the narrow same-target fan spacing Split Shot already uses
  /// rather than inventing a wide, undocumented spread.
  static const double _haldenTwinSpearHalfSpread = volleySpreadRadians / 2;

  /// *Flurry* — a timed self-buff rather than a burst: forced Tier III and a
  /// fire-rate multiplier for its duration, both read every tick from
  /// [_updateFiring] rather than applied once here. *Endless Flurry* (T5a)
  /// and *Perfect Flurry* (T5b) swap the duration/rate pair; Perfect Flurry's
  /// own "+100 % Confluence damage" is read directly off [HeroRuntime] at the
  /// point `ProjectileSystem` receives its Confluence multiplier, alongside
  /// this method rather than inside it.
  void _fireKestrelFlurry() {
    if (hero.has(HeroBehaviour.kestrelEndlessFlurry)) {
      hero.flurryRemaining = _kestrelEndlessFlurryDuration;
      hero.flurryRateMultiplier = _kestrelEndlessFlurryRate;
    } else if (hero.has(HeroBehaviour.kestrelPerfectFlurry)) {
      hero.flurryRemaining = _kestrelPerfectFlurryDuration;
      hero.flurryRateMultiplier = _kestrelFlurryRate;
    } else {
      hero.flurryRemaining = _kestrelFlurryDuration;
      hero.flurryRateMultiplier = _kestrelFlurryRate;
    }
  }

  static const double _kestrelFlurryDuration = 4.0;
  static const double _kestrelFlurryRate = 3.0;
  static const double _kestrelEndlessFlurryDuration = 7.0;
  static const double _kestrelEndlessFlurryRate = 2.2;
  static const double _kestrelPerfectFlurryDuration = 3.0;

  /// +100 %, per *Perfect Flurry*'s own card text — a full doubling, not a
  /// bonus added to whatever Confluence multiplier the build already has.
  static const double _kestrelPerfectFlurryConfluenceMultiplier = 2.0;

  /// *Volley Fan* — 7 arrows in a 90° arc, each at 80 % damage, each laying
  /// its own Windline exactly as any other Tier III arrow would. *Wide Fan*
  /// (T3a) and *Focused Fan* (T3b) are the same release with a different
  /// count, damage share and pierce, not a different mechanic — [hero]'s
  /// flags pick which one applies.
  void _fireWrenVolleyFan() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    final double fromX = entities.posX[p];
    final double fromY = entities.posY[p];

    final int target = FiringSystem.selectTarget(
      entities,
      spatial,
      fromX,
      fromY,
      enemies: enemies,
    );
    // No target still fires — an Ultimate that fizzled because nothing was in
    // range would feel like the button ate the charge for nothing. Centred on
    // facing instead.
    final double baseAngle = target >= 0
        ? FiringSystem.aimAngle(entities, target, fromX, fromY,
            entities.facing[p], aimAssist, projectileSpeed)
        : entities.facing[p];

    final bool focused = hero.has(HeroBehaviour.wrenFocusedFan);
    final bool wide = hero.has(HeroBehaviour.wrenWideFan);

    final int count = focused
        ? _wrenFocusedFanArrows
        : (wide ? _wrenWideFanArrows : _wrenVolleyArrows);
    final double share = focused
        ? _wrenFocusedFanDamageShare
        : (wide ? _wrenWideFanDamageShare : _wrenVolleyDamageShare);
    // Focused Fan's card reads "pierce 3" as a bonus on top of a Tier III
    // arrow's own baseline 2, matching how every other pierce-granting source
    // in the game (Boons, arrows) adds rather than replaces.
    final int extraPierce = focused ? _wrenFocusedFanPierce : 0;

    final double step = count > 1 ? _wrenVolleyArcRadians / (count - 1) : 0;
    final double start = baseAngle - _wrenVolleyArcRadians * 0.5;
    final bool wardensLattice = hero.has(HeroBehaviour.wrenWardensLattice);
    for (int i = 0; i < count; i++) {
      final int slot = _spawnArrow(
        fromX,
        fromY,
        start + step * i,
        DrawTier.three,
        share,
        extraPierce: extraPierce,
      );
      if (slot < 0) continue;
      // *Warden's Fury* (T5b) reads this at the target's own death, well
      // after this arrow may have landed — tagged unconditionally, the
      // same "every Ultimate arrow, not just when a talent needs it"
      // posture `willMarkBoss`/`willChain` already take for their own
      // per-shot tags.
      projectiles.isUltimateArrow[slot] = 1;
      // *Warden's Lattice* (T5a) — "Ultimate Windlines last 4 s."
      if (wardensLattice) {
        projectiles.windlineDurationOverride[slot] = _wrenWardensLatticeDuration;
      }
    }
  }

  static const int _wrenVolleyArrows = 7;
  static const double _wrenVolleyDamageShare = 0.80;
  static const int _wrenWideFanArrows = 11;
  static const double _wrenWideFanDamageShare = 0.60;
  static const int _wrenFocusedFanArrows = 3;
  static const double _wrenFocusedFanDamageShare = 2.20;
  static const int _wrenFocusedFanPierce = 3;
  static const double _wrenWardensLatticeDuration = 4.0;

  /// 90°, in radians — the arc every Volley Fan variant fans across.
  static const double _wrenVolleyArcRadians = math.pi / 2;

  /// Releases one shot, which may be several arrows.
  ///
  /// *Split Shot* (#10) and *Twin Nock* (#17) widen a shot into a fan. The fan
  /// is centred on the aim angle so the middle arrow still goes where the
  /// player is looking — an off-centre fan makes auto-aim feel broken even
  /// though it is aiming correctly.
  void _spawnVolley(double x, double y, double angle, DrawTier tier) {
    final int extra = extraArrows;

    // *Rain of Nocks* (#22) adds a wide, weaker fan on Tier III only. It is a
    // separate release rather than more arrows in the main fan, because its
    // arrows are worth less — folding them in would quietly cheapen the
    // Split Shot arrows beside them.
    if (boons.has(BoonBehaviour.rainOfNocks) && tier == DrawTier.three) {
      const int n = BoonRuntime.rainArrows;
      const double step = BoonRuntime.rainSpreadRadians / (n - 1);
      final double start = angle - BoonRuntime.rainSpreadRadians * 0.5;
      for (int i = 0; i < n; i++) {
        _spawnArrow(
          x,
          y,
          start + step * i,
          tier,
          volleyDamageMultiplier * BoonRuntime.rainDamageShare,
        );
      }
    }

    if (hero.hasArrow(ArrowBehaviour.twinfangConverging)) {
      _fireTwinfangConverging(x, y, angle, tier);
      return;
    }

    if (extra <= 0) {
      _spawnArrow(x, y, angle, tier, volleyDamageMultiplier);
      return;
    }

    final int total = 1 + extra;
    final double spread = volleySpreadRadians * (total - 1);
    final double step = spread / (total - 1);
    final double start = angle - spread * 0.5;

    for (int i = 0; i < total; i++) {
      _spawnArrow(x, y, start + step * i, tier, volleyDamageMultiplier);
    }
  }

  /// Angle between adjacent arrows in a fan. Narrow on purpose: a wide fan
  /// stops being "more arrows at the target" and becomes "arrows near the
  /// target", which reads as a downgrade.
  static const double volleySpreadRadians = 0.14;

  /// Twinfang — two arrows that leave the bow slightly apart (ADR 0012) and
  /// converge to cross exactly [_twinfangCrossDistance] ahead on the aim
  /// line, each carrying a guaranteed Confluence stack from the moment they
  /// spawn rather than one detected geometrically when the paths actually
  /// meet — docs/08 itself prices the payoff as "a reliable ×1.4", which is
  /// exactly one stack's own +40 % (`ConfluenceTuning.bonusFor(1)`), granted
  /// unconditionally rather than left contingent on an enemy standing
  /// precisely on the crossing point.
  void _fireTwinfangConverging(double x, double y, double angle, DrawTier tier) {
    final double crossX = x + math.cos(angle) * _twinfangCrossDistance;
    final double crossY = y + math.sin(angle) * _twinfangCrossDistance;
    final double perpX = -math.sin(angle);
    final double perpY = math.cos(angle);

    for (final double side in <double>[-1.0, 1.0]) {
      final double spawnX = x + perpX * _twinfangSpawnOffset * side;
      final double spawnY = y + perpY * _twinfangSpawnOffset * side;
      final double arrowAngle =
          math.atan2(crossY - spawnY, crossX - spawnX);
      final int i = _spawnArrow(
        spawnX,
        spawnY,
        arrowAngle,
        tier,
        volleyDamageMultiplier,
      );
      if (i >= 0) {
        projectiles.confluenceStacks[i] = _twinfangGuaranteedStacks;
        projectiles.confluenceBonus[i] =
            ConfluenceTuning.bonusFor(_twinfangGuaranteedStacks) *
                confluenceDamageMultiplier;
      }
    }
  }

  static const double _twinfangCrossDistance = 6.0;
  static const double _twinfangSpawnOffset = 0.3; // ADR 0012
  static const int _twinfangGuaranteedStacks = 1;

  /// Skimmer — docs/08: "ricochets 2x off walls or enemies", one shared
  /// counter rather than 2 of each. See `ProjectileSystem` for where a
  /// ricochet is actually resolved (the wall/boundary reflection and the
  /// nearest-unhit-enemy redirect both live there, alongside the wall check
  /// and hit resolution they extend).
  static const int _skimmerRicochetCount = 2;

  /// Corvin's own *Bounce* — "arrows ricochet once off walls or enemies."
  /// *Double Bounce* (T3b) raises the base grant to 2; *Caroms* (the
  /// Ultimate) raises it to 4 for its own duration, *Endless Carom* (T5a)
  /// only changing how long that duration lasts. Composed with whatever the
  /// equipped arrow itself grants (Skimmer) by taking the larger of the
  /// two — "ricochets once" reads as a floor for an ordinary arrow, not a
  /// bonus bounce stacked on top of one that already ricochets more.
  static const int _corvinBounceCount = 1;
  static const int _corvinDoubleBounceCount = 2;
  static const int _corvinCaromsCount = 4;

  /// Returns the spawned arrow's own entity slot, or -1 if the entity pool
  /// was full — most callers ignore the return; Twinfang's own guaranteed
  /// Confluence stack is the one thing that needs to touch the arrow again
  /// right after spawning it.
  int _spawnArrow(
    double x,
    double y,
    double angle,
    DrawTier tier,
    double damageScale, {
    int extraPierce = 0,
    int mirelleDuplicateDepth = 0,
    bool isEcho = false,
    bool marksBoss = false,
  }) {
    final EntityId id = entities.spawn(EntityKind.projectile);
    if (id.isNone) return -1;

    final int i = id.index;
    entities.posX[i] = x;
    entities.posY[i] = y;
    entities.velX[i] = math.cos(angle) * projectileSpeed;
    entities.velY[i] = math.sin(angle) * projectileSpeed;
    entities.radius[i] = arrowRadius * tier.hitboxScale;
    entities.facing[i] = angle;
    entities.health[i] = 1;
    entities.maxHealth[i] = 1;

    projectiles.reset(i);
    // Claim a serial before the arrow moves. Confluence requires strictly-older
    // segments, so this is what stops an arrow threading its own trail.
    projectiles.windlineSerial[i] = windlines.nextSerial;
    projectiles.trailId[i] = _nextTrailId++;
    projectiles.damage[i] = playerAttack * damageScale;
    projectiles.pierceRemaining[i] = basePierce + tier.bonusPierce + extraPierce;
    projectiles.drawTier[i] = tier.index;
    projectiles.lifetime[i] = arrowLifetime;
    projectiles.element[i] = _arrowElementIndex();
    int ricochets =
        hero.hasArrow(ArrowBehaviour.skimmerRicochet) ? _skimmerRicochetCount : 0;
    if (hero.has(HeroBehaviour.corvinBounce)) {
      final int corvinRicochets = hero.caromsRemaining > 0
          ? _corvinCaromsCount
          : (hero.has(HeroBehaviour.corvinDoubleBounce)
              ? _corvinDoubleBounceCount
              : _corvinBounceCount);
      if (corvinRicochets > ricochets) ricochets = corvinRicochets;
    }
    if (ricochets > 0) projectiles.ricochetsLeft[i] = ricochets;
    if (marksBoss) projectiles.willMarkBoss[i] = 1;
    _applyOrielElementCycle(i);
    _applyTorvArc(i);
    _applyKestrelBleed(i);

    _applyArrowBoons(i, tier);


    events.emit(
      SimEventType.arrowFired,
      entityA: i,
      valueA: tier.index.toDouble(),
      x: x,
      y: y,
    );

    _applyMirelleReflection(x, y, angle, tier, damageScale, mirelleDuplicateDepth);
    _applyHallOfMirrorsDuplication(x, y, angle, tier, damageScale, mirelleDuplicateDepth);
    // Echoing's own second arrow never echoes again — "a second arrow", not
    // a chain — so this is skipped for the echo itself the same way Mirelle
    // never re-triggers Torv's Arc counter on a duplicate.
    if (!isEcho) _applyEchoing(x, y, angle, tier, damageScale);
    return i;
  }

  /// *Echoing* — a flat per-shot chance (summed across whichever rolled
  /// affix slots carry it) to fire one exact extra arrow, at the same
  /// damage and in the same direction as the shot that triggered it. No
  /// card text mentions a damage penalty or a spread, unlike Mirelle's own
  /// Reflection, so neither is applied here.
  void _applyEchoing(double x, double y, double angle, DrawTier tier, double damageScale) {
    if (hero.echoChance <= 0) return;
    if (_echoRng.nextDouble() >= hero.echoChance) return;
    _spawnArrow(x, y, angle, tier, damageScale, isEcho: true);
  }

  /// *Hall of Mirrors* — "8 s where every arrow duplicates 3×, and a
  /// mirror clone of the player fights alongside at 60 % stats" (docs/07
  /// §7.3). Two genuinely separate mechanics: a guaranteed, fixed-count
  /// arrow duplication (`_applyHallOfMirrorsDuplication`, spawn-time,
  /// gated on [HeroRuntime.hallOfMirrorsRemaining] rather than any chance
  /// roll — distinct from Reflection's own probabilistic cascade below)
  /// and a temporary companion clone, the identical `CompanionSystem`
  /// primitive Zea's own Falconry (ADR 0073) already proved. *Endless
  /// Hall* (★5a) extends the duplication window; *Twin Warden* (★5b)
  /// instead raises the clone's own share to 80 % and stretches its
  /// lifetime well past any real room's length — "lasts the whole room"
  /// has no literal room-boundary hook at fire time, so this uses a long,
  /// generously-authored duration instead (ADR 0074); a room's own entity
  /// wipe on clear removes it exactly on schedule regardless. The two ★5
  /// branches are mutually exclusive: Twin Warden does not also extend
  /// the duplication window, and Endless Hall does not also raise the
  /// clone's own share.
  void _fireMirelleHallOfMirrors() {
    if (player.isNone || !entities.isAlive(player)) return;
    final int p = player.index;
    final double x = entities.posX[p];
    final double y = entities.posY[p];

    hero.hallOfMirrorsRemaining = hero.has(HeroBehaviour.mirelleEndlessHall)
        ? _mirelleEndlessHallDuration
        : _mirelleHallOfMirrorsDuration;

    final bool twinWarden = hero.has(HeroBehaviour.mirelleTwinWarden);
    final double cloneShare = twinWarden
        ? _mirelleTwinWardenCloneShare
        : _mirelleHallOfMirrorsCloneShare;
    final double cloneDuration =
        twinWarden ? _mirelleTwinWardenCloneDuration : hero.hallOfMirrorsRemaining;

    spawnCompanion(
      x,
      y,
      damageShare: cloneShare,
      fireRate: cloneShare * _mirelleBaseFireRate,
      lifetimeSeconds: cloneDuration,
      followOffsetX: -0.7,
      followOffsetY: 0.6,
    );
  }

  static const double _mirelleHallOfMirrorsDuration = 8.0;
  static const double _mirelleEndlessHallDuration = 14.0;
  static const double _mirelleHallOfMirrorsCloneShare = 0.60;
  static const double _mirelleTwinWardenCloneShare = 0.80;

  /// docs/07's own stated stat line for Mirelle ("Rate 2.20") — the
  /// clone's own "60 %/80 % stats" scales this directly, the same way
  /// [spawnCompanion]'s `damageShare` scales `playerAttack`.
  static const double _mirelleBaseFireRate = 2.20;

  /// See the doc comment on [_fireMirelleHallOfMirrors]: authored well
  /// past any real room's length, since a room's own clear wipes the
  /// clone before this would ever matter.
  static const double _mirelleTwinWardenCloneDuration = 300.0;

  /// *Reflection* — each arrow has a chance to spawn one more, which can
  /// itself duplicate again (geometric), up to a total arrow count from one
  /// original shot. *Truer Mirror* (T1a) raises the chance; *Deeper Mirror*
  /// (T1b) raises the cap; *Silvered* (T3a) removes the duplicate's own
  /// damage penalty; *Fractured* (T3b) spreads duplicates wide instead of
  /// firing them dead on top of the arrow that made them. The damage share
  /// compounds down the chain on purpose — a duplicate of a duplicate is a
  /// weaker arrow than its parent, the same way pierce falloff weakens with
  /// distance rather than resetting per hit.
  void _applyMirelleReflection(
    double x,
    double y,
    double angle,
    DrawTier tier,
    double damageScale,
    int depth,
  ) {
    if (!hero.has(HeroBehaviour.mirelleReflection)) return;
    final int cap = hero.has(HeroBehaviour.mirelleDeeperMirror)
        ? _mirelleDeeperMirrorCap
        : _mirelleReflectionCap;
    if (depth + 1 >= cap) return;

    final double chance = hero.has(HeroBehaviour.mirelleTruerMirror)
        ? _mirelleTruerMirrorChance
        : _mirelleReflectionChance;
    if (_mirelleDuplicateRng.nextDouble() >= chance) return;

    final double share = hero.has(HeroBehaviour.mirelleSilvered)
        ? 1.0
        : _mirelleReflectionDamageShare;
    double duplicateAngle = angle;
    if (hero.has(HeroBehaviour.mirelleFractured)) {
      duplicateAngle += (_mirelleDuplicateRng.nextDouble() * 2 - 1) *
          _mirelleFracturedSpreadRadians;
    }

    _spawnArrow(
      x,
      y,
      duplicateAngle,
      tier,
      damageScale * share,
      mirelleDuplicateDepth: depth + 1,
    );
  }

  static const double _mirelleReflectionChance = 0.25;
  static const double _mirelleTruerMirrorChance = 0.35;
  static const int _mirelleReflectionCap = 4;
  static const int _mirelleDeeperMirrorCap = 6;
  static const double _mirelleReflectionDamageShare = 0.85;

  /// ±20° — Fractured's own card text.
  static const double _mirelleFracturedSpreadRadians = 20 * math.pi / 180;

  /// *Hall of Mirrors*' own guaranteed duplication half — "every arrow
  /// duplicates 3×" while [HeroRuntime.hallOfMirrorsRemaining] runs, at
  /// full damage and with no chance roll, unlike Reflection's own
  /// probabilistic cascade above (which has no stated damage penalty here
  /// to remove, so Silvered makes no difference to these). Gated to
  /// depth 0 so the guaranteed triplicate never re-triggers itself; each
  /// of the 3 still passes back through `_applyMirelleReflection` at
  /// depth 1 and can cascade normally if Reflection is also active, the
  /// same as any other ordinary duplicate. Fractured's own spread is read
  /// as a general "duplicates spread wider" rule rather than one scoped
  /// to Reflection specifically, so it applies here too.
  void _applyHallOfMirrorsDuplication(
    double x,
    double y,
    double angle,
    DrawTier tier,
    double damageScale,
    int depth,
  ) {
    if (depth != 0) return;
    if (hero.hallOfMirrorsRemaining <= 0) return;

    for (int n = 0; n < _mirelleHallOfMirrorsDuplicateCount; n++) {
      double duplicateAngle = angle;
      if (hero.has(HeroBehaviour.mirelleFractured)) {
        duplicateAngle += (_mirelleDuplicateRng.nextDouble() * 2 - 1) *
            _mirelleFracturedSpreadRadians;
      }
      _spawnArrow(
        x,
        y,
        duplicateAngle,
        tier,
        damageScale,
        mirelleDuplicateDepth: 1,
      );
    }
  }

  static const int _mirelleHallOfMirrorsDuplicateCount = 3;

  /// Oriel: *Spectrum* cycles the equipped arrow's own element away in
  /// favour of Ember → Frost → Storm → Toxin, one per shot; *Prism* replaces
  /// that with all four at once for its own window. Prism wins when both are
  /// live, which is every tick it runs — Spectrum is Oriel's passive, always
  /// on, and Prism is layered on top of it rather than instead of it.
  ///
  /// Prismshaft cycles the identical rotation independent of Spectrum — "the
  /// same idea as Oriel's Spectrum passive" per [ArrowBehaviour]'s own doc
  /// comment — so it reads `hero.cycleIndex` through the same call rather
  /// than a second implementation of one rotation.
  void _applyOrielElementCycle(int i) {
    if (hero.prismRemaining > 0 && hero.has(HeroBehaviour.orielPrism)) {
      projectiles.elementMask[i] = _allElements;
      return;
    }
    if (hero.has(HeroBehaviour.orielSpectrum) ||
        hero.hasArrow(ArrowBehaviour.prismshaftCycle)) {
      projectiles.element[i] = SimElement.values[hero.cycleIndex].index;
      hero.cycleIndex = (hero.cycleIndex + 1) % SimElement.values.length;
    }
  }

  /// Torv: *Arc* marks every 5th arrow (3rd, with Frequent Arc) to chain on
  /// whichever hit it eventually lands — decided here, at release, the same
  /// way a crit is rolled once rather than per target. *Tempest Nock* does
  /// not need a mark at all: it is checked live, at hit time, against
  /// [HeroRuntime.tempestNockRemaining] directly.
  void _applyTorvArc(int i) {
    if (!hero.has(HeroBehaviour.torvArc)) return;
    hero.arrowsFired++;
    final int every =
        hero.has(HeroBehaviour.torvFrequentArc) ? _torvFrequentArcEvery : _torvArcEvery;
    if (hero.arrowsFired % every == 0) {
      projectiles.willChain[i] = 1;
    }
  }

  static const int _torvArcEvery = 5;
  static const int _torvFrequentArcEvery = 3;

  /// Kestrel: *Bleed* (T3b) — "every 4th arrow applies a 3 s bleed", tagged
  /// at release exactly like Torv's own Arc mark above (and sharing the
  /// same [HeroRuntime.arrowsFired] counter — the two are never equipped
  /// together, since exactly one hero is ever equipped, so nothing about
  /// sharing it is a real collision).
  void _applyKestrelBleed(int i) {
    if (!hero.has(HeroBehaviour.kestrelBleed)) return;
    hero.arrowsFired++;
    if (hero.arrowsFired % _kestrelBleedEvery == 0) {
      projectiles.willBleed[i] = 1;
    }
  }

  static const int _kestrelBleedEvery = 4;

  /// The element the next arrow carries.
  ///
  /// *Attunement* (#88) and *Elemental Tips* (#81) both settle on one element
  /// at pickup and store it on the runtime, so this is a read rather than a
  /// roll — an element that changed per arrow would make every elemental rider
  /// unpredictable.
  int _arrowElementIndex() =>
      boons.attunedElement?.index ?? arrowElement?.index ?? -1;

  /// Everything a Boon does to an arrow at the moment it is released.
  void _applyArrowBoons(int i, DrawTier tier) {
    boons.arrowsFired++;

    // ── Crit ───────────────────────────────────────────────────────────────
    // Rolled once per arrow, not per target: an arrow that crit its first
    // victim and not its second would make crit unreadable on a piercing shot,
    // and would put an RNG call inside the hit loop.
    //
    // *Umbral Step* guarantees the next few shots crit at a fixed multiplier
    // rather than the player's own composed one — a guarantee, not odds, so
    // it is consumed here ahead of the roll rather than folded into
    // `combat.critChance`, which would still leave it possible to miss.
    if (hero.umbralStepGuaranteedCritShots > 0) {
      hero.umbralStepGuaranteedCritShots--;
      projectiles.wasCrit[i] = 1;
      projectiles.damage[i] *= hero.has(HeroBehaviour.nyxPerfectStep)
          ? _nyxPerfectStepCritMultiplier
          : _nyxUmbralStepCritMultiplier;
    } else if (combat.critChance > 0 &&
        _critRng.nextDouble() < combat.critChance) {
      projectiles.wasCrit[i] = 1;
      projectiles.damage[i] *= combat.critMultiplier;
    }
    // *Deadeye* (#18) — crits punch through, whatever put them there. The
    // falloff exemption is applied at the hit, where the pierce index is
    // known.
    if (projectiles.wasCrit[i] == 1 && boons.has(BoonBehaviour.deadeye)) {
      projectiles.pierceRemaining[i] += BoonRuntime.deadeyePierce;
    }

    // ── The big arrows ─────────────────────────────────────────────────────
    // Counted per run rather than per room so the player can feel the count
    // approaching. A counter that silently reset at every door would make both
    // cards read as random damage.
    if (boons.has(BoonBehaviour.hammerfall) &&
        boons.arrowsFired % BoonRuntime.hammerfallEvery == 0) {
      projectiles.damage[i] *= BoonRuntime.hammerfallMultiplier;
    }
    if (boons.has(BoonBehaviour.quiverfall) &&
        boons.arrowsFired % BoonRuntime.quiverfallEvery == 0) {
      projectiles.damage[i] *= BoonRuntime.quiverfallMultiplier;
      // The stun is the downside, and it is printed on the card. Implemented as
      // a Draw-lock plus a halt so it reads as *being staggered by your own
      // shot* rather than as input being dropped.
      playerDraw.applyDrawLock(BoonRuntime.quiverfallStunSeconds);
      _stunRemaining = BoonRuntime.quiverfallStunSeconds;
    }

    // ── The Long Arrow (#25) ───────────────────────────────────────────────
    // Never despawns, never stops, infinite pierce. The lifetime is large
    // rather than infinite because an arrow that literally never retires would
    // never lay its terminal Windline stub and would hold an entity slot for
    // the whole run.
    if (boons.has(BoonBehaviour.theLongArrow)) {
      projectiles.lifetime[i] = _longArrowLifetime;
      projectiles.pierceRemaining[i] = _longArrowPierce;
    }

    // ── Confluence ─────────────────────────────────────────────────────────
    // *Total Confluence* (#76) starts every arrow at the cap; *Weaver's Grace*
    // (#74) gives one free stack. Total Confluence wins where both are held,
    // which is what the player expects from the stronger card.
    int startStacks = 0;
    if (boons.has(BoonBehaviour.totalConfluence)) {
      startStacks = maxConfluenceStacks;
    } else if (confluenceHeadStart > 0) {
      startStacks = confluenceHeadStart > maxConfluenceStacks
          ? maxConfluenceStacks
          : confluenceHeadStart;
    }
    if (startStacks > 0) {
      projectiles.confluenceStacks[i] = startStacks;
      projectiles.confluenceBonus[i] =
          ConfluenceTuning.bonusFor(startStacks) * confluenceDamageMultiplier;
    }

    // ── Multi-element arrows ───────────────────────────────────────────────
    int mask = 0;
    if (boons.has(BoonBehaviour.frostfire)) {
      mask |= (1 << SimElement.ember.index) | (1 << SimElement.frost.index);
    }
    if (boons.has(BoonBehaviour.stormblight)) {
      mask |= (1 << SimElement.storm.index) | (1 << SimElement.toxin.index);
    }
    if (boons.has(BoonBehaviour.theFourfold)) {
      mask = _allElements;
    }
    // *Elemental Overload* (#90) is periodic rather than constant, which is why
    // it is an Epic and The Fourfold is a Legendary.
    if (boons.has(BoonBehaviour.elementalOverload) &&
        boons.arrowsFired % BoonRuntime.overloadEvery == 0) {
      mask = _allElements;
    }
    if (mask != 0) projectiles.elementMask[i] = mask;
  }

  /// Long enough to cross any arena several times, short enough that the slot
  /// is eventually returned and the trail eventually laid.
  static const double _longArrowLifetime = 30.0;

  /// Effectively infinite. A real infinity would need a sentinel every pierce
  /// check has to know about.
  static const int _longArrowPierce = 1 << 20;

  static const int _allElements = 0xF;

  void _applyInput(InputSnapshot input) {
    if (player.isNone || !entities.isAlive(player)) return;
    final int i = player.index;

    // *Quiverfall* stuns the player with the recoil of their own shot, and
    // Rimefather's own "hit twice within 4s" root (docs/06 §6,
    // `playerDraw.rootRemaining`) does the identical thing from an enemy
    // hit instead of the player's own arrow — rooting rather than dropping
    // the input either way, so the stick still reads and the player can see
    // that the game heard them.
    if (_stunRemaining > 0 || playerDraw.isRooted) {
      entities.velX[i] = 0;
      entities.velY[i] = 0;
      return;
    }

    if (!input.isMoving) {
      entities.velX[i] = 0;
      entities.velY[i] = 0;
      return;
    }

    // Normalise so diagonal movement is not faster than cardinal — the classic
    // bug that makes every optimal path diagonal.
    final double magSq = input.magnitudeSquared;
    final double inv = magSq > 1.0 ? 1.0 / math.sqrt(magSq) : 1.0;

    // Momentum's speed reward, applied here and nowhere else.
    //
    // `DrawState.moveSpeedBonus` existed from Phase 3 and was referenced by
    // nothing until Phase 9 — so half of Momentum had never worked. Its
    // mitigation half did, which is why nothing looked broken: the trade
    // docs/01 §1.1 rests on was paying out at roughly half its stated rate, and
    // every balance measurement taken before this was of a game where moving
    // was quietly worse than the design says.
    // *First Blood*'s kill-speed burst — a flat bonus on top of Momentum's,
    // not a replacement for it. *Chain Kill* multiplies it by the stacked
    // kill count (capped at 3 where the stacks themselves are counted);
    // without that talent the stack count is never touched, so this always
    // reads as a plain single bonus.
    final double firstBloodBonus = hero.firstBloodSpeedRemaining > 0
        ? HeroRuntime.firstBloodSpeedBonus *
            (hero.has(HeroBehaviour.nyxChainKill) ? hero.firstBloodSpeedStacks : 1)
        : 0.0;

    // The Hollow Warden's own P2 ("Crossing its Windlines slows the
    // player", docs/06 §4) — a separate multiplicative lever from
    // Momentum's own bonus, so a player mid-Momentum crossing a Warden
    // line is slowed off their current speed rather than off a lowered
    // baseline. See ADR 0043.
    final double speed = playerMoveSpeed *
        (1.0 + playerDraw.moveSpeedBonus + firstBloodBonus) *
        playerDraw.windlineSlowFactor;

    entities.velX[i] = input.stickX * inv * speed;
    entities.velY[i] = input.stickY * inv * speed;

    // Bellweather's own "movement reversed" toll (docs/06 §6.2, ADR 0064) —
    // flips the resulting velocity, not the raw stick input, so speed and
    // every bonus above it still apply unchanged.
    if (playerDraw.movementReversed) {
      entities.velX[i] = -entities.velX[i];
      entities.velY[i] = -entities.velY[i];
    }

    entities.facing[i] = math.atan2(entities.velY[i], entities.velX[i]);
  }

  /// *Dash* (#49), and its two evolutions.
  ///
  /// The gesture that triggers this is not the simulation's concern —
  /// [InputSnapshot.dashRequested] is the whole contract, true for exactly one
  /// tick per attempt regardless of what recognised the double-tap. What
  /// happens once it fires is: an instant displacement along the current
  /// input direction (or facing, if the stick is centred), clamped short of
  /// any wall it would otherwise pass through.
  void _applyDash(InputSnapshot input, double dt) {
    if (player.isNone || !entities.isAlive(player)) return;
    if (!boons.has(BoonBehaviour.dash)) return;
    if (_stunRemaining > 0 || playerDraw.isRooted) return;

    final bool blink = boons.has(BoonBehaviour.blink);
    if (blink) {
      if (boons.blinkCharges <= 0) return;
    } else if (boons.dashCooldown > 0) {
      return;
    }

    final int p = player.index;
    final double magSq = input.magnitudeSquared;
    double dirX;
    double dirY;
    if (magSq > 1e-9) {
      final double inv = 1.0 / math.sqrt(magSq);
      dirX = input.stickX * inv;
      dirY = input.stickY * inv;
    } else {
      dirX = math.cos(entities.facing[p]);
      dirY = math.sin(entities.facing[p]);
    }

    final double fromX = entities.posX[p];
    final double fromY = entities.posY[p];
    final double r = entities.radius[p];

    // Walk outward in small steps rather than testing the far endpoint
    // directly, so a dash toward a wall stops *at* it instead of teleporting
    // through it. Fires rarely enough (a multi-second cooldown, or one of two
    // charges) that this is not a cost worth optimising away.
    double legalX = fromX;
    double legalY = fromY;
    const double step = 0.1;
    final int steps = (BoonRuntime.dashDistance / step).round();
    for (int s = 1; s <= steps; s++) {
      final double candidateX = fromX + dirX * step * s;
      final double candidateY = fromY + dirY * step * s;
      if (arena.circleHitsWall(candidateX, candidateY, r) ||
          !arena.containsPoint(candidateX, candidateY)) {
        break;
      }
      legalX = candidateX;
      legalY = candidateY;
    }

    entities.posX[p] = legalX;
    entities.posY[p] = legalY;

    if (blink) {
      boons.blinkCharges--;
      // Recharges one charge at a time on the same cooldown a plain Dash uses,
      // rather than all at once — the charge model every MOBA ability with a
      // count uses, and the only reading of "2 charges" that does not need a
      // second invented number beyond the one docs/09 already gives Dash.
      if (boons.dashCooldown <= 0) {
        boons.dashCooldown = BoonRuntime.dashCooldownSeconds;
      }
    } else {
      boons.dashCooldown = BoonRuntime.dashCooldownSeconds;
    }

    if (boons.has(BoonBehaviour.ghostStep)) {
      if (BoonRuntime.ghostStepSeconds > boons.invulnerableRemaining) {
        boons.invulnerableRemaining = BoonRuntime.ghostStepSeconds;
      }
    }

    events.emit(SimEventType.playerDashed, entityA: p, x: legalX, y: legalY);
  }

  /// Places the player. Returns the handle.
  EntityId spawnPlayer(double x, double y) {
    final EntityId id = entities.spawn(EntityKind.player);
    if (id.isNone) return id;
    final int i = id.index;
    entities.posX[i] = x;
    entities.posY[i] = y;
    entities.radius[i] = SimConfig.playerRadius;
    entities.health[i] = 100;
    entities.maxHealth[i] = 100;
    player = id;
    events.emit(SimEventType.entitySpawned, entityA: i, x: x, y: y);
    return id;
  }

  /// Generic spawn for enemies, projectiles and pickups.
  ///
  /// [radius] and [health] are required rather than defaulted: in production
  /// both come from the entity's content definition, and a silent default that
  /// disagrees with the data would produce an enemy whose hitbox does not match
  /// its sprite — visible to players, invisible in code review.
  EntityId spawnAt(
    EntityKind kind,
    double x,
    double y, {
    required double radius,
    required double health,
    int contentIndex = -1,
  }) {
    final EntityId id = entities.spawn(kind);
    if (id.isNone) return id;
    final int i = id.index;
    entities.posX[i] = x;
    entities.posY[i] = y;
    entities.radius[i] = radius;
    entities.health[i] = health;
    entities.maxHealth[i] = health;
    entities.contentIndex[i] = contentIndex;
    events.emit(SimEventType.entitySpawned, entityA: i, x: x, y: y);
    return id;
  }

  /// Swaps in a new room's geometry.
  ///
  /// Call between rooms, not during one. Everything that reads the arena reads
  /// it through this object or through [AiContext], and both are updated here.
  void loadArena(Arena next) {
    arena = next;
    ai.arena = next;
  }

  /// Places an enemy from the content table, fully initialised.
  ///
  /// The one entry point for enemies in tests and tools — [spawnAt] makes a
  /// bare entity with no definition, no plate and no behaviour, which is useful
  /// for damage-chain tests and useless for anything else.
  int spawnEnemy(EnemyArchetype archetype, double x, double y) {
    final int index = content.indexOfArchetype(archetype);
    if (index < 0) return -1;
    _refreshAiContext(SimConfig.fixedStep);
    return EnemySpawner.spawn(ai, contentIndex: index, x: x, y: y);
  }

  /// Places a boss from the content table, tagged for [BossPhaseSystem].
  ///
  /// Built on [spawnAt] rather than [EnemySpawner.spawn]: a boss has no
  /// [EnemyDefinition] to resolve radius, speed or plate data from —
  /// [BossDefinition] is deliberately leaner (see its own doc comment), so a
  /// boss's own hitbox and movement are bespoke, arena-specific work that
  /// lands with its actual fight, not invented here as a placeholder. [health]
  /// is likewise required rather than defaulted, the same reasoning
  /// [spawnAt]'s own doc comment gives: it comes from `Curves.bossHp`, which
  /// only the caller can resolve — `lib/game/sim` reads pre-resolved numbers,
  /// it does not import `Curves` (the same split [enemyHpBase] already keeps
  /// for ordinary enemies).
  int spawnBoss(
    BossArchetype archetype,
    double x,
    double y, {
    required double radius,
    required double health,
  }) {
    final int bossIndex = content.bosses.indexOfArchetype(archetype);
    if (bossIndex < 0) return -1;
    final EntityId id =
        spawnAt(EntityKind.enemy, x, y, radius: radius, health: health);
    if (id.isNone) return -1;
    final int slot = id.index;
    enemies.reset(slot);
    enemies.bossIndex[slot] = bossIndex;
    return slot;
  }

  /// Places The Cinder Choir — three effigies and the primary that holds
  /// their shared health. Test/tool entry point, the same role [spawnBoss]
  /// plays for the generic case; [CinderChoirSystem.spawn] does the real
  /// work. Returns the primary's slot.
  int spawnCinderChoir(
    double x,
    double y, {
    required double health,
    double triangleRadius = 2.2,
    double effigyRadius = 0.5,
  }) =>
      CinderChoirSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
        triangleRadius: triangleRadius,
        effigyRadius: effigyRadius,
      );

  /// Places The Ashen Choir — the Elite remix of Cinder Choir: three
  /// permanently-lit effigies, lethal-from-the-start tethers, and a
  /// fourth hidden effigy revealed only by Windline contact. Test/tool
  /// entry point, the same role [spawnBoss] plays for the generic case;
  /// [AshenChoirSystem.spawn] does the real work. Returns the primary's
  /// slot.
  int spawnAshenChoir(double x, double y, {required double health}) =>
      AshenChoirSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places Bellweather — a single stationary body whose entire threat is
  /// its own rule-tolling every 10s. Test/tool entry point, the same role
  /// [spawnBoss] plays for the generic case; [BellweatherSystem.spawn] does
  /// the real work. Returns its slot.
  int spawnBellweather(double x, double y, {required double health}) =>
      BellweatherSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places The Pale Judge — a single stationary body, permanently immune
  /// to whichever element the player's own current build favours. Test/tool
  /// entry point, the same role [spawnBoss] plays for the generic case;
  /// [PaleJudgeSystem.spawn] does the real work. Reads "the player's build"
  /// via the identical attuned-Boon-then-equipped-arrow priority
  /// `_arrowElementIndex` already uses to decide a fired arrow's own
  /// element. Returns its slot.
  int spawnPaleJudge(double x, double y, {required double health}) =>
      PaleJudgeSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
        playerElement: boons.attunedElement ?? arrowElement,
      );

  /// Places Umbral Twin — a single stationary body; its own card's
  /// differentiating mechanic (darkness lit by Windlines, audio-first
  /// telegraphs) is a presentation concern outside the sim's own
  /// architectural boundary (ADR 0066). Test/tool entry point, the same
  /// role [spawnBoss] plays for the generic case; [UmbralTwinSystem.spawn]
  /// does the real work. Returns its slot.
  int spawnUmbralTwin(double x, double y, {required double health}) =>
      UmbralTwinSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places a single friendly companion (docs/07 §7.3: Zea's own Skyhawk/
  /// Falconry, Mirelle's own Hall of Mirrors clone). Test/tool entry
  /// point; [CompanionSystem.spawn] does the real work, and wiring an
  /// actual hero's own numbers into a call here is a separate, later
  /// piece — see ADR 0071. Returns its slot.
  int spawnCompanion(
    double x,
    double y, {
    required double damageShare,
    required double fireRate,
    double radius = 0.35,
    double lifetimeSeconds = double.infinity,
    bool alwaysCrit = false,
    double followOffsetX = 0,
    double followOffsetY = 0,
  }) =>
      CompanionSystem.spawn(
        store: entities,
        companions: companions,
        events: events,
        x: x,
        y: y,
        damageShare: damageShare,
        fireRate: fireRate,
        radius: radius,
        lifetimeSeconds: lifetimeSeconds,
        alwaysCrit: alwaysCrit,
        followOffsetX: followOffsetX,
        followOffsetY: followOffsetY,
      );

  /// Places Skarn the Unmade — a single directly-hittable body, holding its
  /// own real health, that later splits into two and then four via its own
  /// system. Test/tool entry point, the same role [spawnBoss] plays for the
  /// generic case; [SkarnSystem.spawn] does the real work. Returns the
  /// primary's slot.
  int spawnSkarn(double x, double y, {required double health}) =>
      SkarnSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places Gaunt, the Iron Tide — a single always-plated body. Test/tool
  /// entry point, the same role [spawnBoss] plays for the generic case;
  /// [GauntSystem.spawn] does the real work. Returns its slot.
  int spawnGaunt(double x, double y, {required double health}) =>
      GauntSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places Silversong — a single, stationary body. Test/tool entry point,
  /// the same role [spawnBoss] plays for the generic case;
  /// [SilversongSystem.spawn] does the real work. Returns its slot.
  int spawnSilversong(double x, double y, {required double health}) =>
      SilversongSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places Vermillion, the Long Burn — a single body that lays a burning
  /// trail as it walks. Test/tool entry point, the same role [spawnBoss]
  /// plays for the generic case; [VermillionSystem.spawn] does the real
  /// work. Returns its slot.
  int spawnVermillion(double x, double y, {required double health}) =>
      VermillionSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places Rimefather — a single, stationary body whose freezing cone
  /// roots the player after two hits within 4s. Test/tool entry point, the
  /// same role [spawnBoss] plays for the generic case; [RimefatherSystem.spawn]
  /// does the real work. Returns its slot.
  int spawnRimefather(double x, double y, {required double health}) =>
      RimefatherSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places Arclight — a single, stationary body that spawns Swarmlings
  /// (Rift Maw's own cadence) and chains a lethal line to each one still
  /// alive. Test/tool entry point, the same role [spawnBoss] plays for the
  /// generic case; [ArclightSystem.spawn] does the real work. Returns its
  /// slot.
  int spawnArclight(double x, double y, {required double health}) =>
      ArclightSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places The Green Mother — a single, stationary body that spawns
  /// Knitters continuously and heals from every one still alive. Test/tool
  /// entry point, the same role [spawnBoss] plays for the generic case;
  /// [GreenMotherSystem.spawn] does the real work. Returns its slot.
  int spawnGreenMother(double x, double y, {required double health}) =>
      GreenMotherSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places Mother of Motes — a single, stationary body that spawns Motes
  /// continuously at an escalating rate, docs/06 §6.3's own Endless
  /// Descent boss #19. Test/tool entry point, the same role [spawnBoss]
  /// plays for the generic case; [MotherOfMotesSystem.spawn] does the real
  /// work. Returns its slot.
  int spawnMotherOfMotes(double x, double y, {required double health}) =>
      MotherOfMotesSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places The Loom — a single, stationary body that weaves a tightening
  /// lattice of crimson threads the player's own Windlines can cut,
  /// docs/06 §6.3's own Endless Descent boss #17. Test/tool entry point,
  /// the same role [spawnBoss] plays for the generic case;
  /// [TheLoomSystem.spawn] does the real work. Returns its slot.
  int spawnTheLoom(double x, double y, {required double health}) =>
      TheLoomSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places Coilspine — a 24-segment, chain-following serpent, docs/06
  /// §6.3's own Endless Descent boss #18. Test/tool entry point, the same
  /// role [spawnBoss] plays for the generic case; [CoilspineSystem.spawn]
  /// does the real work. Returns the invisible accounting primary's own
  /// slot — every segment is reachable via `bossParent`.
  int spawnCoilspine(double x, double y, {required double health}) =>
      CoilspineSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places The Last Warden — the true final boss, docs/06 §6.3's own
  /// Endless Descent boss #20. Test/tool entry point, the same role
  /// [spawnBoss] plays for the generic case; [LastWardenSystem.spawn] does
  /// the real work. [echoArchetypes] names up to three bosses P3 should
  /// summon echoes of — resolving those three from `Progression.
  /// bossKillCounts` is the caller's own job (see [LastWardenSystem]'s own
  /// doc comment). Returns its slot.
  int spawnLastWarden(
    double x,
    double y, {
    required double health,
    List<BossArchetype> echoArchetypes = const <BossArchetype>[],
  }) =>
      LastWardenSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
        echoArchetypes: echoArchetypes,
      );

  /// Places Thrall of the Nine — a single, stationary body orbited by nine
  /// destructible sigils, each granting one of three reused attack shapes.
  /// Test/tool entry point, the same role [spawnBoss] plays for the
  /// generic case; [ThrallOfNineSystem.spawn] does the real work. Returns
  /// the Thrall's own slot.
  int spawnThrallOfNine(double x, double y, {required double health}) =>
      ThrallOfNineSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places The Weeping Gate — a single, stationary, unplated body with no
  /// attack of its own; the threat is entirely the ordinary enemies it
  /// spawns through portals. Test/tool entry point, the same role
  /// [spawnBoss] plays for the generic case; [WeepingGateSystem.spawn]
  /// does the real work. Returns its slot.
  int spawnWeepingGate(double x, double y, {required double health}) =>
      WeepingGateSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places The Hollow Warden — a single body that mirrors the player's
  /// own position (inverted about the arena centre) and Draws once its own
  /// movement settles. Test/tool entry point, the same role [spawnBoss]
  /// plays for the generic case; [HollowWardenSystem.spawn] does the real
  /// work. Returns its slot.
  int spawnHollowWarden(double x, double y, {required double health}) =>
      HollowWardenSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Places The Quiverfall — the campaign finale's own central body plus
  /// eight orbiting spoke anchors, sweeping a converging-lines pattern
  /// around itself. Test/tool entry point, the same role [spawnBoss] plays
  /// for the generic case; [TheQuiverfallSystem.spawn] does the real work.
  /// Returns the primary's slot.
  int spawnTheQuiverfall(double x, double y, {required double health}) =>
      TheQuiverfallSystem.spawn(
        store: entities,
        enemies: enemies,
        content: content,
        events: events,
        centerX: x,
        centerY: y,
        health: health,
      );

  /// Starts a room. Waves release from here on, on the spawn system's schedule.
  void beginRoom(RoomPlan plan) {
    spawnState.begin(plan);
    globalStage = plan.globalStage;
    beginRoomForTest();
  }

  /// Half the length of the trail *Anchor Line* lays. Long enough to be worth
  /// threading, short enough to sit under the player rather than across the room.
  static const double _anchorLineHalfLength = 1.5;

  /// Begins a room without a [RoomPlan].
  ///
  /// Exists for tests and for the balance harness, which drive combat directly
  /// and still need the per-room Boon state — Aegis charges, Covenant's grace,
  /// Anchor Line's trail — to be set up exactly as a real room would.
  void beginRoomForTest() {
    boons.beginRoom();
    combat.resetLive();

    if (boons.has(BoonBehaviour.anchorLine) && !player.isNone) {
      final int p = player.index;
      windlines.add(
        fromX: entities.posX[p] - _anchorLineHalfLength,
        fromY: entities.posY[p],
        toX: entities.posX[p] + _anchorLineHalfLength,
        toY: entities.posY[p],
        expiresAt: _elapsed + windlineDuration,
        ownerIndex: 0,
        trailId: _nextTrailId++,
      );
    }

    if (boons.has(BoonBehaviour.theBargain) && !player.isNone) {
      final int p = player.index;
      entities.health[p] =
          entities.maxHealth[p] * BoonRuntime.bargainStartFraction;
    }
  }

  /// Resets to an empty room, preserving the seed stream position.
  void clearRoom() {
    entities.clear();
    enemies.clear();
    spatial.clear();
    events.clear();
    playerDraw.reset();
    hollowWardenDraw.reset();
    lastWardenDraw.reset();
    // *Lingering* (#62) — trails survive the door. Everything else about the
    // room is torn down; this is the one thing the player carries through.
    if (!boons.has(BoonBehaviour.lingering)) {
      windlines.clear();
      windlineIndex.clear();
    }
    status.clear();
    telegraphs.clear();
    hazards.clear();
    spawnState.reset();
    _fireCooldown = 0;
    _playerFiredThisTick = false;
    player = EntityId.none;
  }
}
