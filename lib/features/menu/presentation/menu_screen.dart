import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quiverfall/core/routing/route_guards.dart';
import 'package:quiverfall/core/routing/routes.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:quiverfall/features/gameplay/application/run_launcher.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';

/// The hub. Phase 13 replaces the body with the real Spire scene.
///
/// Even as a placeholder this respects the two-tap rule from
/// docs/10-ui-ux.md §10.4: DESCEND is one tap from launch, and every other
/// destination is exactly one tap from here.
class MenuScreen extends StatelessWidget {
  const MenuScreen({
    required this.repository,
    required this.runs,
    required this.heroes,
    super.key,
  });

  final PlayerRepository repository;
  final RunCoordinator runs;
  final HeroCatalogue heroes;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerSave?>(
      valueListenable: repository.saveNotifier,
      builder: (BuildContext context, PlayerSave? save, _) {
        if (save == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _MenuBody(
          save: save,
          repository: repository,
          runs: runs,
          heroes: heroes,
        );
      },
    );
  }
}

class _MenuBody extends StatelessWidget {
  const _MenuBody({
    required this.save,
    required this.repository,
    required this.runs,
    required this.heroes,
  });

  final PlayerSave save;
  final PlayerRepository repository;
  final RunCoordinator runs;
  final HeroCatalogue heroes;

  /// docs/11-screen-flow.md §11.1: `Menu -->|DESCEND| Game` — resumes
  /// straight into a run with the account's currently equipped build, no
  /// picker at all. Shares the exact claim-a-run logic the Loadout Sheet's
  /// own DESCEND button uses.
  void _descend(BuildContext context) {
    final HeroDefinition? heroDef = heroes.byKey(save.profile.equippedHeroId);
    if (heroDef == null) return;

    final GuardRejection? rejection = RunLauncher.launch(
      repository: repository,
      runs: runs,
      save: save,
      stageRef: StageRef(
        chapter: save.campaign.currentChapter,
        stage: save.campaign.currentStage,
      ),
      heroId: save.profile.equippedHeroId,
      arrowId: save.profile.equippedArrowId,
      heroDefinition: heroDef,
      now: DateTime.now().toUtc(),
    );
    if (rejection != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(rejection.playerMessage)));
      return;
    }

    context.push(Routes.game);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _CurrencyBar(save: save),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Long-press opens the on-device sim benchmark. A hidden
                    // gesture rather than a visible button: it is a developer
                    // tool, and deep-link routing does not exist until Phase 17.
                    GestureDetector(
                      onLongPress: () => context.push(Routes.devBench),
                      child: Text('QUIVERFALL', style: text.displayLarge),
                    ),
                    const SizedBox(height: Tokens.space2),
                    Text(
                      'The Spire scene lands in Phase 13.',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space4,
                vertical: Tokens.space3,
              ),
              child: SizedBox(
                height: Tokens.primaryCtaHeight,
                child: FilledButton(
                  onPressed: () => _descend(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text('DESCEND'),
                      Text(
                        'Chapter ${save.campaign.currentChapter} · '
                        'Stage ${save.campaign.currentStage}',
                        style: text.labelSmall?.copyWith(
                          color: Tokens.bgDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const _BottomNav(),
          ],
        ),
      ),
    );
  }
}

class _CurrencyBar extends StatelessWidget {
  const _CurrencyBar({required this.save});

  final PlayerSave save;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Tokens.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
        child: Row(
          children: <Widget>[
            _Pill(
              label: '${save.vigor.current}/${save.vigor.max}',
              color: Tokens.accent,
            ),
            const SizedBox(width: Tokens.space3),
            _Pill(label: '${save.wallet.gold}', color: Tokens.gold),
            const SizedBox(width: Tokens.space3),
            _Pill(label: '${save.wallet.gems}', color: Tokens.gem),
            const Spacer(),
            IconButton(
              onPressed: () => context.push(Routes.settings),
              icon: const Icon(Icons.settings_outlined),
              color: Tokens.inkDim,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Tokens.space1),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    const List<({String label, IconData icon, String route})> items =
        <({String label, IconData icon, String route})>[
      (label: 'Heroes', icon: Icons.person_outline, route: Routes.heroes),
      (
        label: 'Spire',
        icon: Icons.account_balance_outlined,
        route: Routes.spire
      ),
      (label: 'Gear', icon: Icons.backpack_outlined, route: Routes.gear),
      (label: 'Shop', icon: Icons.storefront_outlined, route: Routes.shop),
      (
        label: 'Compete',
        icon: Icons.leaderboard_outlined,
        route: Routes.compete
      ),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Tokens.bgPanel,
        border: Border(top: BorderSide(color: Tokens.bgRaised)),
      ),
      child: SizedBox(
        height: Tokens.navBarHeight,
        child: Row(
          children: <Widget>[
            for (final ({String label, IconData icon, String route}) item
                in items)
              Expanded(
                child: InkWell(
                  onTap: () => context.push(item.route),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(item.icon, size: 22, color: Tokens.inkDim),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
