# ADR 0036 — Silversong's own P2: a placed object needs its own wind-up field

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2. P3 ("Permanent Draw-lock... the entire final
third must be won at Tier I with maximum Momentum") is not built — a known,
flagged gap.
**Severity** Medium. A real, new shape (a one-time-placed hazard with its
own brief wind-up, distinct from a repeating attack cycle) and another
proactively-caught room-clear bug, the same class ADR 0032 already found
for The Quiverfall.

---

## What was missing

docs/06 §3, Silversong: P2: "Adds standing crimson resonance pillars that
Draw-lock on contact; the safe floor shrinks." Silversong's own P1 (ADR
0024) was one of the earliest bosses built this session.

## Decision — "adds," read literally: the cone keeps running

P2's own wording is additive, not a replacement — the cone scream from P1
keeps cycling unmodified, and pillars accumulate on top of it. The two
mechanics don't interact at all; they simply coexist, each ticked every
frame P2 is active.

## Decision — a pillar owns its own wind-up field, because the primary's own is already spoken for

Every prior boss's "wind up, then resolve" cycle lived on a single body's
own `state`/`stateTimer` — the attacker and the thing winding up were
always the same entity. A resonance pillar breaks that assumption: it is
a *placed object*, not a repeating attack, and Silversong's own primary
already spends `state`/`stateTimer` on the cone's own cycle for the
entire fight. Solution: each pillar is its own real child entity
(`bossParent`/`bossChildIndex`), and *it* owns a one-time
wind-up-then-solidify cycle on *its own* `state`/`stateTimer` — free,
since nothing else has ever run on a pillar's own slot. Placement reuses
`EnemySpawner.findSpawnPoint` (the Weeping Gate's own "anywhere legal in
the arena" search, ADR 0030) for the first time by a boss that isn't
spawning ordinary adds — the exact same search works for placing an inert
hazard just as well as an enemy.

**Draw-lock on contact reuses the cone's own 2.5s number outright** —
`ctx.playerDraw?.applyDrawLock(_drawLockSeconds)`, the identical call P1's
own resolve already makes. The effect is the same effect; inventing a
second lock duration for it would only have made the two mechanics harder
to reason about together for no reason docs/06 gives.

## A second room-clear bug, caught the same way the first one was

Exactly the class ADR 0032 already found and fixed for The Quiverfall's
own spoke anchors: pillars are untargetable and have no death condition of
their own. The first draft of this system never despawned them when the
primary died — left alone, any pillar already standing would sit alive
forever, and the boss room's own "zero alive enemies" clear condition
(ADR 0021) would never fire. Caught by writing "the primary's own death
despawns every pillar" against the first draft (as expected, it failed);
fixed with the identical `_despawnChildren` guard every other multi-body
boss's own primary-health check already carries. **Worth stating plainly:
any boss whose P2/P3 adds a child entity of any kind needs this check —
it is not automatic, and the fastest way to find a missing one is to write
the death test before moving on, not after.**

## Decision — freezing P2 also freezes already-placed pillars

Once `bossPhase` reaches 2 (P3, not built), both the cone and *every
already-solidified pillar* stop mattering — a pillar standing in the
arena no longer applies its own lock, even though it is a physically
placed object rather than an active timer. This was a real choice, not
the only reasonable one: a placed hazard arguably "shouldn't care" that an
internal phase counter advanced. Chosen anyway for consistency with every
other boss's own uniform "the whole mechanic freezes, not just the parts
mid-cycle" contract, and to avoid a half-built P3 inheriting live pillar
hazards nothing has designed for yet.

## What's deliberately not built here

**P3 ("Permanent Draw-lock. The entire final third must be won at Tier I
with maximum Momentum")** — a genuinely different mechanic (an unconditional,
un-liftable lock rather than a repeating timed one) that would need its own
new `DrawState` affordance (nothing currently distinguishes "locked, will
expire" from "locked, permanently"), not attempted here.

## Consequences

Two campaign bosses (Silversong, and Gaunt from ADR 0035) now have
complete P1+P2 fights. The "give a placed object its own wind-up field
rather than reusing the primary's" pattern here is worth checking first
the next time a card describes something *placed* rather than *attacked
with* — Weeping Gate's own portals already hinted at this shape but never
needed a solidify step; this is the first boss where "still forming" and
"already there" are two meaningfully different states worth tracking
separately.
