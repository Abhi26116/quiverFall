import 'dart:io';

import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/harness/expected_power.dart';
import 'package:quiverfall/game/harness/ttk_distribution.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';

/// Phase 12's balance report — currently the TTK half only.
///
/// Runs `TtkHarness.measureChapter` for every campaign chapter at the
/// expected-power loadout ADR 0089 defines, and prints the same p10/p50/p90
/// distribution and pass/fail the roadmap's own exit criterion for this
/// file asks for. This is a report, not a test: `test/harness/ttk_probe_test.dart`
/// is where the actual assertions live (with the whole-campaign gate
/// currently `skip`-marked — see that file and ADR 0089 for why).
///
/// Exit code is non-zero iff any chapter is outside the hard TTK band,
/// matching "CI fails on any out-of-band ... TTK" from docs/20-roadmap.md's
/// Phase 12 exit criterion. `.github/workflows/ci.yaml` runs this step
/// non-blocking for now — see ADR 0089's Consequences for why blocking on it
/// today would fail CI for a gap this phase alone cannot close (no Spire
/// implementation exists until Phase 13).
///
///   dart run tool/balance_report.dart [--runs=N]
Future<void> main(List<String> args) async {
  int runs = 10000;
  for (final String arg in args) {
    if (arg.startsWith('--runs=')) {
      runs = int.parse(arg.substring('--runs='.length));
    }
  }

  final HeroCatalogue heroes = HeroCatalogue.parse(
    File('assets/data/heroes.json').readAsStringSync(),
  ).$1!;
  final ArrowCatalogue arrows = ArrowCatalogue.parse(
    File('assets/data/arrows.json').readAsStringSync(),
  ).$1!;
  final ContentLibrary content = ContentLibrary.parse(
    enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
  ).$1!;

  stdout.writeln('Balance report — TTK Law (docs/02 §2.6), $runs seeded '
      'runs per chapter');
  stdout.writeln('Hard band: [${Curves.ttkHardMin}, ${Curves.ttkHardMax}]s '
      '· target band: [${Curves.ttkTargetMin}, ${Curves.ttkTargetMax}]s\n');

  stdout.writeln(
    '${'chapter'.padRight(9)}'
    '${'stage'.padLeft(7)}'
    '${'arrow'.padLeft(12)}'
    '${'lvl'.padLeft(6)}'
    '${'p10'.padLeft(8)}'
    '${'p50'.padLeft(8)}'
    '${'p90'.padLeft(8)}'
    '${'timeouts'.padLeft(10)}   verdict',
  );
  stdout.writeln('-' * 92);

  bool anyOutOfBand = false;
  for (int chapter = 1; chapter <= 12; chapter++) {
    final ExpectedPower power = ExpectedPower.forChapter(chapter);
    final TtkDistribution d = TtkHarness.measureChapter(
      chapter: chapter,
      content: content,
      heroes: heroes,
      arrows: arrows,
      runs: runs,
    );
    final bool ok = d.withinHardBounds;
    if (!ok) anyOutOfBand = true;

    stdout.writeln(
      '${chapter.toString().padRight(9)}'
      '${d.globalStage.toString().padLeft(7)}'
      '${power.arrow.name.padLeft(12)}'
      '${power.heroLevel.toString().padLeft(6)}'
      '${_fmt(d.samples.isEmpty ? null : d.p10).padLeft(8)}'
      '${_fmt(d.samples.isEmpty ? null : d.p50).padLeft(8)}'
      '${_fmt(d.samples.isEmpty ? null : d.p90).padLeft(8)}'
      '${d.timeouts.toString().padLeft(10)}   '
      '${ok ? 'PASS' : 'FAIL'}',
    );
  }

  stdout.writeln('-' * 92);
  if (anyOutOfBand) {
    stdout.writeln('\nOne or more chapters are outside the hard TTK band. '
        'Expected until Phase 13 ships the Spire — see ADR 0089.');
  } else {
    stdout.writeln('\nAll chapters within the hard TTK band.');
  }

  exit(anyOutOfBand ? 1 : 0);
}

String _fmt(double? seconds) =>
    seconds == null ? '>timeout' : '${seconds.toStringAsFixed(3)}s';
