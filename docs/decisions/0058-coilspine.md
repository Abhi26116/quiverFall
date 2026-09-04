# ADR 0058 — Coilspine: chain-following without a recorded path

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. Coilspine (docs/06 §6.3, Endless Descent boss #18)
is fully built — the third Endless-tier boss in the roster, and the
first genuinely new locomotion pattern this session has built.
**Severity** High. The hardest of the three "smaller" Endless bosses:
nothing in this roster had ever needed a multi-body chain that follows
its own leader, survives losing any segment in any order, and changes
character based on *which* segment died first.

---

## What was missing

docs/06 §6.3, Coilspine: "×85 HP. A 24-segment serpent. Each segment is
individually damageable; destroying segments shortens it and changes its
movement pattern. Killing head-first is fast but enrages it; killing
tail-first is slow but safe. A genuine risk/reward strategy choice with
no correct answer."

## Decision — a live backward scan, not a recorded trail

The obvious implementation of a following chain is a position-history
buffer: record the head's own path, have each segment interpolate along
it some fixed distance behind. That needs new per-segment storage sized
to the longest gap any segment could ever trail by, and a fixed recording
cadence to tune. Instead, every segment, every tick, scans for the
nearest still-alive segment with a smaller ordinal (`bossChildIndex`) and
moves toward it whenever the gap exceeds an authored spacing, halting
once inside it — a chase-with-standoff rather than a replay of a
recorded trail.

**This is what makes segment death free.** A position-history approach
would need to repair a chain's own broken link when a segment in the
middle dies — this system does not, because the scan is live: the tick
after a segment dies, whatever's now the nearest surviving smaller
ordinal is found fresh, with no bookkeeping to update. The segment with
no living leader at all (ordinal 0, or whichever survivor now has the
smallest ordinal once the head is gone) chases the player directly
instead of a leader — "destroying segments... changes its movement
pattern" is this substitution happening live, verified directly: killing
a middle segment and giving its own follower a large starting gap toward
its new (skipped-ahead) leader, the follower is confirmed to actually
close that gap over the following ticks, not sit frozen reaching for a
corpse.

## An invisible accounting primary, the same shape as Cinder Choir's own

There is no single health pool. An untargetable, near-zero-radius primary
— the same "accounting anchor, not a body" shape Cinder Choir's own
invisible primary already established (ADR 0018) — holds a live sum of
every segment still alive as its own `health`, recomputed every tick, so
`BossPhaseSystem`'s generic three-phase machinery needs zero changes to
work against a body that is structurally twenty-four independent
entities rather than one.

## The head-vs-tail choice is a one-way latch, not a live check

The moment ordinal 0 dies while any other segment survives, `comboStep`
(free) latches permanently — checked once per tick, set once, never
cleared. Killing every remaining segment tail-first afterward does not
un-enrage the body; only killing tail-first *from the start*, leaving
the head alive until the very last segment, avoids ever setting the
flag at all. This is the entire mechanical shape of "no correct answer":
a faster clear that trades into a harder finish, against a slower, safer
one — verified directly in both directions, including that the enrage
flag survives every subsequent tail-first kill once set.

## Contact is the whole attack; no separate telegraph

Touching any live segment deals the Thresher's own persistent-aura
anchor (9%, doubled once enraged) on a single cooldown shared across the
whole body — the same "several simultaneous hazards, one shared
cooldown" shape Cinder Choir's tether sweep, Arclight's chain, and The
Loom's own threads all already use. No wind-up is layered on top: the
risk in this fight is entirely positional, staying clear of a moving,
thrashing body, not reading a telegraph.

## A real placement bug caught before it shipped, not by a test

The first draft spawned all 24 segments in a straight line behind the
head at a fixed spacing — for a boss spawned anywhere near the arena's
own edge (or even its centre, since 24 × 0.6u = 14.4u against a 16u-wide
arena), the tail segments landed outside the arena entirely. Caught by
inspection while re-reading the spawn code before writing tests, not by
a failing assertion: fixed by stacking every segment on the centre point
at spawn instead of authoring an initial pose — the chase-with-standoff
behaviour uncoils it into a real trailing train within the first few
ticks regardless, so nothing about the fight is lost by not hand-placing
a starting line.

## Verified end to end

Eight tests: the spawn split (24 independently-healthed segments, the
primary's own health as their live sum); the head genuinely chasing the
player; the whole body uncoiling into a bounded trailing chain rather
than drifting apart; a middle-segment death provably repairing the
follow chain rather than leaving a frozen gap; the room-clear condition
once every segment and the primary are gone; both directions of the
head-vs-tail enrage rule, including the one-way-latch property; and the
shared contact-damage cooldown. One test needed the now-familiar
one-transitional-tick fix (ADR 0023) — checking the enrage flag one tick
too early, before the ordinary death pass had actually reaped the head
segment `CoilspineSystem.update` reads `alive` from.

## Consequences

Three of the four Endless-tier bosses are now built (Mother of Motes,
The Loom, Coilspine). Only The Last Warden (#20) remains — five phases,
by far the largest remaining scope in the whole boss roster: an AI that
reads and applies the player's own live Boon set, a terrain system where
the floor is removed and the player's own fired arrows become solid
platforms, and telemetry-driven boss-echo summons of whichever three
bosses the player has beaten most often.
