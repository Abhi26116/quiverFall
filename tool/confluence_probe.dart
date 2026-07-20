import 'dart:io';
import 'dart:math' as math;

import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spawn/room_composer.dart';

/// Measures how often Confluence actually fires in ordinary play.
///
/// This exists because of ADR 0002. Confluence is implemented and correct, and
/// its natural trigger rate was measured at **0 %**: every trail radiates from
/// the player toward whichever target auto-aim picked, and rays from a common
/// origin diverge rather than cross.
///
/// A probe rather than a test. Tests assert; this reports, so that the fix is
/// chosen against numbers instead of intuition.
/// `test/game/confluence_reachability_test.dart` locks in the floor afterwards.
///
///   dart run tool/confluence_probe.dart
Future<void> main(List<String> args) async {
  final ContentLibrary content = _loadContent();

  stdout.writeln('Confluence reachability probe — ADR 0002');
  stdout.writeln('Windline: ${SimConfig.windlineDuration}s life, '
      '${SimConfig.windlineSegmentLength}u segments, '
      '${SimConfig.windlineHitWidth}u hit width\n');

  stdout.writeln(
    '${'scenario'.padRight(24)}'
    '${'shots'.padLeft(7)}'
    '${'hits'.padLeft(7)}'
    '${'rate'.padLeft(8)}'
    '${'first'.padLeft(9)}'
    '   stacks',
  );
  stdout.writeln('-' * 74);

  final List<_Probe> rooms = <_Probe>[];
  for (final _Scenario scenario in _scenarios) {
    final _Probe probe = _run(scenario, content);
    stdout.writeln(probe);
    if (!scenario.isControl) rooms.add(probe);
  }

  stdout.writeln('-' * 74);

  // Controls are excluded from the verdict. They exist to explain a number, not
  // to be one: immortal dummies keep auto-aim locked on a single target, so
  // every arrow retraces one line and the angle rule correctly rejects it.
  final int shots = rooms.fold(0, (int a, _Probe p) => a + p.shots);
  final int hits = rooms.fold(0, (int a, _Probe p) => a + p.arrowsWithStack);
  final double rate = shots == 0 ? 0 : hits / shots;

  stdout.writeln(
    'real rooms: $hits of $shots shots threaded '
    '(${(rate * 100).toStringAsFixed(1)} %)',
  );

  final double? slowest = rooms
      .map((_Probe p) => p.firstAt)
      .whereType<double>()
      .fold<double?>(null, (double? a, double b) => a == null || b > a ? b : a);
  // A rooted player threading nothing is the design working, not a failure:
  // standing still buys Tier III damage, and retracing one line is not
  // threading it. Naming the rooms is more honest than a pass/fail word.
  final List<String> never = rooms
      .where((_Probe p) => p.firstAt == null)
      .map((_Probe p) => p.name)
      .toList();

  stdout.writeln(
    'time to first: slowest ${slowest?.toStringAsFixed(1) ?? '-'}s'
    '${never.isEmpty ? '' : '; never fired: ${never.join(', ')}'}',
  );

  // The two failure modes ADR 0002 names, as a verdict rather than a number the
  // reader has to interpret.
  if (rate < 0.02) {
    stdout.writeln(
      '\nVERDICT: unreachable. The USP cannot fire from the base kit.',
    );
  } else if (rate > 0.60) {
    stdout.writeln(
      '\nVERDICT: degenerate. A mechanic that fires by default is a flat '
      'damage buff with extra steps.',
    );
  } else {
    stdout.writeln(
      '\nVERDICT: reachable. Confluence fires from the base kit at a rate '
      'that is neither constant nor impossible.',
    );
  }
}

ContentLibrary _loadContent() {
  final File file = File('assets/data/enemies.json');
  if (!file.existsSync()) {
    stderr.writeln('run this from the project root');
    exit(2);
  }
  final (ContentLibrary?, List<ContentError>) parsed =
      ContentLibrary.parse(enemiesJson: file.readAsStringSync());
  final ContentLibrary? content = parsed.$1;
  if (content == null) {
    stderr.writeln(parsed.$2.join('\n'));
    exit(2);
  }
  return content;
}

