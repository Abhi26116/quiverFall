# ADR 0072 — Zea's Skyhawk: the first real use of the companion primitive

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved for the passive half of Zea's kit (Skyhawk, Sharper
Talons, Swift Hawk, Bonded, Flock). Falconry (the Ultimate) and its own
★5 pair remain pending — see below.
**Severity** Medium. Answers the "when does a companion actually get
spawned" lifecycle question ADR 0071 deliberately left open.

---

## What was missing

docs/07 §7.3, Zea, the Falconer: **"Passive — Skyhawk: a spirit hawk
companion attacks independently for 35 % of hero ATK at 1.5/s, and its
shots lay Windlines the player can Confluence through,"** plus four
talents building on it (Sharper Talons, Swift Hawk, Bonded, Flock).
`CompanionSystem` (ADR 0071) gave the sim a way to represent a companion;
nothing yet decided *when* one should exist for a real Zea loadout.

## Decision — synced inside `HeroLoadoutResolver.apply`, idempotently

`HeroLoadoutResolver.apply`'s own doc comment already states its contract:
*"Call whenever the hero's level, stars, talent choices, equipped arrow or
its refine level changes"* — a real build-change hook, not a per-tick one,
and one the codebase already calls more than once across a run (a
level-up, a star-up). This is exactly the right place to keep a permanent
companion in sync with the current build, and the right *reason* to make
it idempotent rather than a one-shot spawn: `_syncZeaSkyhawk` despawns any
existing permanent companion (`CompanionStore.remaining ==
double.infinity` — the one signal that distinguishes a hero's own
passive-granted companion from a temporary Falconry/Hall of Mirrors
summon, whose own `remaining` is always finite) before spawning fresh
one(s) with the current numbers. A level-up mid-run replaces the hawk
with a correctly-scaled one instead of leaving a stale copy *or*
silently accumulating a second one — verified directly.

**Which talents apply here, and why.** Sharper Talons (★1a, "hawk damage
share rises to 50 %"), Swift Hawk (★1b, "hawk attacks at 2.4/s") and
Bonded (★3a, "hawk crits when the player is at Tier III") all read as
blanket "your hawks are better" rules rather than naming Falconry
specifically, so they apply to the passive Skyhawk here. Flock (★3b, "2
*permanent* hawks at 25 % each") names permanence explicitly, so it
belongs here and only here — read as a literal replacement of the base
one-hawk-at-35 % grant, the same "the branch's own stated numbers fully
replace the base shape" reading this roster already uses for Wren's Wide
Fan/Focused Fan against Volley Fan. **Falconry itself (the Ultimate) and
its own two ★5 talents (Skydarken, Great Hawk) are not built here** —
each summons *temporary* companions on demand, the same "fire the
Ultimate" dispatch every other hero's own Ultimate already goes through
in `SimWorld._fireUltimate`, a distinct piece of work from keeping a
passive in sync.

## Verified end to end

Nine new tests: the passive grants exactly one permanent companion; a
hero with no Skyhawk grants none at all; the hawk's own damage share and
fire interval match docs/07's own numbers exactly, and it independently
damages an enemy with no player arrow involved; Sharper Talons and Swift
Hawk each raise their own single number; Flock replaces the one hawk with
two at the stated 25 % each, both still permanent; Bonded sets the
crit flag; re-applying the loadout (a level-up) replaces the hawk rather
than duplicating it; and re-applying with an entirely different hero
removes it. All nine passed on the first real attempt.

## Consequences

Five of Zea's eight `pendingHeroBehaviourWork` entries are resolved:
`zeaSkyhawk`, `zeaSharperTalons`, `zeaSwiftHawk`, `zeaBonded`,
`zeaFlock`. `zeaFalconry`, `zeaSkydarken` and `zeaGreatHawk` remain —
the natural next part, once a temporary-companion Ultimate dispatch is
built (mirroring `_fireHaldenJudgmentSpear`'s own shape, but spawning
companions with a lifetime instead of firing an arrow). Mirelle's own
Hall of Mirrors/Endless Hall/Twin Warden are unaffected and remain fully
pending — they need the identical temporary-companion dispatch, not the
passive-sync shape this ADR resolved.
