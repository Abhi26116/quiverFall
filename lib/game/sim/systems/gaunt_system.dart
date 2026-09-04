import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// Gaunt, the Iron Tide — docs/06 §2, chapter 2's boss. "Tests: flanking."
///
/// **P1 only, built here.** "A colossal shield-bearer. Frontal 180° arc
/// takes 5% damage... Slow advance, shield always facing the player.
/// Rotates 70°/s — beatable by circling." A single body the whole fight
/// (no split, unlike Cinder Choir/Skarn) — the entire lesson is positional:
/// the shield tracks the player at a *capped* turn rate
/// (`Steering.faceToward`, the same primitive Husk's own family tree
/// already turns with), so a player who strafes faster than 70°/s walks
/// around behind it while the front stays locked on where they used to be.
///
/// The frontal arc reuses the *existing* plate system (`plateHalfArc`,
/// `_armourFor`'s arc check) but not its Tier-scaled reduction — docs/06 §2
/// states a flat 5%, without Cinder Choir's own "Tier III breaks it"
/// caveat, so `EnemyStore.plateFlatFactor` (new) overrides the usual
/// 10/55/100% switch. See ADR 0023.
///
/// **Not built here: P2 (the shockwave slam, faster rotation) and P3
/// (dropping the shield for +80% speed and a 3-hit combo).** Once
/// `bossPhase` reaches 1 this system stops moving and turning the boss
/// entirely — a known, flagged gap, not a silent one; docs/06's own
/// "Tests: flanking" lesson lives entirely in P1, so this is a real,
/// standalone slice rather than a fragment of a larger one.
abstract final class GauntSystem {
  /// docs/06 §2 P1's own stated rotation rate.
  static const double _p1RotationDegreesPerSecond = 70.0;

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

  /// Turns Gaunt's shield to track the player (capped at P1's own rotation
  /// rate) and advances it slowly toward them.
  static void update(AiContext ctx) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final ContentLibrary content = ctx.content;

    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.gauntIronTide) {
        continue;
      }

      // P2/P3 not built yet (see the class doc comment) — frozen exactly
      // where `BossPhaseSystem` leaves it once past P1, rather than
      // continuing to move and turn at P1's own (now stale) numbers. Halted
      // explicitly rather than merely skipped: `MovementSystem` still
      // integrates whatever velocity `moveToward` last set, so a P1→P2
      // transition mid-stride would otherwise leave it sliding in a
      // straight line — into a wall, and stuck there — for the rest of the
      // fight.
      if (enemies.bossPhase[i] >= 1) {
        Steering.halt(ctx, i);
        continue;
      }
      if (!ctx.hasPlayer) continue;

      Steering.faceToward(
        ctx,
        i,
        ctx.playerX,
        ctx.playerY,
        _p1RotationDegreesPerSecond,
      );
      Steering.moveToward(ctx, i, ctx.playerX, ctx.playerY, _p1Speed);
    }
  }
}
