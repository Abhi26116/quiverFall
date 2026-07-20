import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/clear_time.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/level/arena_definition.dart';
import 'package:quiverfall/game/level/blueprint_validator.dart';
import 'package:quiverfall/game/level/room_blueprint.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/spawn/composition_validator.dart';
import 'package:quiverfall/game/spawn/room_composer.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';

/// Builds rooms.
///
/// The six-step pipeline from docs/14 §14.2:
///
/// ```
/// 1. Pick arena       — weighted by chapter tag pool, excluding the last 2
///                       used, biased toward latticeHints from chapter 5+
/// 2. Compute budget   — TB = 100 · 1.04^(G−1)
/// 3. Fill budget      — draw from the chapter roster, subject to 05 §5.7
/// 4. Assign waves     — 1–3 waves
/// 5. Place spawns     — family whitelists and the 3.5 u rule
/// 6. Validate         — reject and reroll, max 8 attempts, then fall back
/// ```
///
/// **Step 6 is why this is safe.** The generator is allowed to fail; it is not
/// allowed to ship a bad room. Steps 2–4 are [RoomComposer], which Phase 5
/// built and which the balance harness shares; this owns the arena, the
/// placement and the reroll loop.
class LevelGenerator {
  LevelGenerator({
    required this.content,
    required this.arenas,
  });

  final ContentLibrary content;
  final List<ArenaDefinition> arenas;

  /// docs/14 §14.2: reroll up to eight times, then take the fallback.
  static const int maxAttempts = 8;

  /// Arenas that may not be re-picked immediately.
  ///
  /// Two is enough to stop the obvious "same room three times" complaint
  /// without starving chapters that only have four or five arenas authored.
  static const int arenaCooldown = 2;

  /// From this chapter, arena selection is biased toward lattice geometry.
  ///
  /// The point in the campaign where a player has met Confluence often enough
  /// to start building around it (docs/14 §14.1).
  static const int latticeBiasChapter = 5;

  /// Extra selection weight an arena gets for having lattice hints.
  static const double latticeWeight = 2.5;

  final List<String> _recent = <String>[];

  /// Arenas most recently used, oldest first. Exposed for the stage runner,
  /// which carries it across rooms.
  List<String> get recentArenas => List<String>.unmodifiable(_recent);

  /// Builds one room.
  ///
  /// [rng] is the stage's generator, so a stage seed reproduces the whole stage
  /// room for room.
  RoomBlueprint generate({
    required Rng rng,
    required RoomSlot slot,
    required int chapter,
    required int globalStage,
  }) {
    final List<ArenaDefinition> pool = _poolFor(chapter);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final ArenaDefinition arena = _pickArena(rng, pool, chapter);
      final RoomBlueprint candidate = _assemble(
        rng: rng,
        arena: arena,
        slot: slot,
        chapter: chapter,
        globalStage: globalStage,
        attempts: attempt,
      );

      if (BlueprintValidator.validate(candidate, content).isEmpty) {
        _remember(arena.id);
        return candidate;
      }
    }

