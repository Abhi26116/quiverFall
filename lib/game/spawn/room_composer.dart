import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/clear_time.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/spawn/composition_validator.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';

/// Builds a room's enemy composition from a threat budget.
///
/// The composer's job is to spend `TB = 100 · 1.04^(G-1)` without breaking any
/// of the rules in docs/05 §5.7 — and it is written so that satisfying them is
/// structural rather than incidental. The safe-threat floor, for instance, is
/// met by *allocating* the budget in two parts before anything is picked, not by
/// picking freely and hoping.
///
/// [CompositionValidator] then checks the result anyway. A generator that
/// polices itself and a validator that polices the generator are not redundant:
/// the validator is what makes Phase 8's level generator, remote-config
/// retuning, and hand-authored rooms all subject to the same rules.
abstract final class RoomComposer {
  /// Share of a normal room's budget reserved for Drift and Rush.
  ///
  /// Comfortably above the 40 % floor, because the floor is a *minimum* and a
  /// room sitting exactly on a minimum has no room for the rounding that
  /// greedy packing produces.
  static const double safeBudgetShare = 0.55;

  /// Enemies per wave before another wave is opened.
  static const int enemiesPerWave = 8;

  static const int maxWaves = 3;

  /// Probability an enemy in a chapter-9+ room carries a variant.
  static const double variantChance = 0.35;

  /// Enemies a single room may contain, across all its waves.
  ///
  /// Distinct from [SimConfig.maxContactEnemies], which is the *simultaneous*
  /// ceiling docs/14 §14.4 sets for readability. A room may hold more than that
  /// in total because waves arrive in sequence — the spawn system is what keeps
  /// the on-screen count under the cap.
  static const int maxRoomEnemies = 40;

  /// Bound on the packing loop. A pool of cheap fodder against a late-game
  /// budget could otherwise iterate a long way; the cap is far above any
  /// legitimate room and turns a content bug into a slightly empty room rather
  /// than a hung tick.
  static const int _packingGuard = 256;

  static RoomPlan compose({
    required ContentLibrary content,
    required Rng rng,
    required int chapter,
    required int globalStage,
    bool isElite = false,
  }) {
    final double budget = Curves.threatBudget(globalStage);
    final List<int> roster = _rosterFor(content, chapter);

    final _Packing packing = _Packing(content, chapter, rng);

    if (isElite) {
      final List<int> riftborn =
          _filter(content, roster, EnemyFamily.riftborn);
      if (riftborn.isNotEmpty) {
        packing.take(riftborn[rng.nextInt(riftborn.length)], double.infinity);
        packing.fill(
          _filter(content, roster, null),
          budget * CompositionValidator.eliteSupportShare,
        );
        return _toPlan(packing, budget, chapter, globalStage, isElite: true);
      }
      // No Riftborn is available this early. Falls through to a normal room
      // rather than producing an Elite room with no elite in it.
    }

    final List<int> safe = <int>[
      ..._filter(content, roster, EnemyFamily.drift),
      ..._filter(content, roster, EnemyFamily.rush),
    ];
    final List<int> rest = _filter(content, roster, null);

    packing.fill(safe, budget * safeBudgetShare);
    packing.fill(rest, budget - packing.spent);
    packing.topUpSafeShare(safe, budget);

    return _toPlan(packing, budget, chapter, globalStage, isElite: false);
  }

  static List<int> _rosterFor(ContentLibrary content, int chapter) {
    final List<int> out = <int>[];
    for (int i = 0; i < content.enemies.length; i++) {
      if (content.enemies[i].introducedInChapter <= chapter) out.add(i);
    }
    return out;
  }

  /// Indices of one family, or of everything spawnable in a normal room.
  static List<int> _filter(
    ContentLibrary content,
    List<int> roster,
    EnemyFamily? family,
  ) {
    final List<int> out = <int>[];
    for (final int i in roster) {
      final EnemyFamily f = content.enemies[i].family;
      if (family != null) {
        if (f == family) out.add(i);
        continue;
      }
      // Riftborn are elites and never fill a normal room's budget.
      if (f != EnemyFamily.riftborn) out.add(i);
    }
    return out;
  }

  static RoomPlan _toPlan(
    _Packing packing,
    double budget,
    int chapter,
    int globalStage, {
    required bool isElite,
  }) {
    return RoomPlan(
      waves: _split(packing.picks),
      threatBudget: budget,
      chapter: chapter,
      globalStage: globalStage,
      isElite: isElite,
    );
  }

  /// Splits a room's enemies into waves.
  ///
  /// Front-loaded: the first wave is the largest, so a room opens with a fight
  /// rather than a trickle. Later waves are the escalation.
  static List<WavePlan> _split(List<PlannedEnemy> picks) {
    if (picks.isEmpty) return const <WavePlan>[WavePlan(<PlannedEnemy>[])];

    int waveCount = 1 + (picks.length - 1) ~/ enemiesPerWave;
    if (waveCount > maxWaves) waveCount = maxWaves;

    int perWave = (picks.length + waveCount - 1) ~/ waveCount;
    if (perWave > SimConfig.maxContactEnemies) {
      perWave = SimConfig.maxContactEnemies;
    }

    final List<WavePlan> waves = <WavePlan>[];
    for (int i = 0; i < picks.length; i += perWave) {
      final int end =
          i + perWave > picks.length ? picks.length : i + perWave;
      waves.add(WavePlan(picks.sublist(i, end)));
    }
    return waves;
  }
}

/// Mutable packing state. Private to the composer.
class _Packing {
  _Packing(this.content, this.chapter, this.rng);

