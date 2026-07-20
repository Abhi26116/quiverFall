import 'dart:io';
import 'dart:math' as math;

import 'package:quiverfall/features/gameplay/application/feel_telemetry.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/level/arena_definition.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';

/// How discoverable is Confluence, for players who are not trying?
///
/// The Phase 6 gate asks whether the median tester triggers Confluence within
/// seven minutes **unprompted**, and that needs people. This is what a machine
/// can contribute to the same question: run the real game, with real generated
/// stages, driven by several plausible play styles, and measure how long each
/// takes to stumble into the mechanic.
///
/// **What this cannot tell you.** Whether Confluence *reads*. A bot has no
/// opinion about whether a white flash in a busy arena looks like skill or like
/// noise, and that is the actual question docs/01 §1.5 raises. This bounds the
/// reachability half and leaves the legibility half exactly where it was.
///
///   dart run tool/discovery_probe.dart
Future<void> main(List<String> args) async {
  final ContentLibrary content = _load();

  stdout.writeln('Confluence discovery probe');
  stdout.writeln('Seven minutes of play per style, real generated stages.\n');
  stdout.writeln(
    '${'play style'.padRight(22)}'
    '${'first'.padLeft(8)}'
    '${'per min'.padLeft(9)}'
    '${'thread'.padLeft(8)}'
    '${'draw I/II/III'.padLeft(16)}'
    '${'moving'.padLeft(8)}'
    '${'cross@'.padLeft(9)}',
  );
  stdout.writeln('-' * 80);

  final List<_Result> results = <_Result>[];
  for (final _Style style in _Style.values) {
    final _Result result = _run(style, content);
    results.add(result);
    stdout.writeln(result);
  }

  stdout.writeln('-' * 80);
  _verdict(results);
}

ContentLibrary _load() {
  final (ContentLibrary?, List<ContentError>) parsed = ContentLibrary.parse(
    enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
    arenasJson: File('assets/data/arenas.json').readAsStringSync(),
  );
  final ContentLibrary? content = parsed.$1;
  if (content == null) {
    stderr.writeln(parsed.$2.join('\n'));
    exit(2);
  }
  return content;
}

/// Plausible ways a person actually holds this game.
enum _Style {
  /// Never lets go of the stick. The commonest new-player habit in this genre,
  /// carried over from every twin-stick shooter — and the one that never
  /// reaches Tier II, let alone lays a lattice.
  neverStops('never stops'),

  /// Never moves unless forced. The opposite habit, from Archero players who
  /// have learned that standing still is simply correct.
  neverMoves('never moves'),

  /// Short panicked bursts with no rhythm. A nervous first-timer.
  panicky('panicky'),

  /// The rhythm the design intends: move to survive, root to escalate.
  oscillating('oscillating'),

  /// Walks the room between fights and roots to shoot. A competent player who
  /// has not been told about Windlines.
  roaming('roaming'),

  /// Circles tightly while shooting — the habit that fans trails the most, and
  /// the one most likely to find Confluence by accident.
  circling('circling');

  const _Style(this.label);

  final String label;
}

class _Result {
  _Result(this.style, this.telemetry);

  final _Style style;
  final FeelTelemetry telemetry;

  /// Where crossings happen, relative to the player.
  ///
  /// The distinction the design rests on: threading a trail *out in the field*
  /// is the skill, whereas crossing at your own feet is an artefact of firing
  /// every arrow from one point.
  double crossingDistanceSum = 0;
  int crossingSamples = 0;

  double get meanCrossingDistance =>
      crossingSamples == 0 ? 0 : crossingDistanceSum / crossingSamples;

  bool get found => telemetry.firstConfluenceAt != null;

  @override
  String toString() {
    final String first = telemetry.firstConfluenceAt == null
        ? 'never'
        : '${telemetry.firstConfluenceAt!.toStringAsFixed(0)}s';

    final String tiers = '${(telemetry.tierShare(DrawTier.one) * 100).round()}'
        '/${(telemetry.tierShare(DrawTier.two) * 100).round()}'
        '/${(telemetry.tierShare(DrawTier.three) * 100).round()}';

    return '${style.label.padRight(22)}'
        '${first.padLeft(8)}'
        '${telemetry.confluencePerMinute.toStringAsFixed(1).padLeft(9)}'
        '${'${(telemetry.threadRate * 100).toStringAsFixed(1)}%'.padLeft(8)}'
        '${tiers.padLeft(16)}'
        '${'${(telemetry.movingShare * 100).round()}%'.padLeft(8)}'
        '${'${meanCrossingDistance.toStringAsFixed(1)}u'.padLeft(9)}';
  }
}

/// Seven minutes of play, the window the gate asks about.
const double _sessionSeconds = 7 * 60;

