import 'dart:math' as math;

import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_runtime.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/hero_runtime.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/hazard_store.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// The one place an enemy is allowed to hurt the player.
///
/// **Every damaging path in the roster routes through [damagePlayer].** That is
/// the same rule [DamageResolver] enforces on the player's side and for the same
/// reason: a second damage path silently escapes the Momentum mitigation, the
/// contact cooldown, and the analytics that tell us what is actually killing
/// players (docs/18 §18.4, the "what got you" defeat coaching).
///
/// Damage arrives as a **fraction of the player's max HP**, never a flat number
/// (docs/05 §5.0). It is the only way threat stays constant across a 300x power
/// curve.
abstract final class EnemyAttack {
  /// Applies a fraction of the player's max HP as damage.
  ///
  /// Returns the damage actually dealt, which is zero when there is no player —
  /// a room whose player has died goes quiet rather than crashing.
  static double damagePlayer(
    AiContext ctx,
    double fraction, {
    required int source,
  }) {
    if (!ctx.hasPlayer || fraction <= 0) return 0;

    // Chanter auras land here, once, rather than at twenty-six call sites. The
    // buff is recomputed from live sources every tick, so a Chanter killed a
    // frame before the hit contributes nothing to it.
    final double buff = source >= 0 ? ctx.enemies.attackBuff[source] : 0;
    final double raw = ctx.playerMaxHealth * fraction * (1.0 + buff);

    final BoonRuntime? boons = ctx.boons;

    // *Umbral Step* — the player is untargetable while this reads above
    // zero, so an enemy attack simply cannot land. Same shape as the Boon
    // checks below it, checked first since it needs no `boons` at all.
    if ((ctx.hero?.umbralStepRemaining ?? 0) > 0) return 0;

    // Ashlin's own invulnerability — Rekindle's revive and Ember Body's
    // room-clear window both set this; the same "ignore the hit outright"
    // shape as Umbral Step just above.
    if ((ctx.hero?.ashlinInvulnRemaining ?? 0) > 0) return 0;

    // ── Ignore the hit entirely ────────────────────────────────────────────
    // Covenant's opening grace, Ghost Step's dash window, and Immortal Draw's
    // Tier III. Checked before mitigation, because "no damage" is not "very
    // little damage" — a card that promises invulnerability and lets a single
    // point through has broken its promise.
    if (boons != null) {
      if (boons.isInvulnerable) return 0;
      if (boons.has(BoonBehaviour.immortalDraw) &&
          ctx.playerDraw?.tier == DrawTier.three) {
        return 0;
      }
      // Aegis absorbs whole hits, not partial ones, and spends a charge per
      // hit regardless of size. That is what makes holding it for a big hit a
      // real decision.
      if (boons.aegisCharges > 0) {
        boons.aegisCharges--;
        return 0;
      }
    }

    // Momentum is mitigation, so moving is a *defensive* option as well as an
    // offensive one — the other half of the trade the Draw sets up.
    final double reduction = ctx.playerDraw?.damageReduction ?? 0;

    // *Verdict* (Halden) — "boss attacks deal -15 % to Halden," raised to
    // -28 % by *Warded* (T1b). `applyDamageReduction2`'s own second
    // parameter existed for exactly this — a second, independent reduction
    // source composed multiplicatively with Momentum's — and had no real
    // caller until now.
    double haldenBossReduction = 0;
    if (source >= 0 &&
        ctx.hero != null &&
        ctx.hero!.has(HeroBehaviour.haldenVerdict) &&
        ctx.enemies.isBoss(source)) {
      haldenBossReduction = ctx.hero!.has(HeroBehaviour.haldenWarded)
          ? _haldenWardedBossDamageTakenReduction
          : _haldenVerdictBossDamageTakenReduction;
    }

    double dealt = DamageResolver.applyDamageReduction2(
        raw, reduction, haldenBossReduction);

    // The build's own mitigation, already combined multiplicatively and capped
    // by LoadoutResolver. Applied as one factor so no source reaches the total
    // twice.
    dealt *= ctx.incomingDamageFactor;

    final int p = ctx.player;

    if (boons != null) {
      // The Unbroken caps a single hit. Applied after mitigation, so it is a
      // floor under a bad moment rather than a second layer of reduction.
      if (boons.has(BoonBehaviour.theUnbroken)) {
        final double cap =
            ctx.entities.maxHealth[p] * BoonRuntime.unbrokenCap;
        if (dealt > cap) dealt = cap;
      }

      // Blood Pact defers part of the hit. Cancelled by a kill, which is what
      // makes it an aggressive card rather than a defensive one.
      if (boons.has(BoonBehaviour.bloodPact)) {
        final double deferred = dealt * BoonRuntime.bloodPactFraction;
        dealt -= deferred;
        boons.deferredDamage += deferred;
        boons.deferredRemaining = BoonRuntime.bloodPactSeconds;
      }

      // Shieldweave's shield sits outside the body and is spent first.
      if (boons.shield > 0) {
        final double absorbed = dealt < boons.shield ? dealt : boons.shield;
        boons.shield -= absorbed;
        dealt -= absorbed;
      }
    }

    // *Overheal* (Lira T3a) — a second, independent shield pool (never
    // shared with Shieldweave's own `boons.shield` above — see
    // `HeroRuntime.overhealShield`'s own doc comment for why), spent the
    // same way once Shieldweave's own pool is exhausted.
    final HeroRuntime? hero = ctx.hero;
    if (hero != null && hero.overhealShield > 0) {
      final double absorbed =
          dealt < hero.overhealShield ? dealt : hero.overhealShield;
      hero.overhealShield -= absorbed;
      dealt -= absorbed;
    }

    ctx.entities.health[p] -= dealt;

    // ── Refuse to die ──────────────────────────────────────────────────────
    // Guardian Angel and Phoenix Heart are both once per run and Boon-side;
    // Ashlin's own Rekindle is the hero-side counterpart, capped at 1 (or 2,
    // with Twice Kindled) rather than a plain flag. Checked in this order —
    // cheapest first — so a player holding more than one spends the
    // cheapest before the others.
    if (ctx.entities.health[p] <= 0) {
      if (boons != null &&
          boons.has(BoonBehaviour.guardianAngel) &&
          !boons.guardianAngelSpent) {
        boons.guardianAngelSpent = true;
        ctx.entities.health[p] = BoonRuntime.guardianAngelHealth;
        ctx.events.emit(
          SimEventType.playerHit,
          entityA: p,
          entityB: source,
          x: ctx.entities.posX[p],
          y: ctx.entities.posY[p],
        );
      } else if (boons != null &&
          boons.has(BoonBehaviour.phoenixHeart) &&
          !boons.phoenixHeartSpent) {
        boons.phoenixHeartSpent = true;
        ctx.entities.health[p] =
            ctx.entities.maxHealth[p] * BoonRuntime.phoenixHeartFraction;
      } else if (hero != null && hero.has(HeroBehaviour.ashlinRekindle)) {
        final int cap = hero.has(HeroBehaviour.ashlinTwiceKindled)
            ? _ashlinTwiceKindledCharges
            : _ashlinRekindleCharges;
        if (hero.rekindlesUsed < cap) {
          hero.rekindlesUsed++;
          final double fraction = hero.has(HeroBehaviour.ashlinTwiceKindled)
              ? _ashlinTwiceKindledFraction
              : hero.has(HeroBehaviour.ashlinBrightRekindle)
                  ? _ashlinBrightRekindleFraction
                  : _ashlinRekindleFraction;
          ctx.entities.health[p] = ctx.entities.maxHealth[p] * fraction;
          hero.ashlinInvulnRemaining = _ashlinInvulnDuration;
          // The AoE nova needs playerAttack/spatial/entities together,
          // which only SimWorld has — flagged here, resolved in
          // SimWorld.tick right after AiSystem runs.
          hero.rekindleNovaPending = true;
        }
      }
    }

    ctx.events.emit(
      SimEventType.playerHit,
      entityA: p,
      entityB: source,
      valueA: dealt,
      valueB: fraction,
      x: ctx.entities.posX[p],
      y: ctx.entities.posY[p],
    );

    if (ctx.entities.health[p] <= 0) {
      ctx.events.emit(
        SimEventType.entityDied,
        entityA: p,
        x: ctx.entities.posX[p],
        y: ctx.entities.posY[p],
      );
      ctx.entities.despawn(ctx.entities.idAt(p));
      ctx.player = -1;
    }
    return dealt;
  }

