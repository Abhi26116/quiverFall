import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/ai/enemy_attack.dart';
import 'package:quiverfall/game/sim/ai/steering.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/combat_modifiers.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/systems/arclight_system.dart';
import 'package:quiverfall/game/sim/systems/ashen_choir_system.dart';
import 'package:quiverfall/game/sim/systems/cinder_choir_system.dart';
import 'package:quiverfall/game/sim/systems/draw_system.dart';
import 'package:quiverfall/game/sim/systems/gaunt_system.dart';
import 'package:quiverfall/game/sim/systems/green_mother_system.dart';
import 'package:quiverfall/game/sim/systems/hollow_warden_system.dart';
import 'package:quiverfall/game/sim/systems/rimefather_system.dart';
import 'package:quiverfall/game/sim/systems/silversong_system.dart';
import 'package:quiverfall/game/sim/systems/skarn_system.dart';
import 'package:quiverfall/game/sim/systems/the_quiverfall_system.dart';
import 'package:quiverfall/game/sim/systems/thrall_of_nine_system.dart';
import 'package:quiverfall/game/sim/systems/vermillion_system.dart';
import 'package:quiverfall/game/sim/systems/weeping_gate_system.dart';

/// The Last Warden — docs/06 §6.3, Endless Descent boss #20. "×140 HP, 150s.
/// The true final boss. The Warden who held the Spire before you. Five
/// phases, not three." By far the largest single scope in the boss roster
/// (ADR 0058's own closing line) — built across several parts, one phase (or
/// phase-group) at a time, the same posture Cinder Choir's own four-part
/// P1-P3 build established early in this roster.
///
/// **P1, built here: "Draw/Momentum duel at parity — it plays the game
/// exactly as the player does."** The one card in this entire roster that
/// asks a boss to run the player's own core resource loop, not a themed
/// variant of it — which is exactly what makes this phase cheap to build
/// faithfully rather than approximate: `DrawState`/[DrawSystem] were already
/// generic across any number of live instances the moment the Hollow
/// Warden's own `hollowWardenDraw` proved it (ADR 0031), so a third
/// instance — `SimWorld.lastWardenDraw` — gets the identical ramp-while-
/// still, stack-while-moving rules the player's own Draw runs under, for
/// free.
///
/// "At parity" is read as two real trades, both ways:
///
/// - **Momentum's speed bonus is real for the Warden**, the same
///   `moveSpeedBonus` getter the player's own movement already reads,
///   applied to every step this system takes.
/// - **Momentum's damage reduction is real for the Warden too** — the one
///   piece with no existing hook to reuse, since every other enemy attack
///   pipeline in the game reduces the *player's* incoming damage, never an
///   enemy's own. Intercepting a hit before it lands would mean touching
///   `ProjectileSystem._applyHit`, the single most shared, most heavily
///   tested function in the whole combat pipeline, for a boss-archetype-
///   specific branch nothing else in that file has ever needed. Instead
///   this reuses Rimefather's own "observe and correct after the fact"
///   shape (ADR 0050): `_tickDamageReduction` diffs this tick's health
///   against a baseline read last tick (`bossLastHitAgo`, free — P1 has no
///   children yet to need it for) and refunds a `damageReduction` fraction
///   of whatever dropped. A player at max Momentum takes 10% less damage;
///   the Warden, fighting by the identical rule, does too.
///
/// The rhythm itself — approach and hold to ramp Draw, fire at Tier III,
/// then deliberately disengage to rebuild Momentum before closing again —
/// is docs/01 §1.1's own "root to escalate, move to survive, repeat" player
/// loop, mirrored: `bossTimer` (free) holds a reposition countdown that
/// starts the instant a heavy shot fires, during which the Warden retreats
/// (building Momentum, the mirror of the player's own dash-away-to-refill
/// beat) rather than closing straight back in. The heavy shot itself reuses
/// `EnemyAttack.fireBolt`, the same primitive — and the same "fraction of
/// max HP, derived from an existing anchor, not the player's own actual
/// arrow type or hero stats" honesty ADR 0031 already established for the
/// Hollow Warden's own heavy shot, since porting real arrow behaviour onto
/// an enemy body is the identical out-of-scope redesign question here that
/// it was there.
///
/// P2, built here: "Gains the player's own current Boon set, mirrored."
/// Additive on top of P1, which keeps running unmodified — nothing in the
/// card's own wording says the duel stops. A literal port of every one of
/// the roughly 60 Boons' own bespoke mechanic onto an enemy body is a
/// materially larger redesign question than a single pass can resolve
/// (most are deeply tied to the player's own arrow — pierce falloff,
/// ricochet, elemental procs, hit-streak bookkeeping — concepts a
/// bolt-firing enemy body has no analogue for), so this reads the
/// player's own live CombatModifiers (AiContext.combat, the exact same
/// instance the player's own arrows read every hit, not a snapshot) for
/// the two terms generic enough to reapply as-is: flatDamage (an
/// unconditional percentage) and a real critChance/critMultiplier roll,
/// both folded directly into the heavy shot's own damage at fire time
/// rather than through EnemyStore.attackBuff — AiSystem.update's own
/// generic pass zeroes every enemy's attackBuff every tick before hazards
/// resolve (Chanter auras are meant to be recomputed fresh, not to
/// persist), which runs after every boss system including this one, so a
/// write there would be silently discarded before HazardSystem ever reads
/// it. Baking the bonus into the bolt's own damage field at the moment it
/// is created sidesteps that ordering entirely. Every Boon whose bonus is
/// conditional (vsWounded, perHitStreak, perMomentumStack, and the rest of
/// CombatModifiers) is deliberately not mirrored — flagged here, not
/// guessed at. See ADR 0060.
///
/// P3, built here: "Summons echoes of three bosses the player has beaten
/// most often (read from telemetry)." `lib/game/sim` is deliberately pure
/// — it never reads save data — so resolving "most often" from
/// `Progression.bossKillCounts` is the caller's own job, the same
/// "test/tool entry point, real work happens elsewhere" split every
/// `SimWorld.spawnX` wrapper in this roster already draws; [spawn] simply
/// accepts up to three already-chosen [BossArchetype] values. Each one
/// spawned is not a bespoke "echo" mechanic — it is that archetype's own
/// real `System.spawn`, so its own already-existing system picks it up
/// automatically the exact same generic-table-scan way it already
/// recognises any other instance of itself, with zero new AI code. Scaled
/// to a fraction of the Warden's own max health, not a full boss, since
/// three simultaneous full-HP fights is not what "echo" reads as; placed
/// in the same small triangle staging shape Cinder Choir's own effigies
/// and Rimefather's own mirrors already use. Restricted to the twelve
/// built campaign archetypes plus Ashen Choir — the three still-unbuilt
/// Elite/Event bosses have no `spawn` to call, and the other Endless-tier
/// archetypes (including the Warden's own) are excluded as not the kind
/// of boss "beaten most often" plausibly names. An archetype outside that
/// set, or an empty slot (a fresh save with fewer than three distinct
/// kills), is skipped rather than guessed at. See ADR 0061.
///
/// P4, built here: "Arena floor is removed; combat on floating Windline-
/// drawn platforms the player creates by firing. The mechanic becomes the
/// terrain." A genuine fall-through/void-collision terrain model would
/// mean building real physics onto `SimWorld._applyInput`, the one
/// function every other interaction in the game already depends on — the
/// identical class of change ADR 0038 already declined for Rimefather's
/// own "reduces friction" half of its own P2. Instead this reuses the
/// player-standing-on-a-Windline check the Hollow Warden's own P2 already
/// built (`_pointNearSegment`, reimplemented here against the player's
/// own lines rather than shared, matching this roster's own established
/// "small independent copies" posture — ADR 0057) as a real, working
/// stand-in for "on/off a platform": while not standing on any live
/// player-owned Windline segment, the player takes the roster's own bare
/// persistent-aura anchor on the same shared cooldown The Loom's own
/// threads already use. "The mechanic becomes the terrain" is genuinely
/// true under this reading — the only way to stop taking damage is to
/// keep firing, which is what lays a Windline in the first place — even
/// though no entity can ever fall through the arena floor, because the
/// sim has no such floor to fall through in the first place. See ADR
/// 0062.
abstract final class LastWardenSystem {
  /// Reused from the Hollow Warden's own mirror-approach speed — a
  /// deliberate, readable closing pace, not a lunge.
  static const double _approachSpeed = 2.4;

