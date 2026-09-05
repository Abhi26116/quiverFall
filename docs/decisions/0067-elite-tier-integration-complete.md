# ADR 0067 — Bellweather, The Pale Judge, and Umbral Twin now spawn for real

**Phase** 11
**Date** 2026-09-05
**Status** Resolved. All four Elite/Event bosses (docs/06 §6.2, #13-16)
now have a real-run spawn path, closing the gap ADR 0033 flagged and ADR
0055 first resolved for The Ashen Choir alone.
**Severity** Medium. A real, latent arena/boss-footprint bug was found
and sidestepped along the way — see below.

---

## What was missing

`EliteRoomComposer`'s own doc comment had already named the exact
remaining cost: extend `_builtByGlobalStage` and `BossRoomComposer.spawn`
as each Elite/Event boss got a real fight built (ADR 0055). With
Bellweather, The Pale Judge, and Umbral Twin all built this same day
(ADRs 0064-0066), the entire remaining cost was the one map and three
`switch` arms that comment predicted.

## Placement — spread through the early-to-mid campaign, one exception

Docs/06 states no cadence for this tier (unlike Endless's explicit "every
10 floors"), so each sits at its own chapter's stage 10 — "roughly its
own midpoint," the identical reasoning Ashen Choir's own chapter-3
placement already used. Chapters 3, 5, 7, and 10 were chosen to spread
four rare encounters through the campaign rather than clustering them.

## A real bug found, not invented — and sidestepped, not fixed

The first attempt placed Umbral Twin at chapter 9. `stage_runner_test.
dart`'s own "every chapter completes" test — a realistic bot that walks
to waypoints and fires, not an instant kill — stalled at exactly that
room. Diagnosis, not guesswork: an instant-kill (`_killAll`) cleared the
same room fine, isolating the failure to the realistic bot specifically,
not to any sim logic in `UmbralTwinSystem` itself (which does nothing
per tick at all — ADR 0066).

The actual cause: `corridor_choke` (`assets/data/arenas.json`, eligible
only for chapters 6, 9, and 11) places a wall pillar
(`l:6.0, t:3.9, r:6.6, b:5.1`) directly on the line between its own
left-side spawn points — one sits at exactly `(1.0, 4.5)` — and the
arena's geometric centre, `(8.0, 4.5)`, which is precisely where every
boss in this roster spawns (`BossRoomComposer.spawn`'s own
`arenaWidth/2, arenaHeight/2`). A shot fired from that spawn point
straight at the boss travels along `y = 4.5`, squarely inside the
pillar's own `y: 3.9-5.1` band, and is absorbed by the wall before it
ever arrives. This is a real instance of the exact risk ADR 0021 already
flagged when campaign bosses first started spawning at an arena's own
centre point rather than a bespoke arena: *"arenas were never validated
wall-clear at that specific point for a boss footprint, a real if
likely-rare risk until real boss arenas land."* It has now actually
happened, for the first time, on the first Elite-tier boss placed in one
of `corridor_choke`'s own three eligible chapters.

**Umbral Twin moved to chapter 10 instead** — `corridor_choke` is not
eligible there at all, so the specific failure cannot recur for this
placement. This sidesteps the concrete instance; it does not fix the
general risk. Any campaign or Elite/Event boss landing in chapter 6, 9,
or 11 still risks the identical failure if the room's own RNG happens to
pick `corridor_choke` for that particular seed — Rimefather (chapter 6)
and Skarn (chapter 11) are both already-shipped campaign bosses sitting
in an eligible chapter today. Flagged here for a future, dedicated fix
(either a per-boss bespoke arena, or a filter ruling out arenas whose
own geometry blocks a straight line from every spawn point to centre)
rather than attempted as part of this integration pass.

## Verified end to end

Three new tests (`stage_runner_test.dart`'s own "Elite rooms" group,
mirroring Ashen Choir's own two): chapter 5's stage 10 spawns the real
Bellweather, chapter 7's stage 10 spawns the real Pale Judge, chapter
10's stage 10 spawns the real Umbral Twin — each verified through the
same `advanceToEliteRoom` helper Ashen Choir's own test already
established. The pre-existing "every chapter completes" test (a
realistic bot playing all twelve chapters at stage 10 end to end) is what
actually caught the arena bug, and now passes clean with Umbral Twin at
its corrected chapter.

## Consequences

All four Elite/Event bosses (Ashen Choir, Bellweather, The Pale Judge,
Umbral Twin) now spawn for real in an actual run, alongside all twelve
campaign bosses. What remains for the boss roster: the whole Endless
tier's own spawn-path/floor-depth integration (ADR 0017, unaffected by
this ADR); the general wall-clear-at-boss-footprint risk this ADR
confirmed but did not fix; wiring `Progression.bossKillCounts` into The
Last Warden's own P3; The Last Warden's own P5 sudden-death timeout; and
bespoke boss arenas for the whole roster, which would resolve the
wall-clear risk permanently by construction.
