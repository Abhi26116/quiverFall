import 'dart:math' as math;

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// The Cinder Choir — docs/06 §1, chapter 1's boss. "Tests: the Draw."
///
/// **P1/P2 only.** "Three linked effigies on a triangle... only the effigy
/// whose eyes are lit is vulnerable; the other two are plated like a Husk...
/// Tier III breaks plate." That reuses the *existing* frontal-plate armour
/// system unmodified (`ArmourFactor`'s own tier switch already gives Tier III
/// full damage through any plate) — the only new work is the rotation timer
/// and the shared-pool wiring `EnemyStore.linkedHealthSlot` exists for.
///
/// P3 ("all three light simultaneously... killing one permanently removes
/// it") is a different mechanic — individually-killable bodies rather than a
/// shared pool — and is not built yet; see ADR 0018. Once `bossPhase` reaches
/// 2 this system stops rotating and does nothing further, a known, flagged
/// gap rather than a silent one.
abstract final class CinderChoirSystem {
  /// docs/06 §1 P1: "The lit one rotates every 6 s."
  static const double _p1RotationSeconds = 6.0;

  /// docs/06 §1 P2: "Rotation drops to 4 s."
  static const double _p2RotationSeconds = 4.0;

  /// How many effigies. Named rather than inlined as `3` everywhere, since
  /// P3's individual-death mechanic (ADR 0018) will need to know when this
  /// count drops.
  static const int childCount = 3;

  /// Reused, not invented: `EnemyTuning.plateHealthFraction` (0.45) is what
  /// every ordinary Husk sizes its own plate pool from. Applied here to the
  /// *shared* pool's max health rather than an individual effigy's, since an
  /// effigy has no meaningful health of its own — see ADR 0018 for why that
  /// makes "brute-force it, slowly" a very slow option indeed at boss scale,
  /// rather than an invented, boss-specific number.
  static const double _plateHealthFraction = 0.45;

  /// A full circle, not a frontal arc: `_armourFor`'s own flank rule ("a hit
  /// from behind the plate's arc takes full damage at any tier") exists so
  /// flanking is a real alternative to the Draw — but here the card's whole
  /// point is *which effigy*, not *which angle*, so an unlit effigy is
  /// plated from every direction. See ADR 0018.
  static const double _fullCirclePlateHalfArc = math.pi;

