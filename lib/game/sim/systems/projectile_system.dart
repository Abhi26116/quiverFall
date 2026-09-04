import 'dart:math' as math;

import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/arrow_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_runtime.dart';
import 'package:quiverfall/game/sim/effects/combat_modifiers.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/hero_runtime.dart';
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
    required CombatModifiers combat,
    required BoonRuntime boons,
    required double confluenceDamageMultiplier,
    EnemyStore? enemies,
    StatusStore? status,
    HeroRuntime? hero,
    int player = -1,
    double lifesteal = 0,
  }) {
    final int high = store.highWater;

    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.projectile.index) continue;

      projectiles.lifetime[i] -= dt;
      if (projectiles.lifetime[i] <= 0) {
        _missed(projectiles, combat, i);
        _retire(store, projectiles, lines, i, store.posX[i], store.posY[i], now,
            windlineDuration);
        continue;
      }

      final double fromX = store.posX[i];
      final double fromY = store.posY[i];
      final double toX = fromX + store.velX[i] * dt;
      final double toY = fromY + store.velY[i] * dt;

      // Ghostshaft phases through interior walls entirely — the trade for
      // that is a short 8 u range, checked below — but still respects the
      // arena's own boundary, since there is nothing beyond it to simulate.
      final bool ghostshaftPhase =
          hero?.hasArrow(ArrowBehaviour.ghostshaftPhase) ?? false;

      // Walls stop arrows outright. Cover blocks projectiles but not movement,
      // which is what makes "break line of sight" a real answer to Longeye.
      final bool blockedByWall =
          !ghostshaftPhase && arena.circleHitsWall(toX, toY, store.radius[i]);
      final bool leftArena = !arena.containsPoint(toX, toY);
      if (blockedByWall || leftArena) {
        // Skimmer ricochets off whatever stopped it instead — a shared
        // counter of 2 with its own enemy-ricochet half in `_resolveHits`
        // below (docs/08: "ricochets 2x off walls or enemies", one pool,
        // not 2 of each). The reflected arrow simply waits out the rest of
        // this tick rather than also resuming movement in the new
        // direction — imperceptible at tick granularity, and it rules out
        // an infinite reflect loop in a tight corner.
        if (projectiles.ricochetsLeft[i] > 0) {
          projectiles.ricochetsLeft[i]--;
          projectiles.hasRicocheted[i] = 1;
          _layForcedSegment(
            store: store,
            projectiles: projectiles,
            lines: lines,
            hero: hero,
            slot: i,
            x: fromX,
            y: fromY,
            now: now,
            windlineDuration: windlineDuration,
          );
          // *True Bounce* (Corvin T1a) — a wall ricochet seeks the nearest
          // enemy instead of angle-reflecting. The enemy-ricochet half
          // already always seeks the nearest enemy on its own, so this is
          // the one branch True Bounce actually changes anything for.
          final int trueBounceTarget =
              hero != null && hero.has(HeroBehaviour.corvinTrueBounce)
                  ? _nearestUnhitEnemy(store, projectiles, i, toX, toY)
                  : -1;
          bool trueBounceRedirected = false;
          if (trueBounceTarget >= 0) {
            final double dx = store.posX[trueBounceTarget] - toX;
            final double dy = store.posY[trueBounceTarget] - toY;
            final double len = _length(dx, dy);
            if (len > 1e-6) {
              final double speed = _length(store.velX[i], store.velY[i]);
              store.velX[i] = dx / len * speed;
              store.velY[i] = dy / len * speed;
              trueBounceRedirected = true;
            }
          }
          if (!trueBounceRedirected) {
            _reflectOffWall(arena, store, i, toX, toY, blockedByWall);
          }
          continue;
        }
        _missed(projectiles, combat, i);
        _retire(
            store, projectiles, lines, i, fromX, fromY, now, windlineDuration);
        continue;
      }

      // This tick's travel is banked *before* anything else reads it.
      //
      // Two things depend on that. The terminal stub (ADR 0002) spans from the
      // last emitted segment to wherever the arrow died, so counting the
      // killing tick afterwards left it a tick short — and zero-long whenever a
      // segment had just been emitted. And Confluence eligibility is measured
      // in distance flown, which has to include the tick being resolved.
      final double step = _length(toX - fromX, toY - fromY);
      projectiles.sinceLastSegment[i] += step;
      projectiles.distanceFlown[i] += step;

      if (ghostshaftPhase && projectiles.distanceFlown[i] > _ghostshaftRange) {
        _missed(projectiles, combat, i);
        _retire(store, projectiles, lines, i, toX, toY, now, windlineDuration);
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
        boons: boons,
        confluenceDamageMultiplier: confluenceDamageMultiplier,
        arrowElementIndex: projectiles.element[i],
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
        combat: combat,
        boons: boons,
        hero: hero,
        player: player,
        lifesteal: lifesteal,
      );

      if (consumed) continue;

      // Lay the trail behind the arrow, one segment per
      // [SimConfig.windlineSegmentLength] flown rather than one per tick. The
      // segment spans the whole accumulated stretch, so the polyline is
      // continuous — it is emitted less often, not made of gaps.
      if (projectiles.sinceLastSegment[i] >= segmentLength) {
        _layForcedSegment(
          store: store,
          projectiles: projectiles,
          lines: lines,
          hero: hero,
          slot: i,
          x: toX,
          y: toY,
          now: now,
          windlineDuration: windlineDuration,
        );
      }

      store.posX[i] = toX;
      store.posY[i] = toY;
    }
  }

  /// Emits a Windline segment spanning everything accumulated in
  /// `sinceLastSegment` since the last one, ending at ([x], [y]) — the
  /// periodic per-[SimConfig.windlineSegmentLength] cut during ordinary
  /// flight, and Skimmer's own forced cut at a ricochet point, are the same
  /// operation at two different trigger conditions.
  static void _layForcedSegment({
    required EntityStore store,
    required ProjectileStore projectiles,
    required WindlineStore lines,
    required HeroRuntime? hero,
    required int slot,
    required double x,
    required double y,
    required double now,
    required double windlineDuration,
  }) {
    final double back = projectiles.sinceLastSegment[slot];
    if (back <= 0) return;

    final double dirX = store.velX[slot];
    final double dirY = store.velY[slot];
    final double dirLen = _length(dirX, dirY);
    final double ux = dirLen > 0 ? dirX / dirLen : 0;
    final double uy = dirLen > 0 ? dirY / dirLen : 0;

    lines.add(
      fromX: x - ux * back,
      fromY: y - uy * back,
      toX: x,
      toY: y,
      expiresAt: now + windlineDuration,
      ownerIndex: _playerOwner,
      trailId: projectiles.trailId[slot],
      elementIndex: projectiles.element[slot],
      // *Shadowline* (Nyx, T3a) — a segment laid while Umbral Step's
      // untargetable window is live also deals damage; ADR 0010.
      isShadowline: (hero?.umbralStepRemaining ?? 0) > 0,
      // *Phoenix Trail* (Ashlin, T3b) — same shape, Ashlin's own
      // invulnerability window instead of Nyx's.
      isPhoenixTrail: (hero?.ashlinInvulnRemaining ?? 0) > 0,
    );
    projectiles.sinceLastSegment[slot] = 0;
  }

  static void _reflectOffWall(
    Arena arena,
    EntityStore store,
    int slot,
    double x,
    double y,
    bool hitWall,
  ) {
    if (hitWall) {
      final int w = arena.wallHitBy(x, y, store.radius[slot]);
      if (w >= 0) {
        // Standard AABB reflection: the shallower-penetration axis is the
        // one the arrow actually crossed, so that is the one that flips.
        final double cx = _clampToRange(x, arena.wallLeft(w), arena.wallRight(w));
        final double cy = _clampToRange(y, arena.wallTop(w), arena.wallBottom(w));
        final double dx = x - cx;
        final double dy = y - cy;
        if (dx.abs() >= dy.abs()) {
          store.velX[slot] = -store.velX[slot];
        } else {
          store.velY[slot] = -store.velY[slot];
        }
        return;
      }
    }
    // The arena's own boundary — reflect whichever axis actually left it.
    if (x < 0 || x > arena.width) store.velX[slot] = -store.velX[slot];
    if (y < 0 || y > arena.height) store.velY[slot] = -store.velY[slot];
  }

  static double _clampToRange(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

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
    required BoonRuntime boons,
    required double confluenceDamageMultiplier,
    required int arrowElementIndex,
  }) {
    if (projectiles.confluenceStacks[slot] >= maxStacks) return;

    // An arrow may not thread anything until it has left the bow behind. See
    // [ConfluenceTuning.minThreadDistance].
    if (projectiles.distanceFlown[slot] < ConfluenceTuning.minThreadDistance) {
      return;
    }

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
    projectiles.confluenceBonus[slot] =
        ConfluenceTuning.bonusFor(stacks) * confluenceDamageMultiplier;

    // *Crossbind* (#67) — a threaded arrow also carries the player's element.
    // Applied to the *mask* rather than to `element`, so it composes with the
    // multi-element Boons instead of overwriting them.
    if (boons.has(BoonBehaviour.crossbind) && arrowElementIndex >= 0) {
      projectiles.elementMask[slot] |= 1 << arrowElementIndex;
    }

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

  // ── Ghostshaft ────────────────────────────────────────────────────────────
  // Phases through walls and shields, ignores plating entirely — the trade
  // is a short range and no pierce. Checked both in `update`'s own movement
  // loop (walls, range) and in `_applyHit` below (shield, plate).

  static const double _ghostshaftRange = 8.0;

  // ── Nyx: First Blood ──────────────────────────────────────────────────────

  static const double _nyxFirstBloodFullHealthThreshold = 0.90;
  static const double _nyxFirstBloodBonus = 0.70;
  static const double _nyxExecutionersEyeThreshold = 0.20;
  static const double _nyxExecutionersEyeBonus = 0.35;

  // ── Corvin: Bounce ──────────────────────────────────────────────────────────

  /// "A ricochet deals 120 %" — expressed as the +20 % boonSum term, not a
  /// standalone ×1.2, the same "conditional terms sum, not multiply" rule
  /// every other hero bonus above and below this one follows.
  static const double _corvinHardBounceBonus = 0.20;

  // ── Vane: Distance ─────────────────────────────────────────────────────────

  static const double _vaneCloseRangeThreshold = 3.0;
  static const double _vaneCloseRangePenalty = -0.30;
  static const double _vaneMarkedThreshold = 8.0;
  static const double _vaneMarkedDuration = 5.0;
  static const double _vaneMarkedBonus = 0.25;

  // ── Halden: Verdict ────────────────────────────────────────────────────────

  static const double _haldenVerdictEliteBonus = 0.40;

  // ── Lira: Lifebound ────────────────────────────────────────────────────────

  static const double _liraLifeboundTierThreeBonus = 0.02;

  // ── Lira: Overheal ─────────────────────────────────────────────────────────

  /// docs/07 §7.1: Overheal's own stated cap — "up to 30 % HP". No shared
  /// heal-clamp helper exists anywhere in the sim (Lifebound's own lifesteal
  /// above and Verdant Bloom's regen in `SimWorld` both compute their clamp
  /// inline, independently), so this stays scoped to lifesteal's own call
  /// site; `SimWorld`'s own Bloom tick carries an identical block rather
  /// than reaching across files for one three-line helper. ADR 0016 records
  /// why Overheal only catches these two heal sources — Lira's own — and
  /// not the wider, unaudited BoonSystem regen/shield surface Thane's own
  /// Tempered was deferred over for the identical reason.
  static const double _liraOverhealShieldCap = 0.30;

  static void _applyLiraOverheal(
    HeroRuntime? hero,
    double overflow,
    double maxHealth,
  ) {
    if (hero == null || !hero.has(HeroBehaviour.liraOverheal)) return;
    final double cap = maxHealth * _liraOverhealShieldCap;
    final double newShield = hero.overhealShield + overflow;
    hero.overhealShield = newShield > cap ? cap : newShield;
  }

  // ── Thane: Bloodtide ───────────────────────────────────────────────────────

  static const double _thaneBloodtidePerMissingFraction = 1.2;
  static const double _thaneBloodtideCap = 0.85;
  static const double _thaneDeeperTideCap = 1.20;

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
    required CombatModifiers combat,
    required BoonRuntime boons,
    HeroRuntime? hero,
    int player = -1,
    double lifesteal = 0,
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
        combat: combat,
        boons: boons,
        hero: hero,
        player: player,
        lifesteal: lifesteal,
      );

      if (projectiles.pierceRemaining[slot] < 0) {
        // Skimmer redirects toward the nearest other living enemy it has
        // not already struck this flight, rather than stopping here —
        // sharing the same `ricochetsLeft` pool the wall/boundary half in
        // `update` spends from. No enemy left to bounce to falls through to
        // the ordinary retire below, same as running out of charges would.
        if (projectiles.ricochetsLeft[slot] > 0) {
          final int next = _nearestUnhitEnemy(
              store, projectiles, slot, store.posX[target], store.posY[target],
              exclude: target);
          if (next >= 0) {
            projectiles.ricochetsLeft[slot]--;
            projectiles.hasRicocheted[slot] = 1;
            // Corvin's own "a ricocheted arrow lays a new Windline" applies
            // here too, not just off a wall — the wall half above always
            // did this unconditionally, so this closes the same gap for the
            // enemy half rather than gating it on Corvin specifically.
            _layForcedSegment(
              store: store,
              projectiles: projectiles,
              lines: lines,
              hero: hero,
              slot: slot,
              x: toX,
              y: toY,
              now: now,
              windlineDuration: windlineDuration,
            );
            // One more hit is now owed before pierce runs out again — the
            // same "just enough to reach the next target" reset a fresh
            // arrow's own pierceRemaining already represents.
            projectiles.pierceRemaining[slot] = 0;
            final double dx = store.posX[next] - toX;
            final double dy = store.posY[next] - toY;
            final double len = _length(dx, dy);
            if (len > 1e-6) {
              final double speed = _length(store.velX[slot], store.velY[slot]);
              store.velX[slot] = dx / len * speed;
              store.velY[slot] = dy / len * speed;
            }
            return false;
          }
        }
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

  /// Nearest other living enemy to ([x], [y]) that [slot]'s own arrow has
  /// not already struck this flight — Skimmer's own enemy-ricochet target,
  /// and (from a wall) Corvin's *True Bounce*. A linear scan rather than a
  /// [SpatialHash] query: the enemy-ricochet call site runs from inside
  /// `_resolveHits`'s own candidate loop, which is still reading results
  /// out of `SpatialHash`'s single shared query buffer — a nested query
  /// there would silently corrupt that iteration, the same reasoning
  /// Bram's splash and Torv's chain already document. Coordinates rather
  /// than an origin entity index, since a wall ricochet has no "entity just
  /// hit" to read a position from; [exclude] is still an entity index, for
  /// the enemy-ricochet call site's own "not the one I just hit" rule.
  static int _nearestUnhitEnemy(
    EntityStore store,
    ProjectileStore projectiles,
    int slot,
    double x,
    double y, {
    int exclude = -1,
  }) {
    int nearest = -1;
    double nearestDistSq = double.infinity;
    for (int i = 0; i < store.highWater; i++) {
      if (i == exclude) continue;
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;
      if (projectiles.hasHit(slot, store.idAt(i).raw)) continue;
      final double dx = store.posX[i] - x;
      final double dy = store.posY[i] - y;
      final double distSq = dx * dx + dy * dy;
      if (distSq < nearestDistSq) {
        nearestDistSq = distSq;
        nearest = i;
      }
    }
    return nearest;
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
    required CombatModifiers combat,
    required BoonRuntime boons,
    HeroRuntime? hero,
    int player = -1,
    double lifesteal = 0,
  }) {
    final int pierceIndex = projectiles.hitCount[slot];
    projectiles.recordHit(slot, targetId);

    // A multi-body boss's child (Cinder Choir's effigies today) redirects its
    // *health* to whatever entity holds the shared pool — `linkedHealthSlot`'s
    // own doc comment. Everything else about the hit (armour, plate, shield,
    // stagger tracking) stays keyed on `target` itself: a shared pool with
    // independent per-child armour is the entire point of the mechanic.
    final int healthSlot = (enemies != null && enemies.linkedHealthSlot[target] >= 0)
        ? enemies.linkedHealthSlot[target]
        : target;

    final DrawTier tier = DrawTier.values[projectiles.drawTier[slot]];

    // Ghostshaft ignores plating entirely — armour is not reduced by it, the
    // same way the Draw tier's own armour clang never happens for this arrow.
    final bool ghostshaftPhase =
        hero != null && hero.hasArrow(ArrowBehaviour.ghostshaftPhase);

    // Armour is resolved here, not at fire time: the arrow carries the tier it
    // was fired at, and the plate state is read from the target now.
    double armour = ghostshaftPhase
        ? ArmourFactor.none
        : _armourFor(store, enemies, target, tier, fromX, fromY);

    // *Rend* (#14) wears the plate down permanently, converging to a floor
    // rather than removing it — an enemy whose armour reached zero would stop
    // being the enemy the Draw mechanic exists to teach.
    if (enemies != null && combat.armourShredPerHit > 0) {
      final double shredded = enemies.armourShred[target] +
          combat.armourShredPerHit;
      enemies.armourShred[target] =
          shredded > combat.armourShredMax ? combat.armourShredMax : shredded;
      // Shred lifts the *factor* toward 1.0, so it helps most where armour
      // hurts most.
      armour += (1.0 - armour) * enemies.armourShred[target];
      if (armour > 1.0) armour = 1.0;
    }

    // *Deadeye* (#18) — crits skip the pierce-falloff curve entirely. Applied
    // as a pierce index of zero rather than by removing the term, so the
    // falloff maths stays in one place.
    final bool deadeye = boons.has(BoonBehaviour.deadeye) && projectiles.wasCrit[slot] == 1;
    // *Perfect Carom* (Corvin T5b) — "during Caroms, ricochets never lose
    // damage". The pierce-falloff curve above is exactly what a ricocheted
    // arrow's later hits would otherwise be losing to (a ricochet does not
    // reset `hitCount`, only `pierceRemaining`), so this is the same "skip
    // the curve" shape Deadeye already uses, gated on this hit having
    // actually come from a ricochet.
    final bool perfectCaromActive = hero != null &&
        hero.caromsRemaining > 0 &&
        hero.has(HeroBehaviour.corvinPerfectCarom) &&
        projectiles.hasRicocheted[slot] == 1;
    final int effectivePierceIndex = (deadeye || perfectCaromActive) ? 0 : pierceIndex;

    // The build's conditional terms, resolved against *this* target and *this*
    // shot. They sum into one `boonDamageSum` rather than each multiplying the
    // total — docs/04 §4.1 rule 1, and the reason a twenty-Boon run is linear.
    final double maxHp = store.maxHealth[healthSlot];
    final double targetHealthFraction =
        maxHp > 0 ? store.health[healthSlot] / maxHp : 1.0;

    double boonSum = 0;
    if (!combat.isInert) {
      boonSum = combat.damageSumFor(
        targetHealthFraction: targetHealthFraction,
        // Distance the arrow has actually flown, not the length of this tick's
        // sweep. *Marksman* rewards a long shot, and a long shot is long at the
        // moment it lands, not at the moment it was fired.
        shotDistance: projectiles.distanceFlown[slot],
        targetId: targetId,
        targetAfflicted: status != null &&
            (status.burnStacks[target] > 0 ||
                status.toxinStacks[target] > 0 ||
                status.isFrozen(target)),
        targetArmoured: enemies != null &&
            (enemies.isPlated(target) || enemies.shield[target] > 0),
        isTierThree: tier == DrawTier.three,
        isTierOne: tier == DrawTier.one,
      );
    }

    // *First Blood* — a hero passive, not a Boon, so it lives outside
    // `combat`/`boonDamageSum`'s composed-from-BoonStats world and adds here
    // directly. Executioner's Eye (T1a) widens the same bonus to below 20 %
    // HP as well, which is why this checks the talent flag too rather than
    // being folded into a single always-90 % constant.
    if (hero != null && hero.has(HeroBehaviour.nyxFirstBlood)) {
      if (targetHealthFraction > _nyxFirstBloodFullHealthThreshold) {
        boonSum += _nyxFirstBloodBonus;
      } else if (hero.has(HeroBehaviour.nyxExecutionersEye) &&
          targetHealthFraction < _nyxExecutionersEyeThreshold) {
        boonSum += _nyxExecutionersEyeBonus;
      }
    }

    // *Hard Bounce* (Corvin T1b) — "a ricochet deals 120 %". Every hit this
    // arrow lands after its first ricochet counts, not only the very next
    // one, since [hasRicocheted] is never cleared once set.
    if (hero != null &&
        hero.has(HeroBehaviour.corvinHardBounce) &&
        projectiles.hasRicocheted[slot] == 1) {
      boonSum += _corvinHardBounceBonus;
    }

    // *Distance*'s close-range penalty. The per-unit bonus and its cap are
    // plain StatModifiers on damagePerDistance/damagePerDistanceCap and
    // already reached boonSum above through `combat`; only the "below 3 u"
    // half needs a hero-conditional check, and Steady (T1a) removes it
    // outright rather than reducing it.
    if (hero != null &&
        hero.has(HeroBehaviour.vaneDistance) &&
        !hero.has(HeroBehaviour.vaneSteady) &&
        projectiles.distanceFlown[slot] < _vaneCloseRangeThreshold) {
      boonSum += _vaneCloseRangePenalty;
    }

    // *Marked* (T3a) — reads whatever mark this target is already carrying
    // from an earlier hit; the hit that lands the mark itself (below, after
    // damage resolves) does not get its own bonus retroactively, the same
    // "applies to what comes after, not what caused it" shape Kindling's
    // own Burn already has.
    if (enemies != null && enemies.markedRemaining[target] > 0) {
      boonSum += _vaneMarkedBonus;
    }

    // *Verdict* — only the elite half is reachable before Phase 11 builds
    // bosses. "+40 % to bosses and elites" and "boss attacks deal -15 %"
    // both need an `isBoss` check that does not exist on EnemyStore yet;
    // the elite half needs nothing new, since `isElite` already does.
    if (hero != null &&
        hero.has(HeroBehaviour.haldenVerdict) &&
        enemies != null &&
        enemies.isElite(target)) {
      boonSum += _haldenVerdictEliteBonus;
    }

    // *Verdant Bloom* / *Blood Bloom* — a live window read here rather than
    // gated by a `HeroBehaviour` check, since `bloomRemaining` can only ever
    // be non-zero for a hero who actually holds the Ultimate that sets it.
    if (hero != null && hero.bloomRemaining > 0) {
      boonSum += hero.bloomDamageBonus;
    }

    // *Red Draw* — same reasoning: `redDrawRemaining` only exists for Thane.
    if (hero != null && hero.redDrawRemaining > 0) {
      boonSum += hero.redDrawDamageBonus;
    }

    // *Bloodtide* — the healing-cap half of this passive ("cannot be healed
    // above 70 % max HP by any source") is not implemented: it would need a
    // cap check threaded into every heal source (lifesteal above, and every
    // BoonSystem regen/shield call), and "does a heal-to-full Boon respect
    // it too" is a design question this card's text does not answer on its
    // own. The damage half needs nothing new now that `player` reaches this
    // hit path.
    if (hero != null && hero.has(HeroBehaviour.thaneBloodtide) && player >= 0) {
      final double playerMaxHp = store.maxHealth[player];
      final double missingFraction =
          playerMaxHp > 0 ? 1.0 - (store.health[player] / playerMaxHp) : 0.0;
      final double cap = hero.has(HeroBehaviour.thaneDeeperTide)
          ? _thaneDeeperTideCap
          : _thaneBloodtideCap;
      final double bonus = missingFraction * _thaneBloodtidePerMissingFraction;
      boonSum += bonus > cap ? cap : bonus;
    }

    // *Pull*'s grouped-damage half. "Grouped" has no distance stated
    // anywhere in docs/07 — see ADR 0007 for why this borrows Bram's own
    // 1.6 u splash radius rather than inventing an unrelated number.
    if (hero != null && hero.has(HeroBehaviour.rookPull) && enemies != null) {
      final int grouped = _countRookGrouped(store, target);
      final int cappedCount =
          grouped > _rookGroupingCountCap ? _rookGroupingCountCap : grouped;
      final double perEnemy = hero.has(HeroBehaviour.rookDenserGrouping)
          ? _rookDenserGroupingBonus
          : _rookGroupingBonus;
      boonSum += cappedCount * perEnemy;
    }

    // *Chill* — "+30 % damage while frozen" (Brittle, T1b: +45 %). This is
    // Sela's own headline number, never wired into damage before now:
    // `status.isFrozen` was only read above for a Boon's own targetAfflicted
    // condition, and `StatusStore.damageTakenBonus` (the generic version of
    // this same bonus) had no caller anywhere.
    if (hero != null &&
        hero.has(HeroBehaviour.selaChill) &&
        status != null &&
        status.isFrozen(target)) {
      boonSum += hero.has(HeroBehaviour.selaBrittle)
          ? _selaBrittleDamageBonus
          : ElementTuning.frozenDamageBonus;
    }

    final double damage = DamageResolver.resolve(
      attack: projectiles.damage[slot],
      arrowBaseMultiplier: 1.0,
      drawTierMultiplier: tier.damageMultiplier,
      confluenceBonus: projectiles.confluenceBonus[slot],
      elementalBonus: projectiles.elementalBonus[slot],
      boonDamageSum: boonSum,
      pierceIndex: effectivePierceIndex,
      armourFactor: armour,
    );

    // *Marked* — a hit landed from beyond 8 u opens (or refreshes) the
    // window itself; read above, ahead of this resolve, so the hit that
    // lands the mark is never boosted by its own mark.
    if (hero != null &&
        hero.has(HeroBehaviour.vaneMarked) &&
        enemies != null &&
        projectiles.distanceFlown[slot] > _vaneMarkedThreshold) {
      enemies.markedRemaining[target] = _vaneMarkedDuration;
    }

    // Streak and last-target are updated after the hit is resolved, so
    // *Follow Through* rewards the arrow *after* the one that landed and
    // *Crescendo* counts this hit toward the next.
    combat.hitStreak++;
    combat.lastHitTarget = targetId;

    // *Cull* (#20) finishes anything left below its threshold. Non-elites only:
    // an execute that worked on Riftborn would delete the roster's mechanics
    // rather than reward clearing fodder — a boss (and any of its linked
    // children, sharing that same pool) is exempt for the identical reason,
    // and more severely so: a boss's own HP is a `×22`-`×140` multiplier, so
    // a threshold sized for common-enemy HP would delete a double-digit
    // percentage of a boss bar in one stray low-roll hit.
    if (boons.has(BoonBehaviour.cull) &&
        enemies != null &&
        !enemies.isElite(target) &&
        !enemies.isBoss(target) &&
        enemies.linkedHealthSlot[target] < 0 &&
        store.health[healthSlot] > 0 &&
        store.health[healthSlot] <
            store.maxHealth[healthSlot] * BoonRuntime.cullThreshold) {
      store.health[healthSlot] = 0;
    }

    double toHealth = damage;
    if (enemies != null) {
      // Shield, then plate, then health. The order is the fiction: a Weaver's
      // barrier sits outside the armour, and the armour sits outside the body.
      // Ghostshaft ignores both outright — "passes through walls and
      // shields; ignores plating entirely" — rather than merely dealing full
      // damage through them.
      if (!ghostshaftPhase) {
        toHealth = enemies.absorb(target, toHealth);
        enemies.wearPlate(target, toHealth);
      }
      // Damage taken during a wind-up is what a Ripper's stagger is measured
      // against — the game's parry, counted here because this is where damage
      // is known.
      enemies.damageDuringWindUp[target] += toHealth;

      // Skarn's own "damaging only one causes the other to heal it" (docs/06
      // §11) reads this on the hit slot itself, not `healthSlot` — a shared
      // pool with independently-*pressured* children is the whole mechanic,
      // the same split `linkedHealthSlot` already draws for armour.
      if (toHealth > 0) enemies.bossLastHitAgo[target] = 0;
    }

    store.health[healthSlot] -= toHealth;
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

    _applyHeroInnateElements(
      projectiles: projectiles,
      enemies: enemies,
      status: status,
      events: events,
      hero: hero,
      slot: slot,
      target: target,
      tier: tier,
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

    // docs/07 §7.0's Ultimate charge formula reads on the damage a hit
    // actually dealt, the same number the event above just reported.
    hero?.chargeFromDamage(toHealth);

    // Lifesteal — `lifesteal` is the room-composed fraction any source
    // (currently only Lira's Lifebound) contributes; her own +2 % at Tier
    // III is a hero-specific top-up on top of that composed value, not a
    // second channel, since nothing else in the game varies lifesteal by
    // Draw tier.
    if (lifesteal > 0 && player >= 0) {
      double effectiveLifesteal = lifesteal;
      if (hero != null &&
          hero.has(HeroBehaviour.liraLifebound) &&
          tier == DrawTier.three) {
        effectiveLifesteal += _liraLifeboundTierThreeBonus;
      }
      final double cap = store.maxHealth[player];
      final double healed = store.health[player] + toHealth * effectiveLifesteal;
      if (healed > cap) {
        store.health[player] = cap;
        _applyLiraOverheal(hero, healed - cap, cap);
      } else {
        store.health[player] = healed;
      }
    }

    // *Heavy Ordnance* — splash never applies elements, which is why this
    // reads `toHealth` and stops there rather than calling back into
    // `_applyElement`. Deliberately a linear scan over `store.highWater`
    // rather than a `SpatialHash.queryRadius` call: this runs from inside
    // `_resolveHits`'s own candidate loop, which is still reading results
    // out of `SpatialHash`'s single shared query buffer — a nested query
    // here would silently corrupt that iteration. The scan only runs on a
    // confirmed hit, not every tick, so its cost is bounded by how often
    // Bram's arrows actually land.
    if (hero != null && hero.has(HeroBehaviour.bramHeavyOrdnance) && enemies != null) {
      final bool denser = hero.has(HeroBehaviour.bramDenserBlast);
      final double radius = denser
          ? _bramDenserBlastRadius
          : (hero.has(HeroBehaviour.bramWiderBlast)
              ? _bramWiderBlastRadius
              : _bramSplashRadius);
      final double fraction =
          denser ? _bramDenserBlastFraction : _bramSplashFraction;
      _applyBramSplash(
        store: store,
        primaryTarget: target,
        x: store.posX[target],
        y: store.posY[target],
        radius: radius,
        splashDamage: toHealth * fraction,
      );
    }

    // *Weave* (Iris) — a hit that lands at the (Iris-only) 5-stack Confluence
    // ceiling also splashes in a 2 u AoE. docs/07 gives no share for this one
    // (ADR 0009): reuses the hit's own already-resolved damage in full,
    // rather than a fraction, since a 5-stack hit is the rarest state
    // reachable in the build. Everything else — the 4th/5th-stack damage
    // bonus itself, the raised stack cap, the longer Windline duration — is
    // already generic: `ConfluenceTuning.bonusByStacks` has carried x4/x5
    // since Phase 9, and Weave's own numbers are plain StatModifiers composed
    // through the same channel every Boon uses.
    if (hero != null &&
        hero.has(HeroBehaviour.irisWeave) &&
        enemies != null &&
        projectiles.confluenceStacks[slot] >= ConfluenceTuning.irisMaxStacks) {
      _applyBramSplash(
        store: store,
        primaryTarget: target,
        x: store.posX[target],
        y: store.posY[target],
        radius: _irisWeaveAoeRadius,
        splashDamage: toHealth,
      );
    }

    // *Arc* / *Tempest Nock* — "chains travel along live Windlines" is read
    // as the visual presentation (the render layer draws the chain along
    // nearby trail geometry), not a constraint on which enemies are
    // reachable: querying "which enemies sit near a live Windline segment"
    // is a relationship nothing in the sim currently indexes, and docs/07
    // gives no distance/tolerance for it either. Chains hit whichever
    // enemies are nearest instead — the same linear-scan approach Heavy
    // Ordnance's splash already uses, and for the identical reason: this
    // runs inside `_resolveHits`'s own candidate loop, so a nested
    // `SpatialHash` query here would corrupt it.
    if (hero != null &&
        hero.has(HeroBehaviour.torvArc) &&
        enemies != null &&
        (projectiles.willChain[slot] == 1 || hero.tempestNockRemaining > 0)) {
      final int chainCount =
          hero.has(HeroBehaviour.torvWideArc) ? _torvWideArcTargets : _torvArcTargets;
      _applyTorvChain(
        store: store,
        primaryTarget: target,
        x: store.posX[target],
        y: store.posY[target],
        chainCount: hero.tempestNockRemaining > 0
            ? _torvTempestNockTargets
            : chainCount,
        chainDamage: toHealth * _torvArcDamageShare,
      );
    }

    // *Bleed* (Kestrel T3b) — the tagged 4th arrow applies its own bleed to
    // whatever it hits. A flat set to 1, not an increment: "every 4th arrow
    // applies *a* bleed" reads as one DoT refreshed on reapplication, not a
    // stacking one — see ADR 0015.
    if (hero != null &&
        hero.has(HeroBehaviour.kestrelBleed) &&
        enemies != null &&
        projectiles.willBleed[slot] == 1) {
      enemies.bleedStacks[target] = 1;
      enemies.bleedRemaining[target] = _kestrelBleedDuration;
    }

    // *Pull*'s crit-displacement half. Moves the target toward the shooter
    // (the player, not the arrow's own tick-local `fromX`/`fromY`, which sits
    // almost on top of the impact point and would clamp the pull to nearly
    // nothing) — clamped to the distance actually separating them, so a
    // point-blank crit cannot pull an enemy past the player. No wall check:
    // 1.2-2.0 u is small enough that this reads as a shove, not a teleport,
    // and every other AoE-shaped hero effect in this file (splash, chains) is
    // equally indifferent to walls.
    if (hero != null &&
        hero.has(HeroBehaviour.rookPull) &&
        projectiles.wasCrit[slot] == 1 &&
        player >= 0) {
      final double dx = store.posX[player] - store.posX[target];
      final double dy = store.posY[player] - store.posY[target];
      final double dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 1e-6) {
        final double pullDistance = hero.has(HeroBehaviour.rookStrongerPull)
            ? _rookStrongerPullDistance
            : _rookPullDistance;
        final double actualPull = pullDistance > dist ? dist : pullDistance;
        store.posX[target] += dx / dist * actualPull;
        store.posY[target] += dy / dist * actualPull;
      }
    }

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

  /// Raw damage to every other living enemy within [radius] of ([x], [y]).
  /// No armour, shield or element interaction — a splash is a flat number,
  /// not a second arrow.
  static void _applyBramSplash({
    required EntityStore store,
    required int primaryTarget,
    required double x,
    required double y,
    required double radius,
    required double splashDamage,
  }) {
    final double radiusSq = radius * radius;
    for (int i = 0; i < store.highWater; i++) {
      if (i == primaryTarget) continue;
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;
      final double dx = store.posX[i] - x;
      final double dy = store.posY[i] - y;
      if (dx * dx + dy * dy > radiusSq) continue;
      store.health[i] -= splashDamage;
    }
  }

  static const double _bramSplashRadius = 1.6;
  static const double _bramSplashFraction = 0.45;
  static const double _bramWiderBlastRadius = 2.2;
  static const double _bramDenserBlastRadius = 1.2;
  static const double _bramDenserBlastFraction = 0.65;

  static const double _irisWeaveAoeRadius = 2.0;

  /// Damages the [chainCount] nearest other living enemies to ([x], [y]).
  /// Linear scan, same reasoning and same cost profile as
  /// [_applyBramSplash] — bounded by how often a chain-eligible hit lands,
  /// not paid every tick.
  static void _applyTorvChain({
    required EntityStore store,
    required int primaryTarget,
    required double x,
    required double y,
    required int chainCount,
    required double chainDamage,
  }) {
    // Small, fixed-size "nearest N" via insertion — chainCount never
    // exceeds 5, so this beats allocating and sorting a list.
    final List<int> nearest = List<int>.filled(chainCount, -1);
    final List<double> nearestDistSq =
        List<double>.filled(chainCount, double.infinity);

    for (int i = 0; i < store.highWater; i++) {
      if (i == primaryTarget) continue;
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;
      final double dx = store.posX[i] - x;
      final double dy = store.posY[i] - y;
      final double distSq = dx * dx + dy * dy;

      if (distSq >= nearestDistSq[chainCount - 1]) continue;
      int slot = chainCount - 1;
      while (slot > 0 && nearestDistSq[slot - 1] > distSq) {
        nearestDistSq[slot] = nearestDistSq[slot - 1];
        nearest[slot] = nearest[slot - 1];
        slot--;
      }
      nearestDistSq[slot] = distSq;
      nearest[slot] = i;
    }

    for (final int target in nearest) {
      if (target < 0) continue;
      store.health[target] -= chainDamage;
    }
  }

  static const double _torvArcDamageShare = 0.60;
  static const int _torvArcTargets = 3;
  static const int _torvWideArcTargets = 5;
  static const int _torvTempestNockTargets = 5;

  /// docs/07 §7.1: "every 4th arrow applies a 3 s bleed" — the duration is
  /// the one number the card actually states; the %/s it deals lives on
  /// `ElementSystem._bleedPerSecond` (ADR 0015), next to the tick itself.
  static const double _kestrelBleedDuration = 3.0;

  /// Counts other living enemies within [_rookGroupingRadius] of [target] —
  /// a linear scan for the same reason [_applyBramSplash] is one.
  static int _countRookGrouped(EntityStore store, int target) {
    const double radiusSq = _rookGroupingRadius * _rookGroupingRadius;
    int count = 0;
    for (int i = 0; i < store.highWater; i++) {
      if (i == target) continue;
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;
      final double dx = store.posX[i] - store.posX[target];
      final double dy = store.posY[i] - store.posY[target];
      if (dx * dx + dy * dy > radiusSq) continue;
      count++;
    }
    return count;
  }

  static const double _rookPullDistance = 1.2;
  static const double _rookStrongerPullDistance = 2.0;

  /// ADR 0007 — docs/07 states no distance for "grouped"; this borrows
  /// Bram's own splash radius rather than inventing an unrelated number.
  static const double _rookGroupingRadius = 1.6;
  static const int _rookGroupingCountCap = 4;
  static const double _rookGroupingBonus = 0.12;
  static const double _rookDenserGroupingBonus = 0.18;

  static const double _selaBrittleDamageBonus = 0.45;

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

    // Almost every arrow carries one element or none. The mask is for the four
    // Boons that carry several — and it is what beats the Nullborn, whose
    // adaptation counters one element at a time (docs/05 §5.6).
    final int mask = projectiles.elementMask[slot];
    if (mask != 0) {
      for (final SimElement element in SimElement.values) {
        if (mask & (1 << element.index) == 0) continue;
        _applyOneElement(
            enemies, status, events, slot, target, element, x, y);
      }
      return;
    }

    final int index = projectiles.element[slot];
    if (index < 0) return;
    _applyOneElement(enemies, status, events, slot, target,
        SimElement.values[index], x, y);
  }

  /// Kade's Kindling, Sela's Chill and Sable's Toxin: each grants their own
  /// element "without needing an [Ember/Frost/Toxin] arrow" (their own card
  /// text). Every one of the three uses the exact numbers
  /// [ElementTuning] already defines for an arrow's own elemental application
  /// — Sela's "12 Chill, freeze at 100, +30 % while frozen" is
  /// `ElementTuning.chillPerHit`/`chillToFreeze`/`frozenDamageBonus` verbatim
  /// — so this reuses [_applyOneElement] rather than a second implementation
  /// of the same status.
  ///
  /// Skips an element the arrow already carries: an Emberhead shot from Kade
  /// must not stack Burn twice for one hit.
  static void _applyHeroInnateElements({
    required ProjectileStore projectiles,
    required EnemyStore? enemies,
    required StatusStore? status,
    required SimEventBuffer events,
    required HeroRuntime? hero,
    required int slot,
    required int target,
    required DrawTier tier,
    required double x,
    required double y,
  }) {
    if (status == null || hero == null) return;

    void applyIfNotAlreadyCarried(
      SimElement element, {
      double? chillPerHitOverride,
      int? toxinStacksPerHitOverride,
      int? toxinMaxStacksOverride,
      int? burnMaxStacksOverride,
      double? burnDurationOverride,
    }) {
      final int mask = projectiles.elementMask[slot];
      final int index = projectiles.element[slot];
      final bool alreadyCarried = mask != 0
          ? (mask & (1 << element.index)) != 0
          : index == element.index;
      if (alreadyCarried) return;
      _applyOneElement(enemies, status, events, slot, target, element, x, y,
          chillPerHitOverride: chillPerHitOverride,
          toxinStacksPerHitOverride: toxinStacksPerHitOverride,
          toxinMaxStacksOverride: toxinMaxStacksOverride,
          burnMaxStacksOverride: burnMaxStacksOverride,
          burnDurationOverride: burnDurationOverride);
    }

    // *Hot Iron* (T1a) widens the tier gate to Tier II as well; *Deep Burn*
    // (T1b) keeps the Tier-III-only gate and instead raises the per-second
    // rate — read where the DoT itself ticks, in [ElementSystem], since nothing
    // here computes damage. *Slow Burn* (T3a) is orthogonal to both: whichever
    // gate let the stack through, it lasts longer and caps higher.
    final bool tierQualifies = tier == DrawTier.three ||
        (tier == DrawTier.two && hero.has(HeroBehaviour.kadeHotIron));
    if (tierQualifies && hero.has(HeroBehaviour.kadeKindling)) {
      applyIfNotAlreadyCarried(
        SimElement.ember,
        burnMaxStacksOverride:
            hero.has(HeroBehaviour.kadeSlowBurn) ? _kadeSlowBurnMaxStacks : null,
        burnDurationOverride:
            hero.has(HeroBehaviour.kadeSlowBurn) ? _kadeSlowBurnDuration : null,
      );
    }
    if (hero.has(HeroBehaviour.selaChill)) {
      // *Deeper Chill* (T1a) — 16 per hit instead of the base 12.
      applyIfNotAlreadyCarried(
        SimElement.frost,
        chillPerHitOverride:
            hero.has(HeroBehaviour.selaDeeperChill) ? _selaDeeperChillPerHit : null,
      );
    }
    if (hero.has(HeroBehaviour.sableToxin)) {
      // *Virulence* (T1a) raises the cap alone; *Fast Acting* (T1b) stacks
      // twice as fast but settles for a lower cap — mutually exclusive
      // branches, so only one override pair is ever non-null.
      applyIfNotAlreadyCarried(
        SimElement.toxin,
        toxinStacksPerHitOverride:
            hero.has(HeroBehaviour.sableFastActing) ? _sableFastActingPerHit : null,
        toxinMaxStacksOverride: hero.has(HeroBehaviour.sableFastActing)
            ? _sableFastActingMaxStacks
            : hero.has(HeroBehaviour.sableVirulence)
                ? _sableVirulenceMaxStacks
                : null,
      );
    }
  }

  static const double _selaDeeperChillPerHit = 16.0;
  static const int _sableFastActingPerHit = 2;
  static const int _sableFastActingMaxStacks = 8;
  static const int _sableVirulenceMaxStacks = 12;
  static const int _kadeSlowBurnMaxStacks = 3;
  static const double _kadeSlowBurnDuration = 8.0;

  static void _applyOneElement(
    EnemyStore? enemies,
    StatusStore status,
    SimEventBuffer events,
    int slot,
    int target,
    SimElement element,
    double x,
    double y, {
    double? chillPerHitOverride,
    int? toxinStacksPerHitOverride,
    int? toxinMaxStacksOverride,
    int? burnMaxStacksOverride,
    double? burnDurationOverride,
  }) {
    if (enemies != null && enemies.resistsElement(target, element)) return;

    status.apply(
      target,
      element,
      chillPerHitOverride: chillPerHitOverride,
      toxinStacksPerHitOverride: toxinStacksPerHitOverride,
      toxinMaxStacksOverride: toxinMaxStacksOverride,
      burnMaxStacksOverride: burnMaxStacksOverride,
      burnDurationOverride: burnDurationOverride,
    );
    events.emit(
      SimEventType.elementApplied,
      entityA: target,
      entityB: slot,
      valueA: element.index.toDouble(),
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
  /// An arrow that ends without ever connecting breaks the streak.
  ///
  /// *Crescendo* (#15) says "resets on a miss", and a miss has to be defined
  /// somewhere: it is an arrow retiring with no hits, whether it expired or hit
  /// a wall. Defining it as "a tick with no damage" would break the streak
  /// between two arrows in the same volley, and defining it as "the shot was
  /// aimed badly" is not something the simulation can know.
  static void _missed(
    ProjectileStore projectiles,
    CombatModifiers combat,
    int slot,
  ) {
    if (projectiles.hitCount[slot] == 0) combat.hitStreak = 0;
  }

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
