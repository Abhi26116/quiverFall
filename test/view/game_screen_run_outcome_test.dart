import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/features/gameplay/presentation/boon_choice.dart';
import 'package:quiverfall/features/gameplay/presentation/game_screen.dart';
import 'package:quiverfall/features/gameplay/presentation/run_outcome.dart';
import 'package:quiverfall/game/content/content_loader.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/view/quiverfall_game.dart';

import '../features/repository_test_support.dart';

/// The visible half of ADR 0096 — a cleared or failed stage now shows
/// something and, given a real repository, actually persists.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<QuiverfallGame> boot(
    WidgetTester tester, {
    required PlayerRepository repository,
    required RunCoordinator runs,
  }) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      await ContentLoader.load();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          showTelemetry: false,
          repository: repository,
          runs: runs,
        ),
      ),
    );

    final Finder finder = find.byType(GameWidget<QuiverfallGame>);
    for (int i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(finder, findsOneWidget);

    final GameWidget<QuiverfallGame> widget = tester.widget(finder);
    return widget.game!;
  }

  void killAllEnemies(QuiverfallGame game) {
    for (int i = 0; i < game.sim.entities.highWater; i++) {
      if (game.sim.entities.alive[i] == 0) continue;
      if (game.sim.entities.kind[i] != EntityKind.enemy.index) continue;
      game.sim.entities.health[i] = 0;
    }
  }

  /// Kills every room in the stage in turn — the `game_screen_shrine_test
  /// .dart` rhythm, run to the stage's own end rather than stopping at the
  /// first pause.
  Future<void> clearWholeStage(WidgetTester tester, QuiverfallGame game) async {
    for (int guard = 0; guard < 20000; guard++) {
      if (game.runStatus.value == StageStatus.complete) return;
      if (game.sim.entities.isAlive(game.sim.player)) {
        final int p = game.sim.player.index;
        game.sim.entities.health[p] = game.sim.entities.maxHealth[p];
      }
      killAllEnemies(game);
      await tester.pump(const Duration(milliseconds: 16));
      if (game.runStatus.value == StageStatus.awaitingBoonChoice) {
        final Finder card = find.descendant(
          of: find.byType(BoonChoice),
          matching: find.byType(InkWell),
        );
        if (card.evaluate().isNotEmpty) {
          await tester.tap(card.first);
          await tester.pump();
        }
      } else if (game.runStatus.value == StageStatus.awaitingShrine) {
        final Finder leave = find.text('CONTINUE');
        if (leave.evaluate().isNotEmpty) {
          await tester.tap(leave);
          await tester.pump();
        }
      }
    }
    fail('the stage never completed');
  }

  PlayerSave freshSave() =>
      PlayerSave.initial(playerId: 'p1', now: DateTime.utc(2026, 3));

  testWidgets('a full clear shows RunOutcome and persists gold + advance', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository = buildTestRepository(freshSave());
    final RunCoordinator runs = RunCoordinator();
    addTearDown(repository.dispose);
    addTearDown(runs.dispose);

    final QuiverfallGame game =
        await boot(tester, repository: repository, runs: runs);

    await clearWholeStage(tester, game);
    await tester.pump();

    expect(game.runStatus.value, StageStatus.complete);
    expect(game.halted, isTrue);
    expect(find.byType(RunOutcome), findsOneWidget);
    expect(find.text('STAGE COMPLETE'), findsOneWidget);

    // Persisted for real, not just displayed — the exact gap ADR 0096
    // closes: gold banked and the campaign frontier advanced.
    expect(repository.save.wallet.gold, greaterThan(0));
    expect(repository.save.campaign.currentChapter, 1);
    expect(repository.save.campaign.currentStage, 2);
  });

  testWidgets('tapping RETURN TO MENU clears the run slot', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository = buildTestRepository(freshSave());
    final RunCoordinator runs = RunCoordinator()
      ..tryBeginStart()
      ..completeStart(RunSnapshot(
        runId: 'test-run',
        seed: 1,
        stage: const StageRef(chapter: 1, stage: 1),
        heroId: 'wren',
        arrowId: 'ash_shaft',
        roomIndex: 0,
        currentHp: 100,
        startedAt: DateTime.utc(2026, 3),
      ));
    addTearDown(repository.dispose);
    addTearDown(runs.dispose);

    final QuiverfallGame game =
        await boot(tester, repository: repository, runs: runs);
    await clearWholeStage(tester, game);
    await tester.pump();

    expect(runs.activeRun.value, isNotNull);
    await tester.tap(find.text('RETURN TO MENU'));
    await tester.pump();

    expect(runs.activeRun.value, isNull);
  });

  testWidgets('with no repository, RunOutcome still shows (never a crash)', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await ContentLoader.load();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(showTelemetry: false),
      ),
    );
    final Finder finder = find.byType(GameWidget<QuiverfallGame>);
    for (int i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final GameWidget<QuiverfallGame> widget = tester.widget(finder);
    final QuiverfallGame game = widget.game!;

    await clearWholeStage(tester, game);
    await tester.pump();

    expect(find.byType(RunOutcome), findsOneWidget);
  });
}
