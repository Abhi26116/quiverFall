import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';

/// CHOIR — the priority tax.
///
/// Never dangerous alone. Make everything else dangerous. They exist to teach
/// target selection, which is the one decision auto-aim deliberately refuses to
/// make for the player (docs/05 §5.5).
///
/// Every unit here answers "kill it first" and every one of them *says so* — the
/// Weaver's cyan tether, the Chanter's amber ring, the Knitter's green threads,
/// the Warden-Fell's grey. The game is telling the player the answer; the skill
/// is acting on it while something else is chasing them.
///
/// Aura *effects* are applied in [AiSystem]'s aura pass, recomputed from
/// scratch every tick so they vanish the instant their source dies. This tree
/// is only movement, plus the Weaver's shield, which is a discrete grant rather
/// than a continuous field.
abstract final class ChoirTree {
  static void update(AiContext ctx, int slot, EnemyDefinition def) {
    switch (def.archetype) {
      case EnemyArchetype.weaver:
        _weaver(ctx, slot, def);
      case EnemyArchetype.chanter:
        _chanter(ctx, slot, def);
      case EnemyArchetype.knitter:
        _knitter(ctx, slot, def);
      case EnemyArchetype.wardenFell:
        _wardenFell(ctx, slot, def);
      default:
        _chanter(ctx, slot, def);
    }
  }

  /// Stays behind its ally, keeps the tether up, re-shields when it breaks.
  static void _weaver(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;
    ctx.enemies.state[slot] = AiState.reposition.index;

    final int ally = _nearestAlly(ctx, slot, c.auraRadius);

    if (ally >= 0 &&
        ctx.enemies.attackCooldown[slot] <= 0 &&
        ctx.enemies.shield[ally] <= 0) {
      ctx.enemies.shield[ally] = ctx.entities.maxHealth[ally] * c.auraStrength;
      ctx.enemies.shieldedBy[ally] = slot;
      ctx.enemies.attackCooldown[slot] =
          c.attackCooldown < EnemyTuning.weaverMinReapplySeconds
              ? EnemyTuning.weaverMinReapplySeconds
              : c.attackCooldown;
    }

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }

    if (ally < 0) {
      // Nothing to protect. Falls back to retreating, which keeps a lone Weaver
      // alive long enough to be worth walking over to kill.
      Steering.moveAway(
        ctx,
        slot,
        ctx.playerX,
        ctx.playerY,
        Steering.speedOf(ctx, slot, def),
      );
      return;
    }

