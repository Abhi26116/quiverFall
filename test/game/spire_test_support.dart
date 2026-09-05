import 'dart:io';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/spire/spire_catalogue.dart';

/// Loads the **shipping** Spire catalogue from disk. Same reasoning as
/// `loadHeroes`/`loadArrows`/`loadBoons`: the 24 nodes in
/// `assets/data/spire.json` are as much the thing under test as the code
/// that reads them.
SpireCatalogue loadSpire() {
  final String json = File('assets/data/spire.json').readAsStringSync();
  final (SpireCatalogue?, List<ContentError>) result = SpireCatalogue.parse(json);

  final SpireCatalogue? catalogue = result.$1;
  if (catalogue == null) {
    throw StateError('spire.json failed to load:\n${result.$2.join('\n')}');
  }
  return catalogue;
}
