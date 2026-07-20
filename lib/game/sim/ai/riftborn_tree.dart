import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';

/// RIFTBORN — the elites.
///
/// One per Elite room from chapter 3, always under a crimson arena border and a
/// distinct musical stinger (docs/05 §5.6). Each is a mechanic rather than a
/// stat block, and each one is a rehearsal for something a boss does later.
abstract final class RiftbornTree {
  static void update(AiContext ctx, int slot, EnemyDefinition def) {
    switch (def.archetype) {
      case EnemyArchetype.riftMaw:
        _riftMaw(ctx, slot, def);
      case EnemyArchetype.echo:
        _echo(ctx, slot, def);
      case EnemyArchetype.gravebound:
        _gravebound(ctx, slot, def);
      case EnemyArchetype.nullborn:
        _nullborn(ctx, slot, def);
      default:
        _nullborn(ctx, slot, def);
    }
  }

  /// Stationary. Tears open and spills Swarmlings on a fixed cadence, capped.
  ///
  /// Teaches "kill the source" — a lesson every boss in docs/06 reuses. The cap
  /// is what makes ignoring the adds correct: without it, the intended answer
  /// stops working and the enemy teaches the opposite lesson.
  static void _riftMaw(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;
    Steering.halt(ctx, slot);

    if (ctx.hasPlayer) {
      Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);
    }

    if (ctx.enemies.stateOf(slot) == AiState.windUp) {
      ctx.enemies.stateTimer[slot] -= ctx.dt;
      if (ctx.enemies.stateTimer[slot] > 0) return;
      EnemyAttack.endTelegraph(ctx, slot);
      _summon(ctx, slot, c);
      ctx.enemies.attackCooldown[slot] = c.attackCooldown;
      ctx.enemies.state[slot] = AiState.idle.index;
      return;
    }

    ctx.enemies.state[slot] = AiState.idle.index;

    if (ctx.enemies.attackCooldown[slot] > 0) return;
    if (ctx.enemies.liveAdds[slot] >= c.spawnCap) return;
    if (EnemySpawner.atEnemyCap(ctx)) return;

    ctx.enemies.state[slot] = AiState.windUp.index;
    ctx.enemies.stateTimer[slot] = c.windUpSeconds;

    // The tear pulses before each spawn. Even an add is announced.
    EnemyAttack.beginCircle(
      ctx,
      slot,
      ctx.entities.posX[slot],
      ctx.entities.posY[slot],
      EnemyTuning.riftMawSpawnRadius,
      c.windUpSeconds,
    );
  }

  static void _summon(AiContext ctx, int slot, EnemyCombat c) {
    final String? id = c.spawnsId;
    if (id == null) return;
    final int contentIndex = ctx.content.enemyIndexById[id] ?? -1;
    if (contentIndex < 0) return;

    for (int i = 0; i < c.spawnCount; i++) {
      if (ctx.enemies.liveAdds[slot] >= c.spawnCap) return;
      if (EnemySpawner.atEnemyCap(ctx)) return;

      EnemySpawner.ringPoint(
        ctx,
        slot,
        i,
        c.spawnCount,
        EnemyTuning.riftMawSpawnRadius,
      );
      EnemySpawner.spawn(
        ctx,
        contentIndex: contentIndex,
        x: EnemySpawner.pointX,
        y: EnemySpawner.pointY,
        spawnerSlot: slot,
      );
    }
  }

  /// Mirrors the player's movement, inverted about the arena centre, and fires
  /// when the player fires.
  ///
  /// **The mechanically richest common enemy in the game.** Standing still
  /// stops it dead; better, the mirror can be exploited to walk it through your
  /// own Windlines. It is the only enemy driven by the player's *input* rather
  /// than by their position, which is why it reads as unsettling rather than
  /// merely difficult.
  static void _echo(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }

    ctx.enemies.state[slot] = AiState.seek.index;

    final double mirrorX = ctx.arena.width - ctx.playerX;
    final double mirrorY = ctx.arena.height - ctx.playerY;

    final double dx = mirrorX - ctx.entities.posX[slot];
    final double dy = mirrorY - ctx.entities.posY[slot];

    // Deliberately lagging: the gain is below 1.0 so the Echo trails its mirror
    // point visibly. A perfect mirror would be unexploitable, and exploiting it
    // is the whole enemy.
    if (dx * dx + dy * dy <= 0.01) {
      Steering.halt(ctx, slot);
    } else {
      Steering.moveToward(
        ctx,
        slot,
        mirrorX,
        mirrorY,
        Steering.speedOf(ctx, slot, def) * EnemyTuning.echoMirrorGain,
        separate: false,
      );
    }

    Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);

    if (!ctx.playerFired) return;
    if (ctx.enemies.attackCooldown[slot] > 0) return;
    if (ctx.distanceSquaredToPlayer(slot) > c.attackRange * c.attackRange) {
      return;
    }

    ctx.enemies.attackCooldown[slot] = c.attackCooldown;
    EnemyAttack.fireBolt(
      ctx,
      slot,
      angle: math.atan2(
        ctx.playerY - ctx.entities.posY[slot],
        ctx.playerX - ctx.entities.posX[slot],
      ),
      speed: c.projectileSpeed,
      damage: c.attackDamage,
      radius: EnemyTuning.boltRadius,
      lifetime: c.attackRange / c.projectileSpeed,
    );
  }

  /// Dies, collapses, and gets back up once — unless the corpse is consumed.
  ///
  /// The revive is entered from [AiSystem]'s death pass; this branch only runs
  /// the countdown. Ember burn applied at death prevents it entirely, which is
  /// a taught interaction surfaced by the Elemental Codex research rather than
  /// left for players to discover by accident.
  static void _gravebound(AiContext ctx, int slot, EnemyDefinition def) {
    if (ctx.enemies.stateOf(slot) == AiState.downed) {
      Steering.halt(ctx, slot);
      ctx.enemies.stateTimer[slot] -= ctx.dt;
      if (ctx.enemies.stateTimer[slot] > 0) return;
      _rise(ctx, slot, def);
      return;
    }

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
  }

  static void _rise(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;
    ctx.entities.health[slot] =
        ctx.entities.maxHealth[slot] * c.reviveHealthFraction;
    ctx.entities.radius[slot] = def.radius;
    ctx.enemies.untargetable[slot] = 0;
    ctx.enemies.speedScale[slot] =
        (1.0 + ctx.enemies.variantOf(slot).speedBonus) *
            (1.0 + c.reviveSpeedBonus);
    ctx.enemies.state[slot] = AiState.seek.index;
  }

  /// Adapts to whatever last hurt it.
  ///
  /// The adaptation itself is applied in the damage path, not here — this is a
  /// plain seek. Element rotation counters it; Confluence merging, which
  /// applies two elements in one hit, beats it outright. That makes the Null
  /// the payoff enemy for the game's deepest mechanic, arriving in chapter 8
  /// exactly when a player has one.
  static void _nullborn(AiContext ctx, int slot, EnemyDefinition def) {
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
  }
}
