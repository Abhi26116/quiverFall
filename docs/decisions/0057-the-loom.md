# ADR 0057 — The Loom: threads reuse Silversong's pillars and Hollow Warden's Discord, composed

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. The Loom (docs/06 §6.3, Endless Descent boss #17)
is fully built — the second Endless-tier boss in the roster.
**Severity** Medium. The first Endless boss whose own card names a real
interaction with the player's Windlines, not just a raw spawn cycle.

---

## What was missing

docs/06 §6.3, The Loom: "×75 HP. Weaves a slowly tightening lattice of
crimson threads across the arena; the survivable area shrinks to ~15% by
phase 3. **Player Windlines cut threads.** The purest expression of the
game's mechanic as a survival tool rather than a damage tool."

## Decision — threads are placed hazards; cutting reuses Discord's own geometry

Threads are persistent line hazards, each a placed, untargetable child
entity owning one telegraph — the identical shape Silversong's own
resonance pillars already established (ADR 0036) for a *placed* object
with a one-time wind-up, not a repeating attack cycle. Each spans two
random points on the arena's own perimeter (a woven lattice reads as
room-spanning diagonals, not a regular grid) and is given a deliberately
long telegraph lead (`_threadLifetimeSeconds = 999.0`) so it never
expires on its own — the only way a thread goes away is being cut.

**"Player Windlines cut threads" reuses Hollow Warden's own Discord
crossing-detection exactly** (ADR 0053): `comboStep` (free) holds the
last-seen player-Windline serial, so only segments newer than that
checkpoint are tested each tick against every live thread, the same
incremental "read the store's own serial ordering" trick rather than a
full rescan. A found crossing ends that thread's own telegraph and
despawns its owning child outright — no damage, no detonation, just
removal. This is the one place this ADR deliberately does *not* share
code across the three systems that now all do a parametric segment
crossing (`ConfluenceSystem.segmentsIntersect`, Hollow Warden's own
`_segmentCrossing`, and this boss's own `_segmentsCross`): each is
private to its own file, and none of the three is in a position to
depend on either of the others without a real shared-utility refactor
this pass does not attempt — three small, independent copies of nine
lines of parametric math is a cheaper, safer cost than restructuring
three already-shipped systems to share one.

**No literal "15% of arena area" is computed anywhere.** New threads
accumulate on an escalating cadence across all three phases — the same
"one mechanic, escalating rate" shape Mother of Motes already
established (ADR 0056) — up to an authored cap (24). The card's own
"shrinks to ~15% by phase 3" is a *felt* outcome of how many threads
survive at once against however fast the player is cutting them, not a
number this system directly enforces.

## The boss's own body has no damage-tool half at all

Neither moves nor attacks directly — every bit of this fight's own
threat is the lattice itself. Standing on any live thread deals the
Thresher's own persistent-aura anchor (9%) on a single cooldown shared
across every thread at once (the same shape Cinder Choir's tether sweep
and Arclight's chain both already use for several simultaneous line
hazards), read as literally as the card's own closing line asks: "the
purest expression of the mechanic as a survival tool rather than a
damage tool" — there is no damage-tool half to build here at all.

## Verified end to end, including the exact crossing geometry

Eight tests, the trickiest being the two cutting tests: rather than
placing a player Windline at a pre-computed position (which a randomly-
placed thread would make fragile), the tests read a grown thread's own
committed endpoints back out of its telegraph, then construct a short
player-owned segment through its exact midpoint, perpendicular to its
own direction — a crossing guaranteed by construction regardless of the
thread's own random angle. Both the "removed" and "damage stops" halves
verified, plus the mirror case (an enemy-owned line near the identical
midpoint does *not* cut it), the escalating add rate compared directly
between phases, the cap holding at exactly 24, and the primary's own
death despawning every thread. All eight passed on the first real run.

## Consequences

Two of the four Endless-tier bosses are now built (Mother of Motes,
ADR 0056; The Loom). Two remain: Coilspine (#18, a 24-segment
chain-following body with per-segment destruction changing its own
movement — a genuinely new locomotion pattern nothing in this roster has
built before) and The Last Warden (#20, five phases, by far the largest
remaining scope in the whole boss roster — an AI that reads and applies
the player's own live Boon set, a terrain system where fired arrows
become solid platforms, and telemetry-driven boss-echo summons).
