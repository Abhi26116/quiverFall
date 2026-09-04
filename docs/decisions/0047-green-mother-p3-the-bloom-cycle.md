# ADR 0047 — The Green Mother's own P3: the bloom reuses the Weeping Gate's own plate trick

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. The Green Mother now has P1+P2+P3, complete end to
end.
**Severity** Low-medium. The first P3 to reuse a mechanism another boss's
own *P2* introduced earlier this same session (the Weeping Gate's
conditional plate, ADR 0042) rather than reaching back to P1-era
machinery — real evidence the roster's own primitives are accumulating
faster than new P3s can outpace them.

---

## What was missing

docs/06 §8, The Green Mother: P1 (ADR 0028) and P2 (ADR 0040) are both
already built. P3 — "Retracts into a bloom with a 3s window every 8s where
the core is exposed. Everything else is invulnerable. Burst positioning
check."

## Decision — the exact plate trick ADR 0042 already built, cycled on a timer

"Everything else is invulnerable" except a "3s window every 8s" is,
mechanically, the identical shape the Weeping Gate's own P2 conditional
plate already solved: a plate that toggles between fully open and
effectively invulnerable based on a live condition, using `plateHalfArc =
pi` (the whole body, not a frontal arc) and `plateFlatFactor` set to a
tiny positive epsilon rather than a literal zero (`_armourFor` only takes
that branch when it reads greater than zero — read directly from
`ProjectileSystem`'s own source before either boss's plate was built).
The only genuinely new piece is *what drives the toggle*: Weeping Gate's
own plate reacts to a live enemy count; the Green Mother's own reacts to
a plain elapsed-time cycle. A new `_tickBloom`, run every P3 tick,
advances `bossSweepAngle` (free — nothing else in this system touches it)
as the cycle's own elapsed clock, wrapping at the card's own stated 8s,
and sets `plateHealth` to `0` (open) for the first 3s of every cycle and
`maxHealth` (shut) for the remaining 5s.

Since `bossSweepAngle` defaults to zero and nothing before P3 ever
touches it, the very first tick of P3 starts already inside the exposed
window — a fresh transition opens the core immediately rather than making
the player wait out a first shut cycle, the reading that best fits "a 3s
window... where the core is exposed" as the phase's own opening beat.

## Spawning and roots stop; the fight is not frozen

"Retracts" reads as a retreat, not a third offensive layer stacked on top
of P1's spawns and P2's roots — both stop the instant `bossPhase` reaches
2, the same posture this system's own prior "not built yet" placeholder
already took. What changes from that placeholder is everything else: the
bloom cycle itself runs for real, so this is not a frozen phase, just a
defensively narrower one. Any Knitter still alive is left exactly as
before (not despawned — ADR 0027's "an add outlives its summoner"
posture, unrelated to this change).

## Verified end to end

Three new tests, alongside the pre-existing (still valid, now correctly
regrouped under P3 rather than "past P2") spawn/root-stop test: the core
reads open the instant P3 begins; it reads shut once 3s have passed
(computed to the exact tick, 181 ticks at the fixed 1/60s step, one past
the exact 180-tick boundary); and it reads open again once a full 8s
cycle has wrapped (481 ticks, one past the exact 480-tick boundary).

## Consequences

Four of twelve campaign bosses now have a real P1+P2+P3 (Cinder Choir,
Silversong, Thrall of the Nine, the Green Mother). This is the first P3
to reuse a mechanism a *P2* built earlier in this same session rather
than reaching back to older, P1-era machinery — worth checking the whole
roster's own recently-built P2s, not just P1s, before assuming a P3's own
"hard" requirement (an invulnerability window, a conditional gate, a
locked-in number) needs new mechanism. Weeping Gate's own P3 ("all
portals open at once, permanently... 40s survival check while burning the
core") is the next obvious candidate to check against this same plate
trick, inverted.
