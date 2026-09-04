# ADR 0052 — Vermillion's own P3: the trail detonates itself, no new tracking needed

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for the sequenced detonation. "Frost arrows
extinguish trail segments" is not built — a known, flagged gap needing
two separate missing primitives, not one.
**Severity** Medium-high. The first "hard" P3 tackled after the user's
own explicit "continue on the hard ones" — and a real, demonstrated
timing bug (not a design gap) caught and fixed before it shipped.

---

## What was missing

docs/06 §5, Vermillion, the Long Burn: P1 (ADR 0025) and P2 (ADR 0037)
are both already built. P3 — "Detonates the entire accumulated trail in
sequence over 6s, creating a moving safe window the player must chase.
Frost arrows extinguish trail segments — a hard elemental counter that
rewards bringing the right tool."

## Decision — the trail already tracks everything needed

The class's own prior doc comment (written when P3 was still deferred)
assumed sequencing the trail would need new tracking. Reading
`HazardStore` closely first showed otherwise: every puddle
`EnemyAttack.dropPuddle` lays already carries `owner: primary`
(`ownerAt`), so "which hazards are mine" is already a live, correct
query — no new storage. And since every segment shares an identical
original lifetime and lay rate, the one with the *least* `remaining` time
left is reliably the *oldest* — a correct lay order falls out of data
that already exists, with nothing to maintain separately.

`_tickP3Detonation` counts however many segments exist the instant P3
begins (`comboStep`, free — nothing else in this system touches it) and
derives a fixed per-segment interval from the card's own 6s total
(`bossLastHitAgo`, also free once P2's own charge cooldown stops reading
it). Every interval, the currently-oldest surviving segment detonates for
the roster's own derived heavy hit (a fifth reuse of `0.09 × 2.10`) and is
released — `HazardStore.release` plus `TelegraphStore.release` on that
segment's own recorded telegraph handle, *not* `EnemyAttack.endTelegraph`
(which only ever tracks one telegraph per owner via `enemies.
telegraphSlot`; `dropPuddle` never used that bookkeeping, since many
puddles already coexist under one owner — confirmed by reading its own
source rather than assuming). "The moving safe window" needed no
separate implementation at all: ground already detonated is gone (safe),
ground not yet reached keeps burning exactly as it always has, so the
boundary between the two visibly sweeps through the original lay order
on its own.

## A real bug: the stale P1 countdown

The first draft initialised `comboStep`/`bossLastHitAgo` (the segment
count and the fixed interval) the instant P3 began, but left `bossTimer`
— the *live* countdown — holding whatever P1's own trail-interval cycle
had left in it. Since P1's own countdown could be anywhere from 1.0s down
to a sliver, the first detonation landed early by however much P1 had
left, not a clean fresh interval. Caught immediately by the second new
test (which asserts nothing detonates inside the first ~1.67s of P3) —
fixed by explicitly resetting `bossTimer` to the freshly-computed
interval in the same branch that computes it, not left to inherit
whatever the previous phase's own use of that field happened to leave
behind.

## What's deliberately not built: Frost extinguishing a segment

This is two missing primitives stacked, not one, and reading the sim
honestly rather than guessing at how big it is: `HazardStore` carries no
element for anything it holds — bolts, shells, puddles alike, a shared
struct every enemy's own ordnance already depends on — *and* nothing in
the sim today lets a player's own arrow collide with a hazard at all;
arrows only ever hit enemies, hazards only ever hit the player. Adding
either is real, separate, wide-blast-radius work this pass does not
attempt — the same disciplined "flag the true size, don't guess" posture
Rimefather's own friction gap (ADR 0038) and the Weeping Gate's own
survival timer (ADR 0048) already took.

## Verified end to end, twice caught by its own tests

Three tests, the last of which caught a real test-authoring mistake, not
just a sim bug: measuring detonation damage by placing the player where
the boss's own final P1 position happened to be (which, unnoticed at
first, was already sitting in the *newest* segment's own ongoing ambient
burn from the setup phase) produced a wrong baseline before the
detonation was ever reached — fixed by moving the player clear and
resetting health explicitly rather than assuming a "default" position was
clean, the same lesson ADR 0039 already learned from a different boss.
With both fixes in, the exact expected number — `100 − 100 × 0.189 =
81.1` — landed on the money.

## Consequences

Nine of twelve campaign bosses now have a real P1+P2+P3 (Cinder Choir,
Silversong, Thrall of the Nine, the Green Mother, the Weeping Gate,
Gaunt, Rimefather, Arclight, Vermillion). Two remain: Hollow Warden
(Discord — still the one idea this roster has no analogue for at all) and
The Quiverfall (Confluence-gated invulnerability, "the only fight that
requires Confluence," now with every other boss's own complete P1-P3
built as reference).
