import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/features/gameplay/presentation/game_screen.dart';
import 'package:quiverfall/game/content/content_loader.dart';
import 'package:quiverfall/view/quiverfall_game.dart';

import '../features/repository_test_support.dart';

/// A real account's Spire investment, equipped Marks, and completed
/// Research items now actually reach a real run — the gap
/// `HeroLoadoutResolver.apply`/`ResearchLoadoutResolver.apply` supported
/// since ADR 0092/0095/0093 but nothing in `GameScreen` ever passed
/// through until ADR 0099.
///
/// Each case boots exactly one `GameScreen` — `pumpWidget` a second time in
/// the same test to compare against a live "before" reading does not
/// re-run `initState`/`_start()` reliably against a `FlameGame`'s own
/// lifecycle, so the "before" side of each comparison is Wren + Ash
/// Shaft's own independently-known baseline (docs/07: `atk: 100`; a
/// level-1, ★1 hero reads `100 * (1 + 0.12) = 112.0` via `Curves
/// .heroStat`) rather than a second boot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Wren + Ash Shaft, level 1, ★1, with no Spire investment and no
  /// equipped Marks unless a test's own `save` adds them.
  const double baseAttack = 112.0;

  Future<QuiverfallGame> boot(WidgetTester tester, PlayerSave save) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      await ContentLoader.load();
    });

    final repository = buildTestRepository(save);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          showTelemetry: false,
          heroId: 'wren',
          heroState: save.heroes['wren'],
          arrowId: 'ash_shaft',
          arrowInstance: save.inventory.arrows['ash_shaft'],
          repository: repository,
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

  PlayerSave baseSave() => PlayerSave.initial(playerId: 'p1', now: DateTime.utc(2026, 3))
      .copyWith(
        heroes: const {'wren': HeroState(heroId: 'wren', unlocked: true, stars: 1)},
        inventory: const InventoryState(
          arrows: {'ash_shaft': ArrowInstance(arrowId: 'ash_shaft', crafted: true)},
        ),
      );

  testWidgets('with no Spire investment, playerAttack is the plain hero+arrow value', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester, baseSave());
    expect(game.sim.playerAttack, closeTo(baseAttack, 1e-6));
  });

  testWidgets('Warden\'s Might at L80 raises the real run\'s own playerAttack', (
    WidgetTester tester,
  ) async {
    final PlayerSave withSpire = baseSave().copyWith(
      spire: const SpireState(nodeLevels: {'1': 80}), // Warden's Might
    );
    final QuiverfallGame game = await boot(tester, withSpire);

    expect(game.sim.playerAttack, closeTo(baseAttack * 2.60, 1e-6));
  });

  testWidgets('with no equipped Marks, flatDamage is untouched', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester, baseSave());
    expect(game.sim.combat.flatDamage, 0);
  });

  testWidgets('an equipped Mark of Ruin raises the real run\'s own flatDamage', (
    WidgetTester tester,
  ) async {
    final PlayerSave withMark = baseSave().copyWith(
      marks: const MarkState(unlockedIds: {'mark_of_ruin'}),
      profile: const PlayerProfile(equippedMarkIds: ['mark_of_ruin']),
    );
    final QuiverfallGame game = await boot(tester, withMark);

    expect(game.sim.combat.flatDamage, closeTo(0.10, 1e-9));
  });

  testWidgets('with no Windline Memory researched, the flag is off', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester, baseSave());
    expect(game.sim.windlinesSurviveRoomTransition, isFalse);
  });

  testWidgets('Windline Memory researched turns the flag on in a real run', (
    WidgetTester tester,
  ) async {
    final PlayerSave withResearch = baseSave().copyWith(
      research: const ResearchState(completedIds: {'windline_memory'}),
    );
    final QuiverfallGame game = await boot(tester, withResearch);

    expect(game.sim.windlinesSurviveRoomTransition, isTrue);
  });

  testWidgets('with no repository, the run still starts (nothing to fold in)', (
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
    expect(finder, findsOneWidget);
  });
}
