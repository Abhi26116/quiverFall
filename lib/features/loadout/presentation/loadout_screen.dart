import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quiverfall/core/routing/route_guards.dart';
import 'package:quiverfall/core/routing/routes.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:quiverfall/features/gameplay/application/run_launcher.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/arrows/arrow_refinement.dart';
import 'package:quiverfall/game/balance/curves.dart' as balance;
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';

/// docs/11-screen-flow.md §11.1: `LevelSel --> Loadout --> Game`. Picks the
/// hero, arrow, and (once Marks exist — docs/04 §4.5, Phase 13) Marks for a
/// descent.
///
/// **Only unlocked heroes and owned arrows are offered** — there is nothing
/// to preview here beyond what the Hero and Gear screens already show for a
/// locked one, and a run cannot be started with a build the player does not
/// have.
///
/// **DESCEND's scope stops at claiming the run.** It claims the slot through
/// [RunCoordinator], builds a real [RunSnapshot], and persists the choice as
/// the account's own equipped loadout — but `GameScreen` does not yet read
/// any of that back into its `SimWorld`, and Vigor is not spent. Both are
/// recorded, deliberately, in ADR 0014 rather than half-built here.
class LoadoutScreen extends StatefulWidget {
  const LoadoutScreen({
    required this.repository,
    required this.runs,
    required this.heroes,
    required this.arrows,
    this.stageRef,
    super.key,
  });

  final PlayerRepository repository;
  final RunCoordinator runs;
  final HeroCatalogue heroes;
  final ArrowCatalogue arrows;

  /// The stage this descent targets. Falls back to the campaign's own
  /// current position — `MenuScreen`'s own DESCEND button already assumes
  /// that default — since Level Select (the usual source of a real
  /// [StageRef]) is not built yet.
  final StageRef? stageRef;

  @override
  State<LoadoutScreen> createState() => _LoadoutScreenState();
}

class _LoadoutScreenState extends State<LoadoutScreen> {
  late String _heroId = widget.repository.save.profile.equippedHeroId;
  late String _arrowId = widget.repository.save.profile.equippedArrowId;

  List<HeroDefinition> _unlockedHeroes(PlayerSave save) => <HeroDefinition>[
        for (final HeroDefinition h in widget.heroes.all)
          if (save.heroes[h.key]?.unlocked ?? false) h,
      ];

  List<ArrowDefinition> _ownedArrows(PlayerSave save) => <ArrowDefinition>[
        for (final ArrowDefinition a in widget.arrows.all)
          if (save.inventory.arrows.containsKey(a.key)) a,
      ];

  void _descend(PlayerSave save) {
    final StageRef ref = widget.stageRef ??
        StageRef(chapter: save.campaign.currentChapter, stage: save.campaign.currentStage);
    final HeroDefinition heroDef = widget.heroes.byKey(_heroId)!;

    final GuardRejection? rejection = RunLauncher.launch(
      repository: widget.repository,
      runs: widget.runs,
      save: save,
      stageRef: ref,
      heroId: _heroId,
      arrowId: _arrowId,
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
    return ValueListenableBuilder<PlayerSave?>(
      valueListenable: widget.repository.saveNotifier,
      builder: (BuildContext context, PlayerSave? save, _) {
        if (save == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final List<HeroDefinition> heroes = _unlockedHeroes(save);
        final List<ArrowDefinition> arrows = _ownedArrows(save);
        final HeroDefinition? hero = widget.heroes.byKey(_heroId);
        final ArrowDefinition? arrow = widget.arrows.byKey(_arrowId);
        final bool ready = hero != null &&
            (save.heroes[_heroId]?.unlocked ?? false) &&
            arrow != null &&
            save.inventory.arrows.containsKey(_arrowId);

        return Scaffold(
          appBar: AppBar(title: const Text('LOADOUT')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('HERO', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: Tokens.space2),
                  DropdownButtonFormField<String>(
                    value: heroes.any((HeroDefinition h) => h.key == _heroId)
                        ? _heroId
                        : null,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: <DropdownMenuItem<String>>[
                      for (final HeroDefinition h in heroes)
                        DropdownMenuItem<String>(value: h.key, child: Text(h.name)),
                    ],
                    onChanged: (String? key) {
                      if (key != null) setState(() => _heroId = key);
                    },
                  ),
                  const SizedBox(height: Tokens.space6),
                  Text('ARROW', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: Tokens.space2),
                  DropdownButtonFormField<String>(
                    value: arrows.any((ArrowDefinition a) => a.key == _arrowId)
                        ? _arrowId
                        : null,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: <DropdownMenuItem<String>>[
                      for (final ArrowDefinition a in arrows)
                        DropdownMenuItem<String>(value: a.key, child: Text(a.name)),
                    ],
                    onChanged: (String? key) {
                      if (key != null) setState(() => _arrowId = key);
                    },
                  ),
                  const SizedBox(height: Tokens.space6),
                  if (hero != null && arrow != null)
                    _LoadoutPreview(
                      hero: hero,
                      heroState: save.heroes[_heroId] ?? HeroState(heroId: _heroId),
                      arrow: arrow,
                      arrowInstance: save.inventory.arrows[_arrowId],
                    ),
                  const Spacer(),
                  SizedBox(
                    height: Tokens.primaryCtaHeight,
                    child: FilledButton(
                      onPressed: ready ? () => _descend(save) : null,
                      child: const Text('DESCEND'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadoutPreview extends StatelessWidget {
  const _LoadoutPreview({
    required this.hero,
    required this.heroState,
    required this.arrow,
    required this.arrowInstance,
  });

  final HeroDefinition hero;
  final HeroState heroState;
  final ArrowDefinition arrow;
  final ArrowInstance? arrowInstance;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double atk = balance.Curves.heroStat(hero.stats.atk, heroState.level, heroState.stars);
    final double hp = balance.Curves.heroStat(hero.stats.hp, heroState.level, heroState.stars);
    final int refineLevel = arrowInstance?.refineLevel ?? 0;
    final double baseMult =
        arrow.baseMult * ArrowRefinement.baseMultMultiplier(refineLevel);

    return Container(
      padding: const EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${hero.name} · ${arrow.name}', style: text.titleMedium),
          const SizedBox(height: Tokens.space1),
          Text(
            'ATK ${atk.round()} · HP ${hp.round()} · '
            '${baseMult.toStringAsFixed(2)}× arrow dmg',
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}
