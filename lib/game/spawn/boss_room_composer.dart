import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';

/// Which campaign bosses actually have a fight built, and how to place one.
///
/// docs/06 names all 12 campaign bosses, one per chapter's own stage 20
/// (`StageBlueprint.forStage`'s own `isBossStage` rule) — only Cinder Choir
/// (chapter 1, `CinderChoirSystem`, ADR 0018-0020), Gaunt the Iron Tide
/// (chapter 2, `GauntSystem`, ADR 0023) and Skarn the Unmade (chapter 11,
/// `SkarnSystem`, ADR 0022) have sim code behind them so far. [bossFor] is
/// the single place that fact lives: a chapter with no entry here gets its
/// stage-20 room composed as an ordinary room instead
/// (`LevelGenerator._assemble`), the same "playable rather than a hole in
/// the stage" posture a Shrine slot already gets ahead of Phase 13. Extend
/// the map as each new boss's own fight lands — nothing else needs to
/// change to pick it up (`StageRunner` reads [bossFor] indirectly through
/// `RoomBlueprint.bossArchetype`, never an archetype directly). See ADR 0021.
abstract final class BossRoomComposer {
  static const Map<int, BossArchetype> _builtByChapter = <int, BossArchetype>{
    1: BossArchetype.cinderChoir,
    2: BossArchetype.gauntIronTide,
    11: BossArchetype.skarnUnmade,
  };

  /// The boss chapter [chapter]'s own stage-20 room should spawn, or null if
  /// that chapter's boss has no fight built yet.
  static BossArchetype? bossFor(int chapter) => _builtByChapter[chapter];

  /// Places [archetype]'s boss and returns its primary slot, or -1 if
  /// nothing here knows how to spawn it — which [bossFor] should never
  /// actually let happen, since it only ever returns an archetype this
  /// function also handles.
  ///
  /// Every arena is a fixed `SimConfig.arenaWidth` x `arenaHeight` (16x9), so
  /// the arena's own geometric centre is a stable point across all of them
  /// to spawn at — not a per-arena authored one, since no boss arena exists
  /// yet (ADR 0017's own "no spawn integration" gap) and an ordinary room's
  /// own arena is reused as the fight's venue for now.
  static int spawn(SimWorld world, BossArchetype archetype, double health) {
    return switch (archetype) {
      BossArchetype.cinderChoir => world.spawnCinderChoir(
          SimConfig.arenaWidth / 2,
          SimConfig.arenaHeight / 2,
          health: health,
        ),
      BossArchetype.skarnUnmade => world.spawnSkarn(
          SimConfig.arenaWidth / 2,
          SimConfig.arenaHeight / 2,
          health: health,
        ),
      BossArchetype.gauntIronTide => world.spawnGaunt(
          SimConfig.arenaWidth / 2,
          SimConfig.arenaHeight / 2,
          health: health,
        ),
      _ => -1,
    };
  }
}
