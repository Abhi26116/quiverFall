import 'dart:io';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/research/research_catalogue.dart';

/// Loads the **shipping** Research Lab catalogue from disk. Same reasoning
/// as `loadSpire`/`loadHeroes`: the 12 items in `assets/data/research.json`
/// are as much the thing under test as the code that reads them.
ResearchCatalogue loadResearch() {
  final String json = File('assets/data/research.json').readAsStringSync();
  final (ResearchCatalogue?, List<ContentError>) result =
      ResearchCatalogue.parse(json);

  final ResearchCatalogue? catalogue = result.$1;
  if (catalogue == null) {
    throw StateError('research.json failed to load:\n${result.$2.join('\n')}');
  }
  return catalogue;
}