  /// The distance at which the Warden stops closing and plants to Draw —
  /// authored, close enough that the duel reads as a real confrontation
  /// rather than kiting at range.
  static const double _engageRange = 3.0;
  static const double _engageRangeSq = _engageRange * _engageRange;

  /// How long the Warden deliberately disengages after each heavy shot to
  /// rebuild Momentum before closing again — authored, long enough to
  /// matter against [DrawState]'s own stack-gain rate without stalling the
  /// duel's own pace.
  static const double _repositionSeconds = 1.4;

  /// Reused from the Hollow Warden's own heavy bolt (docs/05 #24's own
  /// numbers, already reused once).
  static const double _boltProjectileSpeed = 8.0;
  static const double _boltRange = 14.0;
  static const double _boltRadius = 0.35;

  /// The heavy shot's own damage — the roster's own derived heavy-hit
  /// anchor (Thresher's 9% persistent-aura anchor, scaled by Tier III's own
  /// 2.10x multiplier), the same number this whole roster already reaches
  /// for by default. See the class doc comment.
  static const double _heavyShotDamage = 0.09 * 2.10;

  /// Fraction of the Warden's own max health each P3 echo carries —
  /// authored, small enough that three at once reads as a real but
  /// secondary threat rather than three simultaneous full boss fights.
  static const double _echoHealthFraction = 0.08;

