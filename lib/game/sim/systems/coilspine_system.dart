import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// Coilspine — docs/06 §6.3, Endless Descent boss #18. Floor 20, 60…
///
/// "×85 HP. A 24-segment serpent. Each segment is individually
/// damageable; destroying segments shortens it and changes its movement
/// pattern. Killing head-first is fast but enrages it; killing tail-first
/// is slow but safe. A genuine risk/reward strategy choice with no
/// correct answer."
///
/// **A genuinely new locomotion pattern — the first chain-following body
/// in the roster.** Every segment is a real, independently-healthed,
/// fully targetable entity (`bossParent`/`bossChildIndex` holding its own
/// ordinal, 0 for the head through 23 for the tail); there is no shared
/// pool. An invisible, untargetable primary — the same "accounting
/// anchor, not a body" shape Cinder Choir's own primary already
/// established (ADR 0018) — holds `BossPhaseSystem`'s own generic health
/// fraction as a live sum of every segment still alive, kept in sync
/// every tick, so the shared three-phase machinery needs no changes at
/// all to work against a body with no single health pool of its own.
///
/// **Following, not a recorded path.** Each tick, every segment scans for
/// the nearest still-alive segment with a smaller ordinal (`bossChildIndex`)
/// and moves toward it whenever the gap exceeds [_segmentSpacing],
/// halting once inside it — a chase-with-standoff rather than a replay of
/// the leader's own recorded trail. This is deliberately *not* a
/// position-history buffer (which would need new per-segment storage and
/// a fixed recording cadence): a live backward ordinal scan is O(24) per
/// segment, cheap at this scale, and — critically — repairs itself for
/// free the instant any segment dies, since the next tick's scan simply
/// finds whichever still-alive segment is now nearest by ordinal. The
/// segment with no living leader at all (ordinal 0, or whichever
/// survivor now has the smallest ordinal once the head is gone) chases
/// the player directly instead — "destroying segments... changes its
/// movement pattern" is this substitution happening live, not a separate
/// mechanic layered on top.
///
/// **"Changes its movement pattern" is read as the whole body growing
/// more agile as it shortens** — the effective head's own speed scales up
/// with how many segments have already died, a fixed multiplier per
/// missing segment. **"Enrages" is a separate, one-way flag**: the moment
/// ordinal 0 (the head) dies while any other segment survives,
/// `comboStep` (free — nothing else in this system touches it) latches
/// permanently, applying its own speed and contact-damage multiplier to
/// every remaining segment for the rest of the fight. Killing tail-first
/// — working inward, leaving the head for last — never sets this flag at
/// all, which is the entire mechanical shape of "no correct answer": a
/// faster kill that trades into a harder finish, against a slower, safer
/// clear.
///
/// **Contact is the whole attack.** Touching any live segment deals the
/// Thresher's own persistent-aura anchor (9%, doubled once enraged) on a
/// single cooldown shared across the whole body — the same "several
/// simultaneous hazards, one shared cooldown" shape Cinder Choir's tether
/// sweep, Arclight's chain, and The Loom's own threads all already use.
/// No separate telegraphed attack is layered on top: the risk in this
/// fight is entirely positional, staying clear of a moving, thrashing
/// body, not reading a wind-up.
///
/// **Every number here — segment speed, spacing, the agility-per-missing-
/// segment bonus, the enrage multiplier — is authored, not GDD-stated**,
/// the same honesty every other Endless boss's own missing
/// `targetDurationSeconds` (ADR 0017) already carries. Real tuning
/// (does the risk/reward genuinely balance in either direction?) is a
/// Phase 14 balance-harness question. See ADR 0058.
abstract final class CoilspineSystem {
  static const int segmentCount = 24;

  static const double _segmentRadius = 0.4;

  /// Authored — a snake-like train, not a solid mass.
  static const double _segmentSpacing = 0.6;

  static const double _headSpeed = 1.5;

  /// Faster than the head, so a follower can genuinely close a gap the
  /// head's own weaving opens up rather than trailing further behind
  /// forever.
  static const double _followSpeed = 3.0;

  /// Authored — "changes its movement pattern" as it shortens.
  static const double _agilityBonusPerMissingSegment = 0.03;

  static const double _enrageSpeedMultiplier = 1.5;
  static const double _enrageDamageMultiplier = 1.5;

  /// The Thresher's own persistent-aura anchor.
  static const double _contactDamage = 0.09;
  static const double _contactCooldownSeconds = 0.6;

