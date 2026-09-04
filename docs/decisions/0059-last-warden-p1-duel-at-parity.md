# ADR 0059 — The Last Warden, P1: a duel fought by the player's own rules

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1 only. The Last Warden (docs/06 §6.3, Endless
Descent boss #20 — the true final boss) is a five-phase fight; this ADR
covers the first phase alone. P2-P5 are tracked separately and are not
built yet.
**Severity** High. The largest single scope in the boss roster (ADR 0058's
own closing line) — this is the first of several parts.

---

## What was missing

docs/06 §6.3, The Last Warden: "×140 HP · 150s · The true final boss. The
Warden who held the Spire before you. Five phases, not three." **P1:
"Draw/Momentum duel at parity — it plays the game exactly as the player
does."**

## Decision — a third live `DrawState`, for free

`DrawState`/`DrawSystem` were already generic across any number of live
instances the moment the Hollow Warden's own `hollowWardenDraw` proved it
(ADR 0031): `DrawSystem.update(state, isMoving, dt, events)` ramps Draw
while stationary and stacks Momentum while moving, for *whatever*
`DrawState` is handed to it. `SimWorld.lastWardenDraw` is a third such
instance, wired through `AiContext.lastWardenDraw` the identical way the
first two are — no changes to either system were needed to support it.

`BossPhaseSystem` also needed zero changes: it already reads
`BossDefinition.phaseThresholds` as a plain list and advances through
however many entries exist. `lastWarden`'s own four thresholds
(`[0.8, 0.6, 0.4, 0.2]`, an inferred even split per `boss_definition.dart`'s
own doc comment, since docs/06 states no numbers) already drive five
phases without modification. **P5's own "one HP each... sudden death" is
explicitly not a fractional threshold** (the same doc comment says so) and
needs its own end-of-fight rule once P5 is actually built — not attempted
here.

## "At parity" is two real trades, both ways

- **Momentum's speed bonus is real for the Warden.** Every step this
  system takes reads `draw.moveSpeedBonus`, the identical getter the
  player's own movement already reads.
- **Momentum's damage reduction is real for the Warden too — this is the
  one piece with no existing hook to reuse**, since every other damage
  pipeline in the game reduces the *player's* incoming damage, never an
  enemy's own. Intercepting a hit before it lands would mean adding a
  boss-archetype-specific branch inside `ProjectileSystem._applyHit`, the
  single most shared, most heavily tested function in the whole combat
  pipeline — a materially riskier and wider change than anything else in
  this pass, for one boss's one phase. Instead, `_tickDamageReduction`
  reuses Rimefather's own "observe and correct after the fact" shape (ADR
  0050): it diffs this tick's health against a baseline read last tick
  (`bossLastHitAgo`, free — P1 places no children) and refunds a
  `damageReduction` fraction of whatever dropped. Verified directly: at
  max Momentum (5 stacks, 10% reduction — the same numbers the player's
  own Momentum grants), a 100-damage hit lands as 90; with zero stacks, a
  hit lands in full.

## The rhythm is the player's own loop, mirrored

docs/01 §1.1's own player loop — root to escalate, move to survive,
repeat — becomes the Warden's own behaviour rather than a themed
variant of it: close to an authored engage range and hold (Draw ramps,
`isMoving == false`), fire at Tier III (`EnemyAttack.fireBolt`, the same
primitive, the same "fraction of max HP derived from an existing anchor,
not the player's own actual arrow type or hero stats" honesty ADR 0031
already established for the Hollow Warden's own heavy shot — porting real
arrow behaviour onto an enemy body remains the identical out-of-scope
redesign question here it was there), then deliberately disengage
(`bossTimer` as a reposition countdown, free — the same generic-countdown
reuse this roster leans on throughout) and retreat to rebuild Momentum
before closing again. No new state machine enum was needed: `bossTimer >
0` (repositioning) versus in-range-or-not is enough to express the whole
cycle.

## Verified end to end

Eight tests: the spawn numbers; closing distance while far; holding
position once in range without a state actually confirming the boss
never drifts a wind-up onto it; the full Draw-to-Tier-III-and-fire cycle,
including that firing resets Draw and starts a real reposition window;
never firing while permanently out of range; Momentum stacks building
while moving, mirroring the player's own rule; the damage-reduction
refund at max stacks landing at the exact fraction; and zero refund at
zero stacks. All eight passed on the first real attempt — no bugs found
this pass.

## Consequences

P1 is real and faithful to its own card. P2 ("gains the player's own
current Boon set, mirrored"), P3 (telemetry-driven echo summons of the
three most-defeated bosses), P4 (the floor removed, Windline-drawn
platforms as terrain), and P5 (one HP each, 20s sudden death) remain
entirely unbuilt — each is its own materially large scope, tracked as
follow-up parts to this same boss rather than folded in here.
