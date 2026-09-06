import 'package:flutter/material.dart';
import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/game/balance/curves.dart' as balance;
import 'package:quiverfall/game/spire/spire_catalogue.dart';
import 'package:quiverfall/game/spire/spire_definition.dart';
import 'package:quiverfall/game/spire/spire_workshop.dart';

/// docs/04 §4.2: 24 nodes across 4 wings, each a level 1-80 investment
/// against gold, gated past L20/L40/L60 by Insight spent here directly (no
/// separate Research Lab visit — [SpireWorkshop.unlockTierBand] is the same
/// spend either way). Wired straight to [SpireWorkshop], the same
/// `_apply(Result)` shape [HeroScreen]/[GearScreen] already use.
///
/// A locked wing tells the account level it needs, the same "never just a
/// lock icon" rule [HeroScreen] already follows for an unlocked hero.
class SpireScreen extends StatelessWidget {
  const SpireScreen({
    required this.repository,
    required this.spire,
    super.key,
  });

  final PlayerRepository repository;
  final SpireCatalogue spire;

  void _showError(BuildContext context, EconomyError error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.message)));
  }

  void _apply(BuildContext context, Result<PlayerSave, EconomyError> result) {
    switch (result) {
      case Ok<PlayerSave, EconomyError>(value: final PlayerSave save):
        repository.mutate((_) => save);
      case Err<PlayerSave, EconomyError>(error: final EconomyError error):
        _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerSave?>(
      valueListenable: repository.saveNotifier,
      builder: (BuildContext context, PlayerSave? save, _) {
        if (save == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('THE SPIRE'),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: Tokens.space4),
                child: Center(child: _CurrencyReadout(save: save)),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space4),
              children: <Widget>[
                for (final SpireWing wing in SpireWing.values)
                  _WingSection(
                    wing: wing,
                    nodes: spire.all
                        .where((SpireNodeDefinition n) => n.wing == wing)
                        .toList(),
                    save: save,
                    onLevelUp: (int nodeId) => _apply(
                      context,
                      SpireWorkshop.levelUp(save, spire, nodeId),
                    ),
                    onUnlockBand: (int nodeId, int band) => _apply(
                      context,
                      SpireWorkshop.unlockTierBand(save, spire, nodeId, band),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CurrencyReadout extends StatelessWidget {
  const _CurrencyReadout({required this.save});

  final PlayerSave save;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.circle, color: Tokens.gold, size: 12),
        const SizedBox(width: Tokens.space1),
        Text('${save.wallet.gold}', style: text.bodyMedium?.copyWith(color: Tokens.gold)),
        const SizedBox(width: Tokens.space3),
        const Icon(Icons.diamond, color: Tokens.accent, size: 12),
        const SizedBox(width: Tokens.space1),
        Text('${save.wallet.insight} Insight',
            style: text.bodyMedium?.copyWith(color: Tokens.accent)),
      ],
    );
  }
}

class _WingSection extends StatelessWidget {
  const _WingSection({
    required this.wing,
    required this.nodes,
    required this.save,
    required this.onLevelUp,
    required this.onUnlockBand,
  });

  final SpireWing wing;
  final List<SpireNodeDefinition> nodes;
  final PlayerSave save;
  final void Function(int nodeId) onLevelUp;
  final void Function(int nodeId, int band) onUnlockBand;

  String get _name => switch (wing) {
        SpireWing.armory => 'THE ARMORY',
        SpireWing.bulwark => 'THE BULWARK',
        SpireWing.fletchery => 'THE FLETCHERY',
        SpireWing.sanctum => 'THE SANCTUM',
      };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool locked = save.profile.accountLevel < wing.unlockAccountLevel;

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(_name, style: text.titleMedium),
          const SizedBox(height: Tokens.space2),
          if (locked)
            _LockedWingBanner(
              accountLevel: save.profile.accountLevel,
              requiredLevel: wing.unlockAccountLevel,
            )
          else
            for (final SpireNodeDefinition node in nodes) ...<Widget>[
              _NodeRow(
                node: node,
                level: save.spire.levelOf(node.id),
                band: save.spire.bandOf(node.id),
                gold: save.wallet.gold,
                insight: save.wallet.insight,
                onLevelUp: () => onLevelUp(node.id),
                onUnlockBand: (int band) => onUnlockBand(node.id, band),
              ),
              const SizedBox(height: Tokens.space2),
            ],
        ],
      ),
    );
  }
}

class _LockedWingBanner extends StatelessWidget {
  const _LockedWingBanner({required this.accountLevel, required this.requiredLevel});

  final int accountLevel;
  final int requiredLevel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Text(
          'Unlocks at account level $requiredLevel — you are level $accountLevel.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Tokens.inkDim),
        ),
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.level,
    required this.band,
    required this.gold,
    required this.insight,
    required this.onLevelUp,
    required this.onUnlockBand,
  });

  final SpireNodeDefinition node;
  final int level;
  final int band;
  final int gold;
  final int insight;
  final VoidCallback onLevelUp;
  final void Function(int band) onUnlockBand;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool maxed = level >= SpireNodeDefinition.maxLevel;
    final int nextLevel = level + 1;
    final int requiredBand = SpireWorkshop.requiredBandFor(nextLevel);
    final bool gateLocked = !maxed && requiredBand > 0 && band < requiredBand;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(node.name, style: text.titleSmall),
                  Text(node.description, style: text.bodySmall),
                  const SizedBox(height: Tokens.space1),
                  Text(
                    maxed ? 'Lv $level / ${SpireNodeDefinition.maxLevel} (MAX)'
                        : 'Lv $level / ${SpireNodeDefinition.maxLevel}',
                    style: text.labelMedium?.copyWith(color: Tokens.inkDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Tokens.space3),
            if (maxed)
              const SizedBox(width: 108)
            else if (gateLocked)
              _GateButton(
                band: requiredBand,
                cost: SpireWorkshop.tierGateInsightCost(requiredBand),
                affordable:
                    insight >= SpireWorkshop.tierGateInsightCost(requiredBand),
                onTap: () => onUnlockBand(requiredBand),
              )
            else
              _LevelUpButton(
                cost: balance.Curves.spireNodeCost(node.baseCost, nextLevel).round(),
                affordable: gold >=
                    balance.Curves.spireNodeCost(node.baseCost, nextLevel).round(),
                onTap: onLevelUp,
              ),
          ],
        ),
      ),
    );
  }
}

class _LevelUpButton extends StatelessWidget {
  const _LevelUpButton({
    required this.cost,
    required this.affordable,
    required this.onTap,
  });

  final int cost;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: FilledButton(
        onPressed: affordable ? onTap : null,
        child: Text('${cost}g'),
      ),
    );
  }
}

class _GateButton extends StatelessWidget {
  const _GateButton({
    required this.band,
    required this.cost,
    required this.affordable,
    required this.onTap,
  });

  final int band;
  final int cost;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: FilledButton(
        onPressed: affordable ? onTap : null,
        child: Text('L$band: $cost insight', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
