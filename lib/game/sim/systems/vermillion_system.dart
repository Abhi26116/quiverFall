import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/hazard_store.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/telegraph.dart';

/// Vermillion, the Long Burn — docs/06 §5, chapter 5's boss. "Tests: Ember,
/// and sustained-damage thinking."
///
/// **P1: "Leaves a persistent burning trail; arena floor progressively
/// becomes lethal."** A single, undamaging-to-touch body (no plate, no
/// contact attack — docs/06 names none for P1) that simply walks toward
/// the player, dropping a lethal ground puddle behind it as it goes, the
/// way a Windline segment is laid every fixed distance travelled
/// (`SimWorld`'s own trail emission) rather than on a fixed clock.
///
/// Needed no new sim primitive: `EnemyAttack.dropPuddle` (already used by
/// every shell that leaves a lingering hazard behind it, docs/05 §5.4) is
/// exactly "place a lethal circle that fades after a while" — Vermillion's
/// own trail is that call, repeated. The floor "progressively becoming
/// lethal" is simply many of these accumulating as it walks; nothing new
/// had to be built to make ground stay dangerous once placed.
///
/// **P2: "Ignites in a 3u aura and charges along amber lines. Safe floor
/// is now ~50%."** "Adds," additively — the P1 walk-and-trail keeps
/// running unmodified. The aura reuses the trail's own `burnPerSecond`
/// anchor, discretised to a tick every 0.6s (the roster's own established
/// magnitude) rather than firing every raw simulation frame, at the
/// card's own stated 3u radius. The charge is this boss's own first real
/// *movement* attack — a telegraphed line wind-up (0.6s, reusing the same
/// "read the committed destination back out of the telegraph"
/// (`TelegraphStore.toXAt`/`toYAt`) trick the Weeping Gate's own portals
/// already established, ADR 0030), then Vermillion's own position snaps
/// to the line's far end at resolve, dealing the roster's own derived
/// "heavy hit" (Thresher's 9% x Tier III's 2.10x — Hollow Warden, Skarn,
/// and Gaunt all already agree on this number) to anyone caught on the
/// path. Charging halts P1's own walk for the wind-up's own duration, so
/// the line's own origin stays exactly where it was drawn. See ADR 0037.
///
/// **P3, built here: "Detonates the entire accumulated trail in sequence
/// over 6s, creating a moving safe window the player must chase."**
/// Walking, laying new trail, the aura, and the charge all stop — P3
/// replaces the offence entirely. "Track which hazards are this boss's
/// own trail" turned out to need no new storage at all: every puddle
/// [EnemyAttack.dropPuddle] already lays is recorded in `HazardStore`
/// with `owner: primary` (read via `ownerAt`), so a live scan already
/// answers "which hazards are mine" — and since every segment shares an
/// identical original lifetime and lay rate, the one with the *least*
/// `remaining` time left is reliably the *oldest*, giving a correct lay
/// order with no separate list to maintain. `_tickP3Detonation` counts
/// however many segments exist the instant P3 begins (`comboStep`, free
/// here — nothing else in this system touches it) and derives a fixed
/// per-segment interval from the card's own 6s total
/// (`bossLastHitAgo`, also free once P2's own charge cooldown stops
/// reading it); every interval, the currently-oldest surviving segment
/// detonates for the roster's own derived heavy hit and is released —
/// `HazardStore.release` plus `TelegraphStore.release` on that segment's
/// own recorded telegraph handle, not `EnemyAttack.endTelegraph` (which
/// only ever tracks *one* telegraph per owner via `enemies.
/// telegraphSlot`; `dropPuddle` never used that bookkeeping in the first
/// place, since many puddles already coexist under the same owner).
/// "The moving safe window" is a free consequence, not separately
/// implemented: ground already detonated is gone (safe), ground not yet
/// reached keeps burning exactly as it always has, so the safe/lethal
/// boundary visibly sweeps through the original lay order on its own.
///
/// **Not built here: "Frost arrows extinguish trail segments."** This is
/// two missing primitives stacked, not one: `HazardStore` carries no
/// element for anything it holds (bolts, shells, puddles alike), *and*
/// nothing in the sim today lets an arrow collide with a hazard at all —
/// arrows only ever hit enemies, hazards only ever hit the player. Adding
/// either is real, separate, wide-blast-radius work (a shared struct
/// every enemy's own ordnance already uses, and a genuinely new
/// interaction category) this pass does not attempt. See ADR 0052.
abstract final class VermillionSystem {
  /// Reused from Husk (docs/05), the same "no stated speed, borrow the base
  /// Carapace archetype's own" choice ADR 0023 already made for Gaunt.
  static const double _p1Speed = 1.0;