  static const double _haldenVerdictBossDamageTakenReduction = 0.15;
  static const double _haldenWardedBossDamageTakenReduction = 0.28;

  static const int _ashlinRekindleCharges = 1;
  static const int _ashlinTwiceKindledCharges = 2;
  static const double _ashlinRekindleFraction = 0.45;
  static const double _ashlinBrightRekindleFraction = 0.70;
  static const double _ashlinTwiceKindledFraction = 0.30;
  static const double _ashlinInvulnDuration = 3.0;

  /// True if the player's body overlaps a circle.
  static bool playerInCircle(
    AiContext ctx,
    double x,
    double y,
    double radius,
  ) {
    if (!ctx.hasPlayer) return false;
    final double dx = ctx.playerX - x;
    final double dy = ctx.playerY - y;
    final double reach = radius + ctx.playerRadius;
    return dx * dx + dy * dy <= reach * reach;
  }

  /// True if the player lies within [width] of a segment — the hitbox of every
  /// charge, lance and beam in the game.
  static bool playerOnLine(
    AiContext ctx,
    double x0,
    double y0,
    double x1,
    double y1,
    double width,
  ) {
    if (!ctx.hasPlayer) return false;

    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double lengthSq = dx * dx + dy * dy;

    double t = 0;
    if (lengthSq > 1e-12) {
      t = ((ctx.playerX - x0) * dx + (ctx.playerY - y0) * dy) / lengthSq;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
    }

    final double gapX = ctx.playerX - (x0 + dx * t);
    final double gapY = ctx.playerY - (y0 + dy * t);
    final double reach = width + ctx.playerRadius;
    return gapX * gapX + gapY * gapY <= reach * reach;
  }

