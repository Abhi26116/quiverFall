import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';

/// The Quiverfall — docs/06 §12, chapter 12's boss. "Tests: mastery ·
/// Campaign finale." "The sky itself, falling. Fought on a collapsing
/// arena that loses 8% of its floor per phase."
///
/// Named `TheQuiverfallSystem`, not `QuiverfallSystem` — every other
/// system in this directory drops a card's own leading "The"
/// (`GreenMotherSystem`, `WeepingGateSystem`), but this boss shares its
/// bare name with both the game's own package and *Quiverfall* the Boon
/// (`BoonBehaviour.quiverfall`) — a real naming collision in the design
/// itself, not invented here, worth keeping unambiguous in code.
///
/// **P1 only, built here.** "P1 — The First Shard: A vast descending
/// shard fires converging amber lines from the arena edges. Safe space is
/// the intersection gaps." A single, stationary body at the arena's own
/// centre (every boss arena is still an ordinary room's own arena — ADR
/// 0017/0021's still-open gap) sweeping several lines around itself, all
/// converging on its own position — mechanically, a grander version of
/// Cinder Choir's own P2 tether sweep (ADR 0019): more spokes (8, not 3 —
/// "the arena edges", plural, authored to read as more than Cinder
/// Choir's own triangle), reusing the identical warning-then-lethal,
/// one-telegraph-per-owning-child shape verbatim. A fitting reuse for the
/// campaign's own "greatest hits" finale — see ADR 0032.
///
/// **The "collapsing arena" itself is not built.** "Loses 8% of its floor
/// per *phase*" reads as a phase-transition event, not a P1-internal
/// mechanic — nothing shrinks *during* P1 under this reading, so nothing
/// here needed a floor-shrink system at all. Building one regardless would
/// be a real, sizeable new capability (nothing in `Arena` today changes
/// shape mid-room) that this pass does not attempt; flagged alongside the
/// rest of what P2/P3 need.
///
/// **P2, built here: "The Choir Reforms" — all eleven previous bosses
/// appear as 12s echoes, one at a time, each using a single signature
/// attack.** Rather than literally invoking each of the eleven other
/// systems' own private, child-entity-entangled tick methods, "a single
/// signature attack" is read as one of the small vocabulary of telegraphed
/// shapes this game already has — a rotating multi-line sweep, a circle
/// slam, a cone, a line/beam, a bolt, a portal spawn — with each boss's
/// own echo picking whichever of that vocabulary its own actual mechanic
/// is closest to, reusing that boss's own already-established numbers
/// (damage, radius, timing) rather than inventing new ones. See ADR 0044
/// for the full boss-by-boss mapping and the reasoning behind it.
///
/// The eight spoke-anchor children P1 already spawns are reused as-is —
/// no new entities are spawned or despawned per echo — and every echo
/// shares the primary's own `state`/`stateTimer`/`attackCooldown` fields,
/// reset whenever the active echo changes (`comboStep`, free until now,
/// holds the current echo index; `bossTimer`, unused by P1's own sweep,
/// holds elapsed time in the current 12s window). The very first echo
/// (Cinder Choir's own) reuses `_tickSweep` verbatim and both `comboStep`
/// and `bossTimer` start at zero by construction, so the P1→P2 transition
/// has no visible seam: the boss is already mid-sweep when P2 begins, and
/// simply keeps going.
///
/// **P3, built here: "Quiverfall" — the shard shatters into 40 fragments
/// raining continuously; the boss is invulnerable except when the
/// player's own Windline lattice connects three or more of them,
/// channelling them into the core — "the only fight in the game that
/// *requires* Confluence."** Replaces P2's own echo cycling entirely —
/// the shard shattering is a new, third state, not the greatest-hits
/// replay continuing underneath it — the same `bossPhase`-gated
/// replacement every other multi-phase boss's own P3 already uses.
///
/// **The 40 fragments are geometry, not entities.** Nothing about them
/// is ever independently targeted, damaged, or killed — the card's own
/// "channels them into the core" reads as a conduit for the player's own
/// arrows, not a destructible body — so `_fragmentX`/`_fragmentY` are
/// pure functions of an ordinal (an 8×5 grid spread across the arena's
/// own bounds), computed on demand rather than forty extra entities
/// competing with the room's own actual threats for the shared entity
/// pool. Every tick, each of the forty positions is queried against
/// `ctx.lineIndex` (the same rebuilt-every-tick spatial index Confluence
/// and this boss's own P2 slow already use) for a live player-owned
/// Windline passing within a small radius; the boss counts as *connected*
/// while three or more read positive.
///
/// **The conditional plate is the fourth reuse of the same trick**
/// (Weeping Gate ADR 0042, the Green Mother ADR 0047, Arclight ADR
/// 0051): a full-circle `plateHalfArc`, a tiny positive
/// `plateFlatFactor` rather than a literal zero, and `plateHealth`
/// toggled every tick between `0` (open, three or more fragments
/// connected) and `maxHealth` (shut, fewer than three). This is the
/// piece the card's own "requires Confluence" claim rests on: the boss
/// is only ever hittable while the player is actively holding a real
/// three-point lattice, not merely has threaded one in the past.
///
/// **"Raining continuously"** is read as ongoing background pressure
/// independent of the lattice puzzle, not another puzzle of its own: a
/// telegraphed circle at a random fragment position, on a short repeating
/// cooldown, dealing the Thresher's own persistent-aura anchor (9%) —
/// dodgeable, continuous, and never the "heavy hit" this roster reserves
/// for decisive blows, since this card's own difficulty is entirely in
/// the targeting puzzle, not in a single strike. See ADR 0054.
abstract final class TheQuiverfallSystem {
  /// "The arena edges", plural — authored as more than Cinder Choir's own
  /// three-spoke triangle (ADR 0018), not a GDD-stated count.
  static const int spokeCount = 8;

