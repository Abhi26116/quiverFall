# ADR 0086 — Torv's Conductive Lines: chains genuinely walk the Windline network

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Torv is the fifteenth hero with nothing deferred.
**Severity** Medium-high. Rewrites the base *Arc* passive's own targeting,
not just Conductive Lines itself — the previous nearest-by-distance
behaviour was a deliberate, documented placeholder for exactly this.

---

## What was missing

docs/07 §7.1, Torv's own passive: **"Arc: every 5th arrow chains to 3
additional enemies at 60% damage. Chains travel along live Windlines,
which can extend the chain range enormously — the most mechanically
integrated passive in the roster."** T3a, *Conductive Lines*: **"chains
along Windlines deal +80%."**

The previous implementation's own comment was explicit about the gap:
"querying 'which enemies sit near a live Windline segment' is a
relationship nothing in the sim currently indexes" — chains picked the
plain nearest 3 (or 5) enemies by raw distance, which is a different,
strictly weaker mechanic than the one docs/07 describes as this hero's
own headline feature. Conductive Lines had nothing to reward, because the
base passive never actually produced a "travelled along a Windline" case
to reward.

## Decision — a bounded breadth-first walk over the player's own live Windline network, reusing the existing spatial index

**`_collectTorvChainAlongWindlines` walks segment endpoints outward from
the hit point**, using `SegmentHash` — the same index `ConfluenceSystem`'s
own sweep already relies on — to find live segments near the current
frontier, collecting any living enemy within that enemy's own radius plus
`SimConfig.windlineHitWidth` of a visited segment (the identical tolerance
`AiSystem._applyWindlineSlow` already uses for "is this enemy touching a
Windline"), and adding both of that segment's endpoints to the next
frontier. Only the player's own lines qualify — "an enemy trail must never
buff the player," the identical rule Confluence already enforces for its
own crossings, applied here for the identical reason.

**Not scoped to a single trail.** The walk crosses from one arrow's own
trail onto another wherever they physically meet, which is the literal
reading of "extend the chain range enormously" — a player who has woven a
real lattice can chain across the whole web, not just along one shot's own
path.

**Safe to query `SegmentHash` here.** The constraint that rules out a
nested spatial query inside hit resolution is `SpatialHash`'s own shared
result buffer, still mid-iteration in `_resolveHits` at this point in the
call stack — a completely different index. `SegmentHash`'s own shared
buffer is not at risk either: `_resolveConfluence`'s own use of it, for
this same arrow, has already fully returned (its results consumed inside
`ConfluenceSystem.sweep`) before hit resolution — and by the time a
second arrow's own turn comes around, the first has already finished
using it too. Nothing about this walk is concurrent with anything else
touching the same buffer.

**Bounded, not exhaustive.** `_torvChainMaxSegmentsVisited` (24) caps how
far one trigger will ever walk, regardless of how sprawling the player's
own Windline budget gets (*The Loom*, Boon 75, removes expiry entirely).
`chainCount` itself (3-5) ends the walk far sooner in ordinary play — the
cap only matters for the pathological case of a chain-eligible hit
landing beside an enormous, sparsely-populated lattice.

**Falls back to the previous nearest-by-distance scan** once the network
is exhausted before `chainCount` targets are found, or for a hit with no
Windline nearby at all — the mechanic never worse than it was before,
only better when a Windline is actually there to use.

**Conductive Lines' own +80%** applies only to targets the network walk
itself found, not ones the fallback scan reached — a link the fallback
found did not travel along anything, so it gets nothing extra.

## Verified end to end

Every existing "Arc and Tempest Nock" test still passes unchanged — the
fallback path preserves the old behaviour exactly for the geometry those
tests use. Three new tests: a deliberately placed Windline reaches an
enemy 4.3 u away — farther than three "distractor" enemies also in
range, each reachable only by raw distance, proving the far enemy is
selected *because* of the Windline, not despite the distance difference;
removing that Windline reverts to the plain nearest-by-distance behaviour
for the identical arena; and Conductive Lines raises only the
Windline-found target's own damage by the documented +80%, leaving a
fallback-found target's own damage untouched.

## Consequences

`pendingHeroBehaviourWork` drops to 1: Nyx's *Twin Step*, which needs the
shared single-charge Ultimate meter restructured to support two charges —
an unanswered design question (does charge overflow into the second
charge, or fill it separately? docs/07 does not say), not merely unbuilt,
and deliberately left for its own pass.
