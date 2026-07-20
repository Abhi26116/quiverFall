import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// CARAPACE — the armour puzzle.
///
/// **The Draw mechanic's reason to exist.** Every enemy here is a directional or
/// timing puzzle that only Tier II/III solves (docs/05 §5.2). Their shared
/// property is the frontal plate; their differences are entirely in what
/// happens when it breaks.
///
/// The Bulwark is the deliberate inversion: it is the one enemy where Tier III
/// is *wrong*, because you must keep moving to flank it, which means Momentum,
/// which means Tier I. That exists so the player never learns "Tier III always".
abstract final class CarapaceTree {
  static void update(AiContext ctx, int slot, EnemyDefinition def) {
    switch (def.archetype) {
      case EnemyArchetype.husk:
        _plod(ctx, slot, def);
      case EnemyArchetype.bulwark:
        _rotate(ctx, slot, def);
      case EnemyArchetype.shellback:
        _shellback(ctx, slot, def);
      case EnemyArchetype.ironmaw:
        _ironmaw(ctx, slot, def);
      default:
        _plod(ctx, slot, def);
    }
  }

  /// Slow direct seek, always turning to keep the plate between it and the
  /// player — but at a finite rate, which is what makes flanking a move a
  /// player can actually execute rather than a line in a design document.
  static void _plod(AiContext ctx, int slot, EnemyDefinition def) {
    ctx.enemies.plateJustBroke[slot] = 0;
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

  /// Never moves. Rotates its 180-degree shield toward the player at a capped
  /// rate. Out-rotating it is the entire fight.
  static void _rotate(AiContext ctx, int slot, EnemyDefinition def) {
    ctx.enemies.plateJustBroke[slot] = 0;
    ctx.enemies.state[slot] = AiState.idle.index;
    Steering.halt(ctx, slot);
    if (!ctx.hasPlayer) return;
    Steering.faceToward(
      ctx,
      slot,
      ctx.playerX,
      ctx.playerY,
      def.combat.turnRateDegrees,
    );
  }

  /// Breaks, retreats, regenerates, re-engages.
  ///
  /// The retreat is what turns the Shellback into a *sustained pressure* check:
  /// a burst-and-wait build lands its burst, watches the plate come back, and
  /// discovers it has nothing for the second round.
  static void _shellback(AiContext ctx, int slot, EnemyDefinition def) {
    if (ctx.enemies.plateJustBroke[slot] == 1) {
      ctx.enemies.plateJustBroke[slot] = 0;
      ctx.enemies.state[slot] = AiState.recover.index;
      ctx.enemies.stateTimer[slot] = def.combat.recoverySeconds;
    }

    if (ctx.enemies.stateOf(slot) == AiState.recover) {
      ctx.enemies.stateTimer[slot] -= ctx.dt;
      if (ctx.enemies.stateTimer[slot] > 0) {
        if (ctx.hasPlayer) {
          Steering.moveAway(
            ctx,
            slot,
            ctx.playerX,
            ctx.playerY,
            Steering.speedOf(ctx, slot, def),
          );
        } else {
          Steering.halt(ctx, slot);
        }
        return;
      }
    }

    _plod(ctx, slot, def);
  }

  /// Enrage, with the telegraph 0.4 s ahead of the threat.
  ///
  /// docs/05 §5.2 is explicit that the plate seams flood crimson *before* the
  /// speed change, and that ordering is the whole enemy: it punishes breaking
  /// armour without an escape plan, and it can only teach that if the player is
  /// given the moment in which to make one.
  static void _ironmaw(AiContext ctx, int slot, EnemyDefinition def) {
    // Freeze cancels the enrage outright, wind-up included (docs/05 §5.2). That
    // is handled centrally in [AiSystem] — a frozen Ironmaw never reaches this
    // tree at all.
    if (ctx.enemies.plateJustBroke[slot] == 1) {
      ctx.enemies.plateJustBroke[slot] = 0;
      ctx.enemies.state[slot] = AiState.windUp.index;
      ctx.enemies.stateTimer[slot] = def.combat.windUpSeconds;
      EnemyAttack.beginCircle(
        ctx,
        slot,
        ctx.entities.posX[slot],
        ctx.entities.posY[slot],
        ctx.entities.radius[slot] * 2.0,
        def.combat.windUpSeconds,
        severity: TelegraphSeverity.lethal,
      );
    }

    if (ctx.enemies.stateOf(slot) == AiState.windUp) {
      Steering.halt(ctx, slot);
      EnemyAttack.followTelegraph(
        ctx,
        slot,
        ctx.entities.posX[slot],
        ctx.entities.posY[slot],
      );
      ctx.enemies.stateTimer[slot] -= ctx.dt;
      if (ctx.enemies.stateTimer[slot] > 0) return;

      EnemyAttack.endTelegraph(ctx, slot);
      ctx.enemies.enrageRemaining[slot] = def.combat.recoverySeconds;
      ctx.enemies.speedScale[slot] =
          _baseSpeedScale(ctx, slot) * EnemyTuning.enrageSpeedMultiplier;
      ctx.enemies.state[slot] = AiState.seek.index;
      return;
    }

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return;
    }

    ctx.enemies.state[slot] = AiState.seek.index;

    // Unenraged it turns freely; enraged it is capped, which is what makes
    // kiting the enrage possible. The threat and the counter-play arrive
    // together.
    Steering.faceToward(
      ctx,
      slot,
      ctx.playerX,
      ctx.playerY,
      ctx.enemies.isEnraged(slot) ? def.combat.turnRateDegrees : 0,
    );
    Steering.moveToward(
      ctx,
      slot,
      ctx.playerX,
      ctx.playerY,
      Steering.speedOf(ctx, slot, def),
    );
  }

  /// The speed scale an enemy returns to once a temporary multiplier ends —
  /// its variant's, not a flat 1.0, or enraging a Frenzied Ironmaw would
  /// permanently *slow* it.
  static double _baseSpeedScale(AiContext ctx, int slot) =>
      1.0 + ctx.enemies.variantOf(slot).speedBonus;
}
