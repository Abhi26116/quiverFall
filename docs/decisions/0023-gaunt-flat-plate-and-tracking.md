# ADR 0023 — Gaunt, the Iron Tide: a flat plate, not a tiered one

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 (the shockwave slam) and P3 (shield drop,
speed, combo) are not built — a known, flagged gap, and a deliberate one:
"Tests: flanking" lives entirely in P1.
**Severity** Medium. One genuinely new primitive (`plateFlatFactor`), one
reused speed anchor, and a real bug this pass found and fixed in the same
sitting rather than shipping.

---

## What was missing

docs/06 §2, Gaunt, the Iron Tide (chapter 2): "A colossal shield-bearer.
Frontal 180° arc takes 5% damage... Slow advance, shield always facing the
player. Rotates 70°/s — beatable by circling." Unlike either boss built
before it, Gaunt is a single body for its whole fight — no split, no shared
pool — so none of Cinder Choir's or Skarn's own primitives applied here at
all. What this boss needed was two things nothing in the sim had yet: a
plate that resists *every* Draw tier equally, and a body whose facing
tracks the player at a capped turn rate rather than snapping or staying
fixed.

## Decision — a flat armour factor, because this boss tests flanking, not the Draw

The existing plate system (`ArmourFactor.plateBlocked`/`platePartial`/
`none`, keyed on Draw tier) is exactly what Cinder Choir's own plate reused
unmodified, because that card explicitly says "Tier III breaks plate."
Gaunt's own card says no such thing — "takes 5% damage", full stop, with no
Tier caveat anywhere in its text, and unlike Cinder Choir ("Tests: the
Draw") this boss's own stated lesson is **flanking**. A shield that a fully
charged Tier III shot could still break through the front of would be
teaching the opposite lesson.

**New: `EnemyStore.plateFlatFactor`.** Zero (the default, meaning "use the
ordinary tiered switch") for every existing plated enemy; `_armourFor`
checks it first and, when set, returns it unconditionally instead of
consulting Draw tier at all. Gaunt sets it to `0.05` at spawn. The arc
check itself — is this hit even inside the plate's facing — is entirely
unchanged; only what happens once a hit is confirmed frontal is different.
This is a small, generic extension (any future enemy wanting a
tier-independent plate gets it for free), not a Gaunt-specific branch
bolted onto a hot, shared function.

**The plate pool is sized to the boss's own max health**, the identical
reasoning ADR 0018 used for Cinder Choir's own plate: since a flat 5%
factor applies at every tier, frontal attrition and the plate's own
"breaking" are the same event mathematically — the plate can never
"shortcut" a kill, only ever track the same damage the boss's real health
already took. Verified directly: a Tier III hit measures within 5% of
`2.10x` a Tier I hit's own damage, not the ~20x swing Cinder Choir's own
tiered plate produces for the identical shot pair (ADR 0018's own numbers).

## Decision — tracking reuses `Steering.faceToward`, nothing new

"Shield always facing the player. Rotates 70°/s" turned out to already be
an existing behaviour-tree primitive: `Steering.faceToward` is the exact
capped-turn-rate helper Husk's own family tree already uses for its own
(unrelated) `EnemyCombat.turnRateDegrees`. `GauntSystem.update` calls it
directly each tick with docs/06's own stated rate — no new steering code,
just a bare boss entity calling an existing helper the way a normal
enemy's own tree would.

**Reused, not invented: `_p1Speed` (1.0 u/s).** docs/06 says "slow advance"
with no number attached. Husk — the base Carapace archetype, the same
family this "colossal shield-bearer" is a heavier variation of — moves at
exactly 1.0 u/s, and its own reuse here follows the same "borrow the
closest existing anchor" posture ADR 0019 and 0022 both already took for
their own unstated numbers.

## A real bug found and fixed before it shipped

The first version of `GauntSystem.update` simply **skipped** calling
`Steering.faceToward`/`moveToward` once `bossPhase >= 1`. `MovementSystem`
still integrates whatever velocity the *last* `moveToward` call set,
though — so a boss that transitioned from P1 to P2 mid-stride would have
kept sliding in a straight line, into a wall, and sat there stuck for the
rest of the fight, since nothing was left to redirect or stop it. Fixed by
calling `Steering.halt` explicitly on that same transition, and caught by a
test that lets the boss move for real first (not from a standing start)
before forcing the phase change — the bug did not reproduce from a fresh
spawn, only from an already-moving one, which is exactly the situation a
real fight would actually hit.

## What's deliberately not built here

**P2's shockwave slam and P3's shield-drop/speed/combo.** Both are real,
separate mechanics this pass did not need to touch the doc-emphasised
lesson ("Tests: flanking"), which is entirely a P1 property. `GauntSystem`
freezes the boss in place — halted, not drifting — the moment `bossPhase`
passes 0, the same "known, flagged, not silently broken" posture Cinder
Choir's and Skarn's own undone phases already took.

**`BossRoomComposer` now maps chapter 2 to `gauntIronTide`** alongside
chapter 1 and chapter 11 — the same two-line integration ADR 0021 predicted
each new boss would cost, confirmed a second time.

## Consequences

Three bosses now exist, in three genuinely different shapes: Cinder Choir
(shared pool, later un-shares), Skarn (shared pool, never un-shares, heals
itself), and Gaunt (no pool-sharing at all, a pure single-body positioning
puzzle). The next boss's own design should be read against whichever of
these three it actually resembles, not assumed to need a new primitive by
default — increasingly, it looks like it won't.
