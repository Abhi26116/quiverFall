import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_workshop.dart';
import 'package:test/test.dart';

import 'hero_test_support.dart';

/// docs/04 §4.3's hero economy (level cost, star cost) and docs/07's twenty
/// per-hero unlock lines, applied against a [PlayerSave].
void main() {
  late HeroCatalogue heroes;
  final DateTime now = DateTime.utc(2026, 3);

  setUpAll(() {
    heroes = loadHeroes();
  });

  PlayerSave freshSave({int currentChapter = 1}) =>
      PlayerSave.initial(playerId: 'p1', now: now).copyWith(
        campaign: CampaignState(currentChapter: currentChapter),
      );

  group('unlock', () {
    test('wren (free, no chapter gate) already ships unlocked', () {
      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.unlock(freshSave(), heroes, 'wren', now: now);

      expect(result.errorOrNull?.code, 'economy_hero_already_unlocked');
    });

    test('kade (free at chapter 5) succeeds once that chapter is reached',
        () {
      final PlayerSave save = freshSave(currentChapter: 5);

      final PlayerSave updated =
          HeroWorkshop.unlock(save, heroes, 'kade', now: now).valueOrNull!;

      final HeroState state = updated.heroes['kade']!;
      expect(state.unlocked, isTrue);
      expect(state.stars, 1);
      expect(state.shardsSpent, 0); // free — no shard cost
      expect(state.firstUnlockedAt, now);
    });

    test('kade fails before chapter 5 is reached', () {
      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.unlock(freshSave(currentChapter: 4), heroes, 'kade', now: now);

      expect(result.errorOrNull?.code, 'economy_chapter_not_reached');
    });

    test('bram (clear chapter 2) succeeds once chapter 2 is cleared', () {
      final PlayerSave save = freshSave(currentChapter: 3);

      final PlayerSave updated =
          HeroWorkshop.unlock(save, heroes, 'bram', now: now).valueOrNull!;

      expect(updated.heroes['bram']!.unlocked, isTrue);
      expect(updated.heroes['bram']!.stars, 1);
    });

    test('bram fails while still on (not yet past) chapter 2', () {
      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.unlock(freshSave(currentChapter: 2), heroes, 'bram', now: now);

      expect(result.errorOrNull?.code, 'economy_chapter_not_cleared');
    });

    test('nyx (shards) succeeds and deducts exactly the shard cost', () {
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(heroShards: <String, int>{'nyx': 40}),
      );

      final PlayerSave updated =
          HeroWorkshop.unlock(save, heroes, 'nyx', now: now).valueOrNull!;

      expect(updated.wallet.shardCount('nyx'), 0);
      final HeroState state = updated.heroes['nyx']!;
      expect(state.unlocked, isTrue);
      expect(state.stars, 1);
      expect(state.shardsSpent, 40);
    });

    test('nyx fails when shards are insufficient', () {
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(heroShards: <String, int>{'nyx': 10}),
      );

      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.unlock(save, heroes, 'nyx', now: now);

      expect(result.errorOrNull?.code, 'economy_insufficient_shards');
    });

    test('fails for an unknown hero id', () {
      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.unlock(freshSave(), heroes, 'not_a_real_hero', now: now);

      expect(result.errorOrNull?.code, 'economy_unknown_hero');
    });
  });

  group('levelUp', () {
    test('costs Curves.heroLevelCost(level) gold and advances level', () {
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(gold: 100000),
      );

      final PlayerSave updated =
          HeroWorkshop.levelUp(save, heroes, 'wren').valueOrNull!;

      expect(updated.heroes['wren']!.level, 2);
      expect(
        save.wallet.gold - updated.wallet.gold,
        Curves.heroLevelCost(1).round(),
      );
    });

    test('fails when gold is insufficient', () {
      final PlayerSave save = freshSave().copyWith(wallet: const Wallet(gold: 1));

      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.levelUp(save, heroes, 'wren');

      expect(result.errorOrNull?.code, 'economy_insufficient_gold');
    });

    test('fails when the hero is not unlocked', () {
      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.levelUp(freshSave(), heroes, 'nyx');

      expect(result.errorOrNull?.code, 'economy_hero_not_unlocked');
    });

    test('fails for an unknown hero id', () {
      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.levelUp(freshSave(), heroes, 'not_a_real_hero');

      expect(result.errorOrNull?.code, 'economy_unknown_hero');
    });

    test('fails once at the chapter-gated level cap', () {
      // chaptersCleared = currentChapter - 1 = 0 -> cap = heroLevelCap(0) = 8.
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(gold: 999999),
        heroes: <String, HeroState>{
          'wren': const HeroState(heroId: 'wren', unlocked: true, stars: 1, level: 8),
        },
      );

      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.levelUp(save, heroes, 'wren');

      expect(result.errorOrNull?.code, 'economy_hero_level_capped');
    });
  });

  group('starUp', () {
    test('costs Curves.heroStarCost(nextStar) shards and advances stars', () {
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(heroShards: <String, int>{'wren': 1000}),
      );

      final PlayerSave updated =
          HeroWorkshop.starUp(save, heroes, 'wren').valueOrNull!;

      expect(updated.heroes['wren']!.stars, 2);
      expect(
        save.wallet.shardCount('wren') - updated.wallet.shardCount('wren'),
        Curves.heroStarCost(2),
      );
    });

    test('fails when shards are insufficient', () {
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(heroShards: <String, int>{'wren': 1}),
      );

      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.starUp(save, heroes, 'wren');

      expect(result.errorOrNull?.code, 'economy_insufficient_shards');
    });

    test('fails when the hero is not unlocked', () {
      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.starUp(freshSave(), heroes, 'nyx');

      expect(result.errorOrNull?.code, 'economy_hero_not_unlocked');
    });

    test('fails once already at ★6', () {
      final PlayerSave save = freshSave().copyWith(
        wallet: const Wallet(heroShards: <String, int>{'wren': 999999}),
        heroes: <String, HeroState>{
          'wren': const HeroState(heroId: 'wren', unlocked: true, stars: 6),
        },
      );

      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.starUp(save, heroes, 'wren');

      expect(result.errorOrNull?.code, 'economy_hero_max_stars');
    });

    test('fails for an unknown hero id', () {
      final Result<PlayerSave, EconomyError> result =
          HeroWorkshop.starUp(freshSave(), heroes, 'not_a_real_hero');

      expect(result.errorOrNull?.code, 'economy_unknown_hero');
    });
  });
}
