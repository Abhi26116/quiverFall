import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// The Cinder Choir — docs/06 §1, chapter 1's boss. "Tests: the Draw."
///
/// **P1/P2 only.** "Three linked effigies on a triangle... only the effigy
/// whose eyes are lit is vulnerable; the other two are plated like a Husk...
/// Tier III breaks plate." That reuses the *existing* frontal-plate armour
/// system unmodified (`ArmourFactor`'s own tier switch already gives Tier III
/// full damage through any plate) — the only new work is the rotation timer
/// and the shared-pool wiring `EnemyStore.linkedHealthSlot` exists for.
/// P2 adds "tethers become damaging crimson lines that sweep the arena at
/// 45°/s" — three lines, reusing `EnemyAttack.playerOnLine`/`beginLine`, the
/// same primitive every charge and beam in the roster already hits with.
///
/// P3 ("all three light simultaneously... killing one permanently removes
/// it") is a different mechanic — individually-killable bodies rather than a
/// shared pool — and is not built yet; see ADR 0018/0019. Once `bossPhase`
/// reaches 2 this system stops rotating, clears any live tether telegraphs,
/// and does nothing further — a known, flagged gap rather than a silent one.
abstract final class CinderChoirSystem {
  /// docs/06 §1 P1: "The lit one rotates every 6 s."
  static const double _p1RotationSeconds = 6.0;

  /// docs/06 §1 P2: "Rotation drops to 4 s."
  static const double _p2RotationSeconds = 4.0;

  /// How many effigies. Named rather than inlined as `3` everywhere, since
  /// P3's individual-death mechanic (ADR 0018) will need to know when this
  /// count drops.
  static const int childCount = 3;

  /// Reused, not invented: `EnemyTuning.plateHealthFraction` (0.45) is what
  /// every ordinary Husk sizes its own plate pool from. Applied here to the
  /// *shared* pool's max health rather than an individual effigy's, since an
  /// effigy has no meaningful health of its own — see ADR 0018 for why that
  /// makes "brute-force it, slowly" a very slow option indeed at boss scale,
  /// rather than an invented, boss-specific number.
  static const double _plateHealthFraction = 0.45;

  /// A full circle, not a frontal arc: `_armourFor`'s own flank rule ("a hit
  /// from behind the plate's arc takes full damage at any tier") exists so
  /// flanking is a real alternative to the Draw — but here the card's whole
  /// point is *which effigy*, not *which angle*, so an unlit effigy is
  /// plated from every direction. See ADR 0018.
  static const double _fullCirclePlateHalfArc = math.pi;

  // ── P2: the tether sweep ────────────────────────────────────────────────
  // See ADR 0019 for the full reasoning behind every number below.

  /// docs/06 §1 P2's own stated rate.
  static const double _p2SweepRadiansPerSecond = 45 * math.pi / 180;

  /// How far each of the three spokes reaches. Authored, not a GDD number —
  /// no boss arena exists yet to size it against (ADR 0017's own gap); large
  /// enough to threaten a `SimWorld`'s default 16x9 arena from a roughly
  /// central spawn.
  static const double _p2TetherLength = 9.0;

  /// ADR 0008's identical problem, reused rather than re-solved: Kade's own
  /// Pyre Line wall had no stated width either, and the fix there was
  /// `SimConfig.windlineHitWidth` — "the one 'is this entity standing on the
  /// line' number already shipped for a line-shaped hazard."
  static const double _p2TetherWidth = SimConfig.windlineHitWidth;

  /// Reused from the Thresher (docs/05) — "a permanent aura... no wind-up
  /// because it has no gap" is the closest existing analogue to a
  /// continuous rotating lethal zone, and its own numbers (9% of max HP,
  /// every 0.6 s) are what this reuses rather than inventing a boss-specific
  /// pair.
  static const double _p2TetherDamage = 0.09;
  static const double _p2TetherCooldown = 0.6;

  /// How long each spoke shows amber before it starts actually hitting, once
  /// P2 begins. docs/06 rule 2 — "every attack is telegraphed... no boss
  /// ever damages the player with something they could not have seen" — is
  /// this game's most repeated rule; the Thresher's own continuous aura
  /// skips a wind-up only because it has been visible since it spawned.
  /// Cinder Choir's sweep begins at a specific moment the player must adapt
  /// to, so it gets one — reusing [_p2TetherCooldown]'s own magnitude rather
  /// than inventing a third number.
  static const double _p2WarningSeconds = _p2TetherCooldown;

