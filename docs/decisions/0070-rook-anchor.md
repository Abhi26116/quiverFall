# ADR 0070 — Rook's Anchor: a root that already existed under Frost's name

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. `rookAnchor` leaves `pendingHeroBehaviourWork`.
**Severity** Low. The ledger's own stated reason for staying pending was
itself slightly wrong — corrected by looking closer, not by building
anything.

---

## What was missing

docs/07 §7.3, Rook, T3b: **"Anchor: pulled enemies are rooted 0.6 s."**
`pendingHeroBehaviourWork`'s own comment gave a reason: *"Anchor needs a
per-enemy root/stun timer, which does not exist yet."* That reason was
not accurate — a per-enemy hard stop already existed, just under a
different name.

## Decision — `StatusStore.frozenRemaining` already is a root timer

Frost's own Freeze (`ElementSystem`, `AiSystem._freeze`) already does
exactly what "rooted" asks for: velocity zeroed, any wind-up telegraph
cancelled, the enemy's own state reset — a genuine hard stop, not a slow.
Anchor sets `status.frozenRemaining[target]` directly, in the same spot
Pull's own crit-displacement already lives
(`ProjectileSystem._applyHit`), rather than adding a second, narrower
root primitive: the same "an enemy cannot act" fact, reached the same way
Kade/Sela/Sable's own innate-element grants already set a status
directly without an actual elemental arrow behind it.

**The "never shortens an active effect" rule** (`DrawState.
applyDrawLock`/`applyRoot`'s own rule, reused here) means a genuine Frost
freeze already running is never cut short by Anchor's own briefer 0.6 s —
verified directly.

**A real, if unstated, side effect of the reuse**: `isFrozen` also drives
`ElementTuning.frozenDamageBonus` elsewhere in the pipeline, so a target
Anchor roots is incidentally "frozen" for that bonus's own purposes too,
even though no Frost element was ever applied. Flagged here rather than
built around — the card names only the root, and treating "rooted" as
structurally identical to "frozen" is the entire point of the reuse, not
a bug to route around.

## Verified end to end

Three new tests, in the existing "Pull" group (Anchor is a modifier on
the same crit-pull moment, not a separate mechanic): a crit pull roots
the target for 0.6 s and the target reads as frozen by the same check
Sela's own Frost freeze uses; without Anchor equipped, a crit pull never
roots at all; and a longer Frost freeze already running is never
shortened by a later Anchor proc. All three passed after one test-only
fix — an early draft's own tolerance assumed near-zero travel time
before the check, when the crit's own real flight time lets a pre-set
freeze decay for real before the hit even lands; loosened to a margin
that only needs to rule out Anchor's own smaller number, not pin an
exact figure.

## Consequences

`pendingHeroBehaviourWork` drops from 40 to 39. Rook's own Ultimate
(Singularity) and its two ★5 variants remain pending — a genuinely
different kind of gap, needing a sustained multi-tick field effect
nothing before now has asked of any Ultimate in this roster, not a
primitive that already existed under another name.