/// How the player behaves for the duration of a probe.
enum _PlayerBehaviour {
  /// Rooted. The Draw ramps to Tier III and every arrow leaves from one point.
  still,

  /// Lateral strafe, reversing on a fixed cadence.
  strafe,

  /// Circling — the movement an experienced player defaults to, and the one
  /// most likely to fan trails apart.
  circle,
}

class _Scenario {
  const _Scenario(
    this.name,
    this.behaviour, {
    this.enemies = const <(EnemyArchetype, double, double)>[],
    this.room,
    this.seconds = 20.0,
  });

  /// A fixed arrangement of immortal dummies.
  ///
  /// A *control*: it isolates the geometry of the player's fire, at the cost of
  /// being nothing like a real fight.
  const _Scenario.control(
    String name,
    _PlayerBehaviour behaviour, {
    required List<(EnemyArchetype, double, double)> enemies,
  }) : this(name, behaviour, enemies: enemies);

  /// A real composed room at a real stage, with real HP and a player whose
  /// attack lands TTK inside the 0.8–1.6 s band of Design Law 1.
  ///
  /// **This is the measurement that decides ADR 0002.**
  const _Scenario.room(
    String name,
    _PlayerBehaviour behaviour, {
    required int chapter,
    required int stage,
  }) : this(name, behaviour, room: (chapter, stage), seconds: 60.0);

  final String name;
  final _PlayerBehaviour behaviour;

  /// Enemy placements, as (archetype, x, y).
  final List<(EnemyArchetype, double, double)> enemies;

  /// (chapter, globalStage) for a composed room, or null for a control.
  final (int, int)? room;

  final double seconds;

  bool get isControl => room == null;
}

final List<_Scenario> _scenarios = <_Scenario>[
  // ── Controls ──────────────────────────────────────────────────────────────
  const _Scenario.control(
    'ctl rooted, 1 target',
    _PlayerBehaviour.still,
    enemies: <(EnemyArchetype, double, double)>[
      (EnemyArchetype.mote, 12.0, 4.5),
    ],
  ),
  // Not const: _ring is computed.
  _Scenario.control(
    'ctl rooted, ring of 8',
    _PlayerBehaviour.still,
    enemies: _ring(8, 4.0),
  ),
  _Scenario.control(
    'ctl circling, ring of 8',
    _PlayerBehaviour.circle,
    enemies: _ring(8, 4.0),
  ),

  // ── Real rooms ────────────────────────────────────────────────────────────
  const _Scenario.room('ch1 rooted', _PlayerBehaviour.still,
      chapter: 1, stage: 1),
  const _Scenario.room('ch1 strafing', _PlayerBehaviour.strafe,
      chapter: 1, stage: 1),
  const _Scenario.room('ch1 circling', _PlayerBehaviour.circle,
      chapter: 1, stage: 1),
  const _Scenario.room('ch4 circling', _PlayerBehaviour.circle,
      chapter: 4, stage: 70),
  const _Scenario.room(
    'ch8 circling',
    _PlayerBehaviour.circle,
    chapter: 8,
    stage: 160,
  ),
];

List<(EnemyArchetype, double, double)> _ring(int count, double radius) {
  return <(EnemyArchetype, double, double)>[
    for (int i = 0; i < count; i++)
      (
        EnemyArchetype.mote,
        SimConfig.arenaWidth / 2 + math.cos(2 * math.pi * i / count) * radius,
        SimConfig.arenaHeight / 2 + math.sin(2 * math.pi * i / count) * radius,
      ),
  ];
}

class _Probe {
  _Probe(this.name);

  final String name;

  int shots = 0;
  int arrowsWithStack = 0;
  final Map<int, int> stackHistogram = <int, int>{};

  /// Seconds until the first Confluence, or null if it never happened. This is
  /// the number docs/03 §3.1 beat 6:00 depends on: the tutorial expects a first
  /// Confluence to fire accidentally by ~7 minutes.
  double? firstAt;

  double get rate => shots == 0 ? 0 : arrowsWithStack / shots;