_Result _run(_Style style, ContentLibrary content) {
  final FeelTelemetry telemetry = FeelTelemetry();
  final _Result result = _Result(style, telemetry);
  final LevelGenerator generator =
      LevelGenerator(content: content, arenas: content.arenas);

  int chapter = 1;
  int stage = 1;
  double elapsed = 0;

  // A session is several stages. A player who clears one starts the next, and
  // the seven-minute window in docs/03 §3.1 is about *play*, not about one room.
  while (elapsed < _sessionSeconds) {
    final StageBlueprint blueprint = StageBlueprint.forStage(
      chapter: chapter,
      stage: stage,
      seed: StageBlueprint.seedFor(
        playerId: style.name,
        chapter: chapter,
        stage: stage,
        attemptSalt: 0,
      ),
    );
    final StagePlan plan =
        generateStage(generator: generator, blueprint: blueprint);
    final SimWorld world = buildStageWorld(
      blueprint: blueprint,
      content: content,
      plan: plan,
    );
    final StageRunner runner =
        StageRunner(world: world, content: content, plan: plan)..start();

    elapsed += _playStage(
      style,
      world,
      runner,
      telemetry,
      result,
      _sessionSeconds - elapsed,
    );

    stage++;
    if (stage > 20) {
      stage = 1;
      chapter++;
    }
  }

  return result;
}

double _playStage(
  _Style style,
  SimWorld world,
  StageRunner runner,
  FeelTelemetry telemetry,
  _Result result,
  double budgetSeconds,
) {
  final InputSnapshot input = InputSnapshot();
  final int maxTicks = (budgetSeconds * 60).round();

  for (int tick = 0; tick < maxTicks; tick++) {
    // Kept alive on purpose. Dying is a different measurement, and a bot that
    // dies in room two tells you nothing about a seven-minute window.
    if (world.entities.isAlive(world.player)) {
      final int p = world.player.index;
      world.entities.health[p] = world.entities.maxHealth[p];
    }

    final double t = tick / 60.0;
    _drive(style, input, world, runner, t);

    world.tick(input);
    telemetry.recordTick(world);

    if (world.entities.isAlive(world.player)) {
      final int p = world.player.index;
      for (int e = 0; e < world.events.count; e++) {
        if (world.events.typeAt(e) != SimEventType.confluenceTriggered) {
          continue;
        }
        final double dx = world.events.xAt(e) - world.entities.posX[p];
        final double dy = world.events.yAt(e) - world.entities.posY[p];
        result.crossingDistanceSum += math.sqrt(dx * dx + dy * dy);
        result.crossingSamples++;
      }
    }

    world.events.clear();

    runner.update();
    if (runner.status != StageStatus.fighting) return t;
  }
  return budgetSeconds;
}

void _drive(
  _Style style,
  InputSnapshot input,
  SimWorld world,
  StageRunner runner,
  double t,
) {
  switch (style) {
    case _Style.neverStops:
      input.set(math.cos(t * 0.9), math.sin(t * 0.9));

    case _Style.neverMoves:
      input.set(0, 0);

    case _Style.panicky:
      // Bursts of 0.35 s with 0.5 s gaps — long enough to lose the Draw, too
      // short to reach Tier II.
      final double phase = t % 0.85;
      if (phase < 0.35) {
        final double angle = (t * 7.3) % (2 * math.pi);
        input.set(math.cos(angle), math.sin(angle));
      } else {
        input.set(0, 0);
      }

    case _Style.oscillating:
      final double phase = t % 2.0;
      if (phase < 0.6) {
        input.set(math.cos(t * 1.1), math.sin(t * 1.1));
      } else {
        input.set(0, 0);
      }

    case _Style.roaming:
      _roam(input, world, runner, t);

    case _Style.circling:
      final double phase = t % 1.6;
      if (phase < 1.1) {
        input.set(math.cos(t * 2.4), math.sin(t * 2.4));
      } else {
        input.set(0, 0);
      }
  }
}

/// Walks between the room's own spawn points, rooting to shoot.
void _roam(
  InputSnapshot input,
  SimWorld world,
  StageRunner runner,
  double t,
) {
  const double leg = 3.4;
  final List<SpawnPoint> points = runner.room.arena.spawnPoints;
  if (points.isEmpty || !world.entities.isAlive(world.player)) {
    input.set(0, 0);
    return;
  }

  if (t % leg > 2.0) {
    input.set(0, 0);
    return;
  }

  final SpawnPoint target = points[(t / leg).floor() % points.length];
  final int p = world.player.index;
  final double dx = target.x - world.entities.posX[p];
  final double dy = target.y - world.entities.posY[p];
  final double length = math.sqrt(dx * dx + dy * dy);

  if (length < 0.2) {
    input.set(0, 0);
  } else {
    input.set(dx / length, dy / length);
  }
}

void _verdict(List<_Result> results) {
  final List<_Result> found =
      results.where((_Result r) => r.found).toList(growable: false);

  stdout.writeln(
    '${found.length} of ${results.length} play styles found Confluence '
    'inside seven minutes.',
  );

  final Iterable<_Result> missed = results.where((_Result r) => !r.found);
  if (missed.isNotEmpty) {
    stdout.writeln(
      'never found it: ${missed.map((_Result r) => r.style.label).join(', ')}',
    );
  }

  stdout.writeln(
    '\nWhat this does NOT answer: whether Confluence *reads* as skill or as '
    'noise.\nThat needs eyes. See docs/runbooks/phase-6-playtest.md.',
  );
}
