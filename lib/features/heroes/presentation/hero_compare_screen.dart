import 'package:flutter/material.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/balance/curves.dart' as balance;
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';

/// docs/10-ui-ux.md §10.12: "Compare overlays two heroes' stats side by
/// side, which is the feature theorycrafters ask for in every game in this
/// genre and almost never get."
///
/// Either side may be a hero the player has not unlocked — a build is worth
/// comparing before spending shards on it, not only after — in which case
/// its stats are shown at the level-1, ★0 baseline every unowned
/// [HeroState] defaults to.
class HeroCompareScreen extends StatefulWidget {
  const HeroCompareScreen({
    required this.heroes,
    required this.save,
    required this.initialLeftKey,
    super.key,
  });

  final HeroCatalogue heroes;
  final PlayerSave save;
  final String initialLeftKey;

  @override
  State<HeroCompareScreen> createState() => _HeroCompareScreenState();
}

class _HeroCompareScreenState extends State<HeroCompareScreen> {
  late String? _leftKey = widget.initialLeftKey;
  String? _rightKey;

  @override
  void initState() {
    super.initState();
    // Default the right side to a different hero than the left, when the
    // roster has one — an immediate two-column comparison rather than an
    // empty picker on first open.
    final HeroDefinition? other = widget.heroes.all
        .cast<HeroDefinition?>()
        .firstWhere((HeroDefinition? h) => h?.key != _leftKey, orElse: () => null);
    _rightKey = other?.key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('COMPARE')),
      body: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _HeroPicker(
                    heroes: widget.heroes,
                    value: _leftKey,
                    onChanged: (String? key) => setState(() => _leftKey = key),
                  ),
                ),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: _HeroPicker(
                    heroes: widget.heroes,
                    value: _rightKey,
                    onChanged: (String? key) => setState(() => _rightKey = key),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space6),
            Expanded(
              child: _leftKey == null || _rightKey == null
                  ? Center(
                      child: Text(
                        'Pick two heroes to compare.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : _CompareTable(
                      heroes: widget.heroes,
                      save: widget.save,
                      leftKey: _leftKey!,
                      rightKey: _rightKey!,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPicker extends StatelessWidget {
  const _HeroPicker({
    required this.heroes,
    required this.value,
    required this.onChanged,
  });

  final HeroCatalogue heroes;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      hint: const Text('Choose a hero'),
      items: <DropdownMenuItem<String>>[
        for (final HeroDefinition h in heroes.all)
          DropdownMenuItem<String>(value: h.key, child: Text(h.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({
    required this.heroes,
    required this.save,
    required this.leftKey,
    required this.rightKey,
  });

  final HeroCatalogue heroes;
  final PlayerSave save;
  final String leftKey;
  final String rightKey;

  @override
  Widget build(BuildContext context) {
    final HeroDefinition left = heroes.byKey(leftKey)!;
    final HeroDefinition right = heroes.byKey(rightKey)!;
    final HeroState leftState = save.heroes[leftKey] ?? HeroState(heroId: leftKey);
    final HeroState rightState =
        save.heroes[rightKey] ?? HeroState(heroId: rightKey);

    final TextTheme text = Theme.of(context).textTheme;

    TableRow statRow(
        String label, double Function(HeroDefinition, HeroState) stat) {
      final double a = stat(left, leftState);
      final double b = stat(right, rightState);
      return TableRow(children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
          child: Text(label, style: text.labelMedium?.copyWith(color: Tokens.inkDim)),
        ),
        _StatCell(value: a, betterOrEqual: a >= b),
        _StatCell(value: b, betterOrEqual: b >= a),
      ]);
    }

    return ListView(
      children: <Widget>[
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
          },
          children: <TableRow>[
            TableRow(children: <Widget>[
              const SizedBox.shrink(),
              _HeroHeader(name: left.name, state: leftState),
              _HeroHeader(name: right.name, state: rightState),
            ]),
            statRow(
              'ATK',
              (HeroDefinition d, HeroState s) =>
                  balance.Curves.heroStat(d.stats.atk, s.level, s.stars),
            ),
            statRow(
              'HP',
              (HeroDefinition d, HeroState s) =>
                  balance.Curves.heroStat(d.stats.hp, s.level, s.stars),
            ),
            statRow(
              'Move',
              (HeroDefinition d, HeroState s) =>
                  balance.Curves.heroStat(d.stats.moveSpeed, s.level, s.stars),
            ),
            statRow(
              'Rate',
              (HeroDefinition d, HeroState s) =>
                  balance.Curves.heroStat(d.stats.fireRate, s.level, s.stars),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _AbilitySummary(definition: left)),
            const SizedBox(width: Tokens.space3),
            Expanded(child: _AbilitySummary(definition: right)),
          ],
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.name, required this.state});

  final String name;
  final HeroState state;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
      child: Column(
        children: <Widget>[
          Text(name, style: text.titleSmall, textAlign: TextAlign.center),
          Text('★${state.stars} · Lv ${state.level}',
              style: text.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.betterOrEqual});

  final double value;
  final bool betterOrEqual;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
      child: Text(
        value.round().toString(),
        textAlign: TextAlign.center,
        style: text.titleMedium?.copyWith(
          color: betterOrEqual ? Tokens.accent : Tokens.inkDim,
        ),
      ),
    );
  }
}

class _AbilitySummary extends StatelessWidget {
  const _AbilitySummary({required this.definition});

  final HeroDefinition definition;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(definition.passive.name,
              style: text.labelMedium?.copyWith(color: Tokens.accent)),
          Text(definition.ultimate.name, style: text.labelMedium),
        ],
      ),
    );
  }
}