  /// Authored, not GDD-stated: proportioned against Cinder Choir's own
  /// tether rate (45°/s across 3 spokes 120° apart, ADR 0019) so a fixed
  /// point sees a line sweep past it about as often here (8 spokes 45°
  /// apart, so a slower rate keeps the "safe dwell time between passes"
  /// comparable rather than compressing it eight-fold). Real tuning is a
  /// balance-harness (Phase 14) question, same as every other unproven
  /// cadence this session has flagged. See ADR 0032.
  static const double _sweepRadiansPerSecond = 20 * math.pi / 180;

  /// How far each spoke reaches. Authored, slightly longer than Cinder
  /// Choir's own 9.0 (ADR 0019) to comfortably clear a default 16x9
  /// arena's own corners from a central spawn — no real boss arena exists
  /// yet (ADR 0017/0021's still-open gap).
  static const double _spokeLength = 10.0;

  /// ADR 0008/0019's own reused line-hazard width.
  static const double _spokeWidth = SimConfig.windlineHitWidth;

  /// The Thresher-derived "persistent aura" anchor, reused yet again.
  static const double _damage = 0.09;
  static const double _cooldown = 0.6;

  /// Same magnitude as [_cooldown] — the amber warning window before a
  /// spoke actually starts hitting, docs/06 rule 2's own most-repeated
  /// rule, the identical choice Cinder Choir's own sweep already made.
  static const double _warningSeconds = _cooldown;

  // ── P2: "The Choir Reforms" ───────────────────────────────────────────
  // See ADR 0044.

  /// docs/06's own stated echo length.
  static const double _echoWindowSeconds = 12.0;

  /// One entry per prior campaign boss, chapter order (1-11) — the order
  /// they were fought in, so the "greatest hits" replay is chronological.
  static const int _echoCount = 11;

  /// A cone shape reused for every cone echo below — Silversong's,
  /// Rimefather's, and Thrall's own P1 cones all happen to share this
  /// exact half-angle and range (docs/05's own common early-cone shape).
  static const double _echoConeHalfAngle = 30 * math.pi / 180;
  static const double _echoConeRange = 5.0;

  /// A line width reused for every line/bolt echo below — the same
  /// generic Windline-hazard width every boss in the roster already
  /// shares.
  static const double _echoLineWidth = SimConfig.windlineHitWidth;

  // ── P3: Quiverfall ─────────────────────────────────────────────────────
  // See ADR 0054.

  /// docs/06 §12 P3's own stated total, laid out as an 8×5 grid.
  static const int _p3FragmentCols = 8;
  static const int _p3FragmentRows = 5;
  static const int _p3FragmentCount = _p3FragmentCols * _p3FragmentRows;

  /// docs/06 §12 P3's own stated threshold.
  static const int _p3FragmentsNeeded = 3;

