import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/gear/presentation/gear_screen.dart';
import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/affix_reroll.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_refinement.dart';

import '../game/affix_test_support.dart';
import '../game/arrow_test_support.dart';
import 'repository_test_support.dart';

/// docs/10-ui-ux.md §10.11: the equipped arrow's detail, the roster grid, and
/// materials — wired to `ArrowWorkshop`.
void main() {
  late ArrowCatalogue arrows;
  late AffixCatalogue affixes;

  setUpAll(() {
    arrows = loadArrows();
    affixes = loadAffixes();
  });

  final Finder detail = find.byKey(const ValueKey<String>('gear-detail'));
  Finder inDetail(Finder matching) =>
      find.descendant(of: detail, matching: matching);
  Finder gridTile(String arrowKey) =>
      find.byKey(ValueKey<String>('arrow-tile-$arrowKey'));

  PlayerSave startingSave() => PlayerSave.initial(
        playerId: 'p1',
        now: DateTime.utc(2026),
      ).copyWith(
        wallet: const Wallet(
          gold: 100000,
          materials: <String, int>{
            'ashwood': 999,
            'ironhead': 999,
            'skyfeather': 999,
            'prismcore': 999,
          },
        ),
      );

  Future<PlayerRepository> pumpScreen(
    WidgetTester tester,
    PlayerSave save,
  ) async {
    final PlayerRepository repository = buildTestRepository(save);
    addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(
      home: GearScreen(repository: repository, arrows: arrows, affixes: affixes),
    ));
    await tester.pump();
    return repository;
  }

  Future<void> tapAndFlush(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('opens on the equipped arrow (Ash Shaft), owned and shown', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, startingSave());

    expect(inDetail(find.textContaining('Ash Shaft')), findsOneWidget);
    expect(inDetail(find.text('EQUIPPED')), findsOneWidget);
  });

  testWidgets('selecting an unowned arrow shows its craft panel', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, startingSave());

    await tapAndFlush(tester, gridTile('broadhead'));

    expect(inDetail(find.text('CRAFT')), findsOneWidget);
  });

  testWidgets('CRAFT spends gold and adds the instance', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository = await pumpScreen(tester, startingSave());
    await tapAndFlush(tester, gridTile('broadhead'));
    final int goldBefore = repository.save.wallet.gold;

    await tapAndFlush(tester, inDetail(find.text('CRAFT')));

    expect(repository.save.inventory.arrows.containsKey('broadhead'), isTrue);
    expect(repository.save.wallet.gold, lessThan(goldBefore));
  });

  testWidgets(
      'REFINE spends gold + materials, advances refineLevel, and rolls one affix',
      (WidgetTester tester) async {
    final PlayerRepository repository = await pumpScreen(tester, startingSave());
    final int goldBefore = repository.save.wallet.gold;

    await tapAndFlush(tester, inDetail(find.textContaining('REFINE')));

    final ArrowInstance updated = repository.save.inventory.arrows['ash_shaft']!;
    expect(updated.refineLevel, 1);
    expect(updated.affixes, hasLength(1));
    expect(repository.save.wallet.gold, lessThan(goldBefore));
  });

  testWidgets('the materials row shows each material\'s wallet count', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, startingSave());

    expect(find.textContaining('Ashwood 999'), findsOneWidget);
    expect(find.textContaining('Ironhead 999'), findsOneWidget);
    expect(find.textContaining('Skyfeather 999'), findsOneWidget);
    expect(find.textContaining('Prismcore 999'), findsOneWidget);
  });

  group('with a refined, one-affix Ash Shaft', () {
    PlayerSave savedWithAffix() => startingSave().copyWith(
          inventory: const InventoryState(
            arrows: <String, ArrowInstance>{
              'ash_shaft': ArrowInstance(
                arrowId: 'ash_shaft',
                crafted: true,
                refineLevel: 1,
                affixes: <Affix>[Affix(affixId: 'sharpened', value: 0.06)],
              ),
            },
          ),
        );

    testWidgets('reroll spends the escalating cost and replaces the affix', (
      WidgetTester tester,
    ) async {
      final PlayerRepository repository =
          await pumpScreen(tester, savedWithAffix());
      final int goldBefore = repository.save.wallet.gold;

      await tapAndFlush(tester, inDetail(find.textContaining('↻')));

      expect(
        goldBefore - repository.save.wallet.gold,
        AffixReroll.goldCost(0),
      );
      expect(repository.save.inventory.rerollCountThisSession, 1);
    });

    testWidgets('locking the one affix hides its reroll button', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, savedWithAffix());

      expect(inDetail(find.textContaining('↻')), findsOneWidget);
      await tapAndFlush(tester, inDetail(find.byTooltip('Lock')));

      expect(inDetail(find.textContaining('↻')), findsNothing);
    });
  });

  testWidgets('REFINE is disabled once an arrow is at max refinement', (
    WidgetTester tester,
  ) async {
    final PlayerSave save = startingSave().copyWith(
      inventory: const InventoryState(
        arrows: <String, ArrowInstance>{
          'ash_shaft': ArrowInstance(
            arrowId: 'ash_shaft',
            crafted: true,
            refineLevel: ArrowRefinement.maxLevel,
          ),
        },
      ),
    );
    await pumpScreen(tester, save);

    final Finder refineButton = inDetail(find.text('MAX REFINE'));
    await tester.ensureVisible(refineButton);
    final OutlinedButton button = tester.widget(find.ancestor(
      of: refineButton,
      matching: find.byType(OutlinedButton),
    ));
    expect(button.onPressed, isNull);
  });
}
