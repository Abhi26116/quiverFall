import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/carapace_tree.dart';
import 'package:quiverfall/game/sim/ai/choir_tree.dart';
import 'package:quiverfall/game/sim/ai/drift_tree.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/riftborn_tree.dart';
import 'package:quiverfall/game/sim/ai/rush_tree.dart';
import 'package:quiverfall/game/sim/ai/salvo_tree.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_runtime.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/hero_runtime.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/systems/boon_system.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';

/// Runs every enemy, every tick.
///
/// Five passes, in this order, and the order is the contract:
///
///  1. **Timers.** Cooldowns, plate regeneration, enrage, adaptation, the
///     Windline slow. Everything that is simply "time passing".
///  2. **Auras.** Chanter buffs, Warden-Fell suppression, Knitter healing —
///     recomputed from scratch, never accumulated. A support enemy's
///     contribution therefore vanishes on the tick it dies, with no bookkeeping
///     and no possibility of a leaked buff outliving its source.
///  3. **Behaviour.** The six family trees.
///  4. **Contact.** Bodies touching the player.
///  5. **Deaths.** Revivals, death blasts, splits, and reaping.
///
/// Deaths run last so an enemy killed by its own death blast, or by a Knitter's
/// heal being out-paced, is resolved in the same tick it happened rather than
/// lingering for one frame at zero health — which the renderer would draw.
abstract final class AiSystem {
  static void update(AiContext ctx) {
    _tickTimers(ctx);
    _applyAuras(ctx);
    _runBehaviours(ctx);
    _resolveContact(ctx);
    _resolveDeaths(ctx);
  }

  // ── 1. Timers ─────────────────────────────────────────────────────────────

  static void _tickTimers(AiContext ctx) {
    final double dt = ctx.dt;
    final int high = ctx.entities.highWater;

    for (int i = 0; i < high; i++) {
      if (ctx.entities.alive[i] == 0) continue;
      if (ctx.entities.kind[i] != EntityKind.enemy.index) continue;
      if (!ctx.hasDefinition(i)) continue;

      _countDown(ctx.enemies.attackCooldown, i, dt);
      _countDown(ctx.enemies.contactCooldown, i, dt);
      _countDown(ctx.enemies.slowRemaining, i, dt);
      _countDown(ctx.enemies.markedRemaining, i, dt);

      if (ctx.enemies.enrageRemaining[i] > 0) {
        ctx.enemies.enrageRemaining[i] -= dt;
        if (ctx.enemies.enrageRemaining[i] <= 0) {
          ctx.enemies.enrageRemaining[i] = 0;
          ctx.enemies.speedScale[i] =
              1.0 + ctx.enemies.variantOf(i).speedBonus;
        }
      }

      // Infinite immunity (the Voidtouched variant) must never count down —
      // subtracting from infinity is still infinity, but the branch documents
      // that this is intentional rather than an oversight.
      final double immunity = ctx.enemies.immuneRemaining[i];
      if (immunity > 0 && immunity.isFinite) {
        ctx.enemies.immuneRemaining[i] = immunity - dt;
        if (ctx.enemies.immuneRemaining[i] <= 0) {
          ctx.enemies.immuneRemaining[i] = 0;
          ctx.enemies.immuneElement[i] = -1;
        }
      }

      _regeneratePlate(ctx, i, dt);
      _applyWindlineSlow(ctx, i);

      // Auras are recomputed every tick from their live sources.
      ctx.enemies.attackBuff[i] = 0;
      ctx.enemies.elementSuppressed[i] = 0;

      // *Corrosion* — each Toxin stack also cuts this enemy's own damage
      // output by 2 %, recomputed live in the same pass as the reset above
      // so it decays the instant the stacks do rather than needing its own
      // timer.
      final HeroRuntime? hero = ctx.hero;
      if (hero != null && hero.has(HeroBehaviour.sableCorrosion)) {
        ctx.enemies.attackBuff[i] -=
            ctx.status.toxinStacks[i] * _sableCorrosionPerStack;
      }
    }
  }

