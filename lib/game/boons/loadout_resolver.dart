import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/boon_stats.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/systems/confluence_system.dart';
import 'package:quiverfall/game/sim/world.dart';

/// Turns a composed [BoonStats] into the numbers the simulation actually runs
/// on.
///
/// **This is the one place a Boon becomes a game rule.** Everything upstream is
/// data — a channel and a value; everything downstream reads plain fields on
/// [SimWorld] and never knows a Boon exists. Keeping that seam sharp is what
/// lets the balance harness swap a whole build by writing one object, and what
/// stops "does Boon X apply here?" from becoming a question asked in forty
/// places.
///
/// Called when the build changes — after a Boon is taken, and at room start —
/// never per tick.
///
/// **Multiplicative across sources** (docs/04 §4.1 rule 1). Each `base*`
/// argument is that source's own composed value; Boons apply one multiplier on
/// top. Two sources never sum into each other here, and no single source is
/// allowed to reach a term twice.
abstract final class LoadoutResolver {
  /// Applies a build to a world.
  ///
  /// The `base*` values are the loadout *before* Boons: hero, arrow, Spire,
  /// research and ascension already composed. They are passed rather than read
  /// back off the world so that applying twice is idempotent — reading the
  /// world's current `playerAttack` and multiplying would compound the same
  /// Boons on every room transition, which is the classic version of this bug.
  static void apply(
    SimWorld world,
    BoonStats stats, {
    required double baseAttack,
    double baseFireRateMultiplier = 1.0,
    double baseMaxHealth = 100.0,
    double baseMoveSpeed = SimConfig.playerMoveSpeed,
    double baseProjectileSpeed = 14.0,
    double baseArrowRadius = 0.12,
    int basePierce = 0,
    double baseWindlineDuration = SimConfig.windlineDuration,
    double baseWindlineHitWidth = SimConfig.windlineHitWidth,
    int baseMaxConfluenceStacks = ConfluenceTuning.defaultMaxStacks,
    int baseMaxMomentum = DrawState.baseMaxMomentum,
    double baseDrawSpeedMultiplier = 1.0,
  }) {
    // ── Offence ─────────────────────────────────────────────────────────────
    // Attack itself is NOT multiplied by the damage channel here. That channel
    // is `boonDamageSum` and belongs in DamageResolver's term 5, where it is
    // clamped and where the conditional channels join it. Applying it in both
    // places would square it — and it would look correct in every single-Boon
    // test.
    world.playerAttack = baseAttack;

    world.fireRateMultiplier =
        baseFireRateMultiplier * stats.multiplierFor(StatChannel.fireRate);

    world.projectileSpeed =
        baseProjectileSpeed * stats.multiplierFor(StatChannel.projectileSpeed);

    world.arrowRadius =
        baseArrowRadius * stats.multiplierFor(StatChannel.arrowRadius);

    world.basePierce = basePierce + stats.countFor(StatChannel.pierce);

    // ── Defence ─────────────────────────────────────────────────────────────
    _applyMaxHealth(
      world,
      baseMaxHealth * stats.multiplierFor(StatChannel.maxHealth),
    );

    // ── Mobility ────────────────────────────────────────────────────────────
    world.playerMoveSpeed =
        baseMoveSpeed * stats.multiplierFor(StatChannel.moveSpeed);

    world.playerDraw
      ..maxMomentum = baseMaxMomentum + stats.countFor(StatChannel.maxMomentum)
      ..drawSpeedMultiplier =
          baseDrawSpeedMultiplier * stats.multiplierFor(StatChannel.drawSpeed);

    // ── Windline & Confluence ───────────────────────────────────────────────
    world.windlineDuration =
        baseWindlineDuration + stats[StatChannel.windlineDuration];

    world.windlineHitWidth =
        baseWindlineHitWidth * stats.multiplierFor(StatChannel.windlineWidth);

    // Clamped to the bonus table: a stack count with no entry would read past
    // the end of ConfluenceTuning.bonusByStacks.
    final int stacks =
        baseMaxConfluenceStacks + stats.countFor(StatChannel.confluenceStacks);
    world.maxConfluenceStacks =
        stacks > ConfluenceTuning.maxStacks ? ConfluenceTuning.maxStacks : stacks;

    world.confluenceDamageMultiplier =
        stats.multiplierFor(StatChannel.confluenceDamage);

    world.confluenceHeadStart = stats.countFor(StatChannel.confluenceHeadStart);

    world.windlineSlow = stats[StatChannel.windlineSlow];
    world.windlineDamageFraction = stats[StatChannel.windlineDamage];

    // ── Momentum tuning ─────────────────────────────────────────────────────
    // Slower decay is a *longer* grace window; faster build is a *shorter*
    // charge time. One multiplies and the other divides, which is the kind of
    // asymmetry that reads as a typo and is not.
    world.playerDraw
      ..graceSeconds = DrawState.momentumGraceSeconds *
          stats.multiplierFor(StatChannel.momentumDecayRate)
      ..stackChargeSeconds = DrawState.secondsPerMomentumStack /
          stats.multiplierFor(StatChannel.momentumBuildRate);

    // ── Mitigation ──────────────────────────────────────────────────────────
    // Kept as separate sources rather than summed, because DamageResolver
    // combines them multiplicatively and caps the product. Summing here would
    // reach 100 % and make the player invulnerable — docs/04 §4.1 rule 2.
    world.boonDamageReduction = stats[StatChannel.damageReduction];
    world.stationaryDamageReduction =
        stats[StatChannel.damageReductionStationary];
    world.elementalResist = stats[StatChannel.elementalResist];
    world.damageTakenMultiplier =
        stats.multiplierFor(StatChannel.damageTakenMultiplier);

    world.thornsReflect = stats[StatChannel.thornsReflect];
    world.lifesteal = stats[StatChannel.lifesteal];
    world.shieldPerMomentum = stats[StatChannel.shieldPerMomentum];
    world.regenWhileMoving = stats[StatChannel.regenWhileMoving];
    world.healOnRoomClear = stats[StatChannel.healOnRoomClear];

    // ── Volley ──────────────────────────────────────────────────────────────
    // Split Shot and Twin Nock add arrows and pay for them per arrow. The
    // penalty is a sum of negatives, so three Split Shots is −45 %, and the
    // clamp stops a hypothetical stack from inverting the sign.
    world.extraArrows = stats.countFor(StatChannel.extraArrows);
    final double penalty = stats[StatChannel.splitDamagePenalty];
    world.volleyDamageMultiplier = penalty < -0.95 ? 0.05 : 1.0 + penalty;

    // ── Per-hit conditionals ────────────────────────────────────────────────
    world.combat.composeFrom(stats);
  }

