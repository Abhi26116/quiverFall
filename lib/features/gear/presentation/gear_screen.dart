import 'package:flutter/material.dart';
import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/affix_definition.dart';
import 'package:quiverfall/game/arrows/affix_reroll.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/arrows/arrow_refinement.dart';
import 'package:quiverfall/game/arrows/arrow_workshop.dart';
import 'package:quiverfall/game/arrows/material_tier.dart';

/// docs/10-ui-ux.md §10.11: the equipped arrow's detail (refine level,
/// baseMult, affix rows with lock/reroll), the 12-arrow roster grid, and
/// materials — wired to [ArrowWorkshop].
///
/// Rerolling and refining draw fresh entropy per tap
/// (`Rng(DateTime.now().microsecondsSinceEpoch)`) rather than a seed carried
/// on [PlayerSave]. Nothing about a Gear-screen roll is replayed or balance-
/// harnessed the way a run's own RNG stream is (docs/12 §12.0's determinism
/// requirement is about runs and the harness); a fresh seed per tap is the
/// same "just roll it" shape any other meta-progression gacha pull uses.
class GearScreen extends StatefulWidget {
  const GearScreen({
    required this.repository,
    required this.arrows,
    required this.affixes,
    super.key,
  });

  final PlayerRepository repository;
  final ArrowCatalogue arrows;
  final AffixCatalogue affixes;

  @override
  State<GearScreen> createState() => _GearScreenState();
}

class _GearScreenState extends State<GearScreen> {
  late String _selectedArrowId = widget.repository.save.profile.equippedArrowId;