  static const double _sableCorrosionPerStack = 0.02;

  static void _countDown(List<double> timers, int slot, double dt) {
    if (timers[slot] <= 0) return;
    timers[slot] -= dt;
    if (timers[slot] < 0) timers[slot] = 0;
  }

  static void _regeneratePlate(AiContext ctx, int slot, double dt) {
    final EnemyDefinition def = ctx.definitionOf(slot);
    if (!def.hasFrontalPlate || def.plateRegenSeconds <= 0) return;
    if (ctx.enemies.plateHealth[slot] > 0) return;

    if (ctx.enemies.plateRegen[slot] <= 0) {
      ctx.enemies.plateRegen[slot] = def.plateRegenSeconds;
      return;
    }

    ctx.enemies.plateRegen[slot] -= dt;
    if (ctx.enemies.plateRegen[slot] > 0) return;

    ctx.enemies.plateRegen[slot] = 0;
    ctx.enemies.plateHealth[slot] =
        ctx.entities.maxHealth[slot] * EnemyTuning.plateHealthFraction;
  }

  /// A live Windline slows whatever crosses it. Does not stack across segments.
  ///
  /// This is what makes the trail a *zoning* tool as well as a damage one: a
  /// player who has woven a lattice has also built a slow field, which is worth
  /// something even on the shots that thread nothing.
  static void _applyWindlineSlow(AiContext ctx, int slot) {
    // Airborne is immune, which is most of what makes the Bounder feel
    // different from everything else in its family.
    if (ctx.enemies.stateOf(slot) == AiState.airborne) return;
    if (ctx.lines.liveCount == 0) return;

    final double x = ctx.entities.posX[slot];
    final double y = ctx.entities.posY[slot];
    final double reach = ctx.entities.radius[slot] + SimConfig.windlineHitWidth;

    final int found = ctx.lineIndex.querySegment(
      x,
      y,
      x,
      y,
      reach,
      ctx.segmentScratch,
    );

    for (int i = 0; i < found; i++) {
      final int seg = ctx.segmentScratch[i];
      if (!ctx.lines.isAlive(seg)) continue;
      if (_pointNearSegment(
        x,
        y,
        ctx.lines.x0(seg),
        ctx.lines.y0(seg),
        ctx.lines.x1(seg),
        ctx.lines.y1(seg),
        reach,
      )) {
        ctx.enemies.slowRemaining[slot] = EnemyTuning.windlineSlowLinger;
        return;
      }
    }
  }

