import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/features/gameplay/presentation/game_screen.dart';
import 'package:quiverfall/game/content/content_loader.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/view/quiverfall_game.dart';

import '../game/hero_test_support.dart';

/// ADR 0014's own gap, closed: `GameScreen` now actually reads the claimed
/// run's hero/arrow into the sim, via `HeroLoadoutResolver.apply`, rather
/// than always running the hero-blind `lawfulAttackFor` placeholder.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<QuiverfallGame> boot(
    WidgetTester tester, {
    String? heroId,
    HeroState? heroState,
    String? arrowId,
    ArrowInstance? arrowInstance,
  }) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(ContentLoader.load);

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        showTelemetry: false,
        heroId: heroId,
        heroState: heroState,
        arrowId: arrowId,
        arrowInstance: arrowInstance,
      ),
    ));

    final Finder finder = find.byType(GameWidget<QuiverfallGame>);
    for (int i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(finder, findsOneWidget,
        reason: 'the arena never got past its loading state');

    final GameWidget<QuiverfallGame> widget = tester.widget(finder);
    return widget.game!;
  }

  testWidgets('with no chosen build, the sim keeps the generic placeholder', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester);

    expect(
      game.sim.playerAttack,
      closeTo(lawfulAttackFor(game.sim.globalStage), 1e-6),
    );
  });

  testWidgets(
      'with a chosen hero and arrow, playerAttack is the composed value, '
      'not the placeholder', (WidgetTester tester) async {
    final HeroCatalogue heroes = loadHeroes();
    final HeroDefinition wren = heroes.byArchetype(HeroArchetype.wren)!;

    final QuiverfallGame game = await boot(
      tester,
      heroId: 'wren',
      heroState: const HeroState(heroId: 'wren'), // level 1, ★0
      arrowId: 'ash_shaft',
      arrowInstance: const ArrowInstance(arrowId: 'ash_shaft'), // refine I
    );

    // Level 1, ★0, unrefined Ash Shaft: heroAtk == the hero's own level-1
    // base stat exactly (both curve multipliers are 1.0 at these inputs),
    // and arrowBaseMult == 1.0, so playerAttack == wren.stats.atk exactly.
    expect(game.sim.playerAttack, closeTo(wren.stats.atk, 1e-6));
    expect(
      game.sim.playerAttack,
      isNot(closeTo(lawfulAttackFor(game.sim.globalStage), 1e-6)),
      reason: 'a chosen build must not fall back to the hero-blind placeholder',
    );
  });
}