  @override
  String toString() {
    final String first =
        firstAt == null ? 'never' : '${firstAt!.toStringAsFixed(1)}s';
    final String stacks = stackHistogram.isEmpty
        ? '-'
        : (stackHistogram.keys.toList()..sort())
            .map((int k) => 'x$k:${stackHistogram[k]}')
            .join(' ');

    return '${name.padRight(24)}'
        '${shots.toString().padLeft(7)}'
        '${arrowsWithStack.toString().padLeft(7)}'
        '${'${(rate * 100).toStringAsFixed(1)}%'.padLeft(8)}'
        '${first.padLeft(9)}'
        '   $stacks';
  }
}

_Probe _run(_Scenario scenario, ContentLibrary content) {
  final _Probe probe = _Probe(scenario.name);
  final SimWorld world = SimWorld(seed: 90210, content: content);
  final int player = world.spawnPlayer(4.0, 4.5).index;

  if (scenario.isControl) {
    // Immortal dummies. Note what this costs: auto-aim keeps picking the same
    // nearest target forever, so consecutive arrows retrace one line and the
    // angle rule correctly rejects every pair.
    world
      ..enemyHpBase = 1e9
      ..playerAttack = 1;
    for (final (EnemyArchetype archetype, double x, double y)
        in scenario.enemies) {
      world.spawnEnemy(archetype, x, y);
    }
  } else {
    _arm(world, content, scenario, 90210);
  }

  final InputSnapshot input = InputSnapshot();
  final int ticks = (scenario.seconds * 60).round();

  for (int tick = 0; tick < ticks; tick++) {
    // Health is topped up every tick rather than set enormous. Contact damage
    // is a *fraction of max HP* (docs/05 §5.0), so a player with 1e12 health
    // dies exactly as fast as one with 100 — which is the whole reason that
    // scaling rule exists.
    world.entities.health[player] = world.entities.maxHealth[player];

    _drive(input, scenario.behaviour, tick);
    world.tick(input);

    final double now = tick * SimConfig.fixedStep;
    for (int i = 0; i < world.events.count; i++) {
      switch (world.events.typeAt(i)) {
        case SimEventType.arrowFired:
          probe.shots++;
        case SimEventType.confluenceTriggered:
          final int stacks = world.events.valueAAt(i).round();
          // The event fires on every stack gained, so counting the ones that
          // took an arrow from zero to one counts *arrows*, not stacks.
          if (stacks == 1) {
            probe.arrowsWithStack++;
            probe.firstAt ??= now;
          }
          probe.stackHistogram[stacks] =
              (probe.stackHistogram[stacks] ?? 0) + 1;
        default:
          break;
      }
    }
    world.events.clear();

    // Keep the fight going for the whole window. A cleared room measures
    // nothing, and a player who clears one room goes straight into another.
    if (!scenario.isControl && world.spawnState.roomClearedEmitted) {
      _arm(world, content, scenario, 90210 + tick);
    }
  }

  return probe;
}

void _arm(
  SimWorld world,
  ContentLibrary content,
  _Scenario scenario,
  int seed,
) {
  final (int chapter, int stage) = scenario.room!;
  // Design Law 1: a common enemy dies in 0.8–1.6 s for a correctly-progressed
  // player. Attack is solved from the HP curve so the probe measures a fight at
  // the intended pace rather than a sandbag or a one-shot.
  world
    ..enemyHpBase = Curves.enemyHp(stage)
    ..playerAttack = _attackForLawfulTtk(Curves.enemyHp(stage));

  world.beginRoom(
    RoomComposer.compose(
      content: content,
      rng: Rng(seed),
      chapter: chapter,
      globalStage: stage,
    ),
  );
}

/// Attack that kills a x1.0 common enemy inside the TTK band.
///
/// Two Tier-III arrows in ~1.2 s is the shape docs/02 §2.6 derives every HP
/// curve from, so this is the attack a correctly-progressed player has.
double _attackForLawfulTtk(double baseHp) => baseHp / (2.10 * 2);

void _drive(InputSnapshot input, _PlayerBehaviour behaviour, int tick) {
  final double t = tick * SimConfig.fixedStep;
  switch (behaviour) {
    case _PlayerBehaviour.still:
      input.set(0, 0);
    case _PlayerBehaviour.strafe:
      input.set(0, math.sin(t * 1.4) > 0 ? 1 : -1);
    case _PlayerBehaviour.circle:
      input.set(math.cos(t * 1.1), math.sin(t * 1.1));
  }
}
