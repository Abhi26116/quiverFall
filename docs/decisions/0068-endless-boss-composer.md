# ADR 0068 — Endless Descent bosses: the floor resolver, not the mode

**Phase** 11
**Date** 2026-09-05
**Status** Resolved for what Phase 11 actually owes this tier. The
Endless Descent mode itself remains out of scope — see below.
**Severity** Medium. The scope boundary is the significant part.

---

## What was asked, and what Phase 11 actually owes it

The user asked to continue Endless-tier spawn-path integration — the
same category of work ADR 0055/0067 already did for the Elite/Event
tier. Read literally against docs/06/14, "integrating" the Endless tier
in full means building floor generation, a weekly global seed, Descent
Modifiers every 5 floors, and the Ascension gate that unlocks the mode
at all (docs/14 §14.7). None of that is Phase 11 work:
`docs/20-roadmap.md` places "Ascension: gate, projection screen, reset,
Emberdust tree" at Phase 13 and "Endless Descent with weekly seeds"
explicitly at Phase 17 — both several phases past this session, each
depending on phases (12 through 16) that have not started. Phase 11's
own exit criteria is narrower than the mode: *"All 20 bosses beatable,
all phase transitions correct, every attack telegraphed. Each boss has
a test."* All four Endless bosses already meet that bar (ADRs 0056-0063).

**What Phase 11 can honestly build ahead of the mode**: the same "one
function decides who, one function places them" resolver shape
`BossRoomComposer`/`EliteRoomComposer` already proved twice —
`EndlessBossComposer.bossFor(floor)` and `.spawn(...)` — pure,
deterministic, and completely independent of any floor-generation loop,
save data, or UI. This is exactly the primitive Phase 17's own future
driver will need to call, the identical way `LevelGenerator._assemble`
already calls the other two composers' own resolvers. No game-mode
infrastructure — a floor counter, a seed, a screen — is attempted here.

## The floor pattern is read off each card, not invented

docs/14 §14.7: "Boss every 10 floors." Each of the four cards then gives
its own repeating list: The Loom "Floor 10, 30, 50…" (every 20 from 10);
Coilspine "Floor 20, 60…" (every 40 from 20); Mother of Motes "Floor 40,
80…" (every 40 from 40 — the complementary half of Coilspine's own
cadence, since together every multiple of 20 that is not a multiple of
10-mod-20 is covered); The Last Warden "Floor 100, then every 50." These
four patterns partition every multiple of 10 with one deliberate
overlap: from floor 100 onward, every 50th floor (100, 150, 200…) also
satisfies Coilspine's own "every 40 from 20" rule. The Last Warden's own
check runs first in `bossFor` and wins — "the true final boss"
superseding the ordinary rotation as the descent deepens, resolved by
ordering, not by inventing a fifth exception rule.

## Health reuses an already-built, unused curve

`Curves.endlessHp(floor)` already existed (`enemyHp(240) *
1.09^floor`, docs/14's own stated growth rate) and was unused until now
— the Endless tier's own enemy-HP baseline. `healthFor` composes it with
the boss's own `hpMultiplier` from `bosses.json`, the identical shape
`Curves.bossHp` already uses for a campaign boss (`enemyHp(g) *
multiplier`). `encounterCount` is left at 0, the same deliberate gap
`BossRoomComposer.spawn`'s own doc comment already carries for every
other tier, since none of these composers reads `PlayerSave`.

## A related, honest note on the Elite/Event placements already shipped

docs/06 §6.4's own "boss frequency" line distinguishes an Elite
mini-boss ("every 5 stages from chapter 3") from an Event boss ("one
event boss per week") as two different frequency models — Event bosses
are meant to rotate through a live weekly window (Phase 17's own "event
framework"), not sit at a fixed campaign stage. ADR 0067 placed
Bellweather, The Pale Judge, and Umbral Twin (all tagged `tier: event`)
through the same fixed-stage `EliteRoomComposer` mechanism Ashen Choir
(tagged `tier: elite`) uses, which is a stand-in for a system Phase 17
has not built yet — not the "real" placement docs/06 ultimately
describes. This is the same "playable rather than a hole in the stage"
posture already accepted for other not-yet-built systems in this
codebase, not a new gap; noted here for whoever eventually builds the
real weekly event framework.

## Verified end to end

Nine tests: every non-multiple-of-10 floor (including 0 and negative)
resolves to no boss; the full documented pattern from floor 10 through
200 resolves exactly, including The Last Warden's own three-floor
override; health equals `Curves.endlessHp(floor) * multiplier` exactly,
and grows with floor depth for the same boss; each of the four
archetypes spawns its own real system's primary through `spawn`; and an
archetype outside this tier is not handled. All nine passed on the first
real attempt.

## Consequences

`EndlessBossComposer` is ready for Phase 17's own floor-generation loop
to call. Not attempted here, and tracked for that later phase: the loop
itself, the weekly seed, Descent Modifiers, the Ascension gate, wiring
`Progression.bossKillCounts`/`endlessBestFloor`/`endlessSeasonId` (all
three already exist as dormant save fields) into a real run, and The
Last Warden's own `echoArchetypes` resolution (ADR 0061) — `spawn` leaves
it at its empty default here for the identical reason.
