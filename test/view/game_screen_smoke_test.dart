import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiverfall/features/gameplay/presentation/game_screen.dart';
import 'package:quiverfall/game/content/content_loader.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/view/quiverfall_game.dart';

/// Proof that the arena actually runs.
///
/// Every other test in this project asserts a rule. This one asserts something
/// duller and, for Phase 6, more important: the whole stack — content load,
/// world construction, room composition, the Flame loop, the renderer, the HUD
/// and the joystick — comes up, paints frames, and advances the simulation
/// without throwing.
///
/// A phase whose deliverable is "a thing eight strangers can hold" needs a test
/// that says the thing starts.
///
/// Note the absence of `pumpAndSettle`: a running game never settles. Frames
/// are pumped explicitly, which is also the only honest way to test something
/// driven by a ticker.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Boots the screen and waits for the content load to resolve.
  Future<QuiverfallGame> boot(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Reading an asset is real I/O and cannot complete inside the fake-async
    // zone that `pump` runs in. Warming the cache here means the screen's own
    // `await` resolves on a microtask, which `pump` *can* flush.
    await tester.runAsync(ContentLoader.load);

    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(showTelemetry: false)),
    );

    final Finder finder = find.byType(GameWidget<QuiverfallGame>);
    for (int i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      finder,
      findsOneWidget,
      reason: 'the arena never got past its loading state',
    );

    final GameWidget<QuiverfallGame> widget = tester.widget(finder);
    return widget.game!;
  }

  Future<void> advance(WidgetTester tester, int frames) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  int aliveEnemies(QuiverfallGame game) {
    int n = 0;
    for (int i = 0; i < game.sim.entities.highWater; i++) {
      if (game.sim.entities.alive[i] == 1 &&
          game.sim.entities.kind[i] == EntityKind.enemy.index) {
        n++;
      }
    }
    return n;
  }

  testWidgets('the arena boots, paints, and simulates', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester);

    expect(game.sim.content.enemies, hasLength(26));
    expect(game.sim.entities.isAlive(game.sim.player), isTrue);
    expect(game.sim.spawnState.plan, isNotNull);

    // The first wave is telegraphed for 0.4 s before anything exists, so a
    // second and a half covers spawn, AI, hazards and rendering.
    await advance(tester, 90);

    expect(
      game.sim.tickCount,
      greaterThan(30),
      reason: 'the simulation never advanced',
    );
    expect(
      aliveEnemies(game),
      greaterThan(0),
      reason: 'the room never populated',
    );
    expect(
      game.telemetry.sessionSeconds,
      greaterThan(0),
      reason: 'the gate telemetry was never fed',
    );
  });

  testWidgets('a thumb in the stick zone moves the player', (
    WidgetTester tester,
  ) async {
    final QuiverfallGame game = await boot(tester);
    await advance(tester, 5);

    final double before = game.sim.entities.posX[game.sim.player.index];

    // Land in the bottom-left thumb zone and drag right, past full deflection.
    final TestGesture gesture =
        await tester.startGesture(const Offset(80, 330));
    await tester.pump();
    await gesture.moveTo(const Offset(240, 330));
    await advance(tester, 60);

    expect(
      game.sim.entities.posX[game.sim.player.index],
      greaterThan(before + 0.5),
      reason: 'the joystick never reached the simulation',
    );

    await gesture.up();
    await tester.pump();

    expect(game.joystick.isActive, isFalse);
    expect(game.joystick.magnitude, 0);
  });

  testWidgets('a tap outside the thumb zone does not steal movement', (
    WidgetTester tester,
  ) async {
    // The exit button lives top-right for exactly this reason: a stick that
    // claimed the whole screen would make every UI tap a lurch.
    final QuiverfallGame game = await boot(tester);

    final TestGesture gesture =
        await tester.startGesture(const Offset(700, 60));
    await tester.pump();

    expect(game.joystick.isActive, isFalse);

    await gesture.up();
    await tester.pump();
  });
}
