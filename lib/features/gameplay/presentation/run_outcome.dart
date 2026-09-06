import 'package:flutter/material.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';

/// docs/11 §11.1's own nav graph names both `RoomClear -> ... -> Victory`
/// and a defeat path — until now `GameScreen` rendered
/// `SizedBox.shrink()` for both, the visible half of the gap ADR 0096
/// closes on the save side. Deliberately minimal, the same "just enough to
/// be real, not a placeholder" scope that ADR's own workshop keeps:
/// [StageRunner.finalGold] is the only number this run actually has to
/// show yet — no stars, no material drops, no boss-defeat banner — each a
/// real, separate follow-on that ADR's own Consequences already name.
class RunOutcome extends StatelessWidget {
  const RunOutcome({
    required this.runner,
    required this.onContinue,
    super.key,
  });

  final StageRunner runner;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    assert(
      runner.status == StageStatus.complete ||
          runner.status == StageStatus.failed,
      'RunOutcome is only meaningful once a run has actually ended',
    );
    final bool victory = runner.status == StageStatus.complete;
    final double gold = runner.finalGold;
    final TextTheme text = Theme.of(context).textTheme;

    return ColoredBox(
      color: Tokens.bgDeep.withOpacity(0.96),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  victory ? 'STAGE COMPLETE' : 'RUN FAILED',
                  style: text.titleLarge?.copyWith(
                    color: victory ? Tokens.accent : Tokens.danger,
                  ),
                ),
                const SizedBox(height: Tokens.space3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.circle, color: Tokens.gold, size: 12),
                    const SizedBox(width: Tokens.space1),
                    Text(
                      '${gold.round()} gold',
                      style: text.bodyLarge?.copyWith(color: Tokens.gold),
                    ),
                  ],
                ),
                const SizedBox(height: Tokens.space6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onContinue,
                    child: const Text('RETURN TO MENU'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
