# ADR 0045 — Silversong's own P3: the lock goes ambient

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. Silversong now has P1+P2+P3, complete end to end.
**Severity** Low. The smallest P3 in the roster so far — zero new sim
primitives, and the card's own "must be won at Tier I with maximum
Momentum" turned out to already be a free consequence of a mechanic this
game already had, not a rule that needed writing.

---

## What was missing

docs/06 §3, Silversong: P1 (ADR 0024) and P2 (ADR 0036) are both already
built. P3 — "Permanent Draw-lock. The entire final third must be won at
Tier I with maximum Momentum. The first fight in the game that says *the
other half of the core mechanic is real*."

## Decision — an ambient effect, not a dodgeable one

Every other phase in this fight (and every cone/pillar in the game) is a
telegraphed, positional, dodgeable hazard. "Permanent" reads as something
categorically different: not "the cone fires very fast forever," but an
ambient condition with no telegraph and no position check at all — the
lock is just *true*, everywhere in the room, for the rest of the fight.
Once `bossPhase` reaches 2, the cone stops winding up and no new pillar
grows (any pillar already standing is left in place — harmless, since its
own contact-lock is now redundant with the ambient one, not worth tearing
down); a new `_tickPermanentLock` calls the exact same `DrawState.
applyDrawLock(_drawLockSeconds)` the cone and pillars already call, every
tick, with no telegraph. `applyDrawLock`'s own "refreshes to the longer of
the current remaining and this" rule (the same rule `applyRoot` already
uses, ADR 0026) means a lock re-applied every ~0.0167s tick never has a
gap for the player to notice — mechanically permanent, without a new
"is this boss's own P3 running" flag on `DrawState` itself.

## "Tier I with maximum Momentum" needed no rule of its own

Reading `DrawState.rootRemaining`'s own doc comment (which already
states, of a totally different mechanic, "Momentum still works, which is
precisely why Momentum builds exist as a genuine alternative") pointed at
the answer directly: `applyDrawLock` only ever suppresses **tier
progress** (`drawSeconds` stays frozen at zero while locked —
`DrawSystem.update` already gates that advance behind `!state.
isDrawLocked`), never Momentum accumulation, which is tracked
independently and reacts to movement, not to the Draw at all. A
continuously-refreshed lock and an already-unlocked Momentum system
*are*, together, "Tier I with maximum Momentum" — there was no separate
rule to write for "and Momentum keeps building regardless." This is the
smallest P3 built so far specifically because the card's own two halves
(permanently capped tier, freely available Momentum) turned out to be one
mechanism and its own absence, not two mechanisms.

## Verified end to end

Two new tests replace the old "past P2, nothing happens" placeholder
(itself now describing a phase this ADR makes real, not undone): one
confirms the cone/pillar-growth machinery actually stops while any
already-standing pillar count holds steady; the other places the player
far from both the boss's own body and anywhere a pillar could plausibly
stand, confirms `isDrawLocked` and `drawSeconds == 0` immediately, then
runs 200 more ticks confirming the lock and the Tier I ceiling both hold
— the "anywhere in the room" half of "ambient," not just "eventually
locked while standing near the boss."

## Consequences

Two of twelve campaign bosses now have a real P1+P2+P3 (Cinder Choir, and
now Silversong). The next P3 worth reaching for should be checked against
this same question first: does the card's own "hard" description
(permanent, absorbed, everything invulnerable) actually need new
mechanism, or is it already latent in how an existing system's own
suppression/exemption already works once applied continuously or
absolutely rather than periodically?
