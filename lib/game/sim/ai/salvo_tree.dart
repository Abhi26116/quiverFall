import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// SALVO — the position tax.
///
/// Rush enemies say "don't stand". Salvo enemies say "don't stand *there*"
/// (docs/05 §5.4). Every one of them converts an area of the arena into a
/// decision, which is what stops the movement game from being a single
/// undifferentiated "keep moving".
abstract final class SalvoTree {
  static void update(AiContext ctx, int slot, EnemyDefinition def) {
    switch (def.archetype) {
      case EnemyArchetype.spitter:
        _spitter(ctx, slot, def);
      case EnemyArchetype.nettle:
        _nettle(ctx, slot, def);
      case EnemyArchetype.longeye:
        _longeye(ctx, slot, def);
      case EnemyArchetype.mortarite:
        _mortarite(ctx, slot, def);
      case EnemyArchetype.screecher:
        _screecher(ctx, slot, def);
      default:
        _nettle(ctx, slot, def);
    }
  }

  /// Shared approach for every Salvo unit: hold the stand-off, face the player,
  /// and open fire when in range and off cooldown.
  ///
  /// Returns true when the caller should begin its wind-up.
  static bool _hold(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return false;
    }

    ctx.enemies.state[slot] = AiState.reposition.index;
    Steering.holdRange(
      ctx,
      slot,
      ctx.playerX,
      ctx.playerY,
      c.keepDistance,
      Steering.speedOf(ctx, slot, def),
    );
    Steering.faceToward(
      ctx,
      slot,
      ctx.playerX,
      ctx.playerY,
      c.turnRateDegrees,
    );

