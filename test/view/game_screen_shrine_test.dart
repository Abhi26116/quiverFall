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

/// The Shrine's counterpart to `game_screen_boon_choice_test.dart`.
///
/// Chapter 2 is used deliberately: docs/14 §14.2 puts the Shrine at room
/// index 4 from chapter 2 onward, and the Elite not until chapter 3 — so a
/// chapter-2 stage reaches the Shrine after exactly four ordinary Boon
/// Choices, with nothing else in the way.
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
      const MaterialApp(
        home: GameScreen(chapter: 2, showTelemetry: false),
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

  Future<void> forceRoomClear(WidgetTester tester, QuiverfallGame game) async {
    final StageStatus before = game.runStatus.value;
    for (int i = 0; i < 1800; i++) {
      if (game.sim.entities.isAlive(game.sim.player)) {
        final int p = game.sim.player.index;
        game.sim.entities.health[p] = game.sim.entities.maxHealth[p];
      }
      killAllEnemies(game);
      await tester.pump(const Duration(milliseconds: 16));
      if (game.runStatus.value != before) return;
    }
    fail('the room never cleared');
  }

  /// Taps the first offered card, exactly as a player choosing without
  /// deliberation would.
  Future<void> tapFirstBoon(WidgetTester tester) async {
    final Finder card = find
        .descendant(of: find.byType(BoonChoice), matching: find.byType(InkWell))
        .first;
    await tester.tap(card);
    await tester.pump();
  }

  testWidgets('four ordinary clears reach the Shrine, not another Boon Choice', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester);

    for (int room = 0; room < 4; room++) {
      await forceRoomClear(tester, game);
      expect(game.runStatus.value, StageStatus.awaitingBoonChoice,
          reason: 'room $room should be an ordinary clear');
      await tapFirstBoon(tester);
      expect(game.runStatus.value, StageStatus.fighting);
    }

    await forceRoomClear(tester, game);

    expect(game.runStatus.value, StageStatus.awaitingShrine);
    expect(game.halted, isTrue);
    expect(find.byType(Shrine), findsOneWidget);
    expect(find.byType(BoonChoice), findsNothing);
  });

  testWidgets('leaving the Shrine resumes the fight', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester);
    for (int room = 0; room < 4; room++) {
      await forceRoomClear(tester, game);
      await tapFirstBoon(tester);
    }
    await forceRoomClear(tester, game);
    expect(game.runStatus.value, StageStatus.awaitingShrine);

    final int roomBefore = game.runner!.roomIndex;
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    expect(game.runStatus.value, StageStatus.fighting);
    expect(game.halted, isFalse);
    expect(find.byType(Shrine), findsNothing);
    expect(game.runner!.roomIndex, roomBefore + 1);
  });
}
