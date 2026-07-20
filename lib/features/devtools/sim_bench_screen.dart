import 'package:flutter/material.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/systems/confluence_system.dart';
import 'package:quiverfall/game/sim/windline_store.dart';
import 'package:quiverfall/game/sim/world.dart';

/// On-device simulation benchmark.
///
/// The budgets in docs/19-performance.md are for a phone, but every number
/// measured so far comes from a developer machine — which is both a different
/// architecture and roughly an order of magnitude faster. This runs the same
/// gates on real hardware so the two can be compared.
///
/// A permanent dev tool rather than throwaway code: Phase 6 needs it to tune
/// game feel against a real frame budget, Phase 7 needs it for the render layer,
/// and Phase 19's low-end verification is exactly this screen on a weaker
/// device.
class SimBenchScreen extends StatefulWidget {
  const SimBenchScreen({super.key});

  @override
  State<SimBenchScreen> createState() => _SimBenchScreenState();
}

class _SimBenchScreenState extends State<SimBenchScreen> {
  final List<_BenchResult> _results = <_BenchResult>[];
  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    // Yield so the spinner paints before the main thread is monopolised.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    _results
      ..add(_benchMovementOnly())
      ..add(_benchCombat())
      ..add(_benchConfluenceWorstCase());

    setState(() => _running = false);
  }

  _BenchResult _benchMovementOnly() {
    final SimWorld world = SimWorld(seed: 4242)..autoFire = false;
    world.spawnPlayer(2.0, 4.5);
    for (int i = 0; i < 89; i++) {
      world.spawnAt(
        EntityKind.enemy,
        1.0 + (i % 14) * 1.05,
        0.6 + (i ~/ 14) * 1.3,
        radius: 0.3,
        health: 100,
      );
      final int idx = world.entities.highWater - 1;
      world.entities.velX[idx] = (i.isEven ? 1.0 : -1.0) * 1.4;
      world.entities.velY[idx] = (i % 3 == 0 ? 1.0 : -1.0) * 0.9;
    }

    final InputSnapshot input = InputSnapshot()..set(0.8, 0.6);
    return _time(
      label: 'Movement + spatial, 90 entities',
      budgetMs: 4.0,
      warmup: 600,
      samples: 4000,
      body: () => world.tick(input),
    );
  }

  _BenchResult _benchCombat() {
    final SimWorld world = SimWorld(seed: 9)
      ..playerAttack = 1
      ..basePierce = 4;
    world.spawnPlayer(8.0, 4.5);
    for (int i = 0; i < 60; i++) {
      world.spawnAt(
        EntityKind.enemy,
        1.0 + (i % 14) * 1.05,
        0.8 + (i ~/ 14) * 1.5,
        radius: 0.3,
        health: 1e9,
      );
    }

    final InputSnapshot input = InputSnapshot();
    return _time(
      label: 'Full combat tick + Windlines',
      budgetMs: 4.0,
      warmup: 900,
      samples: 3000,
      body: () => world.tick(input),
    );
  }

  _BenchResult _benchConfluenceWorstCase() {
    final WindlineStore lines = WindlineStore();
    for (int i = 0; i < SimConfig.maxWindlineSegments; i++) {
      final double x = (i % 40) * 0.4;
      final double y = ((i ~/ 40) % 22) * 0.4;
      lines.add(
        fromX: x,
        fromY: y,
        toX: x + 0.6,
        toY: y + 0.5,
        expiresAt: 1e9,
        ownerIndex: 0,
        trailId: i,
      );
    }
    final int serial = lines.nextSerial + 1;
    final List<int> none = <int>[];

    return _time(
      label: 'Confluence ceiling (synthetic, ADR 0002)',
      budgetMs: 0.8,
      isWatchItem: true,
      warmup: 40,
      samples: 300,
      body: () {
        for (int a = 0; a < 60; a++) {
          ConfluenceSystem.sweep(
            lines: lines,
            fromX: (a % 16).toDouble(),
            fromY: 0.5,
            toX: (a % 16).toDouble() + 0.25,
            toY: 0.75,
            arrowSerial: serial,
            ownerIndex: 0,
            hitWidth: SimConfig.windlineHitWidth,
            maxStacks: 3,
            alreadyCrossed: none,
            crossedBase: 0,
            crossedCount: 0,
          );
        }
      },
    );
  }

  _BenchResult _time({
    required String label,
    required double budgetMs,
    required int warmup,
    required int samples,
    required void Function() body,
    bool isWatchItem = false,
  }) {
    for (int i = 0; i < warmup; i++) {
      body();
    }
    final Stopwatch sw = Stopwatch()..start();
    for (int i = 0; i < samples; i++) {
      body();
    }
    sw.stop();
    return _BenchResult(
      label: label,
      perIterationMs: sw.elapsedMicroseconds / samples / 1000.0,
      budgetMs: budgetMs,
      isWatchItem: isWatchItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sim Benchmark')),
      body: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Runs the docs/19 performance gates on this device. '
              'Numbers from a developer machine are not a substitute.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: Tokens.space4),
            FilledButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'RUNNING…' : 'RUN BENCHMARK'),
            ),
            const SizedBox(height: Tokens.space6),
            if (_running)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Tokens.space3),
                  itemBuilder: (_, int i) => _ResultTile(result: _results[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BenchResult {
  const _BenchResult({
    required this.label,
    required this.perIterationMs,
    required this.budgetMs,
    this.isWatchItem = false,
  });

  final String label;
  final double perIterationMs;
  final double budgetMs;

  /// A known, tracked over-budget case rather than a regression. Shown in amber
  /// (threat) rather than crimson (lethal), per the semantic palette — a
  /// developer glancing at this screen should not read a documented limitation
  /// as a fresh failure.
  final bool isWatchItem;

  bool get passed => perIterationMs < budgetMs;

  double get headroom => budgetMs / perIterationMs;
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final _BenchResult result;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color tone = result.passed
        ? Tokens.accent
        : (result.isWatchItem ? Tokens.warn : Tokens.danger);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        border: Border.all(color: tone.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(result.label, style: text.titleMedium),
            const SizedBox(height: Tokens.space2),
            Row(
              children: <Widget>[
                Text(
                  '${result.perIterationMs.toStringAsFixed(4)} ms',
                  style: text.titleLarge?.copyWith(color: tone),
                ),
                const SizedBox(width: Tokens.space2),
                Text(
                  'budget ${result.budgetMs} ms',
                  style: text.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: Tokens.space1),
            Text(
              result.passed
                  ? '${result.headroom.toStringAsFixed(1)}x headroom'
                  : (result.isWatchItem
                      ? 'KNOWN — synthetic ceiling, not reached in play'
                      : 'OVER BUDGET'),
              style: text.labelSmall?.copyWith(color: tone),
            ),
          ],
        ),
      ),
    );
  }
}
