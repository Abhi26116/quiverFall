# ADR 0063 — The Last Warden, P5: one hit point, honestly stripped of a timer

**Phase** 11
**Date** 2026-09-05
**Status** Resolved for the mechanically decidable half. The 20s
sudden-death timer's own consequence is explicitly not built. P1-P4
(ADRs 0059-0062) are done — this closes out the fight's own five phases.
**Severity** Medium. The only phase in this whole boss roster whose own
card was flagged, ahead of time, as needing a rule nothing else in the
sim provides.

---

## What was missing

docs/06 §6.3, The Last Warden, P5: **"One HP each. Pure duel — first hit
wins, 20s timer, sudden death."** `boss_definition.dart`'s own doc comment
(quoted in ADR 0059) already anticipated this: P5 "is not a fractional
threshold at all and needs its own end-of-fight rule when that boss is
actually built" — the fourth of `phaseThresholds`'s own four entries only
marks *entry into* P5; everything P5 itself does had to be written fresh.

## Decision — the HP drop is free once made; the timer is not guessed at

The moment the fourth threshold is crossed, `_beginSuddenDeath` sets both
combatants' own `health` to exactly `1.0`, once (`bossSweepAngle`, free —
nothing in P1-P4 touches it — doubles as the one-time latch). **Nothing
further was needed to make "first hit wins" mechanically true.** The
game's own damage model always computes a landed hit as a fraction of
`maxHealth`, never a fixed amount — the player's own arrow against the
Warden's own six-figure max health, or the Warden's own heavy shot
against the player's, are each many times larger than `1.0` the instant
either connects, so any hit already ends the fight outright through the
ordinary death/reap path every other boss and every player death in the
game already uses. This is the same "the existing primitive already
covers it" discovery this session has repeatedly made (Rimefather's own
decoy mirrors, Hollow Warden's own Discord) — a card that reads as a
brand-new win condition turned out to need no new one at all.

**"Pure duel" reads as stripping the one mechanical crutch entirely
within this system's own control.** The Warden's own Momentum damage
reduction (`_tickDamageReduction`, ADR 0059) stops running once
`bossPhase >= 4` — a hit lands in full, not partially refunded. The
player's own Momentum stays exactly as it always works: touching the
player's own core damage-reduction path lives inside `SimWorld`'s own
shared damage pipeline, the same class of change this system has declined
to reach into everywhere else in this fight (ADR 0059's own damage-
reduction section, ADR 0062's own floor section). Stripping only the half
genuinely local to this system is the honest boundary, not a full
"symmetry" this pass cannot safely deliver.

## What stays unbuilt

**The 20s timer, and whatever "sudden death" means if it elapses with no
hit landed, are not built.** No "timer-based win condition" primitive
exists anywhere in the sim — the Weeping Gate's own 40s survival timer
(docs/06 §6.1) is the identical, already-flagged gap, never resolved
either. Deciding the timeout's own consequence (a forced loss, a forced
win, a reset back to a live round) is a genuine game-design question, not
an engineering one this pass should guess at.

## Verified end to end

Four new tests, twenty-five total for this boss: health is left
completely alone before P5; both combatants drop to exactly one hit point
the instant P5 begins, and are never reset again on a later tick even
after being changed; a hit far smaller than any real arrow's own fraction
of the Warden's own max health still ends the fight outright; and the
Warden's own Momentum damage reduction, proven built up to the cap, no
longer refunds anything once P5 begins. All four passed on the first
real attempt.

## Consequences

All five phases of The Last Warden (docs/06 §6.3, Endless Descent boss
#20 — the true final boss) are now built: ADRs 0059-0063. What remains
for this boss, tracked but not attempted here: the 20s sudden-death
timer's own consequence; wiring `Progression.bossKillCounts` into a real
`echoArchetypes` argument at an actual spawn call site (ADR 0061); and
the same Endless-tier spawn-path/floor-depth gating every one of Mother
of Motes, The Loom, and Coilspine is already missing (ADR 0017).
