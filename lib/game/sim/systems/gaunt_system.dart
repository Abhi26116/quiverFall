import 'dart:math' as math;

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// Gaunt, the Iron Tide — docs/06 §2, chapter 2's boss. "Tests: flanking."
///
/// **P1: "A colossal shield-bearer. Frontal 180° arc takes 5% damage...
/// Slow advance, shield always facing the player. Rotates 70°/s — beatable
/// by circling."** A single body the whole fight (no split, unlike Cinder
/// Choir/Skarn) — the entire P1 lesson is positional: the shield tracks
/// the player at a *capped* turn rate (`Steering.faceToward`, the same
/// primitive Husk's own family tree already turns with), so a player who
/// strafes faster than 70°/s walks around behind it while the front stays
/// locked on where they used to be.
///
/// The frontal arc reuses the *existing* plate system (`plateHalfArc`,
/// `_armourFor`'s arc check) but not its Tier-scaled reduction — docs/06 §2
/// states a flat 5%, without Cinder Choir's own "Tier III breaks it"
/// caveat, so `EnemyStore.plateFlatFactor` (new) overrides the usual
/// 10/55/100% switch. See ADR 0023.
///
/// **P2: "Shield slams, sending a crimson shockwave ring outward (jumpable
/// only by being outside 5u — there is no jump, so this is a positioning
/// check). Rotation rises to 110°/s."** A "ring outward" is a rendering
/// question, not a sim one — the hit test at resolve time is the same
/// `beginCircle`/`playerInCircle` every other boss's own circle attack
/// already uses, at the card's own stated 5u radius. Unlike Skarn's own
/// P1 slam (ADR 0034), this one is *not* range-gated: it fires on a plain
/// cooldown regardless of distance, since the shockwave's own radius
/// already *is* the range question — "outside 5u" is the entire dodge.
/// The wind-up (1.8s) and cooldown (2.0s) reuse Skarn's own "enormous
/// telegraph" magnitudes (ADR 0034), and the damage reuses the same
/// derived "heavy hit" anchor Hollow Warden's shot and Skarn's slam
/// already share (the Thresher's own 9%, scaled by Tier III's own 2.10x
/// multiplier) — a third boss agreeing on what "heavy" means numerically,
/// not a fourth independently-guessed number. The shield keeps advancing
/// and tracking the player between slams, just at P2's own faster,
/// GDD-stated rotation rate. See ADR 0035.
///
/// **P3, built here: "Drops the shield entirely, gains +80% speed and a
/// Ripper-style 3-hit combo with a stagger window. The armour puzzle
/// becomes a reflex test."** "Ripper-style" names an existing family
/// verbatim (docs/05, `RushTree._ripper`) — its own three-hit combo (two
/// openers, a lethal overhead finisher; landing enough damage during the
/// finisher's own wind-up staggers it, `EnemyTuning.
/// ripperStaggerFraction`/`ripperStaggerSeconds`/`ripperComboLength`/
/// `ripperSwingArcDegrees`/`ripperOpenerFraction` all reused verbatim) is
/// reimplemented directly against `Steering`/`EnemyAttack` rather than
/// called into, the same "reuse the shape, not the private function"
/// posture every borrowed-family-mechanic boss already takes — Gaunt has
/// no `EnemyDefinition` to run that tree method with. Timing (0.35s/0.8s/
/// 0.7s/1.6s wind-up/heavy-wind-up/recovery/cooldown) is reused verbatim
/// from the ordinary Ripper's own content data (unchanged — a genuinely
/// fast combo is what makes it a reflex test); damage and reach are
/// scaled up for a boss-sized body: the finisher deals the same derived
/// "heavy hit" this boss's own P2 shockwave already uses (0.09 × 2.10),
/// openers scale off it by the ordinary Ripper's own opener fraction
/// (0.36), and the attack range roughly doubles the ordinary Ripper's own
/// 1.3u. `plateHealth` is permanently zeroed the instant P3 begins — "the
/// armour puzzle becomes a reflex test" reads as the puzzle being *gone*,
/// not merely bypassable — and never re-armed. `_p1Speed × 1.8` is the
/// card's own stated speed multiplier applied to the one number this
/// fight has always used for movement. See ADR 0049.
abstract final class GauntSystem {
  /// docs/06 §2 P1's own stated rotation rate.
  static const double _p1RotationDegreesPerSecond = 70.0;

  /// docs/06 §2 P2's own stated rotation rate.
  static const double _p2RotationDegreesPerSecond = 110.0;

  /// docs/06 §2's own stated frontal factor.
  static const double _frontalFactor = 0.05;

  /// docs/06 §2: "Frontal 180° arc" is a full angle; `plateHalfArc` wants
  /// half of it.
  static const double _plateHalfArc = math.pi / 2;

  /// Reused from Husk (docs/05), the base Carapace archetype whose own
  /// family this "colossal shield-bearer" is a heavier variation of —
  /// docs/06 gives no speed number of its own for "slow advance". See ADR
  /// 0023.
  static const double _p1Speed = 1.0;