    // Directly behind the ally, on the line away from the player — the position
    // that makes the tether the only thing pointing at it.
    final double ax = ctx.entities.posX[ally];
    final double ay = ctx.entities.posY[ally];
    double dx = ax - ctx.playerX;
    double dy = ay - ctx.playerY;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len > 1e-9) {
      dx /= len;
      dy /= len;
    }
    final double standOff =
        ctx.entities.radius[ally] + ctx.entities.radius[slot] + c.keepDistance;

    Steering.moveToward(
      ctx,
      slot,
      ax + dx * standOff,
      ay + dy * standOff,
      Steering.speedOf(ctx, slot, def),
    );
  }

  /// Retreats from the player while keeping allies inside its aura.
  ///
  /// Those two goals conflict, which is what makes the Chanter catchable: it
  /// cannot run and buff at the same time, so pressuring it costs the pack its
  /// damage bonus even before it dies.
  static void _chanter(AiContext ctx, int slot, EnemyDefinition def) {
    final EnemyCombat c = def.combat;
    ctx.enemies.state[slot] = AiState.reposition.index;

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }

    final double speed = Steering.speedOf(ctx, slot, def);
    final double distSq = ctx.distanceSquaredToPlayer(slot);

    if (distSq < c.keepDistance * c.keepDistance) {
      Steering.moveAway(ctx, slot, ctx.playerX, ctx.playerY, speed);
      return;
    }

    // Far enough from the player: drift back toward the pack it is buffing.
    if (_packCentroid(ctx, slot, c.auraRadius * 2)) {
      Steering.moveToward(ctx, slot, _centroidX, _centroidY, speed);
      return;
    }
    Steering.halt(ctx, slot);
  }

  /// Moves to the most-damaged ally.
  ///
  /// The clearest DPS check in the game: a Knitter can out-heal an underpowered
  /// player outright, and the answer is either Toxin (halved healing) or simply
  /// killing it — both of which are decisions rather than reflexes.
  static void _knitter(AiContext ctx, int slot, EnemyDefinition def) {
    ctx.enemies.state[slot] = AiState.reposition.index;

    final int patient = _mostDamagedAlly(ctx, slot, def.combat.auraRadius * 3);
    final double speed = Steering.speedOf(ctx, slot, def);

    if (patient >= 0) {
      Steering.moveToward(
        ctx,
        slot,
        ctx.entities.posX[patient],
        ctx.entities.posY[patient],
        speed,
      );
      return;
    }

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }
    Steering.moveAway(ctx, slot, ctx.playerX, ctx.playerY, speed);
  }

  /// Interposes itself between the player and the pack.
  ///
  /// The build-check enemy: inside its aura the world literally goes grey and
  /// no element applies, so a pure elemental build must have a physical answer.
  /// Standing *between* is what makes "pull enemies out of its aura" a real
  /// alternative to killing it.
  static void _wardenFell(AiContext ctx, int slot, EnemyDefinition def) {
    ctx.enemies.state[slot] = AiState.reposition.index;

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }

    final double speed = Steering.speedOf(ctx, slot, def);
    if (!_packCentroid(ctx, slot, def.combat.auraRadius * 2)) {
      Steering.moveToward(ctx, slot, ctx.playerX, ctx.playerY, speed);
      return;
    }

    Steering.moveToward(
      ctx,
      slot,
      (_centroidX + ctx.playerX) / 2,
      (_centroidY + ctx.playerY) / 2,
      speed,
    );
  }

  // ── Ally queries ──────────────────────────────────────────────────────────
  //
  // Choir units are rare — at most two per room by the composition rules — so
  // these run a handful of times per tick, not per enemy.

  static int _nearestAlly(AiContext ctx, int slot, double radius) {
    final int found = ctx.spatial.queryRadius(
      ctx.entities.posX[slot],
      ctx.entities.posY[slot],
      radius,
    );

    int best = -1;
    double bestDistSq = double.infinity;

    for (int i = 0; i < found; i++) {
      final int other = ctx.spatial.resultAt(i);
      if (!_isAlly(ctx, slot, other)) continue;
      final double dx = ctx.entities.posX[other] - ctx.entities.posX[slot];
      final double dy = ctx.entities.posY[other] - ctx.entities.posY[slot];
      final double distSq = dx * dx + dy * dy;
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        best = other;
      }
    }
    return best;
  }

  static int _mostDamagedAlly(AiContext ctx, int slot, double radius) {
    final int found = ctx.spatial.queryRadius(
      ctx.entities.posX[slot],
      ctx.entities.posY[slot],
      radius,
    );

    int best = -1;
    double worstFraction = 1.0;

    for (int i = 0; i < found; i++) {
      final int other = ctx.spatial.resultAt(i);
      if (!_isAlly(ctx, slot, other)) continue;
      final double max = ctx.entities.maxHealth[other];
      if (max <= 0) continue;
      final double fraction = ctx.entities.health[other] / max;
      if (fraction < worstFraction) {
        worstFraction = fraction;
        best = other;
      }
    }
    return best;
  }

  /// Centroid of nearby allies, written to [_centroidX] / [_centroidY].
  /// Returns false when there are none.
  ///
  /// Static scratch rather than a returned record or a pair of out-parameters:
  /// the sim is single-threaded by construction and this is called on the hot
  /// path, where a record would allocate.
  static bool _packCentroid(AiContext ctx, int slot, double radius) {
    final int found = ctx.spatial.queryRadius(
      ctx.entities.posX[slot],
      ctx.entities.posY[slot],
      radius,
    );

    double sumX = 0;
    double sumY = 0;
    int count = 0;

    for (int i = 0; i < found; i++) {
      final int other = ctx.spatial.resultAt(i);
      if (!_isAlly(ctx, slot, other)) continue;
      sumX += ctx.entities.posX[other];
      sumY += ctx.entities.posY[other];
      count++;
    }

    if (count == 0) return false;
    _centroidX = sumX / count;
    _centroidY = sumY / count;
    return true;
  }

  static double _centroidX = 0;
  static double _centroidY = 0;

  static bool _isAlly(AiContext ctx, int slot, int other) {
    if (other == slot) return false;
    if (ctx.entities.alive[other] == 0) return false;
    if (ctx.entities.kind[other] != EntityKind.enemy.index) return false;
    // A bare entity with no content definition — a boss's own body, or one
    // of its inert children, `contentIndex = -1` — has no family to read at
    // all, so `definitionOf` must not be called on it; it is trivially not
    // Choir-family and so a valid ally. This is exactly how a boss's own
    // spawned Knitters find and heal it (The Green Mother, docs/06 §8).
    if (!ctx.hasDefinition(other)) return true;
    // A Choir unit supporting another Choir unit is a healing loop the player
    // cannot break in the intended order, so they simply do not see each other.
    return ctx.definitionOf(other).family != EnemyFamily.choir;
  }
}
