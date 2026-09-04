# ADR 0041 — Thrall of the Nine's own P2: simultaneous means synchronised, not independent

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2. P3 ("absorbs all remaining sigils for +25%
damage each") is not built — a known, flagged gap.
**Severity** Medium. A real architectural question (does "two abilities
simultaneously" need two independent timers, or one shared one) resolved
in favour of the simpler, still-faithful reading — no new `EnemyStore`
field needed even here.

---

## What was missing

docs/06 §9, Thrall of the Nine: P2: "Remaining sigils accelerate and the
Thrall uses two abilities simultaneously." Thrall's own P1 (ADR 0029)
already established the nine-sigil round-robin and resolved the card's own
"what are the nine abilities" gap; P2 asks the same rotation to do two
things at once.

## Decision — one shared clock, two telegraph owners

The tempting reading of "simultaneously" is two independently-timed
attacks that could start and resolve at different moments — which would
have needed a second full `state`/`stateTimer`/`attackCooldown` set, and
this roster has no spare per-boss timer fields left duplicable that way
without adding a new `EnemyStore` column, something this session has
avoided everywhere else by finding an existing free field first. The
simpler, equally faithful reading won instead: "simultaneously" means
*synchronised* — both abilities share the exact same wind-up, resolve, and
cooldown, driven by the identical `state`/`stateTimer`/`attackCooldown`
P1 already used on the primary, completely unchanged.

**What genuinely needed solving was the telegraph, not the timing.** "An
enemy owns at most one telegraph at a time" (the constraint every
multi-line boss in this roster already works around) meant the primary
could not own two simultaneous wind-up telegraphs. `_beginWindUp`/
`_resolve` were generalised to take an explicit telegraph *owner*,
separate from the shooting position (always the Thrall's own body, per
P1's own established rule): the first ability keeps using the primary's
own slot exactly as P1 already does, and the second uses that turn's own
second living sigil's slot instead. `comboStep` (free — nothing else on
this boss touches it) holds the second sigil's own ordinal for the turn,
sentinelled by equalling the first sigil's own index when there is no
second (P1, or only one living sigil remains) — no new field, the same
"an existing generic field, repurposed" discipline this session has kept
since Skarn (ADR 0022).

## Verified end to end, not just structurally

A test places the player where the first turn's own cone (sigil 0) and
second ability's own line (sigil 1, since both are selected in the same
fixed order every fresh fight starts with) both independently reach, and
asserts the *exact* resulting health: two separate 9% hits against max
health, 100 − 9 − 9 = 82, not a compounded 100 × 0.91² = 82.81. It matched
on the first run — real confirmation that both abilities fire and resolve
independently, not just that two telegraphs exist.

## "Accelerate" is authored, not derived

The orbit's own angular velocity doubles once P2 begins — docs/06 states
no exact multiplier, so 2x is an authored, flagged choice, the same
category of number as every other unverified rate this session's ADRs
already carry.

## What's deliberately not built here

**P3 ("absorbs all remaining sigils for +25% damage each... a player who
destroyed five sigils fights a fundamentally different, easier phase 3")**
— needs a damage multiplier keyed to however many sigils survived to that
point, real scoped work not attempted here. Once `bossPhase` reaches 2,
the orbit and rotation both freeze and every live telegraph — the
primary's own, and any live second ability's own on a sigil — is cleared,
the same posture every other boss's own undone phase already takes.

## Consequences

Seven of twelve campaign bosses now have some form of P1+P2. The
"synchronised, not independent" reading here is worth checking first the
next time a card says two things happen "simultaneously" or "at once" —
a shared clock with a second telegraph owner is very often enough, and
is considerably cheaper than a genuinely concurrent second state machine.
