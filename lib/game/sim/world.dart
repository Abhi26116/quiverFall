import 'dart:math' as math;

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
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
import 'package:quiverfall/game/sim/systems/boon_system.dart';
import 'package:quiverfall/game/sim/systems/confluence_system.dart';
import 'package:quiverfall/game/sim/systems/draw_system.dart';
import 'package:quiverfall/game/sim/systems/element_system.dart';
import 'package:quiverfall/game/sim/systems/firing_system.dart';
import 'package:quiverfall/game/sim/systems/hazard_system.dart';
import 'package:quiverfall/game/sim/systems/movement_system.dart';
import 'package:quiverfall/game/sim/systems/projectile_system.dart';
import 'package:quiverfall/game/sim/systems/spawn_system.dart';
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

  final ProjectileStore projectiles = ProjectileStore();

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
    final double remaining = (1.0 - _clamp01(boonDamageReduction)) *
        (1.0 - _clamp01(combat.playerStationary ? stationaryDamageReduction : 0)) *
        (1.0 - _clamp01(playerDraw.damageReduction));

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
    DrawSystem.update(
      playerDraw,
      wantsToMove,
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
        final double healed = entities.health[p] +
            entities.maxHealth[p] * hero.bloomHealPerSecond * dt;
        final double cap = entities.maxHealth[p];
        entities.health[p] = healed > cap ? cap : healed;
      }
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
    );

    // ── ai ─────────────────────────────────────────────────────────────────
    _refreshAiContext(dt);
    AiSystem.update(ai);

    // ── hazards ────────────────────────────────────────────────────────────
    HazardSystem.update(ai);

    // ── spawning ───────────────────────────────────────────────────────────
    SpawnSystem.update(ai, spawnState);

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
      ..boons = boons
      ..combat = combat
      ..hero = hero
      ..incomingDamageFactor = incomingDamageFactor
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
    final DrawTier tier = boons.has(BoonBehaviour.perfectForm) ||
            hero.flurryRemaining > 0
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
    }
  }

  static const double _orielEndlessPrismDuration = 16.0;

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

    if (hero.has(HeroBehaviour.haldenTwinSpear)) {
      _spawnArrow(fromX, fromY, baseAngle - _haldenTwinSpearHalfSpread,
          DrawTier.three, _haldenTwinSpearDamageShare);
      _spawnArrow(fromX, fromY, baseAngle + _haldenTwinSpearHalfSpread,
          DrawTier.three, _haldenTwinSpearDamageShare);
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
    _spawnArrow(fromX, fromY, baseAngle, DrawTier.three, share);
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
    for (int i = 0; i < count; i++) {
      _spawnArrow(
        fromX,
        fromY,
        start + step * i,
        DrawTier.three,
        share,
        extraPierce: extraPierce,
      );
    }
  }

  static const int _wrenVolleyArrows = 7;
  static const double _wrenVolleyDamageShare = 0.80;
  static const int _wrenWideFanArrows = 11;
  static const double _wrenWideFanDamageShare = 0.60;
  static const int _wrenFocusedFanArrows = 3;
  static const double _wrenFocusedFanDamageShare = 2.20;
  static const int _wrenFocusedFanPierce = 3;

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

  void _spawnArrow(
    double x,
    double y,
    double angle,
    DrawTier tier,
    double damageScale, {
    int extraPierce = 0,
  }) {
    final EntityId id = entities.spawn(EntityKind.projectile);
    if (id.isNone) return;

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
    _applyOrielElementCycle(i);

    _applyArrowBoons(i, tier);


    events.emit(
      SimEventType.arrowFired,
      entityA: i,
      valueA: tier.index.toDouble(),
      x: x,
      y: y,
    );
  }

  /// Oriel: *Spectrum* cycles the equipped arrow's own element away in
  /// favour of Ember → Frost → Storm → Toxin, one per shot; *Prism* replaces
  /// that with all four at once for its own window. Prism wins when both are
  /// live, which is every tick it runs — Spectrum is Oriel's passive, always
  /// on, and Prism is layered on top of it rather than instead of it.
  void _applyOrielElementCycle(int i) {
    if (hero.prismRemaining > 0 && hero.has(HeroBehaviour.orielPrism)) {
      projectiles.elementMask[i] = _allElements;
      return;
    }
    if (hero.has(HeroBehaviour.orielSpectrum)) {
      projectiles.element[i] = SimElement.values[hero.cycleIndex].index;
      hero.cycleIndex = (hero.cycleIndex + 1) % SimElement.values.length;
    }
  }

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
    if (combat.critChance > 0 && _critRng.nextDouble() < combat.critChance) {
      projectiles.wasCrit[i] = 1;
      projectiles.damage[i] *= combat.critMultiplier;
      // *Deadeye* (#18) — crits punch through. The falloff exemption is applied
      // at the hit, where the pierce index is known.
      if (boons.has(BoonBehaviour.deadeye)) {
        projectiles.pierceRemaining[i] += BoonRuntime.deadeyePierce;
      }
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

    // *Quiverfall* stuns the player with the recoil of their own shot. Rooting
    // rather than dropping the input, so the stick still reads and the player
    // can see that the game heard them.
    if (_stunRemaining > 0) {
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
    // not a replacement for it.
    final double firstBloodBonus = hero.firstBloodSpeedRemaining > 0
        ? HeroRuntime.firstBloodSpeedBonus
        : 0.0;

    final double speed = playerMoveSpeed *
        (1.0 + playerDraw.moveSpeedBonus + firstBloodBonus);

    entities.velX[i] = input.stickX * inv * speed;
    entities.velY[i] = input.stickY * inv * speed;
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
    if (_stunRemaining > 0) return;

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
