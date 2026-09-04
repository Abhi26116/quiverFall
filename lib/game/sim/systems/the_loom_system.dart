import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/windline_store.dart';

/// The Loom — docs/06 §6.3, Endless Descent boss #17. Floor 10, 30, 50…
///
/// "Weaves a slowly tightening lattice of crimson threads across the
/// arena; the survivable area shrinks to ~15% by phase 3. **Player
/// Windlines cut threads.** The purest expression of the game's mechanic
/// as a survival tool rather than a damage tool."
///
/// **Threads are placed, persistent line hazards — the same
/// "untargetable child owns one telegraph" shape Silversong's own
/// pillars (ADR 0036) and every other placed-object boss in this roster
/// already use**, spanning two random points on the arena's own
/// perimeter (`_randomPerimeterPoint`) rather than a fixed grid, since a
/// woven lattice reads as room-spanning diagonals, not a regular pattern.
/// Each thread's own telegraph is given a deliberately long lead
/// ([_threadLifetimeSeconds]) so it never expires on its own — the only
/// way a thread goes away is being cut. New threads accumulate on an
/// escalating cadence across all three phases (faster in P2, faster
/// still in P3, the same "one mechanic, escalating rate" shape Mother of
/// Motes already established, ADR 0056) up to [_threadCap], which is
/// what makes "shrinks to ~15% by phase 3" a real, felt outcome rather
/// than a fixed number this system enforces directly — nothing here
/// computes a literal percentage of arena area; the safe fraction is a
/// natural consequence of how many threads survive at once.
///
/// **"Player Windlines cut threads" reuses the exact crossing-detection
/// shape Hollow Warden's own Discord already established (ADR 0053)**,
/// checked incrementally: `comboStep` (free — nothing else in this file
/// touches it) holds the last-seen player-Windline serial, so only
/// segments newer than that checkpoint are tested against every live
/// thread each tick, the same "read the store's own serial ordering"
/// trick rather than a full rescan. A crossing found this way ends that
/// thread's own telegraph and despawns its owning child outright — no
/// damage, no detonation, just removal, matching "a survival tool rather
/// than a damage tool" literally: cutting a thread is purely defensive,
/// never a way to hurt the boss.
///
/// **Standing on a live thread deals the Thresher's own persistent-aura
/// anchor (9%), on a single shared cooldown across every thread at
/// once** (`attackCooldown`) — the same "several simultaneous line
/// hazards, one damage cooldown" shape Cinder Choir's tether sweep and
/// Arclight's chain both already use. The Loom's own body neither moves
/// nor attacks directly — every bit of this fight's own threat is the
/// lattice itself, which is what "the purest expression of the
/// mechanic as a survival tool" means read literally: there is no
/// damage-tool half of this boss at all.
///
/// **The exact thread-add cadence and cap are authored, not GDD-stated**
/// — like every Endless boss, docs/06 gives no fight length to size a
/// rate against (`targetDurationSeconds` is nullable for the whole tier,
/// ADR 0017), and no exact thread count either. Real tuning (does the
/// stated ~15% actually fall out of these numbers against a realistic
/// cutting rate?) is a Phase 14 balance-harness question. See ADR 0057.
abstract final class TheLoomSystem {
  /// Authored — escalates roughly 1.5-2x each phase, the same "one
  /// mechanic, escalating" shape Mother of Motes already established.
  static const double _threadIntervalP1 = 3.0;
  static const double _threadIntervalP2 = 1.8;
  static const double _threadIntervalP3 = 1.0;

  /// Authored — beyond this a phone screen reads as solid crimson rather
  /// than a lattice with real gaps in it.
  static const int _threadCap = 24;

  /// A deliberately long lead — long enough that nothing in a normal
  /// fight ever reaches it — since a thread is only ever removed by
  /// being cut, never by its own clock running out.
  static const double _threadLifetimeSeconds = 999.0;

  /// ADR 0008/0019's own reused line-hazard width.
  static const double _threadWidth = SimConfig.windlineHitWidth;

  /// The Thresher's own persistent-aura anchor — ongoing space-denial
  /// pressure, not the roster's own heavy hit; this card's own difficulty
  /// is staying out of the lattice, not surviving one big strike.
  static const double _threadDamage = 0.09;

