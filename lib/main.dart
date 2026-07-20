import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiverfall/bootstrap.dart';
import 'package:quiverfall/core/di/service_locator.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/core/routing/app_router.dart';
import 'package:quiverfall/core/theme/app_theme.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Result<void, BootstrapFailure> result = await bootstrap();

  runApp(
    ProviderScope(
      child: switch (result) {
        Ok<void, BootstrapFailure>() => const QuiverfallApp(),
        Err<void, BootstrapFailure>(error: final BootstrapFailure failure) =>
          BootstrapErrorApp(failure: failure),
      },
    ),
  );
}

class QuiverfallApp extends StatefulWidget {
  const QuiverfallApp({super.key});

  @override
  State<QuiverfallApp> createState() => _QuiverfallAppState();
}

class _QuiverfallAppState extends State<QuiverfallApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = locator<AppRouter>().router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Unconditional flush on background. The OS can kill a backgrounded app at
    // any moment with no further callbacks, so this is the last reliable chance
    // to persist. See docs/12-architecture.md §12.7.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(locator<PlayerRepository>().flush());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Quiverfall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: _router,
    );
  }
}

/// Shown when bootstrap fails.
///
/// A frozen splash is the worst possible failure mode: the player cannot tell a
/// slow launch from a dead app, so they force-quit and often uninstall. This
/// names the stage, shows the error code, and offers a retry.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({required this.failure, super.key});

  final BootstrapFailure failure;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Tokens.warn,
                  size: 48,
                ),
                const SizedBox(height: Tokens.space4),
                Text(
                  'Quiverfall could not start',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: Tokens.space2),
                Text(
                  'Stage: ${failure.stage.name}\n'
                  'Code: ${failure.error.code}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Tokens.space6),
                FilledButton(
                  onPressed: () async {
                    await disposeContainer();
                    final Result<void, BootstrapFailure> retry =
                        await bootstrap();
                    if (retry.isOk) {
                      runApp(const ProviderScope(child: QuiverfallApp()));
                    }
                  },
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
