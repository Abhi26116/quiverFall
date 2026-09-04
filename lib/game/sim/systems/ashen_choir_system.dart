import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// The Ashen Choir — docs/06 §13, "Elite remix of #1." "×48 HP · 70s. All
/// three effigies lit permanently; tethers are lethal from the start; a
/// fourth invisible effigy exists, revealed only by Windline contact."
///
/// **Built as a remix of `CinderChoirSystem` (ADR 0018/0019), reusing its
/// exact shared-pool wiring and tether-sweep primitive — the differences
/// are all subtractive or additive, never a new attack shape.** "All three
/// effigies lit permanently" removes the rotation entirely: every plate is
/// zero from spawn and never set again, so this system contains no
/// rotation timer at all, unlike the original. "Tethers are lethal from
/// the start" removes the original's own 0.6s amber warning — every
/// telegraph here begins `TelegraphSeverity.lethal`.
///
/// **The fourth invisible effigy is the one genuinely new mechanic**: a
/// child that starts near-zero radius, `untargetable`, and *not*
/// health-linked (so an accidental hit, however unlikely against a
/// pinprick hitbox, does nothing at all — no redirect, no consequence)
/// until a live player Windline segment passes within reach of its own
/// position, at which point it is revealed — a real body, targetable,
/// sharing the pool like the other three. The proximity check reuses
/// `AiSystem._applyWindlineSlow`'s own exact shape (`AiContext.lineIndex.
/// querySegment` + a point-to-segment distance check), reimplemented here
/// since that method is private — the same "the shape, not the private
/// function" posture Hollow Warden's own borrowed mirror-movement already
/// takes.
///
/// **No phase-gated content at all — a real, deliberate difference from
/// every campaign boss.** docs/06 §6.2 describes this fight as one flat,
/// permanent state, not an escalating P1/P2/P3; `bossPhase` still advances
/// generically (`BossPhaseSystem` is "true of every boss regardless of
/// what its fight actually does", for the visual/musical transition cue
/// docs/06 §6.0 promises), but nothing here reads it to freeze or unlock
/// anything — the tether sweep and the reveal check both run continuously
/// for the whole fight.
///
/// **Real-run spawn integration is NOT built.** Every campaign boss had
/// an unambiguous chapter number to hook `BossRoomComposer` into; this
/// Elite remix has none — docs/06 §6.2 states no drop rate, unlock
/// chapter, or trigger condition for when it replaces an ordinary Elite
/// pick (`RoomComposer.compose(isElite: true)`'s own random Riftborn
/// choice), and that composer is a pure, allocation-free `RoomPlan`
/// generator with no notion of a live, multi-entity, bespoke boss spawn to
/// begin with — a materially different integration problem than any
/// `BossRoomComposer` entry has solved so far. See ADR 0033.
abstract final class AshenChoirSystem {
  static const int childCount = 3;

  /// Reused from Cinder Choir's own authored staging (ADR 0018) — no GDD
  /// geometry exists for this fight either.
  static const double _triangleRadius = 2.2;
  static const double _effigyRadius = 0.5;

  /// Reused from Cinder Choir's own P2 tether sweep (ADR 0019) — nothing
  /// about the rate is stated as different here.
  static const double _sweepRadiansPerSecond = 45 * math.pi / 180;
  static const double _tetherLength = 9.0;
  static const double _tetherWidth = SimConfig.windlineHitWidth;
  static const double _tetherDamage = 0.09;
  static const double _tetherCooldown = 0.6;

  /// How close a Windline segment must pass to reveal the fourth effigy.
  /// Authored to match the other three effigies' own visual footprint —
  /// docs/06 states no exact reach.
  static const double _revealReach = _effigyRadius;

