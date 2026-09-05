import 'package:quiverfall/game/balance/damage.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/companion_store.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/systems/firing_system.dart';

/// A friendly, independently-acting body fighting alongside the player —
/// Zea's own Skyhawk/Falconry and Mirelle's own Hall of Mirrors clone
/// (docs/07 §7.3, the first kits in this roster needing one). Generic on
/// purpose: nothing here is hero-specific, the same "primitive here,
/// hero-specific numbers at the caller" split every other shared system in
/// this codebase already draws. See `CompanionStore` and ADR 0071.
///
/// **Companion damage is deliberately simple, not routed through
/// `ProjectileSystem`.** Every companion card states a bare percentage of
/// ATK or of the player's own stats ("35 % of hero ATK", "60 % stats"),
/// never a number modified by the player's own current Draw tier, Boon
/// `boonSum`, or pierce falloff — the pipeline built for the player's own
/// arrow. Routing a companion's hit through that pipeline would silently
/// let it inherit bonuses no card asks for (an "every arrow explodes"
/// Boon, an elemental arrow's own element) and would mean threading a new
/// "this hit is not really the player's own arrow" branch through the
/// single most shared, most heavily tested function in the combat
/// pipeline — the same class of risk this roster has avoided everywhere
/// else. Instead a companion's shot resolves instantly (no travelling
/// arrow to sweep-collide) the moment its own cooldown allows: shield,
/// then plate, then health, the identical order `ProjectileSystem._applyHit`
/// already uses, with no boonSum term at all.
///
/// **"Its shots lay Windlines the player can Confluence through" needed no
/// new Confluence logic.** A companion's own Windline segment is added
/// under the exact sentinel (`ownerIndex: 0`) every consumer of
/// `WindlineStore.ownerAt` already treats as "the player's own trail" — so
/// it is indistinguishable from a segment the player laid themselves
/// everywhere Confluence already checks, the same "read the store's own
/// existing owner convention" trick this roster has reused for every
/// Windline-laying enemy so far (Hollow Warden, The Last Warden).
abstract final class CompanionSystem {
  static const int _playerLineOwner = 0;

  /// Authored — docs/07 states no hover formation, so companions spread
  /// around the player rather than stacking on one point.
  static const double _followSpeed = 4.5;
  static const double _arrivedDistanceSq = 0.04;

  /// Places a single companion. Returns its slot, or -1 if the entity pool
  /// was full.
  ///
  /// [lifetimeSeconds] left at its default (`double.infinity`) makes a
  /// permanent companion (Zea's own passive Skyhawk); a finite value makes
  /// a timed summon (Falconry's own extra hawks, Mirelle's own clone).
  static int spawn({
    required EntityStore store,
    required CompanionStore companions,
    required SimEventBuffer events,
    required double x,
    required double y,
    required double damageShare,
    required double fireRate,
    double radius = 0.35,
    double lifetimeSeconds = double.infinity,
    bool alwaysCrit = false,
    double followOffsetX = 0,
    double followOffsetY = 0,
  }) {
    final EntityId id = store.spawn(EntityKind.companion);
    if (id.isNone) return -1;
    final int slot = id.index;

    store.posX[slot] = x;
    store.posY[slot] = y;
    store.radius[slot] = radius;
    store.health[slot] = 1;
    store.maxHealth[slot] = 1;
    store.contentIndex[slot] = -1;
    events.emit(SimEventType.entitySpawned, entityA: slot, x: x, y: y);

    companions.reset(slot);
    companions.damageShare[slot] = damageShare;
    companions.fireIntervalSeconds[slot] =
        fireRate > 0 ? 1.0 / fireRate : double.infinity;
    companions.remaining[slot] = lifetimeSeconds;
    companions.alwaysCrit[slot] = alwaysCrit ? 1 : 0;
    companions.followOffsetX[slot] = followOffsetX;
    companions.followOffsetY[slot] = followOffsetY;

    return slot;
  }

  static void update(AiContext ctx, CompanionStore companions) {
    final EntityStore store = ctx.entities;
    final int high = store.highWater;

    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.companion.index) continue;

      // A permanent companion's own `remaining` is `double.infinity`,
      // which this comparison — and the subtraction below it — never
      // reaches zero from.
      if (companions.remaining[i] < double.infinity) {
        companions.remaining[i] -= ctx.dt;
        if (companions.remaining[i] <= 0) {
          store.despawn(store.idAt(i));
          continue;
        }
      }

      if (!ctx.hasPlayer) {
        store.velX[i] = 0;
        store.velY[i] = 0;
        if (companions.attackCooldown[i] > 0) {
          companions.attackCooldown[i] -= ctx.dt;
        }
        continue;
      }

      _tickFollow(ctx, i, companions);
      _tickFire(ctx, i, companions);
    }
  }

  static void _tickFollow(AiContext ctx, int slot, CompanionStore companions) {
    final EntityStore store = ctx.entities;
    final double targetX = ctx.playerX + companions.followOffsetX[slot];
    final double targetY = ctx.playerY + companions.followOffsetY[slot];

    final double dx = targetX - store.posX[slot];
    final double dy = targetY - store.posY[slot];
    if (dx * dx + dy * dy <= _arrivedDistanceSq) {
      Steering.halt(ctx, slot);
      return;
    }
    Steering.moveToward(ctx, slot, targetX, targetY, _followSpeed, separate: false);
  }

  static void _tickFire(AiContext ctx, int slot, CompanionStore companions) {
    if (companions.attackCooldown[slot] > 0) {
      companions.attackCooldown[slot] -= ctx.dt;
      return;
    }

    final EntityStore store = ctx.entities;
    final double fromX = store.posX[slot];
    final double fromY = store.posY[slot];

    final int target = FiringSystem.selectTarget(
      store,
      ctx.spatial,
      fromX,
      fromY,
      enemies: ctx.enemies,
    );
    // No target, no shot — the same "auto-fire is not auto-waste"
    // posture `SimWorld._updateFiring` already holds the player's own
    // bow to; the cooldown is left untouched so a target that appears a
    // moment later fires immediately rather than owing a backlog.
    if (target < 0) return;

    companions.attackCooldown[slot] = companions.fireIntervalSeconds[slot];

    double damage = ctx.playerAttack * companions.damageShare[slot];
    if (companions.alwaysCrit[slot] == 1 &&
        ctx.playerDraw?.tier == DrawTier.three) {
      damage *= ctx.combat?.critMultiplier ?? DamageResolver.baseCritMultiplier;
    }

    final EnemyStore enemies = ctx.enemies;
    double toHealth = damage;
    toHealth = enemies.absorb(target, toHealth);
    enemies.wearPlate(target, toHealth);
    if (toHealth > 0) enemies.bossLastHitAgo[target] = 0;
    store.health[target] -= toHealth;

    ctx.events.emit(
      SimEventType.damageDealt,
      entityA: target,
      entityB: slot,
      valueA: toHealth,
      x: store.posX[target],
      y: store.posY[target],
    );

    // "Its shots lay Windlines the player can Confluence through" — see
    // the class doc comment for why `_playerLineOwner` alone is the whole
    // mechanism.
    ctx.lines.add(
      fromX: fromX,
      fromY: fromY,
      toX: store.posX[target],
      toY: store.posY[target],
      expiresAt: ctx.now + SimConfig.windlineDuration,
      ownerIndex: _playerLineOwner,
      trailId: ctx.nextEchoTrailId(),
    );
  }
}
