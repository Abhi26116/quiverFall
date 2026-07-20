import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:quiverfall/core/routing/routes.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/features/gameplay/application/feel_telemetry.dart';
import 'package:quiverfall/game/balance/curves.dart' as balance;
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/content_loader.dart';
import 'package:quiverfall/game/feel/cues.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spawn/room_composer.dart';
import 'package:quiverfall/services/audio/audio_port.dart';
import 'package:quiverfall/services/haptics/haptic_service.dart';
import 'package:quiverfall/view/hud/combat_hud.dart';
import 'package:quiverfall/view/input/joystick_layer.dart';
import 'package:quiverfall/view/quiverfall_game.dart';

/// The arena.
///
/// Phase 6's deliverable is a thing eight people who have never seen the game
/// can be handed, and this is that thing. It is deliberately not the final
/// gameplay screen — no pause sheet, no ultimate button, no Boon choice, no
/// victory flow — because none of those are what the gate measures. The gate
/// measures whether the Draw/Confluence loop is fun, and everything here exists
/// to put that in front of a thumb.
///
/// Phase 8 replaces the hard-coded room with the real level generator and the
/// `RunCoordinator` handshake; Phase 15 replaces the HUD with the production
/// one.
class GameScreen extends StatefulWidget {
  const GameScreen({
    this.chapter = 1,
    this.globalStage = 1,
    this.showTelemetry = true,
    super.key,
  });

  final int chapter;
  final int globalStage;

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

  Future<void> _start() async {
    try {
      final ContentLibrary content = await ContentLoader.load();
      if (!mounted) return;

      final SimWorld sim = SimWorld(
        seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
        content: content,
      );

      sim
        ..enemyHpBase = balance.Curves.enemyHp(widget.globalStage)
        ..globalStage = widget.globalStage
        // Design Law 1: a common enemy dies in 0.8-1.6 s for a
        // correctly-progressed player, which is two Tier-III arrows. Phase 10
        // computes this from the real loadout; until then it is solved from the
        // curve so the playtest fights at the intended pace.
        ..playerAttack =
            balance.Curves.enemyHp(widget.globalStage) / (2.10 * 2);

      sim.spawnPlayer(SimConfig.arenaWidth * 0.25, SimConfig.arenaHeight / 2);
      sim.beginRoom(
        RoomComposer.compose(
          content: content,
          rng: sim.rng,
          chapter: widget.chapter,
          globalStage: widget.globalStage,
        ),
      );

      setState(() {
        _game = QuiverfallGame(
          sim: sim,
          sinks: <CueSink>[_haptics, _audio],
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
              showTelemetry: widget.showTelemetry,
            ),
            _ExitButton(telemetry: game.telemetry),
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
