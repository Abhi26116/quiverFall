# ADR 0048 — The Weeping Gate's own P3: several portals, one honest gap

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for the escalated spawn pressure. The 40s
survival-check *timer* itself is not built — a known, flagged gap, the
first genuinely new sim category this session's own P3 sweep has run
into.
**Severity** Medium. The escalation itself reused an established pattern
cleanly; the survival-check half is the first honest "this needs a new
room-clear category, not attempted here" scope cut since the P2 sweep's
own Hollow Warden/Quiverfall gaps.

---

## What was missing

docs/06 §10, The Weeping Gate: P1 (ADR 0030) and P2 (ADR 0042) are both
already built. P3 — "All portals open at once, permanently. Survival
check for 40 s while burning the core."

## Decision — several simultaneous portal children, the Silversong shape

P1/P2's own portal is a single cycle living entirely on the primary's own
`state`/`stateTimer`/`attackCooldown`/`telegraphSlot` — one portal warns,
spawns, cools down, repeats. "All portals open at once" cannot be that
same cycle sped up; it needs several *independent, concurrent* wind-up/
spawn/cooldown cycles, and "an enemy owns at most one telegraph at a
time" means that needs several separate owning entities. `_spawnP3Portals`
places three (authored — docs/06 states no exact count; "several,
simultaneous" is the reading that actually escalates past P2's own single
portal spawning pairs, not a wash) untargetable portal-anchor children the
instant P3 begins — the same placed-object shape Silversong's own
resonance pillars already established (ADR 0036), idempotent by a cheap
scan for an existing child rather than a separate one-time latch field.
Each child runs the *exact* wind-up→spawn→cooldown loop P1's own portal
already used, just on that child's own slot instead of the primary's, so
three fire independently and simultaneously rather than taking turns.
Cadence is authored faster than P2's own single-portal 4.0s (2.0s per
child, three children) — three portals every two seconds is a real,
measurable escalation over two Riftborn every four, not merely more
entities doing the same total amount of work.

**The plate stays forced open**, unchanged from the system's own prior
placeholder — "burning the core" already meant the core has to stay
hittable throughout, and no boss's own plate anywhere in this roster has
ever needed to be shut while the fight is still meant to be winnable.

## A real room-clear bug caught before it existed, not after

P1/P2's own "children" are ordinary, targetable Riftborn/roster enemies
that correctly outlive their summoner (Arclight's/Green Mother's own
established posture) — this system never needed a primary-death cleanup
before, because nothing untargetable was ever spawned. P3's own portal
anchors *are* untargetable accounting children, the same class of entity
that has already caused two real room-clear bugs this session (The
Quiverfall's spoke anchors, ADR 0032; Silversong's pillars, ADR 0036) —
so a `_despawnP3Portals` guard on the primary's own death check was added
alongside the feature itself, written and tested from the start rather
than discovered by a failing "the room can still clear" test written
after the fact.

## What's deliberately not built: the survival-check timer itself

"Survival check for 40s while burning the core" describes a **timer-based
win condition** — outlast a clock, rather than reduce the primary's own
health to zero. Nothing in the sim has ever had one: every boss fight so
far ends exclusively through the HP-based room-clear path ADR 0021
established (zero alive enemies, driven by the primary's own health
reaching zero). Adding a second, timer-driven win category is real,
separate level-design/sim integration work — where does the 40s clock
start, what happens if the player is still fighting normal HP-based
combat when it expires, does "burning the core" mean player damage output
also gates the timer somehow — none of which docs/06 resolves, and none
of which this pass attempts. The escalated spawn pressure this ADR
builds is real and playable without it; what's missing is only the
enforced 40-second framing the card's own wording promises.

## Verified end to end

Four tests: the primary's own single-portal cycle confirmed permanently
stopped (its own `telegraphSlot` never returns); three portal children
confirmed placed with distinct ordinals; several *distinct* spawner slots
confirmed among what actually spawns over 200 ticks (not just one working
portal happening to fire enough times to look like several); and the
primary's own death confirmed to despawn every portal child, the same
"write the death test first" discipline ADR 0032 established.

## Consequences

Five of twelve campaign bosses now have a real P1+P2+P3 (Cinder Choir,
Silversong, Thrall of the Nine, the Green Mother, the Weeping Gate). This
is the first P3 this session's own sweep has had to split into "the real
mechanic, built" and "a genuinely new sim category, honestly deferred" —
worth checking whichever P3 comes next for the same split before assuming
a card's own single sentence is one piece of work rather than two.
