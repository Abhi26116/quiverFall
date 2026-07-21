import 'dart:io';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';

/// Loads the **shipping** hero catalogue from disk.
///
/// Deliberately not a fixture, for the same reason `loadBoons` is not: the 20
/// heroes in `assets/data/heroes.json` are as much the thing under test as the
/// code that reads them.
HeroCatalogue loadHeroes() {
  final String json = File('assets/data/heroes.json').readAsStringSync();
  final (HeroCatalogue?, List<ContentError>) result = HeroCatalogue.parse(json);

  final HeroCatalogue? catalogue = result.$1;
  if (catalogue == null) {
    throw StateError('heroes.json failed to load:\n${result.$2.join('\n')}');
  }
  return catalogue;
}
