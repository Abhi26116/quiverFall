import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/hazard_store.dart';

/// Moves and resolves everything the enemies have put into the world.
///
/// Runs after the AI, so ordnance fired this tick starts flying this tick — a
/// shell that waited a frame would land a frame late, and the landing ring
/// would be a frame's worth of lie.
abstract final class HazardSystem {
  static void update(AiContext ctx) {
    // Puddles do not stack (docs/05 §5.4). Enforced per tick rather than per
    // puddle: standing where two acid pools overlap is a positioning mistake
    // worth one puddle's damage, not two, or Spitters would become the most
    // lethal enemy in the game by accident.
    bool puddleApplied = false;

    for (int i = 0; i < ctx.hazards.capacity; i++) {
      if (!ctx.hazards.isAlive(i)) continue;

      if (ctx.hazards.isSpent(i)) {
        _retire(ctx, i);
        continue;
      }

      switch (ctx.hazards.kindAt(i)) {
        case HazardKind.bolt:
          _advanceBolt(ctx, i);
        case HazardKind.shell:
          _advanceShell(ctx, i);
        case HazardKind.puddle:
          puddleApplied = _tickPuddle(ctx, i, puddleApplied);
      }
    }
  }

  static void _advanceBolt(AiContext ctx, int slot) {
    final double fromX = ctx.hazards.x[slot];
    final double fromY = ctx.hazards.y[slot];
    final double toX = fromX + ctx.hazards.velX[slot] * ctx.dt;
    final double toY = fromY + ctx.hazards.velY[slot] * ctx.dt;

    ctx.hazards.remaining[slot] -= ctx.dt;

    // Walls stop enemy fire exactly as they stop the player's. Cover being a
    // real answer to a Nettle is the same promise as cover being a real answer
    // to a Longeye.
    if (ctx.arena.circleHitsWall(toX, toY, ctx.hazards.radius[slot]) ||
        !ctx.arena.containsPoint(toX, toY) ||
        ctx.hazards.remaining[slot] <= 0) {
      ctx.hazards.markSpent(slot);
      ctx.hazards.x[slot] = toX;
      ctx.hazards.y[slot] = toY;
      return;
    }

    // Swept, not sampled: a 5 u/s bolt covers 0.08 u per tick, and a point test
    // against a moving player is exactly how "it went through me" bugs happen.
    if (EnemyAttack.playerOnLine(
      ctx,
      fromX,
      fromY,
      toX,
      toY,
      ctx.hazards.radius[slot],
    )) {
      EnemyAttack.damagePlayer(
        ctx,
        ctx.hazards.damage[slot],
        source: ctx.hazards.ownerAt(slot),
      );
      ctx.hazards.markSpent(slot);
    }

    ctx.hazards.x[slot] = toX;
    ctx.hazards.y[slot] = toY;
  }

  static void _advanceShell(AiContext ctx, int slot) {
    ctx.hazards.remaining[slot] -= ctx.dt;

    // Position is interpolated along the flight rather than integrated, so the
    // shell is guaranteed to arrive on its ring at the exact moment the ring
    // finishes filling.
    final double t = ctx.hazards.progressAt(slot);
    ctx.hazards.x[slot] = ctx.hazards.fromX[slot] +
        (ctx.hazards.toX[slot] - ctx.hazards.fromX[slot]) * t;
    ctx.hazards.y[slot] = ctx.hazards.fromY[slot] +
        (ctx.hazards.toY[slot] - ctx.hazards.fromY[slot]) * t;

    if (ctx.hazards.remaining[slot] > 0) return;

    final double x = ctx.hazards.toX[slot];
    final double y = ctx.hazards.toY[slot];

    EnemyAttack.blast(
      ctx,
      source: ctx.hazards.ownerAt(slot),
      x: x,
      y: y,
      radius: ctx.hazards.radius[slot],
      damage: ctx.hazards.damage[slot],
    );

    if (ctx.hazards.lingerSeconds[slot] > 0) {
      EnemyAttack.dropPuddle(
        ctx,
        ctx.hazards.ownerAt(slot),
        x: x,
        y: y,
        radius: ctx.hazards.radius[slot],
        damagePerSecond: ctx.hazards.lingerDamage[slot],
        seconds: ctx.hazards.lingerSeconds[slot],
      );
    }

    _retire(ctx, slot);
  }

  static bool _tickPuddle(AiContext ctx, int slot, bool alreadyApplied) {
    ctx.hazards.remaining[slot] -= ctx.dt;
    if (ctx.hazards.remaining[slot] <= 0) {
      _retire(ctx, slot);
      return alreadyApplied;
    }

    if (alreadyApplied) return true;

    if (!EnemyAttack.playerInCircle(
      ctx,
      ctx.hazards.x[slot],
      ctx.hazards.y[slot],
      ctx.hazards.radius[slot],
    )) {
      return false;
    }

    EnemyAttack.damagePlayer(
      ctx,
      ctx.hazards.damagePerSecond[slot] * ctx.dt,
      source: ctx.hazards.ownerAt(slot),
    );
    return true;
  }

  static void _retire(AiContext ctx, int slot) {
    ctx.telegraphs.release(
      ctx.hazards.telegraphSlotAt(slot),
      ctx.hazards.telegraphSerialAt(slot),
    );
    ctx.hazards.release(slot);
  }
}