  /// Authored — docs/06 gives no cadence for the trail. Long enough that a
  /// walking boss lays a readable, connected line rather than an unbroken
  /// smear. See ADR 0025.
  static const double _trailIntervalSeconds = 1.0;

  /// Authored — no stated puddle size.
  static const double _trailRadius = 1.0;

  /// Reused, not invented: `ElementTuning.burnPerSecond` (4%/s) is the
  /// game's own existing Ember DoT rate — "Tests: Ember" is the card's own
  /// stated lesson, so the trail's own damage is anchored to the element it
  /// is thematically already.
  static const double _trailDamagePerSecond = ElementTuning.burnPerSecond;

  /// Authored — long enough that a segment laid early in P1 is still alive
  /// by the time P3 would detonate it (not built yet), short enough that a
  /// full ~65s fight's worth of trail stays comfortably under
  /// `HazardStore`'s own 96-slot capacity (at one segment/second, this
  /// bounds roughly 20 concurrent segments, not 65).
  static const double _trailLifetimeSeconds = 20.0;

  // ── P2: ignite aura ──────────────────────────────────────────────────────
  // See ADR 0037.

  /// docs/06 §5 P2's own stated radius.
  static const double _auraRadius = 3.0;

  /// The roster's own established "amber warning" tick magnitude, applied
  /// here to an ongoing aura rather than a one-shot resolve.
  static const double _auraTickSeconds = 0.6;

  /// The trail's own `burnPerSecond` anchor, discretised to one tick's
  /// worth rather than invented separately for the aura.
  static const double _auraDamagePerTick = _trailDamagePerSecond * _auraTickSeconds;

  // ── P2: the charge ───────────────────────────────────────────────────────

  static const double _chargeWindUpSeconds = 0.6;

  /// Authored — docs/06 gives no cadence between charges.
  static const double _chargeCooldownSeconds = 3.0;

  /// Authored — no stated charge distance.
  static const double _chargeLength = 6.0;

  /// ADR 0008/0019's own reused line-hazard width.
  static const double _chargeWidth = SimConfig.windlineHitWidth;

  /// Derived, not guessed a fourth time: the same "heavy hit" anchor
  /// Hollow Warden, Skarn and Gaunt already share.
  static const double _chargeDamage = 0.09 * 2.10;

  // ── P3: the sequenced detonation ──────────────────────────────────────
  // See ADR 0052.

  /// docs/06 §5 P3's own stated total.
  static const double _p3DetonationSeconds = 6.0;

  /// A fifth reuse of the same derived heavy hit — the trail's own
  /// climactic finale deserves the roster's established "how heavy is
  /// heavy" answer, not a fresh guess.
  static const double _p3DetonationDamage = _chargeDamage;

