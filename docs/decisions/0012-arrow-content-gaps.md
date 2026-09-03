# ADR 0012 — Three arrow-content gaps found wiring up Task 5

**Phase** 10
**Date** 2026-07-21
**Status** Resolved, each independently — see the three decisions below.
**Severity** Low to medium. None change whether an arrow's core promise
holds; each fills in one missing number or count needed to implement it.

---

## 1. Twinfang's spawn offset

docs/08-arrows.md §8.3: "Twinfang — fires 2 arrows on converging paths that
cross at 6 u." The crossing distance is stated. How far apart the two
arrows leave the bow is not — and it cannot be zero: two rays from the
*same* point can never cross again, only spread further apart, so a
"converging then crossing" pair necessarily starts from two distinct
points.

**Decision.** Spawn the two arrows 0.3 u apart, symmetric about the aim
line, each aimed at the point 6 u ahead on the center line. 0.3 u is
Small relative to the crossing distance (a narrow "V" rather than a wide
one, matching "twin fangs" leaving the bow close together) and is not
otherwise anchored to anything in the existing content — a free choice
within "small." Search `_twinfangSpawnOffset` in `lib/game/sim/world.dart`
if playtesting wants a different angle of convergence.

The guarantee itself is granted directly at spawn — both arrows start
with `confluenceStacks = 1` (worth +40 %, `ConfluenceTuning.bonusFor(1)`)
rather than being detected geometrically when the paths actually cross.
This is not a numeric gap to resolve so much as a reliability choice: docs/08
itself computes Twinfang's payoff as "a reliable ×1.4" (1 + 0.40 —
exactly one Confluence stack's own bonus), and granting it unconditionally
is what makes it reliable rather than contingent on an enemy happening to
stand exactly on the crossing point.

## 2. Skimmer and Corvin's shared ricochet primitive

`Arena`'s own doc comment already names the intended shape: "ricochet
normals are trivially correct — which matters because Corvin, Skimmer
arrows, and every Windline that clips a wall depend on reflection behaving
predictably." Building Skimmer's wall/enemy ricochet (docs/08: "ricochets
2× off walls or enemies") is this ADR's second piece — the reflection
primitive itself, plus a target-selection rule for the enemy half docs/08
never states.

**Decision.** Wall ricochet reflects the offending velocity component
against the arena boundary or, for an interior wall, the axis with the
shallower penetration (the standard AABB reflection heuristic — not a
game-balance number, so it needs no anchor). Enemy ricochet redirects
toward the nearest other living enemy the arrow has not yet struck this
flight, the same "nearest, excluding what's already been hit" shape
already used for Torv's Arc chain and Sela's Cascading Nail. Corvin's own
kit stays pending — his own card text asks for the *hero-level* bounce
mechanic (a passive that makes ordinary arrows bounce), not this
arrow-specific one, and still has no enemy-bounce target rule of its
own — but now shares the same reflection code this ADR adds, rather than
needing a second implementation the day it is picked up.

## 3. The 18-entry affix pool is actually 17

docs/08 §8.4 says "Affixes roll from an 18-entry pool," then names exactly
17: Sharpened, Keen, Swift, Wide, Fleet, Weaving, Confluent, Piercing,
Kindled, Rimed, Charged, Blighted, Executioner, Fortune, Threaded,
Resonant, Echoing. Counted twice against the table itself, not against a
guess at what's missing.

**Decision.** Ship the 17 named affixes; treat "18-entry" as the document's
own miscount rather than inventing an 18th affix with no card text at all
to anchor it. If a future GDD pass adds a genuine 18th affix, this file is
the record of why the pool shipped one short of its own stated count.

Rarity draw weights (docs/08 says only "weighted by tier," no numbers) reuse
Boon rarity's own three shared tiers verbatim — `BoonRarity.common.weight`
(0.58), `.rare.weight` (0.27), `.epic.weight` (0.11) — the only
"Common/Rare/Epic draw weight" numbers already balance-considered anywhere
in the game, rather than a fresh, unanchored guess.
