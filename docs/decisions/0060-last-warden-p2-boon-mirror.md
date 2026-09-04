# ADR 0060 — The Last Warden, P2: mirroring the player's own build, honestly

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2 only. P1 (ADR 0059) is done; P3-P5 remain.
**Severity** Medium. Narrower than P1's own scope, but the one phase in
this whole roster that reads as "port every Boon" if taken literally.

---

## What was missing

docs/06 §6.3, The Last Warden, P2: **"Gains the player's own current Boon
set, mirrored."** Additive on top of P1 (nothing in the card says the
duel stops) — `LastWardenSystem.update` keeps running its own Draw/
Momentum/movement loop unmodified; P2 only changes what the heavy shot's
own damage is once fired.

## Decision — two generic terms, real; everything else, flagged

A literal reading — every one of the roughly 60 Boons' own bespoke effect
reapplied to an enemy body — is a materially larger redesign question
than a single pass can resolve. Most Boons are inseparable from the
player's own *arrow*: pierce-index falloff, ricochet stacking, elemental
application on hit, hit-streak bookkeeping, shot-distance scaling — a
bolt-firing enemy body (`EnemyAttack.fireBolt`, the same primitive the
Hollow Warden's own heavy shot already reuses per ADR 0031) has no
analogue for any of it.

`AiContext.combat` is not a snapshot — it is the exact same live
`CombatModifiers` instance the player's own arrows read on every hit,
already assembled from whatever Boons are currently held. Of its fields,
exactly two are generic enough to reapply as-is, with no player-arrow
context required: `flatDamage` (an unconditional percentage) and a real
`critChance`/`critMultiplier` roll. Both are folded directly into the
heavy shot's own `damage` value at the moment `_fireHeavyShot` creates
it, gated on `bossPhase >= 1`.

**Deliberately not mirrored:** every conditional term in
`CombatModifiers` — `vsWounded`, `vsDying`, `vsAfflicted`, `vsArmoured`,
`perHitStreak`, `perMomentumStack`, `perDistanceUnit`, `armourShredPerHit`,
and the rest. Each would need either a concept the Warden's own single
target (the player) has no reciprocal for, or new bookkeeping this pass
does not attempt. Flagged here, not guessed at — the same posture ADR
0031 and ADR 0038 already established for this roster.

## Why the bonus is baked into `damage`, not `attackBuff`

`EnemyStore.attackBuff` is the sim's own existing generic "boost this
enemy's outgoing damage" hook — `EnemyAttack.damagePlayer` already reads
it for *any* attacker, hazard-sourced or not, so it looked like the
obvious place to write the mirrored bonus. It is not: `AiSystem.update`
unconditionally zeroes every enemy's own `attackBuff` at the start of its
own pass (Chanter auras are meant to be recomputed fresh each tick, not
to persist), and that pass runs *after* every boss system in
`SimWorld.tick`'s own fixed order, including this one — a write there
would be silently discarded before `HazardSystem` ever resolves the bolt
and reads it. Baking the bonus into the hazard's own `damage` field at
the instant it is created sidesteps the ordering question entirely: once
a hazard exists, its own damage is fixed for its whole flight, unaffected
by anything `attackBuff` does afterward.

## Verified end to end

Four new tests, twelve total for this boss: the mirror is absent before
`bossPhase >= 1` (a flat-damage Boon held from the start of the fight has
no effect on P1's own heavy shot); once P2 begins, an active flat-damage
bonus scales the heavy shot's own damage by the exact same factor;
a guaranteed crit (`critChance = 1.0`) multiplies by the player's own
*current* `critMultiplier`, read live rather than assumed; and a zero
crit chance never rolls one, even in P2. All twelve passed on the first
real attempt.

## Consequences

P3 (telemetry-driven echo summons of the three most-defeated bosses), P4
(floor removed, Windline-drawn platforms as terrain) and P5 (one HP each,
20s sudden death) remain entirely unbuilt.
