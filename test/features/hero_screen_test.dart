import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/heroes/presentation/hero_screen.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';

import '../game/hero_test_support.dart';
import 'repository_test_support.dart';

/// docs/10-ui-ux.md §10.12's Hero screen: roster carousel, stats, abilities,
/// talents, and the level-up/star-up/equip actions wired to `HeroWorkshop`.
///
/// Every hero's page shares the same button labels ("LEVEL UP", "★ UP",
/// "EQUIP" …), and `PageView.builder` keeps neighbouring pages built for
/// swipe smoothness — so every find here is scoped to one hero's own page
/// via its `ValueKey(heroKey)` rather than matching text globally, which
/// would otherwise risk matching the same label on an adjacent, off-screen
/// hero.
void main() {
  late HeroCatalogue heroes;

  setUpAll(() {
    heroes = loadHeroes();
  });

  Finder pageOf(String heroKey) => find.byKey(ValueKey<String>(heroKey));
  Finder onPage(String heroKey, Finder matching) =>
      find.descendant(of: pageOf(heroKey), matching: matching);

  PlayerSave startingSave() => PlayerSave.initial(
        playerId: 'p1',
        now: DateTime.utc(2026),
      ).copyWith(
        wallet: const Wallet(
          gold: 100000,
          heroShards: <String, int>{'wren': 1000, 'nyx': 40},
        ),
      );

  Future<PlayerRepository> pumpScreen(
    WidgetTester tester,
    PlayerSave save,
  ) async {
    final PlayerRepository repository = buildTestRepository(save);
    addTearDown(repository.dispose);
    await tester.pumpWidget(MaterialApp(
      home: HeroScreen(repository: repository, heroes: heroes),
    ));
    await tester.pump();
    return repository;
  }

  /// Swipes from the first page to [heroKey]'s page.
  Future<void> swipeTo(WidgetTester tester, String heroKey) async {
    final int index = heroes.all.indexWhere((HeroDefinition h) => h.key == heroKey);
    for (int i = 0; i < index; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }
  }

  /// Scrolls [finder] into view (the detail page is taller than the test
  /// surface), taps it, then pumps past `PlayerRepository`'s 400 ms save
  /// debounce so its `Timer` fires and completes within the test — an
  /// un-flushed one fails the framework's own "no pending timers" invariant
  /// at teardown.
  Future<void> tapAndFlush(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('opens on the equipped hero (Wren), unlocked and shown', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, startingSave());

    expect(onPage('wren', find.text('Wren  ★1')), findsOneWidget);
    expect(onPage('wren', find.text('EQUIPPED')), findsOneWidget);
    expect(onPage('wren', find.textContaining('LEVEL UP')), findsOneWidget);
    expect(onPage('wren', find.textContaining('★ UP')), findsOneWidget);
  });

  testWidgets('LEVEL UP spends gold and advances Wren\'s level', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository = await pumpScreen(tester, startingSave());
    final int goldBefore = repository.save.wallet.gold;

    await tapAndFlush(tester, onPage('wren', find.textContaining('LEVEL UP')));

    expect(repository.save.heroes['wren']!.level, 2);
    expect(repository.save.wallet.gold, lessThan(goldBefore));
  });

  testWidgets('★ UP spends shards and advances Wren\'s stars', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository = await pumpScreen(tester, startingSave());

    await tapAndFlush(tester, onPage('wren', find.textContaining('★ UP')));

    expect(repository.save.heroes['wren']!.stars, 2);
    expect(repository.save.wallet.shardCount('wren'), lessThan(1000));
  });

  testWidgets('a locked hero (Nyx) shows how to unlock, never just a lock icon', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, startingSave());
    await swipeTo(tester, 'nyx');

    expect(onPage('nyx', find.text('Nyx')), findsOneWidget);
    expect(onPage('nyx', find.textContaining('40 shards')), findsWidgets);
    expect(onPage('nyx', find.text('UNLOCK')), findsOneWidget);
  });

  testWidgets('unlocking Nyx (enough shards held) sets her unlocked with ★1', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository = await pumpScreen(tester, startingSave());
    await swipeTo(tester, 'nyx');

    await tapAndFlush(tester, onPage('nyx', find.text('UNLOCK')));

    expect(repository.save.heroes['nyx']!.unlocked, isTrue);
    expect(repository.save.heroes['nyx']!.stars, 1);
  });

  testWidgets('choosing a talent branch at ★1 records the choice', (
    WidgetTester tester,
  ) async {
    final PlayerRepository repository = await pumpScreen(tester, startingSave());

    final HeroTalentNode node = heroes.byKey('wren')!.talents.first;
    expect(node.starRequired, 1); // sanity: the always-unlocked node
    final HeroTalentBranch branch = node.branches.first;

    await tapAndFlush(tester, onPage('wren', find.text(branch.name)));

    expect(repository.save.heroes['wren']!.talentChoices['1'], branch.key);
  });

  testWidgets('EQUIP swaps the equipped hero once unlocked', (
    WidgetTester tester,
  ) async {
    final PlayerSave save = startingSave().copyWith(
      heroes: const <String, HeroState>{
        'wren': HeroState(heroId: 'wren', unlocked: true, stars: 1),
        'bram': HeroState(heroId: 'bram', unlocked: true, stars: 1),
      },
    );
    final PlayerRepository repository = await pumpScreen(tester, save);
    await swipeTo(tester, 'bram');

    expect(onPage('bram', find.text('Bram  ★1')), findsOneWidget);
    await tapAndFlush(tester, onPage('bram', find.text('EQUIP')));

    expect(repository.save.profile.equippedHeroId, 'bram');
  });
}