  final ContentLibrary content;
  final int chapter;
  final Rng rng;

  final List<PlannedEnemy> picks = <PlannedEnemy>[];

  double spent = 0;

  /// Estimated seconds to clear what has been picked so far.
  ///
  /// The threat budget is the binding constraint in early chapters and stops
  /// binding entirely later: `TB = 100 · 1.04^(G-1)` reaches six figures by
  /// chapter 12 while enemy threat costs stay fixed. From roughly chapter 4
  /// onward it is **clear time** that decides how big a room is, which is what
  /// docs/14 §14.2 actually cares about.
  double seconds = 0;

  int choirCount = 0;
  bool hasScreecher = false;
  bool hasLongeye = false;

  bool canTake(int index, double remaining) {
    final EnemyDefinition def = content.enemies[index];
    if (def.threatCost > remaining) return false;
    if (picks.length >= RoomComposer.maxRoomEnemies) return false;

    // Stop short of the 55 s rejection ceiling rather than at it: greedy
    // packing cannot see the enemy it is about to add, so a composer aiming at
    // the ceiling overshoots it routinely and gets rejected by its own
    // validator.
    if (seconds + ClearTimeModel.secondsForOne(def) >
        ClearTimeModel.packingTarget) {
      return false;
    }

    if (def.family == EnemyFamily.choir &&
        choirCount >= CompositionValidator.maxChoirPerRoom) {
      return false;
    }

    // Draw-lock into a 22 % hitscan is an unfair combination for a learning
    // player, so the pairing simply cannot be assembled before chapter 8.
    if (chapter < CompositionValidator.screecherLongeyeChapter) {
      if (def.archetype == EnemyArchetype.screecher && hasLongeye) return false;
      if (def.archetype == EnemyArchetype.longeye && hasScreecher) return false;
    }

    return true;
  }

  void take(int index, double remaining) {
    final EnemyDefinition def = content.enemies[index];
    final EnemyVariant variant = _rollVariant(def, remaining);

    picks.add(PlannedEnemy(index, variant));
    spent += def.threatCost * variant.threatMultiplier;
    seconds += ClearTimeModel.secondsForOne(def);

    if (def.family == EnemyFamily.choir) choirCount++;
    if (def.archetype == EnemyArchetype.screecher) hasScreecher = true;
    if (def.archetype == EnemyArchetype.longeye) hasLongeye = true;
  }

  /// Chapters 9–12 add no new base types; they recombine the existing 26 into
  /// roughly 104 effective encounters (docs/05 §5.8). This is where that
  /// happens, and it is the only reason the late campaign stays novel without a
  /// second art budget.
  EnemyVariant _rollVariant(EnemyDefinition def, double remaining) {
    if (chapter < EnemyVariant.firstChapter) return EnemyVariant.none;
    if (!rng.chance(RoomComposer.variantChance)) return EnemyVariant.none;

    final EnemyVariant candidate =
        EnemyVariant.values[1 + rng.nextInt(EnemyVariant.values.length - 1)];
    final double cost = def.threatCost * candidate.threatMultiplier;
    return cost <= remaining ? candidate : EnemyVariant.none;
  }

  /// Greedily spends [budget] from [pool], weighting cheap fodder higher.
  ///
  /// Inverse-cost weighting is what keeps rooms *populated*: uniform picking
  /// against a late-game budget produces four expensive units and an empty
  /// arena, which is neither readable nor fun to shoot.
  void fill(List<int> pool, double budget) {
    if (pool.isEmpty || budget <= 0) return;

    final double start = spent;
    final List<int> affordable = <int>[];
    final List<double> weights = <double>[];

    for (int guard = 0; guard < RoomComposer._packingGuard; guard++) {
      final double remaining = budget - (spent - start);
      if (remaining <= 0) break;

      affordable.clear();
      weights.clear();
      for (final int index in pool) {
        if (!canTake(index, remaining)) continue;
        affordable.add(index);
        weights.add(1.0 / content.enemies[index].threatCost);
      }
      if (affordable.isEmpty) break;

      take(affordable[rng.pickWeightedIndex(weights)], remaining);
    }
  }

  /// Adds cheap Drift/Rush units until the safe-threat floor is met.
  ///
  /// Greedy packing can land a hair under the floor when the expensive half of
  /// the budget happens to fill perfectly. Topping up is always possible and
  /// always correct — adding safe threat raises the ratio monotonically — so
  /// this converges rather than looping.
  void topUpSafeShare(List<int> safePool, double budget) {
    if (safePool.isEmpty) return;

    int cheapest = safePool.first;
    for (final int index in safePool) {
      if (content.enemies[index].threatCost <
          content.enemies[cheapest].threatCost) {
        cheapest = index;
      }
    }

    for (int guard = 0; guard < RoomComposer._packingGuard; guard++) {
      if (_safeShare() >= CompositionValidator.minSafeThreatShare) return;
      if (!canTake(cheapest, budget - spent)) return;
      // Deliberately variant-free: this is a correction, and paying a variant
      // premium here could push the room back over its budget.
      picks.add(PlannedEnemy(cheapest));
      spent += content.enemies[cheapest].threatCost;
      seconds += ClearTimeModel.secondsForOne(content.enemies[cheapest]);
    }
  }

  double _safeShare() {
    double total = 0;
    double safe = 0;
    for (final PlannedEnemy e in picks) {
      final double cost = e.threatIn(content);
      total += cost;
      final EnemyFamily family = e.definitionIn(content).family;
      if (family == EnemyFamily.drift || family == EnemyFamily.rush) {
        safe += cost;
      }
    }
    return total <= 0 ? 1.0 : safe / total;
  }
}
