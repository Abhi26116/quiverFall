import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/spire/spire_catalogue.dart';
import 'package:quiverfall/game/spire/spire_definition.dart';

/// Spends gold and Insight against a [PlayerSave] to level a Spire node, or
/// Insight alone to unlock its next tier gate — docs/04 §4.2, applied.
///
/// Same shape as [HeroWorkshop] (`lib/game/heroes/hero_workshop.dart`):
/// every method is a pure `PlayerSave -> Result<PlayerSave, EconomyError>`
/// function that validates preconditions and returns the whole new save on
/// success, for a caller to apply through
/// `PlayerRepository.mutate`/`mutateAndFlush`.
abstract final class SpireWorkshop {
  /// The tier-gate band a purchase of level [n] (1-based, matching
  /// `Curves.spireNodeCost`'s own convention) needs already unlocked.
  ///
  /// docs/04 §4.2 says "advancing past L20/L40/L60" needs Insight spent —
  /// read as: buying the level that *crosses* a boundary needs that
  /// boundary's own gate already open. Level 20 itself needs nothing; level
  /// 21 (the first level past it) needs the L20 gate. See ADR 0092.
  static int requiredBandFor(int n) {
    if (n > 60) return 60;
    if (n > 40) return 40;
    if (n > 20) return 20;
    return 0;
  }

  /// Levels [nodeId] up by one, at `Curves.spireNodeCost(node.baseCost, n)`
  /// gold, where `n` is the level about to be bought.
  static Result<PlayerSave, EconomyError> levelUp(
    PlayerSave save,
    SpireCatalogue catalogue,
    int nodeId,
  ) {
    final SpireNodeDefinition? node = catalogue.byId(nodeId);
    if (node == null) {
      return Err<PlayerSave, EconomyError>(EconomyError.unknownSpireNode(nodeId));
    }

    if (save.profile.accountLevel < node.wing.unlockAccountLevel) {
      return Err<PlayerSave, EconomyError>(EconomyError.spireWingLocked(
        nodeId: nodeId,
        requiredAccountLevel: node.wing.unlockAccountLevel,
      ));
    }

    final int currentLevel = save.spire.levelOf(nodeId);
    if (currentLevel >= SpireNodeDefinition.maxLevel) {
      return Err<PlayerSave, EconomyError>(EconomyError.spireNodeMaxLevel(nodeId));
    }

    final int nextLevel = currentLevel + 1;
    final int requiredBand = requiredBandFor(nextLevel);
    if (requiredBand > 0 && save.spire.bandOf(nodeId) < requiredBand) {
      return Err<PlayerSave, EconomyError>(EconomyError.spireTierGateLocked(
        nodeId: nodeId,
        requiredBand: requiredBand,
      ));
    }

    final int cost = Curves.spireNodeCost(node.baseCost, nextLevel).round();
    if (save.wallet.gold < cost) {
      return Err<PlayerSave, EconomyError>(
        EconomyError.insufficientGold(need: cost, have: save.wallet.gold),
      );
    }

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      wallet: save.wallet.copyWith(gold: save.wallet.gold - cost),
      spire: save.spire.copyWith(
        nodeLevels: Map<String, int>.of(save.spire.nodeLevels)
          ..['$nodeId'] = nextLevel,
        totalGoldSpent: save.spire.totalGoldSpent + cost,
      ),
    ));
  }

  /// Unlocks [nodeId]'s next tier gate (20 -> 40 -> 60), at the fixed
  /// Insight cost docs/02 §2.11 and docs/04 §4.2 both state: 25 / 90 / 300
  /// for the L20 / L40 / L60 gate respectively. Bands must be unlocked in
  /// order — there is no way to buy L60 while L40 is still closed.
  static Result<PlayerSave, EconomyError> unlockTierBand(
    PlayerSave save,
    SpireCatalogue catalogue,
    int nodeId,
    int band,
  ) {
    if (catalogue.byId(nodeId) == null) {
      return Err<PlayerSave, EconomyError>(EconomyError.unknownSpireNode(nodeId));
    }
    if (band != 20 && band != 40 && band != 60) {
      return Err<PlayerSave, EconomyError>(EconomyError.spireTierBandOutOfOrder(
        nodeId: nodeId,
        band: band,
        currentBand: save.spire.bandOf(nodeId),
      ));
    }

    final int currentBand = save.spire.bandOf(nodeId);
    if (currentBand >= band) {
      return Err<PlayerSave, EconomyError>(EconomyError.spireTierBandAlreadyUnlocked(
        nodeId: nodeId,
        band: band,
      ));
    }
    final int expectedPrevious = band - 20;
    if (currentBand != expectedPrevious) {
      return Err<PlayerSave, EconomyError>(EconomyError.spireTierBandOutOfOrder(
        nodeId: nodeId,
        band: band,
        currentBand: currentBand,
      ));
    }

    final int cost = tierGateInsightCost(band);
    if (save.wallet.insight < cost) {
      return Err<PlayerSave, EconomyError>(
        EconomyError.insufficientInsight(need: cost, have: save.wallet.insight),
      );
    }

    return Ok<PlayerSave, EconomyError>(save.copyWith(
      wallet: save.wallet.copyWith(insight: save.wallet.insight - cost),
      spire: save.spire.copyWith(
        tierGatesUnlocked: Map<String, int>.of(save.spire.tierGatesUnlocked)
          ..['$nodeId'] = band,
      ),
    ));
  }

  /// docs/02 §2.11 / docs/04 §4.2's own fixed table — public so a UI can
  /// show the price before a player taps, not just validate it after.
  static int tierGateInsightCost(int band) => _tierGateInsightCost[band]!;

  static const Map<int, int> _tierGateInsightCost = <int, int>{
    20: 25,
    40: 90,
    60: 300,
  };
}