  // ── Telegraphs ────────────────────────────────────────────────────────────
  //
  // An enemy owns at most one telegraph at a time. Two simultaneous warnings
  // from one body is unreadable at phone size, and every enemy in docs/05
  // telegraphs one thing at a time by design.

  static void beginCircle(
    AiContext ctx,
    int slot,
    double x,
    double y,
    double radius,
    double lead, {
    TelegraphSeverity severity = TelegraphSeverity.warning,
  }) {
    _begin(
      ctx,
      slot,
      TelegraphShape.circle,
      severity,
      lead,
      x: x,
      y: y,
      radius: radius,
    );
  }

  static void beginLine(
    AiContext ctx,
    int slot,
    double x0,
    double y0,
    double x1,
    double y1,
    double width,
    double lead, {
    TelegraphSeverity severity = TelegraphSeverity.warning,
  }) {
    _begin(
      ctx,
      slot,
      TelegraphShape.line,
      severity,
      lead,
      x: x0,
      y: y0,
      toX: x1,
      toY: y1,
      radius: width,
    );
  }

  static void beginCone(
    AiContext ctx,
    int slot,
    double x,
    double y,
    double facing,
    double halfAngle,
    double range,
    double lead, {
    TelegraphSeverity severity = TelegraphSeverity.warning,
  }) {
    _begin(
      ctx,
      slot,
      TelegraphShape.cone,
      severity,
      lead,
      x: x,
      y: y,
      radius: range,
      angle: facing,
      halfAngle: halfAngle,
    );
  }

  /// Retargets this enemy's live telegraph, for attacks that track before they
  /// commit.
  static void retarget(AiContext ctx, int slot, double x, double y) {
    ctx.telegraphs.retarget(
      ctx.enemies.telegraphSlot[slot],
      ctx.enemies.telegraphSerial[slot],
      x,
      y,
    );
  }

  /// Moves this enemy's live telegraph with its owner.
  static void followTelegraph(AiContext ctx, int slot, double x, double y) {
    ctx.telegraphs.move(
      ctx.enemies.telegraphSlot[slot],
      ctx.enemies.telegraphSerial[slot],
      x,
      y,
    );
  }

  static void extendTelegraph(AiContext ctx, int slot, double until) {
    ctx.telegraphs.extend(
      ctx.enemies.telegraphSlot[slot],
      ctx.enemies.telegraphSerial[slot],
      until,
    );
  }

  static bool hasTelegraph(AiContext ctx, int slot) =>
      ctx.enemies.telegraphSlot[slot] >= 0 &&
      ctx.telegraphs.isAlive(ctx.enemies.telegraphSlot[slot]) &&
      ctx.telegraphs.serialAt(ctx.enemies.telegraphSlot[slot]) ==
          ctx.enemies.telegraphSerial[slot];

  static void endTelegraph(AiContext ctx, int slot) {
    ctx.telegraphs.release(
      ctx.enemies.telegraphSlot[slot],
      ctx.enemies.telegraphSerial[slot],
    );
    ctx.enemies.telegraphSlot[slot] = -1;
    ctx.enemies.telegraphSerial[slot] = 0;
  }

