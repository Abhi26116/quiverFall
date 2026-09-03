import 'package:flutter/material.dart';
import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/heroes/presentation/hero_compare_screen.dart';
import 'package:quiverfall/game/balance/curves.dart' as balance;
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_workshop.dart';

/// docs/10-ui-ux.md §10.12: a horizontal carousel across the 20-hero roster.
/// Each page shows one hero's stats, passive, ultimate, and talent tree, with
/// level-up/star-up/equip actions wired straight to [HeroWorkshop] — and, for
/// a hero the player has not unlocked yet, exactly how to get it, never just
/// a lock icon ("A locked hero always tells you how to get it").
///
/// **Talent re-spec is not cost-gated here.** docs/02 §2.4 prices a *change*
/// to an already-made talent choice at "free ×3/day, then 250 gold", but that
/// needs a daily-reset counter nothing in the codebase has yet — the same gap
/// ADR 0013 §3 already flagged for the arrow reroll session counter. Tapping
/// either branch of an unlocked node sets it for free, unlimited times, until
/// that counter exists to price it. `docs/04-upgrades.md` gates *this* screen
/// on nothing else — the first pick at a newly-reached star, and every pick
/// before that daily economy is built, is honestly free.
class HeroScreen extends StatefulWidget {
  const HeroScreen({required this.repository, required this.heroes, super.key});

  final PlayerRepository repository;
  final HeroCatalogue heroes;

  @override
  State<HeroScreen> createState() => _HeroScreenState();
}

class _HeroScreenState extends State<HeroScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final String equippedId = widget.repository.save.profile.equippedHeroId;
    final int startIndex =
        widget.heroes.all.indexWhere((HeroDefinition h) => h.key == equippedId);
    _currentIndex = startIndex < 0 ? 0 : startIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerSave?>(
      valueListenable: widget.repository.saveNotifier,
      builder: (BuildContext context, PlayerSave? save, _) {
        if (save == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('HEROES'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => HeroCompareScreen(
                    heroes: widget.heroes,
                    save: save,
                    initialLeftKey: widget.heroes.all[_currentIndex].key,
                  ),
                )),
                child: const Text('Compare'),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: widget.heroes.all.length,
            onPageChanged: (int i) => setState(() => _currentIndex = i),
            itemBuilder: (BuildContext context, int i) {
              final HeroDefinition def = widget.heroes.all[i];
              final HeroState state =
                  save.heroes[def.key] ?? HeroState(heroId: def.key);
              return _HeroPage(
                key: ValueKey<String>(def.key),
                definition: def,
                state: state,
                save: save,
                onUnlock: () => _apply(HeroWorkshop.unlock(
                  save,
                  widget.heroes,
                  def.key,
                  now: DateTime.now().toUtc(),
                )),
                onLevelUp: () =>
                    _apply(HeroWorkshop.levelUp(save, widget.heroes, def.key)),
                onStarUp: () =>
                    _apply(HeroWorkshop.starUp(save, widget.heroes, def.key)),
                onEquip: () => widget.repository.mutate(
                  (PlayerSave s) => s.copyWith(
                    profile: s.profile.copyWith(equippedHeroId: def.key),
                  ),
                ),
                onChooseTalent: (int starRequired, String branchKey) =>
                    widget.repository.mutate((PlayerSave s) {
                  final HeroState current =
                      s.heroes[def.key] ?? HeroState(heroId: def.key);
                  final Map<String, String> choices =
                      Map<String, String>.of(current.talentChoices)
                        ..['$starRequired'] = branchKey;
                  return s.copyWith(
                    heroes: Map<String, HeroState>.of(s.heroes)
                      ..[def.key] = current.copyWith(talentChoices: choices),
                  );
                }),
              );
            },
          ),
        );
      },
    );
  }
}

class _HeroPage extends StatelessWidget {
  const _HeroPage({
    required this.definition,
    required this.state,
    required this.save,
    required this.onUnlock,
    required this.onLevelUp,
    required this.onStarUp,
    required this.onEquip,
    required this.onChooseTalent,
    super.key,
  });

