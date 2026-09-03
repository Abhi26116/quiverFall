import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';

/// Spends gold and hero shards against a [PlayerSave] to unlock, level up, or
/// star up a hero — docs/04 §4.3 and docs/07's twenty per-hero unlock lines,
/// applied.
///
/// Same shape as `ArrowWorkshop` (`lib/game/arrows/arrow_workshop.dart`):
/// every method is a pure `PlayerSave -> Result<PlayerSave, EconomyError>`
/// function that validates preconditions and returns the whole new save on
/// success, for a caller to apply through
/// `PlayerRepository.mutate`/`mutateAndFlush`.
abstract final class HeroWorkshop {
  /// Unlocks [heroId], per its own [HeroUnlock.kind]:
  ///
  ///  - [HeroUnlockKind.free] — no cost. If [HeroUnlock.chapter] is set (Kade:
  ///    "free at chapter 5 (tutorial grant)"), the hero is granted the moment
  ///    that chapter is *reached* (`currentChapter >= chapter`) — "tutorial
  ///    grant" reads as a gift on arrival, not a reward gated behind clearing
  ///    it, the way [HeroUnlockKind.chapterClear]'s own "clear chapter N"
  ///    phrasing (ADR 0005) is.
  ///  - [HeroUnlockKind.chapterClear] — no cost, once that chapter is
  ///    *cleared* (`currentChapter > chapter`, i.e. the campaign has moved
  ///    past it).
  ///  - [HeroUnlockKind.shards] — costs [HeroUnlock.shardCost] of that hero's
  ///    own shards (`Wallet.heroShards[heroId]`).
  ///
  /// Unlocking always sets `stars = 1` — docs/04 §4.3's "40 to unlock, then
  /// 30/80/180/400/900" prices the unlock itself as star 1
  /// (`Curves.heroStarCost(1)`), and `PlayerSave.initial`'s own starting Wren
  /// (`unlocked: true, stars: 1`) already assumes that pairing.
  static Result<PlayerSave, EconomyError> unlock(
    PlayerSave save,
    HeroCatalogue heroes,
    String heroId, {
    required DateTime now,
  }) {
    final HeroDefinition? def = heroes.byKey(heroId);
    if (def == null) return Err<PlayerSave, EconomyError>(EconomyError.unknownHero(heroId));

    final HeroState existing = save.heroes[heroId] ?? HeroState(heroId: heroId);
    if (existing.unlocked) {
      return Err<PlayerSave, EconomyError>(EconomyError.heroAlreadyUnlocked(heroId));
    }

    switch (def.unlock.kind) {
      case HeroUnlockKind.free:
        final int? chapter = def.unlock.chapter;
        if (chapter != null && save.campaign.currentChapter < chapter) {
          return Err<PlayerSave, EconomyError>(
            EconomyError.chapterNotReached(heroId: heroId, chapter: chapter),
          );
        }
        return Ok<PlayerSave, EconomyError>(_grantUnlock(save, existing, now, shardsCost: 0));

      case HeroUnlockKind.chapterClear:
        final int chapter = def.unlock.chapter!;
        if (save.campaign.currentChapter <= chapter) {
          return Err<PlayerSave, EconomyError>(
            EconomyError.chapterNotCleared(heroId: heroId, chapter: chapter),
          );
        }
        return Ok<PlayerSave, EconomyError>(_grantUnlock(save, existing, now, shardsCost: 0));

      case HeroUnlockKind.shards:
        final int cost = def.unlock.shardCost!;
        final int have = save.wallet.shardCount(heroId);
        if (have < cost) {
          return Err<PlayerSave, EconomyError>(
            EconomyError.insufficientShards(heroId: heroId, need: cost, have: have),
          );
        }
        final PlayerSave spent = save.copyWith(
          wallet: save.wallet.copyWith(
            heroShards: Map<String, int>.of(save.wallet.heroShards)..[heroId] = have - cost,
          ),
        );
        return Ok<PlayerSave, EconomyError>(
          _grantUnlock(spent, existing, now, shardsCost: cost),
        );
    }
  }

  static PlayerSave _grantUnlock(
    PlayerSave save,
    HeroState existing,
    DateTime now, {
    required int shardsCost,
  }) {
    final HeroState newState = existing.copyWith(
      unlocked: true,
      stars: 1,
      shardsSpent: existing.shardsSpent + shardsCost,
      firstUnlockedAt: existing.firstUnlockedAt ?? now,
    );
    return save.copyWith(
      heroes: Map<String, HeroState>.of(save.heroes)..[existing.heroId] = newState,
    );
  }

  /// Advances [heroId] one level, at `Curves.heroLevelCost(level)` gold, up
  /// to the campaign-gated cap `Curves.heroLevelCap(chaptersCleared)` — where
  /// `chaptersCleared` is read as `currentChapter - 1`, the same "chapter N
  /// cleared means the campaign has moved past it" reading [unlock] uses for
  /// [HeroUnlockKind.chapterClear].
  static Result<PlayerSave, EconomyError> levelUp(
    PlayerSave save,
    HeroCatalogue heroes,
    String heroId,
  ) {
    if (heroes.byKey(heroId) == null) {
      return Err<PlayerSave, EconomyError>(EconomyError.unknownHero(heroId));
    }
    final HeroState? state = save.heroes[heroId];
    if (state == null || !state.unlocked) {
      return Err<PlayerSave, EconomyError>(EconomyError.heroNotUnlocked(heroId));
    }

    final int cap = Curves.heroLevelCap(save.campaign.currentChapter - 1);
    if (state.level >= cap) {
      return Err<PlayerSave, EconomyError>(
        EconomyError.heroLevelCapped(heroId: heroId, cap: cap),
      );
    }

    final int cost = Curves.heroLevelCost(state.level).round();
    if (save.wallet.gold < cost) {
      return Err<PlayerSave, EconomyError>(
        EconomyError.insufficientGold(need: cost, have: save.wallet.gold),
      );
    }

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      wallet: save.wallet.copyWith(gold: save.wallet.gold - cost),
      heroes: Map<String, HeroState>.of(save.heroes)
        ..[heroId] = state.copyWith(level: state.level + 1),
    ));
  }

  /// Advances [heroId] one star (up to ★6), at `Curves.heroStarCost` shards
  /// of that hero's own kind.
  static Result<PlayerSave, EconomyError> starUp(
    PlayerSave save,
    HeroCatalogue heroes,
    String heroId,
  ) {
    if (heroes.byKey(heroId) == null) {
      return Err<PlayerSave, EconomyError>(EconomyError.unknownHero(heroId));
    }
    final HeroState? state = save.heroes[heroId];
    if (state == null || !state.unlocked) {
      return Err<PlayerSave, EconomyError>(EconomyError.heroNotUnlocked(heroId));
    }
    if (state.stars >= 6) {
      return Err<PlayerSave, EconomyError>(EconomyError.heroMaxStars(heroId));
    }

    final int nextStar = state.stars + 1;
    final int cost = Curves.heroStarCost(nextStar);
    final int have = save.wallet.shardCount(heroId);
    if (have < cost) {
      return Err<PlayerSave, EconomyError>(
        EconomyError.insufficientShards(heroId: heroId, need: cost, have: have),
      );
    }

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      wallet: save.wallet.copyWith(
        heroShards: Map<String, int>.of(save.wallet.heroShards)..[heroId] = have - cost,
      ),
      heroes: Map<String, HeroState>.of(save.heroes)
        ..[heroId] = state.copyWith(
          stars: nextStar,
          shardsSpent: state.shardsSpent + cost,
        ),
    ));
  }
}
