import 'dart:io';

import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';

/// Loads the **shipping** affix catalogue from disk. Same reasoning as
/// `loadArrows`/`loadHeroes`: the content is the thing under test.
AffixCatalogue loadAffixes() {
  final String json = File('assets/data/affixes.json').readAsStringSync();
  final (AffixCatalogue?, List<ContentError>) result =
      AffixCatalogue.parse(json);

  final AffixCatalogue? catalogue = result.$1;
  if (catalogue == null) {
    throw StateError('affixes.json failed to load:\n${result.$2.join('\n')}');
  }
  return catalogue;
}
