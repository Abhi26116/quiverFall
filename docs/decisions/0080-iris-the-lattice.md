# ADR 0080 — Iris's The Lattice: a guaranteed-max Confluence override, layered not embedded

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Iris's own kit is now complete.
**Severity** Medium. Touches the Confluence path, this game's single most
performance- and correctness-sensitive system — kept safe by adding a
layer on top of it rather than editing it.

---

## What was missing

docs/07 §7.3, Iris's own Ultimate: **"The Lattice: instantly draws a 6-line
web across the arena, persisting 10 s. Every shot through it caps out at
5 Confluence."** T5: *Grand Lattice* (10 lines, 16 s) / *Living Lattice*
(the Lattice follows the player). Her passive (Weave — raised Windline
duration and Confluence cap) was already implemented; only the Ultimate
and its two talents were pending, flagged as needing either "a guaranteed-
max override bolted onto the shared Confluence-detection code every Boon
build depends on, or a genuinely dense criss-crossing web geometry docs/07
does not describe."

## Decision — real, authored geometry, plus a small override that never touches the shared sweep

**The web is authored, not invented from nothing.** Docs/07 gives a line
count and a duration but no actual shape, so — the same kind of call ADR
0011 already made for Ashlin's own nova radius — it is modelled as spokes
radiating from one centre at evenly spaced angles across 180° (6 for the
base Ultimate, 10 for *Grand Lattice*; `count` directions across 180°
gives `count` genuinely distinct lines, not `count / 2` doubled up).
Length reuses `_kadePyreLineLength` ("long enough to reach across the
arena") rather than inventing a second number for the same idea.

**The web is deliberately not a real `WindlineStore` entry.** Nothing else
needs to interact with it as a Windline (no Confluence-through-it needs
Boon composition, no rendering pass needs it drawn as a trail), and
keeping it out of that store means the shared, heavily-optimised
`ConfluenceSystem.sweep()` and `ConfluenceResult` are never touched at
all — the exact code the original note was right to worry about. Instead,
`HeroRuntime.latticeLines` (a flat `Float64List`, `[x0,y0,x1,y1]` per
spoke — the one array-shaped field on that class, because a small fixed
bundle of line endpoints is exactly what a flat buffer is for) holds plain
coordinates, recomputed each tick by `SimWorld._tickIrisLattice` — the
trig lives there, since `ProjectileSystem` deliberately avoids `dart:math`
in its own hot loop (see `_length`'s own doc comment).

**The override itself is a separate pass, run right after the existing
organic sweep, never inside it.** `ProjectileSystem._applyIrisLatticeOverride`
does a plain segment-intersection test between the arrow's own swept path
and each spoke; on any real intersection, it force-sets the arrow's
Confluence stacks to the hero's own current max (whatever `maxConfluenceStacks`
already is — Iris's own raised 5, not a new Iris-specific constant) and
emits the identical `confluenceTriggered` event the organic path already
does, so the guarantee has the same audio-visual feedback a real crossing
would. A no-op the instant an arrow is already at the cap.

**A new, separate intersection test — deliberately not
`ConfluenceSystem.segmentsIntersect`.** That function's own near-parallel
rejection (25°) exists specifically to stop an *organic* trail from
farming Confluence by retracing itself at a shallow angle — a rule about
discouraging a degenerate strategy, not about geometry. The Lattice is the
opposite: a deliberate, authored web the player is *rewarded* for
threading an arrow through at any angle at all. Reusing the angle-gated
function would have silently created dead zones — an arrow travelling
near-parallel to one spoke could fail to register even a true geometric
crossing — breaking the card's own absolute "caps out at 5" promise for
some shots. `_irisLatticeIntersects` is the plain crossing test with no
angle gate, small enough to read and verify on its own.

**Grand Lattice/Living Lattice** are read directly off `hero.has(...)` at
the point they matter — line count and duration at cast time, and whether
the centre re-tracks the player every tick in `_tickIrisLattice` — rather
than stored as a separate mode flag.

## Verified end to end

Six new tests: casting sets a 6-line web at the player's own position for
10 s; a shot whose flight genuinely crosses manually-placed spokes (mid-
arena, clear of the player's own spawn point, since every spoke radiates
from one centre and starting exactly there is a numerically degenerate
case) registers a guaranteed 5-stack `confluenceTriggered` event at
exactly the 5th-stack bonus (3.20), in an arena with zero pre-existing
real Windlines and every autoFire shot travelling a near-parallel path —
proving the 5 stacks come entirely from the override, not incidental
organic crossings; Grand Lattice casts 10 lines for 16 s; Living Lattice
recentres the web on the player after it moves; without that talent the
web stays fixed; and the web's own line count and timer both clear once
its duration elapses.

## Consequences

Iris's entire kit is now implemented — the eleventh hero with nothing
deferred. `pendingHeroBehaviourWork` drops to 13.
