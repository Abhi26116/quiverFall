import 'dart:typed_data';

import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_runtime.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/segment_hash.dart';
import 'package:quiverfall/game/sim/windline_store.dart';

/// The Boon behaviours that need a tick.
///
/// Runs at [SystemOrder.boon], after everything that could have changed the
/// player's state this frame and before cleanup — so a shield sized from
/// Momentum is sized from *this* tick's Momentum, and a Blood Pact instalment
/// lands on a player whose health the AI has already touched.
///
/// Behaviours that fire at a moment rather than continuously live where that
/// moment is: survival at [EnemyAttack.damagePlayer], arrow behaviour in
/// [ProjectileSystem], element and volley behaviour at the point of firing.
/// Putting them all here would mean this system reaching into every other one.
abstract final class BoonSystem {
  static void update({
    required BoonRuntime boons,
    required EntityStore entities,
    required DrawState draw,
    required SimEventBuffer events,
    required int player,
    required bool isMoving,
    required double maxHealth,
    required double shieldPerMomentum,
    required double regenWhileMoving,
    required double dt,
  }) {
    _tickTimers(boons, dt);

    if (player < 0 || entities.alive[player] == 0) return;

    _momentum(boons, draw);
    _shield(boons, draw, maxHealth, shieldPerMomentum);
    _regen(entities, player, isMoving, regenWhileMoving, maxHealth, dt);
    _bloodPact(boons, entities, events, player, dt);
  }

  /// What a Windline does to an enemy standing on it.
  ///
  /// Three cards share this pass because they share the query: *Tangle* (#63)
  /// slows, *Cutting Lines* (#66) damages, and *Sunthread* (#73) does both and
  /// blinds. Running three separate passes over the same segment hash would
  /// cost three times as much for the same answer.
  ///
  /// The whole pass is skipped when no card that needs it is held, which is
  /// almost every build.
  static void applyWindlineField({
    required BoonRuntime boons,
    required EntityStore entities,
    required EnemyStore enemies,
    required WindlineStore lines,
    required SegmentHash index,
    required double slow,
    required double damageFraction,
    required double dt,
    bool hasShadowline = false,
  }) {
    final bool sunthread = boons.has(BoonBehaviour.sunthread);
    if (slow <= 0 && damageFraction <= 0 && !sunthread && !hasShadowline) {
      return;
    }

    final int high = entities.highWater;
    for (int i = 0; i < high; i++) {
      if (entities.alive[i] == 0) continue;
      if (entities.kind[i] != EntityKind.enemy.index) continue;

      final double x = entities.posX[i];
      final double y = entities.posY[i];
      final double r = entities.radius[i];

      final int found = index.querySegment(x, y, x, y, r, _scratch);
      bool standing = false;
      bool standingOnShadowline = false;
      for (int c = 0; c < found; c++) {
        final int seg = _scratch[c];
        if (!lines.isAlive(seg)) continue;
        // Only the player's own trails. An enemy standing on another enemy's
        // line is not something this game has, but the owner check is what
        // makes that stay true when the Hollow Warden arrives in docs/06.
        if (lines.ownerAt(seg) != _playerOwner) continue;
        if (_pointNearSegment(x, y, lines.x0(seg), lines.y0(seg), lines.x1(seg),
            lines.y1(seg), r)) {
          standing = true;
          if (lines.isShadowlineAt(seg)) standingOnShadowline = true;
        }
      }
      if (!standing) continue;

      if (slow > 0 || sunthread) {
        // Multiplied into the live speed scale rather than assigned, so it
        // stacks correctly with a variant's own speed bonus and expires with
        // the AI's own recomputation next tick.
        final double factor = 1.0 - (sunthread ? slow + 0.10 : slow);
        enemies.windlineSlowFactor[i] = factor < 0.1 ? 0.1 : factor;
      }

      if (damageFraction > 0 || sunthread || standingOnShadowline) {
        // *Shadowline* (Nyx, T3a) — a tagged segment damages on its own
        // rate (ADR 0010), on top of whatever Cutting-Lines-shaped share the
        // build already has, exactly like Sunthread's own bonus above it.
        final double share = damageFraction +
            (sunthread ? _sunthreadDamageFraction : 0) +
            (standingOnShadowline ? _nyxShadowlineDamageFraction : 0);
        entities.health[i] -= entities.maxHealth[i] * share * dt;
      }

      if (sunthread) {
        // Blinded enemies lose their aim, which is what makes Sunthread a
        // defensive card as well as a damaging one.
        enemies.blindRemaining[i] = _sunthreadBlindSeconds;
      }
    }
  }

  /// Sunthread's own damage, on top of any Cutting Lines share.
  static const double _sunthreadDamageFraction = 0.010;
  static const double _sunthreadBlindSeconds = 0.6;

  /// ADR 0010 — docs/07 gives Shadowline no rate; this borrows the same one
  /// Iris's own Cutting Lines and Boon #66 already ship.
  static const double _nyxShadowlineDamageFraction = 0.02;

  /// Windlines the player laid. Matches `ProjectileSystem`'s owner id.
  static const int _playerOwner = 0;

  static final Int32List _scratch = Int32List(64);