  // ── P3: alternating cones, killable one at a time ──────────────────────
  // See ADR 0020.

  /// docs/06 §1 P3's own stated number: "90° flame cones" is a full angle,
  /// so half of it.
  static const double _p3ConeHalfAngle = math.pi / 4;

  /// Same magnitude as every other number this boss's own kit already uses
  /// (`_p2TetherCooldown`/`_p2WarningSeconds`) rather than a fourth,
  /// unrelated invented value.
  static const double _p3ConeWindUpSeconds = _p2TetherCooldown;

  /// Reused directly, not re-derived: the same 9%-of-max-HP anchor P2's own
  /// tether uses (the Thresher's aura).
  static const double _p3ConeDamage = _p2TetherDamage;

  /// Reused directly: the same reach P2's own spokes use.
  static const double _p3ConeRange = _p2TetherLength;

  /// Positions three effigies on a triangle around `(centerX, centerY)` and
  /// links their health to a new primary boss entity holding the real pool.
  /// Returns the primary's slot, or -1 if the entity pool was full or
  /// [BossArchetype.cinderChoir] has no catalogue entry.
  ///
  /// Takes raw stores rather than a `SimWorld`, the same shape every other
  /// system in this directory uses (`BossPhaseSystem.update`'s own
  /// signature) — a spawn *factory* still belongs beside its own system
  /// rather than as a `SimWorld` convenience method, since this one is
  /// bespoke to a single archetype, unlike `SimWorld.spawnEnemy`/`spawnBoss`,
  /// which are generic across the whole roster.
  ///
  /// [triangleRadius] and [effigyRadius] are authored staging, not GDD
  /// numbers — docs/06 gives no arena geometry for any boss yet (no boss
  /// arena exists at all — ADR 0017's own "no spawn integration" gap).
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double triangleRadius = 2.2,
    double effigyRadius = 0.5,
  }) {
    final int bossIndex =
        content.bosses.indexOfArchetype(BossArchetype.cinderChoir);
    if (bossIndex < 0) return -1;

    final EntityId primaryId = store.spawn(EntityKind.enemy);
    if (primaryId.isNone) return -1;
    final int primary = primaryId.index;

    // An accounting anchor, not a body — near-zero radius so an ordinary
    // shot cannot land on it by accident (see `linkedHealthSlot`'s own doc
    // comment: a hit that somehow does land here is still correct, since an
    // unlinked slot just damages its own health).
    store.posX[primary] = centerX;
    store.posY[primary] = centerY;
    store.radius[primary] = 0.01;
    store.health[primary] = health;
    store.maxHealth[primary] = health;
    store.contentIndex[primary] = -1;
    events.emit(SimEventType.entitySpawned, entityA: primary, x: centerX, y: centerY);

    enemies.reset(primary);
    enemies.bossIndex[primary] = bossIndex;
    enemies.untargetable[primary] = 1;

    final double plateHealth = _plateHealthFraction * health;

    for (int child = 0; child < childCount; child++) {
      // Index 0 at the top, spaced 120° apart — an arbitrary but stable
      // triangle orientation.
      final double angle = -math.pi / 2 + child * (2 * math.pi / childCount);
      final double x = centerX + triangleRadius * math.cos(angle);
      final double y = centerY + triangleRadius * math.sin(angle);

      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      store.posX[slot] = x;
      store.posY[slot] = y;
      store.radius[slot] = effigyRadius;
      // An effigy's own health/maxHealth are never read for damage — see
      // `linkedHealthSlot` — but a positive value keeps it out of any
      // "already dead" fast path that might read it before that link is
      // consulted.
      store.health[slot] = health;
      store.maxHealth[slot] = health;
      store.contentIndex[slot] = -1;
      events.emit(SimEventType.entitySpawned, entityA: slot, x: x, y: y);

      enemies.reset(slot);
      enemies.linkedHealthSlot[slot] = primary;
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = child;

      // Child 0 starts lit (fully vulnerable); the other two start plated.
      // `_rotate` below reuses this exact same "plateHealth 0 vs full" shape
      // every rotation after, so the initial state is not a special case.
      if (child == 0) {
        enemies.plateHealth[slot] = 0;
      } else {
        enemies.plateHealth[slot] = plateHealth;
        enemies.plateHalfArc[slot] = _fullCirclePlateHalfArc;
      }
    }

    enemies.bossActiveChildIndex[primary] = 0;
    enemies.bossTimer[primary] = _p1RotationSeconds;
    return primary;
  }

  /// Advances every live Cinder Choir's rotation and (in P2) tether sweep.
  ///
  /// Called from `SimWorld.tick` after `_refreshAiContext`, sharing
  /// `BossPhaseSystem`'s own `SystemOrder.bossPhase` slot rather than
  /// claiming a new one — see that field's own doc comment. Takes an
  /// [AiContext], not raw stores like [spawn] or `BossPhaseSystem.update`:
  /// the tether sweep needs `EnemyAttack`'s player-facing helpers
  /// (`playerOnLine`, `damagePlayer`, telegraph management), which are
  /// themselves written against [AiContext] — the same object every other
  /// enemy's own attack logic in `lib/game/sim/ai` already runs on.
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.cinderChoir) {
        continue;
      }

      // P3 first, so a split that just happened (or a child that just died)
      // is reflected in `store.health[i]` — the sum this tick, not last
      // tick's — before the death check right below reads it.
      if (enemies.bossPhase[i] == 2) {
        _tickP3(ctx, i, dt);
      }

      // The primary's own health reached zero this tick — in P1/P2, a hit or
      // a DoT tick redirected here through `linkedHealthSlot`; in P3, the
      // last of the three independent pools just emptied (`_tickP3` mirrors
      // their sum into this same field for exactly this check to keep
      // working unmodified). `AiSystem`'s death pass reaps the primary
      // itself through the ordinary bare-entity path — see that pass's own
      // `hasDefinition` guard. `_despawnChildren` is the safety net for any
      // child that is somehow still alive at that moment (P1/P2: always, by
      // construction; P3: only if several died in the same tick a moment
      // faster than this check runs) — quietly, no `entityDied` for a child,
      // only the primary's own death is "the boss died".
      if (store.health[i] <= 0) {
        _despawnChildren(ctx, i);
        continue;
      }

      // P3 own attack logic already ran above; nothing below applies to it.
      if (enemies.bossPhase[i] >= 2) continue;

      enemies.bossTimer[i] -= dt;
      if (enemies.bossTimer[i] <= 0) {
        final double rotation = enemies.bossPhase[i] == 0
            ? _p1RotationSeconds
            : _p2RotationSeconds;
        // Carries any overshoot forward rather than snapping to the full
        // duration, so a rotation never systematically drifts late.
        enemies.bossTimer[i] += rotation;
        _rotate(store, enemies, i);
      }

      if (enemies.bossPhase[i] == 1) {
        _tickTetherSweep(ctx, i, dt);
      }
    }
  }

  static void _rotate(EntityStore store, EnemyStore enemies, int primary) {
    final int current = enemies.bossActiveChildIndex[primary];
    final int next = (current + 1) % childCount;
    final double plateHealth =
        _plateHealthFraction * store.maxHealth[primary];

    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.linkedHealthSlot[j] != primary) continue;

      final int childIndex = enemies.bossChildIndex[j];
      if (childIndex == next) {
        // The incoming lit effigy — fully vulnerable.
        enemies.plateHealth[j] = 0;
      } else if (childIndex == current) {
        // The outgoing effigy — re-plated. An effigy an "impatient player"
        // already broke by attrition (see the class doc comment) stays
        // broken: this only restores an effigy that was plated the whole
        // time it was *not* lit, which — by construction — is exactly what
        // `current` was until this call.
        enemies.plateHealth[j] = plateHealth;
        enemies.plateHalfArc[j] = _fullCirclePlateHalfArc;
      }
      // The third effigy (neither current nor next) is untouched.
    }

    enemies.bossActiveChildIndex[primary] = next;
  }

  static void _despawnChildren(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      // `bossParent`, not `linkedHealthSlot`: P3 clears the latter on split,
      // but a child is still this primary's own for cleanup purposes either
      // way.
      if (enemies.bossParent[j] != primary) continue;
      // A child reaped here could be mid cone wind-up (P3) with a live
      // telegraph nobody will ever resolve or expire it — end it explicitly,
      // the same first step the ordinary death path (`AiSystem._reap`)
      // already takes for every other enemy.
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
      store.despawn(store.idAt(j));
    }
  }

  /// Advances the sweep angle, keeps each of the three tether telegraphs
  /// pointed the right way, and damages the player on a cooldown once the
  /// initial warning window has passed. One spoke per child, tracked on
  /// that child's own `telegraphSlot`/`telegraphSerial` — the same fields
  /// `EnemyAttack` already manages one-per-entity for every ordinary enemy.
  static void _tickTetherSweep(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    enemies.bossSweepAngle[primary] += _p2SweepRadiansPerSecond * dt;
    // Kept bounded — this angle otherwise grows for the rest of the fight.
    if (enemies.bossSweepAngle[primary] > 2 * math.pi) {
      enemies.bossSweepAngle[primary] -= 2 * math.pi;
    }

    final bool warningDone = enemies.bossSweepAngle[primary] >=
        _p2SweepRadiansPerSecond * _p2WarningSeconds;
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
      if (enemies.linkedHealthSlot[j] != primary) continue;

      final double angle = -math.pi / 2 +
          enemies.bossChildIndex[j] * (2 * math.pi / childCount) +
          enemies.bossSweepAngle[primary];
      final double toX = centerX + _p2TetherLength * math.cos(angle);
      final double toY = centerY + _p2TetherLength * math.sin(angle);

      if (EnemyAttack.hasTelegraph(ctx, j) &&
          ctx.telegraphs.severityAt(enemies.telegraphSlot[j]) == severity) {
        // Same severity as last tick — just keep sweeping it.
        EnemyAttack.retarget(ctx, j, toX, toY);
        EnemyAttack.extendTelegraph(ctx, j, ctx.now + _p2TetherCooldown);
      } else {
        // Either the very first tick of P2, or the warning→lethal
        // transition — `beginLine` ends whatever was there first.
        EnemyAttack.beginLine(
          ctx,
          j,
          centerX,
          centerY,
          toX,
          toY,
          _p2TetherWidth,
          _p2TetherCooldown,
          severity: severity,
        );
      }

      if (warningDone &&
          EnemyAttack.playerOnLine(ctx, centerX, centerY, toX, toY, _p2TetherWidth)) {
        playerHit = true;
      }
    }

    if (playerHit && enemies.attackCooldown[primary] <= 0) {
      EnemyAttack.damagePlayer(ctx, _p2TetherDamage, source: primary);
      enemies.attackCooldown[primary] = _p2TetherCooldown;
    }
  }

  static void _clearTethers(AiContext ctx, int primary) {
    final int high = ctx.entities.highWater;
    for (int j = 0; j < high; j++) {
      if (ctx.entities.alive[j] == 0) continue;
      if (ctx.enemies.linkedHealthSlot[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
    }
  }

  // ── P3 ───────────────────────────────────────────────────────────────────

  /// The one-time split (docs/06 §1 P3: "All three light simultaneously"),
  /// then the ongoing alternating-cone cycle. Called every tick this boss is
  /// in P3; the split itself only runs the first time, detected by whether
  /// any child is still health-linked to [primary] at all.
  static void _tickP3(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;

    bool stillShared = false;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.linkedHealthSlot[j] == primary) {
        stillShared = true;
        break;
      }
    }

    if (stillShared) {
      // Wipe P2's leftover tether telegraphs *before* anything below might
      // start a cone telegraph on the same slot this same tick.
      _clearTethers(ctx, primary);

      int aliveCount = 0;
      for (int j = 0; j < high; j++) {
        if (store.alive[j] == 0) continue;
        if (enemies.bossParent[j] != primary) continue;
        aliveCount++;
      }
      final double share =
          aliveCount > 0 ? store.health[primary] / aliveCount : 0;

      for (int j = 0; j < high; j++) {
        if (store.alive[j] == 0) continue;
        if (enemies.bossParent[j] != primary) continue;
        // Un-share: from here on this child's own health is the real one.
        enemies.linkedHealthSlot[j] = -1;
        store.health[j] = share;
        store.maxHealth[j] = share;
        // "All three light simultaneously" — no more plate distinction.
        enemies.plateHealth[j] = 0;
      }
    }

    // `BossPhaseSystem` and the death check just below both read
    // `store.health[primary]` as this boss's real HP; after the split above
    // that is a derived sum, not any single field's own truth, so it is
    // recomputed every tick from whichever children are still alive.
    //
    // Only overwrites it when children were actually found: a boss spawned
    // through the generic `SimWorld.spawnBoss` (no `bossParent` children at
    // all — `boss_phase_system_test.dart`'s own scaffold, testing the phase
    // machine in isolation) must not have its real health zeroed out here
    // and be mistaken for "the last child just died".
    double sum = 0;
    int found = 0;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      sum += store.health[j];
      found++;
    }
    if (found > 0) store.health[primary] = sum;

    _tickCones(ctx, primary, dt);
  }

  /// Advances whichever effigy currently holds the "turn": counts down its
  /// own wind-up (`EnemyStore.state`/`stateTimer` — the same fields every
  /// ordinary enemy's own family tree already uses for this, unused by a
  /// bare boss child until now), resolves into a lethal cone flash and a
  /// damage check on expiry, then hands the turn to the next living child —
  /// "alternating", read as strict round-robin with no gap between one
  /// resolving and the next beginning.
  static void _tickCones(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final int activeIndex = enemies.bossActiveChildIndex[primary];
    final int activeSlot = _findChild(ctx, primary, activeIndex);

    // Nobody is currently wound up — either this is P3's very first tick, or
    // the last attacker just resolved (or died mid-turn). Hand off and begin
    // the next one's wind-up in the same tick, so a turn never sits idle.
    if (activeSlot < 0 || enemies.stateOf(activeSlot) != AiState.windUp) {
      final int next = activeSlot < 0
          ? _nextAliveChildIndex(ctx, primary, activeIndex)
          : activeIndex;
      if (next < 0) return; // none left; the primary's own death handles it
      final int nextSlot = _findChild(ctx, primary, next);
      if (nextSlot < 0) return;
      enemies.bossActiveChildIndex[primary] = next;
      _beginWindUp(ctx, primary, nextSlot);
      return;
    }

    enemies.stateTimer[activeSlot] -= dt;
    if (enemies.stateTimer[activeSlot] > 0) return;

    // Resolve: a one-tick lethal flash exactly where the amber cone was
    // aimed, the same "second `beginCone` call, `resolvesAt: now`" shape the
    // Screecher's own scream already uses.
    final double x = store.posX[primary];
    final double y = store.posY[primary];
    final double facing = store.facing[activeSlot];
    EnemyAttack.beginCone(
      ctx,
      activeSlot,
      x,
      y,
      facing,
      _p3ConeHalfAngle,
      _p3ConeRange,
      0,
      severity: TelegraphSeverity.lethal,
    );
    if (EnemyAttack.playerInCone(ctx, x, y, facing, _p3ConeHalfAngle, _p3ConeRange)) {
      EnemyAttack.damagePlayer(ctx, _p3ConeDamage, source: primary);
    }
    enemies.state[activeSlot] = AiState.idle.index;

    final int next = _nextAliveChildIndex(ctx, primary, activeIndex);
    if (next < 0) return;
    final int nextSlot = _findChild(ctx, primary, next);
    if (nextSlot < 0) return;
    enemies.bossActiveChildIndex[primary] = next;
    _beginWindUp(ctx, primary, nextSlot);
  }

  static void _beginWindUp(AiContext ctx, int primary, int slot) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    enemies.state[slot] = AiState.windUp.index;
    enemies.stateTimer[slot] = _p3ConeWindUpSeconds;

    final double x = store.posX[primary];
    final double y = store.posY[primary];
    final double facing = ctx.hasPlayer
        ? math.atan2(ctx.playerY - y, ctx.playerX - x)
        : store.facing[slot];
    store.facing[slot] = facing;

    EnemyAttack.beginCone(
      ctx,
      slot,
      x,
      y,
      facing,
      _p3ConeHalfAngle,
      _p3ConeRange,
      _p3ConeWindUpSeconds,
    );
  }

  /// This boss's own living child at ordinal [childIndex], or -1.
  static int _findChild(AiContext ctx, int primary, int childIndex) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (enemies.bossChildIndex[j] == childIndex) return j;
    }
    return -1;
  }

  /// The next living child's ordinal after [from], wrapping — or -1 if none
  /// remain (the primary's own death, handled by the caller, follows within
  /// the same tick once its summed health reaches zero).
  static int _nextAliveChildIndex(AiContext ctx, int primary, int from) {
    for (int step = 1; step <= childCount; step++) {
      final int candidate = (from + step) % childCount;
      if (_findChild(ctx, primary, candidate) >= 0) return candidate;
    }
    return -1;
  }
}
