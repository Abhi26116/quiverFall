import 'dart:math' as math;

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/level/arena_definition.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';

/// The "average Boon draw" half of docs/02 §2.6's expected-power definition
/// — a headless bot that actually plays a stage rather than approximating
/// what a Boon draw might look like.
///
/// The fighting rhythm (root to escalate the Draw, roam so line of sight
/// reaches every corner of a walled arena) is `stage_runner_test.dart`'s own
/// proven bot, copied rather than imported — that file is a test, this is
/// `lib/`, and duplicating roughly twenty lines of movement logic is cheaper
/// than making a test file part of the harness's own dependency surface.
/// What is new here is resolving the two interstitials a real run pauses on
/// that a plain stage-completion check never needs to: a Boon Choice and a
/// Shrine. See ADR 0091 for why each resolves the way it does.
abstract final class HarnessBot {
  /// A dedicated stream, split off the world's own seed, so which Boon this
  /// bot happens to draw from a tied offer never perturbs any other seeded
  /// sequence (crit rolls, AI phase, elemental application chance) — the
  /// same reasoning `StageRunner`'s own `_boonRng` is split for.
  static const int _boonPickRngLabel = 0xBA55;

  /// Plays [runner] until [runner.roomIndex] reaches [targetRoomIndex], or
  /// the stage ends first — check `runner.status` after return to tell the
  /// two apart. Every Boon Choice reached along the way is resolved with a
  /// uniform-random pick among the offers (ADR 0091's "average"); a Shrine
  /// room is passed through with no purchase (the harness does not model a
  /// gold-spending policy — same ADR).
  ///
  /// Room index, not a Boon count: docs/02 §2.6 says "at room 5", and a
  /// short stage's own final room clear never offers a Boon at all (`
  /// StageRunner.update`'s own `isLastRoom` check completes the stage
  /// instead) — a 6-room stage (`StageBlueprint.roomCount`'s own floor)
  /// offers at most 5 choices in total, fewer still if a Shrine room eats
  /// one of those slots. Counting picks instead of rooms would make "room
  /// 5" unreachable on exactly the short early chapters this harness most
  /// needs a reading from.
  ///
  /// [maxSeconds] is generous on purpose: an expected-power loadout well
  /// short of viable this early can be genuinely slow to clear rooms, and a
  /// harness call that returns having simply run out of time (rather than
  /// hanging) is easy to tell from a real death — check `runner.status`.
  static void playToRoom(
    StageRunner runner,
    SimWorld world, {
    required int targetRoomIndex,
    double maxSeconds = 900,
  }) {
    final Rng pickRng = world.rngFor(_boonPickRngLabel);
    final InputSnapshot input = InputSnapshot();
    final int maxTicks = (maxSeconds * 60).round();

    for (int tick = 0; tick < maxTicks; tick++) {
      if (runner.roomIndex >= targetRoomIndex) return;
      if (runner.status == StageStatus.complete ||
          runner.status == StageStatus.failed) {
        return;
      }

      if (runner.status == StageStatus.awaitingBoonChoice) {
        final offer = pickRng.pick(runner.pendingBoonOffers);
        runner.pickBoon(offer.definition);
        continue;
      }
      if (runner.status == StageStatus.awaitingShrine) {
        runner.leaveShrine();
        continue;
      }

      // Invulnerable while fighting, the same choice
      // `stage_runner_test.dart`'s own bot makes: this measures whether a
      // Boon draw is reachable, not whether this particular scripted bot is
      // good enough to survive to it.
      if (world.entities.isAlive(world.player)) {
        final int p = world.player.index;
        world.entities.health[p] = world.entities.maxHealth[p];
      }

      final double t = tick / 60.0;
      const double leg = 3.4;
      final List<SpawnPoint> waypoints = runner.room.arena.spawnPoints;
      final int index = (t / leg).floor() % waypoints.length;
      final bool rooting = t % leg > 2.0;

      if (rooting || !world.entities.isAlive(world.player)) {
        input.set(0, 0);
      } else {
        final int p = world.player.index;
        final double dx = waypoints[index].x - world.entities.posX[p];
        final double dy = waypoints[index].y - world.entities.posY[p];
        final double len = math.sqrt(dx * dx + dy * dy);
        if (len < 0.2) {
          input.set(0, 0);
        } else {
          input.set(dx / len, dy / len);
        }
      }

      world.tick(input);
      world.events.clear();
      runner.update();
    }
  }
}
