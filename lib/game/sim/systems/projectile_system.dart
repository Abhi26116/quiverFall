import 'dart:math' as math;

import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
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

      // Walls stop arrows outright. Cover blocks projectiles but not movement,
      // which is what makes "break line of sight" a real answer to Longeye.
      if (arena.circleHitsWall(toX, toY, store.radius[i]) ||
          !arena.containsPoint(toX, toY)) {
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

  // ── Nyx: First Blood ──────────────────────────────────────────────────────

  static const double _nyxFirstBloodFullHealthThreshold = 0.90;
  static const double _nyxFirstBloodBonus = 0.70;
  static const double _nyxExecutionersEyeThreshold = 0.20;
  static const double _nyxExecutionersEyeBonus = 0.35;

  // ── Vane: Distance ─────────────────────────────────────────────────────────

  static const double _vaneCloseRangeThreshold = 3.0;
  static const double _vaneCloseRangePenalty = -0.30;

  // ── Halden: Verdict ────────────────────────────────────────────────────────

  static const double _haldenVerdictEliteBonus = 0.40;

  // ── Lira: Lifebound ────────────────────────────────────────────────────────

  static const double _liraLifeboundTierThreeBonus = 0.02;

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
    required CombatModifiers combat,
    required BoonRuntime boons,
    HeroRuntime? hero,
    int player = -1,
    double lifesteal = 0,
  }) {
    final int pierceIndex = projectiles.hitCount[slot];
    projectiles.recordHit(slot, targetId);

    final DrawTier tier = DrawTier.values[projectiles.drawTier[slot]];

    // Armour is resolved here, not at fire time: the arrow carries the tier it
    // was fired at, and the plate state is read from the target now.
    double armour = _armourFor(store, enemies, target, tier, fromX, fromY);

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
    final int effectivePierceIndex = deadeye ? 0 : pierceIndex;

    // The build's conditional terms, resolved against *this* target and *this*
    // shot. They sum into one `boonDamageSum` rather than each multiplying the
    // total — docs/04 §4.1 rule 1, and the reason a twenty-Boon run is linear.
    final double maxHp = store.maxHealth[target];
    final double targetHealthFraction =
        maxHp > 0 ? store.health[target] / maxHp : 1.0;

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

    // Streak and last-target are updated after the hit is resolved, so
    // *Follow Through* rewards the arrow *after* the one that landed and
    // *Crescendo* counts this hit toward the next.
    combat.hitStreak++;
    combat.lastHitTarget = targetId;

    // *Cull* (#20) finishes anything left below its threshold. Non-elites only:
    // an execute that worked on Riftborn would delete the roster's mechanics
    // rather than reward clearing fodder.
    if (boons.has(BoonBehaviour.cull) &&
        enemies != null &&
        !enemies.isElite(target) &&
        store.health[target] > 0 &&
        store.health[target] <
            store.maxHealth[target] * BoonRuntime.cullThreshold) {
      store.health[target] = 0;
    }

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
      final double healed = store.health[player] + toHealth * effectiveLifesteal;
      final double cap = store.maxHealth[player];
      store.health[player] = healed > cap ? cap : healed;
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

    void applyIfNotAlreadyCarried(SimElement element) {
      final int mask = projectiles.elementMask[slot];
      final int index = projectiles.element[slot];
      final bool alreadyCarried = mask != 0
          ? (mask & (1 << element.index)) != 0
          : index == element.index;
      if (alreadyCarried) return;
      _applyOneElement(enemies, status, events, slot, target, element, x, y);
    }

    if (tier == DrawTier.three && hero.has(HeroBehaviour.kadeKindling)) {
      applyIfNotAlreadyCarried(SimElement.ember);
    }
    if (hero.has(HeroBehaviour.selaChill)) {
      applyIfNotAlreadyCarried(SimElement.frost);
    }
    if (hero.has(HeroBehaviour.sableToxin)) {
      applyIfNotAlreadyCarried(SimElement.toxin);
    }
  }

  static void _applyOneElement(
    EnemyStore? enemies,
    StatusStore status,
    SimEventBuffer events,
    int slot,
    int target,
    SimElement element,
    double x,
    double y,
  ) {
    if (enemies != null && enemies.resistsElement(target, element)) return;

    status.apply(target, element);
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
