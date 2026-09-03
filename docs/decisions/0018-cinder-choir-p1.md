# ADR 0018 — Cinder Choir P1/P2: a shared pool, and the plate reused unmodified

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1/P2. P3 is a different mechanic, not built — see
"What's deliberately not built here."
**Severity** Medium. Real judgment calls with gameplay consequence, not just
missing numbers — the shared-pool primitive especially, since Skarn,
Coilspine and Thrall (docs/06 §6.1) will all read this ADR's reasoning as
precedent.

---

## What was missing

The Cinder Choir (docs/06 §1, chapter 1's boss) is "three linked effigies on
a triangle... only the effigy whose eyes are lit is vulnerable; the other two
are plated like a Husk... Tier III breaks plate. The lit one rotates every
6s (4s in P2)." Nothing in the sim could represent three separate, hittable
bodies that share one health pool — `BossPhaseSystem` (ADR 0017) assumes one
entity's own `health`/`maxHealth` is the boss's real HP, and every existing
enemy takes damage on its own slot.

## Decision — the shared pool

**`EnemyStore.linkedHealthSlot`**: a child points at the entity holding its
real health; -1 (the default) means "my own health is the real one." Both
places damage actually reduces health — `ProjectileSystem._applyHit`'s final
write and `ElementSystem.update`'s DoT tick — follow the link for the health
read/write only. Everything else about a hit (armour resolution, plate wear,
shield absorption, stagger tracking, *Rend*'s shred) stays keyed on the hit
slot itself, because a shared pool with *independent* per-child armour is the
entire point of the mechanic — a plated effigy must still resist by its own
plate, not the primary's.

Built generic against Cinder Choir rather than special-cased to it, on the
theory that a second and third consumer are already named in the same GDD
section: Skarn's 1→2/4 split ("sharing one HP pool"), Coilspine's 24
segments, Thrall's nine sigils. Each of those will still need its own
spawn/rotation logic — `linkedHealthSlot` only answers "which pool", not "how
does this boss use the pattern."

**Two smaller, related fixes landed alongside it, both real bugs a linked
child would otherwise hit immediately:**

- *Cull* (#20) already exempted Riftborn elites from its execute threshold
  ("an execute that worked on Riftborn would delete the roster's mechanics").
  A boss is exempt for the identical reason, more severely: boss HP is a
  `×22`-`×140` multiplier, so a threshold sized for common-enemy HP could
  delete a double-digit percentage of a boss bar in one stray low-roll hit.
  `ProjectileSystem._applyHit` now also checks `!enemies.isBoss(target) &&
  enemies.linkedHealthSlot[target] < 0`.
- Both the Cull check and the Boon-conditional `targetHealthFraction` term
  now read the *linked* slot's health fraction, not the hit child's own
  (meaningless) one — a Boon that reads "how hurt is this enemy" should read
  how hurt the boss actually is.

## Decision — the plate is reused exactly, not rebuilt

"Only the lit effigy is vulnerable... plated like a Husk... Tier III breaks
plate" turned out to already be `ArmourFactor`'s own existing tier switch,
unmodified: Tier III already returns `ArmourFactor.none` (full damage)
against *any* plated target, regardless of how much plate health remains —
so "an impatient player can brute-force it, slowly" was already true of the
existing system the moment an unlit effigy's `plateHealth` was set positive.
No new armour math was needed, only spawning/toggling the existing fields.

**One real deviation from how an ordinary Husk uses that system:**
`plateHalfArc` is set to a full circle (`π`), not the frontal arc every other
plated enemy uses. `_armourFor`'s own doc comment frames the frontal arc as
deliberate — "a hit from behind the plate's arc takes full damage at any
tier... what makes flanking a real alternative to the Draw." But the Cinder
Choir's whole puzzle is *which effigy*, not *which angle*; a flankable unlit
effigy would let a player route around the puzzle entirely by circling
rather than reading the rotation. An unlit effigy is plated from every
direction instead.

**`plateHealthFraction` (0.45, `EnemyTuning`'s own constant for every Husk)
is reused unmodified, applied to the *shared* pool's max health rather than
an individual effigy's.** No boss-specific fraction is stated anywhere in
docs/06, and reusing the existing anchor is the established preference over
inventing one. The consequence is worth stating plainly: at boss scale, 45%
of the *entire* HP bar is a very large plate pool — "brute-force it, slowly"
reads, at this number, as closer to "theoretically possible" than "a
realistic alternate strategy within one ~55s fight." If playtesting ever
wants brute-forcing to be a real in-fight option, this fraction (not the
mechanism) is what to retune.

## What's deliberately not built here

**P3 is not built.** "All three light simultaneously... killing one
permanently removes it" is a different mechanic — independently-killable
bodies, not a shared pool — and needs its own design pass (does the primary's
own health become a sum of three new sub-pools? does the fight end when the
last one dies, or does the primary need its own terminal condition?).
`CinderChoirSystem.update` explicitly stops rotating once `bossPhase` reaches
2 and does nothing further; whatever plate state P1/P2 left behind simply
freezes. The fight is not unwinnable in that state — the still-unplated
effigy stays killable, and Tier III still brute-forces the other two — but it
is not the "frantic finale" the card describes either.

**No tether-sweep hazard (P2's "damaging crimson lines that sweep the arena
at 45°/s").** `HazardStore`/`TelegraphStore` exist and are meant for exactly
this, but a continuously-rotating line hazard is new territory for both
stores (everything today is placed once and expires, not re-angled every
tick) and deserves its own design pass rather than a rushed extension bolted
on to land P1 the same day.

**No arena, no spawn integration, no VFX/audio for the rotation itself** —
all already flagged by ADR 0017 as the next slice, still true here.

## Consequences

The next Cinder Choir slice is P2's tether sweep (the first thing that will
actually test whether `TelegraphStore`/`HazardStore` need a "re-angle a live
one" method or a new shape), then P3's individual-death model — which is also
the first real test of whether `linkedHealthSlot`'s "one pool" assumption
needs a second mode ("N independent pools, same boss") or whether P3 is
better modelled as simply setting `linkedHealthSlot = -1` on all three and
letting them become ordinary, independently-healthed enemies from that point
on. Skarn, Coilspine and Thrall should each re-read this ADR before assuming
`linkedHealthSlot` covers their own shape unmodified — it is proven generic
for "several bodies, one pool", not yet for "a pool that later un-shares."