    return ctx.enemies.attackCooldown[slot] <= 0 &&
        ctx.distanceSquaredToPlayer(slot) <= c.attackRange * c.attackRange;
  }

  /// Ticks a wind-up. Returns true on the tick it completes.
  static bool _windUpDone(AiContext ctx, int slot) {
    Steering.halt(ctx, slot);
    ctx.enemies.stateTimer[slot] -= ctx.dt;
    return ctx.enemies.stateTimer[slot] <= 0;
  }

  static void _recoverInto(AiContext ctx, int slot, EnemyCombat c) {
    ctx.enemies.state[slot] = AiState.recover.index;
    ctx.enemies.stateTimer[slot] = c.recoverySeconds;
    ctx.enemies.attackCooldown[slot] = c.attackCooldown;
  }

  // ── Spitter ───────────────────────────────────────────────────────────────

  /// Kites backward at 6 u and lobs an acid glob that leaves a crimson puddle.
  ///
  /// Puddles do not stack, so a Spitter denies *an* area rather than escalating
  /// one — which is what makes cornering it the answer instead of out-running
  /// it forever.
  static void _spitter(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    switch (ctx.enemies.stateOf(slot)) {
      case AiState.windUp:
        if (!_windUpDone(ctx, slot)) return;
        EnemyAttack.endTelegraph(ctx, slot);
        if (ctx.hasPlayer) {
          EnemyAttack.fireShell(
            ctx,
            slot,
            toX: ctx.enemies.targetX[slot],
            toY: ctx.enemies.targetY[slot],
            flightSeconds: c.flightSeconds,
            damage: c.attackDamage,
            radius: c.areaRadius,
            lingerSeconds: c.lingerSeconds,
            lingerDamage: c.lingerDamage,
          );
        }
        _recoverInto(ctx, slot, c);

      case AiState.recover:
        if (_windUpDone(ctx, slot)) {
          ctx.enemies.state[slot] = AiState.reposition.index;
        }

      default:
        if (!_hold(ctx, slot, def)) return;
        ctx.enemies.targetX[slot] = ctx.playerX;
        ctx.enemies.targetY[slot] = ctx.playerY;
        ctx.enemies.state[slot] = AiState.windUp.index;
        ctx.enemies.stateTimer[slot] = c.windUpSeconds;
        EnemyAttack.beginCircle(
          ctx,
          slot,
          ctx.entities.posX[slot],
          ctx.entities.posY[slot],
          ctx.entities.radius[slot] * 1.6,
          c.windUpSeconds,
        );
    }
  }

  // ── Nettle ────────────────────────────────────────────────────────────────

  /// A three-bolt 30-degree spread. Strafing perpendicular beats it, and at
  /// close range the spread has a wide safe gap — so walking *toward* a Nettle
  /// is safer than backing away from it, which is a genuinely useful thing for
  /// a player to learn in chapter 2.
  static void _nettle(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    switch (ctx.enemies.stateOf(slot)) {
      case AiState.windUp:
        if (!_windUpDone(ctx, slot)) return;
        EnemyAttack.endTelegraph(ctx, slot);
        _fireSpread(ctx, slot, c);
        _recoverInto(ctx, slot, c);

      case AiState.recover:
        if (_windUpDone(ctx, slot)) {
          ctx.enemies.state[slot] = AiState.reposition.index;
        }

      default:
        if (!_hold(ctx, slot, def)) return;
        ctx.enemies.state[slot] = AiState.windUp.index;
        ctx.enemies.stateTimer[slot] = c.windUpSeconds;
        EnemyAttack.beginCone(
          ctx,
          slot,
          ctx.entities.posX[slot],
          ctx.entities.posY[slot],
          ctx.entities.facing[slot],
          Steering.toRadians(c.spreadDegrees / 2),
          c.attackRange,
          c.windUpSeconds,
        );
    }
  }

  static void _fireSpread(AiContext ctx, int slot, EnemyCombat c) {
    final int count = c.projectileCount;
    if (count <= 0 || c.projectileSpeed <= 0) return;

    final double spread = Steering.toRadians(c.spreadDegrees);
    final double step = count > 1 ? spread / (count - 1) : 0;
    final double start = ctx.entities.facing[slot] - spread / 2;
    final double lifetime = c.attackRange / c.projectileSpeed;

    for (int i = 0; i < count; i++) {
      EnemyAttack.fireBolt(
        ctx,
        slot,
        angle: count > 1 ? start + step * i : ctx.entities.facing[slot],
        speed: c.projectileSpeed,
        damage: c.attackDamage,
        radius: EnemyTuning.boltRadius,
        lifetime: lifetime,
      );
    }
  }

  // ── Longeye ───────────────────────────────────────────────────────────────

  /// The heaviest-hitting non-boss enemy in the game, and the one that most
  /// rewards reading.
  ///
  /// The beam tracks for 0.8 s and **commits for the final 0.4 s**. That single
  /// number is the entire enemy: without the commit window the attack is
  /// undodgeable, and with a longer one it is trivial. Moving laterally in the
  /// last fraction of a second, or breaking line of sight behind cover, beats
  /// 22 % of the player's health.
  static void _longeye(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    switch (ctx.enemies.stateOf(slot)) {
      case AiState.windUp:
        Steering.halt(ctx, slot);
        ctx.enemies.stateTimer[slot] -= ctx.dt;

        // Track until the cutoff, then stop — the beam freezing in place is
        // the player's cue that the shot has committed.
        if (ctx.enemies.stateTimer[slot] > c.trackingCutoffSeconds &&
            ctx.hasPlayer) {
          ctx.enemies.targetX[slot] = ctx.playerX;
          ctx.enemies.targetY[slot] = ctx.playerY;
          Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);
          EnemyAttack.retarget(ctx, slot, ctx.playerX, ctx.playerY);
        }

        if (ctx.enemies.stateTimer[slot] > 0) return;

        EnemyAttack.endTelegraph(ctx, slot);
        _fireLance(ctx, slot, c);
        _recoverInto(ctx, slot, c);

      case AiState.recover:
        if (_windUpDone(ctx, slot)) {
          ctx.enemies.state[slot] = AiState.reposition.index;
        }

      default:
        if (!_hold(ctx, slot, def)) return;
        ctx.enemies.targetX[slot] = ctx.playerX;
        ctx.enemies.targetY[slot] = ctx.playerY;
        ctx.enemies.state[slot] = AiState.windUp.index;
        ctx.enemies.stateTimer[slot] = c.windUpSeconds;
        EnemyAttack.beginLine(
          ctx,
          slot,
          ctx.entities.posX[slot],
          ctx.entities.posY[slot],
          ctx.playerX,
          ctx.playerY,
          c.areaRadius,
          c.windUpSeconds,
        );
    }
  }

  static void _fireLance(AiContext ctx, int slot, EnemyCombat c) {
    final double x = ctx.entities.posX[slot];
    final double y = ctx.entities.posY[slot];

    // Extend the committed direction to full range: the lance is hitscan, so
    // standing beyond the aim point must not be a free dodge.
    final double dx = ctx.enemies.targetX[slot] - x;
    final double dy = ctx.enemies.targetY[slot] - y;
    final double len = math.sqrt(dx * dx + dy * dy);
    final double toX = len > 1e-9 ? x + dx / len * c.attackRange : x;
    final double toY = len > 1e-9 ? y + dy / len * c.attackRange : y;

    ctx.telegraphs.add(
      shape: TelegraphShape.line,
      severity: TelegraphSeverity.lethal,
      owner: slot,
      x: x,
      y: y,
      toX: toX,
      toY: toY,
      radius: c.areaRadius,
      startedAt: ctx.now,
      resolvesAt: ctx.now,
    );

    if (EnemyAttack.playerOnLine(ctx, x, y, toX, toY, c.areaRadius)) {
      EnemyAttack.damagePlayer(ctx, c.attackDamage, source: slot);
    }
  }

  // ── Mortarite ─────────────────────────────────────────────────────────────

  /// Three shells in a triangle around the player's **predicted** position.
  ///
  /// Prediction always leads, so a direction change beats it. That is the point:
  /// the Mortarite punishes rooting hard and rewards nothing but movement, which
  /// makes it the natural counterweight to a room full of Carapace enemies that
  /// want the player standing still at Tier III.
  static void _mortarite(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    switch (ctx.enemies.stateOf(slot)) {
      case AiState.windUp:
        if (!_windUpDone(ctx, slot)) return;
        EnemyAttack.endTelegraph(ctx, slot);
        _fireBarrage(ctx, slot, c);
        _recoverInto(ctx, slot, c);

      case AiState.recover:
        if (_windUpDone(ctx, slot)) {
          ctx.enemies.state[slot] = AiState.reposition.index;
        }

      default:
        if (!_hold(ctx, slot, def)) return;
        ctx.enemies.state[slot] = AiState.windUp.index;
        ctx.enemies.stateTimer[slot] = c.windUpSeconds;
        EnemyAttack.beginCircle(
          ctx,
          slot,
          ctx.entities.posX[slot],
          ctx.entities.posY[slot],
          ctx.entities.radius[slot] * 1.6,
          c.windUpSeconds,
        );
    }
  }

  static void _fireBarrage(AiContext ctx, int slot, EnemyCombat c) {
    if (!ctx.hasPlayer) return;

    final double centreX =
        ctx.playerX + ctx.playerVelX * EnemyTuning.mortaritePredictionSeconds;
    final double centreY =
        ctx.playerY + ctx.playerVelY * EnemyTuning.mortaritePredictionSeconds;

    final int count = c.projectileCount;
    for (int i = 0; i < count; i++) {
      final double angle = 2 * math.pi * i / count;
      EnemyAttack.fireShell(
        ctx,
        slot,
        toX: centreX +
            math.cos(angle) * EnemyTuning.mortariteTriangleRadius,
        toY: centreY +
            math.sin(angle) * EnemyTuning.mortariteTriangleRadius,
        flightSeconds: c.flightSeconds,
        damage: c.attackDamage,
        radius: c.areaRadius,
      );
    }
  }

  // ── Screecher ─────────────────────────────────────────────────────────────

  /// The only enemy that attacks the player's *mechanic* rather than their HP.
  ///
  /// Draw-lock suppresses tier gain for 2 s; Momentum still works. Screechers
  /// are the reason Momentum builds exist as a genuine alternative rather than
  /// a fallback — an enemy that turned off half the game with no answer would
  /// simply be a tax.
  ///
  /// Its cone is narrow and it turns at 60 degrees per second, so flanking it
  /// is always available.
  static void _screecher(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    switch (ctx.enemies.stateOf(slot)) {
      case AiState.windUp:
        Steering.halt(ctx, slot);
        if (ctx.hasPlayer) {
          Steering.faceToward(
            ctx,
            slot,
            ctx.playerX,
            ctx.playerY,
            c.turnRateDegrees,
          );
        }
        ctx.enemies.stateTimer[slot] -= ctx.dt;
        if (ctx.enemies.stateTimer[slot] > 0) return;

        EnemyAttack.endTelegraph(ctx, slot);
        _scream(ctx, slot, c);
        _recoverInto(ctx, slot, c);

      case AiState.recover:
        if (_windUpDone(ctx, slot)) {
          ctx.enemies.state[slot] = AiState.reposition.index;
        }

      default:
        if (!_hold(ctx, slot, def)) return;
        ctx.enemies.state[slot] = AiState.windUp.index;
        ctx.enemies.stateTimer[slot] = c.windUpSeconds;
        EnemyAttack.beginCone(
          ctx,
          slot,
          ctx.entities.posX[slot],
          ctx.entities.posY[slot],
          ctx.entities.facing[slot],
          Steering.toRadians(c.spreadDegrees / 2),
          c.areaRadius,
          c.windUpSeconds,
        );
    }
  }

  static void _scream(AiContext ctx, int slot, EnemyCombat c) {
    final double halfAngle = Steering.toRadians(c.spreadDegrees / 2);

    ctx.telegraphs.add(
      shape: TelegraphShape.cone,
      severity: TelegraphSeverity.lethal,
      owner: slot,
      x: ctx.entities.posX[slot],
      y: ctx.entities.posY[slot],
      radius: c.areaRadius,
      angle: ctx.entities.facing[slot],
      halfAngle: halfAngle,
      startedAt: ctx.now,
      resolvesAt: ctx.now,
    );

    if (!EnemyAttack.playerInCone(
      ctx,
      ctx.entities.posX[slot],
      ctx.entities.posY[slot],
      ctx.entities.facing[slot],
      halfAngle,
      c.areaRadius,
    )) {
      return;
    }

    EnemyAttack.damagePlayer(ctx, c.attackDamage, source: slot);
    ctx.playerDraw?.applyDrawLock(c.drawLockSeconds);
  }
}
