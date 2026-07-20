import 'package:flutter/material.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';

/// docs/11 §11.1: `RoomClear -> Shrine -> Game`. docs/02 §2.4: "the only
/// place in-run gold matters *during* the run".
///
/// Three of the four actions docs/02 names — the fourth, gambling, is never
/// specified anywhere in the GDD (no odds, no stake, no payout) and is left
/// out rather than guessed at; see [ShrinePricing]'s own doc comment.
///
/// Like [BoonChoice], this widget only reads [StageRunner] for prices and
/// [StageRunner.bankedGold] — it does not spend anything itself. Each button
/// disables itself when the run cannot afford it, so a tap can never reach a
/// rejected purchase; [StageRunner]'s own affordability check underneath is
/// the actual guarantee, this is just what keeps a dead button from inviting
/// the tap in the first place.
class Shrine extends StatelessWidget {
  const Shrine({
    required this.runner,
    required this.onBuyHeal,
    required this.onBuyReroll,
    required this.onBuyBoon,
    required this.onLeave,
    super.key,
  });

  final StageRunner runner;
  final VoidCallback onBuyHeal;
  final VoidCallback onBuyReroll;
  final VoidCallback onBuyBoon;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final double gold = runner.bankedGold;

    // A Column sized to its natural height, the way the first draft of this
    // widget was, overflows on a short landscape phone — three action cards
    // plus a title and a footer button do not fit in ~390 dp of height. The
    // three actions scroll; the title and the CONTINUE button stay put, the
    // same split `BoonChoice` uses for its own card list.
    return ColoredBox(
      color: Tokens.bgDeep.withOpacity(0.96),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Column(
            children: <Widget>[
              const SizedBox(height: Tokens.space6),
              Text('THE SHRINE', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Tokens.space2),
              _GoldReadout(gold: gold),
              const SizedBox(height: Tokens.space4),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    _ShrineAction(
                      label: 'HEAL',
                      detail: '+${(ShrineActionDetail.healFraction * 100).round()} '
                          '% max HP',
                      price: runner.shrineHealPrice,
                      available: gold,
                      onBuy: onBuyHeal,
                    ),
                    const SizedBox(height: Tokens.space3),
                    _ShrineAction(
                      label: 'REROLL',
                      detail: 'One free reroll on your next Boon choice',
                      price: runner.shrineRerollPrice,
                      available: gold,
                      onBuy: onBuyReroll,
                    ),
                    const SizedBox(height: Tokens.space3),
                    _ShrineAction(
                      label: 'BUY A BOON',
                      detail: 'A guaranteed Rare-or-better draw',
                      price: runner.shrineBoonPrice,
                      available: gold,
                      onBuy: onBuyBoon,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Tokens.space3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onLeave,
                  child: const Text('CONTINUE'),
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

/// Values a widget test can assert against without importing the pricing
/// module's implementation constants directly.
abstract final class ShrineActionDetail {
  static const double healFraction = 0.35;
}

class _GoldReadout extends StatelessWidget {
  const _GoldReadout({required this.gold});

  final double gold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.circle, color: Tokens.gold, size: 12),
        const SizedBox(width: Tokens.space1),
        Text(
          '${gold.round()} gold banked',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Tokens.gold),
        ),
      ],
    );
  }
}

class _ShrineAction extends StatelessWidget {
  const _ShrineAction({
    required this.label,
    required this.detail,
    required this.price,
    required this.available,
    required this.onBuy,
  });

  final String label;
  final String detail;
  final double price;
  final double available;
  final VoidCallback onBuy;

  bool get _affordable => available >= price;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: text.titleMedium),
                  const SizedBox(height: Tokens.space1),
                  Text(detail, style: text.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: Tokens.space3),
            SizedBox(
              width: 96,
              child: FilledButton(
                onPressed: _affordable ? onBuy : null,
                child: Text('${price.round()}g'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
