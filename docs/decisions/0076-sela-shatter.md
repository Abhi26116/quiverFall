# ADR 0076 — Sela's Shatter: an on-kill AoE centred on the kill, not the player

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved.
**Severity** Low. A small, local addition inside an existing death-pass
read-before-reset block; no new field, no new hand-off.

---

## What was missing

docs/07 §7.3, Sela T3a: **"Shatter: killing a frozen enemy deals 250 % in
2 u."** The ledger's own note explained why this had stayed pending: every
existing per-kill hook (Nyx's First Blood included) only sets timed state on
the *killer's* own runtime — none of them deal damage to a third party.

## Decision — read the corpse before `clearSlot`, deal damage where it died

`AiSystem._reap` already has exactly the right shape for this: Contagion and
Wildfire (Kade/Sable) both read a corpse's own status fields immediately
before `ctx.status.clearSlot(slot)` erases them, specifically because a
corpse still has real state to read for one more instant. Shatter's own
check — `hero.has(HeroBehaviour.selaShatter) && ctx.status.isFrozen(slot)` —
joins that same spot, using the corpse's own `posX`/`posY` (also still valid
before `despawn`) as the burst's centre.

**Why this needed a new helper instead of reusing `SimWorld.
_applyPlayerCenteredNova`** (built two ADRs ago for Ashlin's revive/Ultimate
and Ovrin's Riposte): that helper is *player*-centred by construction and
lives in `SimWorld`, which `AiSystem` cannot call into. Shatter's own centre
is the kill's position, not the player's, so it gets its own small
`AiSystem._applyRadiusDamage(ctx, x, y, radius, damage)` — the identical
`spatial.queryRadius` scan and flat `health -=` math, no absorb/plate
handling (matching the existing nova exactly, not "improving" it unasked),
parameterised on a point instead of assuming the player's.

**No new field, no pending-hand-off flag was needed** — unlike Riposte,
`AiContext` already carries `playerAttack`/`spatial`/`entities` together (the
same trio `AiSystem` reads throughout this file), so the burst resolves
inline, in the same tick, at the exact moment of the kill.

**Re-entrancy**: a Shatter burst that kills a lower-indexed neighbour before
`_resolveDeaths`'s own forward scan reaches it will not reap that neighbour
until the *next* tick's own death pass — the identical, already-accepted
latency `DriftTree.detonateAt`'s own death blast already carries for exactly
the same reason (a single forward pass over `[0, high)`). Not a new risk.

## Verified end to end

Four new tests: killing a frozen primary deals exactly 250 % of
`playerAttack` to a bystander 1 u away; killing an *un-frozen* primary does
nothing to the bystander; without the Shatter talent, killing a frozen
primary does nothing extra; a bystander 3 u away (outside the 2 u burst)
takes nothing even though the kill was frozen. All four passed on the first
real attempt. `killWithOneHit`'s own test helper stops the tick loop the
instant the target is reaped — autoFire retargeting onto the bystander the
moment the primary died would otherwise contaminate a "no damage" assertion
with ordinary, unrelated arrow hits.

## Consequences

`pendingHeroBehaviourWork` drops to 23. Sela's own *Lingering Frost* (T3b)
stays pending — it needs a genuinely new "timed slow zone independent of
Windlines" primitive, a materially bigger piece than this ADR's own small
addition, and is not reopened here.
