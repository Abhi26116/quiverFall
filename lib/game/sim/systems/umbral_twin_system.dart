import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// Umbral Twin — docs/06 §6.2, Event boss #14, *The Long Night*. "Fights in
/// near-total darkness; the arena is lit only by the player's own
/// Windlines, so the depth mechanic becomes the light source. Attacks are
/// audible before visible — the one fight with genuine audio-first
/// design."
///
/// **This card's own differentiating mechanic is entirely a presentation
/// concern, outside `lib/game/sim`'s own architectural boundary** —
/// confirmed, not guessed at, by reading what the card itself is talking
/// about. "The depth mechanic" is docs/03 §3's own name for Confluence/
/// Windlines (`"Taught: the depth mechanic, discovered rather than
/// lectured"`, docs/03-progression.md, the room that teaches Windlines by
/// accident); "the arena is lit only by the player's own Windlines" is a
/// *lighting* read of Windline positions the sim already tracks in full —
/// rendering which pixels are dark is a decision for whatever draws the
/// arena, not a new fact the simulation needs to compute or store.
/// "Attacks are audible before visible" is a feedback-sequencing question
/// (`FeedbackDirector`/`FeelTelemetry`, both already carrying an explicit
/// deferred no-op for a boss's own phase-transition VFX/audio) — cueing
/// sound ahead of a telegraph's own visual, not a rule about when damage
/// can be dealt or avoided. Neither piece has a sim-level consequence a
/// test in this file could ever observe: the architecture guard's own
/// "sim purity" check (`lib/game/sim` imports nothing from Flutter, Flame
/// or Riverpod) is exactly what makes rendering and audio the wrong
/// layer for this code to live in regardless.
///
/// **No attack is stated either** — the third Event-tier boss in a row
/// (after Bellweather, ADR 0064, and The Pale Judge, ADR 0065) whose own
/// card names no attack shape, which reads as this tier's own consistent
/// design rather than three unrelated omissions. None is invented here.
///
/// What remains, and is built here, is the one thing every boss needs
/// regardless: a correctly-statted body a real run can spawn and fight.
/// See ADR 0066.
abstract final class UmbralTwinSystem {
  /// Places Umbral Twin's single, stationary body. Returns its slot, or -1
  /// if the entity pool was full or [BossArchetype.umbralTwin] has no
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
    final int bossIndex = content.bosses.indexOfArchetype(BossArchetype.umbralTwin);
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

    return slot;
  }

  /// No per-tick sim mechanic exists to run — see the class doc comment.
  /// Kept for consistency with every other boss in this roster's own
  /// six-step pattern, and a real seam if a future pass ever adds
  /// sim-level, phase-gated behaviour docs/06 does not itself state.
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
      if (content.bosses.all[bossIndex].archetype != BossArchetype.umbralTwin) {
        continue;
      }
      // Nothing to tick — see the class doc comment.
    }
  }
}
