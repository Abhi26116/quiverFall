import 'package:flutter/material.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/boons/boon_pool.dart';

/// docs/11 §11.1: `RoomClear -> Boon Choice -> Game`.
///
/// Reads [StageRunner.pendingBoonOffers] and nothing else about the run — it
/// does not take the pick itself, it reports which card was tapped through
/// [onPick] and leaves applying it to whoever owns the halt/resume dance with
/// the simulation ([GameScreen]). That split is what keeps this widget testable
/// with a plain [StageRunner] and no live [SimWorld] underneath it.
///
/// Rarity is read from each card and nothing is said about *why* a card is in
/// the set. docs/09 §9.1's anti-frustration rules — the forced offence card,
/// the usability fallback — are described there as protecting the player
/// "quietly", and a badge reading FORCED on a card would be the opposite of
/// quiet.
class BoonChoice extends StatelessWidget {
  const BoonChoice({
    required this.runner,
    required this.onPick,
    this.onReroll,
    super.key,
  });

  final StageRunner runner;
  final ValueChanged<BoonDefinition> onPick;

  /// Null when no reroll is available — the button disables rather than
  /// disappears, so its price stays visible as something to want.
  final VoidCallback? onReroll;

  @override
  Widget build(BuildContext context) {
    final List<BoonOffer> offers = runner.pendingBoonOffers;

    return ColoredBox(
      color: Tokens.bgDeep.withOpacity(0.96),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Column(
            children: <Widget>[
              const SizedBox(height: Tokens.space6),
              Text('CHOOSE A BOON', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Tokens.space2),
              Text(
                'Room ${runner.roomIndex + 1} of ${runner.roomTotal}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Tokens.space4),
              Expanded(
                child: ListView.separated(
                  itemCount: offers.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Tokens.space3),
                  itemBuilder: (BuildContext context, int i) => _BoonCard(
                    definition: offers[i].definition,
                    onTap: () => onPick(offers[i].definition),
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space3),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onReroll,
                  child: Text(
                    onReroll != null
                        ? 'REROLL  ·  ${runner.rerollsRemaining} left'
                        : 'REROLL  ·  none left',
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space4),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoonCard extends StatelessWidget {
  const _BoonCard({required this.definition, required this.onTap});

  final BoonDefinition definition;
  final VoidCallback onTap;

  /// docs/09 §9.2 G: Cursed cards render with a crimson border. Everything
  /// else uses its rarity's colour, matching `Tokens.Rarity`.
  Color get _accent =>
      definition.category == BoonCategory.cursed ? Tokens.danger : switch (definition.rarity) {
        BoonRarity.common => Tokens.rarityCommon,
        BoonRarity.rare => Tokens.rarityRare,
        BoonRarity.epic => Tokens.rarityEpic,
        BoonRarity.legendary => Tokens.rarityLegendary,
        BoonRarity.mythic => Tokens.rarityMythic,
      };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? downside = definition.downside;

    return Material(
      color: Tokens.bgPanel,
      borderRadius: BorderRadius.circular(Tokens.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(Tokens.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusCard),
            border: Border.all(color: _accent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(definition.name, style: text.titleMedium),
                  ),
                  _RarityPill(
                    label: definition.category == BoonCategory.cursed
                        ? 'CURSED'
                        : definition.rarity.name.toUpperCase(),
                    color: _accent,
                  ),
                ],
              ),
              const SizedBox(height: Tokens.space2),
              Text(definition.description, style: text.bodyLarge),
              if (downside != null) ...<Widget>[
                const SizedBox(height: Tokens.space2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.warning_amber_rounded,
                        color: Tokens.danger, size: 16),
                    const SizedBox(width: Tokens.space1),
                    Expanded(
                      child: Text(
                        downside,
                        style: text.bodyMedium?.copyWith(color: Tokens.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RarityPill extends StatelessWidget {
  const _RarityPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(Tokens.radiusChip),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, letterSpacing: 0.6),
      ),
    );
  }
}
