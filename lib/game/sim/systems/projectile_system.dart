import 'dart:math' as math;

import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/projectile_store.dart';
import 'package:quiverfall/game/sim/segment_hash.dart';
import 'package:quiverfall/game/sim/spatial_hash.dart';
import 'package:quiverfall/game/sim/status_store.dart';
import 'package:quiverfall/game/sim/systems/confluence_system.dart';
import 'package:quiverfall/game/sim/windline_store.dart';

/// Moves arrows, resolves what they hit, and applies damage.
///
/// **Swept collision, not point sampling.** An arrow at 14 u/s covers 0.23 u per
/// tick; a 0.22 u Mote is smaller than that, so testing only the arrow's end
/// position would let arrows pass through small enemies at certain relative
/// speeds. That is the classic intermittent "my shot didn't register" bug, and
/// it is unacceptable in a game whose core loop is shooting things.
abstract final class ProjectileSystem {
  static void update({
    required EntityStore store,
    required ProjectileStore projectiles,
    required SpatialHash spatial,
    required Arena arena,
    required SimEventBuffer events,
    required WindlineStore lines,
    required SegmentHash lineIndex,
    required double now,
    required int maxConfluenceStacks,
    required double windlineHitWidth,
    required double windlineDuration,
    required double segmentLength,
    required double dt,
    EnemyStore? enemies,
    StatusStore? status,
  }) {
    final int high = store.highWater;

    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.projectile.index) continue;

      projectiles.lifetime[i] -= dt;
      if (projectiles.lifetime[i] <= 0) {
        _retire(store, projectiles, lines, i, store.posX[i], store.posY[i], now,
            windlineDuration);
        continue;
      }

      final double fromX = store.posX[i];
      final double fromY = store.posY[i];
      final double toX = fromX + store.velX[i] * dt;
      final double toY = fromY + store.velY[i] * dt;

      // Walls stop arrows outright. Cover blocks projectiles but not movement,
      // which is what makes "break line of sight" a real answer to Longeye.
      if (arena.circleHitsWall(toX, toY, store.radius[i]) ||
          !arena.containsPoint(toX, toY)) {
        _retire(
            store, projectiles, lines, i, fromX, fromY, now, windlineDuration);
        continue;
      }

      // Confluence is resolved on the swept path *before* hits, so an arrow
      // that threads a line and strikes an enemy in the same tick carries the
      // bonus into that hit rather than the one after.
      _resolveConfluence(
        projectiles: projectiles,
        lines: lines,
        lineIndex: lineIndex,
        events: events,
        slot: i,
        fromX: fromX,
        fromY: fromY,
        toX: toX,
        toY: toY,
        maxStacks: maxConfluenceStacks,
        hitWidth: windlineHitWidth,
      );

      final bool consumed = _resolveHits(
        store: store,
        projectiles: projectiles,
        spatial: spatial,
        events: events,
        enemies: enemies,
        status: status,
        lines: lines,
        now: now,
        windlineDuration: windlineDuration,
        slot: i,
        fromX: fromX,
        fromY: fromY,
        toX: toX,
        toY: toY,
      );

      if (consumed) continue;

      // Lay the trail behind the arrow, one segment per
      // [SimConfig.windlineSegmentLength] flown rather than one per tick. The
      // segment spans the whole accumulated stretch, so the polyline is
      // continuous — it is emitted less often, not made of gaps.
      final double stepX = toX - fromX;
      final double stepY = toY - fromY;
      final double step = _length(stepX, stepY);
      projectiles.sinceLastSegment[i] += step;

      if (projectiles.sinceLastSegment[i] >= segmentLength) {
        final double back = projectiles.sinceLastSegment[i];
        final double dirX = store.velX[i];
        final double dirY = store.velY[i];
        final double dirLen = _length(dirX, dirY);
        final double ux = dirLen > 0 ? dirX / dirLen : 0;
        final double uy = dirLen > 0 ? dirY / dirLen : 0;

        lines.add(
          fromX: toX - ux * back,
          fromY: toY - uy * back,
          toX: toX,
          toY: toY,
          expiresAt: now + windlineDuration,
          ownerIndex: _playerOwner,
          trailId: projectiles.trailId[i],
          elementIndex: projectiles.element[i],
        );
        projectiles.sinceLastSegment[i] = 0;
      }

