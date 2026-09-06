import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';

/// Applies a finished run's outcome to a [PlayerSave] — the one piece
/// nothing in this codebase calls yet. `GameScreen`'s own build method
/// renders `SizedBox.shrink()` for both `StageStatus.complete` and
/// `.failed` today; without this, a cleared stage's gold, campaign
/// advance, and Ascension's own peak tracking (ADR 0094's own dependency)
/// never reach the save at all — a player could clear chapter 1 forever
/// and chapter 2 would never unlock. See ADR 0096.
///
/// Deliberately the smallest version of this that is genuinely correct:
/// gold, campaign position, and — since ADR 0097 — the campaign bosses
/// defeated along the way. Per-stage records/stars, material rewards, Elite
/// and Endless boss tracking, and what happens once a player clears chapter
/// 12 (docs/14's own Endless Descent transition, not a chapter 13 that does
/// not exist) are all real, separate follow-ons, not attempted here — see
/// ADR 0096's own Consequences and ADR 0097's.
abstract final class CampaignProgressWorkshop {
  /// Call once, the first tick `runner.status` reads
  /// [StageStatus.complete] or [StageStatus.failed] — mirrors the exact
  /// "call once, on the state change" contract `StageRunner.update` itself
  /// already documents for advancing rooms.
  static PlayerSave apply(PlayerSave save, StageRunner runner) {
    assert(
      runner.status == StageStatus.complete ||
          runner.status == StageStatus.failed,
      'CampaignProgressWorkshop.apply is only meaningful once a run has '
      'actually ended',
    );

    final int chapter = runner.plan.blueprint.chapter;
    final int stage = runner.plan.blueprint.stage;
    final double gold = runner.finalGold;

    CampaignState campaign = save.campaign;
    // Only the player's own current frontier advances it — replaying an
    // already-cleared stage (farming gold, say) must not regress or
    // duplicate campaign position.
    if (runner.status == StageStatus.complete &&
        chapter == save.campaign.currentChapter &&
        stage == save.campaign.currentStage) {
      final (int nextChapter, int nextStage) = _next(chapter, stage);
      campaign =
          campaign.copyWith(currentChapter: nextChapter, currentStage: nextStage);
    }

    // Never resets, and is the Emberdust award's own input (ADR 0094) — has
    // to stay current with real progress, not just the act of ascending.
    final int highestChapterEver = chapter > save.ascension.highestChapterEver
        ? chapter
        : save.ascension.highestChapterEver;

    // Mark of the Choir's own condition ("defeat all 20 bosses") — the
    // campaign-boss slice of it. `bossArchetype` is only ever non-null on a
    // real fight's own room (`BossRoomComposer.bossFor` found one for this
    // chapter); a chapter with no fight built yet, or an ordinary
    // fallback room, leaves this untouched. See ADR 0097 for why Elite and
    // Endless bosses are not counted here.
    if (runner.status == StageStatus.complete &&
        runner.room.kind == RoomKind.boss &&
        runner.room.bossArchetype != null) {
      final String key = runner.room.bossArchetype!.name;
      campaign = campaign.copyWith(
        bossesDefeated: <String>{...campaign.bossesDefeated, key},
        bossKillCounts: <String, int>{
          ...campaign.bossKillCounts,
          key: (campaign.bossKillCounts[key] ?? 0) + 1,
        },
      );
    }

    return save.copyWith(
      wallet: save.wallet.copyWith(gold: save.wallet.gold + gold.round()),
      campaign: campaign,
      ascension:
          save.ascension.copyWith(highestChapterEver: highestChapterEver),
    );
  }

  /// The campaign's own last authored chapter and stage — advancing past
  /// this is docs/14's own Endless Descent transition, not more numbered
  /// campaign content, so this clamps here rather than manufacturing a
  /// chapter that does not exist.
  static const int _lastChapter = 12;

  static (int, int) _next(int chapter, int stage) {
    if (chapter >= _lastChapter && stage >= StageBlueprint.stagesPerChapter) {
      return (chapter, stage);
    }
    if (stage < StageBlueprint.stagesPerChapter) return (chapter, stage + 1);
    return (chapter + 1, 1);
  }
}
