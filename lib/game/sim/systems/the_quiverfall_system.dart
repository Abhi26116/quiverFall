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

/// The Quiverfall — docs/06 §12, chapter 12's boss. "Tests: mastery ·
/// Campaign finale." "The sky itself, falling. Fought on a collapsing
/// arena that loses 8% of its floor per phase."
///
/// Named `TheQuiverfallSystem`, not `QuiverfallSystem` — every other
/// system in this directory drops a card's own leading "The"
/// (`GreenMotherSystem`, `WeepingGateSystem`), but this boss shares its
/// bare name with both the game's own package and *Quiverfall* the Boon
/// (`BoonBehaviour.quiverfall`) — a real naming collision in the design
/// itself, not invented here, worth keeping unambiguous in code.
///
/// **P1 only, built here.** "P1 — The First Shard: A vast descending
/// shard fires converging amber lines from the arena edges. Safe space is
/// the intersection gaps." A single, stationary body at the arena's own
/// centre (every boss arena is still an ordinary room's own arena — ADR
/// 0017/0021's still-open gap) sweeping several lines around itself, all
/// converging on its own position — mechanically, a grander version of
/// Cinder Choir's own P2 tether sweep (ADR 0019): more spokes (8, not 3 —
/// "the arena edges", plural, authored to read as more than Cinder
/// Choir's own triangle), reusing the identical warning-then-lethal,
/// one-telegraph-per-owning-child shape verbatim. A fitting reuse for the
/// campaign's own "greatest hits" finale — see ADR 0032.
///
/// **The "collapsing arena" itself is not built.** "Loses 8% of its floor
/// per *phase*" reads as a phase-transition event, not a P1-internal
/// mechanic — nothing shrinks *during* P1 under this reading, so nothing
/// here needed a floor-shrink system at all. Building one regardless would
/// be a real, sizeable new capability (nothing in `Arena` today changes
/// shape mid-room) that this pass does not attempt; flagged alongside the
/// rest of what P2/P3 need.
///
/// **Not built here: P2 ("The Choir Reforms" — all eleven previous bosses
/// appear as 12s echoes, one at a time, each using a single signature
/// attack) and P3 ("Quiverfall" — the shard shatters into 40 fragments;
/// the boss is invulnerable except when the player's own Windline lattice
/// connects three or more of them, channelling them into the core — "the
/// only fight in the game that *requires* Confluence").** Both are large,
/// scoped pieces of their own: P2 needs a real "echo" primitive (a
/// time-boxed body that borrows another boss's own signature move) this
/// pass does not attempt to generalise from eleven bespoke systems; P3
/// needs a genuinely new kind of conditional invulnerability driven by the
/// *player's* own Windline geometry, not any timer or live-count this
/// session has built before. Once `bossPhase` reaches 1, the sweep stops
/// and every live telegraph is cleared — the same posture every other
/// boss's own undone phases already take.
abstract final class TheQuiverfallSystem {
  /// "The arena edges", plural — authored as more than Cinder Choir's own
  /// three-spoke triangle (ADR 0018), not a GDD-stated count.
  static const int spokeCount = 8;

  /// Authored, not GDD-stated: proportioned against Cinder Choir's own
  /// tether rate (45°/s across 3 spokes 120° apart, ADR 0019) so a fixed
  /// point sees a line sweep past it about as often here (8 spokes 45°
  /// apart, so a slower rate keeps the "safe dwell time between passes"
  /// comparable rather than compressing it eight-fold). Real tuning is a
  /// balance-harness (Phase 14) question, same as every other unproven
  /// cadence this session has flagged. See ADR 0032.
  static const double _sweepRadiansPerSecond = 20 * math.pi / 180;

  /// How far each spoke reaches. Authored, slightly longer than Cinder
  /// Choir's own 9.0 (ADR 0019) to comfortably clear a default 16x9
  /// arena's own corners from a central spawn — no real boss arena exists
  /// yet (ADR 0017/0021's still-open gap).
  static const double _spokeLength = 10.0;

  /// ADR 0008/0019's own reused line-hazard width.
  static const double _spokeWidth = SimConfig.windlineHitWidth;

  /// The Thresher-derived "persistent aura" anchor, reused yet again.
  static const double _damage = 0.09;
  static const double _cooldown = 0.6;

  /// Same magnitude as [_cooldown] — the amber warning window before a
  /// spoke actually starts hitting, docs/06 rule 2's own most-repeated
  /// rule, the identical choice Cinder Choir's own sweep already made.
  static const double _warningSeconds = _cooldown;