  /// Places three permanently-lit effigies (Cinder Choir's own triangle,
  /// no plate ever applied) plus one hidden fourth at the triangle's own
  /// centre — authored, since docs/06 states no position for it. Returns
  /// the primary's slot, or -1 if the entity pool was full or
  /// [BossArchetype.ashenChoir] has no catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
  }) {
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.ashenChoir);
    if (bossIndex < 0) return -1;

    final EntityId primaryId = store.spawn(EntityKind.enemy);
    if (primaryId.isNone) return -1;
    final int primary = primaryId.index;

    // An accounting anchor, not a body — same shape Cinder Choir's own
    // primary already uses (ADR 0018).
    store.posX[primary] = centerX;
    store.posY[primary] = centerY;
    store.radius[primary] = 0.01;
    store.health[primary] = health;
    store.maxHealth[primary] = health;
    store.contentIndex[primary] = -1;
    events.emit(SimEventType.entitySpawned, entityA: primary, x: centerX, y: centerY);

    enemies.reset(primary);
    enemies.bossIndex[primary] = bossIndex;
    enemies.untargetable[primary] = 1;

    for (int child = 0; child < childCount; child++) {
      final double angle = -math.pi / 2 + child * (2 * math.pi / childCount);
      final double x = centerX + _triangleRadius * math.cos(angle);
      final double y = centerY + _triangleRadius * math.sin(angle);

      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      store.posX[slot] = x;
      store.posY[slot] = y;
      store.radius[slot] = _effigyRadius;
      store.health[slot] = health;
      store.maxHealth[slot] = health;
      store.contentIndex[slot] = -1;
      events.emit(SimEventType.entitySpawned, entityA: slot, x: x, y: y);

      enemies.reset(slot);
      enemies.linkedHealthSlot[slot] = primary;
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = child;
      // plateHealth stays 0 (reset()'s own default) — permanently lit.
    }

    // The fourth, hidden effigy — not one of the three tether spokes,
    // outside childCount's own indexing on purpose.
    final EntityId hiddenId = store.spawn(EntityKind.enemy);
    if (!hiddenId.isNone) {
      final int slot = hiddenId.index;
      store.posX[slot] = centerX;
      store.posY[slot] = centerY;
      store.radius[slot] = 0.01;
      store.health[slot] = health;
      store.maxHealth[slot] = health;
      store.contentIndex[slot] = -1;
      events.emit(SimEventType.entitySpawned, entityA: slot, x: centerX, y: centerY);

      enemies.reset(slot);
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = childCount; // 3 — not a tether spoke
      enemies.untargetable[slot] = 1;
      // linkedHealthSlot stays -1 until revealed — see _checkReveal.
    }

    return primary;
  }

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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.ashenChoir) {
        continue;
      }

      if (store.health[i] <= 0) {
        _despawnChildren(ctx, i);
        continue;
      }

      // No phase-gated content — see the class doc comment. Both run for
      // the whole fight, `bossPhase` notwithstanding.
      _tickTetherSweep(ctx, i, dt);
      _checkReveal(ctx, i);
    }
  }

  /// `CinderChoirSystem._tickTetherSweep`, minus the warning window —
  /// every telegraph here is lethal from the tick it begins.
  static void _tickTetherSweep(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    enemies.bossSweepAngle[primary] += _sweepRadiansPerSecond * dt;
    if (enemies.bossSweepAngle[primary] > 2 * math.pi) {
      enemies.bossSweepAngle[primary] -= 2 * math.pi;
    }

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
    }

    final double centerX = ctx.entities.posX[primary];
    final double centerY = ctx.entities.posY[primary];
    bool playerHit = false;

    final int high = ctx.entities.highWater;
    for (int j = 0; j < high; j++) {
      if (ctx.entities.alive[j] == 0) continue;
      if (enemies.linkedHealthSlot[j] != primary) continue;
      // Only the three tether spokes — the hidden fourth, even once
      // revealed, never grows one of its own.
      if (enemies.bossChildIndex[j] >= childCount) continue;

      final double angle = -math.pi / 2 +
          enemies.bossChildIndex[j] * (2 * math.pi / childCount) +
          enemies.bossSweepAngle[primary];
      final double toX = centerX + _tetherLength * math.cos(angle);
      final double toY = centerY + _tetherLength * math.sin(angle);

      if (EnemyAttack.hasTelegraph(ctx, j)) {
        EnemyAttack.retarget(ctx, j, toX, toY);
        EnemyAttack.extendTelegraph(ctx, j, ctx.now + _tetherCooldown);
      } else {
        EnemyAttack.beginLine(
          ctx,
          j,
          centerX,
          centerY,
          toX,
          toY,
          _tetherWidth,
          _tetherCooldown,
          severity: TelegraphSeverity.lethal,
        );
      }

      if (EnemyAttack.playerOnLine(ctx, centerX, centerY, toX, toY, _tetherWidth)) {
        playerHit = true;
      }
    }

    if (playerHit && enemies.attackCooldown[primary] <= 0) {
      EnemyAttack.damagePlayer(ctx, _tetherDamage, source: primary);
      enemies.attackCooldown[primary] = _tetherCooldown;
    }
  }

  /// Reveals the hidden fourth effigy the instant a live Windline segment
  /// passes within [_revealReach] of it — `AiSystem._applyWindlineSlow`'s
  /// own exact broad-phase-then-precise-distance shape, reimplemented
  /// since that method is private.
  ///
  /// Exactly one child ever carries `bossChildIndex == childCount` (the
  /// hidden one — see [spawn]), so the `return` inside this loop exits
  /// only after that one child has actually been checked, never early.
  static void _checkReveal(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;

    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (enemies.bossChildIndex[j] != childCount) continue; // the hidden one
      if (enemies.linkedHealthSlot[j] == primary) return; // already revealed

      if (!_touchedByWindline(ctx, store.posX[j], store.posY[j], _revealReach)) {
        return;
      }

      store.radius[j] = _effigyRadius;
      enemies.untargetable[j] = 0;
      enemies.linkedHealthSlot[j] = primary;
      return;
    }
  }

  static bool _touchedByWindline(AiContext ctx, double x, double y, double reach) {
    if (ctx.lines.liveCount == 0) return false;

    final int found =
        ctx.lineIndex.querySegment(x, y, x, y, reach, ctx.segmentScratch);
    for (int i = 0; i < found; i++) {
      final int seg = ctx.segmentScratch[i];
      if (!ctx.lines.isAlive(seg)) continue;
      if (_pointNearSegment(
        x,
        y,
        ctx.lines.x0(seg),
        ctx.lines.y0(seg),
        ctx.lines.x1(seg),
        ctx.lines.y1(seg),
        reach,
      )) {
        return true;
      }
    }
    return false;
  }

  static bool _pointNearSegment(
    double px,
    double py,
    double x0,
    double y0,
    double x1,
    double y1,
    double reach,
  ) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double lengthSq = dx * dx + dy * dy;

    double t = 0;
    if (lengthSq > 1e-12) {
      t = ((px - x0) * dx + (py - y0) * dy) / lengthSq;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
    }

    final double gapX = px - (x0 + dx * t);
    final double gapY = py - (y0 + dy * t);
    return gapX * gapX + gapY * gapY <= reach * reach;
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
