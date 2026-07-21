# ADR 0007 — Rook's Pull names no radius for "grouped enemies"

**Phase** 10
**Date** 2026-07-21
**Status** Resolved. Borrows Bram's 1.6 u splash radius as the grouping distance.
**Severity** Medium. Changes how easily Rook's core damage bonus triggers, for every build.

---

## What was found

docs/07-heroes.md §7.3's line for Rook's passive, Pull:

> "Crits pull the target 1.2 u toward the impact point. Grouped enemies take
> +12 % damage each (max +48 %)."

The percentage-per-enemy and the cap are both stated. What "grouped" means —
how close another enemy has to stand to the crit's target to count — is not.
This is a real gap, not a rounding-off of an already-implied number: nothing
elsewhere in docs/07 or docs/08 defines a standing "grouping" or "cluster"
distance for Rook specifically, and the same gap exists for his own T3
Crush (also a per-enemy scaling effect) and for the Ultimate's own "pulling
everything in 6 u to a point" clause, which at least gives a number for the
Ultimate's *pull* radius but not for what counts as "grouped" damage-bonus
purposes on the passive.

## Decision

**Reuse Bram's Heavy Ordnance splash radius — 1.6 u — as Rook's grouping
distance**, rather than inventing an unrelated number. Reasons:

- It is the only other "how close counts as a cluster" radius already
  authored anywhere in the roster (docs/07 §7.1's Bram: "45 % splash in
  1.6 u"), for a card in the same rough design space (area-adjacent, common
  rarity down to epic, both about rewarding the player for finding grouped
  enemies). Reusing an existing, already-shipped number is a smaller bet
  than authoring a new one with no anchor at all.
- 1.2 u (Rook's own pull distance) is too tight to double as the grouping
  radius — it would mean a pulled target only ever "groups" with an enemy
  it nearly touches, which reads as a much weaker card than +48% max implies.
- No design document, balance harness constant, or existing implementation
  suggests a different number; this is a genuinely free choice within "some
  small cluster radius," and 1.6 u is a defensible, already-battle-tested
  one.

## Consequences

- If real playtesting shows Rook's grouping bonus triggering too often or
  too rarely, docs/07 needs an explicit number and this file is the record
  of what shipped in its absence — search for `_rookGroupingRadius` in
  `lib/game/sim/systems/projectile_system.dart`.
- Crush (T3a, "grouped enemies take stacking 5 %/s") reuses the same radius
  for consistency — a hero should not have two different definitions of
  "grouped" depending on which talent is read.
- Singularity's own "pulling everything in 6 u" is a *different*, explicitly
  stated number for a different purpose (the Ultimate's own pull field) and
  is unaffected by this decision.
