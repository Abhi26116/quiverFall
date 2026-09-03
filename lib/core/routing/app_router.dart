import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quiverfall/core/routing/route_guards.dart';
import 'package:quiverfall/core/routing/routes.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/devtools/sim_bench_screen.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:quiverfall/features/gameplay/presentation/game_screen.dart';
import 'package:quiverfall/features/heroes/presentation/hero_screen.dart';
import 'package:quiverfall/features/menu/presentation/menu_screen.dart';
import 'package:quiverfall/features/shell/placeholder_screen.dart';
import 'package:quiverfall/game/content/content_library.dart';

/// Every route in the game, in one file.
///
/// Screens are placeholders until their phase lands, but the graph, the guards,
/// and the back-stack behaviour are real from Phase 1 — those are the parts that
/// break subtly and late if left until the end.
///
/// See docs/11-screen-flow.md.
class AppRouter {
  AppRouter({
    required PlayerRepository repository,
    required RunCoordinator runs,
    required ContentLibrary content,
  })  : _repository = repository,
        _runs = runs,
        _content = content;

  final PlayerRepository _repository;
  final RunCoordinator _runs;
  final ContentLibrary _content;

  late final GoRouter router = GoRouter(
    initialLocation: Routes.menu,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.menu,
        builder: (_, __) => MenuScreen(repository: _repository),
      ),
      GoRoute(
        path: Routes.levels,
        redirect: (BuildContext context, GoRouterState state) {
          final int? chapter =
              int.tryParse(state.pathParameters['chapter'] ?? '');
          if (chapter == null) return Routes.menu;
          final GuardRejection? rejection =
              RouteGuards.chapter(_repository.saveNotifier.value, chapter);
          return rejection == null ? null : Routes.menu;
        },
        builder: (_, GoRouterState state) => PlaceholderScreen(
          title: 'Chapter ${state.pathParameters['chapter']}',
          buildPhase: 8,
          detail: 'Level Select. Stage path, threat preview, star records.',
        ),
      ),
      GoRoute(
        path: Routes.loadout,
        builder: (_, __) => const PlaceholderScreen(
          title: 'Loadout',
          buildPhase: 10,
          detail: 'Hero, arrow and Mark selection before a descent.',
        ),
      ),
      GoRoute(
        path: Routes.game,
        redirect: (BuildContext context, GoRouterState state) {
          // Rejects deep links and restored back-stack entries that point at
          // /game with no session behind them.
          final GuardRejection? rejection =
              RouteGuards.game(_repository.saveNotifier.value, _runs);
          return rejection == null ? null : Routes.menu;
        },
        builder: (_, __) => const GameScreen(),
      ),
      GoRoute(
        path: Routes.spire,
        builder: (_, __) => const PlaceholderScreen(
          title: 'The Spire',
          buildPhase: 13,
          detail: '24 upgrade nodes across 4 wings.',
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'research',
            redirect: (BuildContext context, GoRouterState state) {
              final GuardRejection? rejection =
                  RouteGuards.research(_repository.saveNotifier.value);
              return rejection == null ? null : Routes.spire;
            },
            builder: (_, __) => const PlaceholderScreen(
              title: 'Research Lab',
              buildPhase: 13,
              detail: 'Spends Insight. Unlocks Spire tier bands.',
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.heroes,
        builder: (_, __) =>
            HeroScreen(repository: _repository, heroes: _content.heroes),
      ),
      GoRoute(
        path: Routes.gear,
        builder: (_, __) => const PlaceholderScreen(
          title: 'Gear',
          buildPhase: 10,
          detail: 'Arrows, refinement, affixes, materials.',
        ),
      ),
      GoRoute(
        path: Routes.shop,
        builder: (_, __) => const PlaceholderScreen(
          title: 'Shop',
          buildPhase: 16,
          detail: 'Daily, gems, bundles, cosmetics.',
        ),
      ),
      GoRoute(
        path: Routes.compete,
        builder: (_, __) => const PlaceholderScreen(
          title: 'Compete',
          buildPhase: 17,
          detail: 'Cohort, global and friend ladders.',
        ),
      ),
      GoRoute(
        path: Routes.events,
        builder: (_, GoRouterState state) => PlaceholderScreen(
          title: 'Event',
          buildPhase: 17,
          detail: 'Event ${state.pathParameters['eventId']}.',
        ),
      ),
      GoRoute(
        path: Routes.pass,
        builder: (_, __) => const PlaceholderScreen(
          title: 'Battle Pass',
          buildPhase: 16,
          detail: '60 tiers, free and premium tracks.',
        ),
      ),
      GoRoute(
        path: Routes.achievements,
        builder: (_, __) => const PlaceholderScreen(
          title: 'Achievements',
          buildPhase: 15,
          detail: 'Progress, Marks, and the bestiary.',
        ),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const PlaceholderScreen(
          title: 'Settings',
          buildPhase: 15,
          detail: 'Audio, graphics, gameplay, account, legal.',
        ),
      ),
      GoRoute(
        path: Routes.daily,
        builder: (_, __) => const PlaceholderScreen(
          title: 'Daily Rewards',
          buildPhase: 14,
          detail: '28-day cycle. No streak-loss punishment.',
        ),
      ),
      GoRoute(
        path: Routes.devBench,
        builder: (_, __) => const SimBenchScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const PlaceholderScreen(
          title: 'Account',
          buildPhase: 17,
          detail: 'Cloud save. Guest play stays fully featured.',
        ),
      ),
    ],
    errorBuilder: (_, GoRouterState state) => PlaceholderScreen(
      title: 'Lost',
      buildPhase: 1,
      detail: 'No route for ${state.uri}.',
    ),
  );
}
