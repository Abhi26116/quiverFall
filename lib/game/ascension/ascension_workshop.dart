import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/balance/curves.dart';

/// docs/04 §4.7 — the whole Ascension cycle: gate, reset, and the Emberdust
/// award. Same shape as every other workshop in this codebase: a pure
/// `PlayerSave -> Result<PlayerSave, EconomyError>` function.
///
/// The Emberdust tree itself (5 branches spending it) is not built here —
/// docs/04 §4.7 gives every branch's own effect and max rank but, unlike
/// the Spire's `Curves.spireNodeCost`, states no per-rank cost formula for
/// spending Emberdust at all. See ADR 0094: this Part is the gate, the
/// reset, and the award only — genuinely all three are fully specified,
/// and the tree is a real, separate open question left for whoever picks
/// it up next.
abstract final class AscensionWorkshop {
  /// docs/04 §4.7: "Available after clearing chapter 10 *and* reaching
  /// account level 40."
  static const int gateChapter = 10;
  static const int gateAccountLevel = 40;

  static Result<PlayerSave, EconomyError> ascend(
    PlayerSave save, {
    required DateTime now,
  }) {
    if (save.campaign.currentChapter <= gateChapter) {
      return const Err<PlayerSave, EconomyError>(
        EconomyError.ascensionChapterNotCleared(chapter: gateChapter),
      );
    }
    if (save.profile.accountLevel < gateAccountLevel) {
      return const Err<PlayerSave, EconomyError>(
        EconomyError.ascensionAccountLevelTooLow(
            requiredLevel: gateAccountLevel),
      );
    }

    // Never resets, and is the *input* to the award below — must be
    // brought up to date with wherever this run left off before computing
    // it, or a second Ascension from a lower chapter than an earlier peak
    // would silently under-pay.
    final int highestChapterEver = save.campaign.currentChapter >
            save.ascension.highestChapterEver
        ? save.campaign.currentChapter
        : save.ascension.highestChapterEver;

    final int emberdust =
        Curves.emberdustFor(highestChapterEver, save.ascension.count);

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      // "All 24 Spire node levels -> 0."
      spire: const SpireState(),
      // "All banked gold -> 0" — every other wallet currency (gems,
      // Insight, Emberdust, materials, hero shards, event tokens) survives,
      // matching docs/04's own explicit "Insight... survives" and the
      // absence of gems/materials/shards from either of its two lists.
      wallet: save.wallet.copyWith(
        gold: 0,
        emberdust: save.wallet.emberdust + emberdust,
      ),
      // "Campaign progress -> chapter 1" reads as *position*, not history —
      // bossesDefeated/bossKillCounts/records/endless progress stay, the
      // same way Marks survive a mastery condition keyed to lifetime totals
      // (e.g. "Defeat all 20 bosses") would otherwise lose its own progress
      // through a cycle Marks are explicitly stated to survive.
      campaign: save.campaign.copyWith(currentChapter: 1, currentStage: 1),
      ascension: save.ascension.copyWith(
        count: save.ascension.count + 1,
        lastAscendedAt: now,
        highestChapterEver: highestChapterEver,
      ),
    ));
  }
}