  /// Places Coilspine's 24 segments, stacked on the centre point, and an
  /// invisible accounting primary. Returns the primary's own slot, or -1
  /// if the entity pool was full or [BossArchetype.coilspine] has no
  /// catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
  }) {
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.coilspine);
    if (bossIndex < 0) return -1;

    final EntityId primaryId = store.spawn(EntityKind.enemy);
    if (primaryId.isNone) return -1;
    final int primary = primaryId.index;

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

    final double segmentHealth = health / segmentCount;

    for (int ordinal = 0; ordinal < segmentCount; ordinal++) {
      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      // Every segment starts stacked on the centre rather than laid out
      // in a line long enough to clip through a wall for an arbitrary
      // spawn point — the chase-with-standoff behaviour uncoils it into
      // a real trailing train within the first few ticks regardless, so
      // nothing is lost by not authoring an initial pose.
      store.posX[slot] = centerX;
      store.posY[slot] = centerY;
      store.radius[slot] = _segmentRadius;
      store.health[slot] = segmentHealth;
      store.maxHealth[slot] = segmentHealth;
      store.contentIndex[slot] = -1;
      events.emit(SimEventType.entitySpawned, entityA: slot, x: centerX, y: centerY);

      enemies.reset(slot);
      enemies.bossParent[slot] = primary;
      enemies.bossChildIndex[slot] = ordinal;
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.coilspine) {
        continue;
      }

      if (store.health[i] <= 0) {
        _despawnSegments(ctx, i);
        continue;
      }

      int aliveCount = 0;
      bool headAlive = false;
      double healthSum = 0;
      for (int j = 0; j < high; j++) {
        if (store.alive[j] == 0) continue;
        if (enemies.bossParent[j] != i) continue;
        aliveCount++;
        if (enemies.bossChildIndex[j] == 0) headAlive = true;
        healthSum += store.health[j];
      }

      if (aliveCount == 0) {
        // Every segment already gone — the primary follows them.
        store.health[i] = 0;
        continue;
      }

      store.health[i] = healthSum;

      // A one-way latch: once the head has died alongside a survivor,
      // the body stays enraged for the rest of the fight, even if every
      // remaining segment is later killed tail-first.
      if (!headAlive) enemies.comboStep[i] = 1;
      final bool enraged = enemies.comboStep[i] != 0;
      final int missing = segmentCount - aliveCount;

      _tickContactDamage(ctx, i, dt, enraged);

      for (int j = 0; j < high; j++) {
        if (store.alive[j] == 0) continue;
        if (enemies.bossParent[j] != i) continue;
        _tickSegment(ctx, i, j, enemies.bossChildIndex[j], enraged, missing);
      }
    }
  }

  static void _despawnSegments(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      store.despawn(store.idAt(j));
    }
  }

  /// Moves [segSlot] toward the nearest still-alive segment with a
  /// smaller ordinal, halting once within [_segmentSpacing] — or, for
  /// whichever segment has no living leader at all, chases the player
  /// directly.
  static void _tickSegment(
    AiContext ctx,
    int primary,
    int segSlot,
    int ordinal,
    bool enraged,
    int missing,
  ) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    int leaderSlot = -1;
    int bestOrdinal = -1;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      final int oj = enemies.bossChildIndex[j];
      if (oj >= ordinal) continue;
      if (oj > bestOrdinal) {
        bestOrdinal = oj;
        leaderSlot = j;
      }
    }

    final double speedMultiplier = (enraged ? _enrageSpeedMultiplier : 1.0) *
        (1.0 + missing * _agilityBonusPerMissingSegment);

    if (leaderSlot < 0) {
      if (!ctx.hasPlayer) {
        Steering.halt(ctx, segSlot);
        return;
      }
      Steering.faceToward(ctx, segSlot, ctx.playerX, ctx.playerY, 0);
      Steering.moveToward(
          ctx, segSlot, ctx.playerX, ctx.playerY, _headSpeed * speedMultiplier);
      return;
    }

    final double leaderX = store.posX[leaderSlot];
    final double leaderY = store.posY[leaderSlot];
    final double dx = leaderX - store.posX[segSlot];
    final double dy = leaderY - store.posY[segSlot];
    if (dx * dx + dy * dy <= _segmentSpacing * _segmentSpacing) {
      Steering.halt(ctx, segSlot);
      return;
    }

    Steering.faceToward(ctx, segSlot, leaderX, leaderY, 0);
    Steering.moveToward(ctx, segSlot, leaderX, leaderY, _followSpeed * speedMultiplier);
  }

  /// Damages the player for touching any live segment, at most once per
  /// [_contactCooldownSeconds] regardless of how many segments they
  /// touch at once.
  static void _tickContactDamage(AiContext ctx, int primary, double dt, bool enraged) {
    final EnemyStore enemies = ctx.enemies;
    final EntityStore store = ctx.entities;

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }
    if (!ctx.hasPlayer) return;

    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      if (!EnemyAttack.playerInCircle(ctx, store.posX[j], store.posY[j], store.radius[j])) {
        continue;
      }

      final double damage =
          enraged ? _contactDamage * _enrageDamageMultiplier : _contactDamage;
      EnemyAttack.damagePlayer(ctx, damage, source: primary);
      enemies.attackCooldown[primary] = _contactCooldownSeconds;
      return;
    }
  }
}
