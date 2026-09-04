# ADR 0034 — Skarn's own P1: closing the session's oldest flagged gap

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. Skarn the Unmade now has a real, damaging attack in
every phase of its own fight — the last campaign boss with an
entirely-undamaging phase.
**Severity** Low. Pure composition of already-established primitives; no
new sim surface area.

---

## What was missing

docs/06 §11, Skarn the Unmade (chapter 11): P1: "Single heavy body, slow,
enormous telegraphs." This was the single oldest open gap from this
session's own boss work — Skarn's P2/P3 (the split, the shared pool, the
neglect-heal pressure mechanic) landed back in ADR 0022, with P1's own
attack explicitly deferred because the fight's own doc-emphasised
centrepiece ("Tests: split attention") lived entirely in the split, not in
P1. With all twelve campaign bosses' own P1s now built and the roster's
own vocabulary of reusable pieces much larger than it was then, this was
worth closing.

## Decision — an ordinary heavy-hit cycle, composed from four already-established pieces

Nothing here is new. "Slow" advance reuses `Steering.moveToward`/
`faceToward` at a speed below Gaunt's own "slow advance" (ADR 0023).
"Enormous telegraphs" reuses the ordinary wind-up/resolve/cooldown cycle
every boss in the roster already runs, just with a wind-up several times
the usual 0.6s baseline and a correspondingly large `beginCircle`/
`playerInCircle` radius — the bigger the tell, literally, the more
"enormous" reads as true rather than as flavour text nothing backs up.

**The damage is derived, not guessed a third time.** Hollow Warden's own
heavy shot (ADR 0031) already established "the Thresher's own 9% anchor,
scaled by Tier III's own 2.10x damage multiplier" as this roster's answer
to "how heavy is a *heavy* hit" — reused verbatim here rather than
inventing an independent number for the second boss that needed the same
concept. Two data points now agree on what "heavy" means numerically
across the whole roster.

## What this does *not* touch

P2/P3 (the split, the shared pool, the neglect-heal pressure) are
untouched — the new slam runs only while `bossPhase == 0`, and the moment
splitting begins, the fight is exactly what ADR 0022 already shipped and
tested. Verified directly: a test forces `bossPhase` to 1 immediately and
confirms zero damage lands from the slam path for the rest of the fight.

## Consequences

Every campaign boss's own P1 now deals real damage to the player in some
form — Skarn was the last one whose entire P1 was a plain, undamaging body.
The "derive from an existing anchor rather than invent a third number"
move used here for damage is worth reusing again the next time a card
calls for something explicitly "heavy" — two derivations from the same
formula is a pattern; a third confirms it.