  /// Positions three effigies on a triangle around `(centerX, centerY)` and
  /// links their health to a new primary boss entity holding the real pool.
  /// Returns the primary's slot, or -1 if the entity pool was full or
  /// [BossArchetype.cinderChoir] has no catalogue entry.
  ///
  /// Takes raw stores rather than a `SimWorld`, the same shape every other
  /// system in this directory uses (`BossPhaseSystem.update`'s own
  /// signature) — a spawn *factory* still belongs beside its own system
  /// rather than as a `SimWorld` convenience method, since this one is
  /// bespoke to a single archetype, unlike `SimWorld.spawnEnemy`/`spawnBoss`,
  /// which are generic across the whole roster.
  ///
  /// [triangleRadius] and [effigyRadius] are authored staging, not GDD
  /// numbers — docs/06 gives no arena geometry for any boss yet (no boss
  /// arena exists at all — ADR 0017's own "no spawn integration" gap).
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double triangleRadius = 2.2,
    double effigyRadius = 0.5,
  }) {
    final int bossIndex =
        content.bosses.indexOfArchetype(BossArchetype.cinderChoir);
    if (bossIndex < 0) return -1;

    final EntityId primaryId = store.spawn(EntityKind.enemy);
    if (primaryId.isNone) return -1;
    final int primary = primaryId.index;

    // An accounting anchor, not a body — near-zero radius so an ordinary
    // shot cannot land on it by accident (see `linkedHealthSlot`'s own doc
    // comment: a hit that somehow does land here is still correct, since an
    // unlinked slot just damages its own health).
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

    final double plateHealth = _plateHealthFraction * health;

    for (int child = 0; child < childCount; child++) {
      // Index 0 at the top, spaced 120° apart — an arbitrary but stable
      // triangle orientation.
      final double angle = -math.pi / 2 + child * (2 * math.pi / childCount);
      final double x = centerX + triangleRadius * math.cos(angle);
      final double y = centerY + triangleRadius * math.sin(angle);

      final EntityId id = store.spawn(EntityKind.enemy);
      if (id.isNone) continue;
      final int slot = id.index;

      store.posX[slot] = x;
      store.posY[slot] = y;
      store.radius[slot] = effigyRadius;
      // An effigy's own health/maxHealth are never read for damage — see
      // `linkedHealthSlot` — but a positive value keeps it out of any
      // "already dead" fast path that might read it before that link is
      // consulted.
      store.health[slot] = health;
      store.maxHealth[slot] = health;
      store.contentIndex[slot] = -1;
      events.emit(SimEventType.entitySpawned, entityA: slot, x: x, y: y);

      enemies.reset(slot);
      enemies.linkedHealthSlot[slot] = primary;
      enemies.bossChildIndex[slot] = child;

      // Child 0 starts lit (fully vulnerable); the other two start plated.
      // `_rotate` below reuses this exact same "plateHealth 0 vs full" shape
      // every rotation after, so the initial state is not a special case.
      if (child == 0) {
        enemies.plateHealth[slot] = 0;
      } else {
        enemies.plateHealth[slot] = plateHealth;
        enemies.plateHalfArc[slot] = _fullCirclePlateHalfArc;
      }
    }

    enemies.bossActiveChildIndex[primary] = 0;
    enemies.bossTimer[primary] = _p1RotationSeconds;
    return primary;
  }

  /// Advances every live Cinder Choir's rotation timer, called from
  /// `SimWorld.tick` at `SystemOrder.bossPhase`'s own slot, right after
  /// `BossPhaseSystem` — after, so a phase change this tick (P1→P2's faster
  /// rotation) is already visible; sharing the slot rather than claiming a
  /// new one, since a `SystemOrder` entry per boss archetype would not scale
  /// to twenty of them.
  static void update({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required double dt,
  }) {
    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.cinderChoir) {
        continue;
      }

      // The primary's own health reached zero this tick (a hit or a DoT tick
      // redirected here through `linkedHealthSlot`). `AiSystem`'s death pass
      // reaps the primary itself through the ordinary bare-entity path — see
      // that pass's own `hasDefinition` guard — but the three effigies never
      // take damage on their *own* health, so nothing else would ever remove
      // them. Done here, ahead of that pass, quietly (no `entityDied` for
      // each effigy — only the primary's own death is "the boss died").
      if (store.health[i] <= 0) {
        _despawnChildren(store, enemies, i);
        continue;
      }

      // P3 ("all three light simultaneously... killing one permanently
      // removes it") is a different mechanic, not built yet — ADR 0018.
      // Whatever rotation state P1/P2 left behind simply freezes.
      if (enemies.bossPhase[i] >= 2) continue;

      enemies.bossTimer[i] -= dt;
      if (enemies.bossTimer[i] > 0) continue;

      final double rotation =
          enemies.bossPhase[i] == 0 ? _p1RotationSeconds : _p2RotationSeconds;
      // Carries any overshoot forward rather than snapping to the full
      // duration, so a rotation never systematically drifts late.
      enemies.bossTimer[i] += rotation;

      _rotate(store, enemies, i);
    }
  }

  static void _rotate(EntityStore store, EnemyStore enemies, int primary) {
    final int current = enemies.bossActiveChildIndex[primary];
    final int next = (current + 1) % childCount;
    final double plateHealth =
        _plateHealthFraction * store.maxHealth[primary];

    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.linkedHealthSlot[j] != primary) continue;

      final int childIndex = enemies.bossChildIndex[j];
      if (childIndex == next) {
        // The incoming lit effigy — fully vulnerable.
        enemies.plateHealth[j] = 0;
      } else if (childIndex == current) {
        // The outgoing effigy — re-plated. An effigy an "impatient player"
        // already broke by attrition (see the class doc comment) stays
        // broken: this only restores an effigy that was plated the whole
        // time it was *not* lit, which — by construction — is exactly what
        // `current` was until this call.
        enemies.plateHealth[j] = plateHealth;
        enemies.plateHalfArc[j] = _fullCirclePlateHalfArc;
      }
      // The third effigy (neither current nor next) is untouched.
    }

    enemies.bossActiveChildIndex[primary] = next;
  }

  static void _despawnChildren(EntityStore store, EnemyStore enemies, int primary) {
    final int high = store.highWater;
    for (int j = 0; j < high; j++) {
      if (store.alive[j] == 0) continue;
      if (enemies.linkedHealthSlot[j] != primary) continue;
      store.despawn(store.idAt(j));
    }
  }
}