    return _fallback(
      rng: rng,
      pool: pool,
      slot: slot,
      chapter: chapter,
      globalStage: globalStage,
    );
  }

  /// Composes, places, and prices a candidate. No validation — the caller does
  /// that, because a candidate that fails is still a useful thing to inspect.
  RoomBlueprint _assemble({
    required Rng rng,
    required ArenaDefinition arena,
    required RoomSlot slot,
    required int chapter,
    required int globalStage,
    required int attempts,
    bool usedFallback = false,
  }) {
    final RoomPlan plan = RoomComposer.compose(
      content: content,
      rng: rng,
      chapter: chapter,
      globalStage: globalStage,
      isElite: slot.kind == RoomKind.elite,
    );

    final RoomPlan placed = _place(rng, arena, plan);

    return RoomBlueprint(
      arena: arena,
      plan: placed,
      slot: slot,
      estimatedSeconds: ClearTimeModel.secondsFor(
        placed.waves
            .expand((WavePlan w) => w.enemies)
            .map((PlannedEnemy e) => e.definitionIn(content)),
        waves: placed.waves.length,
      ),
      attempts: attempts,
      usedFallback: usedFallback,
    );
  }

  // ── Step 1: arena selection ───────────────────────────────────────────────

  List<ArenaDefinition> _poolFor(int chapter) {
    final List<ArenaDefinition> pool = arenas
        .where((ArenaDefinition a) => a.allowsChapter(chapter))
        .toList(growable: false);

    // A chapter with no arenas authored yet would otherwise fail at the pick.
    // Falling back to the whole set keeps an unfinished content pass playable
    // rather than crashing on the chapter nobody has reached.
    return pool.isEmpty ? arenas : pool;
  }

  ArenaDefinition _pickArena(
    Rng rng,
    List<ArenaDefinition> pool,
    int chapter,
  ) {
    final List<ArenaDefinition> eligible = pool
        .where((ArenaDefinition a) => !_recent.contains(a.id))
        .toList(growable: false);

    // If the cooldown has eaten the pool, ignore it rather than fail. Repeating
    // an arena is a much smaller problem than not producing a room.
    final List<ArenaDefinition> from = eligible.isEmpty ? pool : eligible;
    if (from.length == 1) return from.first;

    final List<double> weights = <double>[
      for (final ArenaDefinition a in from)
        chapter >= latticeBiasChapter && a.hasLatticeHints
            ? latticeWeight
            : 1.0,
    ];

    return from[rng.pickWeightedIndex(weights)];
  }

  void _remember(String id) {
    _recent.add(id);
    while (_recent.length > arenaCooldown) {
      _recent.removeAt(0);
    }
  }

  /// Restores a cooldown carried across rooms of a stage.
  void primeRecent(Iterable<String> ids) {
    _recent
      ..clear()
      ..addAll(ids);
    while (_recent.length > arenaCooldown) {
      _recent.removeAt(0);
    }
  }

  // ── Step 5: placement ─────────────────────────────────────────────────────

  /// Assigns every enemy an authored spawn point its family may use.
  ///
  /// docs/14 §14.4's family rules are what make a room readable rather than
  /// merely survivable: Salvo at the edges and at range, Rush at mid-distance
  /// so its approach can be seen coming, Choir *behind* its pack so the
  /// priority target is visually obvious, Riftborn central.
  RoomPlan _place(Rng rng, ArenaDefinition arena, RoomPlan plan) {
    final List<WavePlan> waves = <WavePlan>[];

    for (final WavePlan wave in plan.waves) {
      final List<PlannedEnemy> placed = <PlannedEnemy>[];

      for (final PlannedEnemy enemy in wave.enemies) {
        final EnemyDefinition def = enemy.definitionIn(content);
        final List<SpawnPoint> points = _pointsFor(arena, def.family);

        if (points.isEmpty) {
          // No legal point for this family in this arena. Left unplaced so the
          // validator rejects the room rather than the enemy landing somewhere
          // its family rules forbid.
          placed.add(enemy);
          continue;
        }

        final SpawnPoint point = points[rng.nextInt(points.length)];

        // Jittered so a pack from one point does not stack into a single
        // silhouette before separation pushes it apart.
        //
        // **Jitter must never push an enemy into a wall.** Movement is
        // axis-separated with no pathfinding, so an enemy that starts inside
        // geometry has both axes blocked and never moves again — and a room
        // with one stuck enemy never clears, which deadlocks the whole stage.
        // The authored point is validated clear of walls, so it is always a
        // safe answer to fall back to.
        double x =
            _clampX(point.x + rng.nextDoubleRange(-_jitter, _jitter), def);
        double y =
            _clampY(point.y + rng.nextDoubleRange(-_jitter, _jitter), def);
        if (_blocked(arena, x, y, def.radius)) {
          x = point.x;
          y = point.y;
        }

        placed.add(enemy.placedAt(x, y));
      }

      waves.add(WavePlan(placed));
    }

    return RoomPlan(
      waves: waves,
      threatBudget: plan.threatBudget,
      chapter: plan.chapter,
      globalStage: plan.globalStage,
      isElite: plan.isElite,
    );
  }

  static const double _jitter = 0.45;

  /// True if a circle here would overlap a wall.
  ///
  /// Cover is deliberately not checked: it blocks projectiles, not movement,
  /// so an enemy standing in cover is legal and occasionally clever.
  bool _blocked(ArenaDefinition arena, double x, double y, double radius) {
    for (final ArenaRect wall in arena.walls) {
      if (wall.overlapsCircle(x, y, radius + 0.05)) return true;
    }
    return false;
  }

  List<SpawnPoint> _pointsFor(ArenaDefinition arena, EnemyFamily family) {
    final List<SpawnPoint> allowed = arena.pointsFor(family);
    if (allowed.isEmpty) return allowed;

    // Riftborn get the elite points if any exist; everything else avoids them,
    // so an elite always has the space its entrance needs.
    if (family == EnemyFamily.riftborn) {
      final List<SpawnPoint> elite = allowed
          .where((SpawnPoint p) => p.kind == SpawnKind.elite)
          .toList(growable: false);
      if (elite.isNotEmpty) return elite;
      return allowed;
    }

    final List<SpawnPoint> nonElite = allowed
        .where((SpawnPoint p) => p.kind != SpawnKind.elite)
        .toList(growable: false);
    return nonElite.isEmpty ? allowed : nonElite;
  }

  double _clampX(double x, EnemyDefinition def) {
    final double r = def.radius + 0.05;
    return x < r ? r : (x > 16.0 - r ? 16.0 - r : x);
  }

  double _clampY(double y, EnemyDefinition def) {
    final double r = def.radius + 0.05;
    return y < r ? r : (y > 9.0 - r ? 9.0 - r : y);
  }

  // ── Step 6: the fallback ──────────────────────────────────────────────────

  /// A known-good encounter, used when eight attempts all failed.
  ///
  /// **Not a random retry.** It is a deliberately conservative room — the
  /// safest arena in the pool, a chapter-1 composition, no elite — chosen so
  /// that it is impossible for it to be the thing that fails. A fallback that
  /// could itself be invalid would defeat the entire point of step 6.
  ///
  /// Reaching this is a generator bug, and [RoomBlueprint.usedFallback] says
  /// so loudly enough for a test to fail on it.
  RoomBlueprint _fallback({
    required Rng rng,
    required List<ArenaDefinition> pool,
    required RoomSlot slot,
    required int chapter,
    required int globalStage,
  }) {
    final ArenaDefinition arena = pool.firstWhere(
      (ArenaDefinition a) => a.tags.contains(ArenaTag.open),
      orElse: () => pool.first,
    );

    return _assemble(
      rng: rng,
      arena: arena,
      // A Normal slot: an Elite fallback would need a Riftborn, and needing
      // something specific is exactly how a fallback fails.
      slot: RoomSlot(index: slot.index, kind: RoomKind.normal),
      chapter: 1,
      globalStage: globalStage < 20 ? globalStage : 20,
      attempts: maxAttempts,
      usedFallback: true,
    );
  }
}

