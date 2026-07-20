import 'dart:io';

import 'package:quiverfall/game/content/content_library.dart';

/// Build-time content validation.
///
/// Run in CI before anything else. A malformed enemy entry must fail the build,
/// never crash a player's phone in chapter 7 — docs/13-database.md §13.11.
///
///   dart run tool/validate_content.dart
///
/// Exits non-zero and prints every problem found, not just the first.
Future<void> main(List<String> args) async {
  const String dataDir = 'assets/data';

  final File enemiesFile = File('$dataDir/enemies.json');
  if (!enemiesFile.existsSync()) {
    stderr.writeln('missing $dataDir/enemies.json');
    exit(1);
  }

  final (ContentLibrary? library, List<ContentError> errors) =
      ContentLibrary.parse(enemiesJson: enemiesFile.readAsStringSync());

  if (errors.isNotEmpty) {
    stderr.writeln('Content validation FAILED (${errors.length} problems):');
    for (final ContentError e in errors) {
      stderr.writeln('  $e');
    }
    exit(1);
  }

  final ContentLibrary loaded = library!;

  final StringBuffer report = StringBuffer()
    ..writeln('Content OK')
    ..writeln('  enemies: ${loaded.enemies.length}');

  // Report roster growth per chapter. Useful as a design signal on its own:
  // docs/05 §5.8 front-loads all 26 base types by chapter 8 so the late game is
  // about combinations rather than memorising new sprites.
  for (int c = 1; c <= 12; c++) {
    final int n = loaded.enemiesUpToChapter(c).length;
    if (c == 1 || n != loaded.enemiesUpToChapter(c - 1).length) {
      report.writeln('  by chapter $c: $n types');
    }
  }

  // Written as one guarded call. A build tool that throws when its stdout is
  // closed — piped through `head`, or a CI log collector that hangs up — turns a
  // successful validation into a red build for no reason.
  try {
    stdout.write(report.toString());
  } on FileSystemException {
    // Consumer went away. The validation itself succeeded; that is what matters.
  }
}
