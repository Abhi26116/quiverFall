import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// Skarn the Unmade — docs/06 §11, chapter 11's boss. "Tests: split
/// attention."
///
/// **P1: "Single heavy body, slow, enormous telegraphs."** A slow advance
/// (`Steering.moveToward`/`faceToward`, the same primitives Gaunt's own
/// "slow advance" already uses) into a heavy circular slam once the player
/// is in range — an ordinary wind-up/resolve/cooldown cycle, the same
/// shape every other boss's own single attack already takes, just with a
/// wind-up several times longer than usual (1.8s against the roster's own
/// 0.6s baseline) and a correspondingly large radius, matching "enormous
/// telegraphs" literally: the bigger the tell, the more room there is to
/// misjudge the dodge. Damage is derived, not invented — the Thresher's
/// own 9% anchor scaled by Tier III's own 2.10x multiplier, the identical
/// "how heavy is heavy" derivation Hollow Warden's own shot already uses
/// (ADR 0031) — reused again here for the second "heavy hit" in the
/// roster rather than a third independently-guessed number. This attack
/// runs only in P1 (`bossPhase == 0`); once splitting begins, the fight is
/// entirely the pressure mechanic below, unchanged from what already
/// shipped. See ADR 0034.
///
/// **P2/P3:** "Splits into two halves [then four] at 66%[/33%], sharing one
/// HP pool. Damaging only one causes the other to heal it at 3%/s." Reuses
/// Cinder Choir's own shared-pool primitives (`EnemyStore.linkedHealthSlot`/
/// `bossParent`) unmodified — the genuinely new piece is the *pressure*
/// mechanic: each body tracks its own `bossLastHitAgo`, and any body that
/// has gone too long unhit heals the shared pool on its own, independent of
/// the others. See ADR 0022.
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

  // ── P1: the heavy slam ──────────────────────────────────────────────────
  // See ADR 0034 for the full reasoning behind every number below.

  /// Slower than Gaunt's own 1.0 u/s "slow advance" (ADR 0023) — "single
  /// heavy body, slow" reads as slower than a merely deliberate one.
  static const double _p1MoveSpeed = 0.8;

  /// "Enormous telegraphs" read literally: several times the roster's own
  /// 0.6s baseline wind-up.
  static const double _p1WindUpSeconds = 1.8;

  /// Authored — large enough to threaten a default 16x9 arena's own
  /// working space (no boss arena exists yet, ADR 0017/0021), and to read
  /// as "enormous" next to Thrall's own 2.0u circle ability.
  static const double _p1SlamRadius = 3.0;

  /// Authored — "slow" applies to the cooldown too, not just the
  /// footwork.
  static const double _p1CooldownSeconds = 2.0;

  /// Derived, not guessed: the Thresher's own 9% anchor scaled by Tier
  /// III's own 2.10x damage multiplier — the same "how heavy is heavy"
  /// derivation Hollow Warden's own shot already uses (ADR 0031).
  static const double _p1SlamDamage = 0.09 * 2.10;

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

      // The heavy slam runs only in P1; once splitting begins the fight
      // is entirely the pressure mechanic below, unchanged from what
      // already shipped (ADR 0022).
      if (phase == 0) {
        _tickP1Slam(ctx, i, dt);
      } else {
        _tickPressure(ctx, i, dt);
      }
    }
  }

  /// The wind-up/resolve/cooldown cycle behind "slow, enormous
  /// telegraphs": close the distance, plant its feet once the player is in
  /// range, and slam. See ADR 0034.
  static void _tickP1Slam(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (enemies.stateOf(primary) == AiState.windUp) {
      Steering.halt(ctx, primary);
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;
      _resolveSlam(ctx, primary);
      enemies.state[primary] = AiState.idle.index;
      enemies.attackCooldown[primary] = _p1CooldownSeconds;
      return;
    }

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, primary);
      return;
    }

    Steering.faceToward(ctx, primary, ctx.playerX, ctx.playerY, 0);

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      Steering.moveToward(ctx, primary, ctx.playerX, ctx.playerY, _p1MoveSpeed);
      return;
    }

    if (ctx.distanceSquaredToPlayer(primary) <= _p1SlamRadius * _p1SlamRadius) {
      Steering.halt(ctx, primary);
      enemies.state[primary] = AiState.windUp.index;
      enemies.stateTimer[primary] = _p1WindUpSeconds;
      EnemyAttack.beginCircle(
        ctx,
        primary,
        store.posX[primary],
        store.posY[primary],
        _p1SlamRadius,
        _p1WindUpSeconds,
      );
      return;
    }

    Steering.moveToward(ctx, primary, ctx.playerX, ctx.playerY, _p1MoveSpeed);
  }

  static void _resolveSlam(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final double x = store.posX[primary];
    final double y = store.posY[primary];

    EnemyAttack.beginCircle(
      ctx,
      primary,
      x,
      y,
      _p1SlamRadius,
      0,
      severity: TelegraphSeverity.lethal,
    );
    if (EnemyAttack.playerInCircle(ctx, x, y, _p1SlamRadius)) {
      EnemyAttack.damagePlayer(ctx, _p1SlamDamage, source: primary);
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