  static void _begin(
    AiContext ctx,
    int slot,
    TelegraphShape shape,
    TelegraphSeverity severity,
    double lead, {
    double x = 0,
    double y = 0,
    double toX = 0,
    double toY = 0,
    double radius = 0,
    double angle = 0,
    double halfAngle = 0,
  }) {
    endTelegraph(ctx, slot);

    final int id = ctx.telegraphs.add(
      shape: shape,
      severity: severity,
      owner: slot,
      x: x,
      y: y,
      toX: toX,
      toY: toY,
      radius: radius,
      angle: angle,
      halfAngle: halfAngle,
      startedAt: ctx.now,
      resolvesAt: ctx.now + lead,
    );
    if (id < 0) return;

    ctx.enemies.telegraphSlot[slot] = id;
    ctx.enemies.telegraphSerial[slot] = ctx.telegraphs.serialAt(id);

    // Announced to the presentation layer as well as drawn. The sound of a
    // wind-up is what lets a player survive a room they are not looking at.
    ctx.events.emit(
      SimEventType.telegraphStarted,
      entityA: slot,
      valueA: shape.index.toDouble(),
      valueB: severity.index.toDouble(),
      x: x,
      y: y,
    );
  }

  // ── Ordnance ──────────────────────────────────────────────────────────────

  /// A straight-line bolt. Its own body is the telegraph — it is slow enough to
  /// see and to strafe, which is why Nettles are a positioning problem rather
  /// than a damage one.
  static void fireBolt(
    AiContext ctx,
    int slot, {
    required double angle,
    required double speed,
    required double damage,
    required double radius,
    required double lifetime,
  }) {
    ctx.hazards.add(
      kind: HazardKind.bolt,
      owner: slot,
      atX: ctx.entities.posX[slot],
      atY: ctx.entities.posY[slot],
      velocityX: math.cos(angle) * speed,
      velocityY: math.sin(angle) * speed,
      lifetime: lifetime,
      hitRadius: radius,
      impactDamage: damage,
    );
  }

  /// A shell that flies for a fixed time to a fixed point.
  ///
  /// The landing ring is created here, at launch, and lives exactly as long as
  /// the flight — so the ring on the ground is always the truth about where and
  /// when the shell lands. Anything less makes lobbed attacks feel arbitrary.
  static void fireShell(
    AiContext ctx,
    int slot, {
    required double toX,
    required double toY,
    required double flightSeconds,
    required double damage,
    required double radius,
    double lingerSeconds = 0,
    double lingerDamage = 0,
  }) {
    final int telegraph = ctx.telegraphs.add(
      shape: TelegraphShape.circle,
      severity: TelegraphSeverity.warning,
      owner: slot,
      x: toX,
      y: toY,
      radius: radius,
      startedAt: ctx.now,
      resolvesAt: ctx.now + flightSeconds,
    );

    ctx.hazards.add(
      kind: HazardKind.shell,
      owner: slot,
      atX: ctx.entities.posX[slot],
      atY: ctx.entities.posY[slot],
      targetX: toX,
      targetY: toY,
      lifetime: flightSeconds,
      hitRadius: radius,
      impactDamage: damage,
      linger: lingerSeconds,
      lingerPerSecond: lingerDamage,
      telegraphSlot: telegraph,
      telegraphSerial: telegraph < 0 ? 0 : ctx.telegraphs.serialAt(telegraph),
    );
  }

  /// A persistent ground hazard. Always crimson: lethal zones are crimson, and
  /// the vocabulary is never violated.
  static void dropPuddle(
    AiContext ctx,
    int owner, {
    required double x,
    required double y,
    required double radius,
    required double damagePerSecond,
    required double seconds,
  }) {
    final int telegraph = ctx.telegraphs.add(
      shape: TelegraphShape.circle,
      severity: TelegraphSeverity.lethal,
      owner: owner,
      x: x,
      y: y,
      radius: radius,
      startedAt: ctx.now,
      resolvesAt: ctx.now + seconds,
    );

    ctx.hazards.add(
      kind: HazardKind.puddle,
      owner: owner,
      atX: x,
      atY: y,
      lifetime: seconds,
      hitRadius: radius,
      perSecondDamage: damagePerSecond,
      telegraphSlot: telegraph,
      telegraphSerial: telegraph < 0 ? 0 : ctx.telegraphs.serialAt(telegraph),
    );
  }

  /// An instantaneous blast at a point. Used by Cinder Mote detonations and
  /// Bounder slams, both of which have already telegraphed.
  static void blast(
    AiContext ctx, {
    required int source,
    required double x,
    required double y,
    required double radius,
    required double damage,
  }) {
    if (!playerInCircle(ctx, x, y, radius)) return;
    damagePlayer(ctx, damage, source: source);
  }

  /// Cone damage, for the Screecher's scream and every boss sweep after it.
  static bool playerInCone(
    AiContext ctx,
    double x,
    double y,
    double facing,
    double halfAngle,
    double range,
  ) {
    if (!ctx.hasPlayer) return false;
    return Steering.insideCone(
      x,
      y,
      facing,
      halfAngle,
      range + ctx.playerRadius,
      ctx.playerX,
      ctx.playerY,
    );
  }
}
