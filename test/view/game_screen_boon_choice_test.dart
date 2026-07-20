import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/features/gameplay/presentation/boon_choice.dart';
import 'package:quiverfall/features/gameplay/presentation/game_screen.dart';
import 'package:quiverfall/features/gameplay/presentation/shrine.dart';
import 'package:quiverfall/game/boons/boon_content_loader.dart';
import 'package:quiverfall/game/content/content_loader.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/view/quiverfall_game.dart';

/// Proof that the Boon Choice actually reaches the screen, not just
/// [StageRunner] in isolation.
///
/// `stage_runner_boons_test.dart` proves the mechanics headlessly; this proves
/// the wiring through the real widget tree — [QuiverfallGame.halted],
/// [QuiverfallGame.runStatus], and the overlay `GameScreen` builds from it —
/// the exact seam a headless test cannot see.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<QuiverfallGame> boot(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      await ContentLoader.load();
      await BoonContentLoader.load();
    });

    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(showTelemetry: false)),
    );

    final Finder finder = find.byType(GameWidget<QuiverfallGame>);
    for (int i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(finder, findsOneWidget,
        reason: 'the arena never got past its loading state');

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

  /// Forces a room clear as fast as the simulation will allow: top up the
  /// player, delete every enemy each frame, and keep pumping until the runner
  /// pauses on an interstitial. Chapter 1 has neither an Elite nor a Shrine
  /// (docs/14 §14.2 — both start from chapter 2+), so the only interstitial a
  /// chapter-1 clear can produce is the Boon Choice.
  Future<void> forceRoomClear(WidgetTester tester, QuiverfallGame game) async {
    for (int i = 0; i < 1800; i++) {
      if (game.sim.entities.isAlive(game.sim.player)) {
        final int p = game.sim.player.index;
        game.sim.entities.health[p] = game.sim.entities.maxHealth[p];
      }
      killAllEnemies(game);
      await tester.pump(const Duration(milliseconds: 16));
      if (game.runStatus.value != StageStatus.fighting) return;
    }
    fail('the room never cleared');
  }

  testWidgets('a room clear halts the sim and shows the Boon Choice', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester);
    expect(game.halted, isFalse);

    await forceRoomClear(tester, game);

    expect(game.runStatus.value, StageStatus.awaitingBoonChoice);
    expect(game.halted, isTrue,
        reason: 'the sim must stop ticking while the choice is up');
    expect(find.byType(BoonChoice), findsOneWidget);
    expect(find.byType(Shrine), findsNothing);
  });

  testWidgets('picking a card resumes the fight', (WidgetTester tester) async {
    final QuiverfallGame game = await boot(tester);
    await forceRoomClear(tester, game);
    expect(find.byType(BoonChoice), findsOneWidget);

    final int roomBefore = game.runner!.roomIndex;

    // The first card's InkWell — BoonChoice renders one tappable card per
    // offer, and the first is always present (a draw is never empty).
    final Finder card = find
        .descendant(of: find.byType(BoonChoice), matching: find.byType(InkWell))
        .first;
    await tester.tap(card);
    await tester.pump();

    expect(game.runStatus.value, StageStatus.fighting);
    expect(game.halted, isFalse,
        reason: 'resolving the choice must resume the sim');
    expect(find.byType(BoonChoice), findsNothing);
    expect(game.runner!.roomIndex, roomBefore + 1);
  });

  testWidgets('the sim does not advance while the choice is up', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester);
    await forceRoomClear(tester, game);

    final int ticksBefore = game.sim.tickCount;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(game.sim.tickCount, ticksBefore,
        reason: 'halted must mean halted — no ticks while a card is showing');
  });
}