  /// Places the boss's central body plus [spokeCount] invisible,
  /// untargetable anchor children — one per spoke, existing solely to own
  /// that spoke's own telegraph (an enemy owns at most one at a time).
  /// Returns the primary's slot, or -1 if the entity pool was full or
  /// [BossArchetype.quiverfall] has no catalogue entry.
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
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.quiverfall);
    if (bossIndex < 0) return -1;

    final EntityId primaryId = store.spawn(EntityKind.enemy);
    if (primaryId.isNone) return -1;
    final int primary = primaryId.index;

    store.posX[primary] = centerX;
    store.posY[primary] = centerY;
    store.radius[primary] = radius;
    store.health[primary] = health;
    store.maxHealth[primary] = health;
    store.contentIndex[primary] = -1;
    events.emit(SimEventType.entitySpawned, entityA: primary, x: centerX, y: centerY);

    enemies.reset(primary);
    enemies.bossIndex[primary] = bossIndex;

    for (int spoke = 0; spoke < spokeCount; spoke++) {
      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      // An accounting anchor, not a body — same shape Cinder Choir's own
      // invisible primary already uses (ADR 0018).
      store.posX[slot] = centerX;
      store.posY[slot] = centerY;
      store.radius[slot] = 0.01;
      store.health[slot] = health;
      store.maxHealth[slot] = health;
      store.contentIndex[slot] = -1;
      events.emit(SimEventType.entitySpawned, entityA: slot, x: centerX, y: centerY);

      enemies.reset(slot);
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = spoke;
      enemies.untargetable[slot] = 1;
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.quiverfall) {
        continue;
      }

      // The primary's own health reached zero this tick. The eight spoke
      // anchors are untargetable and have no death condition of their
      // own — left alone, they would sit alive forever, and the boss
      // room's own "zero alive enemies" clear condition (ADR 0021) would
      // never fire. The same cleanup `CinderChoirSystem._despawnChildren`
      // already does for its own children.
      if (store.health[i] <= 0) {
        _despawnChildren(ctx, i);
        continue;
      }

      // P2/P3 not built yet (see the class doc comment) — frozen, every
      // live spoke telegraph cleared, rather than left mid-sweep forever.
      if (enemies.bossPhase[i] >= 1) {
        _clearSpokes(ctx, i);
        continue;
      }

      _tickSweep(ctx, i, dt);
    }
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

  /// Advances the shared sweep angle, keeps every spoke's own telegraph
  /// pointed the right way, and damages the player on a cooldown once the
  /// warning window has passed — `CinderChoirSystem._tickTetherSweep`
  /// verbatim, just against [spokeCount] spokes instead of three.
  static void _tickSweep(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    enemies.bossSweepAngle[primary] += _sweepRadiansPerSecond * dt;
    if (enemies.bossSweepAngle[primary] > 2 * math.pi) {
      enemies.bossSweepAngle[primary] -= 2 * math.pi;
    }

    final bool warningDone =
        enemies.bossSweepAngle[primary] >= _sweepRadiansPerSecond * _warningSeconds;
    final TelegraphSeverity severity =
        warningDone ? TelegraphSeverity.lethal : TelegraphSeverity.warning;

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
    }

    final double centerX = ctx.entities.posX[primary];
    final double centerY = ctx.entities.posY[primary];
    bool playerHit = false;

    final int high = ctx.entities.highWater;
    for (int j = 0; j < high; j++) {
      if (ctx.entities.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;

      final double angle = 2 * math.pi * enemies.bossChildIndex[j] / spokeCount +
          enemies.bossSweepAngle[primary];
      final double toX = centerX + _spokeLength * math.cos(angle);
      final double toY = centerY + _spokeLength * math.sin(angle);

      if (EnemyAttack.hasTelegraph(ctx, j) &&
          ctx.telegraphs.severityAt(enemies.telegraphSlot[j]) == severity) {
        EnemyAttack.retarget(ctx, j, toX, toY);
        EnemyAttack.extendTelegraph(ctx, j, ctx.now + _cooldown);
      } else {
        EnemyAttack.beginLine(
          ctx,
          j,
          centerX,
          centerY,
          toX,
          toY,
          _spokeWidth,
          _cooldown,
          severity: severity,
        );
      }

      if (warningDone &&
          EnemyAttack.playerOnLine(ctx, centerX, centerY, toX, toY, _spokeWidth)) {
        playerHit = true;
      }
    }

    if (playerHit && enemies.attackCooldown[primary] <= 0) {
      EnemyAttack.damagePlayer(ctx, _damage, source: primary);
      enemies.attackCooldown[primary] = _cooldown;
    }
  }

  static void _clearSpokes(AiContext ctx, int primary) {
    final int high = ctx.entities.highWater;
    for (int j = 0; j < high; j++) {
      if (ctx.entities.alive[j] == 0) continue;
      if (ctx.enemies.bossParent[j] != primary) continue;
      if (EnemyAttack.hasTelegraph(ctx, j)) EnemyAttack.endTelegraph(ctx, j);
    }
  }
}
