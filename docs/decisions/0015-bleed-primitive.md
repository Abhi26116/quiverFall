# ADR 0015 — Bleed: a fifth DoT, and the two numbers docs/07 leaves out

**Phase** 10
**Date** 2026-09-03
**Status** Resolved — including the Crush follow-up this ADR anticipated.
**Severity** Low. One invented rate, reused from an existing anchor; one
storage-location call with real consequences for what reuses it later.

---

## Update — Rook's Crush landed, reusing this storage as planned

"What this does not do" named exactly the two things Crush needed and
deferred them on purpose; both are now built. Its own trigger is
continuous rather than on-hit: `SimWorld._tickRookCrush` re-evaluates a
few times a second (the same throttled-`spatial.queryRadius` shape
`_tickSableMiasma` already uses — reentrancy-safe because it runs from
`tick()` itself, never from inside `ProjectileSystem`'s own hit-resolution
loop) and *sets* `bleedStacks`/`bleedRemaining` for whichever enemies are
currently grouped, capped at 4 (Pull's own grouping cap). It never reads
or writes `ProjectileSystem`'s private `_countRookGrouped` — a second,
small linear scan over `EntityStore` lives in `world.dart` instead, since
sharing it would have meant `ElementSystem` or `world.dart` reaching into
`ProjectileSystem` for one helper, an awkward cross-system dependency for
what a ~10-line scan avoids entirely.

Unlike Kestrel's own flat refresh, Crush's own card states its rate
outright — "5 %/s" — so `ElementSystem` now picks between Bleed's borrowed
4 %/s and Crush's stated 5 %/s by which hero is equipped, the same
per-hero rate switch Kade's Deep Burn already established for Burn. The
refresh window each recheck sets (twice the recheck interval) is not a
designed grace period — it exists only so `ElementSystem.update`'s own
`-= dt` later the same tick never immediately expires a stack this pass
just set — so a "just left the group" enemy keeps bleeding for a
fraction of a second past its own current true grouped state; nothing in
docs/07 says otherwise, and this is the same "continuous math discretized
into ticks" slack Miasma's own pulse rate already carries.

---

## What was missing

Kestrel's T3b talent — "Bleed (every 4th arrow applies a 3 s bleed)" — was
the first hero effect needing a damage-over-time that is not one of the
four elements. `StatusStore`'s own doc comment is explicit that it models
"four elements, four different shapes of state" — Ember, Frost, Storm,
Toxin — deliberately, and Bleed does not react, does not pair with
Confluence, and touches no `SimElement` at all. Shoehorning it into
`StatusStore` would have made that comment a lie the next reader would have
had to discover for themselves.

Two numbers are also missing outright: docs/07 states Bleed's duration
(3 s) but never a damage rate, and never says whether repeated applications
to the same target stack or just refresh.

## Decisions

**1. Storage: `EnemyStore`, not `StatusStore`.** `EnemyStore` already hosts
exactly this shape of thing — a per-enemy timed status that is not an
element (`markedRemaining`, Vane's own Marked, is the precedent). Bleed's
own two fields (`bleedStacks`, `bleedRemaining`) follow it there. The tick
itself still lives in `ElementSystem.update`, which now takes an optional
`EnemyStore? enemies` — not because Bleed is an element, but because that
system already *is* the shared "apply damage, check death, emit the event,
despawn" routine every DoT in the game needs, and writing a second copy of
it elsewhere would be the real inconsistency.

**2. Rate: Burn's own `ElementTuning.burnPerSecond` (4 %/s of max HP).**
No number is stated anywhere for Bleed, so this reuses the closest existing
anchor — a stacking, duration-based DoT — rather than inventing an
unanchored one. `ElementSystem._bleedPerSecond` records the reasoning at
the constant itself.

**3. Refreshes, doesn't stack — for Kestrel.** "Every 4th arrow applies *a*
bleed" (singular) reads as one DoT effect reapplied, not a stacking one, so
Kestrel's own trigger sets `bleedStacks` to a flat 1 rather than
incrementing it. The field is a stack **count**, not a bool, on purpose:
Rook's own *Crush* ("grouped enemies take stacking 5 %/s") is pending on
this exact same primitive per the hero-behaviour ledger, and when it lands
it can increment the same storage instead of needing a parallel one — this
ADR is what that future work should read first, not rediscover the
storage decision from scratch.

## What this does not do

Rook's Crush is not implemented here. Its own trigger (continuous,
group-proximity-gated, reusing `_countRookGrouped` from Pull) is a
genuinely different shape from Kestrel's (on-hit, every-4th-arrow, tagged
at release) — bundling the two into one pass risked conflating two designs
to save one ADR. `bleedStacks`/`bleedRemaining` and `ElementSystem`'s own
tick block are already shaped to take Crush's own trigger later without
touching either.
