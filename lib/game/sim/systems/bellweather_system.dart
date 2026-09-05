import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// Bellweather — docs/06 §6.2, Event boss #15, *Tollings*. "Every 10s a bell
/// tolls and inverts one rule for the next 10s (movement reversed / Draw
/// inverted so moving charges it / Windlines damage the player / healing
/// damages)."
///
/// The card names no attack of its own — unlike The Ashen Choir (#13,
/// explicitly "Elite remix of #1", reusing Cinder Choir's own attack), this
/// Event boss's entire threat is the rule-inversions themselves, the same
/// posture Silversong's own "the fight is not about HP" and the Weeping
/// Gate's own "never directly attacks" already established for a card that
/// is silent or explicit about dealing no damage of its own. No baseline
/// attack is invented here.
///
/// Each toll picks one of the four rules at random (`ctx.rng`, docs/06 gives
/// no cadence beyond "one rule" — a fixed round-robin would let a player
/// memorise and pre-empt the sequence, which reads against the fight's own
/// "Tollings" surprise) and holds it until the next toll replaces it —
/// `comboStep` (free) encodes which of the five states (0 = none, 1-4 = one
/// rule each) is currently live, `bossTimer` (free) counts down to the next
/// one, both continuous across every phase (no phase-gated content, the
/// same posture Ashen Choir already established for a card describing one
/// flat mechanic rather than an escalating P1/P2/P3).
///
/// Two of the four rules are new sim surface **on the player's own
/// [DrawState]** (`movementReversed`, `drawChargesWhileMoving`) — the same
/// "a boss sets a flag on the player's own live state, read at the exact
/// point that state already lives" posture [DrawState.windlineSlowFactor]
/// and [DrawState.rootRemaining] already use, rather than an
/// archetype-specific branch inside `SimWorld._applyInput` or the Draw
/// update call site itself. The other two need no new player-facing surface
/// at all: "Windlines damage the player" reuses the exact "standing on a
/// live player-owned Windline" check the Hollow Warden's own P2 and The
/// Last Warden's own P4 already built (`_pointNearSegment`, independently
/// reimplemented per this roster's own established "small copies, not a
/// shared utility" posture), inverted to punish rather than protect;
/// "healing damages" needed no audit of the several scattered player-heal
/// call sites (Bloom regen, lifesteal, Overheal) at all — it reuses the
/// roster's own "observe and correct after the fact" shape (Rimefather's
/// decoy mirrors, ADR 0050) instead, diffing the player's own health
/// tick-to-tick and inverting any net *gain* into an equal-sized loss while
/// the rule is live, regardless of which of those sources produced it.
/// See ADR 0064.
abstract final class BellweatherSystem {
  /// docs/06's own stated cadence.
  static const double _tollIntervalSeconds = 10.0;

  // `comboStep == 0` (its reset default) means no rule is live yet — the
  // opening window before the first toll.
  static const int _ruleMovementReversed = 1;
  static const int _ruleDrawInverted = 2;
  static const int _ruleWindlinesHarm = 3;
  static const int _ruleHealingHarms = 4;
  static const int _ruleCount = 4;

  /// The roster's own bare persistent-aura anchor — an ongoing damage
  /// source, not a single decisive hit.
  static const double _windlineHarmDamage = 0.09;

  /// The Loom's own established cadence for a shared ambient-damage
  /// cooldown.
  static const double _windlineHarmCooldownSeconds = 0.6;

  /// The sentinel every consumer of `WindlineStore.ownerAt` already treats
  /// as "the player's own trail."
  static const int _playerLineOwner = 0;

