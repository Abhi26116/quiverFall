import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// The single place an enemy comes into existence.
///
/// Wave spawning, Rift Maw summoning and the Twinned variant's split all route
/// through here. That matters more than it looks: an enemy is not one object
/// but a row in three stores plus a content reference, and a second construction
/// path is how you end up with a Husk whose plate never initialised or a
/// Gravebound that revives forever.
abstract final class EnemySpawner {
  /// Places an enemy and returns its slot, or -1 if the entity pool is full.
  static int spawn(
    AiContext ctx, {
    required int contentIndex,
    required double x,
    required double y,
    EnemyVariant variant = EnemyVariant.none,
    int spawnerSlot = -1,
    double healthScale = 1.0,
  }) {
    final EnemyDefinition def = ctx.content.enemies[contentIndex];

    final EntityId id = ctx.entities.spawn(EntityKind.enemy);
    if (id.isNone) return -1;
    final int slot = id.index;

    final double health = ctx.enemyHpBase *
        def.hpMultiplier *
        (1.0 + variant.healthBonus) *
        healthScale;

    ctx.entities.posX[slot] = x;
    ctx.entities.posY[slot] = y;
    ctx.entities.velX[slot] = 0;
    ctx.entities.velY[slot] = 0;
    ctx.entities.radius[slot] = def.radius;
    ctx.entities.health[slot] = health;
    ctx.entities.maxHealth[slot] = health;
    ctx.entities.contentIndex[slot] = contentIndex;
    ctx.entities.facing[slot] = ctx.hasPlayer
        ? math.atan2(ctx.playerY - y, ctx.playerX - x)
        : 0;

    ctx.enemies.reset(slot);
    // Denormalised so the hit loop can ask "is this an elite?" without a
    // content lookup — *Cull* (#20) asks on every hit.
    ctx.enemies.elite[slot] =
        def.family == EnemyFamily.riftborn ? 1 : 0;
    ctx.enemies.rush[slot] = def.family == EnemyFamily.rush ? 1 : 0;
    ctx.enemies.variant[slot] = variant.index;
    ctx.enemies.speedScale[slot] = 1.0 + variant.speedBonus;
    ctx.enemies.spawnerSlot[slot] = spawnerSlot;
    ctx.enemies.revivesLeft[slot] = def.combat.reviveCount;

    // Phase is seeded per enemy so a pack of Wisps does not weave in lockstep,
    // which would read as one wide object rather than four small ones.
    ctx.enemies.phase[slot] = ctx.rng.nextDouble() * 2 * math.pi;

    ctx.enemies.adaptSeconds[slot] = def.combat.immunitySeconds;

    if (def.hasFrontalPlate) {
      ctx.enemies.plateHealth[slot] =
          health * EnemyTuning.plateHealthFraction;
      ctx.enemies.plateHalfArc[slot] =
          def.plateArcDegrees / 2 * (math.pi / 180.0);
    }

    if (variant == EnemyVariant.voidtouched) {
      // Permanent, and chosen from the run's own generator so a seed reproduces
      // exactly which element a given Voidtouched shrugs off.
      final SimElement immune =
          SimElement.values[ctx.rng.nextInt(SimElement.values.length)];
      ctx.enemies.adaptTo(slot, immune, double.infinity);
    }

    ctx.status.clearSlot(slot);

    if (spawnerSlot >= 0) {
      ctx.enemies.liveAdds[spawnerSlot]++;
    }

    ctx.events.emit(
      SimEventType.entitySpawned,
      entityA: slot,
      valueA: contentIndex.toDouble(),
      valueB: variant.index.toDouble(),
      x: x,
      y: y,
    );

    return slot;
  }

  /// Finds a legal spawn point: inside the arena, clear of walls, and at least
  /// [EnemyTuning.minSpawnDistanceFromPlayer] from the player.
  ///
  /// Writes the result to [pointX] / [pointY] and returns whether the search
  /// succeeded on its own terms. On failure it still writes a usable point —
  /// the arena corner furthest from the player — because a wave that silently
  /// spawns nothing is a room the player can never clear.
  static bool findSpawnPoint(AiContext ctx, double radius) {
    final double minDist = EnemyTuning.minSpawnDistanceFromPlayer + radius;
    final double minDistSq = minDist * minDist;

    for (int attempt = 0;
        attempt < EnemyTuning.spawnPlacementAttempts;
        attempt++) {
      final double x = ctx.rng.nextDoubleRange(radius, ctx.arena.width - radius);
      final double y =
          ctx.rng.nextDoubleRange(radius, ctx.arena.height - radius);

      if (ctx.arena.circleHitsWall(x, y, radius)) continue;

      if (ctx.hasPlayer) {
        final double dx = x - ctx.playerX;
        final double dy = y - ctx.playerY;
        if (dx * dx + dy * dy < minDistSq) continue;
      }

      pointX = x;
      pointY = y;
      return true;
    }

    _furthestCorner(ctx, radius);
    return false;
  }

  /// Result of the last [findSpawnPoint]. Static scratch rather than a returned
  /// pair, for the same reason everything else in the sim avoids records: this
  /// runs inside spawn loops and must not allocate.
  static double pointX = 0;
  static double pointY = 0;

  static void _furthestCorner(AiContext ctx, double radius) {
    final double lo = radius;
    final double hiX = ctx.arena.width - radius;
    final double hiY = ctx.arena.height - radius;

    pointX = ctx.hasPlayer && ctx.playerX < ctx.arena.width / 2 ? hiX : lo;
    pointY = ctx.hasPlayer && ctx.playerY < ctx.arena.height / 2 ? hiY : lo;
  }

  /// A point on a ring around [ownerSlot], for summoners that place their adds
  /// around themselves rather than anywhere in the arena.
  static void ringPoint(
    AiContext ctx,
    int ownerSlot,
    int index,
    int count,
    double radius,
  ) {
    final double angle =
        2 * math.pi * index / (count <= 0 ? 1 : count) +
            ctx.enemies.phase[ownerSlot];

    double x = ctx.entities.posX[ownerSlot] + math.cos(angle) * radius;
    double y = ctx.entities.posY[ownerSlot] + math.sin(angle) * radius;

    if (x < radius) x = radius;
    if (y < radius) y = radius;
    if (x > ctx.arena.width - radius) x = ctx.arena.width - radius;
    if (y > ctx.arena.height - radius) y = ctx.arena.height - radius;

    pointX = x;
    pointY = y;
  }

  /// True if the room is already at the ceiling for contact-capable enemies.
  ///
  /// Beyond this a phone screen is unreadable regardless of frame rate
  /// (docs/19 §19.1), and on Battery tier the ceiling is lower still.
  static bool atEnemyCap(AiContext ctx) {
    int enemies = 0;
    final int high = ctx.entities.highWater;
    for (int i = 0; i < high; i++) {
      if (ctx.entities.alive[i] == 0) continue;
      if (ctx.entities.kind[i] != EntityKind.enemy.index) continue;
      enemies++;
      if (enemies >= ctx.enemyCap) return true;
    }
    return false;
  }
}
