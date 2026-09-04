# ADR 0025 — Vermillion: the trail is just puddles, repeated

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 (bigger aura, charging) and P3 (sequenced
detonation, Frost extinguishing) are not built — a known, flagged gap.
**Severity** Low-Medium. No new sim primitive; a real test bug (not a sim
bug) caught and fixed across two boss test files while building this one.

---

## What was missing

docs/06 §5, Vermillion, the Long Burn (chapter 5): "Leaves a persistent
burning trail; arena floor progressively becomes lethal." Nothing about P1
needed a new primitive — `EnemyAttack.dropPuddle` already exists
specifically to "place a lethal circle that lingers after a while" (every
shell with a linger already uses it, docs/05 §5.4), and "the floor
progressively becomes lethal" is simply many of those calls accumulating as
the boss walks. `VermillionSystem` is a single-body walker
(`Steering.moveToward`, the same primitive Gaunt already uses) that calls
`dropPuddle` on a fixed cadence instead of once.

## Decision — cadence is time-based, sized against the hazard pool's own capacity

Silversong (ADR 0024) anchored its own unstated cooldown to a number the
card itself implied; Vermillion's card gives no cadence hint at all, so this
one is a plainer authored choice: one segment per second while walking.
**The segment lifetime (20 s) was chosen specifically against
`HazardStore`'s own fixed 96-slot capacity** — at one drop/second that
bounds roughly 20 *concurrent* segments rather than the ~65 a full fight's
worth of un-expiring drops would otherwise leave alive, comfortably inside
a pool nothing else is drawing from during a solo boss fight. `dropPuddle`
itself needed no change to support this; only the caller's own numbers
needed picking with the shared pool in mind.

**Damage rate is reused, not invented: `ElementTuning.burnPerSecond`
(4%/s)**, the game's own existing Ember DoT rate — "Tests: Ember" is the
card's own stated lesson, so the trail's own damage is anchored to the
element it already represents rather than a boss-specific number.

## A real test bug found and fixed — not a sim bug

Writing this boss's own "halts once past P1" test (mirroring the one ADR
0023 added for Gaunt) surfaced a flaw in **that Gaunt test itself**: it
placed the player due south of the boss and then asserted `posX` stayed
constant — true for the *entire* test regardless of whether the halt fix
did anything at all, since a boss walking straight south never moves in X
to begin with. The vacuous check happened to still pass, silently proving
nothing. Vermillion's own test used an east-of-centre player instead, which
does exercise the X axis, and it caught something real: `MovementSystem`
still integrates one tick's worth of the velocity `moveToward` set the tick
*before* the phase changed, since `Steering.halt`'s own call only lands
later that same tick, after movement has already been applied for it. This
is correct, expected behaviour given the tick's own fixed system order, not
a bug — but both tests needed to capture their "before" reading *after*
that one transitional tick, not before it, to assert the real invariant
("stays put once halted") instead of a coincidentally-true one. Both
`gaunt_system_test.dart` and `vermillion_system_test.dart` now do this;
Gaunt's own player position was also changed to a diagonal one so its
`posX` check is no longer vacuous either.

## What's deliberately not built here

**P2 (a bigger ignite aura, charging along amber lines) and P3 (detonating
the whole accumulated trail in sequence over 6s; Frost arrows extinguishing
a segment).** P3 especially needs real new work this pass did not attempt:
*tracking* which hazard slots belong to this boss's own trail specifically
(to sequence-detonate them, not just let them expire), and giving a hazard
some notion of its own element so a Frost hit can look it up and remove it
— `HazardStore` carries no element field at all today. Once `bossPhase`
reaches 1, `VermillionSystem` halts and stops laying trail — the same
posture every other boss's own undone phases already take.

**`BossRoomComposer` now maps chapter 5 to `vermillion`** — the fifth
confirmation of ADR 0021's own predicted two-line integration cost.

## Consequences

Five bosses now exist. The next one whose card echoes an existing element
or enemy family (Rimefather/Frost, Arclight/Storm) should be checked
against that family's own existing primitives first, the same way this one
found `dropPuddle` already waiting and Silversong (ADR 0024) found
Draw-lock already waiting — it is looking like the sim's existing roster
already covers more of the boss list than any of them initially assumed.
