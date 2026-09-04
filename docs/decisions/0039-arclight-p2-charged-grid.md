# ADR 0039 — Arclight's own P2: no new telegraph shape, and a real test lesson about baselines

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2. P3 (untargetable orbit; four conduits;
Confluence chaining) is not built — a known, flagged gap.
**Severity** Low-Medium. No new sim primitive; a real, worth-recording
test-design lesson about assuming a clean starting baseline when a
mechanic can legitimately fire on its very first tick.

---

## What was missing

docs/06 §7, Arclight: P2: "Charges the arena floor in a grid; alternating
grid cells go live on a 1.5s cycle. Pure pattern-reading." Arclight's own
P1 (ADR 0027) landed as one of this session's own "zero new primitives"
bosses; P2 turned out to be another.

## Decision — a plain checkerboard, checked directly rather than telegraphed

`TelegraphShape` has no notion of a grid, and "pure pattern-reading" reads
as the alternating state itself being the entire tell — an
always-visible, always-known pattern, not something that needs its own
warning window on top. So this is checked directly rather than routed
through the telegraph system at all: an authored grid of 2u cells covers
the arena, `(col + row)` parity decides which half is currently live, and
the live half flips every 1.5s (the card's own stated rate — the third
boss in a row, after Gaunt and Vermillion, to get a real number straight
from its own card). A player standing on a live cell takes the
Thresher-derived anchor on the roster's own established 0.6s tick, the
fifth boss to reuse that exact pair of numbers.

**Chains from P1 keep running unmodified alongside it** — the same
additive framing every other "P2 adds X" card has taken so far.

## Three more free fields, on a primary that already had three spoken for

Arclight's own primary already uses `state`/`stateTimer` (spawn wind-up),
`attackCooldown` (spawn cooldown), and `bossTimer` (chain damage-tick
cooldown). The grid needed three more concerns tracked and found them
without adding a field: `bossLastHitAgo` (free — countdown to the next
flip), `comboStep` (free — the 0/1 parity flag), and `bossSweepAngle`
(free — the grid's own separate damage-tick cooldown, repurposed as a
plain scalar rather than an angle, since this boss never sweeps
anything). Six generic per-boss fields, six different meanings, on one
primary, zero collisions — the pattern this session's ADRs have tracked
since Skarn (0022) still holding at this scale.

## A real test lesson: a mechanic that can fire on tick one breaks a "starts at 100" assumption

The grid's own damage check has no wind-up and no warm-up delay — its
countdown starts at zero, so it can legitimately land a hit on the very
first tick a player happens to be standing on the live parity, *including
a player who never moved there on purpose*. A first draft of "damages a
player standing on a live cell" positioned the player deliberately, then
asserted their health was still exactly 100 before running the damage
window — and failed, because the single tick spent reading the grid's own
current parity had *already* caught the player's own default spawn point
on a live cell and dealt a hit before the test ever repositioned them.
Fixed by measuring relative change (`before` and `after` around the
window under test) instead of assuming a clean starting baseline —
**worth remembering for any mechanic whose own trigger condition has no
warm-up at all**: a "does X happen" test needs a captured baseline taken
after any setup tick that could itself have already triggered X, not an
assumed constant.

A related issue in the same pass: a "past P2" test asserting player
health stays constant over 400 ticks failed because *Swarmlings
themselves* — ordinary, independently-alive enemies with their own
contact damage, unaffected by Arclight's own frozen `bossPhase` — kept
fighting the player the whole time, exactly as ADR 0027 already
documented they should. Fixed by checking the grid's own internal state
(parity, cooldown) staying put instead of raw player health, which
isolates "did the grid stop" from "is anything else in the room still
dangerous" — the latter being correct, expected behaviour, not a bug.

## What's deliberately not built here

**P3 (untargetable orbit; four grounded conduits; Confluence chains
between them, "the first fight where the depth mechanic is dramatically
better without being required")** — already flagged in this boss's own
P1 ADR (0027) as needing a real new multi-target structure, still true.
Once `bossPhase` reaches 2, spawning, chains, and the grid all stop
together.

## Consequences

Five of twelve campaign bosses now have some form of P1+P2 (Gaunt,
Silversong, Vermillion, Rimefather, Arclight). The two testing lessons
here — measure relative change when a mechanic has no warm-up, and check
a mechanic's own internal state rather than player health when other
independent threats share the room — are both worth applying by default
to the remaining P2/P3 builds, not just remembered after the fact.
