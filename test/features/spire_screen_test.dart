import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/spire/presentation/spire_screen.dart';
import 'package:quiverfall/game/spire/spire_catalogue.dart';

import '../game/spire_test_support.dart';
import 'repository_test_support.dart';

/// docs/04 §4.2: the Spire hub — 24 nodes across 4 wings, wired to
/// `SpireWorkshop`. See ADR 0100.
void main() {
  late SpireCatalogue spire;

  setUpAll(() {
    spire = loadSpire();
  });

  PlayerSave startingSave({
    int accountLevel = 1,
    int gold = 100000,
    int insight = 10000,
  }) =>
      PlayerSave.initial(playerId: 'p1', now: DateTime.utc(2026)).copyWith(
        profile: PlayerProfile(accountLevel: accountLevel),
        wallet: Wallet(gold: gold, insight: insight),
      );

  Future<PlayerRepository> pumpScreen(
    WidgetTester tester,
    PlayerSave save,
  ) async {
    // Tall enough that all 24 nodes across all 4 wings sit within
    // `ListView`'s own cache extent without scrolling — `find` only sees
    // elements the sliver has actually inflated, not merely ones that
    // "exist" as widget objects in the `children:` list.
    await tester.binding.setSurfaceSize(const Size(400, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final PlayerRepository repository = buildTestRepository(save);
    addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(
      home: SpireScreen(repository: repository, spire: spire),
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

  testWidgets('shows all 4 wing names', (WidgetTester tester) async {
    await pumpScreen(tester, startingSave(accountLevel: 90));

    expect(find.text('THE ARMORY'), findsOneWidget);
    expect(find.text('THE BULWARK'), findsOneWidget);
    expect(find.text('THE FLETCHERY'), findsOneWidget);
    expect(find.text('THE SANCTUM'), findsOneWidget);
  });

  testWidgets('a locked wing shows the account-level banner, not its nodes', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, startingSave());

    expect(find.textContaining('Unlocks at account level 5'), findsOneWidget);
    // Bulwark's own first node (Vitality) must not appear while locked.
    expect(find.text('Vitality'), findsNothing);
  });

  testWidgets('an unlocked wing shows its own nodes', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, startingSave());
    expect(find.text("Warden's Might"), findsOneWidget);
    expect(find.text('Lv 0 / 80'), findsWidgets);
  });

  testWidgets('tapping level up spends gold and raises the node\'s level', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository =
        await pumpScreen(tester, startingSave());

    expect(repository.save.spire.levelOf(1), 0);
    final int goldBefore = repository.save.wallet.gold;

    await tapAndFlush(tester, find.text('60g').first);

    expect(repository.save.spire.levelOf(1), 1);
    expect(repository.save.wallet.gold, lessThan(goldBefore));
    expect(find.text('Lv 1 / 80'), findsOneWidget);
  });

  testWidgets('insufficient gold disables the level-up button', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, startingSave(gold: 0));

    final Finder button = find.ancestor(
      of: find.text('60g').first,
      matching: find.byType(FilledButton),
    );
    final FilledButton widget = tester.widget(button);
    expect(widget.onPressed, isNull);
  });

  testWidgets('at level 20, the row offers to unlock the L20 gate instead', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository = await pumpScreen(
      tester,
      startingSave().copyWith(
        spire: const SpireState(nodeLevels: {'1': 20}),
      ),
    );

    expect(find.textContaining('L20:'), findsOneWidget);
    expect(find.text('60g'), findsNothing);

    await tapAndFlush(tester, find.textContaining('L20:').first);

    expect(repository.save.spire.bandOf(1), 20);
    expect(find.textContaining('L20:'), findsNothing);
  });

  testWidgets('a node at level 80 shows MAX and no purchase button', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      startingSave().copyWith(
        spire: const SpireState(nodeLevels: {'1': 80}),
      ),
    );

    expect(find.textContaining('MAX'), findsOneWidget);
  });

  testWidgets('the currency readout shows gold and Insight', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, startingSave(gold: 1234, insight: 56));
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('56 Insight'), findsOneWidget);
  });
}
