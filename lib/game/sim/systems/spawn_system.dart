import 'dart:typed_data';

import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/sim/ai/ai_context.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/spawn/enemy_spawner.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';

/// Progress through a room's [RoomPlan].
///
/// Held by the world rather than by the system, because the system is static
/// and stateless like every other system in the sim — which is what lets the
/// balance harness run ten thousand rooms without ten thousand system objects.
class SpawnState {
  SpawnState({this.capacity = SimConfig.maxContactEnemies})
      : _pendingContent = Int32List(capacity),
        _pendingVariant = Uint8List(capacity),
        _pendingX = Float64List(capacity),
        _pendingY = Float64List(capacity),
        _pendingTimer = Float64List(capacity),
        _pendingTelegraph = Int32List(capacity),
        _pendingSerial = Int32List(capacity),
        _pendingAlive = Uint8List(capacity);

  final int capacity;

  RoomPlan? plan;

  /// Index of the next wave to release.
  int nextWave = 0;

  /// How many enemies the most recently released wave contained. The next wave
  /// releases when the arena is down to a fraction of it.
  int lastWaveSize = 0;

  double sinceLastWave = 0;

  bool roomClearedEmitted = false;

  // ── Pending spawns ────────────────────────────────────────────────────────
  //
  // An enemy does not appear the instant its wave releases. It is announced by
  // a 0.4 s edge-flash at the spawn location first (docs/05 §5.7), so that an
  // off-screen spawn is never the first the player knows of it.

  final Int32List _pendingContent;
  final Uint8List _pendingVariant;
  final Float64List _pendingX;
  final Float64List _pendingY;
  final Float64List _pendingTimer;
  final Int32List _pendingTelegraph;
  final Int32List _pendingSerial;
  final Uint8List _pendingAlive;

  int pendingCount = 0;

  bool get hasPending => pendingCount > 0;

  bool get allWavesReleased => plan == null || nextWave >= plan!.waves.length;

  void reset() {
    plan = null;
    nextWave = 0;
    lastWaveSize = 0;
    sinceLastWave = 0;
    roomClearedEmitted = false;
    for (int i = 0; i < capacity; i++) {
      _pendingAlive[i] = 0;
    }
    pendingCount = 0;
  }

  void begin(RoomPlan roomPlan) {
    reset();
    plan = roomPlan;
    // The first wave lands immediately; the room opens with a fight.
    sinceLastWave = EnemyTuning.waveIntervalSeconds;
  }
}

/// Releases waves and turns a [RoomPlan] into live enemies.
///
/// Two rules are enforced here rather than left to the composer, because both
/// are about *where and when* rather than *what*:
///
///  - **No enemy spawns within 3.5 u of the player.** A spawn on top of the
///    player is unavoidable damage, and unavoidable damage is the one thing a
///    fair action game may never do.
///  - **Every spawn is announced.** The 0.4 s edge-flash means the player is
///    told before they are attacked, which is the same promise every telegraph
///    in the game makes.
abstract final class SpawnSystem {
  static void update(AiContext ctx, SpawnState state) {
    if (state.plan == null) return;

    _resolvePending(ctx, state);

    state.sinceLastWave += ctx.dt;
    _maybeReleaseWave(ctx, state);
    _maybeClearRoom(ctx, state);
  }

  static void _resolvePending(AiContext ctx, SpawnState state) {
    for (int i = 0; i < state.capacity; i++) {
      if (state._pendingAlive[i] == 0) continue;

      state._pendingTimer[i] -= ctx.dt;
      if (state._pendingTimer[i] > 0) continue;

      ctx.telegraphs.release(state._pendingTelegraph[i], state._pendingSerial[i]);
      state._pendingAlive[i] = 0;
      state.pendingCount--;

      EnemySpawner.spawn(
        ctx,
        contentIndex: state._pendingContent[i],
        x: state._pendingX[i],
        y: state._pendingY[i],
        variant: EnemyVariant.values[state._pendingVariant[i]],
      );
    }
  }

  static void _maybeReleaseWave(AiContext ctx, SpawnState state) {
    final RoomPlan plan = state.plan!;
    if (state.nextWave >= plan.waves.length) return;
    if (state.hasPending) return;
    if (state.sinceLastWave < EnemyTuning.waveIntervalSeconds) return;

    // The next wave arrives while the last one is still dying, not after the
    // arena has gone empty — an empty arena between waves reads as the room
    // being over.
    final int alive = _aliveEnemies(ctx);
    if (state.nextWave > 0 &&
        alive > state.lastWaveSize * EnemyTuning.waveReleaseThreshold) {
      return;
    }

    final WavePlan wave = plan.waves[state.nextWave];
    state.nextWave++;
    state.lastWaveSize = wave.size;
    state.sinceLastWave = 0;

    for (final PlannedEnemy planned in wave.enemies) {
      if (state.pendingCount >= state.capacity) break;
      if (alive + state.pendingCount >= SimConfig.maxContactEnemies) break;
      _queue(ctx, state, planned);
    }
  }

  static void _queue(AiContext ctx, SpawnState state, PlannedEnemy planned) {
    final double radius = ctx.content.enemies[planned.contentIndex].radius;
    EnemySpawner.findSpawnPoint(ctx, radius);

    for (int i = 0; i < state.capacity; i++) {
      if (state._pendingAlive[i] == 1) continue;

      final int telegraph = ctx.telegraphs.add(
        shape: TelegraphShape.circle,
        severity: TelegraphSeverity.warning,
        owner: -1,
        x: EnemySpawner.pointX,
        y: EnemySpawner.pointY,
        radius: radius * 2,
        startedAt: ctx.now,
        resolvesAt: ctx.now + EnemyTuning.spawnTelegraphSeconds,
      );

      state._pendingAlive[i] = 1;
      state._pendingContent[i] = planned.contentIndex;
      state._pendingVariant[i] = planned.variant.index;
      state._pendingX[i] = EnemySpawner.pointX;
      state._pendingY[i] = EnemySpawner.pointY;
      state._pendingTimer[i] = EnemyTuning.spawnTelegraphSeconds;
      state._pendingTelegraph[i] = telegraph;
      state._pendingSerial[i] =
          telegraph < 0 ? 0 : ctx.telegraphs.serialAt(telegraph);
      state.pendingCount++;
      return;
    }
  }

  static void _maybeClearRoom(AiContext ctx, SpawnState state) {
    if (state.roomClearedEmitted) return;
    if (!state.allWavesReleased) return;
    if (state.hasPending) return;
    if (_aliveEnemies(ctx) > 0) return;

    state.roomClearedEmitted = true;
    ctx.events.emit(SimEventType.roomCleared);
  }

  static int _aliveEnemies(AiContext ctx) {
    int n = 0;
    final int high = ctx.entities.highWater;
    for (int i = 0; i < high; i++) {
      if (ctx.entities.alive[i] == 0) continue;
      if (ctx.entities.kind[i] == EntityKind.enemy.index) n++;
    }
    return n;
  }
}
