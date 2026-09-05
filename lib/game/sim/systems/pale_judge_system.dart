import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// The Pale Judge — docs/06 §6.2, Event boss #16, *Assize*. "Reads the
/// player's build at fight start and gains a matching immunity — an Ember
/// build faces a fire-immune Judge. Explicitly designed to punish
/// mono-builds and to sell the second loadout slot honestly."
///
/// **Needed zero new sim primitives.** `EnemyStore.adaptTo`'s own doc
/// comment already names exactly this shape: "a duration of zero clears any
/// adaptation — the Voidtouched variant passes `double.infinity` once at
/// spawn and is never touched again." The Voidtouched (docs/05 §5.6) is a
/// permanently element-immune enemy built the identical way; the only
/// difference here is *which* element gets passed in is read from the
/// player's own current build rather than fixed at content-authoring time.
/// `resistsElement` — already the single choke point `ProjectileSystem.
/// _applyOneElement` checks before applying any Burn/Frost/Toxin/Storm
/// status, for arrow-carried elements and hero-innate ones alike — needed
/// no changes at all.
///
/// "The player's build" is read at spawn time, not live from `AiContext`
/// each tick, matching the card's own "at fight start" wording literally
/// and the same "the real work is the caller's job" split The Last
/// Warden's own `echoArchetypes` parameter already established (ADR 0061):
/// [spawn] takes an already-resolved [playerElement], which `SimWorld.
/// spawnPaleJudge` supplies from the identical attuned-Boon-then-equipped-
/// arrow priority the sim's own `_arrowElementIndex` already uses to decide
/// what a fired arrow's own element is — so "the player's build" means
/// exactly what the game already means by it everywhere else, not a new
/// definition invented for this one boss. A player carrying no element at
/// all (a null-build run) faces a Judge immune to nothing, an honest
/// degrade rather than a guessed default.
///
/// **No attack of its own is described, and none is invented** — the same
/// posture Bellweather's own card already established (ADR 0064) for an
/// Event-tier card silent on an attack shape. The whole fight is the
/// immunity itself: a chunk of whatever build the player brought does
/// nothing here, and clearing the boss anyway is the lesson.
abstract final class PaleJudgeSystem {
  /// Places the Judge's single, stationary body, immune for the rest of
  /// the fight to whichever element the player currently favours. Returns
  /// its slot, or -1 if the entity pool was full or [BossArchetype.
  /// paleJudge] has no catalogue entry.
  static int spawn({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
    required double centerX,
    required double centerY,
    required double health,
    double radius = 0.8,
    SimElement? playerElement,
  }) {
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.paleJudge);
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

    if (playerElement != null) {
      enemies.adaptTo(slot, playerElement, double.infinity);
    }

    return slot;
  }

  /// No per-tick mechanic exists to run — see the class doc comment. Kept
  /// for the same reason every other boss in this roster has an `update`:
  /// consistency with the six-step pattern, and a real seam if a future
  /// pass ever adds phase-gated behaviour docs/06 does not itself state.
  static void update(AiContext ctx) {
    final EntityStore store = ctx.entities;
    final EnemyStore enemies = ctx.enemies;
    final ContentLibrary content = ctx.content;

    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;
      if (content.bosses.all[bossIndex].archetype != BossArchetype.paleJudge) {
        continue;
      }
      // Nothing to tick — the whole mechanic already happened at spawn.
    }
  }
}