  /// Authored — how close a live player Windline must pass to "connect"
  /// a fragment. Small enough that a lattice has to be deliberately
  /// routed through the grid, not merely drawn somewhere in its general
  /// vicinity.
  static const double _p3FragmentTouchRadius = 0.6;

  /// Kept clear of the arena's own walls.
  static const double _p3FragmentMargin = 1.0;

  /// `_armourFor` only takes the flat-factor branch when it reads greater
  /// than zero — the fourth reuse of the same conditional-invulnerability
  /// trick this roster already established (Weeping Gate ADR 0042, the
  /// Green Mother ADR 0047, Arclight ADR 0051).
  static const double _p3ShutPlateFactor = 0.0001;

  /// Authored — docs/06 gives "continuously" no exact cadence. Frequent
  /// enough to read as ongoing pressure rather than an occasional attack.
  static const double _p3RainWindUpSeconds = _warningSeconds;
  static const double _p3RainCooldownSeconds = 1.0;
  static const double _p3RainRadius = 1.2;

  /// The Thresher's own persistent-aura anchor — ongoing, dodgeable
  /// pressure, deliberately *not* the roster's own "heavy hit": this
  /// card's own difficulty is the targeting puzzle, not a single strike.
  static const double _p3RainDamage = 0.09;

  /// Places the boss's central body plus [spokeCount] invisible,
  /// untargetable anchor children — one per spoke, existing solely to own
  /// that spoke's own telegraph (an enemy owns at most one at a time).
  /// Returns the primary's slot, or -1 if the entity pool was full or
  /// [BossArchetype.quiverfall] has no catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 0.8,
  }) {
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.quiverfall);
    if (bossIndex < 0) return -1;

    final EntityId primaryId = store.spawn(EntityKind.enemy);
    if (primaryId.isNone) return -1;
    final int primary = primaryId.index;

    store.posX[primary] = centerX;
    store.posY[primary] = centerY;
    store.radius[primary] = radius;
    store.health[primary] = health;
    store.maxHealth[primary] = health;
    store.contentIndex[primary] = -1;
    events.emit(SimEventType.entitySpawned, entityA: primary, x: centerX, y: centerY);

    enemies.reset(primary);
    enemies.bossIndex[primary] = bossIndex;

    for (int spoke = 0; spoke < spokeCount; spoke++) {
      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      // An accounting anchor, not a body — same shape Cinder Choir's own
      // invisible primary already uses (ADR 0018).
      store.posX[slot] = centerX;
      store.posY[slot] = centerY;
      store.radius[slot] = 0.01;
      store.health[slot] = health;
      store.maxHealth[slot] = health;
      store.contentIndex[slot] = -1;
      events.emit(SimEventType.entitySpawned, entityA: slot, x: centerX, y: centerY);

      enemies.reset(slot);
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = spoke;
      enemies.untargetable[slot] = 1;
    }

    return primary;
  }

  static void update(AiContext ctx) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final ContentLibrary content = ctx.content;
    final double dt = ctx.dt;

    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.quiverfall) {
        continue;
      }

      // The primary's own health reached zero this tick. The eight spoke
      // anchors are untargetable and have no death condition of their
      // own — left alone, they would sit alive forever, and the boss
      // room's own "zero alive enemies" clear condition (ADR 0021) would
      // never fire. The same cleanup `CinderChoirSystem._despawnChildren`
      // already does for its own children.
      if (store.health[i] <= 0) {
        _despawnChildren(ctx, i);
        continue;
      }

      // P3: the shard shatters — the echo cycle stops entirely, replaced
      // by the fragment lattice and the conditional plate (see the class
      // doc comment). Whatever the last echo left telegraphed is cleared
      // exactly once, on the transition itself (`bossActiveChildIndex` as
      // a one-time latch, free — nothing else in this system touches it)
      // — not every tick, since P3's own rain mechanic needs `state`/
      // `stateTimer`/`attackCooldown` for its own wind-up/cooldown cycle
      // from here on.
      if (enemies.bossPhase[i] >= 2) {
        if (enemies.bossActiveChildIndex[i] == 0) {
          _clearCurrentAttack(ctx, i);
          enemies.bossActiveChildIndex[i] = 1;
        }
        _tickP3(ctx, i, dt);
        continue;
      }

      if (enemies.bossPhase[i] >= 1) {
        _tickEcho(ctx, i, dt);
        continue;
      }

      _tickSweep(ctx, i, dt);
    }
  }

  /// Advances the current echo's own clock and, once it runs out, rotates
  /// [comboStep] to the next boss in chapter order and resets every field
  /// an echo's own attack could have left behind — then dispatches to
  /// that echo's own tick method. See the class doc comment and ADR 0044
  /// for the full boss-by-boss mapping.
  static void _tickEcho(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    enemies.bossTimer[primary] += dt;
    if (enemies.bossTimer[primary] >= _echoWindowSeconds) {
      // Carries any overshoot forward rather than snapping to zero, the
      // same "never systematically drifts late" rule `_tickSweep`'s own
      // rotation timer already follows.
      enemies.bossTimer[primary] -= _echoWindowSeconds;
      enemies.comboStep[primary] = (enemies.comboStep[primary] + 1) % _echoCount;
      _clearCurrentAttack(ctx, primary);
    }

    switch (enemies.comboStep[primary]) {
      case 0: // The Cinder Choir — the tether sweep, reused verbatim.
        _tickSweep(ctx, primary, dt);

      case 1: // Gaunt, the Iron Tide — the P2 shockwave slam (ADR 0035).
        _tickCircleSlamEcho(
          ctx,
          primary,
          dt,
          windUpSeconds: 1.8,
          radius: 5.0,
          damage: 0.09 * 2.10,
          cooldownSeconds: 2.0,
        );

      case 2: // Silversong — the Draw-locking cone, not a damage hit.
        _tickConeEcho(
          ctx,
          primary,
          dt,
          windUpSeconds: 0.6,
          cooldownSeconds: 2.5,
          onHit: (AiContext c) => c.playerDraw?.applyDrawLock(2.5),
        );

      case 3: // The Hollow Warden — the heavy bolt (ADR 0031).
        _tickHollowWardenEcho(ctx, primary, dt);

      case 4: // Vermillion, the Long Burn — the P2 charge (ADR 0037).
        _tickLineEcho(
          ctx,
          primary,
          dt,
          windUpSeconds: 0.6,
          length: 6.0,
          cooldownSeconds: 3.0,
          onHit: (AiContext c) =>
              EnemyAttack.damagePlayer(c, 0.09 * 2.10, source: primary),
        );

      case 5: // Rimefather — the frost cone (P1's own).
        _tickConeEcho(
          ctx,
          primary,
          dt,
          windUpSeconds: 0.6,
          cooldownSeconds: 1.5,
          onHit: (AiContext c) =>
              EnemyAttack.damagePlayer(c, 0.09, source: primary),
        );

      case 6: // Arclight — the chain bolt (P1's own).
        _tickLineEcho(
          ctx,
          primary,
          dt,
          windUpSeconds: 0.6,
          length: 6.0,
          cooldownSeconds: 0.6,
          onHit: (AiContext c) =>
              EnemyAttack.damagePlayer(c, 0.09, source: primary),
        );

      case 7: // The Green Mother — a root eruption, real Toxin (ADR 0040).
        _tickLineEcho(
          ctx,
          primary,
          dt,
          windUpSeconds: 0.6,
          length: 5.0,
          cooldownSeconds: 3.0,
          onHit: (AiContext c) {
            if (c.hasPlayer) c.status.apply(c.player, SimElement.toxin);
          },
        );
        // `ElementSystem` never ticks the player's own Toxin — Green
        // Mother's own P2 already established that this boss applies the
        // DoT itself, every tick, at the shared rate. See ADR 0040.
        if (ctx.hasPlayer && ctx.status.toxinStacks[ctx.player] > 0) {
          EnemyAttack.damagePlayer(
            ctx,
            ElementTuning.toxinPerStackPerSecond *
                ctx.status.toxinStacks[ctx.player] *
                dt,
            source: primary,
          );
        }

      case 8: // Thrall of the Nine — its first ability, a cone (ADR 0029).
        _tickConeEcho(
          ctx,
          primary,
          dt,
          windUpSeconds: 0.6,
          cooldownSeconds: 1.0,
          onHit: (AiContext c) =>
              EnemyAttack.damagePlayer(c, 0.09, source: primary),
        );

      case 9: // The Weeping Gate — a portal (ADR 0030).
        _tickWeepingGateEcho(ctx, primary, dt);

      case 10: // Skarn the Unmade — the ground slam (ADR 0034).
        _tickCircleSlamEcho(
          ctx,
          primary,
          dt,
          windUpSeconds: 1.8,
          radius: 3.0,
          damage: 0.09 * 2.10,
          cooldownSeconds: 2.0,
        );
    }
  }

  /// Ends whatever telegraph the current echo left live — the primary's
  /// own, or (echo 0 only) every spoke's — and resets every shared field
  /// an echo's own attack could have left mid-cycle. Called both when the
  /// active echo changes and, every tick, once P3's own freeze begins.
  static void _clearCurrentAttack(AiContext ctx, int primary) {
    final EnemyStore enemies = ctx.enemies;
    if (EnemyAttack.hasTelegraph(ctx, primary)) {
      EnemyAttack.endTelegraph(ctx, primary);
    }
    _clearSpokes(ctx, primary);
    enemies.state[primary] = AiState.idle.index;
    enemies.stateTimer[primary] = 0;
    enemies.attackCooldown[primary] = 0;
    enemies.bossSweepAngle[primary] = 0;
  }

  /// A generic windUp → AoE circle around the caster's own position →
  /// cooldown cycle — Gaunt's own P2 shockwave and Skarn's own P1 slam are
  /// both this exact shape, just with different numbers.
  static void _tickCircleSlamEcho(
    AiContext ctx,
    int primary,
    double dt, {
    required double windUpSeconds,
    required double radius,
    required double damage,
    required double cooldownSeconds,
  }) {
    final EnemyStore enemies = ctx.enemies;
    final EntityStore store = ctx.entities;

    if (enemies.stateOf(primary) == AiState.windUp) {
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;
      if (EnemyAttack.playerInCircle(
          ctx, store.posX[primary], store.posY[primary], radius)) {
        EnemyAttack.damagePlayer(ctx, damage, source: primary);
      }
      if (EnemyAttack.hasTelegraph(ctx, primary)) {
        EnemyAttack.endTelegraph(ctx, primary);
      }
      enemies.attackCooldown[primary] = cooldownSeconds;
      enemies.state[primary] = AiState.idle.index;
      return;
    }

    enemies.state[primary] = AiState.idle.index;
    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }

    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = windUpSeconds;
    EnemyAttack.beginCircle(
      ctx,
      primary,
      store.posX[primary],
      store.posY[primary],
      radius,
      windUpSeconds,
    );
  }

  /// A generic windUp → cone facing the player at wind-up start → cooldown
  /// cycle. [onHit] is what the cone actually does on a landed hit —
  /// Silversong's own cone Draw-locks rather than damaging; every other
  /// cone echo damages.
  static void _tickConeEcho(
    AiContext ctx,
    int primary,
    double dt, {
    required double windUpSeconds,
    required double cooldownSeconds,
    required void Function(AiContext ctx) onHit,
  }) {
    final EnemyStore enemies = ctx.enemies;
    final EntityStore store = ctx.entities;

    if (enemies.stateOf(primary) == AiState.windUp) {
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;
      if (EnemyAttack.playerInCone(
        ctx,
        store.posX[primary],
        store.posY[primary],
        store.facing[primary],
        _echoConeHalfAngle,
        _echoConeRange,
      )) {
        onHit(ctx);
      }
      if (EnemyAttack.hasTelegraph(ctx, primary)) {
        EnemyAttack.endTelegraph(ctx, primary);
      }
      enemies.attackCooldown[primary] = cooldownSeconds;
      enemies.state[primary] = AiState.idle.index;
      return;
    }

    enemies.state[primary] = AiState.idle.index;
    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }
    if (!ctx.hasPlayer) return;

    final double angle = math.atan2(
      ctx.playerY - store.posY[primary],
      ctx.playerX - store.posX[primary],
    );
    store.facing[primary] = angle;
    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = windUpSeconds;
    EnemyAttack.beginCone(
      ctx,
      primary,
      store.posX[primary],
      store.posY[primary],
      angle,
      _echoConeHalfAngle,
      _echoConeRange,
      windUpSeconds,
    );
  }

  /// A generic windUp → straight line toward the player's own position at
  /// wind-up start → cooldown cycle, reading the committed endpoint back
  /// from the telegraph itself (the same trick ADR 0030/0037/0040 already
  /// established) rather than tracking a second field. [onHit] is what a
  /// landed hit actually does — raw damage for most, a Toxin application
  /// for the Green Mother's own echo.
  static void _tickLineEcho(
    AiContext ctx,
    int primary,
    double dt, {
    required double windUpSeconds,
    required double length,
    required double cooldownSeconds,
    required void Function(AiContext ctx) onHit,
  }) {
    final EnemyStore enemies = ctx.enemies;
    final EntityStore store = ctx.entities;

    if (enemies.stateOf(primary) == AiState.windUp) {
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;
      final int telegraphSlot = enemies.telegraphSlot[primary];
      if (EnemyAttack.hasTelegraph(ctx, primary) &&
          EnemyAttack.playerOnLine(
            ctx,
            ctx.telegraphs.xAt(telegraphSlot),
            ctx.telegraphs.yAt(telegraphSlot),
            ctx.telegraphs.toXAt(telegraphSlot),
            ctx.telegraphs.toYAt(telegraphSlot),
            _echoLineWidth,
          )) {
        onHit(ctx);
      }
      if (EnemyAttack.hasTelegraph(ctx, primary)) {
        EnemyAttack.endTelegraph(ctx, primary);
      }
      enemies.attackCooldown[primary] = cooldownSeconds;
      enemies.state[primary] = AiState.idle.index;
      return;
    }

    enemies.state[primary] = AiState.idle.index;
    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }
    if (!ctx.hasPlayer) return;

    final double x0 = store.posX[primary];
    final double y0 = store.posY[primary];
    final double angle = math.atan2(ctx.playerY - y0, ctx.playerX - x0);
    final double x1 = x0 + length * math.cos(angle);
    final double y1 = y0 + length * math.sin(angle);
    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = windUpSeconds;
    EnemyAttack.beginLine(
        ctx, primary, x0, y0, x1, y1, _echoLineWidth, windUpSeconds);
  }

  /// The Hollow Warden's own echo: a wind-up (this boss's own Draw ramp is
  /// not replicated — see ADR 0044) followed by the same `EnemyAttack.
  /// fireBolt` primitive ADR 0031's own heavy shot already fires with,
  /// reusing its exact numbers.
  static void _tickHollowWardenEcho(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;
    final EntityStore store = ctx.entities;

    const double windUpSeconds = 0.6;
    const double boltSpeed = 8.0;
    const double boltRange = 14.0;
    const double boltDamage = 0.06 * 2.10;
    const double cooldownSeconds = 2.0;

    if (enemies.stateOf(primary) == AiState.windUp) {
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;
      if (ctx.hasPlayer) {
        final double angle = math.atan2(
          ctx.playerY - store.posY[primary],
          ctx.playerX - store.posX[primary],
        );
        EnemyAttack.fireBolt(
          ctx,
          primary,
          angle: angle,
          speed: boltSpeed,
          damage: boltDamage,
          radius: EnemyTuning.boltRadius,
          lifetime: boltRange / boltSpeed,
        );
      }
      if (EnemyAttack.hasTelegraph(ctx, primary)) {
        EnemyAttack.endTelegraph(ctx, primary);
      }
      enemies.attackCooldown[primary] = cooldownSeconds;
      enemies.state[primary] = AiState.idle.index;
      return;
    }

    enemies.state[primary] = AiState.idle.index;
    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }
    if (!ctx.hasPlayer) return;

    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = windUpSeconds;
    EnemyAttack.beginLine(
      ctx,
      primary,
      store.posX[primary],
      store.posY[primary],
      ctx.playerX,
      ctx.playerY,
      _echoLineWidth,
      windUpSeconds,
    );
  }

  /// The Weeping Gate's own echo: the identical wind-up-a-circle-then-
  /// spawn-there shape ADR 0030 already built, drawing from the same four
  /// Riftborn archetypes ADR 0042's own P2 introduced (the ids duplicated
  /// here rather than exposed from `WeepingGateSystem`, which keeps them
  /// private — the same "reuse the shape, not the private field" rule
  /// this session already applies to borrowed movement).
  static void _tickWeepingGateEcho(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    const double windUpSeconds = 0.5;
    const double intervalSeconds = 4.0;
    const double placementRadius = 0.5;
    const List<String> riftbornIds = <String>[
      'riftMaw',
      'echo',
      'gravebound',
      'nullborn',
    ];

    if (enemies.stateOf(primary) == AiState.windUp) {
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;

      if (EnemyAttack.hasTelegraph(ctx, primary)) {
        final int telegraphSlot = enemies.telegraphSlot[primary];
        final double x = ctx.telegraphs.xAt(telegraphSlot);
        final double y = ctx.telegraphs.yAt(telegraphSlot);
        EnemyAttack.endTelegraph(ctx, primary);

        if (!EnemySpawner.atEnemyCap(ctx)) {
          final String id = riftbornIds[ctx.rng.nextInt(riftbornIds.length)];
          final int contentIndex = ctx.content.enemyIndexById[id] ?? -1;
          if (contentIndex >= 0) {
            EnemySpawner.spawn(
              ctx,
              contentIndex: contentIndex,
              x: x,
              y: y,
              spawnerSlot: primary,
            );
          }
        }
      }

      enemies.attackCooldown[primary] = intervalSeconds;
      enemies.state[primary] = AiState.idle.index;
      return;
    }

    enemies.state[primary] = AiState.idle.index;
    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }

    EnemySpawner.findSpawnPoint(ctx, placementRadius);
    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = windUpSeconds;
    EnemyAttack.beginCircle(
      ctx,
      primary,
      EnemySpawner.pointX,
      EnemySpawner.pointY,
      placementRadius,
      windUpSeconds,
    );
  }

  static void _despawnChildren(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
      store.despawn(store.idAt(j));
    }
  }

  /// Advances the shared sweep angle, keeps every spoke's own telegraph
  /// pointed the right way, and damages the player on a cooldown once the
  /// warning window has passed — `CinderChoirSystem._tickTetherSweep`
  /// verbatim, just against [spokeCount] spokes instead of three.
  static void _tickSweep(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    enemies.bossSweepAngle[primary] += _sweepRadiansPerSecond * dt;
    if (enemies.bossSweepAngle[primary] > 2 * math.pi) {
      enemies.bossSweepAngle[primary] -= 2 * math.pi;
    }

    final bool warningDone =
        enemies.bossSweepAngle[primary] >= _sweepRadiansPerSecond * _warningSeconds;
    final TelegraphSeverity severity =
        warningDone ? TelegraphSeverity.lethal : TelegraphSeverity.warning;

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
    }

    final double centerX = ctx.entities.posX[primary];
    final double centerY = ctx.entities.posY[primary];
    bool playerHit = false;

    final int high = ctx.entities.highWater;
    for (int j = 0; j < high; j++) {
      if (ctx.entities.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;

      final double angle = 2 * math.pi * enemies.bossChildIndex[j] / spokeCount +
          enemies.bossSweepAngle[primary];
      final double toX = centerX + _spokeLength * math.cos(angle);
      final double toY = centerY + _spokeLength * math.sin(angle);

      if (EnemyAttack.hasTelegraph(ctx, j) &&
          ctx.telegraphs.severityAt(enemies.telegraphSlot[j]) == severity) {
        EnemyAttack.retarget(ctx, j, toX, toY);
        EnemyAttack.extendTelegraph(ctx, j, ctx.now + _cooldown);
      } else {
        EnemyAttack.beginLine(
          ctx,
          j,
          centerX,
          centerY,
          toX,
          toY,
          _spokeWidth,
          _cooldown,
          severity: severity,
        );
      }

      if (warningDone &&
          EnemyAttack.playerOnLine(ctx, centerX, centerY, toX, toY, _spokeWidth)) {
        playerHit = true;
      }
    }

    if (playerHit && enemies.attackCooldown[primary] <= 0) {
      EnemyAttack.damagePlayer(ctx, _damage, source: primary);
      enemies.attackCooldown[primary] = _cooldown;
    }
  }

  static void _clearSpokes(AiContext ctx, int primary) {
    final int high = ctx.entities.highWater;
    for (int j = 0; j < high; j++) {
      if (ctx.entities.alive[j] == 0) continue;
      if (ctx.enemies.bossParent[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
    }
  }

  /// P3's own whole mechanic: the plate stays shut except while the
  /// player's own live lattice currently connects at least
  /// [_p3FragmentsNeeded] of the forty fragment positions, plus an
  /// ongoing, dodgeable rain of small hits at random fragments.
  static void _tickP3(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;
    final EntityStore store = ctx.entities;

    enemies.plateHalfArc[primary] = math.pi;
    enemies.plateFlatFactor[primary] = _p3ShutPlateFactor;
    final int connected = _countConnectedFragments(ctx);
    enemies.plateHealth[primary] =
        connected >= _p3FragmentsNeeded ? 0 : store.maxHealth[primary];

    _tickRain(ctx, primary, dt);
  }

  /// Ordinal → world position on the fragment grid. Pure geometry, not an
  /// entity — see the class doc comment.
  static double _fragmentX(AiContext ctx, int ordinal) {
    final int col = ordinal % _p3FragmentCols;
    final double usable = ctx.arena.width - _p3FragmentMargin * 2;
    return _p3FragmentMargin + usable * (col + 0.5) / _p3FragmentCols;
  }

  static double _fragmentY(AiContext ctx, int ordinal) {
    final int row = ordinal ~/ _p3FragmentCols;
    final double usable = ctx.arena.height - _p3FragmentMargin * 2;
    return _p3FragmentMargin + usable * (row + 0.5) / _p3FragmentRows;
  }

  /// How many of the forty fragment positions currently have a live
  /// player-owned Windline passing within [_p3FragmentTouchRadius] —
  /// queried through `ctx.lineIndex`, the same rebuilt-every-tick spatial
  /// index Confluence and this boss's own P2 slow already use.
  static int _countConnectedFragments(AiContext ctx) {
    int count = 0;
    for (int f = 0; f < _p3FragmentCount; f++) {
      final double fx = _fragmentX(ctx, f);
      final double fy = _fragmentY(ctx, f);

      final int found = ctx.lineIndex
          .querySegment(fx, fy, fx, fy, _p3FragmentTouchRadius, ctx.segmentScratch);
      for (int c = 0; c < found; c++) {
        final int seg = ctx.segmentScratch[c];
        if (!ctx.lines.isAlive(seg)) continue;
        // `0` is the fixed sentinel every consumer of `ownerAt` already
        // treats as "the player's own trail" (`ProjectileSystem`'s own
        // private `_playerOwner`).
        if (ctx.lines.ownerAt(seg) != 0) continue;
        if (_pointNearSegment(fx, fy, ctx.lines.x0(seg), ctx.lines.y0(seg),
            ctx.lines.x1(seg), ctx.lines.y1(seg), _p3FragmentTouchRadius)) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  static bool _pointNearSegment(double px, double py, double ax, double ay,
      double bx, double by, double radius) {
    final double dx = bx - ax;
    final double dy = by - ay;
    final double lenSq = dx * dx + dy * dy;
    double t = lenSq <= 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / lenSq;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final double cx = ax + dx * t;
    final double cy = ay + dy * t;
    final double ox = px - cx;
    final double oy = py - cy;
    return ox * ox + oy * oy <= radius * radius;
  }

  /// A telegraphed strike at a random fragment position, on a short
  /// repeating cooldown — ongoing background pressure independent of the
  /// lattice puzzle itself.
  static void _tickRain(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    if (enemies.stateOf(primary) == AiState.windUp) {
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;
      _resolveRain(ctx, primary);
      enemies.state[primary] = AiState.idle.index;
      enemies.attackCooldown[primary] = _p3RainCooldownSeconds;
      return;
    }

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }

    final int ordinal = ctx.rng.nextInt(_p3FragmentCount);
    final double x = _fragmentX(ctx, ordinal);
    final double y = _fragmentY(ctx, ordinal);
    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = _p3RainWindUpSeconds;
    EnemyAttack.beginCircle(ctx, primary, x, y, _p3RainRadius, _p3RainWindUpSeconds);
  }

  static void _resolveRain(AiContext ctx, int primary) {
    final int telegraphSlot = ctx.enemies.telegraphSlot[primary];
    if (telegraphSlot < 0) return;

    final double x = ctx.telegraphs.xAt(telegraphSlot);
    final double y = ctx.telegraphs.yAt(telegraphSlot);
    EnemyAttack.beginCircle(ctx, primary, x, y, _p3RainRadius, 0,
        severity: TelegraphSeverity.lethal);
    EnemyAttack.blast(
      ctx,
      source: primary,
      x: x,
      y: y,
      radius: _p3RainRadius,
      damage: _p3RainDamage,
    );
  }
}
