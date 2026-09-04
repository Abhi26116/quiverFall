import 'package:quiverfall/game/content/boss_definition.dart';

/// Which Elite-tier bosses (docs/06 §6.2, #13–16) actually have a fight
/// built, and on which exact stage of the campaign they replace an
/// ordinary Elite room.
///
/// **Why a single `globalStage`, not a chapter.** `BossRoomComposer.bossFor`
/// keys by chapter alone because a campaign boss always sits on that
/// chapter's own stage 20 — one occurrence per chapter, by construction.
/// An Elite room instead exists on *every* non-boss stage from chapter 3
/// onward (`StageBlueprint.eliteIndex`), so keying by chapter would make
/// an Elite-tier boss replace the ordinary Elite pick on every single
/// stage of that chapter — roughly nineteen fights in a row, when the
/// card itself is written as a rare, heavier encounter than the ordinary
/// "one Riftborn plus scraps" Elite room. Keying by the exact
/// `globalStage` instead gives each Elite-tier boss precisely the one
/// occurrence its own rarity implies.
///
/// **The Ashen Choir's own placement is authored, not GDD-stated.**
/// docs/06 gives Endless bosses an explicit cadence ("every 10 floors")
/// but no cadence at all for the Elite/Event tier. Chapter 3, stage 10 is
/// chosen deliberately: chapter 3 is the very first chapter with any
/// Elite room at all (`StageBlueprint.firstEliteChapter`), and stage 10
/// is roughly its own midpoint — "an Elite remix of the very first boss
/// you fought, the first time the game shows you what an Elite room can
/// be," rather than an arbitrary pick. `globalStage` for chapter 3 stage
/// 10 is `(3 − 1) × 20 + 10 = 50`.
///
/// Extend [_builtByGlobalStage] as Umbral Twin, Bellweather, and The Pale
/// Judge (docs/06 #14–16) each get a real fight built — nothing else
/// needs to change to pick one up, the same "one map, everything else
/// generic" shape [BossRoomComposer] already proved twelve times over
/// (ADR 0021) and now a thirteenth. `LevelGenerator._assemble` reads
/// [eliteFor] for any `RoomKind.elite` slot exactly the way it already
/// reads `BossRoomComposer.bossFor` for a `RoomKind.boss` slot, and
/// `StageRunner`'s own spawn call (`BossRoomComposer.spawn`, which this
/// tier also runs through — every Elite-tier archetype is still a
/// [BossArchetype]) needed no changes at all to pick either tier up. See
/// ADR 0055.
abstract final class EliteRoomComposer {
  static const Map<int, BossArchetype> _builtByGlobalStage = <int, BossArchetype>{
    50: BossArchetype.ashenChoir, // chapter 3, stage 10.
  };

  /// The `BossArchetype` that should replace the ordinary Elite pick on
  /// [globalStage], or null if that stage's own Elite room should stay
  /// an ordinary "one Riftborn plus scraps" room.
  static BossArchetype? eliteFor(int globalStage) =>
      _builtByGlobalStage[globalStage];
}
