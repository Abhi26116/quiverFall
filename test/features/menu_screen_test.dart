import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:quiverfall/features/menu/presentation/menu_screen.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';

import '../game/hero_test_support.dart';
import 'repository_test_support.dart';

/// docs/11-screen-flow.md §11.1: `Menu -->|DESCEND| Game` — resumes straight
/// into a run with the account's currently equipped build.
void main() {
  late HeroCatalogue heroes;

  setUpAll(() {
    heroes = loadHeroes();
  });

  PlayerSave startingSave() =>
      PlayerSave.initial(playerId: 'p1', now: DateTime.utc(2026));

  Future<({PlayerRepository repository, RunCoordinator runs})> pumpScreen(
    WidgetTester tester, {
    PlayerSave? save,
  }) async {
    final PlayerRepository repository = buildTestRepository(save ?? startingSave());
    final RunCoordinator runs = RunCoordinator();
    addTearDown(repository.dispose);
    addTearDown(runs.dispose);

    final GoRouter router = GoRouter(
      initialLocation: '/menu',
      routes: <RouteBase>[
        GoRoute(
          path: '/menu',
          builder: (_, __) => MenuScreen(
            repository: repository,
            runs: runs,
            heroes: heroes,
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

  testWidgets('DESCEND claims a run with the equipped build and navigates', (
    WidgetTester tester,
  ) async {
    final (:repository, :runs) = await pumpScreen(tester);

    await tester.tap(find.text('DESCEND'));
    await tester.pumpAndSettle();

    expect(find.text('IN A RUN'), findsOneWidget);
    expect(runs.activeRun.value, isNotNull);
    expect(runs.activeRun.value!.heroId, 'wren');
    expect(runs.activeRun.value!.arrowId, 'ash_shaft');
    expect(runs.activeRun.value!.stage.chapter, 1);
    expect(repository.save.profile.equippedHeroId, 'wren');
  });

  testWidgets('DESCEND launches whichever hero/arrow the account has equipped', (
    WidgetTester tester,
  ) async {
    final PlayerSave base = startingSave();
    final PlayerSave save = base.copyWith(
      profile: base.profile.copyWith(equippedArrowId: 'broadhead'),
      inventory: const InventoryState(
        arrows: <String, ArrowInstance>{
          'ash_shaft': ArrowInstance(arrowId: 'ash_shaft', crafted: true),
          'broadhead': ArrowInstance(arrowId: 'broadhead', crafted: true),
        },
      ),
    );
    final (:repository, :runs) = await pumpScreen(tester, save: save);

    await tester.tap(find.text('DESCEND'));
    await tester.pumpAndSettle();

    expect(runs.activeRun.value!.arrowId, 'broadhead');
  });
}
