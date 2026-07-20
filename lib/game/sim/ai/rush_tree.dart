import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// RUSH — the movement tax.
///
/// Every enemy here is a timer on how long you may stand still. They exist to
/// force the player out of Tier III, which is what stops the Draw from
/// collapsing into "stand still and win" (docs/05 §5.3).
///
/// All of them share one shape: **approach, telegraph, commit, be vulnerable.**
/// The recovery window is not a concession, it is the payoff — baiting a charge
/// and punishing the whiff is the skill this family teaches.
abstract final class RushTree {
  static void update(AiContext ctx, int slot, EnemyDefinition def) {
    switch (def.archetype) {
      case EnemyArchetype.lancer:
        _lancer(ctx, slot, def);
      case EnemyArchetype.stalker:
        _stalker(ctx, slot, def);
      case EnemyArchetype.bounder:
        _bounder(ctx, slot, def);
      case EnemyArchetype.ripper:
        _ripper(ctx, slot, def);
      case EnemyArchetype.thresher:
        _thresher(ctx, slot, def);
      default:
        _lancer(ctx, slot, def);
    }
  }

  // ── Lancer ────────────────────────────────────────────────────────────────

  /// Approach to 5 u, 0.7 s wind-up drawing a bright amber line along the
  /// charge path, dash 6 u, 1.1 s fully-vulnerable recovery.
  ///
  /// **The amber charge line is the game's canonical "this will hurt"
  /// language.** It is introduced here, in chapter 1, and every boss in docs/06
  /// reuses it unchanged. That is why the Lancer ships in the first room of the
  /// game and never leaves the roster.
  static void _lancer(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    switch (ctx.enemies.stateOf(slot)) {
      case AiState.windUp:
        // Freeze during the wind-up cancels the charge outright — handled
        // centrally in [AiSystem], so a frozen Lancer never gets here.
        Steering.halt(ctx, slot);
        ctx.enemies.stateTimer[slot] -= ctx.dt;
        if (ctx.enemies.stateTimer[slot] <= 0) _launchCharge(ctx, slot, c);

      case AiState.attack:
        _advanceCharge(ctx, slot, c);

      case AiState.recover:
        Steering.halt(ctx, slot);
        ctx.enemies.stateTimer[slot] -= ctx.dt;
        if (ctx.enemies.stateTimer[slot] <= 0) {
          ctx.enemies.state[slot] = AiState.seek.index;
          ctx.enemies.attackCooldown[slot] = c.attackCooldown;
        }

      default:
        if (!ctx.hasPlayer) {
          Steering.halt(ctx, slot);
          return;
        }
        ctx.enemies.state[slot] = AiState.seek.index;
        Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);
        Steering.moveToward(
          ctx,
          slot,
          ctx.playerX,
          ctx.playerY,
          Steering.speedOf(ctx, slot, def),
        );

        final double range = c.attackRange;
        if (ctx.enemies.attackCooldown[slot] <= 0 &&
            ctx.distanceSquaredToPlayer(slot) <= range * range) {
          _beginCharge(ctx, slot, c);
        }
    }
  }

  /// Locks the charge path and draws it. The destination is fixed **now** —
  /// a charge that re-solved mid-dash would be a homing attack, and homing
  /// attacks cannot be dodged, only outrun.
  static void _beginCharge(AiContext ctx, int slot, EnemyCombat c) {
    final double x = ctx.entities.posX[slot];
    final double y = ctx.entities.posY[slot];
    final double angle = math.atan2(ctx.playerY - y, ctx.playerX - x);

    ctx.entities.facing[slot] = angle;
    ctx.enemies.targetX[slot] = x + math.cos(angle) * c.chargeDistance;
    ctx.enemies.targetY[slot] = y + math.sin(angle) * c.chargeDistance;
    ctx.enemies.state[slot] = AiState.windUp.index;
    ctx.enemies.stateTimer[slot] = c.windUpSeconds;
    ctx.enemies.comboStep[slot] = 0;

    EnemyAttack.beginLine(
      ctx,
      slot,
      x,
      y,
      ctx.enemies.targetX[slot],
      ctx.enemies.targetY[slot],
      ctx.entities.radius[slot],
      c.windUpSeconds,
    );
    Steering.halt(ctx, slot);
  }

  static void _launchCharge(AiContext ctx, int slot, EnemyCombat c) {
    EnemyAttack.endTelegraph(ctx, slot);
    ctx.enemies.state[slot] = AiState.attack.index;
    // Time-boxed as well as distance-boxed: a charge into a wall must still
    // end, or the enemy grinds against it forever.
    ctx.enemies.stateTimer[slot] =
        c.chargeSpeed > 0 ? c.chargeDistance / c.chargeSpeed : 0;
  }

  static void _advanceCharge(AiContext ctx, int slot, EnemyCombat c) {
    final double fromX = ctx.entities.posX[slot];
    final double fromY = ctx.entities.posY[slot];

    Steering.moveToward(
      ctx,
      slot,
      ctx.enemies.targetX[slot],
      ctx.enemies.targetY[slot],
      c.chargeSpeed,
      separate: false,
    );

    // Swept, not sampled: at 8 u/s a charge covers 0.13 u per tick, and a point
    // test would let it pass through a player standing exactly on the line.
    final double toX = fromX + ctx.entities.velX[slot] * ctx.dt;
    final double toY = fromY + ctx.entities.velY[slot] * ctx.dt;

    if (ctx.enemies.comboStep[slot] == 0 &&
        EnemyAttack.playerOnLine(
          ctx,
          fromX,
          fromY,
          toX,
          toY,
          ctx.entities.radius[slot],
        )) {
      ctx.enemies.comboStep[slot] = 1;
      EnemyAttack.damagePlayer(ctx, c.attackDamage, source: slot);
    }

    ctx.enemies.stateTimer[slot] -= ctx.dt;

    final double dx = ctx.enemies.targetX[slot] - toX;
    final double dy = ctx.enemies.targetY[slot] - toY;
    final bool arrived = dx * dx + dy * dy <= 0.04;

    if (arrived || ctx.enemies.stateTimer[slot] <= 0) {
      ctx.enemies.state[slot] = AiState.recover.index;
      ctx.enemies.stateTimer[slot] = c.recoverySeconds;
      Steering.halt(ctx, slot);
    }
  }

  // ── Stalker ───────────────────────────────────────────────────────────────

  /// Orbits at 4 u, always sliding toward the player's rear 120 degrees, and
  /// only lunges from behind.
  ///
  /// Turning to face it is the whole counter-play. That is a deliberately
  /// *cheap* answer — it costs the player nothing but attention — because the
  /// Stalker's job is to teach camera awareness, not to kill.
  static void _stalker(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    switch (ctx.enemies.stateOf(slot)) {
      case AiState.windUp:
        Steering.halt(ctx, slot);
        ctx.enemies.stateTimer[slot] -= ctx.dt;
        if (ctx.enemies.stateTimer[slot] <= 0) _launchCharge(ctx, slot, c);

      case AiState.attack:
        _advanceCharge(ctx, slot, c);

      case AiState.recover:
        Steering.halt(ctx, slot);
        ctx.enemies.stateTimer[slot] -= ctx.dt;
        if (ctx.enemies.stateTimer[slot] <= 0) {
          ctx.enemies.state[slot] = AiState.reposition.index;
          ctx.enemies.attackCooldown[slot] = c.attackCooldown;
        }

      default:
        if (!ctx.hasPlayer) {
          Steering.halt(ctx, slot);
          return;
        }
        ctx.enemies.state[slot] = AiState.reposition.index;

        final double behind = ctx.entities.facing[ctx.player] + math.pi;
        Steering.orbit(
          ctx,
          slot,
          ctx.playerX,
          ctx.playerY,
          c.keepDistance,
          Steering.speedOf(ctx, slot, def),
          behind,
        );
        Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);

        if (ctx.enemies.attackCooldown[slot] <= 0 &&
            _inPlayerRear(ctx, slot) &&
            ctx.distanceSquaredToPlayer(slot) <=
                c.attackRange * c.attackRange) {
          _beginCharge(ctx, slot, c);
        }
    }
  }

  static bool _inPlayerRear(AiContext ctx, int slot) {
    final double toEnemy = math.atan2(
      ctx.entities.posY[slot] - ctx.playerY,
      ctx.entities.posX[slot] - ctx.playerX,
    );
    final double delta = Steering.shortestAngleDelta(
      ctx.entities.facing[ctx.player],
      toEnemy,
    ).abs();
    return delta >=
        math.pi - Steering.toRadians(EnemyTuning.stalkerRearArcDegrees / 2);
  }

  // ── Bounder ───────────────────────────────────────────────────────────────

  /// Leaps in a parabolic arc. **Airborne means untargetable and immune to the
  /// Windline slow.**
  ///
  /// This is the only enemy in the game auto-aim cannot solve, which is exactly
  /// why it exists: it is the one moment a player who has leaned entirely on
  /// assisted targeting has to lead a shot themselves.
  static void _bounder(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    switch (ctx.enemies.stateOf(slot)) {
      case AiState.windUp:
        Steering.halt(ctx, slot);
        ctx.enemies.stateTimer[slot] -= ctx.dt;
        if (ctx.enemies.stateTimer[slot] <= 0) {
          ctx.enemies.state[slot] = AiState.airborne.index;
          ctx.enemies.stateTimer[slot] = c.flightSeconds;
          ctx.enemies.untargetable[slot] = 1;
        }

      case AiState.airborne:
        _fly(ctx, slot, c);

      case AiState.recover:
        Steering.halt(ctx, slot);
        ctx.enemies.stateTimer[slot] -= ctx.dt;
        if (ctx.enemies.stateTimer[slot] <= 0) {
          ctx.enemies.state[slot] = AiState.seek.index;
        }

      default:
        if (!ctx.hasPlayer) {
          Steering.halt(ctx, slot);
          return;
        }
        ctx.enemies.state[slot] = AiState.seek.index;
        Steering.moveToward(
          ctx,
          slot,
          ctx.playerX,
          ctx.playerY,
          Steering.speedOf(ctx, slot, def),
        );

        if (ctx.enemies.attackCooldown[slot] <= 0 &&
            ctx.distanceSquaredToPlayer(slot) <=
                c.attackRange * c.attackRange) {
          _beginLeap(ctx, slot, c);
        }
    }
  }

  static void _beginLeap(AiContext ctx, int slot, EnemyCombat c) {
    ctx.enemies.targetX[slot] = ctx.playerX;
    ctx.enemies.targetY[slot] = ctx.playerY;
    ctx.enemies.state[slot] = AiState.windUp.index;
    ctx.enemies.stateTimer[slot] = c.windUpSeconds;

    // The ring is drawn now and resolves at impact, so it is on the ground for
    // the whole crouch *and* the whole arc. The shadow beneath a Bounder is the
    // real telegraph, and it has to be there before the leap starts.
    EnemyAttack.beginCircle(
      ctx,
      slot,
      ctx.enemies.targetX[slot],
      ctx.enemies.targetY[slot],
      c.areaRadius,
      c.windUpSeconds + c.flightSeconds,
    );
    Steering.halt(ctx, slot);
  }

  static void _fly(AiContext ctx, int slot, EnemyCombat c) {
    final double remaining = ctx.enemies.stateTimer[slot];
    if (remaining > 0) {
      // Constant-velocity solve for the remaining time, so the Bounder lands on
      // its ring to the tick even if a wall shortened an earlier step.
      ctx.entities.velX[slot] =
          (ctx.enemies.targetX[slot] - ctx.entities.posX[slot]) / remaining;
      ctx.entities.velY[slot] =
          (ctx.enemies.targetY[slot] - ctx.entities.posY[slot]) / remaining;
    }

    ctx.enemies.stateTimer[slot] -= ctx.dt;
    if (ctx.enemies.stateTimer[slot] > 0) return;

    ctx.enemies.untargetable[slot] = 0;
    EnemyAttack.endTelegraph(ctx, slot);
    Steering.halt(ctx, slot);

    EnemyAttack.blast(
      ctx,
      source: slot,
      x: ctx.enemies.targetX[slot],
      y: ctx.enemies.targetY[slot],
      radius: c.areaRadius,
      damage: c.attackDamage,
    );

    ctx.enemies.state[slot] = AiState.recover.index;
    ctx.enemies.stateTimer[slot] = c.recoverySeconds;
    ctx.enemies.attackCooldown[slot] = c.attackCooldown;
  }

  // ── Ripper ────────────────────────────────────────────────────────────────

  /// A three-hit combo whose third swing is the game's parry.
  ///
  /// Landing more than [EnemyTuning.ripperStaggerFraction] of the Ripper's max
  /// HP during the final wind-up staggers it. **There is no button for this.**
  /// The skill expression is entirely in choosing to commit damage into a
  /// specific 0.8 s window, which is a decision the Draw mechanic already
  /// taught the player how to make.
  static void _ripper(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;
    final int step = ctx.enemies.comboStep[slot];
    final bool finisher = step >= EnemyTuning.ripperComboLength - 1;

    switch (ctx.enemies.stateOf(slot)) {
      case AiState.windUp:
        Steering.halt(ctx, slot);
        if (ctx.hasPlayer) {
          Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);
        }

        if (finisher &&
            ctx.enemies.damageDuringWindUp[slot] >
                ctx.entities.maxHealth[slot] *
                    EnemyTuning.ripperStaggerFraction) {
          EnemyAttack.endTelegraph(ctx, slot);
          ctx.enemies.state[slot] = AiState.staggered.index;
          ctx.enemies.stateTimer[slot] = EnemyTuning.ripperStaggerSeconds;
          ctx.enemies.comboStep[slot] = 0;
          ctx.enemies.attackCooldown[slot] = c.attackCooldown;
          return;
        }

        ctx.enemies.stateTimer[slot] -= ctx.dt;
        if (ctx.enemies.stateTimer[slot] > 0) return;

        EnemyAttack.endTelegraph(ctx, slot);
        if (EnemyAttack.playerInCone(
          ctx,
          ctx.entities.posX[slot],
          ctx.entities.posY[slot],
          ctx.entities.facing[slot],
          Steering.toRadians(EnemyTuning.ripperSwingArcDegrees / 2),
          c.attackRange,
        )) {
          EnemyAttack.damagePlayer(
            ctx,
            finisher
                ? c.attackDamage
                : c.attackDamage * EnemyTuning.ripperOpenerFraction,
            source: slot,
          );
        }

        if (finisher) {
          ctx.enemies.comboStep[slot] = 0;
          ctx.enemies.state[slot] = AiState.recover.index;
          ctx.enemies.stateTimer[slot] = c.recoverySeconds;
          ctx.enemies.attackCooldown[slot] = c.attackCooldown;
        } else {
          ctx.enemies.comboStep[slot] = step + 1;
          _beginSwing(ctx, slot, c);
        }

      case AiState.staggered:
      case AiState.recover:
        Steering.halt(ctx, slot);
        ctx.enemies.stateTimer[slot] -= ctx.dt;
        if (ctx.enemies.stateTimer[slot] <= 0) {
          ctx.enemies.state[slot] = AiState.seek.index;
        }

      default:
        if (!ctx.hasPlayer) {
          Steering.halt(ctx, slot);
          return;
        }
        ctx.enemies.state[slot] = AiState.seek.index;
        ctx.enemies.comboStep[slot] = 0;
        Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);
        Steering.moveToward(
          ctx,
          slot,
          ctx.playerX,
          ctx.playerY,
          Steering.speedOf(ctx, slot, def),
        );

        if (ctx.enemies.attackCooldown[slot] <= 0 &&
            ctx.distanceSquaredToPlayer(slot) <=
                c.attackRange * c.attackRange) {
          _beginSwing(ctx, slot, c);
        }
    }
  }

  static void _beginSwing(AiContext ctx, int slot, EnemyCombat c) {
    final bool finisher =
        ctx.enemies.comboStep[slot] >= EnemyTuning.ripperComboLength - 1;
    final double lead = finisher ? c.heavyWindUpSeconds : c.windUpSeconds;

    ctx.enemies.state[slot] = AiState.windUp.index;
    ctx.enemies.stateTimer[slot] = lead;
    ctx.enemies.damageDuringWindUp[slot] = 0;

    EnemyAttack.beginCone(
      ctx,
      slot,
      ctx.entities.posX[slot],
      ctx.entities.posY[slot],
      ctx.entities.facing[slot],
      Steering.toRadians(EnemyTuning.ripperSwingArcDegrees / 2),
      c.attackRange,
      lead,
      // The overhead third swing is unmistakable, and it says so in colour: the
      // openers warn, the finisher promises.
      severity: finisher ? TelegraphSeverity.lethal : TelegraphSeverity.warning,
    );
    Steering.halt(ctx, slot);
  }

  // ── Thresher ──────────────────────────────────────────────────────────────

  /// A permanent lethal aura on a moving body. No wind-up, no gap, no ranged
  /// option and no gap-closer.
  ///
  /// The counter-play is range — pure and simple. The Thresher is the one enemy
  /// in the roster with no telegraph, and it earns that by being *always*
  /// telegraphed: the hard-edged crimson circle on the ground is its exact
  /// aura, permanently visible, and lethal zones are always crimson.
  static void _thresher(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    if (!EnemyAttack.hasTelegraph(ctx, slot)) {
      EnemyAttack.beginCircle(
        ctx,
        slot,
        ctx.entities.posX[slot],
        ctx.entities.posY[slot],
        c.areaRadius,
        c.attackCooldown,
        severity: TelegraphSeverity.lethal,
      );
    } else {
      EnemyAttack.followTelegraph(
        ctx,
        slot,
        ctx.entities.posX[slot],
        ctx.entities.posY[slot],
      );
      EnemyAttack.extendTelegraph(ctx, slot, ctx.now + c.attackCooldown);
    }

    if (ctx.enemies.attackCooldown[slot] <= 0 &&
        EnemyAttack.playerInCircle(
          ctx,
          ctx.entities.posX[slot],
          ctx.entities.posY[slot],
          c.areaRadius,
        )) {
      EnemyAttack.damagePlayer(ctx, c.attackDamage, source: slot);
      ctx.enemies.attackCooldown[slot] = c.attackCooldown;
    }

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }
    ctx.enemies.state[slot] = AiState.seek.index;
    Steering.moveToward(
      ctx,
      slot,
      ctx.playerX,
      ctx.playerY,
      Steering.speedOf(ctx, slot, def),
    );
  }
}
