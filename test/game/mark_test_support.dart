import 'dart:io';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/marks/mark_catalogue.dart';

/// Loads the **shipping** Mark catalogue from disk. Same reasoning as
/// `loadSpire`/`loadResearch`: the 9 named Marks in `assets/data/marks.json`
/// are as much the thing under test as the code that reads them.
MarkCatalogue loadMarks() {
  final String json = File('assets/data/marks.json').readAsStringSync();
  final (MarkCatalogue?, List<ContentError>) result = MarkCatalogue.parse(json);

  final MarkCatalogue? catalogue = result.$1;
  if (catalogue == null) {
    throw StateError('marks.json failed to load:\n${result.$2.join('\n')}');
  }
  return catalogue;
}
