# ADR 0016 — Overheal's shield: which heals it catches, and why not all

**Phase** 10
**Date** 2026-09-03
**Status** Resolved.
**Severity** Low. A scope boundary, not a missing number — docs/07 states
Overheal's own cap (30 % max HP) outright.

---

## What was missing

Lira's T3a talent — "Overheal (excess healing becomes a shield up to 30 %
HP)" — needed a player shield that persists past the heal that created it.
The game already has one: `BoonRuntime.shield` (Shieldweave, recomputed
from live Momentum). The question was never "does a shield mechanic
exist" but "which heals does Overheal actually catch."

The honest answer is: not all of them. `lib/game/sim` has exactly two
places that heal the player directly — Lifebound's own lifesteal
(`ProjectileSystem._applyHit`) and Verdant Bloom's regen
(`SimWorld.tick`) — both computing their own max-HP clamp inline, since no
shared heal-clamp helper exists anywhere. A third, much larger surface
exists too: "every BoonSystem regen/shield call." That third surface is
exactly what Thane's own *Tempered* (a healing *cap*, a different
mechanic aimed at the same problem) was left pending over — "it would
need a cap check threaded into every heal source... and 'does a
heal-to-full Boon respect it too' is a design question this card's text
does not answer on its own." Overheal hits the identical breadth problem
from the other direction: an *unaudited* set of Boon effects, none of
which this pass inventoried.

## Decision

**Overheal only catches Lira's own two heal sources — Lifebound's
lifesteal and Verdant Bloom's regen.** Boon-granted healing is out of
scope, for the same reason Tempered's cap was: the BoonSystem regen/shield
surface is broad and unaudited, and extending into it without reading
every Boon that heals is exactly the kind of change that reads correct in
a single-Boon test and quietly misses a case in a twenty-Boon run.

This reading is also the more thematically honest one — "your own
excess healing becomes your own shield" pairs Lira's kit with itself,
the same way every other hero-conditional bonus in this codebase reads
its own hero's own state rather than reaching into the shared Boon pool.

**The shield itself is a second, independent pool** —
`HeroRuntime.overhealShield` — not folded into `BoonRuntime.shield`.
Shieldweave's own pool is *recomputed from live Momentum* and its own
tick-by-tick clamp shrinks it the moment Momentum drops
(`BoonSystem._shield`'s own doc comment: "damage already absorbed stays
absorbed until the stacks that paid for it are re-earned"). Sharing that
pool would mean an unrelated Momentum drop could silently eat shield
Overheal had nothing to do with earning. `EnemyAttack.damagePlayer` now
spends both pools the same way, Shieldweave's first, Overheal's second —
order chosen only to keep the diff against the existing code minimal, not
because either the card text or design intent says one should deplete
before the other.

## Consequences

If a future Boon or hero effect wants its own excess-healing-to-shield
behaviour, `HeroRuntime.overhealShield`'s own doc comment is where to
start reading, not `BoonRuntime.shield` — the two pools exist for
different reasons and should stay that way. Widening Overheal itself to
catch Boon-granted heals is a real future improvement, gated on actually
auditing that surface — this ADR is the record of why that audit did not
happen here.
