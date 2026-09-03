import 'dart:io';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:test/test.dart';

/// [ContentLibrary]'s hero/arrow/affix aggregation — the plumbing that lets
/// the running app (not just tests) load the catalogues `ContentLoader`
/// hands to the Hero/Gear/Loadout screens.
void main() {
  final String enemies = File('assets/data/enemies.json').readAsStringSync();
  final String heroes = File('assets/data/heroes.json').readAsStringSync();
  final String arrows = File('assets/data/arrows.json').readAsStringSync();
  final String affixes = File('assets/data/affixes.json').readAsStringSync();

  test('parses and aggregates all three when their JSON is supplied', () {
    final (ContentLibrary?, List<ContentError>) result = ContentLibrary.parse(
      enemiesJson: enemies,
      heroesJson: heroes,
      arrowsJson: arrows,
      affixesJson: affixes,
    );

    expect(result.$2, isEmpty);
    final ContentLibrary library = result.$1!;
    expect(library.heroes.length, 20);
    expect(library.arrows.all, hasLength(12));
    expect(library.affixes.length, 17);
  });

  test('defaults every one of the three to empty when omitted', () {
    final (ContentLibrary?, List<ContentError>) result =
        ContentLibrary.parse(enemiesJson: enemies);

    expect(result.$2, isEmpty);
    final ContentLibrary library = result.$1!;
    expect(library.heroes.isEmpty, isTrue);
    expect(library.arrows.all, isEmpty);
    expect(library.affixes.isEmpty, isTrue);
  });

  test('ContentLibrary.empty() carries empty hero/arrow/affix catalogues too',
      () {
    final ContentLibrary library = ContentLibrary.empty();
    expect(library.heroes.isEmpty, isTrue);
    expect(library.arrows.all, isEmpty);
    expect(library.affixes.isEmpty, isTrue);
  });

  test('a malformed heroesJson surfaces its own errors and fails the whole parse',
      () {
    final (ContentLibrary?, List<ContentError>) result = ContentLibrary.parse(
      enemiesJson: enemies,
      heroesJson: '{"heroes": "not a list"}',
    );

    expect(result.$1, isNull);
    expect(result.$2, isNotEmpty);
  });
}
