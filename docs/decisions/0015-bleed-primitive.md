# ADR 0015 — Bleed: a fifth DoT, and the two numbers docs/07 leaves out

**Phase** 10
**Date** 2026-09-03
**Status** Resolved.
**Severity** Low. One invented rate, reused from an existing anchor; one
storage-location call with real consequences for what reuses it later.

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
