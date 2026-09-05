import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/game/research/research_catalogue.dart';

/// Spends Insight against a [PlayerSave] to complete a Research Lab item —
/// docs/04 §4.6, applied. Same shape as [SpireWorkshop]/[HeroWorkshop]: a
/// pure `PlayerSave -> Result<PlayerSave, EconomyError>` function.
///
/// Every item is a one-time, permanent unlock (`ResearchState.completedIds`)
/// — unlike the Spire, there is no level or rank to buy repeatedly.
abstract final class ResearchWorkshop {
  /// docs/04 §4.6: "Unlocks at account level 9."
  static const int labUnlockAccountLevel = 9;

  static Result<PlayerSave, EconomyError> unlock(
    PlayerSave save,
    ResearchCatalogue catalogue,
    String researchKey,
  ) {
    final def = catalogue.byKey(researchKey);
    if (def == null) {
      return Err<PlayerSave, EconomyError>(
          EconomyError.unknownResearch(researchKey));
    }

    if (save.profile.accountLevel < labUnlockAccountLevel) {
      return const Err<PlayerSave, EconomyError>(EconomyError.researchLabLocked(
        requiredAccountLevel: labUnlockAccountLevel,
      ));
    }

    if (save.research.completedIds.contains(def.key)) {
      return Err<PlayerSave, EconomyError>(
          EconomyError.researchAlreadyCompleted(def.key));
    }

    if (save.wallet.insight < def.insightCost) {
      return Err<PlayerSave, EconomyError>(EconomyError.insufficientInsight(
        need: def.insightCost,
        have: save.wallet.insight,
      ));
    }

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      wallet: save.wallet.copyWith(
        insight: save.wallet.insight - def.insightCost,
      ),
      research: save.research.copyWith(
        completedIds: <String>{...save.research.completedIds, def.key},
        insightSpent: save.research.insightSpent + def.insightCost,
      ),
    ));
  }
}
