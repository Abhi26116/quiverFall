# ADR 0075 — Ovrin's Aegis Pin: a reflect-damage primitive, and Thorns' free fix

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Ovrin's own kit is now complete.
**Severity** Medium. A new primitive (`EnemyAttack._reflectDamageToAttacker`)
reused immediately to fix an unrelated, previously-invisible dead Boon.

---

## What was missing

docs/07 §7.3, Ovrin the Bulwark's Ultimate: **"Aegis Pin: plants a shield
wall that blocks all enemy projectiles for 6 s and reflects 30 % of blocked
damage as Storm."** T3b *Riposte*: "breaking a shield deals 200 % AoE." T5:
*Long Wall* (10 s) / *Mirror Wall* (100 % reflect, 3 s). His own passive
(+55 % max HP, a per-Momentum shield) and the two other T1/T3 talents were
already done — both are plain `StatChannel`s reusing Shieldweave's own
mechanism (`BoonRuntime.shield`, refilled each tick by `shieldPerMomentum`)
— leaving only the Ultimate and its two talents pending.

## Decision — "blocks the hit," a new reflect primitive, and a shield-break hand-off

**Aegis Pin.** The sim has no standalone enemy-projectile entity for a wall
to intercept — every enemy attack reaches the player as a single
`EnemyAttack.damagePlayer` call, a fraction of max HP. "Blocks all enemy
projectiles" is read as "blocks the hit outright," the identical shape
`umbralStepRemaining`/`ashlinInvulnRemaining` already use, via a new
`HeroRuntime.aegisPinRemaining` timed field. Unlike those two, it also pays
something back: a share of the blocked hit's pre-mitigation damage,
reflected at the attacker.

**The reflect itself is a new shared primitive**, `EnemyAttack.
_reflectDamageToAttacker`, doing exactly what `CompanionSystem`'s own hit
resolution already does (absorb → plate → health, matching that a hero
runtime reflect and a companion's shot are both "damage dealt to an enemy
from outside the ordinary arrow path"). "As Storm" is flavour-only for this
hit: Storm's own mechanical identity in this sim is chaining between
targets (`ElementTuning.chainTargets`), which does not apply to one
non-chaining reflected hit, and no elemental *status* exists for Storm the
way Chill/Toxin/Burn each have one — so no reaction pipeline is invoked
here, a deliberate, flagged simplification rather than new cross-system
wiring for one card's typing.

**Riposte** detects the shield (`boons.shield`) reaching zero from a hit
that found it above zero, inside the existing Shieldweave-spend block in
`damagePlayer` — the pool is shared with Shieldweave's own Boon by design
(Ovrin's Aegis grants "*a* shield," not a second pool), so any source
emptying it counts. Resolving the actual AoE needs `playerAttack`/`spatial`/
`entities` together, which `EnemyAttack` does not have; it sets a new
`HeroRuntime.riposteNovaPending` flag instead, read and cleared in
`SimWorld.tick` right after `AiSystem.update` — the identical hand-off
`rekindleNovaPending` already uses for Ashlin's own revive nova, for the
same reason. The AoE math itself reuses that same helper too, renamed from
`_applyAshlinNova` to `_applyPlayerCenteredNova` now that a second hero
needs it — named for what it does rather than who first needed it.

**Long Wall/Mirror Wall** are `_fireOvrinAegisPin`'s own two mutually
exclusive ★5 branches: one changes only the duration, the other changes
only the reflect share (read directly off `hero.has(ovrinMirrorWall)` at
hit-resolution time, not a second stored field) and swaps its own duration
in along with it.

## A second, unrelated fix that fell out for free — Thorns (Boon #31)

Building the reflect primitive meant threading `SimWorld.thornsReflect`
into `AiContext` for the first time. `thornsReflect` had existed since
Phase 9 (Boon #31, "reflect 15 % of contact damage") and a test already
confirmed the card set it to 0.15 on pickup — but nothing had ever *read*
it. Thorns has no `behaviour` field in its own data (a plain `StatChannel`,
like `vaneFarsight`/`liraDeepRoots`), so it never joined either ledger
(`pendingBehaviourWork` or `pendingHeroBehaviourWork`) that would have
flagged it as incomplete — the composition test made it look finished. It
was not: every Thorns pickup since Phase 9 has done nothing.

Fixed the same way as Aegis Pin's own reflect: a new `AiContext.
thornsReflect` field, copied from `world.thornsReflect` in
`_refreshAiContext` alongside `incomingDamageFactor`, read in
`damagePlayer` right after the final `dealt` is settled and reflected via
the same `_reflectDamageToAttacker` helper — "contact damage" is read as
any hit that reaches the player through this one function, since the sim
draws no separate "contact vs. ranged" attack category anywhere. A new test
in `boon_effects_test.dart` (not `hero_behaviour_test.dart` — this is
Boon-side, not hero-side) proves the reflection actually happens now,
rather than only that the number arrives.

## Verified end to end

Six new hero tests: Aegis Pin blocks a hit and reflects exactly 30 %;
without it active the same hit lands in full; Long Wall extends the window
to 10 s; Mirror Wall reflects 100 % for 3 s; Riposte's AoE fires at exactly
200 % of `playerAttack` when Ovrin's own shield breaks; without the talent,
breaking the shield does nothing extra. One new Boon test: Thorns actually
moves damage from the player back onto the attacker at its own 15 %.

## Consequences

Ovrin's entire kit is now implemented. `pendingHeroBehaviourWork` drops to
24. Thorns (Boon #31) is fixed as a side effect — every prior run that took
it got nothing for the pick, silently, since Phase 9.