  static bool _pointNearSegment(
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

  // ── 2. Auras ──────────────────────────────────────────────────────────────

  static void _applyAuras(AiContext ctx) {
    final int high = ctx.entities.highWater;

    for (int i = 0; i < high; i++) {
      if (ctx.entities.alive[i] == 0) continue;
      if (ctx.entities.kind[i] != EntityKind.enemy.index) continue;
      if (!ctx.hasDefinition(i)) continue;

      final EnemyDefinition def = ctx.definitionOf(i);
      final double radius = def.combat.auraRadius;
      if (radius <= 0) continue;
      if (def.archetype == EnemyArchetype.weaver) continue; // discrete, not field

      final int found = ctx.spatial.queryRadius(
        ctx.entities.posX[i],
        ctx.entities.posY[i],
        radius,
      );

      for (int k = 0; k < found; k++) {
        final int other = ctx.spatial.resultAt(k);
        if (ctx.entities.alive[other] == 0) continue;
        if (ctx.entities.kind[other] != EntityKind.enemy.index) continue;

        final double dx = ctx.entities.posX[other] - ctx.entities.posX[i];
        final double dy = ctx.entities.posY[other] - ctx.entities.posY[i];
        if (dx * dx + dy * dy > radius * radius) continue;

        // A support unit is not its own ally — a Knitter that healed itself
        // would be a second HP bar rather than a priority target, which is the
        // opposite of what the Choir family exists to teach.
        if (other == i && def.archetype != EnemyArchetype.wardenFell) continue;

        switch (def.archetype) {
          case EnemyArchetype.chanter:
            ctx.enemies.attackBuff[other] += def.combat.auraStrength;
          case EnemyArchetype.wardenFell:
            // Suppresses itself too. A Warden-Fell that could be frozen while
            // making its allies unfreezable would read as a bug.
            ctx.enemies.elementSuppressed[other] = 1;
          case EnemyArchetype.knitter:
            _heal(ctx, other, def.combat.auraStrength);
          default:
            break;
        }
      }
    }
  }

  /// Heals a fraction of max HP per second, reduced by Toxin.
  ///
  /// Toxin's healing reduction is the designed counter to the Knitter, so it
  /// has to be applied *here* rather than at the Toxin end — otherwise a player
  /// who correctly built for the answer would see no difference.
  static void _heal(AiContext ctx, int slot, double fractionPerSecond) {
    final double max = ctx.entities.maxHealth[slot];
    if (ctx.entities.health[slot] >= max) return;

    final double healed = max *
        fractionPerSecond *
        ctx.status.healingMultiplier(slot) *
        ctx.dt;
    if (healed <= 0) return;

    ctx.entities.health[slot] += healed;
    if (ctx.entities.health[slot] > max) ctx.entities.health[slot] = max;
  }

  // ── 3. Behaviour ──────────────────────────────────────────────────────────

  static void _runBehaviours(AiContext ctx) {
    final int high = ctx.entities.highWater;

    for (int i = 0; i < high; i++) {
      if (ctx.entities.alive[i] == 0) continue;
      if (ctx.entities.kind[i] != EntityKind.enemy.index) continue;
      if (!ctx.hasDefinition(i)) continue;

      if (ctx.status.isFrozen(i) && _freeze(ctx, i)) continue;

      final EnemyDefinition def = ctx.definitionOf(i);
      switch (def.family) {
        case EnemyFamily.drift:
          DriftTree.update(ctx, i, def);
        case EnemyFamily.carapace:
          CarapaceTree.update(ctx, i, def);
        case EnemyFamily.rush:
          RushTree.update(ctx, i, def);
        case EnemyFamily.salvo:
          SalvoTree.update(ctx, i, def);
        case EnemyFamily.choir:
          ChoirTree.update(ctx, i, def);
        case EnemyFamily.riftborn:
          RiftbornTree.update(ctx, i, def);
      }
    }
  }

  /// Freeze is the game's hard stop, and it is resolved here rather than in each
  /// tree.
  ///
  /// A frozen enemy stops moving, drops any wind-up, and loses any temporary
  /// speed buff. Centralising it is what makes the taught interactions
  /// consistent: freeze suppresses a Cinder Mote's fuse, cancels a Lancer's
  /// charge and cancels an Ironmaw's enrage for the same reason, in the same
  /// place, rather than three archetypes each remembering to check.
  ///
  /// Returns true when the enemy's tree should be skipped this tick.
  static bool _freeze(AiContext ctx, int slot) {
    final AiState state = ctx.enemies.stateOf(slot);

    // A Bounder already in the air has to land, and a corpse has to finish
    // deciding whether it gets up. Neither is steering, so neither is affected
    // by a hard stop.
    if (state == AiState.airborne || state == AiState.downed) return false;

    ctx.entities.velX[slot] = 0;
    ctx.entities.velY[slot] = 0;

    if (state == AiState.windUp) {
      EnemyAttack.endTelegraph(ctx, slot);
      ctx.enemies.state[slot] = AiState.seek.index;
      ctx.enemies.stateTimer[slot] = 0;
      ctx.enemies.comboStep[slot] = 0;
    }

    if (ctx.enemies.enrageRemaining[slot] > 0) {
      ctx.enemies.enrageRemaining[slot] = 0;
      ctx.enemies.speedScale[slot] =
          1.0 + ctx.enemies.variantOf(slot).speedBonus;
    }

    return true;
  }

  // ── 4. Contact ────────────────────────────────────────────────────────────

  static void _resolveContact(AiContext ctx) {
    if (!ctx.hasPlayer) return;

    final int found = ctx.spatial.queryRadius(
      ctx.playerX,
      ctx.playerY,
      ctx.playerRadius + _maxContactReach,
    );

    for (int k = 0; k < found; k++) {
      final int i = ctx.spatial.resultAt(k);
      if (ctx.entities.alive[i] == 0) continue;
      if (ctx.entities.kind[i] != EntityKind.enemy.index) continue;
      if (ctx.enemies.contactCooldown[i] > 0) continue;
      if (!ctx.hasDefinition(i)) continue;

      final AiState state = ctx.enemies.stateOf(i);
      // A leaping enemy is in the air and a corpse is on the floor. Neither
      // touches you.
      if (state == AiState.airborne || state == AiState.downed) continue;

      final EnemyDefinition def = ctx.definitionOf(i);
      if (def.contactDamage <= 0) continue;

      if (!EnemyAttack.playerInCircle(
        ctx,
        ctx.entities.posX[i],
        ctx.entities.posY[i],
        ctx.entities.radius[i] + EnemyTuning.contactSlack,
      )) {
        continue;
      }

      EnemyAttack.damagePlayer(ctx, def.contactDamage, source: i);
      ctx.enemies.contactCooldown[i] = def.combat.contactCooldown;

      if (!ctx.hasPlayer) return;
    }
  }

  /// Largest enemy radius in the roster, plus slack. Used only to size the
  /// broad-phase query, so an over-estimate is harmless and an under-estimate
  /// would silently drop contact hits.
  static const double _maxContactReach = 0.6;

  // ── 5. Deaths ─────────────────────────────────────────────────────────────

  static void _resolveDeaths(AiContext ctx) {
    final int high = ctx.entities.highWater;

    for (int i = 0; i < high; i++) {
      if (ctx.entities.alive[i] == 0) continue;
      if (ctx.entities.kind[i] != EntityKind.enemy.index) continue;
      if (ctx.entities.health[i] > 0) continue;

      if (!ctx.hasDefinition(i)) {
        _reap(ctx, i);
        continue;
      }

      final EnemyDefinition def = ctx.definitionOf(i);

      if (_tryRevive(ctx, i, def)) continue;

      // Death blast before the status is cleared, because Frost suppresses it
      // and clearing first would let every frozen Cinder Mote explode.
      DriftTree.detonateAt(
        ctx,
        i,
        def,
        ctx.entities.posX[i],
        ctx.entities.posY[i],
      );

      _split(ctx, i, def);

      ctx.events.emit(
        SimEventType.entityDied,
        entityA: i,
        valueA: ctx.entities.contentIndex[i].toDouble(),
        x: ctx.entities.posX[i],
        y: ctx.entities.posY[i],
      );

      _reap(ctx, i, emitDeath: false);
    }
  }

  /// Retires a corpse: telegraph released, summoner's tally corrected, stores
  /// cleared, slot returned to the pool.
  static void _reap(AiContext ctx, int slot, {bool emitDeath = true}) {
    if (emitDeath) {
      ctx.events.emit(
        SimEventType.entityDied,
        entityA: slot,
        valueA: ctx.entities.contentIndex[slot].toDouble(),
        x: ctx.entities.posX[slot],
        y: ctx.entities.posY[slot],
      );
    }

    EnemyAttack.endTelegraph(ctx, slot);

    final BoonRuntime? boons = ctx.boons;
    if (boons != null) {
      // *Blood Pact* (#41) — a kill cancels the deferred damage. That is what
      // makes it an aggressive card rather than a defensive one: the answer to
      // the debt is to keep killing.
      BoonSystem.cancelDeferred(boons);

      // *Echo Thread* (#69) — the corpse leaves a trail. The one behaviour in
      // the catalogue authored to scale with copies, so the line grows rather
      // than the card doing nothing at ×2.
      if (boons.has(BoonBehaviour.echoThread)) {
        final double half = BoonRuntime.echoLengthPerCopy *
            (boons.echoThreadCopies < 1 ? 1 : boons.echoThreadCopies) *
            0.5;
        final double x = ctx.entities.posX[slot];
        final double y = ctx.entities.posY[slot];
        ctx.lines.add(
          fromX: x - half,
          fromY: y,
          toX: x + half,
          toY: y,
          expiresAt: ctx.now + ctx.echoLineDuration,
          ownerIndex: 0,
          trailId: ctx.nextEchoTrailId(),
        );
      }
    }

    final int spawner = ctx.enemies.spawnerSlot[slot];
    if (spawner >= 0 && ctx.enemies.liveAdds[spawner] > 0) {
      ctx.enemies.liveAdds[spawner]--;
    }

    // *First Blood* — a kill grants a speed burst. Refreshes rather than
    // stacks by default; *Chain Kill* (T3b) stacks it instead, up to 3,
    // read at the same move-speed site that already reads
    // `firstBloodSpeedBonus` — a kill that lands while the window is
    // already running adds a stack, one that lands after it has expired
    // starts a fresh single stack.
    final HeroRuntime? hero = ctx.hero;
    if (hero != null && hero.has(HeroBehaviour.nyxFirstBlood)) {
      if (hero.has(HeroBehaviour.nyxChainKill)) {
        hero.firstBloodSpeedStacks = hero.firstBloodSpeedRemaining > 0 &&
                hero.firstBloodSpeedStacks < _nyxChainKillMaxStacks
            ? hero.firstBloodSpeedStacks + 1
            : 1;
      }
      hero.firstBloodSpeedRemaining = HeroRuntime.firstBloodSpeedDuration;
    }

    // *Contagion* — half this corpse's Toxin stacks jump to the nearest
    // other enemy, read before `clearSlot` below erases them. Read before
    // the reset, since a corpse still has real stacks to give away.
    if (hero != null &&
        hero.has(HeroBehaviour.sableContagion) &&
        ctx.status.toxinStacks[slot] > 0) {
      final int jumpStacks = ctx.status.toxinStacks[slot] ~/ 2;
      if (jumpStacks > 0) {
        final int nearest = _nearestOtherEnemy(ctx, slot);
        if (nearest >= 0 && !ctx.enemies.resistsElement(nearest, SimElement.toxin)) {
          final int maxStacks = hero.has(HeroBehaviour.sableFastActing)
              ? _sableFastActingMaxStacks
              : hero.has(HeroBehaviour.sableVirulence)
                  ? _sableVirulenceMaxStacks
                  : ElementTuning.toxinMaxStacks;
          final int next = ctx.status.toxinStacks[nearest] + jumpStacks;
          ctx.status.toxinStacks[nearest] =
              next > maxStacks ? maxStacks : next;
        }
      }
    }

    // *Wildfire* (Kade, T3a) — Burn spreads to one enemy within 2 u on death,
    // applied exactly like a fresh hit's own ember application (respecting
    // whatever stack cap/duration Slow Burn grants) rather than transferring
    // a stack count the way Contagion does above: "spreads" reads as the
    // fire jumping to a new target, not a numeric share.
    if (hero != null &&
        hero.has(HeroBehaviour.kadeWildfire) &&
        ctx.status.burnStacks[slot] > 0) {
      final int nearest =
          _nearestOtherEnemyWithin(ctx, slot, _kadeWildfireRadius);
      if (nearest >= 0 && !ctx.enemies.resistsElement(nearest, SimElement.ember)) {
        ctx.status.apply(
          nearest,
          SimElement.ember,
          burnMaxStacksOverride:
              hero.has(HeroBehaviour.kadeSlowBurn) ? _kadeSlowBurnMaxStacks : null,
          burnDurationOverride:
              hero.has(HeroBehaviour.kadeSlowBurn) ? _kadeSlowBurnDuration : null,
        );
      }
    }

    // *Warden's Fury* (Wren, T5b) — "Ultimate refunds 30 % charge on
    // kill." Reads `EnemyStore.lastHitWasUltimate`, set wherever a hit
    // actually resolves against this target (`ProjectileSystem`'s own
    // primary-hit path) — a kill credits whichever arrow struck last, not
    // merely "one of the Ultimate's own arrows existed somewhere in this
    // fight." Read before `ctx.enemies.reset(slot)` below clears it.
    if (hero != null &&
        hero.has(HeroBehaviour.wrenWardensFury) &&
        ctx.enemies.lastHitWasUltimate[slot] == 1) {
      final double next = hero.ultimateCharge + _wrenWardensFuryChargeRefund;
      hero.ultimateCharge = next > 1.0 ? 1.0 : next;
    }

    // *Shatter* (Sela, T3a) — "killing a frozen enemy deals 250 % in 2 u."
    // Read before `clearSlot` below erases the frozen status, the same
    // "read before the reset" ordering Contagion/Wildfire above already
    // use. Centred on the kill itself, not the player — the one existing
    // player-sourced AoE (`SimWorld._applyPlayerCenteredNova`, Ashlin's
    // Rebirth Nova and Ovrin's Riposte) is always player-centred and lives
    // in `SimWorld` for that reason; this one needs the corpse's own
    // position, which only exists here, so it gets its own small helper
    // rather than forcing a location parameter onto a nova named for
    // always being centred on the player.
    if (hero != null &&
        hero.has(HeroBehaviour.selaShatter) &&
        ctx.status.isFrozen(slot)) {
      _applyRadiusDamage(
        ctx,
        ctx.entities.posX[slot],
        ctx.entities.posY[slot],
        _selaShatterRadius,
        ctx.playerAttack * _selaShatterDamageShare,
        excludeSlot: slot,
      );
    }

    ctx.status.clearSlot(slot);
    ctx.enemies.reset(slot);
    ctx.entities.despawn(ctx.entities.idAt(slot));
  }

  /// AoE damage from the player centred on an arbitrary point. Mirrors
  /// `SimWorld._applyPlayerCenteredNova`'s own math exactly (a
  /// `spatial.queryRadius` scan, flat `health -=`, no absorb/plate
  /// handling — that nova does not use them either), the one difference
  /// being the centre: every existing player AoE is anchored on the
  /// player, but Sela's own *Shatter* needs the kill's own location.
  static void _applyRadiusDamage(
    AiContext ctx,
    double x,
    double y,
    double radius,
    double damage, {
    int excludeSlot = -1,
  }) {
    final double radiusSq = radius * radius;
    final int found = ctx.spatial.queryRadius(x, y, radius);
    for (int i = 0; i < found; i++) {
      final int e = ctx.spatial.resultAt(i);
      if (e == excludeSlot) continue;
      if (ctx.entities.alive[e] == 0) continue;
      if (ctx.entities.kind[e] != EntityKind.enemy.index) continue;
      final double dx = ctx.entities.posX[e] - x;
      final double dy = ctx.entities.posY[e] - y;
      if (dx * dx + dy * dy > radiusSq) continue;
      ctx.entities.health[e] -= damage;
    }
  }

  static const double _selaShatterRadius = 2.0;
  static const double _selaShatterDamageShare = 2.50;
  static const double _wrenWardensFuryChargeRefund = 0.30;

  static const double _kadeWildfireRadius = 2.0;
  static const int _kadeSlowBurnMaxStacks = 3;
  static const double _kadeSlowBurnDuration = 8.0;

  /// Bounded variant of [_nearestOtherEnemy] — returns -1 when the closest
  /// other enemy overall is still further than [radius], since nothing
  /// closer than the global nearest could ever qualify instead.
  static int _nearestOtherEnemyWithin(AiContext ctx, int slot, double radius) {
    final int nearest = _nearestOtherEnemy(ctx, slot);
    if (nearest < 0) return -1;
    final double dx = ctx.entities.posX[nearest] - ctx.entities.posX[slot];
    final double dy = ctx.entities.posY[nearest] - ctx.entities.posY[slot];
    return (dx * dx + dy * dy) <= radius * radius ? nearest : -1;
  }

  /// Mirrors the same two mutually-exclusive T1 caps
  /// [ProjectileSystem._applyHeroInnateElements] reads for Sable's own
  /// Toxin application — kept alongside rather than imported, since
  /// `ProjectileSystem`'s copies are private and this is the only other
  /// place that needs to know the current cap.
  static const int _sableFastActingMaxStacks = 8;
  static const int _sableVirulenceMaxStacks = 12;

  static const int _nyxChainKillMaxStacks = 3;

  /// Nearest other living enemy to [slot], for *Contagion*. A linear scan
  /// rather than a [SpatialHash] query: this runs once per kill, not once
  /// per hit, so the cost that matters elsewhere in the sim does not apply
  /// here.
  static int _nearestOtherEnemy(AiContext ctx, int slot) {
    final double x = ctx.entities.posX[slot];
    final double y = ctx.entities.posY[slot];
    int nearest = -1;
    double nearestDistSq = double.infinity;
    for (int i = 0; i < ctx.entities.highWater; i++) {
      if (i == slot) continue;
      if (ctx.entities.alive[i] == 0) continue;
      if (ctx.entities.kind[i] != EntityKind.enemy.index) continue;
      final double dx = ctx.entities.posX[i] - x;
      final double dy = ctx.entities.posY[i] - y;
      final double distSq = dx * dx + dy * dy;
      if (distSq < nearestDistSq) {
        nearestDistSq = distSq;
        nearest = i;
      }
    }
    return nearest;
  }

  /// Puts a Gravebound down instead of killing it.
  ///
  /// The revive charge is spent on the way *in*, not on the way out, so a
  /// corpse finished off during its window dies for good — which is what makes
  /// the window a real opportunity rather than decoration.
  static bool _tryRevive(AiContext ctx, int slot, EnemyDefinition def) {
    if (ctx.enemies.revivesLeft[slot] == 0) return false;
    if (ctx.enemies.stateOf(slot) == AiState.downed) return false;

    // Ember burn at the moment of death consumes the corpse. A taught
    // interaction, surfaced by the Elemental Codex research rather than left to
    // be discovered by accident.
    if (ctx.status.burnStacks[slot] > 0) return false;

    ctx.enemies.revivesLeft[slot]--;
    ctx.enemies.state[slot] = AiState.downed.index;
    ctx.enemies.stateTimer[slot] = def.combat.windUpSeconds;
    ctx.enemies.untargetable[slot] = 1;
    ctx.entities.velX[slot] = 0;
    ctx.entities.velY[slot] = 0;

    // A sliver of health, so the corpse is a real target for any AoE rather
    // than an invulnerable prop.
    ctx.entities.health[slot] = ctx.entities.maxHealth[slot] * _corpseHealth;
    ctx.entities.radius[slot] =
        def.radius * EnemyTuning.graveboundCorpseRadiusScale;

    EnemyAttack.endTelegraph(ctx, slot);
    ctx.events.emit(
      SimEventType.entityDied,
      entityA: slot,
      valueA: ctx.entities.contentIndex[slot].toDouble(),
      valueB: 1,
      x: ctx.entities.posX[slot],
      y: ctx.entities.posY[slot],
    );
    return true;
  }

  static const double _corpseHealth = 0.02;

  /// The Twinned variant leaves two half-strength copies.
  static void _split(AiContext ctx, int slot, EnemyDefinition def) {
    if (ctx.enemies.variantOf(slot) != EnemyVariant.twinned) return;
    if (EnemySpawner.atEnemyCap(ctx)) return;

    final int contentIndex = ctx.entities.contentIndex[slot];
    final double spread = def.radius * 2;

    for (int i = 0; i < 2; i++) {
      EnemySpawner.spawn(
        ctx,
        contentIndex: contentIndex,
        x: ctx.entities.posX[slot] + (i == 0 ? -spread : spread),
        y: ctx.entities.posY[slot],
        healthScale: EnemyVariant.twinFraction,
      );
    }
  }
}
