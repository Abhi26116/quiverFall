# ADR 0021 — Wiring a boss room into a real run

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for Cinder Choir. Every other campaign boss falls back
to an ordinary room until its own fight is built — deliberate, not a gap in
this pass.
**Severity** Medium. Two real scope cuts (which arena, which encounter
count) with actual gameplay consequence, alongside the wiring itself.

---

## What was missing

`RoomKind.boss` existed structurally since Phase 8 (`StageBlueprint`'s own
`isBossStage` rule) but nothing read it — `LevelGenerator` composed a boss
slot exactly like a normal room (ADR 0017 already named this gap). With
Cinder Choir's fight fully built (ADR 0018-0020), the framework had a real
boss to spawn and nothing spawning it into an actual run.

## Decision — an empty `RoomPlan`, not a new spawn mechanism

**A boss slot whose chapter has a fight built gets no ordinary composition
at all: `LevelGenerator._assemble` hands it an empty `RoomPlan` (zero
waves).** `SpawnSystem._maybeClearRoom` already fires `roomCleared` on
exactly `allWavesReleased && !hasPending && zero alive enemies` — with an
empty plan, `allWavesReleased` is true from the first tick, so the room's
clear condition reduces to "zero alive enemy-kind entities", which is
*already* the correct definition of "the boss died" once `StageRunner`
spawns Cinder Choir's four entities (the primary plus three effigies) as
`EntityKind.enemy`. **No change to `SpawnSystem` or `SpawnState` was
needed** — the existing wave-clear machinery already expresses "room ends
when its entities do" generically enough to cover a boss with zero actual
waves.

`StageRunner._advance()` reads the new `RoomBlueprint.bossArchetype` (set
by `LevelGenerator`, carried through from `BossRoomComposer.bossFor`) and
calls `BossRoomComposer.spawn` right after `beginRoom` loads the (empty)
plan. `BossRoomComposer` is the one place both facts live — which chapters
have a real fight (`bossFor`) and how to place one (`spawn`, a `switch` on
archetype dispatching to `CinderChoirSystem` today) — so `StageRunner`
itself never needs to know an archetype exists; extending either map when
the next boss lands is the entire integration cost for it.

**Both `BlueprintValidator` and `CompositionValidator` already treat an
empty plan as trivially valid** — every check that could fail is gated on
`enemyCount > 0` or returns early on `totalEnemies == 0` — so a boss room
always succeeds on the generator's first attempt; nothing needed to change
there either.

## Decision — every chapter without a built boss keeps working

**`BossRoomComposer.bossFor(chapter)` is a plain, static map — today just
`{1: cinderChoir}`.** A chapter whose boss is not in it falls straight
through `LevelGenerator._assemble`'s existing ordinary-composition path,
exactly like any other room. This is the identical posture `generateStage`'s
own doc comment already states for Shrine rooms ahead of Phase 13:
"playable rather than a hole in the stage." Extending the map is the whole
job the next boss's own integration needs to do here.

## Two real, deliberate scope cuts

**No bespoke boss arena exists** (ADR 0017's own gap, still open) — the
boss spawns at `(SimConfig.arenaWidth/2, SimConfig.arenaHeight/2)`, the
geometric centre of whichever *ordinary* arena the room slot happened to
draw. Every arena is a fixed 16x9, so that point is stable across all of
them, but arenas were authored for common-enemy encounters, not validated
clear of walls at their own centre for a boss's own triangle footprint —
this is a real, if probably rare in practice, risk of an effigy spawning
inside geometry until dedicated boss arenas are authored.

**`Curves.bossHp`'s own `encounterCount` (repeat-kill scaling, "+6% per
prior kill") is always passed as `0`.** `StageRunner` has no access to
`PlayerSave` — it is pure room/sim orchestration, and threading a save
reference through it to answer "how many times has this player beaten this
boss" is a materially different, larger change than wiring the room itself.
Every kill is scaled as a first kill until that tracking exists.

## Consequences

The next campaign boss's own integration is now a two-line change to
`BossRoomComposer` (one entry in `_builtByChapter`, one `switch` arm in
`spawn`) plus its own `CinderChoirSystem`-shaped fight — everything else in
this ADR (empty-plan composition, `SpawnSystem` reuse, validator
compatibility) is already generic across every future boss. Repeat-kill
scaling and a real boss arena are the two flagged follow-ups; both are
scoped narrowly enough that either can land without touching this wiring
again.

**Update, same day:** confirmed twice more — Skarn (ADR 0022) and Gaunt
(ADR 0023) both landed at exactly this two-line cost, with two genuinely
different fight shapes (a shared pool that never un-shares; no pool-sharing
at all) behind them. Three bosses now spawn for real in an actual run.

**Update, same day:** and a fourth — Silversong (ADR 0024), chapter 3, the
first boss built almost entirely from an existing enemy's own primitive
(the Screecher's own Draw-lock scream) rather than a new one.

**Update, same day:** and a fifth — Vermillion (ADR 0025), chapter 5,
another win for reuse (`EnemyAttack.dropPuddle`, already built for lingering
shell impacts). Also caught a real, vacuously-passing test bug in Gaunt's
own "halts past P1" test while writing Vermillion's equivalent — see ADR
0025's own account.