  /// The roster's own established tick magnitude, reused for the shared
  /// damage cooldown across every live thread at once.
  static const double _threadDamageCooldownSeconds = 0.6;

  /// The sentinel every consumer of `WindlineStore.ownerAt` already
  /// treats as "the player's own trail" (`ProjectileSystem`'s own
  /// private `_playerOwner`).
  static const int _playerLineOwner = 0;

  /// Places The Loom's single, stationary body. Returns its slot, or -1
  /// if the entity pool was full or [BossArchetype.theLoom] has no
  /// catalogue entry.
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
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.theLoom);
    if (bossIndex < 0) return -1;

    final EntityId id = store.spawn(EntityKind.enemy);
    if (id.isNone) return -1;
    final int slot = id.index;

    store.posX[slot] = centerX;
    store.posY[slot] = centerY;
    store.radius[slot] = radius;
    store.health[slot] = health;
    store.maxHealth[slot] = health;
    store.contentIndex[slot] = -1;
    events.emit(SimEventType.entitySpawned, entityA: slot, x: centerX, y: centerY);

    enemies.reset(slot);
    enemies.bossIndex[slot] = bossIndex;
    enemies.bossTimer[slot] = _threadIntervalP1;

    return slot;
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.theLoom) {
        continue;
      }

      // The primary's own health reached zero this tick. Threads are
      // untargetable and have no death condition of their own — left
      // alone, they would sit alive forever, and the boss room's own
      // "zero alive enemies" clear condition (ADR 0021) would never
      // fire. The same cleanup every multi-body boss's own
      // `_despawnChildren` already does.
      if (store.health[i] <= 0) {
        _despawnThreads(ctx, i);
        continue;
      }

      _tickThreadGrowth(ctx, i, dt);
      _tickCutting(ctx, i);
      _tickThreadDamage(ctx, i, dt);
    }
  }

  static void _despawnThreads(AiContext ctx, int primary) {
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

  /// Adds a fresh thread on an escalating cadence, up to [_threadCap].
  static void _tickThreadGrowth(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    final double interval = switch (enemies.bossPhase[primary]) {
      0 => _threadIntervalP1,
      1 => _threadIntervalP2,
      _ => _threadIntervalP3,
    };

    enemies.bossTimer[primary] -= dt;
    if (enemies.bossTimer[primary] > 0) return;
    enemies.bossTimer[primary] += interval;

    if (_countThreads(ctx, primary) >= _threadCap) return;
    _spawnThread(ctx, primary);
  }

  static int _countThreads(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    int count = 0;
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.bossParent[j] != primary) continue;
      count++;
    }
    return count;
  }

  static void _spawnThread(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final EntityId id = store.spawn(EntityKind.enemy);
    if (id.isNone) return;
    final int slot = id.index;

    final ({double x, double y}) from = _randomPerimeterPoint(ctx);
    final ({double x, double y}) to = _randomPerimeterPoint(ctx);

    store.posX[slot] = (from.x + to.x) / 2;
    store.posY[slot] = (from.y + to.y) / 2;
    store.radius[slot] = 0.01;
    store.health[slot] = store.maxHealth[primary];
    store.maxHealth[slot] = store.maxHealth[primary];
    store.contentIndex[slot] = -1;
    ctx.events.emit(
      SimEventType.entitySpawned,
      entityA: slot,
      x: store.posX[slot],
      y: store.posY[slot],
    );

    enemies.reset(slot);
    enemies.bossParent[slot] = primary;
    // `bossActiveChildIndex` is a running "how many threads ever placed"
    // ordinal here — free, since this boss's own rotation never needs
    // it the way a cycling-attack boss's primary would.
    enemies.bossChildIndex[slot] = enemies.bossActiveChildIndex[primary]++;
    enemies.untargetable[slot] = 1;

    EnemyAttack.beginLine(
      ctx,
      slot,
      from.x,
      from.y,
      to.x,
      to.y,
      _threadWidth,
      _threadLifetimeSeconds,
      severity: TelegraphSeverity.lethal,
    );
  }

  static ({double x, double y}) _randomPerimeterPoint(AiContext ctx) {
    final double w = ctx.arena.width;
    final double h = ctx.arena.height;
    return switch (ctx.rng.nextInt(4)) {
      0 => (x: ctx.rng.nextDoubleRange(0, w), y: 0.0),
      1 => (x: ctx.rng.nextDoubleRange(0, w), y: h),
      2 => (x: 0.0, y: ctx.rng.nextDoubleRange(0, h)),
      _ => (x: w, y: ctx.rng.nextDoubleRange(0, h)),
    };
  }

  /// Tests every player-Windline segment newer than the last checkpoint
  /// against every live thread, cutting (ending the telegraph and
  /// despawning the owning child) on a genuine crossing — the same
  /// parametric test Hollow Warden's own Discord already established
  /// (ADR 0053), reused rather than reimplemented a third time by
  /// exposing it there and importing it here.
  static void _tickCutting(AiContext ctx, int primary) {
    final EnemyStore enemies = ctx.enemies;
    final EntityStore store = ctx.entities;
    final WindlineStore lines = ctx.lines;

    final int lastSerial = enemies.comboStep[primary];
    int maxSerial = lastSerial;

    final int cap = lines.capacity;
    for (int s = 0; s < cap; s++) {
      if (!lines.isAlive(s)) continue;
      if (lines.ownerAt(s) != _playerLineOwner) continue;
      final int serial = lines.serialAt(s);
      if (serial > maxSerial) maxSerial = serial;
      if (serial <= lastSerial) continue;

      final int high = store.highWater;
      for (int j = 0; j < high; j++) {
        if (store.alive[j] == 0) continue;
        if (enemies.bossParent[j] != primary) continue;
        if (!EnemyAttack.hasTelegraph(ctx, j)) continue;

        final int t = enemies.telegraphSlot[j];
        final bool crosses = _segmentsCross(
          lines.x0(s),
          lines.y0(s),
          lines.x1(s),
          lines.y1(s),
          ctx.telegraphs.xAt(t),
          ctx.telegraphs.yAt(t),
          ctx.telegraphs.toXAt(t),
          ctx.telegraphs.toYAt(t),
        );
        if (!crosses) continue;

        EnemyAttack.endTelegraph(ctx, j);
        store.despawn(store.idAt(j));
      }
    }

    enemies.comboStep[primary] = maxSerial;
  }

  /// A proper segment-segment crossing, parametrically — the identical
  /// shape `ConfluenceSystem.segmentsIntersect`/`HollowWardenSystem.
  /// _segmentCrossing` already use, reimplemented rather than shared
  /// since none of the three is in a position to depend on either of
  /// the others. No near-miss tolerance, no parallel-rejection: both
  /// exist elsewhere to stop a rapid-fire player's own arrows from
  /// Confluencing with themselves at the bow, a degenerate case with no
  /// analogue for cutting a fixed, externally-placed thread.
  static bool _segmentsCross(
    double ax0,
    double ay0,
    double ax1,
    double ay1,
    double bx0,
    double by0,
    double bx1,
    double by1,
  ) {
    final double d1x = ax1 - ax0;
    final double d1y = ay1 - ay0;
    final double d2x = bx1 - bx0;
    final double d2y = by1 - by0;

    final double denom = d1x * d2y - d1y * d2x;
    if (denom.abs() < 1e-12) return false;

    final double ex = bx0 - ax0;
    final double ey = by0 - ay0;
    final double t = (ex * d2y - ey * d2x) / denom;
    final double u = (ex * d1y - ey * d1x) / denom;
    return t >= 0 && t <= 1 && u >= 0 && u <= 1;
  }

  /// Damages the player for standing on any live thread, at most once
  /// per [_threadDamageCooldownSeconds] regardless of how many threads
  /// they touch at once — the same shared-cooldown shape Cinder Choir's
  /// tether sweep and Arclight's chain both already use.
  static void _tickThreadDamage(AiContext ctx, int primary, double dt) {
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
      if (!EnemyAttack.hasTelegraph(ctx, j)) continue;

      final int t = enemies.telegraphSlot[j];
      if (EnemyAttack.playerOnLine(
        ctx,
        ctx.telegraphs.xAt(t),
        ctx.telegraphs.yAt(t),
        ctx.telegraphs.toXAt(t),
        ctx.telegraphs.toYAt(t),
        _threadWidth,
      )) {
        EnemyAttack.damagePlayer(ctx, _threadDamage, source: primary);
        enemies.attackCooldown[primary] = _threadDamageCooldownSeconds;
        return;
      }
    }
  }
}