      store.posX[i] = toX;
      store.posY[i] = toY;
    }
  }

  static void _resolveConfluence({
    required ProjectileStore projectiles,
    required WindlineStore lines,
    required SegmentHash lineIndex,
    required SimEventBuffer events,
    required int slot,
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    required int maxStacks,
    required double hitWidth,
  }) {
    if (projectiles.confluenceStacks[slot] >= maxStacks) return;

    final ConfluenceResult found = ConfluenceSystem.sweep(
      lines: lines,
      fromX: fromX,
      fromY: fromY,
      toX: toX,
      toY: toY,
      arrowSerial: projectiles.windlineSerial[slot],
      ownerIndex: _playerOwner,
      hitWidth: hitWidth,
      maxStacks: maxStacks - projectiles.confluenceStacks[slot],
      alreadyCrossed: projectiles.crossedRaw,
      crossedBase: projectiles.crossedBase(slot),
      crossedCount: projectiles.crossedCount[slot],
      index: lineIndex,
    );

    if (found.stacks == 0) return;

    for (int k = 0; k < found.crossedSerials.length; k++) {
      projectiles.recordCrossing(slot, found.crossedSerials[k]);
    }
    for (int k = 0; k < found.elements.length; k++) {
      projectiles.confluenceElementMask[slot] |= 1 << found.elements[k];
    }

    int stacks = projectiles.confluenceStacks[slot] + found.stacks;
    if (stacks > maxStacks) stacks = maxStacks;
    projectiles.confluenceStacks[slot] = stacks;
    projectiles.confluenceBonus[slot] = ConfluenceTuning.bonusFor(stacks);

    events.emit(
      SimEventType.confluenceTriggered,
      entityA: slot,
      valueA: stacks.toDouble(),
      valueB: projectiles.confluenceBonus[slot],
      x: toX,
      y: toY,
    );
  }

  static double _length(double x, double y) {
    final double sq = x * x + y * y;
    if (sq == 0) return 0;
    // Newton's method; avoids a dart:math import in the hottest loop and keeps
    // the result bit-identical across platforms for determinism.
    double g = sq > 1 ? sq : 1.0;
    for (int i = 0; i < 20; i++) {
      g = 0.5 * (g + sq / g);
    }
    return g;
  }

  /// The player is the only Confluence-eligible owner for now. Phase 11 gives
  /// the Hollow Warden its own owner id so its trails interact through the
  /// separate Discord rule rather than buffing the player.
  static const int _playerOwner = 0;

  /// Tests the swept segment against nearby enemies. Returns true if the arrow
  /// was consumed.
  static bool _resolveHits({
    required EntityStore store,
    required ProjectileStore projectiles,
    required SpatialHash spatial,
    required SimEventBuffer events,
    required EnemyStore? enemies,
    required StatusStore? status,
    required WindlineStore lines,
    required double now,
    required double windlineDuration,
    required int slot,
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
  }) {
    final double arrowRadius = store.radius[slot];
    final int candidates =
        spatial.querySegment(fromX, fromY, toX, toY, arrowRadius + 1.0);

    for (int c = 0; c < candidates; c++) {
      final int target = spatial.resultAt(c);
      if (store.alive[target] == 0) continue;
      if (store.kind[target] != EntityKind.enemy.index) continue;

      final int targetId = store.idAt(target).raw;
      if (projectiles.hasHit(slot, targetId)) continue;

      final double combined = arrowRadius + store.radius[target];
      if (!_segmentHitsCircle(
        fromX,
        fromY,
        toX,
        toY,
        store.posX[target],
        store.posY[target],
        combined,
      )) {
        continue;
      }

      _applyHit(
        store: store,
        projectiles: projectiles,
        events: events,
        enemies: enemies,
        status: status,
        slot: slot,
        target: target,
        targetId: targetId,
        fromX: fromX,
        fromY: fromY,
      );

      if (projectiles.pierceRemaining[slot] < 0) {
        // The stub runs to the swept end rather than to the arrow's last
        // committed position, so a trail that ends in an enemy actually reaches
        // that enemy.
        _retire(
            store, projectiles, lines, slot, toX, toY, now, windlineDuration);
        return true;
      }
    }
    return false;
  }

  static void _applyHit({
    required EntityStore store,
    required ProjectileStore projectiles,
    required SimEventBuffer events,
    required EnemyStore? enemies,
    required StatusStore? status,
    required int slot,
    required int target,
    required int targetId,
    required double fromX,
    required double fromY,
  }) {
    final int pierceIndex = projectiles.hitCount[slot];
    projectiles.recordHit(slot, targetId);

    final DrawTier tier = DrawTier.values[projectiles.drawTier[slot]];

    // Armour is resolved here, not at fire time: the arrow carries the tier it
    // was fired at, and the plate state is read from the target now.
    final double armour =
        _armourFor(store, enemies, target, tier, fromX, fromY);

    final double damage = DamageResolver.resolve(
      attack: projectiles.damage[slot],
      arrowBaseMultiplier: 1.0,
      drawTierMultiplier: tier.damageMultiplier,
      confluenceBonus: projectiles.confluenceBonus[slot],
      elementalBonus: projectiles.elementalBonus[slot],
      pierceIndex: pierceIndex,
      armourFactor: armour,
    );

    double toHealth = damage;
    if (enemies != null) {
      // Shield, then plate, then health. The order is the fiction: a Weaver's
      // barrier sits outside the armour, and the armour sits outside the body.
      toHealth = enemies.absorb(target, toHealth);
      enemies.wearPlate(target, toHealth);
      // Damage taken during a wind-up is what a Ripper's stagger is measured
      // against — the game's parry, counted here because this is where damage
      // is known.
      enemies.damageDuringWindUp[target] += toHealth;
    }

    store.health[target] -= toHealth;
    projectiles.pierceRemaining[slot]--;

    _applyElement(
      projectiles: projectiles,
      enemies: enemies,
      status: status,
      events: events,
      slot: slot,
      target: target,
      x: store.posX[target],
      y: store.posY[target],
    );

    events.emit(
      SimEventType.damageDealt,
      entityA: target,
      entityB: slot,
      valueA: toHealth,
      valueB: armour,
      x: store.posX[target],
      y: store.posY[target],
    );

    // Death is **not** resolved here. [AiSystem]'s death pass owns it, because a
    // death can mean a detonation, a revival or a split, and those must not
    // depend on which system happened to land the killing tick. Without an
    // enemy store there is no such enemy, so the corpse is reaped immediately.
    if (store.health[target] <= 0 && enemies == null) {
      events.emit(
        SimEventType.entityDied,
        entityA: target,
        x: store.posX[target],
        y: store.posY[target],
      );
      store.despawn(store.idAt(target));
    }
  }

  /// Applies the arrow's element, and lets adapting enemies adapt.
  ///
  /// Two things can refuse the application: a Warden-Fell aura, which
  /// suppresses elemental procs inside its radius, and an existing immunity —
  /// the Null's adaptation, or a Voidtouched variant's permanent resistance.
  /// **Neither blocks Confluence**, which is what makes element rotation and
  /// reaction merging the intended answers rather than a soft counter.
  static void _applyElement({
    required ProjectileStore projectiles,
    required EnemyStore? enemies,
    required StatusStore? status,
    required SimEventBuffer events,
    required int slot,
    required int target,
    required double x,
    required double y,
  }) {
    if (status == null) return;
    final int index = projectiles.element[slot];
    if (index < 0) return;

    final SimElement element = SimElement.values[index];
    if (enemies != null && enemies.resistsElement(target, element)) return;

    status.apply(target, element);
    events.emit(
      SimEventType.elementApplied,
      entityA: target,
      entityB: slot,
      valueA: index.toDouble(),
      x: x,
      y: y,
    );

    if (enemies != null && enemies.adaptSeconds[target] > 0) {
      enemies.adaptTo(target, element, enemies.adaptSeconds[target]);
    }
  }

  /// Frontal-plate resolution.
  ///
  /// A Tier-I arrow into a live plate deals 10 % and produces a metallic clang
  /// with no damage number; Tier II gets 55 % through; Tier III breaks it
  /// outright. **A hit from behind the plate's arc takes full damage at any
  /// tier**, which is what makes flanking a real alternative to the Draw rather
  /// than a consolation (docs/05 §5.2).
  static double _armourFor(
    EntityStore store,
    EnemyStore? enemies,
    int target,
    DrawTier tier,
    double fromX,
    double fromY,
  ) {
    if (enemies == null || !enemies.isPlated(target)) return ArmourFactor.none;

    final double toShooter = math.atan2(
      fromY - store.posY[target],
      fromX - store.posX[target],
    );
    final double offset =
        _shortestAngleDelta(store.facing[target], toShooter).abs();
    if (offset > enemies.plateHalfArc[target]) return ArmourFactor.none;

    return switch (tier) {
      DrawTier.one => ArmourFactor.plateBlocked,
      DrawTier.two => ArmourFactor.platePartial,
      DrawTier.three => ArmourFactor.none,
    };
  }

  static double _shortestAngleDelta(double from, double to) {
    double delta = (to - from) % (2 * math.pi);
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta <= -math.pi) delta += 2 * math.pi;
    return delta;
  }

  /// Ends an arrow's life, laying the last stretch of its trail first.
  ///
  /// **This is the fix for ADR 0002.** Windline segments are emitted per
  /// 0.9 u flown, so the final 0–0.9 u of every trail — the stretch nearest
  /// whatever the arrow hit — was never emitted at all. That gap sits exactly
  /// where converging fire meets, which is why the measured natural Confluence
  /// rate was 0 %: every trail stopped short of the one place trails cross.
  ///
  /// A trail is the path an arrow flew. Rounding it down to the last whole
  /// segment was an artefact of distance-based emission, not a decision.
  static void _retire(
    EntityStore store,
    ProjectileStore projectiles,
    WindlineStore lines,
    int slot,
    double endX,
    double endY,
    double now,
    double windlineDuration,
  ) {
    _layFinalSegment(
      store,
      projectiles,
      lines,
      slot,
      endX,
      endY,
      now,
      windlineDuration,
    );
    projectiles.reset(slot);
    store.despawn(store.idAt(slot));
  }

  static void _layFinalSegment(
    EntityStore store,
    ProjectileStore projectiles,
    WindlineStore lines,
    int slot,
    double endX,
    double endY,
    double now,
    double windlineDuration,
  ) {
    final double back = projectiles.sinceLastSegment[slot];
    if (back <= 0) return;

    final double dirX = store.velX[slot];
    final double dirY = store.velY[slot];
    final double len = _length(dirX, dirY);
    if (len <= 0) return;

    // WindlineStore rejects degenerate segments, so a stub shorter than the
    // minimum length is dropped there rather than guarded here.
    lines.add(
      fromX: endX - dirX / len * back,
      fromY: endY - dirY / len * back,
      toX: endX,
      toY: endY,
      expiresAt: now + windlineDuration,
      ownerIndex: _playerOwner,
      trailId: projectiles.trailId[slot],
      elementIndex: projectiles.element[slot],
    );
  }

  /// Closest-approach test between a swept segment and a circle.
  ///
  /// Projects the circle's centre onto the segment, clamps to the segment's
  /// extent, and compares the perpendicular distance. Exact, branch-light, and
  /// allocation-free.
  static bool _segmentHitsCircle(
    double x0,
    double y0,
    double x1,
    double y1,
    double cx,
    double cy,
    double radius,
  ) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double lengthSq = dx * dx + dy * dy;

    double t;
    if (lengthSq <= 1e-12) {
      t = 0;
    } else {
      t = ((cx - x0) * dx + (cy - y0) * dy) / lengthSq;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
    }

    final double nearestX = x0 + dx * t;
    final double nearestY = y0 + dy * t;
    final double gapX = cx - nearestX;
    final double gapY = cy - nearestY;

    return gapX * gapX + gapY * gapY <= radius * radius;
  }
}