  /// A small triangle around the Warden's own position — the same
  /// staging-radius reasoning Cinder Choir's own triangle and Rimefather's
  /// own mirrors already use.
  static const double _echoPlacementRadius = 3.0;
  static const int _echoSlots = 3;

  // ── P4: the floor is removed ──────────────────────────────────────────
  // See ADR 0062.

  /// The roster's own bare persistent-aura anchor — an ongoing damage
  /// source, not a single decisive hit.
  static const double _voidDamage = 0.09;

  /// The Loom's own established cadence for a shared ambient-damage
  /// cooldown.
  static const double _voidDamageCooldownSeconds = 0.6;

  /// The sentinel every consumer of `WindlineStore.ownerAt` already
  /// treats as "the player's own trail."
  static const int _playerLineOwner = 0;

  /// Places the Warden's single, stationary-until-it-moves body. Returns
  /// its slot, or -1 if the entity pool was full or [BossArchetype.
  /// lastWarden] has no catalogue entry.
  ///
  /// [echoArchetypes] names up to three already-chosen bosses (docs/06
  /// §6.3's own P3, "the three bosses the player has beaten most often
  /// (read from telemetry)") to summon once P3 begins — see the class doc
  /// comment for why resolving *which* three is entirely the caller's own
  /// job. Fewer than three, or none at all, is a valid, honest input.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 0.6,
    List<BossArchetype> echoArchetypes = const <BossArchetype>[],
  }) {
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.lastWarden);
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
    // A health baseline for `_tickDamageReduction`'s own tick-to-tick
    // diff — the same repurposing Rimefather's own mirrors already use
    // `bossLastHitAgo` for (ADR 0050), free here since P1 has no children.
    enemies.bossLastHitAgo[slot] = health;

    // The three chosen echo archetypes, stashed as plain indices in three
    // otherwise-free per-primary fields (`state` doubles as the "not yet
    // spawned" latch below, so it is not one of the three) — -1 marks an
    // empty slot.
    final List<int> echoIndex = List<int>.filled(_echoSlots, -1);
    for (int i = 0; i < echoArchetypes.length && i < _echoSlots; i++) {
      echoIndex[i] = echoArchetypes[i].index;
    }
    enemies.comboStep[slot] = echoIndex[0];
    enemies.bossActiveChildIndex[slot] = echoIndex[1];
    enemies.bossChildIndex[slot] = echoIndex[2];

    return slot;
  }

  static void update(AiContext ctx) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final ContentLibrary content = ctx.content;
    final double dt = ctx.dt;
    final DrawState? draw = ctx.lastWardenDraw;
    if (draw == null) return;

    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.lastWarden) {
        continue;
      }

      _tickDamageReduction(ctx, i, draw);

      final bool isMoving = _tickMovement(ctx, i, draw, dt);
      DrawSystem.update(draw, isMoving, dt, ctx.events);

      if (draw.tier == DrawTier.three) {
        _fireHeavyShot(ctx, i, draw);
        draw.drawSeconds = 0;
        enemies.bossTimer[i] = _repositionSeconds;
      }

      // P3: "Summons echoes of three bosses the player has beaten most
      // often." `state` doubles as the one-time latch — nothing in P1/P2
      // ever sets it, so 0 means "not yet spawned."
      if (enemies.bossPhase[i] >= 2 && enemies.state[i] == 0) {
        _spawnEchoes(ctx, i);
        enemies.state[i] = 1;
      }

      // P4: "The floor is removed." See the class doc comment for the
      // scoped reading — standing off a live player-owned Windline is
      // punished directly rather than modelled as a real fall.
      if (enemies.bossPhase[i] >= 3) _tickVoidFloor(ctx, i, dt);
    }
  }

  /// Approach-and-hold while no reposition is pending, deliberate retreat
  /// once one is. Returns whether the Warden is moving this tick — exactly
  /// the signal [DrawSystem.update] needs as `isMoving`, the same "still
  /// closing" reading the Hollow Warden's own mirror already feeds it.
  static bool _tickMovement(AiContext ctx, int slot, DrawState draw, double dt) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    if (!ctx.hasPlayer) {
      Steering.halt(ctx, slot);
      return false;
    }

    final double speed = _approachSpeed * (1.0 + draw.moveSpeedBonus);

    if (enemies.bossTimer[slot] > 0) {
      enemies.bossTimer[slot] -= dt;
      Steering.moveAway(ctx, slot, ctx.playerX, ctx.playerY, speed);
      Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);
      return true;
    }

    final double dx = ctx.playerX - store.posX[slot];
    final double dy = ctx.playerY - store.posY[slot];
    Steering.faceToward(ctx, slot, ctx.playerX, ctx.playerY, 0);

    if (dx * dx + dy * dy <= _engageRangeSq) {
      Steering.halt(ctx, slot);
      return false;
    }

    Steering.moveToward(ctx, slot, ctx.playerX, ctx.playerY, speed);
    return true;
  }

  static void _fireHeavyShot(AiContext ctx, int slot, DrawState draw) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final double fromX = store.posX[slot];
    final double fromY = store.posY[slot];
    final double angle = math.atan2(ctx.playerY - fromY, ctx.playerX - fromX);

    double damage = _heavyShotDamage;

    // P2: "Gains the player's own current Boon set, mirrored" — the flat,
    // unconditional portion of it, plus a real crit roll, folded in here
    // rather than through `attackBuff` (see the class doc comment for why).
    if (enemies.bossPhase[slot] >= 1) {
      final CombatModifiers? combat = ctx.combat;
      if (combat != null) {
        damage *= 1.0 + combat.flatDamage;
        if (combat.critChance > 0 && ctx.rng.nextDouble() < combat.critChance) {
          damage *= combat.critMultiplier;
        }
      }
    }

    EnemyAttack.fireBolt(
      ctx,
      slot,
      angle: angle,
      speed: _boltProjectileSpeed,
      damage: damage,
      radius: _boltRadius,
      lifetime: _boltRange / _boltProjectileSpeed,
    );
  }

  /// Compares this tick's health against what was read last tick and
  /// refunds a `draw.damageReduction` fraction of whatever dropped — the
  /// Warden's own Momentum stacks mitigating incoming damage the identical
  /// way the player's own do, without touching the shared hit-resolution
  /// pipeline. See the class doc comment.
  static void _tickDamageReduction(AiContext ctx, int slot, DrawState draw) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final double baseline = enemies.bossLastHitAgo[slot];
    final double current = store.health[slot];
    final double drop = baseline - current;

    if (drop > 0 && draw.damageReduction > 0) {
      double healed = current + drop * draw.damageReduction;
      if (healed > store.maxHealth[slot]) healed = store.maxHealth[slot];
      store.health[slot] = healed;
    }

    enemies.bossLastHitAgo[slot] = store.health[slot];
  }

  /// Spawns whichever of the three echo archetypes stashed at spawn time
  /// (see [spawn]'s own doc comment) are actually set, in a small triangle
  /// around the Warden's own current position. Each one is that
  /// archetype's own real primary, at [_echoHealthFraction] of the
  /// Warden's own max health, so its own already-existing system drives
  /// it from the moment it appears — no bespoke "echo AI" of any kind.
  static void _spawnEchoes(AiContext ctx, int primary) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;

    final List<int> echoIndex = <int>[
      enemies.comboStep[primary],
      enemies.bossActiveChildIndex[primary],
      enemies.bossChildIndex[primary],
    ];

    final double centerX = store.posX[primary];
    final double centerY = store.posY[primary];
    final double echoHealth = store.maxHealth[primary] * _echoHealthFraction;

    for (int slot = 0; slot < _echoSlots; slot++) {
      final int rawIndex = echoIndex[slot];
      if (rawIndex < 0 || rawIndex >= BossArchetype.values.length) continue;

      final double angle = 2 * math.pi * slot / _echoSlots;
      final double x = centerX + _echoPlacementRadius * math.cos(angle);
      final double y = centerY + _echoPlacementRadius * math.sin(angle);

      _spawnEchoOf(ctx, BossArchetype.values[rawIndex], x, y, echoHealth);
    }
  }

  /// Dispatches to the named archetype's own real `System.spawn` — every
  /// built campaign boss plus Ashen Choir. Anything else (the three
  /// unbuilt Elite/Event bosses, the other Endless-tier archetypes, or the
  /// Warden's own) has no case here and is silently skipped; see the class
  /// doc comment for why.
  static int _spawnEchoOf(
    AiContext ctx,
    BossArchetype archetype,
    double x,
    double y,
    double health,
  ) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final ContentLibrary content = ctx.content;
    final SimEventBuffer events = ctx.events;

    switch (archetype) {
      case BossArchetype.cinderChoir:
        return CinderChoirSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.gauntIronTide:
        return GauntSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.silversong:
        return SilversongSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.hollowWarden:
        return HollowWardenSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.vermillion:
        return VermillionSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.rimefather:
        return RimefatherSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.arclight:
        return ArclightSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.greenMother:
        return GreenMotherSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.thrallOfNine:
        return ThrallOfNineSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.weepingGate:
        return WeepingGateSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.skarnUnmade:
        return SkarnSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.quiverfall:
        return TheQuiverfallSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.ashenChoir:
        return AshenChoirSystem.spawn(
          store: store,
          enemies: enemies,
          content: content,
          events: events,
          centerX: x,
          centerY: y,
          health: health,
        );
      case BossArchetype.umbralTwin:
      case BossArchetype.bellweather:
      case BossArchetype.paleJudge:
      case BossArchetype.theLoom:
      case BossArchetype.coilspine:
      case BossArchetype.motherOfMotes:
      case BossArchetype.lastWarden:
        return -1;
    }
  }

  /// While the player is not standing on any live player-owned Windline
  /// segment, deals [_voidDamage] on a shared cooldown — "the floor is
  /// removed," read as ongoing chip damage rather than a fall this sim has
  /// no physics to model. `attackCooldown` is free here — the heavy shot's
  /// own cadence lives on `bossTimer`/[DrawState], never this field.
  static void _tickVoidFloor(AiContext ctx, int slot, double dt) {
    final EnemyStore enemies = ctx.enemies;

    if (enemies.attackCooldown[slot] > 0) {
      enemies.attackCooldown[slot] -= dt;
    }
    if (!ctx.hasPlayer) return;

    final double px = ctx.playerX;
    final double py = ctx.playerY;
    final double r = ctx.playerRadius;

    final int found =
        ctx.lineIndex.querySegment(px, py, px, py, r, ctx.segmentScratch);
    bool onPlatform = false;
    for (int c = 0; c < found; c++) {
      final int seg = ctx.segmentScratch[c];
      if (!ctx.lines.isAlive(seg)) continue;
      if (ctx.lines.ownerAt(seg) != _playerLineOwner) continue;
      if (_pointNearSegment(px, py, ctx.lines.x0(seg), ctx.lines.y0(seg),
          ctx.lines.x1(seg), ctx.lines.y1(seg), r)) {
        onPlatform = true;
        break;
      }
    }

    if (!onPlatform && enemies.attackCooldown[slot] <= 0) {
      EnemyAttack.damagePlayer(ctx, _voidDamage, source: slot);
      enemies.attackCooldown[slot] = _voidDamageCooldownSeconds;
    }
  }

  /// The roster's own small, independently-reimplemented "is this point
  /// within `radius` of this segment" test — the same shape the Hollow
  /// Warden's own `_tickPlayerSlow` already uses, deliberately not shared
  /// (ADR 0057's own reasoning: a handful of independent nine-line copies
  /// is cheaper and safer than restructuring already-shipped systems to
  /// share one).
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