  // ── P2: the shockwave slam ───────────────────────────────────────────────
  // See ADR 0035.

  /// docs/06 §2 P2's own stated radius — "outside 5u" is the entire dodge.
  static const double _p2SlamRadius = 5.0;

  /// Reused from Skarn's own "enormous telegraph" magnitude (ADR 0034).
  static const double _p2SlamWindUpSeconds = 1.8;
  static const double _p2SlamCooldownSeconds = 2.0;

  /// Derived, not guessed a third time: the Thresher's own 9% anchor
  /// scaled by Tier III's own 2.10x damage multiplier — the same
  /// derivation Hollow Warden's shot and Skarn's slam already use.
  static const double _p2SlamDamage = 0.09 * 2.10;

  // ── P3: the Ripper-style combo ────────────────────────────────────────
  // See ADR 0049.

  /// docs/06 §2's own stated speed multiplier, applied to [_p1Speed] — the
  /// one number this fight has always used for movement.
  static const double _p3Speed = _p1Speed * 1.8;

  /// The finisher's own damage — the same derived "heavy hit" this boss's
  /// own P2 shockwave already uses, not a fourth independently-guessed
  /// number.
  static const double _p3AttackDamage = _p2SlamDamage;

  /// Double the ordinary Ripper's own 1.3u (docs/05, content data) —
  /// authored for a boss-sized body, not GDD-stated.
  static const double _p3AttackRange = 1.3 * 2;

  /// Reused verbatim from the ordinary Ripper's own content data — a
  /// genuinely fast combo is what makes this "a reflex test".
  static const double _p3WindUpSeconds = 0.35;
  static const double _p3HeavyWindUpSeconds = 0.8;
  static const double _p3RecoverySeconds = 0.7;
  static const double _p3AttackCooldownSeconds = 1.6;