  void _showError(EconomyError error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.message)));
  }

  void _apply(Result<PlayerSave, EconomyError> result) {
    switch (result) {
      case Ok<PlayerSave, EconomyError>(value: final PlayerSave save):
        widget.repository.mutate((_) => save);
      case Err<PlayerSave, EconomyError>(error: final EconomyError error):
        _showError(error);
    }
  }

  Rng _freshRng() => Rng(DateTime.now().microsecondsSinceEpoch);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerSave?>(
      valueListenable: widget.repository.saveNotifier,
      builder: (BuildContext context, PlayerSave? save, _) {
        if (save == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final ArrowDefinition def = widget.arrows.byKey(_selectedArrowId)!;
        final ArrowInstance? owned = save.inventory.arrows[_selectedArrowId];

        return Scaffold(
          appBar: AppBar(title: const Text('GEAR')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Tokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  KeyedSubtree(
                    key: const ValueKey<String>('gear-detail'),
                    child: owned == null
                        ? _CraftPanel(
                            definition: def,
                            save: save,
                            onCraft: () => _apply(ArrowWorkshop.craft(
                                save, widget.arrows, def.key)),
                          )
                        : _EquippedPanel(
                            definition: def,
                            instance: owned,
                            save: save,
                            affixes: widget.affixes,
                            onRefine: () => _apply(ArrowWorkshop.refine(
                                save, widget.affixes, def.key, _freshRng())),
                            onReroll: (int slot) => _apply(
                                ArrowWorkshop.rerollAffix(save, widget.affixes,
                                    def.key, slot, _freshRng())),
                            onToggleLock: (int slot, bool lock) => _apply(lock
                                ? ArrowWorkshop.lockAffix(save, def.key, slot)
                                : ArrowWorkshop.unlockAffix(
                                    save, def.key, slot)),
                            onEquip: () => widget.repository.mutate(
                              (PlayerSave s) => s.copyWith(
                                profile: s.profile
                                    .copyWith(equippedArrowId: def.key),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: Tokens.space6),
                  Text('ALL ARROWS',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: Tokens.space2),
                  _ArrowGrid(
                    arrows: widget.arrows,
                    save: save,
                    selectedId: _selectedArrowId,
                    onSelect: (String id) =>
                        setState(() => _selectedArrowId = id),
                  ),
                  const SizedBox(height: Tokens.space6),
                  Text('MATERIALS',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: Tokens.space2),
                  _MaterialsRow(save: save),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// docs/08 §8.4's roman-numeral display for a 0-indexed [ArrowInstance.refineLevel].
String _romanRefine(int level) {
  const List<String> numerals = <String>['I', 'II', 'III', 'IV', 'V'];
  return numerals[level.clamp(0, numerals.length - 1)];
}

String _formatAffixValue(AffixDefinition def, double value) {
  return switch (def.archetype) {
    AffixArchetype.weaving => '+${value.toStringAsFixed(2)}s',
    AffixArchetype.piercing => '+${value.round()} pierce',
    AffixArchetype.threaded => '+${value.round()} Confluence cap',
    _ => '+${(value * 100).toStringAsFixed(1)}%',
  };
}

class _CraftPanel extends StatelessWidget {
  const _CraftPanel({
    required this.definition,
    required this.save,
    required this.onCraft,
  });

  final ArrowDefinition definition;
  final PlayerSave save;
  final VoidCallback onCraft;

  bool get _canAfford {
    final ArrowCraftCost cost = definition.craftCost;
    if (save.wallet.gold < cost.gold) return false;
    for (final MapEntry<int, int> need in cost.materialsByTier.entries) {
      if (save.wallet.materialCount(MaterialTier.keyFor(need.key)) <
          need.value) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ArrowCraftCost cost = definition.craftCost;
    final String materials = cost.materialsByTier.entries
        .map((MapEntry<int, int> e) => '${e.value} T${e.key}')
        .join(' · ');

    return Container(
      padding: const EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(definition.name, style: text.titleLarge),
          const SizedBox(height: Tokens.space1),
          Text(definition.description, style: text.bodyMedium),
          const SizedBox(height: Tokens.space3),
          Text(
            materials.isEmpty
                ? '${cost.gold} gold to craft'
                : '${cost.gold} gold + $materials to craft',
            style: text.labelMedium,
          ),
          const SizedBox(height: Tokens.space3),
          FilledButton(
            onPressed: _canAfford ? onCraft : null,
            child: const Text('CRAFT'),
          ),
        ],
      ),
    );
  }
}

class _EquippedPanel extends StatelessWidget {
  const _EquippedPanel({
    required this.definition,
    required this.instance,
    required this.save,
    required this.affixes,
    required this.onRefine,
    required this.onReroll,
    required this.onToggleLock,
    required this.onEquip,
  });

  final ArrowDefinition definition;
  final ArrowInstance instance;
  final PlayerSave save;
  final AffixCatalogue affixes;
  final VoidCallback onRefine;
  final ValueChanged<int> onReroll;
  final void Function(int slot, bool lock) onToggleLock;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool equipped = save.profile.equippedArrowId == definition.key;
    final double baseMult = definition.baseMult *
        ArrowRefinement.baseMultMultiplier(instance.refineLevel);
    final bool atMaxRefine = instance.refineLevel >= ArrowRefinement.maxLevel;
    final int refineGoldCost =
        atMaxRefine ? 0 : ArrowRefinement.goldCost(instance.refineLevel);
    final int rerollCost =
        AffixReroll.goldCost(save.inventory.rerollCountThisSession);

    return Container(
      padding: const EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
              '${definition.name}  ·  Refine '
              '${_romanRefine(instance.refineLevel)}',
              style: text.titleLarge),
          Text('${baseMult.toStringAsFixed(2)}× dmg · '
              '${instance.affixes.length} affixes'),
          const SizedBox(height: Tokens.space3),
          for (int slot = 0; slot < instance.affixes.length; slot++)
            _AffixRow(
              affix: instance.affixes[slot],
              definition: affixes.byKey(instance.affixes[slot].affixId),
              locked: instance.lockedAffixSlots.contains(slot),
              rerollCost: rerollCost,
              canLockMore: instance.canLockMore,
              onReroll: () => onReroll(slot),
              onToggleLock: (bool lock) => onToggleLock(slot, lock),
            ),
          const SizedBox(height: Tokens.space3),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: atMaxRefine ? null : onRefine,
                  child: Text(
                      atMaxRefine ? 'MAX REFINE' : 'REFINE  $refineGoldCost🪙'),
                ),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: FilledButton(
                  onPressed: equipped ? null : onEquip,
                  child: Text(equipped ? 'EQUIPPED' : 'EQUIP'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AffixRow extends StatelessWidget {
  const _AffixRow({
    required this.affix,
    required this.definition,
    required this.locked,
    required this.rerollCost,
    required this.canLockMore,
    required this.onReroll,
    required this.onToggleLock,
  });

  final Affix affix;
  final AffixDefinition? definition;
  final bool locked;
  final int rerollCost;
  final bool canLockMore;
  final VoidCallback onReroll;
  final ValueChanged<bool> onToggleLock;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AffixDefinition? def = definition;
    final String label = def == null
        ? affix.affixId
        : '${def.name} ${_formatAffixValue(def, affix.value)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: text.bodyMedium)),
          IconButton(
            tooltip: locked ? 'Unlock' : 'Lock',
            onPressed:
                locked || canLockMore ? () => onToggleLock(!locked) : null,
            icon: Icon(
              locked ? Icons.lock : Icons.lock_open,
              size: 18,
              color: locked ? Tokens.accent : Tokens.inkDim,
            ),
          ),
          if (!locked)
            TextButton(
              onPressed: onReroll,
              child: Text('↻$rerollCost'),
            ),
        ],
      ),
    );
  }
}

class _ArrowGrid extends StatelessWidget {
  const _ArrowGrid({
    required this.arrows,
    required this.save,
    required this.selectedId,
    required this.onSelect,
  });

  final ArrowCatalogue arrows;
  final PlayerSave save;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: Tokens.space2,
      mainAxisSpacing: Tokens.space2,
      children: <Widget>[
        for (final ArrowDefinition def in arrows.all)
          _ArrowTile(
            key: ValueKey<String>('arrow-tile-${def.key}'),
            definition: def,
            owned: save.inventory.arrows.containsKey(def.key),
            selected: def.key == selectedId,
            equipped: def.key == save.profile.equippedArrowId,
            onTap: () => onSelect(def.key),
            labelStyle: text.labelSmall,
          ),
      ],
    );
  }
}

class _ArrowTile extends StatelessWidget {
  const _ArrowTile({
    required this.definition,
    required this.owned,
    required this.selected,
    required this.equipped,
    required this.onTap,
    required this.labelStyle,
    super.key,
  });

  final ArrowDefinition definition;
  final bool owned;
  final bool selected;
  final bool equipped;
  final VoidCallback onTap;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusChip),
      child: Container(
        decoration: BoxDecoration(
          color: owned ? Tokens.bgRaised : Tokens.bgPanel,
          borderRadius: BorderRadius.circular(Tokens.radiusChip),
          border: Border.all(
            color: selected
                ? Tokens.accent
                : (equipped ? Tokens.gold : Colors.transparent),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(Tokens.space1),
        child: Opacity(
          opacity: owned ? 1.0 : 0.45,
          child: Text(
            definition.name,
            style: labelStyle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _MaterialsRow extends StatelessWidget {
  const _MaterialsRow({required this.save});

  final PlayerSave save;

  static const List<String> _keys = <String>[
    'ashwood',
    'ironhead',
    'skyfeather',
    'prismcore',
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Wrap(
      spacing: Tokens.space4,
      runSpacing: Tokens.space2,
      children: <Widget>[
        for (final String key in _keys)
          Text(
            '${key[0].toUpperCase()}${key.substring(1)} '
            '${save.wallet.materialCount(key)}',
            style: text.bodyMedium,
          ),
      ],
    );
  }
}