  /// Places Bellweather's single, stationary body. Returns its slot, or -1
  /// if the entity pool was full or [BossArchetype.bellweather] has no
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
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.bellweather);
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
    // The first toll rings 10s in, giving the player a clean opening
    // window before anything inverts.
    enemies.bossTimer[slot] = _tollIntervalSeconds;

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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.bellweather) {
        continue;
      }

      _tickToll(ctx, i);
      _tickWindlineHarm(ctx, i, dt);
      _tickHealingInversion(ctx, i);
    }
  }

  /// Counts down to the next toll and, once it rings, picks one of the
  /// four rules at random and sets the two player-`DrawState` flags to
  /// match — clearing whichever was live before, since only one rule is
  /// ever active at once.
  static void _tickToll(AiContext ctx, int primary) {
    final EnemyStore enemies = ctx.enemies;

    enemies.bossTimer[primary] -= ctx.dt;
    if (enemies.bossTimer[primary] > 0) return;

    enemies.bossTimer[primary] = _tollIntervalSeconds;
    final int rule = ctx.rng.nextInt(_ruleCount) + 1;
    enemies.comboStep[primary] = rule;

    final DrawState? draw = ctx.playerDraw;
    if (draw != null) {
      draw.movementReversed = rule == _ruleMovementReversed;
      draw.drawChargesWhileMoving = rule == _ruleDrawInverted;
    }
  }

  /// While "Windlines damage the player" is the live rule, standing on any
  /// live player-owned Windline segment deals [_windlineHarmDamage] on a
  /// shared cooldown — the exact inverse of what a Windline normally means
  /// for its own owner.
  static void _tickWindlineHarm(AiContext ctx, int primary, double dt) {
    final EnemyStore enemies = ctx.enemies;

    if (enemies.attackCooldown[primary] > 0) {
      enemies.attackCooldown[primary] -= dt;
    }
    if (enemies.comboStep[primary] != _ruleWindlinesHarm) return;
    if (!ctx.hasPlayer) return;

    final double px = ctx.playerX;
    final double py = ctx.playerY;
    final double r = ctx.playerRadius;

    final int found =
        ctx.lineIndex.querySegment(px, py, px, py, r, ctx.segmentScratch);
    bool onOwnLine = false;
    for (int c = 0; c < found; c++) {
      final int seg = ctx.segmentScratch[c];
      if (!ctx.lines.isAlive(seg)) continue;
      if (ctx.lines.ownerAt(seg) != _playerLineOwner) continue;
      if (_pointNearSegment(px, py, ctx.lines.x0(seg), ctx.lines.y0(seg),
          ctx.lines.x1(seg), ctx.lines.y1(seg), r)) {
        onOwnLine = true;
        break;
      }
    }

    if (onOwnLine && enemies.attackCooldown[primary] <= 0) {
      EnemyAttack.damagePlayer(ctx, _windlineHarmDamage, source: primary);
      enemies.attackCooldown[primary] = _windlineHarmCooldownSeconds;
    }
  }

  /// Refreshes a per-tick baseline of the player's own health every tick
  /// regardless of which rule is live, so the baseline is never stale by
  /// more than one tick the moment "healing damages" actually becomes the
  /// live rule; while it is, any net *gain* since last tick — however it
  /// was produced — is inverted into an equal-sized loss instead.
  /// `bossLastHitAgo` is free here, the same repurposing-as-baseline
  /// Rimefather's own mirrors already use (ADR 0050).
  static void _tickHealingInversion(AiContext ctx, int primary) {
    if (!ctx.hasPlayer) return;
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final int player = ctx.player;

    final double baseline = enemies.bossLastHitAgo[primary];
    final double current = store.health[player];
    final double delta = current - baseline;

    if (delta > 0 && enemies.comboStep[primary] == _ruleHealingHarms) {
      double corrected = baseline - delta;
      if (corrected < 0) corrected = 0;
      store.health[player] = corrected;
    }

    enemies.bossLastHitAgo[primary] = store.health[player];
  }

  /// The roster's own small, independently-reimplemented "is this point
  /// within `radius` of this segment" test — the same shape the Hollow
  /// Warden's own P2 and The Last Warden's own P4 already use, deliberately
  /// not shared (ADR 0057's own reasoning).
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
}
