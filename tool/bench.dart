import 'dart:io';

/// Runs the performance gates in isolation.
///
/// Benchmarks live in `benchmark/`, not `test/`, so a bare `flutter test` never
/// runs them. That separation is structural rather than tag-based: tags compose
/// badly (an `exclude_tags` in dart_test.yaml silently cancels a `--tags` on the
/// command line, and the run reports "No tests ran").
///
/// They are excluded because they are wall-clock measurements and the default
/// runner executes files in parallel — the Confluence gate reads 0.59 ms alone
/// and 0.88 ms under contention, which turns a 0.8 ms budget into a coin flip.
/// `-j 1` forces a single concurrent job so the numbers mean something.
///
///   dart run tool/bench.dart
Future<void> main(List<String> args) async {
  stdout.writeln('Running performance gates (single-threaded)...\n');

  final Process process = await Process.start(
    'flutter',
    <String>['test', 'benchmark/', '-j', '1', '--reporter', 'expanded'],
    mode: ProcessStartMode.inheritStdio,
  );

  final int code = await process.exitCode;

  stdout.writeln(
    code == 0
        ? '\nAll performance gates passed.'
        : '\nPerformance gates FAILED (exit $code).',
  );
  exit(code);
}