  /// Places Gaunt's single, always-plated body. Returns its slot, or -1 if
  /// the entity pool was full or [BossArchetype.gauntIronTide] has no
  /// catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 1.0,
  }) {
    final int bossIndex =
        content.bosses.indexOfArchetype(BossArchetype.gauntIronTide);
    if (bossIndex < 0) return -1;

    final EntityId id = store.spawn(EntityKind.enemy);
    if (id.isNone) return -1;
    final int slot = id.index;

    store.posX[slot] = centerX;
    store.posY[slot] = centerY;
    store.radius[slot] = radius;
    store.health[slot] = health;
    store.maxHealth[slot] = health;
    store.contentIndex[slot] = -1;
    events.emit(SimEventType.entitySpawned, entityA: slot, x: centerX, y: centerY);

    enemies.reset(slot);
    enemies.bossIndex[slot] = bossIndex;

    // Sized to the boss's own max health so frontal attrition alone can
    // never wear the plate down early — a frontal kill and a "broken
    // plate" kill would then always cost the exact same total damage,
    // which is what keeps the shield from ever needing to actually break
    // as its own separate event (unlike Cinder Choir's own plate — see
    // ADR 0023).
    enemies.plateHealth[slot] = health;
    enemies.plateHalfArc[slot] = _plateHalfArc;
    enemies.plateFlatFactor[slot] = _frontalFactor;

    return slot;
  }

  /// Turns Gaunt's shield to track the player (capped at the current
  /// phase's own rotation rate), advances it toward them, and — once P2
  /// begins — slams on a cooldown.
  static void update(AiContext ctx) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final ContentLibrary content = ctx.content;
    final double dt = ctx.dt;

    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.gauntIronTide) {
        continue;
      }

      // P3: the shield is gone for good (see the class doc comment) — a
      // one-time drop is enough, not a per-tick assignment, but writing
      // it every tick costs nothing and needs no separate one-time latch.
      if (enemies.bossPhase[i] >= 2) {
        enemies.plateHealth[i] = 0;
        _tickP3Combo(ctx, i, dt);
        continue;
      }
      if (!ctx.hasPlayer) continue;

      final bool inP2 = enemies.bossPhase[i] >= 1;
      Steering.faceToward(
        ctx,
        i,
        ctx.playerX,
        ctx.playerY,
        inP2 ? _p2RotationDegreesPerSecond : _p1RotationDegreesPerSecond,
      );

      if (inP2) {
        _tickP2Slam(ctx, i, dt);
      } else {
        Steering.moveToward(ctx, i, ctx.playerX, ctx.playerY, _p1Speed);
      }
    }
  }

  /// The shockwave cycle: advance between slams, plant its feet and wind
  /// up on a plain cooldown (not range-gated — see the class doc comment),
  /// resolve into a lethal circle at the card's own stated radius.
  static void _tickP2Slam(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (enemies.stateOf(primary) == AiState.windUp) {
      Steering.halt(ctx, primary);
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;
      _resolveShockwave(ctx, primary);
      enemies.state[primary] = AiState.idle.index;
      enemies.attackCooldown[primary] = _p2SlamCooldownSeconds;
      return;
    }

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      Steering.moveToward(ctx, primary, ctx.playerX, ctx.playerY, _p1Speed);
      return;
    }

    Steering.halt(ctx, primary);
    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = _p2SlamWindUpSeconds;
    EnemyAttack.beginCircle(
      ctx,
      primary,
      store.posX[primary],
      store.posY[primary],
      _p2SlamRadius,
      _p2SlamWindUpSeconds,
    );
  }

  static void _resolveShockwave(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final double x = store.posX[primary];
    final double y = store.posY[primary];

    EnemyAttack.beginCircle(
      ctx,
      primary,
      x,
      y,
      _p2SlamRadius,
      0,
      severity: TelegraphSeverity.lethal,
    );
    if (EnemyAttack.playerInCircle(ctx, x, y, _p2SlamRadius)) {
      EnemyAttack.damagePlayer(ctx, _p2SlamDamage, source: primary);
    }
  }

  /// `RushTree._ripper`'s own three-hit combo, reimplemented directly
  /// against `Steering`/`EnemyAttack` rather than called into (Gaunt has
  /// no `EnemyDefinition` to run that private tree method with) — see the
  /// class doc comment for which numbers are reused verbatim and which
  /// are scaled up for a boss-sized body.
  static void _tickP3Combo(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int step = enemies.comboStep[primary];
    final bool finisher = step >= EnemyTuning.ripperComboLength - 1;

    switch (enemies.stateOf(primary)) {
      case AiState.windUp:
        Steering.halt(ctx, primary);
        if (ctx.hasPlayer) {
          Steering.faceToward(ctx, primary, ctx.playerX, ctx.playerY, 0);
        }

        if (finisher &&
            enemies.damageDuringWindUp[primary] >
                store.maxHealth[primary] * EnemyTuning.ripperStaggerFraction) {
          EnemyAttack.endTelegraph(ctx, primary);
          enemies.state[primary] = AiState.staggered.index;
          enemies.stateTimer[primary] = EnemyTuning.ripperStaggerSeconds;
          enemies.comboStep[primary] = 0;
          enemies.attackCooldown[primary] = _p3AttackCooldownSeconds;
          return;
        }

        enemies.stateTimer[primary] -= dt;
        if (enemies.stateTimer[primary] > 0) return;

        EnemyAttack.endTelegraph(ctx, primary);
        if (EnemyAttack.playerInCone(
          ctx,
          store.posX[primary],
          store.posY[primary],
          store.facing[primary],
          Steering.toRadians(EnemyTuning.ripperSwingArcDegrees / 2),
          _p3AttackRange,
        )) {
          EnemyAttack.damagePlayer(
            ctx,
            finisher
                ? _p3AttackDamage
                : _p3AttackDamage * EnemyTuning.ripperOpenerFraction,
            source: primary,
          );
        }

        if (finisher) {
          enemies.comboStep[primary] = 0;
          enemies.state[primary] = AiState.recover.index;
          enemies.stateTimer[primary] = _p3RecoverySeconds;
          enemies.attackCooldown[primary] = _p3AttackCooldownSeconds;
        } else {
          enemies.comboStep[primary] = step + 1;
          _beginP3Swing(ctx, primary);
        }

      case AiState.staggered:
      case AiState.recover:
        Steering.halt(ctx, primary);
        enemies.stateTimer[primary] -= dt;
        if (enemies.stateTimer[primary] <= 0) {
          enemies.state[primary] = AiState.seek.index;
        }

      default:
        if (!ctx.hasPlayer) {
          Steering.halt(ctx, primary);
          return;
        }
        enemies.state[primary] = AiState.seek.index;
        enemies.comboStep[primary] = 0;
        Steering.faceToward(ctx, primary, ctx.playerX, ctx.playerY, 0);
        Steering.moveToward(ctx, primary, ctx.playerX, ctx.playerY, _p3Speed);

        if (enemies.attackCooldown[primary] <= 0 &&
            ctx.distanceSquaredToPlayer(primary) <=
                _p3AttackRange * _p3AttackRange) {
          _beginP3Swing(ctx, primary);
        }
    }
  }

  static void _beginP3Swing(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final bool finisher =
        enemies.comboStep[primary] >= EnemyTuning.ripperComboLength - 1;
    final double lead = finisher ? _p3HeavyWindUpSeconds : _p3WindUpSeconds;

    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = lead;
    enemies.damageDuringWindUp[primary] = 0;

    EnemyAttack.beginCone(
      ctx,
      primary,
      store.posX[primary],
      store.posY[primary],
      store.facing[primary],
      Steering.toRadians(EnemyTuning.ripperSwingArcDegrees / 2),
      _p3AttackRange,
      lead,
      // The overhead third swing is unmistakable, and it says so in
      // colour: the openers warn, the finisher promises — the same rule
      // the ordinary Ripper's own combo already follows.
      severity: finisher ? TelegraphSeverity.lethal : TelegraphSeverity.warning,
    );
    Steering.halt(ctx, primary);
  }
}
