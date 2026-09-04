# ADR 0030 — The Weeping Gate: a boss with no attack of its own

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 (Riftborn elite pairs; a live-count-gated
plate) and P3 (all portals open, permanent, 40s survival check) are not
built — a known, flagged gap.
**Severity** Medium. A real interpretation call on an ambiguous card (does
P1 have a plate at all?), a deliberate, honestly-flagged scope cut ("the
full enemy roster" → six representative archetypes), and a genuinely new
"where do I even remember what I decided" problem solved by reading a
value back out of the telegraph store itself.

---

## What was missing

docs/06 §10, The Weeping Gate (chapter 10): "Tests: everything from
chapters 1-9 · Ascension gate." "A stationary arch that never moves and
never directly attacks." P1: "Opens portals spawning waves that escalate
through the full enemy roster." Every boss built so far has had at least
one attack of its own; this is the first whose entire P1 threat is
delegated to ordinary enemies it spawns — closer in spirit to a themed room
than to any prior boss, but still needing `BossPhaseSystem`'s own machinery
and a real HP bar.

## Decision — no plate in P1, read literally

docs/06's own plate line — "The Gate's own plating opens only while fewer
than three enemies are alive" — sits inside the **P2** bullet, not P1's.
Read literally, the plate itself arrives with P2; P1 is a plain, fully
vulnerable body, the same posture every other boss's own undamaging-or-
undefended P1 already takes (Skarn's own attackless P1, Green Mother's own
DPS-race P1). This keeps `BossPhaseSystem`'s generic HP-threshold advance
working completely unmodified — the alternative reading (permanently shut
plate the entire fight until some live-count condition is met) would have
made the Gate's own HP never move at all in P1, and the phase system would
never advance past it. Flagged here as a real interpretation call on an
ambiguous card, not a certainty.

## Decision — "the full enemy roster" is six representative archetypes, not 26

docs/05 names 26 base enemies. Cycling a live spawner through all of them
by name — resolving 26 content indices, choosing which ones are safe to
spawn bare (no elite-only requirements, no family-specific setup) — is a
large content-mapping exercise this pass does not attempt. Instead, **one
archetype per chapter 1-6's own unlock order** (Mote, Swarmling, Wisp,
Bounder, Thresher, Screecher — docs/05's own per-chapter table), each
already a plain enemy with no special spawn-time requirements, escalating
by *widening the pool*, not by increasing spawn rate: every 15s of P1's own
elapsed time (authored — docs/06 gives no cadence at all), the next
archetype in the list joins the pool a spawn may draw from at random. This
is a genuinely narrower reading than "the full roster," honestly flagged
rather than silently substituted.

## Decision — every spawned enemy is a real, ordinary enemy; no attack of the Gate's own exists to write

`EnemySpawner.spawn` places each portal's own arrival exactly the way
Arclight's Swarmlings and Green Mother's Knitters already are (ADR
0027/0028) — a real `contentIndex >= 0` entity running its own family
tree from the instant it exists. `WeepingGateSystem` itself never calls
`EnemyAttack.damagePlayer` anywhere; `weeping_gate_system_test.dart`'s own
"never itself lands a hit" test checks this directly, by source, on every
`playerHit` event across a long run — not just "the player's health didn't
drop," which a spawned Mote's own contact damage would trivially violate
and should.

## A new problem: remembering a choice across a wind-up, without a new field

Every prior add-spawner (Rift Maw, Arclight, Green Mother) places its own
adds in a ring around itself — one radius, one owner position, nothing to
remember. Portals are placed anywhere legal in the arena
(`EnemySpawner.findSpawnPoint`, the same "inside the arena, clear of
walls, far enough from the player" search ordinary wave composition
already uses — reused here for the first time by a boss, rather than
`ringPoint`), which means the wind-up's own telegraph circle and the
enemy that eventually spawns there must agree on *which* point, across the
0.5s gap between choosing it and resolving it. Rather than add a new
per-boss X/Y field, the chosen point is read back out of **the telegraph
itself** at resolve time (`TelegraphStore.xAt`/`yAt`) — a telegraph already
persists an x/y for exactly as long as the wind-up lasts, so nothing new
needed storing at all. The archetype itself is deliberately *not* chosen
until resolve time either, for the same reason: nothing needs to preview
which enemy is coming, so there is nothing to persist for it.

## What's deliberately not built here

**P2 (portals spawn Riftborn elites in pairs; the Gate's own plate opens
only while fewer than three enemies are alive) and P3 (all portals open at
once, permanently; a 40s survival check while burning the core).** P2
needs a genuinely new mechanic — a plate whose state is driven by a live
enemy count rather than a timer or a Draw tier, something no boss has
needed yet. Once `bossPhase` reaches 1, spawning stops and any live
telegraph is cleared — the same posture every other boss's own undone
phases already take. Any already-spawned enemy is not despawned, the same
"an add outlives its summoner" posture Arclight's/Green Mother's own adds
already established — which means, as with those two, the boss room's own
zero-enemies clear condition (ADR 0021) requires clearing them too.

**`BossRoomComposer` now maps chapter 10 to `weepingGate`** — the tenth
confirmation of ADR 0021's own predicted two-line integration cost.

## Consequences

Ten bosses now exist. The first with genuinely no attack of its own is a
useful data point for whatever boss comes next with a similarly delegated
threat model — "read the committed value back out of the telegraph" is a
reusable trick worth checking before adding a new per-boss field any time
a wind-up needs to remember something more than a shape and a target.
