import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/heroes/presentation/hero_compare_screen.dart';
import 'package:quiverfall/features/heroes/presentation/hero_screen.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';

import '../game/hero_test_support.dart';
import 'repository_test_support.dart';

/// docs/10-ui-ux.md §10.12: "Compare overlays two heroes' stats side by
/// side."
void main() {
  late HeroCatalogue heroes;

  setUpAll(() {
    heroes = loadHeroes();
  });

  PlayerSave startingSave() =>
      PlayerSave.initial(playerId: 'p1', now: DateTime.utc(2026));

  testWidgets('opens with the given left hero and a default right hero, both compared',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HeroCompareScreen(
        heroes: heroes,
        save: startingSave(),
        initialLeftKey: 'wren',
      ),
    ));
    await tester.pump();

    expect(find.text('COMPARE'), findsOneWidget);
    // Wren (left, ★1 in the starting save) and Bram (right, the first other
    // hero in the roster, unowned so ★0) both show a stat table rather than
    // the "pick two heroes" empty state.
    expect(find.text('Pick two heroes to compare.'), findsNothing);
    expect(find.text('ATK'), findsOneWidget);
    expect(find.text('HP'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Rate'), findsOneWidget);
  });

  testWidgets('the Compare button on the Hero screen opens this screen', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository = buildTestRepository(startingSave());
    addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(
      home: HeroScreen(repository: repository, heroes: heroes),
    ));
    await tester.pump();

    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();

    expect(find.text('COMPARE'), findsOneWidget);
  });
}
