# ADR 0079 — Rook's Singularity: a sustained well, not a new primitive

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Rook's own kit is now complete.
**Severity** Medium. The largest single addition of this stretch, but it
composes entirely out of shapes the sim already had for Sable's Miasma and
Kade's Pyre Line.

---

## What was missing

docs/07 §7.3, Rook's own Ultimate: **"Singularity: a 4 s well pulling
everything in 6 u to a point, then detonating for 400 %."** T5: *Twin
Singularity* (2 wells) / *Collapsing Singularity* (1 well, 6 s, 900 %). The
ledger's own note called this out specifically: "a multi-tick 'pull
everything toward a point, then detonate' well needs a sustained field
effect nothing before now has asked of Ultimates (every other one so far
resolves in a single tick)."

That premise turned out to be the one part of the note that did not
survive a second look: Sable's Miasma and Kade's Pyre Line are *already*
sustained, multi-tick Ultimates — a cloud and a wall, each pinned at cast
time on `HeroRuntime`, ticked every frame from `SimWorld.tick` outside
`ProjectileSystem`'s own hit-resolution loop. Singularity is a third
instance of the identical shape, not a new one.

## Decision — the same fixed-zone shape, plus a pull step and a detonation

`HeroRuntime.singularityRemaining`/`singularityX`/`singularityY` are set at
cast time by `_fireRookSingularity`, using `FiringSystem.selectTarget` —
the same nearest-target selection Pyre Line and Glacier Nail already use —
to pick the well's own centre, falling back to the player's own position
with nothing in range. `_tickRookSingularity` runs every tick alongside
`_tickSableMiasma`/`_tickKadePyreLine`: while the timer is above zero it
drags every enemy within 6 u toward the centre by a flat 5 u/s (docs/07
states no pull speed; fast enough that anything caught at the full radius
still reaches the centre before the base 4 s window ends, so the promise
"pulling everything... to a point" is one the well keeps rather than a slow
drift); the instant the timer reaches zero, it detonates once and never
again.

**Two new small helpers, not a reused nova.** `_pullTowardWell` is new
(nothing before this moved an enemy's position over time from a hero
effect — `ProjectileSystem`'s own crit-Pull is instant, a single
displacement, not a sustained drag). `_detonateAt(x, y, radius,
multiplier)` is also new rather than a call into
`_applyPlayerCenteredNova`: that helper is fixed to the player's own
position and a shared 3.5 u radius (Ashlin/Ovrin), while a well can sit
anywhere and Rook's own radius is a different, stated 6 u — forcing an
optional centre and radius onto a function named for always using the
player's own single one would have made a worse name for both existing
callers.

**Twin Singularity's second well** targets the *second*-nearest enemy
(`_nearestEnemyExcluding`, a linear scan patterned on the existing
`_furthestEnemy`), the same "second independent instance of the same fixed
zone" shape `HeroRuntime.pyreLine2X0` already established for Kade's own
Twin Pyre — mirroring the first well's own position would just be one well
with a redundant name. Collapsing Singularity trades that second well for
a longer, harder-hitting single one; the two stay this Ultimate's own
mutually exclusive ★5 branches.

## Verified end to end

Six new tests: firing locks the well onto the nearest enemy and pulls
another enemy within range measurably closer over one tick; the well
detonates for exactly 400 % of `playerAttack` once its 4 s window elapses;
an enemy 6+ u away is never pulled or hit (spawned *after* the well has
already locked its own target, so it cannot accidentally become that
target itself — the arena's own 16×9 bounds make a bystander that far from
the well *and* further from the player than the real target too tight to
place any other way); Twin Singularity forms a second well at the
second-nearest enemy; without it, only one well ever exists; Collapsing
Singularity forms one 6 s well that detonates for 900 %. Every duration
check right after casting uses the same 0.02 s slack this file's other
timed windows already need — `_tickRookSingularity` runs later in the same
tick that fires the Ultimate, so one frame of decay has already elapsed by
the time a test can read it, the identical same-tick-decay shape Rook's
own Anchor test hit earlier this session.

## Consequences

Rook's entire kit is now implemented — the ninth hero with nothing
deferred. `pendingHeroBehaviourWork` drops to 16.
