import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// Vermillion, the Long Burn — docs/06 §5, chapter 5's boss. "Tests: Ember,
/// and sustained-damage thinking."
///
/// **P1 only, built here.** "Leaves a persistent burning trail; arena floor
/// progressively becomes lethal." A single, undamaging-to-touch body (no
/// plate, no contact attack — docs/06 names none for P1) that simply walks
/// toward the player, dropping a lethal ground puddle behind it as it goes,
/// the way a Windline segment is laid every fixed distance travelled
/// (`SimWorld`'s own trail emission) rather than on a fixed clock.
///
/// Needed no new sim primitive: `EnemyAttack.dropPuddle` (already used by
/// every shell that leaves a lingering hazard behind it, docs/05 §5.4) is
/// exactly "place a lethal circle that fades after a while" — Vermillion's
/// own trail is that call, repeated. The floor "progressively becoming
/// lethal" is simply many of these accumulating as it walks; nothing new
/// had to be built to make ground stay dangerous once placed.
///
/// **Not built here: P2 (a bigger ignite aura, charging along amber lines)
/// and P3 (detonating the whole accumulated trail in sequence; Frost arrows
/// extinguishing a segment).** Both are real, separate mechanics — P3
/// especially needs to *track* which hazards are this boss's own trail to
/// sequence them, and "extinguish" needs hazards to know their own element,
/// which nothing in `HazardStore` carries yet. Once `bossPhase` reaches 1
/// this system stops moving and stops laying trail — a known, flagged gap,
/// the same posture every other boss's own undone phases already take.
abstract final class VermillionSystem {
  /// Reused from Husk (docs/05), the same "no stated speed, borrow the base
  /// Carapace archetype's own" choice ADR 0023 already made for Gaunt.
  static const double _p1Speed = 1.0;

  /// Authored — docs/06 gives no cadence for the trail. Long enough that a
  /// walking boss lays a readable, connected line rather than an unbroken
  /// smear. See ADR 0025.
  static const double _trailIntervalSeconds = 1.0;

  /// Authored — no stated puddle size.
  static const double _trailRadius = 1.0;

  /// Reused, not invented: `ElementTuning.burnPerSecond` (4%/s) is the
  /// game's own existing Ember DoT rate — "Tests: Ember" is the card's own
  /// stated lesson, so the trail's own damage is anchored to the element it
  /// is thematically already.
  static const double _trailDamagePerSecond = ElementTuning.burnPerSecond;

  /// Authored — long enough that a segment laid early in P1 is still alive
  /// by the time P3 would detonate it (not built yet), short enough that a
  /// full ~65s fight's worth of trail stays comfortably under
  /// `HazardStore`'s own 96-slot capacity (at one segment/second, this
  /// bounds roughly 20 concurrent segments, not 65).
  static const double _trailLifetimeSeconds = 20.0;

  /// Places Vermillion's single body. Returns its slot, or -1 if the entity
  /// pool was full or [BossArchetype.vermillion] has no catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 0.8,
  }) {
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.vermillion);
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
    // Counts down to the next trail drop — `bossTimer`'s own established
    // "generic countdown a boss's own system owns" role.
    enemies.bossTimer[slot] = _trailIntervalSeconds;

    return slot;
  }

  /// Walks toward the player and lays a lethal puddle behind it on a fixed
  /// cadence.
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.vermillion) {
        continue;
      }

      // P2/P3 not built yet (see the class doc comment) — halted rather
      // than left carrying stale velocity into a wall, the same fix ADR
      // 0023 made for Gaunt.
      if (enemies.bossPhase[i] >= 1) {
        Steering.halt(ctx, i);
        continue;
      }

      if (ctx.hasPlayer) {
        Steering.moveToward(ctx, i, ctx.playerX, ctx.playerY, _p1Speed);
      }

      enemies.bossTimer[i] -= dt;
      if (enemies.bossTimer[i] > 0) continue;
      enemies.bossTimer[i] += _trailIntervalSeconds;

      EnemyAttack.dropPuddle(
        ctx,
        i,
        x: store.posX[i],
        y: store.posY[i],
        radius: _trailRadius,
        damagePerSecond: _trailDamagePerSecond,
        seconds: _trailLifetimeSeconds,
      );
    }
  }
}
