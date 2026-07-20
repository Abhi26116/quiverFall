import 'dart:io';

import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';

/// Loads the **shipping** Boon catalogue from disk.
///
/// Deliberately not a fixture, for the same reason `loadEnemies` is not: the
/// 112 cards in `assets/data/boons.json` are as much the thing under test as
/// the code that reads them. A Legendary authored at ×3, a Cursed card with no
/// downside line, or an elemental rider with no `requires` tag is a shipping
/// bug, and a hand-written fixture would hide exactly that class of problem.
BoonCatalogue loadBoons() {
  final String json = File('assets/data/boons.json').readAsStringSync();
  final (BoonCatalogue?, List<ContentError>) result = BoonCatalogue.parse(json);

  final BoonCatalogue? catalogue = result.$1;
  if (catalogue == null) {
    throw StateError('boons.json failed to load:\n${result.$2.join('\n')}');
  }
  return catalogue;
}

/// Loads the **shipping** synergy sets and evolution paths.
SynergyCatalogue loadSynergies(BoonCatalogue boons) {
  final String json = File('assets/data/synergies.json').readAsStringSync();
  final (SynergyCatalogue?, List<ContentError>) result =
      SynergyCatalogue.parse(json, boons: boons);

  final SynergyCatalogue? catalogue = result.$1;
  if (catalogue == null) {
    throw StateError('synergies.json failed to load:\n${result.$2.join('\n')}');
  }
  return catalogue;
}
