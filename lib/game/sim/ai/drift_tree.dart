import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// DRIFT — the fodder.
///
/// Slow, dumb, numerous. Exist to be the canvas the player paints Windlines on
/// (docs/05 §5.1). A game like this needs constant harmless traffic so that the
/// *dangerous* things read as dangerous by contrast, which is why the family
/// with the least behaviour in it is also the one present in every chapter of
/// the game.
abstract final class DriftTree {
  static void update(AiContext ctx, int slot, EnemyDefinition def) {
    switch (def.archetype) {
      case EnemyArchetype.mote:
        _seek(ctx, slot, def);
      case EnemyArchetype.swarmling:
        _flock(ctx, slot, def);
      case EnemyArchetype.wisp:
        _weave(ctx, slot, def);
      case EnemyArchetype.cinderMote:
        _fuse(ctx, slot, def);
      default:
        // Unreachable: the family tree is chosen from the archetype's family,
        // and every Drift archetype has a branch above. A plain seek is the
        // safe fallback rather than a throw — a content bug must not be able to
        // kill a run in progress.
        _seek(ctx, slot, def);
    }
  }

  /// Direct seek. No avoidance, no prediction — the Mote punishes nothing and
  /// teaches that aiming and auto-fire exist.
  static void _seek(AiContext ctx, int slot, EnemyDefinition def) {
    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }
    ctx.enemies.state[slot] = AiState.seek.index;
    Steering.faceToward(
      ctx,
      slot,
      ctx.playerX,
      ctx.playerY,
      def.combat.turnRateDegrees,
    );
    Steering.moveToward(
      ctx,
      slot,
      ctx.playerX,
      ctx.playerY,
      Steering.speedOf(ctx, slot, def),
    );
  }

  /// Boids, from docs/05 §5.1: separation, alignment, cohesion at radius 1.2 u,
  /// on top of a seek.
  ///
  /// The flock must read as **one moving shape** — individually trivial,
  /// collectively lethal. That is a rendering requirement expressed as a
  /// movement rule: without alignment and cohesion the pack disperses into
  /// twelve unrelated dots and the enemy stops meaning anything.
  static void _flock(AiContext ctx, int slot, EnemyDefinition def) {
    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }
    ctx.enemies.state[slot] = AiState.seek.index;

    final double x = ctx.entities.posX[slot];
    final double y = ctx.entities.posY[slot];
    final double speed = Steering.speedOf(ctx, slot, def);

    double sepX = 0;
    double sepY = 0;
    double alignX = 0;
    double alignY = 0;
    double cohX = 0;
    double cohY = 0;
    int neighbours = 0;

    final int found =
        ctx.spatial.queryRadius(x, y, EnemyTuning.flockRadius);
    for (int i = 0; i < found && neighbours < EnemyTuning.flockMaxNeighbours;
        i++) {
      final int other = ctx.spatial.resultAt(i);
      if (other == slot) continue;
      if (ctx.entities.alive[other] == 0) continue;
      if (ctx.entities.kind[other] != EntityKind.enemy.index) continue;
      // Only flock with your own kind. A Swarmling aligning to a Bulwark would
      // simply stop.
      if (ctx.entities.contentIndex[other] != ctx.entities.contentIndex[slot]) {
        continue;
      }

      final double dx = x - ctx.entities.posX[other];
      final double dy = y - ctx.entities.posY[other];
      final double distSq = dx * dx + dy * dy;
      if (distSq > EnemyTuning.flockRadius * EnemyTuning.flockRadius) continue;

      neighbours++;
      if (distSq > 1e-9) {
        final double dist = math.sqrt(distSq);
        sepX += dx / dist * (1.0 - dist / EnemyTuning.flockRadius);
        sepY += dy / dist * (1.0 - dist / EnemyTuning.flockRadius);
      }
      alignX += ctx.entities.velX[other];
      alignY += ctx.entities.velY[other];
      cohX += ctx.entities.posX[other] - x;
      cohY += ctx.entities.posY[other] - y;
    }

    // Routed around any wall in the way, exactly as a seeking enemy is. A
    // flock that ignored geometry would wedge itself behind a pillar and stall
    // the room, which is the one failure a room can never recover from.
    Steering.seekDirection(ctx, slot, ctx.playerX, ctx.playerY);
    double dirX = Steering.dirX;
    double dirY = Steering.dirY;

    if (neighbours > 0) {
      final double inv = 1.0 / neighbours;
      dirX += sepX * EnemyTuning.flockSeparationWeight +
          alignX * inv * EnemyTuning.flockAlignmentWeight +
          cohX * inv * EnemyTuning.flockCohesionWeight;
      dirY += sepY * EnemyTuning.flockSeparationWeight +
          alignY * inv * EnemyTuning.flockAlignmentWeight +
          cohY * inv * EnemyTuning.flockCohesionWeight;
    }

    final double mag = math.sqrt(dirX * dirX + dirY * dirY);
    if (mag <= 1e-9) {
      Steering.halt(ctx, slot);
      return;
    }
    ctx.entities.velX[slot] = dirX / mag * speed;
    ctx.entities.velY[slot] = dirY / mag * speed;
    ctx.entities.facing[slot] = math.atan2(dirY, dirX);
  }

  /// A genuine 2.4 Hz sine perpendicular to travel, **not** a random walk.
  ///
  /// The distinction is the whole enemy. A random walk is unreadable, so being
  /// hit by one teaches nothing; a sine can be predicted and led, so a Wisp
  /// rewards *Arrow Velocity* and *Wide Nock* rather than punishing the player
  /// for owning neither.
  static void _weave(AiContext ctx, int slot, EnemyDefinition def) {
    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }
    ctx.enemies.state[slot] = AiState.seek.index;

    ctx.enemies.phase[slot] += 2 * math.pi * EnemyTuning.wispSineHz * ctx.dt;

    Steering.moveToward(
      ctx,
      slot,
      ctx.playerX,
      ctx.playerY,
      Steering.speedOf(ctx, slot, def),
      separate: false,
    );

    final double vx = ctx.entities.velX[slot];
    final double vy = ctx.entities.velY[slot];
    final double speed = math.sqrt(vx * vx + vy * vy);
    if (speed <= 1e-9) return;

    final double swing =
        math.sin(ctx.enemies.phase[slot]) * EnemyTuning.wispSineAmplitude;

    // Perpendicular to travel, then renormalised, so the weave changes the
    // *path* without changing the speed. Scaling velocity instead would make a
    // Wisp visibly sprint through the middle of each zag.
    final double nx = vx / speed - vy / speed * swing;
    final double ny = vy / speed + vx / speed * swing;
    final double mag = math.sqrt(nx * nx + ny * ny);

    ctx.entities.velX[slot] = nx / mag * speed;
    ctx.entities.velY[slot] = ny / mag * speed;
    ctx.entities.facing[slot] = math.atan2(ny, nx);
  }

  /// As the Mote, but accelerates inside its trigger radius and detonates.
  ///
  /// Teaches two things at once: kill order matters, and Frost has a use beyond
  /// damage — freeze suppresses the fuse entirely, which is checked before the
  /// wind-up may start.
  static void _fuse(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    // Freeze cancels a lit fuse. Not "delays" — cancels, and the Cinder Mote
    // dies inert. [AiSystem] drops the wind-up centrally, so a frozen Mote
    // arrives here already back in seek.
    if (ctx.enemies.stateOf(slot) == AiState.windUp) {
      Steering.halt(ctx, slot);
      ctx.enemies.stateTimer[slot] -= ctx.dt;
      if (ctx.enemies.stateTimer[slot] <= 0) {
        _detonate(ctx, slot, def);
      }
      return;
    }

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }

    final double distSq = ctx.distanceSquaredToPlayer(slot);
    final double reach =
        ctx.entities.radius[slot] + ctx.playerRadius + EnemyTuning.contactSlack;

    if (distSq <= reach * reach) {
      ctx.enemies.state[slot] = AiState.windUp.index;
      ctx.enemies.stateTimer[slot] = c.windUpSeconds;
      EnemyAttack.beginCircle(
        ctx,
        slot,
        ctx.entities.posX[slot],
        ctx.entities.posY[slot],
        c.deathBlastRadius,
        c.windUpSeconds,
      );
      Steering.halt(ctx, slot);
      return;
    }

    ctx.enemies.state[slot] = AiState.seek.index;

    // The lunge: x1.6 inside the trigger radius, which is what turns "walk away
    // from it" into "kill it at range".
    final double speed = distSq <= c.attackRange * c.attackRange
        ? c.chargeSpeed * ctx.enemies.speedScale[slot]
        : Steering.speedOf(ctx, slot, def);

    Steering.moveToward(ctx, slot, ctx.playerX, ctx.playerY, speed);
  }

  /// Ends the fuse by killing the Mote.
  ///
  /// The blast itself is *not* fired here. It is left to the shared death
  /// handler in [AiSystem], which is the single place a death blast happens —
  /// so a Cinder Mote that fuses out and one that is shot produce exactly one
  /// explosion each, by construction rather than by care.
  static void _detonate(AiContext ctx, int slot, EnemyDefinition def) {
    EnemyAttack.endTelegraph(ctx, slot);
    ctx.entities.health[slot] = 0;
  }

  /// The death blast, reachable both from the fuse and from dying.
  ///
  /// Frost suppresses it in both cases: a frozen Cinder Mote killed at range
  /// leaves nothing behind, which is the payoff for having learned the
  /// interaction.
  static void detonateAt(
    AiContext ctx,
    int slot,
    EnemyDefinition def,
    double x,
    double y,
  ) {
    if (def.combat.deathBlastDamage <= 0) return;
    if (ctx.status.isFrozen(slot)) return;

    ctx.telegraphs.add(
      shape: TelegraphShape.circle,
      severity: TelegraphSeverity.lethal,
      owner: slot,
      x: x,
      y: y,
      radius: def.combat.deathBlastRadius,
      startedAt: ctx.now,
      resolvesAt: ctx.now,
    );

    EnemyAttack.blast(
      ctx,
      source: slot,
      x: x,
      y: y,
      radius: def.combat.deathBlastRadius,
      damage: def.combat.deathBlastDamage,
    );
  }
}
