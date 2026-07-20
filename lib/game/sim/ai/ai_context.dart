import 'dart:typed_data';

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/boon_runtime.dart';
import 'package:quiverfall/game/sim/effects/combat_modifiers.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/hazard_store.dart';
import 'package:quiverfall/game/sim/segment_hash.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/spatial_hash.dart';
import 'package:quiverfall/game/sim/status_store.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/windline_store.dart';

/// Everything a behaviour tree needs, in one object.
///
/// **Allocated once per world and mutated in place**, never per tick and never
/// per enemy. Twenty-six behaviours each needing the entity store, the spatial
/// hash, the telegraph store, the arena, the clock and the player's position is
/// either one long-lived context object or fifteen positional parameters
/// threaded through every branch; the context is the smaller cost, and it keeps
/// the trees readable, which is where the bugs would otherwise hide.
///
/// Pure Dart, like everything under `lib/game/sim` — see
/// docs/12-architecture.md §12.0.
class AiContext {
  AiContext({
    required this.content,
    required this.entities,
    required this.enemies,
    required this.status,
    required this.spatial,
    required this.arena,
    required this.events,
    required this.telegraphs,
    required this.hazards,
    required this.lines,
    required this.lineIndex,
    required this.rng,
  }) : _segmentScratch = Int32List(SimConfig.maxWindlineSegments);

  final ContentLibrary content;
  final EntityStore entities;
  final EnemyStore enemies;
  final StatusStore status;
  final SpatialHash spatial;

  /// The room's collision geometry.
  ///
  /// Not final: a stage swaps arenas between rooms, and an AI holding the
  /// previous room's walls would path against geometry that is no longer there.
  Arena arena;
  final SimEventBuffer events;
  final TelegraphStore telegraphs;
  final HazardStore hazards;

  /// The player's Windlines. Enemies crossing one are slowed — which is what
  /// turns the trail from a damage mechanic into a *zoning* one, and is the
  /// reason weaving a lattice is worth doing even when nothing threads it.
  final WindlineStore lines;

  final SegmentHash lineIndex;

  /// The AI's own generator, split off the run seed so that adding an enemy
  /// behaviour does not reshuffle Boon draws or room composition.
  final Rng rng;

  final Int32List _segmentScratch;

  // ── Per-tick state ────────────────────────────────────────────────────────

  double dt = SimConfig.fixedStep;
  double now = 0;

  /// `Curves.enemyHp(globalStage)` for the room being played — the absolute HP
  /// a x1.0 enemy has here. Every enemy's health is this times its multiplier,
  /// which is how one number per enemy covers all 240 stages (docs/05 §5.0).
  double enemyHpBase = 44.0;

  /// Contact-capable enemies allowed on screen at once.
  ///
  /// A quality setting (docs/19 §19.4: 60 on Battery, 90 otherwise) rather than
  /// a constant, and therefore a *gameplay* difference between tiers as well as
  /// a performance one. It caps concurrency, never total room threat — a
  /// Battery player fights the same room, arriving in more waves.
  int enemyCap = SimConfig.maxContactEnemies;

  /// Global stage index, 1-based. Drives variant availability and nothing else
  /// in this layer — the curves are pre-resolved into [enemyHpBase].
  int globalStage = 1;

  /// Entity slot of the player, or -1 when there is none. Every behaviour
  /// checks this: a room whose player has died must not crash, it must go
  /// quiet.
  int player = -1;

  double playerX = 0;
  double playerY = 0;
  double playerVelX = 0;
  double playerVelY = 0;
  double playerMaxHealth = 1;
  double playerRadius = SimConfig.playerRadius;

  /// The player's Draw and Momentum state. Read for damage reduction, written
  /// by the Screecher's Draw-lock.
  DrawState? playerDraw;

  /// Which Boon behaviours are live, and their state.
  ///
  /// Null in a world with no Boons at all, which is every test that predates
  /// Phase 9. [EnemyAttack.damagePlayer] treats null as "no Boons" rather than
  /// requiring every caller to construct one.
  BoonRuntime? boons;

  /// Composed mitigation and modifiers. Same nullability contract as [boons].
  CombatModifiers? combat;

  /// Multiplier on incoming damage from the player's own build — mitigation
  /// already combined and capped. 1.0 means unmodified.
  double incomingDamageFactor = 1.0;

  /// How long an *Echo Thread* (#69) line lasts.
  double echoLineDuration = 1.0;

  /// Serial source for trails a Boon lays, kept distinct from the player's
  /// arrows so Confluence still dedupes correctly.
  int _echoTrailId = -1;

  int nextEchoTrailId() => _echoTrailId--;

  /// True on ticks the player released an arrow. The Echo fires when the player
  /// fires, which is the only enemy in the game driven by the player's input
  /// rather than by their position.
  bool playerFired = false;

  bool get hasPlayer => player >= 0 && entities.alive[player] == 1;

  /// Whether this slot references a real content row.
  ///
  /// Tests and the render-layer sandbox spawn bare entities with no definition
  /// behind them. They are legitimate targets and they die normally; they just
  /// have no behaviour, so every AI pass steps over them rather than indexing
  /// past the end of the content table.
  bool hasDefinition(int slot) {
    final int index = entities.contentIndex[slot];
    return index >= 0 && index < content.enemies.length;
  }

  /// The definition behind an enemy slot.
  EnemyDefinition definitionOf(int slot) =>
      content.enemies[entities.contentIndex[slot]];

  EnemyArchetype archetypeOf(int slot) =>
      content.enemies[entities.contentIndex[slot]].archetype;

  /// Scratch buffer for Windline queries. Callers must consume the result
  /// before the next query — the same contract [SpatialHash] uses, for the same
  /// reason: a fresh list per query would allocate thousands of times a tick.
  Int32List get segmentScratch => _segmentScratch;

  /// Squared distance from an enemy to the player. Squared because the callers
  /// are comparisons, and a square root per enemy per tick buys nothing.
  double distanceSquaredToPlayer(int slot) {
    final double dx = playerX - entities.posX[slot];
    final double dy = playerY - entities.posY[slot];
    return dx * dx + dy * dy;
  }
}
