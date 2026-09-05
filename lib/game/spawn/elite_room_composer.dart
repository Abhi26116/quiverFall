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
/// All four Elite/Event bosses (docs/06 #13-16) now have a fight built and
/// a placement here — nothing else needed to change to pick each one up,
/// the same "one map, everything else generic" shape [BossRoomComposer]
/// already proved twelve times over (ADR 0021) and now four more.
/// `LevelGenerator._assemble` reads [eliteFor] for any `RoomKind.elite`
/// slot exactly the way it already reads `BossRoomComposer.bossFor` for a
/// `RoomKind.boss` slot, and `StageRunner`'s own spawn call
/// (`BossRoomComposer.spawn`, which this tier also runs through — every
/// Elite-tier archetype is still a [BossArchetype]) needed no changes at
/// all to pick any of them up.
///
/// **Bellweather, The Pale Judge, and Umbral Twin's own placements are
/// authored the identical way Ashen Choir's own was** (ADR 0055): docs/06
/// states no cadence for this tier, so each sits at its own chapter's
/// stage 10 — "roughly its own midpoint" — spread through the
/// early-to-mid campaign (3, 5, 7, 10) rather than clustering in one
/// place. Every stage from chapter 3 onward already carries an ordinary
/// Elite room slot (`StageBlueprint.eliteIndex`, unconditional past
/// `firstEliteChapter`), so any stage number here is a valid pick — stage
/// 10 is a choice for evenness, not a structural requirement the way a
/// campaign boss's own stage 20 is.
///
/// **Umbral Twin sits at chapter 10, not chapter 9** — chapter 9 is
/// deliberately skipped. `corridor_choke` (`assets/data/arenas.json`,
/// chapters 6/9/11 only) places a wall pillar directly on the line
/// between its own left-side spawn points and the arena's geometric
/// centre, exactly where every boss spawns (`BossRoomComposer.spawn`'s
/// own `arenaWidth/2, arenaHeight/2`) — a real instance of the "arenas
/// were never validated wall-clear at a boss's own footprint" risk ADR
/// 0021 already flagged, not a defect in Umbral Twin's own sim code
/// (confirmed directly: an instant-kill clears the room fine; only a
/// realistic bot standing at that arena's own y=4.5 spawn point, firing
/// straight at a boss dead centre, has its every shot absorbed by the
/// pillar first). Landing a boss in any of chapters 6/9/11 risks the
/// identical failure for whichever arena the room's own RNG happens to
/// pick — sidestepped here by choosing a chapter `corridor_choke` is not
/// eligible for, not by fixing the general risk, which remains open. See
/// ADR 0067.
abstract final class EliteRoomComposer {
  static const Map<int, BossArchetype> _builtByGlobalStage = <int, BossArchetype>{
    50: BossArchetype.ashenChoir, // chapter 3, stage 10.
    90: BossArchetype.bellweather, // chapter 5, stage 10.
    130: BossArchetype.paleJudge, // chapter 7, stage 10.
    190: BossArchetype.umbralTwin, // chapter 10, stage 10.
  };

  /// The `BossArchetype` that should replace the ordinary Elite pick on
  /// [globalStage], or null if that stage's own Elite room should stay
  /// an ordinary "one Riftborn plus scraps" room.
  static BossArchetype? eliteFor(int globalStage) =>
      _builtByGlobalStage[globalStage];
}
