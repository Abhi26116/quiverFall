import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:quiverfall/core/di/service_locator.dart';
import 'package:quiverfall/core/routing/routes.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/features/gameplay/application/feel_telemetry.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/features/gameplay/presentation/boon_choice.dart';
import 'package:quiverfall/features/gameplay/presentation/shrine.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_content_loader.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/content_loader.dart';
import 'package:quiverfall/game/feel/cues.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/services/audio/audio_port.dart';
import 'package:quiverfall/services/device/quality_controller.dart';
import 'package:quiverfall/services/haptics/haptic_service.dart';
import 'package:quiverfall/view/hud/combat_hud.dart';
import 'package:quiverfall/view/input/joystick_layer.dart';
import 'package:quiverfall/view/quiverfall_game.dart';

/// The arena.
///
/// Phase 6's deliverable was a thing eight people who have never seen the game
/// can be handed, and Phase 9 is the first phase to build on top of it rather
/// than replace it: the Boon Choice and the Shrine are now real, everything
/// else Phase 6 deferred — a pause sheet, an ultimate button, a victory flow —
/// still is not here.
///
/// Phase 8 replaces the hard-coded room with the real level generator and the
/// `RunCoordinator` handshake; Phase 15 replaces the HUD with the production
/// one.
class GameScreen extends StatefulWidget {
  const GameScreen({
    this.chapter = 1,
    this.stage = 1,
    this.playerId = 'local',
    this.showTelemetry = true,
    super.key,
  });

  final int chapter;
  final int stage;

  /// Part of the stage seed, so two players on the same stage get different
  /// rooms (docs/14 §14.2).
  final String playerId;

  /// The playtest overlay. On by default in Phase 6 precisely because the
  /// numbers behind the gate have to be readable off the device by whoever is
  /// running the session.
  final bool showTelemetry;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  QuiverfallGame? _game;
  StageRunner? _runner;
  Object? _loadError;

  late final HapticService _haptics = HapticService();
  late final SilentAudioSink _audio = SilentAudioSink();