  /// Places Vermillion's single body. Returns its slot, or -1 if the entity
  /// pool was full or [BossArchetype.vermillion] has no catalogue entry.
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
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.vermillion);
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
    // Counts down to the next trail drop — `bossTimer`'s own established
    // "generic countdown a boss's own system owns" role.
    enemies.bossTimer[slot] = _trailIntervalSeconds;

    return slot;
  }

  /// Walks toward the player and lays a lethal puddle behind it on a fixed
  /// cadence; once P2 begins, also ignites (a continuous 3u aura) and
  /// periodically charges.
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.vermillion) {
        continue;
      }

      // P3: walking, new trail, the aura, and the charge all stop —
      // halted rather than left carrying stale velocity into a wall, the
      // same fix ADR 0023 made for Gaunt; any live charge telegraph is
      // cleared too. The trail already laid detonates in sequence
      // instead (see the class doc comment).
      if (enemies.bossPhase[i] >= 2) {
        Steering.halt(ctx, i);
        if (EnemyAttack.hasTelegraph(ctx, i)) EnemyAttack.endTelegraph(ctx, i);
        _tickP3Detonation(ctx, i, dt);
        continue;
      }

      final bool inP2 = enemies.bossPhase[i] >= 1;
      final bool charging = inP2 && enemies.stateOf(i) == AiState.windUp;

      if (ctx.hasPlayer && !charging) {
        Steering.moveToward(ctx, i, ctx.playerX, ctx.playerY, _p1Speed);
      }

      enemies.bossTimer[i] -= dt;
      if (enemies.bossTimer[i] <= 0) {
        enemies.bossTimer[i] += _trailIntervalSeconds;
        EnemyAttack.dropPuddle(
          ctx,
          i,
          x: store.posX[i],
          y: store.posY[i],
          radius: _trailRadius,
          damagePerSecond: _trailDamagePerSecond,
          seconds: _trailLifetimeSeconds,
        );
      }

      if (inP2) {
        _tickAura(ctx, i, dt);
        _tickCharge(ctx, i, dt);
      }
    }
  }

  /// A continuous burn field around Vermillion's own current position,
  /// ticking on the roster's own established 0.6s cadence rather than
  /// every raw frame.
  static void _tickAura(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
      return;
    }

    if (EnemyAttack.playerInCircle(
        ctx, store.posX[primary], store.posY[primary], _auraRadius)) {
      EnemyAttack.damagePlayer(ctx, _auraDamagePerTick, source: primary);
    }
    enemies.attackCooldown[primary] = _auraTickSeconds;
  }

  /// The wind-up/resolve/cooldown cycle behind "charges along amber
  /// lines": aim at the player once, hold that aim through the wind-up
  /// (`bossLastHitAgo` doubles as the between-charges cooldown here — a
  /// different meaning from Skarn's own reuse of the same field, on a
  /// different boss, with no conflict), then snap to the line's own far
  /// end at resolve.
  static void _tickCharge(AiContext ctx, int primary, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (enemies.stateOf(primary) == AiState.windUp) {
      enemies.stateTimer[primary] -= dt;
      if (enemies.stateTimer[primary] > 0) return;
      _resolveCharge(ctx, primary);
      enemies.state[primary] = AiState.idle.index;
      enemies.bossLastHitAgo[primary] = _chargeCooldownSeconds;
      return;
    }

    if (enemies.bossLastHitAgo[primary] > 0) {
      enemies.bossLastHitAgo[primary] -= dt;
      return;
    }

    if (!ctx.hasPlayer) return;

    final double x = store.posX[primary];
    final double y = store.posY[primary];
    final double angle = math.atan2(ctx.playerY - y, ctx.playerX - x);
    double toX = x + _chargeLength * math.cos(angle);
    double toY = y + _chargeLength * math.sin(angle);
    final double r = store.radius[primary];
    if (toX < r) toX = r;
    if (toX > ctx.arena.width - r) toX = ctx.arena.width - r;
    if (toY < r) toY = r;
    if (toY > ctx.arena.height - r) toY = ctx.arena.height - r;

    store.facing[primary] = angle;
    enemies.state[primary] = AiState.windUp.index;
    enemies.stateTimer[primary] = _chargeWindUpSeconds;
    EnemyAttack.beginLine(ctx, primary, x, y, toX, toY, _chargeWidth, _chargeWindUpSeconds);
  }

  static void _resolveCharge(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int telegraphSlot = enemies.telegraphSlot[primary];
    if (telegraphSlot < 0) return;

    // The destination the wind-up itself committed to — read back out of
    // the telegraph rather than recomputed, the same trick the Weeping
    // Gate's own portals already use (ADR 0030), so a player who moved
    // during the wind-up cannot retarget an already-aimed charge.
    final double fromX = ctx.telegraphs.xAt(telegraphSlot);
    final double fromY = ctx.telegraphs.yAt(telegraphSlot);
    final double toX = ctx.telegraphs.toXAt(telegraphSlot);
    final double toY = ctx.telegraphs.toYAt(telegraphSlot);

    EnemyAttack.beginLine(
      ctx,
      primary,
      fromX,
      fromY,
      toX,
      toY,
      _chargeWidth,
      0,
      severity: TelegraphSeverity.lethal,
    );
    if (EnemyAttack.playerOnLine(ctx, fromX, fromY, toX, toY, _chargeWidth)) {
      EnemyAttack.damagePlayer(ctx, _chargeDamage, source: primary);
    }

    store.posX[primary] = toX;
    store.posY[primary] = toY;
  }

  /// Detonates the accumulated trail one segment at a time, oldest first,
  /// spread evenly across [_p3DetonationSeconds]. `comboStep` holds how
  /// many segments are still queued (counted once, the instant this
  /// first runs); `bossLastHitAgo` holds the fixed interval derived from
  /// that count, and doubles as the live countdown to the next
  /// detonation. See the class doc comment for why no separate ordered
  /// list is needed.
  static void _tickP3Detonation(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    if (enemies.comboStep[primary] == 0) {
      final int count = _countOwnedTrailSegments(ctx, primary);
      if (count == 0) return; // nothing left to detonate, ever
      enemies.comboStep[primary] = count;
      enemies.bossLastHitAgo[primary] = _p3DetonationSeconds / count;
      // `bossTimer` is P1's own trail-interval countdown, mid-cycle the
      // instant P3 begins — reset to a fresh full interval rather than
      // inheriting that stale remainder, or the very first detonation
      // would land early by however much P1's own countdown had left.
      enemies.bossTimer[primary] = enemies.bossLastHitAgo[primary];
    }

    enemies.bossTimer[primary] -= dt;
    if (enemies.bossTimer[primary] > 0) return;
    enemies.bossTimer[primary] += enemies.bossLastHitAgo[primary];

    final int oldest = _oldestOwnedTrailSegment(ctx, primary);
    if (oldest < 0) return; // already fully detonated

    _detonateSegment(ctx, primary, oldest);
    enemies.comboStep[primary]--;
  }

  static int _countOwnedTrailSegments(AiContext ctx, int primary) {
    final HazardStore hazards = ctx.hazards;
    int count = 0;
    for (int h = 0; h < hazards.capacity; h++) {
      if (!hazards.isAlive(h)) continue;
      if (hazards.kindAt(h) != HazardKind.puddle) continue;
      if (hazards.ownerAt(h) != primary) continue;
      count++;
    }
    return count;
  }

  /// The puddle with the least time left — every segment shares an
  /// identical original lifetime and lay rate, so the one closest to its
  /// own natural expiry is reliably the one laid earliest.
  static int _oldestOwnedTrailSegment(AiContext ctx, int primary) {
    final HazardStore hazards = ctx.hazards;
    int oldest = -1;
    double leastRemaining = double.infinity;
    for (int h = 0; h < hazards.capacity; h++) {
      if (!hazards.isAlive(h)) continue;
      if (hazards.kindAt(h) != HazardKind.puddle) continue;
      if (hazards.ownerAt(h) != primary) continue;
      if (hazards.remaining[h] < leastRemaining) {
        leastRemaining = hazards.remaining[h];
        oldest = h;
      }
    }
    return oldest;
  }

  static void _detonateSegment(AiContext ctx, int primary, int hazardSlot) {
    final HazardStore hazards = ctx.hazards;
    EnemyAttack.blast(
      ctx,
      source: primary,
      x: hazards.x[hazardSlot],
      y: hazards.y[hazardSlot],
      radius: hazards.radius[hazardSlot],
      damage: _p3DetonationDamage,
    );
    ctx.telegraphs.release(
      hazards.telegraphSlotAt(hazardSlot),
      hazards.telegraphSerialAt(hazardSlot),
    );
    hazards.release(hazardSlot);
  }
}
