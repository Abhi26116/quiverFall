import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:quiverfall/features/loadout/presentation/loadout_screen.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';

import '../game/arrow_test_support.dart';
import '../game/hero_test_support.dart';
import 'repository_test_support.dart';

/// docs/11-screen-flow.md §11.1: `LevelSel --> Loadout --> Game`. See
/// ADR 0014 for exactly what DESCEND does and does not wire up yet.
void main() {
  late HeroCatalogue heroes;
  late ArrowCatalogue arrows;

  setUpAll(() {
    heroes = loadHeroes();
    arrows = loadArrows();
  });

  PlayerSave startingSave() => PlayerSave.initial(
        playerId: 'p1',
        now: DateTime.utc(2026),
      );

  /// Pumps a two-route router (`/loadout` -> [LoadoutScreen], `/game` -> a
  /// stand-in) so `context.push(Routes.game)` inside the screen has
  /// somewhere real to land.
  Future<({PlayerRepository repository, RunCoordinator runs})> pumpScreen(
    WidgetTester tester, {
    PlayerSave? save,
    StageRef? stageRef,
  }) async {
    final PlayerRepository repository = buildTestRepository(save ?? startingSave());
    final RunCoordinator runs = RunCoordinator();
    addTearDown(repository.dispose);
    addTearDown(runs.dispose);

    final GoRouter router = GoRouter(
      initialLocation: '/loadout',
      routes: <RouteBase>[
        GoRoute(
          path: '/loadout',
          builder: (_, __) => LoadoutScreen(
            repository: repository,
            runs: runs,
            heroes: heroes,
            arrows: arrows,
            stageRef: stageRef,
          ),
        ),
        GoRoute(
          path: '/game',
          builder: (_, __) => const Scaffold(body: Text('IN A RUN')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    return (repository: repository, runs: runs);
  }

  testWidgets('opens with the equipped hero/arrow and a ready preview', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Wren'), findsOneWidget);
    expect(find.text('Ash Shaft'), findsOneWidget);
    expect(find.textContaining('Wren · Ash Shaft'), findsOneWidget);

    final FilledButton button =
        tester.widget(find.widgetWithText(FilledButton, 'DESCEND'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('DESCEND claims the run, persists the loadout, and navigates', (
    WidgetTester tester,
  ) async {
    final (:repository, :runs) = await pumpScreen(tester);

    await tester.tap(find.text('DESCEND'));
    await tester.pumpAndSettle();

    expect(find.text('IN A RUN'), findsOneWidget);
    expect(runs.activeRun.value, isNotNull);
    expect(runs.activeRun.value!.heroId, 'wren');
    expect(runs.activeRun.value!.arrowId, 'ash_shaft');
    expect(repository.save.profile.equippedHeroId, 'wren');
    expect(repository.save.profile.equippedArrowId, 'ash_shaft');
  });

  testWidgets('a chapter-locked stage refuses to claim the run', (
    WidgetTester tester,
  ) async {
    final (:repository, :runs) = await pumpScreen(
      tester,
      // The starting save is on chapter 1 — chapter 5 is not yet open.
      stageRef: const StageRef(chapter: 5, stage: 1),
    );

    await tester.tap(find.text('DESCEND'));
    await tester.pump();

    expect(find.text('IN A RUN'), findsNothing);
    expect(runs.activeRun.value, isNull);
    expect(find.textContaining('sealed'), findsOneWidget);
  });

  testWidgets('choosing a different owned arrow updates the preview', (
    WidgetTester tester,
  ) async {
    final PlayerSave save = startingSave().copyWith(
      inventory: const InventoryState(
        arrows: <String, ArrowInstance>{
          'ash_shaft': ArrowInstance(arrowId: 'ash_shaft', crafted: true),
          'broadhead': ArrowInstance(arrowId: 'broadhead', crafted: true),
        },
      ),
    );
    await pumpScreen(tester, save: save);

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Ash Shaft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Broadhead').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Wren · Broadhead'), findsOneWidget);
  });
}