  /// Drives the HUD's repaint without rebuilding the widget tree.
  late final Ticker _ticker;
  final ValueNotifier<int> _hudFrame = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
    _start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hudFrame.dispose();
    super.dispose();
  }

  void _onFrame(Duration _) {
    // The HUD repaints at frame rate but never *rebuilds*: docs/19 §19.1 gives
    // the whole Flutter layer 1.0 ms, and a layout pass would spend it before
    // anything was drawn.
    _hudFrame.value++;
  }

  /// Runs a [StageRunner] mutation from the Boon Choice or the Shrine, then
  /// re-syncs the game with whatever it left behind.
  ///
  /// Needed because [QuiverfallGame.halted] stops [QuiverfallGame._afterTick]
  /// from running at all while an interstitial is up — there will be no
  /// further tick to notice the runner's status changed on its own, so the
  /// widget that caused the change has to push it through itself.
  void _resolve(void Function() action) {
    final QuiverfallGame? game = _game;
    final StageRunner? runner = _runner;
    if (game == null || runner == null) return;

    action();

    game.runStatus.value = runner.status;
    game.halted = runner.status == StageStatus.awaitingBoonChoice ||
        runner.status == StageStatus.awaitingShrine;
  }

  Future<void> _start() async {
    try {
      // Loaded together: neither is needed before the other, and a run that
      // fails to load its Boon table should fail the same way a run that
      // fails to load its enemy table does, rather than reaching the first
      // room clear and discovering it there.
      final (ContentLibrary content, (BoonCatalogue, SynergyCatalogue) boons) =
          await (ContentLoader.load(), BoonContentLoader.load()).wait;
      if (!mounted) return;

      // The whole stage is generated up front. That is what makes it
      // reproducible from its seed, and what lets the room *after* this one be
      // validated before the player ever reaches it (docs/14 §14.2).
      final StageBlueprint blueprint = StageBlueprint.forStage(
        chapter: widget.chapter,
        stage: widget.stage,
        seed: StageBlueprint.seedFor(
          playerId: widget.playerId,
          chapter: widget.chapter,
          stage: widget.stage,
          // Phase 14 persists the attempt count. A wall-clock salt still gives
          // the property that matters now: a retry is a different stage.
          attemptSalt: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
        ),
      );

      final StagePlan plan = generateStage(
        generator: LevelGenerator(content: content, arenas: content.arenas),
        blueprint: blueprint,
      );

      final SimWorld sim = buildStageWorld(
        blueprint: blueprint,
        content: content,
        plan: plan,
      );

      final StageRunner runner = StageRunner(
        world: sim,
        content: content,
        plan: plan,
        boonCatalogue: boons.$1,
        synergies: boons.$2,
      )..start();

      setState(() {
        _runner = runner;
        _game = QuiverfallGame(
          sim: sim,
          runner: runner,
          sinks: <CueSink>[_haptics, _audio],
          // Decided by the boot benchmark. Absent in tests and tools, where the
          // default tier is the right answer anyway.
          quality: locator.isRegistered<QualityController>()
              ? locator<QualityController>()
              : null,
        );
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final QuiverfallGame? game = _game;

    if (_loadError != null) {
      return _ErrorState(error: _loadError!);
    }
    if (game == null) {
      return const ColoredBox(
        color: Tokens.bgDeep,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Tokens.bgDeep,
      body: JoystickLayer(
        model: game.joystick,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GameWidget<QuiverfallGame>(game: game),
            CombatHud(
              world: game.sim,
              repaint: _hudFrame,
              telemetry: game.telemetry,
              runner: _runner,
              showTelemetry: widget.showTelemetry,
            ),
            _ExitButton(telemetry: game.telemetry),
            ValueListenableBuilder<StageStatus>(
              valueListenable: game.runStatus,
              builder: (BuildContext context, StageStatus status, _) {
                final StageRunner? runner = _runner;
                if (runner == null) return const SizedBox.shrink();

                return switch (status) {
                  StageStatus.awaitingBoonChoice => BoonChoice(
                      runner: runner,
                      onPick: (BoonDefinition def) =>
                          _resolve(() => runner.pickBoon(def)),
                      onReroll: runner.rerollsRemaining > 0
                          ? () => _resolve(runner.rerollBoonOffers)
                          : null,
                    ),
                  StageStatus.awaitingShrine => Shrine(
                      runner: runner,
                      onBuyHeal: () => _resolve(runner.buyShrineHeal),
                      onBuyReroll: () => _resolve(runner.buyShrineReroll),
                      onBuyBoon: () => _resolve(runner.buyShrineBoon),
                      onLeave: () => _resolve(runner.leaveShrine),
                    ),
                  StageStatus.fighting ||
                  StageStatus.complete ||
                  StageStatus.failed =>
                    const SizedBox.shrink(),
                };
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Leaves the arena, printing the session's numbers on the way out.
///
/// Top-*right*, deliberately: docs/10 §10.0 reserves the bottom 96 dp for the
/// left thumb, and a quit button anywhere near the stick during a playtest is a
/// run ended by accident.
class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.telemetry});

  final FeelTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space2),
          child: SizedBox(
            width: Tokens.minTouchTarget,
            height: Tokens.minTouchTarget,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Tokens.inkDim),
              onPressed: () {
                // The session's numbers are the deliverable, so they are
                // printed on the way out rather than lost with the screen.
                debugPrint('── Phase 6 session ──\n${telemetry.summary()}');
                final NavigatorState navigator = Navigator.of(context);
                if (navigator.canPop()) navigator.pop();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.bgDeep,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: Tokens.warn,
                size: 40,
              ),
              const SizedBox(height: Tokens.space4),
              const Text(
                'The arena could not load',
                style: TextStyle(color: Tokens.ink, fontSize: 18),
              ),
              const SizedBox(height: Tokens.space2),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Tokens.inkDim, fontSize: 12),
              ),
              const SizedBox(height: Tokens.space6),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('BACK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Route helper, so the router does not need to know the screen's parameters.
Widget buildGameScreen() => const GameScreen();

/// Deep link used by the dev menu to jump straight into an arena.
const String kGameRoute = Routes.game;
