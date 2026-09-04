import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// Skarn the Unmade — docs/06 §11, chapter 11's boss. "Tests: split
/// attention."
///
/// **P1:** a single body — nothing bespoke here yet; its own "enormous
/// telegraphs" are not built (see the class-level gap note below), so it is
/// a plain, undamaging shared-pool source until the split begins.
///
/// **P2/P3:** "Splits into two halves [then four] at 66%[/33%], sharing one
/// HP pool. Damaging only one causes the other to heal it at 3%/s." Reuses
/// Cinder Choir's own shared-pool primitives (`EnemyStore.linkedHealthSlot`/
/// `bossParent`) unmodified — the genuinely new piece is the *pressure*
/// mechanic: each body tracks its own `bossLastHitAgo`, and any body that
/// has gone too long unhit heals the shared pool on its own, independent of
/// the others. See ADR 0022.
///
/// **Not built here: P1's own attack.** "Slow, enormous telegraphs" needs a
/// real wind-up-then-slam, and nothing about the split/pressure mechanic —
/// this boss's own doc-emphasised centrepiece ("Tests: split attention")
/// — depends on it existing first. A known, flagged gap, the same posture
/// Cinder Choir's own P3 attacks got before they were built.
abstract final class SkarnSystem {
  /// The full 4-body ring every split slots into, even while only 1 or 2 of
  /// its positions are occupied — see [_spawnBody]'s own doc comment for why
  /// nothing ever needs to move once placed.
  static const int _maxBodyCount = 4;

  /// Authored, not a GDD number — no boss arena exists yet (ADR 0017). Small
  /// enough that all four positions stay inside a default 16x9 arena from a
  /// roughly central spawn.
  static const double _bodyRingRadius = 1.8;

  /// docs/06 §11's own stated rate.
  static const double _neglectHealPerSecond = 0.03;

  /// How long a body may go unhit before it starts healing. Not stated by
  /// docs/06 — "Tests: split attention" reads as a short window, so this is
  /// authored deliberately tight rather than borrowed from an unrelated
  /// anchor. See ADR 0022.
  static const double _neglectThresholdSeconds = 1.0;

  /// Places Skarn's single, directly-hittable P1 body — unlike Cinder
  /// Choir's own invisible anchor, this entity *is* the fight for the whole
  /// of P1, so it holds its own real health and is fully targetable.
  /// Returns its slot, or -1 if the entity pool was full or
  /// [BossArchetype.skarnUnmade] has no catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 0.9,
  }) {
    final int bossIndex =
        content.bosses.indexOfArchetype(BossArchetype.skarnUnmade);
    if (bossIndex < 0) return -1;

    final EntityId id = store.spawn(EntityKind.enemy);
    if (id.isNone) return -1;
    final int primary = id.index;

    store.posX[primary] = centerX;
    store.posY[primary] = centerY;
    store.radius[primary] = radius;
    store.health[primary] = health;
    store.maxHealth[primary] = health;
    store.contentIndex[primary] = -1;
    events.emit(SimEventType.entitySpawned, entityA: primary, x: centerX, y: centerY);

    enemies.reset(primary);
    enemies.bossIndex[primary] = bossIndex;
    // Its own ring slot too, so `_ensureBodyCount`'s occupancy scan can
    // treat the primary the same as any split-off body.
    enemies.bossChildIndex[primary] = 0;

    return primary;
  }

  /// Advances every live Skarn: keeps its body count matching its phase, and
  /// ticks the pressure/neglect-heal mechanic once splitting has begun.
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.skarnUnmade) {
        continue;
      }

      // Every split body stays health-linked its whole life (unlike Cinder
      // Choir's P3), so only the primary's own health can ever reach zero —
      // when it does, any child still standing is cleaned up here, quietly.
      if (store.health[i] <= 0) {
        _despawnChildren(ctx, i);
        continue;
      }

      final int phase = enemies.bossPhase[i];
      final int targetCount = switch (phase) {
        0 => 1,
        1 => 2,
        _ => _maxBodyCount,
      };
      _ensureBodyCount(ctx, i, targetCount);

      // P1 is a lone, undamaging body — "damaging only one causes the
      // other to heal it" has no meaning with nothing else to neglect.
      if (phase >= 1) _tickPressure(ctx, i, dt);
    }
  }

  static void _ensureBodyCount(AiContext ctx, int primary, int targetCount) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final List<bool> present = List<bool>.filled(_maxBodyCount, false);
    present[enemies.bossChildIndex[primary]] = true;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      present[enemies.bossChildIndex[j]] = true;
    }

    int have = 0;
    for (final bool p in present) {
      if (p) have++;
    }
    if (have >= targetCount) return;

    // The two-body split (P2) uses the primary's own slot (0) plus its
    // *opposite* ring position (2) — a symmetric pair rather than two
    // adjacent quarters. The four-body split (P3) fills the remaining two
    // (1, 3), completing an evenly-spaced ring nothing has to reposition.
    const List<int> spawnOrder = <int>[2, 1, 3];
    for (final int slot in spawnOrder) {
      if (have >= targetCount) break;
      if (present[slot]) continue;
      _spawnBody(ctx, primary, slot);
      have++;
    }
  }

  /// Places one linked body at its own fixed ring slot. A slot's angle only
  /// depends on its own index within the full 4-body ring, never on how
  /// many bodies currently exist — so a body spawned at P2 sits exactly
  /// where P3 will still expect it, and nothing already on the field ever
  /// needs to move when the count changes.
  static void _spawnBody(AiContext ctx, int primary, int childIndex) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final double angle =
        -math.pi / 2 + childIndex * (2 * math.pi / _maxBodyCount);
    final double x = store.posX[primary] + _bodyRingRadius * math.cos(angle);
    final double y = store.posY[primary] + _bodyRingRadius * math.sin(angle);

    final EntityId id = store.spawn(EntityKind.enemy);
    if (id.isNone) return;
    final int slot = id.index;

    store.posX[slot] = x;
    store.posY[slot] = y;
    store.radius[slot] = store.radius[primary];
    // Never read for damage (see `linkedHealthSlot`'s own doc comment) — a
    // positive value only keeps it out of an "already dead" fast path.
    store.health[slot] = store.maxHealth[primary];
    store.maxHealth[slot] = store.maxHealth[primary];
    store.contentIndex[slot] = -1;
    ctx.events.emit(SimEventType.entitySpawned, entityA: slot, x: x, y: y);

    enemies.reset(slot);
    enemies.linkedHealthSlot[slot] = primary;
    enemies.bossParent[slot] = primary;
    enemies.bossChildIndex[slot] = childIndex;
  }

  /// Every currently-hittable body — the primary plus whichever children
  /// exist — heals the shared pool on its own once it has gone
  /// [_neglectThresholdSeconds] without taking a hit. Bodies heal
  /// independently: ignore two out of two and both contribute their own
  /// 3%/s, exactly the "both must be pressured" reading of docs/06 §11.
  static void _tickPressure(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final double maxHealth = store.maxHealth[primary];

    double healed = 0;
    void tick(int slot) {
      enemies.bossLastHitAgo[slot] += dt;
      if (enemies.bossLastHitAgo[slot] <= _neglectThresholdSeconds) return;
      healed += _neglectHealPerSecond * maxHealth * dt;
    }

    tick(primary);
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      tick(j);
    }

    if (healed <= 0) return;
    final double next = store.health[primary] + healed;
    store.health[primary] = next > maxHealth ? maxHealth : next;
  }

  static void _despawnChildren(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
      store.despawn(store.idAt(j));
    }
  }
}