  /// Changes max HP while preserving the *fraction* the player is standing at.
  ///
  /// Taking *Toughened Hide* at 30 % HP must not heal, and *Ruin* halving max
  /// HP must not kill. Both are the same bug in opposite directions, and both
  /// are what happens if max HP is written without touching current.
  static void _applyMaxHealth(SimWorld world, double newMax) {
    if (world.player.isNone) return;
    final int p = world.player.index;

    final double oldMax = world.entities.maxHealth[p];
    final double fraction =
        oldMax > 0 ? (world.entities.health[p] / oldMax).clamp(0.0, 1.0) : 1.0;

    world.entities.maxHealth[p] = newMax;
    world.entities.health[p] = newMax * fraction;
  }

  /// The mitigation the player has right now, as a single factor.
  ///
  /// Combined multiplicatively and capped at
  /// [DamageResolver.maxDamageReduction] — never summed.
  static double incomingDamageFactor(SimWorld world) {
    final double momentum = world.playerDraw.damageReduction;
    final double stationary =
        world.combat.playerStationary ? world.stationaryDamageReduction : 0.0;

    final double remaining = (1.0 - _clamp01(world.boonDamageReduction)) *
        (1.0 - _clamp01(stationary)) *
        (1.0 - _clamp01(momentum));

    double total = 1.0 - remaining;
    if (total > DamageResolver.maxDamageReduction) {
      total = DamageResolver.maxDamageReduction;
    }
    return (1.0 - total) * world.damageTakenMultiplier;
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
}