  final HeroDefinition definition;
  final HeroState state;
  final PlayerSave save;
  final VoidCallback onUnlock;
  final VoidCallback onLevelUp;
  final VoidCallback onStarUp;
  final VoidCallback onEquip;
  final void Function(int starRequired, String branchKey) onChooseTalent;

  Color get _rarityColor => switch (definition.rarity) {
        HeroRarity.common => Tokens.rarityCommon,
        HeroRarity.rare => Tokens.rarityRare,
        HeroRarity.epic => Tokens.rarityEpic,
        HeroRarity.legendary => Tokens.rarityLegendary,
      };

  @override
  Widget build(BuildContext context) {
    if (!state.unlocked) {
      return _LockedHeroBody(
        definition: definition,
        save: save,
        accent: _rarityColor,
        onUnlock: onUnlock,
      );
    }

    final TextTheme text = Theme.of(context).textTheme;
    final bool equipped = save.profile.equippedHeroId == definition.key;
    final int levelCap =
        balance.Curves.heroLevelCap(save.campaign.currentChapter - 1);
    final bool atLevelCap = state.level >= levelCap;
    final bool atMaxStars = state.stars >= 6;
    final int levelCost = balance.Curves.heroLevelCost(state.level).round();
    final int starCost =
        atMaxStars ? 0 : balance.Curves.heroStarCost(state.stars + 1);

    final double atk =
        balance.Curves.heroStat(definition.stats.atk, state.level, state.stars);
    final double hp =
        balance.Curves.heroStat(definition.stats.hp, state.level, state.stars);
    final double fireRate = balance.Curves.heroStat(
        definition.stats.fireRate, state.level, state.stars);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PortraitBox(accent: _rarityColor, letter: definition.name[0]),
                const SizedBox(width: Tokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${definition.name}  ★${state.stars}',
                          style: text.titleLarge),
                      Text(definition.epithet, style: text.bodyMedium),
                      const SizedBox(height: Tokens.space1),
                      Text('Lv ${state.level} / $levelCap',
                          style: text.labelMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            Wrap(
              spacing: Tokens.space4,
              runSpacing: Tokens.space2,
              children: <Widget>[
                _StatPill(label: 'ATK', value: atk.round().toString()),
                _StatPill(label: 'HP', value: hp.round().toString()),
                _StatPill(
                    label: 'Rate', value: '${fireRate.toStringAsFixed(2)}/s'),
              ],
            ),
            const SizedBox(height: Tokens.space6),
            _AbilityCard(
              label: 'PASSIVE · ${definition.passive.name}',
              description: definition.passive.description,
            ),
            const SizedBox(height: Tokens.space3),
            _AbilityCard(
              label: 'ULTIMATE · ${definition.ultimate.name}',
              description: definition.ultimate.description,
            ),
            const SizedBox(height: Tokens.space6),
            Text('TALENTS', style: text.labelLarge),
            const SizedBox(height: Tokens.space2),
            for (final HeroTalentNode node in definition.talents)
              _TalentRow(
                node: node,
                stars: state.stars,
                chosenKey: state.talentChoices['${node.starRequired}'],
                onChoose: (String key) =>
                    onChooseTalent(node.starRequired, key),
              ),
            const SizedBox(height: Tokens.space6),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: atLevelCap ? null : onLevelUp,
                    child: Text(
                        atLevelCap ? 'LEVEL CAPPED' : 'LEVEL UP  $levelCost🪙'),
                  ),
                ),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: OutlinedButton(
                    onPressed: atMaxStars ? null : onStarUp,
                    child: Text(atMaxStars ? 'MAX ★' : '★ UP  $starCost⧫'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            SizedBox(
              width: double.infinity,
              height: Tokens.primaryCtaHeight,
              child: FilledButton(
                onPressed: equipped ? null : onEquip,
                child: Text(equipped ? 'EQUIPPED' : 'EQUIP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedHeroBody extends StatelessWidget {
  const _LockedHeroBody({
    required this.definition,
    required this.save,
    required this.accent,
    required this.onUnlock,
  });

  final HeroDefinition definition;
  final PlayerSave save;
  final Color accent;
  final VoidCallback onUnlock;

  /// docs/10.12: "A locked hero always tells you how to get it" — never just
  /// a lock icon.
  String get _howToUnlock {
    final HeroUnlock u = definition.unlock;
    return switch (u.kind) {
      HeroUnlockKind.free => u.chapter == null
          ? 'Free from the start.'
          : 'Free on reaching chapter ${u.chapter}.',
      HeroUnlockKind.chapterClear =>
        'Unlocks on clearing chapter ${u.chapter}.',
      HeroUnlockKind.shards => u.source == null
          ? '${u.shardCost} shards to unlock.'
          : '${u.shardCost} shards to unlock — from ${u.source}.',
    };
  }

  bool get _canUnlockNow {
    final HeroUnlock u = definition.unlock;
    return switch (u.kind) {
      HeroUnlockKind.free =>
        u.chapter == null || save.campaign.currentChapter >= u.chapter!,
      HeroUnlockKind.chapterClear => save.campaign.currentChapter > u.chapter!,
      HeroUnlockKind.shards =>
        save.wallet.shardCount(definition.key) >= u.shardCost!,
    };
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final HeroUnlock u = definition.unlock;
    final int have = save.wallet.shardCount(definition.key);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PortraitBox(
                  accent: accent, letter: definition.name[0], locked: true),
              const SizedBox(height: Tokens.space4),
              Text(definition.name, style: text.titleLarge),
              Text(definition.epithet, style: text.bodyMedium),
              const SizedBox(height: Tokens.space4),
              if (u.kind == HeroUnlockKind.shards) ...<Widget>[
                Text('$have / ${u.shardCost} shards', style: text.titleMedium),
                const SizedBox(height: Tokens.space2),
              ],
              Text(_howToUnlock,
                  style: text.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: Tokens.space4),
              SizedBox(
                width: double.infinity,
                height: Tokens.primaryCtaHeight,
                child: FilledButton(
                  onPressed: _canUnlockNow ? onUnlock : null,
                  child: const Text('UNLOCK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitBox extends StatelessWidget {
  const _PortraitBox({
    required this.accent,
    required this.letter,
    this.locked = false,
  });

  final Color accent;
  final String letter;
  final bool locked;

  /// No hero art exists in the asset pipeline yet — a rarity-tinted initial
  /// stands in for it, the same "colour carries the information, not the
  /// missing art" choice [PlaceholderScreen] already makes for its own phase
  /// badge.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: locked ? Tokens.bgRaised : accent.withOpacity(0.25),
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        border: Border.all(color: accent, width: 2),
      ),
      alignment: Alignment.center,
      child: locked
          ? const Icon(Icons.lock_outline, color: Tokens.inkDim)
          : Text(letter, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$label ',
            style: text.labelMedium?.copyWith(color: Tokens.inkDim)),
        Text(value, style: text.titleMedium),
      ],
    );
  }
}

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: text.labelLarge?.copyWith(color: Tokens.accent)),
          const SizedBox(height: Tokens.space1),
          Text(description, style: text.bodyMedium),
        ],
      ),
    );
  }
}

class _TalentRow extends StatelessWidget {
  const _TalentRow({
    required this.node,
    required this.stars,
    required this.chosenKey,
    required this.onChoose,
  });

  final HeroTalentNode node;
  final int stars;
  final String? chosenKey;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool unlocked = stars >= node.starRequired;

    if (!unlocked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
        child: Row(
          children: <Widget>[
            Text('★${node.starRequired}  ', style: text.labelMedium),
            const Icon(Icons.lock_outline, size: 16, color: Tokens.inkDim),
            const SizedBox(width: Tokens.space1),
            Text('unlock at ★${node.starRequired}',
                style: text.bodyMedium?.copyWith(color: Tokens.inkDim)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
      child: Row(
        children: <Widget>[
          Text('★${node.starRequired}  ', style: text.labelMedium),
          for (final HeroTalentBranch b in node.branches)
            Expanded(
              child: InkWell(
                onTap: () => onChoose(b.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Tokens.space1, vertical: Tokens.space1),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        chosenKey == b.key
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color:
                            chosenKey == b.key ? Tokens.accent : Tokens.inkDim,
                      ),
                      const SizedBox(width: Tokens.space1),
                      Flexible(
                        child: Text(b.name,
                            style: text.bodyMedium,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