  static bool _pointNearSegment(double px, double py, double ax, double ay,
      double bx, double by, double radius) {
    final double dx = bx - ax;
    final double dy = by - ay;
    final double lenSq = dx * dx + dy * dy;
    double t = lenSq <= 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / lenSq;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final double cx = ax + dx * t;
    final double cy = ay + dy * t;
    final double ox = px - cx;
    final double oy = py - cy;
    return ox * ox + oy * oy <= radius * radius;
  }

  static void _tickTimers(BoonRuntime boons, double dt) {
    if (boons.covenantRemaining > 0) boons.covenantRemaining -= dt;
    if (boons.invulnerableRemaining > 0) boons.invulnerableRemaining -= dt;

    if (boons.dashCooldown > 0) {
      boons.dashCooldown -= dt;
      // *Blink* (#53) recharges one of its two charges when the shared
      // cooldown completes, rather than both at once — the standard
      // charge-ability model, and the reading of "2 charges" that needs no
      // number beyond the one *Dash* already gives.
      if (boons.dashCooldown <= 0 &&
          boons.has(BoonBehaviour.blink) &&
          boons.blinkCharges < BoonRuntime.blinkChargeCount) {
        boons.blinkCharges++;
        if (boons.blinkCharges < BoonRuntime.blinkChargeCount) {
          boons.dashCooldown = BoonRuntime.dashCooldownSeconds;
        }
      }
    }
  }

  /// *Momentum Engine* (#54) and *Perpetual* (#58).
  ///
  /// Both are handled by making the *stop* not count rather than by adding
  /// stacks: Momentum Engine holds `sinceStoppedSeconds` at zero so the grace
  /// window never elapses, and Perpetual additionally leaves the Draw running.
  /// Granting stacks directly would let them exceed `maxMomentum` and would
  /// double-count against Light Boots.
  static void _momentum(BoonRuntime boons, DrawState draw) {
    if (boons.has(BoonBehaviour.momentumEngine) ||
        boons.has(BoonBehaviour.perpetual)) {
      draw.sinceStoppedSeconds = 0;
    }

    // Perpetual's *Draw* half is handled inside DrawSystem, by not resetting
    // rather than by adding the time back here. DrawSystem zeroes drawSeconds
    // on every moving tick, so anything downstream would only ever see a single
    // frame's worth — which reads as "Perpetual does nothing" and is the exact
    // shape of bug this comment exists to stop being reintroduced.
  }

  /// *Shieldweave* (#33). Recomputed from live Momentum rather than granted on
  /// each stack gain, so losing Momentum loses the shield with it — a shield
  /// that survived the stacks that bought it would be a much stronger card.
  static void _shield(
    BoonRuntime boons,
    DrawState draw,
    double maxHealth,
    double shieldPerMomentum,
  ) {
    if (shieldPerMomentum <= 0) {
      boons.shield = 0;
      return;
    }
    final double capacity =
        maxHealth * shieldPerMomentum * draw.momentumStacks;
    // Grows to capacity but is not refilled by it: damage already absorbed
    // stays absorbed until the stacks that paid for it are re-earned.
    if (boons.shield > capacity) boons.shield = capacity;
  }

  /// *Regrowth* (#36). Heals only while moving, which is the point.
  static void _regen(
    EntityStore entities,
    int player,
    bool isMoving,
    double regenWhileMoving,
    double maxHealth,
    double dt,
  ) {
    if (!isMoving || regenWhileMoving <= 0) return;
    final double healed =
        entities.health[player] + maxHealth * regenWhileMoving * dt;
    entities.health[player] = healed > maxHealth ? maxHealth : healed;
  }

  /// *Blood Pact* (#41). Pays the deferred damage out over time.
  ///
  /// The kill that cancels it is handled where kills are known — see
  /// [cancelDeferred].
  static void _bloodPact(
    BoonRuntime boons,
    EntityStore entities,
    SimEventBuffer events,
    int player,
    double dt,
  ) {
    if (boons.deferredRemaining <= 0 || boons.deferredDamage <= 0) return;

    final double instalment =
        boons.deferredDamage * (dt / boons.deferredRemaining).clamp(0.0, 1.0);
    boons.deferredDamage -= instalment;
    boons.deferredRemaining -= dt;
    entities.health[player] -= instalment;

    if (boons.deferredRemaining <= 0) {
      boons.deferredDamage = 0;
    }

    if (entities.health[player] <= 0) {
      events.emit(
        SimEventType.entityDied,
        entityA: player,
        x: entities.posX[player],
        y: entities.posY[player],
      );
      entities.despawn(entities.idAt(player));
    }
  }

  /// *Blood Pact*'s escape clause: a kill cancels the outstanding debt.
  ///
  /// Called from the death pass rather than polled here, because "a kill
  /// happened" is knowledge the AI system has and this one does not.
  static void cancelDeferred(BoonRuntime boons) {
    if (!boons.has(BoonBehaviour.bloodPact)) return;
    boons.deferredDamage = 0;
    boons.deferredRemaining = 0;
  }

  /// *Shieldweave* again: called when Momentum *rises*, to top the shield up.
  static void refillShield(
    BoonRuntime boons,
    DrawState draw,
    double maxHealth,
    double shieldPerMomentum,
  ) {
    if (shieldPerMomentum <= 0) return;
    boons.shield = maxHealth * shieldPerMomentum * draw.momentumStacks;
  }
}