/// A whole stage's worth of rooms.
class StagePlan {
  const StagePlan({required this.blueprint, required this.rooms});

  final StageBlueprint blueprint;
  final List<RoomBlueprint> rooms;

  int get roomCount => rooms.length;

  bool get usedAnyFallback => rooms.any((RoomBlueprint r) => r.usedFallback);

  double get totalEstimatedSeconds => rooms.fold(
        0,
        (double a, RoomBlueprint r) => a + r.estimatedSeconds,
      );

  /// Every violation across the stage. Empty is the only shippable answer.
  List<CompositionViolation> validate(ContentLibrary content) =>
      <CompositionViolation>[
        for (final RoomBlueprint room in rooms)
          ...BlueprintValidator.validate(room, content),
      ];
}

/// Builds a whole stage in one call.
///
/// The arena cooldown is carried across rooms, which is the only piece of state
/// that has to survive between them — and the reason the generator is an object
/// rather than a static function.
StagePlan generateStage({
  required LevelGenerator generator,
  required StageBlueprint blueprint,
}) {
  final Rng rng = Rng(blueprint.seed);
  final List<RoomBlueprint> rooms = <RoomBlueprint>[];

  // Shrine rooms still get an arena and a composition. Phase 13 turns them
  // into the actual push-or-bank sink; until then a Shrine slot is a normal
  // fight in a Shrine's place, which is playable rather than a hole in the
  // stage.
  for (final RoomSlot slot in blueprint.rooms) {
    rooms.add(
      generator.generate(
        rng: rng,
        slot: slot,
        chapter: blueprint.chapter,
        globalStage: blueprint.globalStage,
      ),
    );
  }

  return StagePlan(blueprint: blueprint, rooms: rooms);
}
