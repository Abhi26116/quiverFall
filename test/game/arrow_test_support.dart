import 'dart:io';

import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';

/// Loads the **shipping** arrow catalogue from disk. Same reasoning as
/// `loadHeroes`/`loadBoons`: the content is the thing under test.
ArrowCatalogue loadArrows() {
  final String json = File('assets/data/arrows.json').readAsStringSync();
  final (ArrowCatalogue?, List<ContentError>) result =
      ArrowCatalogue.parse(json);

  final ArrowCatalogue? catalogue = result.$1;
  if (catalogue == null) {
    throw StateError('arrows.json failed to load:\n${result.$2.join('\n')}');
  }
  return catalogue;
}
