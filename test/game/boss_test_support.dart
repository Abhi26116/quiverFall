import 'dart:io';

import 'package:quiverfall/game/content/boss_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';

/// Loads the **shipping** boss catalogue from disk.
///
/// Deliberately not a fixture, for the same reason `loadHeroes` is not: the
/// 20 bosses in `assets/data/bosses.json` are as much the thing under test as
/// the code that reads them.
BossCatalogue loadBosses() {
  final String json = File('assets/data/bosses.json').readAsStringSync();
  final (BossCatalogue?, List<ContentError>) result = BossCatalogue.parse(json);

  final BossCatalogue? catalogue = result.$1;
  if (catalogue == null) {
    throw StateError('bosses.json failed to load:\n${result.$2.join('\n')}');
  }
  return catalogue;
}

/// A [ContentLibrary] carrying both the shipping enemy table and the shipping
/// boss table — what `SimWorld.spawnBoss` needs `content.bosses` populated
/// for. `enemy_test_support.dart`'s own `loadEnemies` only parses
/// `enemies.json`, which is enough for ordinary enemy tests but leaves
/// `content.bosses` empty.
ContentLibrary loadContentWithBosses() {
  final String enemies = File('assets/data/enemies.json').readAsStringSync();
  final String bosses = File('assets/data/bosses.json').readAsStringSync();
  final (ContentLibrary?, List<ContentError>) result = ContentLibrary.parse(
    enemiesJson: enemies,
    bossesJson: bosses,
  );

  final ContentLibrary? library = result.$1;
  if (library == null) {
    throw StateError(
        'content failed to load:\n${result.$2.join('\n')}');
  }
  return library;
}
