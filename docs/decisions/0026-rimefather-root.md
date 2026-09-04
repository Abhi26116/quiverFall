# ADR 0026 — Rimefather: the freezing cone is Silversong's shape; the root is new

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 (arena floor freezing outward, ice friction)
and P3 (ice-mirror decoys) are not built — a known, flagged gap.
**Severity** Medium. One genuinely new sim primitive (`DrawState.rootRemaining`)
— the first enemy-inflicted "the player cannot move at all" effect in the
game.

---

## What was missing

docs/06 §6, Rimefather (chapter 6): "Tests: Frost, and forced movement." P1:
"Freezing cone; a player hit twice within 4s is rooted for 1.2s." The cone
itself is Silversong's own shape exactly — a stationary single body cycling
wind-up → resolve → cooldown, `EnemyAttack.beginCone`/`playerInCone`, the
same Screecher-derived numbers (30° half-angle, 5u range, 0.6s wind-up) ADR
0024 already reused. `RimefatherSystem` is close to a copy of
`SilversongSystem` with one attack shape swapped for another.

What Silversong's own shape does *not* cover is the root. Draw-lock
(`DrawState.applyDrawLock`) only denies *tier progress* — the player can
still walk, dash, and fire at Tier I throughout. "Rooted" is qualitatively
different: the player cannot move at all. Nothing in the sim could do that
to the player before this boss.

## Decision — a new `DrawState.rootRemaining`, not a reuse of `SimWorld._stunRemaining`

`SimWorld` already has a private `_stunRemaining` field — the *Quiverfall*
arrow's own self-inflicted recoil stun, checked in `_applyInput`/`_applyDash`.
It is the same shape ("time during which movement input is ignored") this
mechanic needs, but it is `SimWorld`-private and semantically a *player's own
choice's* cost, not an enemy's effect — conflating the two would mean a
`Quiverfall` shot landing during a Rimefather root (or vice versa) silently
extends or shortens the wrong timer, and would make `DrawState` (the object
every boss's own reused Draw-lock/status logic already reads through
`AiContext.playerDraw`) an incomplete picture of what's stopping the player.

Instead, `DrawState` gets its own `rootRemaining`/`isRooted`/`applyRoot()`,
built the same way `applyDrawLock` already is (longest-remaining-wins, never
shortens an active effect), decremented by `DrawSystem.update` alongside the
existing `drawLockRemaining` countdown. `SimWorld._applyInput` and
`_applyDash` now check `_stunRemaining > 0 || playerDraw.isRooted` — both
timers stop movement, independently, for their own reasons.

**The cone's own damage (9%) is reused, not new**: the same Thresher-derived
"persistent aura" anchor Cinder Choir's tether and cones already reused
(ADR 0019/0020). "Frost" is thematic only here — this pass does not apply a
real elemental status to the player; that would be a separate, larger
primitive (the player has no "afflicted by an element" state at all today)
and P1's card does not require it, only the freeze-as-root metaphor.

**The cooldown (1.5s, authored)** is shorter than Silversong's own 2.5s —
chosen so two casts land comfortably inside the 4s streak window rather than
requiring a played-perfectly-still target to ever see the root at all.

## The streak itself reuses `comboStep` and `bossTimer`, not new fields

Two more of `EnemyStore`'s own generic per-boss fields, following the
session's established discipline of checking for an unused-by-a-bare-boss
field before adding one: `comboStep` (normally "which swing of a multi-hit
combo is next" for an ordinary melee enemy — meaningless for a boss entity,
since `AiSystem`'s own generic tree never runs on a slot whose `contentIndex`
is -1, which every boss's own `spawn()` sets) now counts hits within the
current streak; `bossTimer` (previously used by Skarn for its own "how long
since either body was last hit" pressure countdown — a different boss, no
conflict) now counts down the 4s window itself, ticking every frame
regardless of the attack cycle's own `attackCooldown`. A hit when the window
has already expired starts a fresh streak of one rather than extending a
stale one — the actual content of the "within 4s" qualifier, and the one
thing worth a dedicated test (`rimefather_system_test.dart`'s "a streak that
goes cold resets").

## What's deliberately not built here

**P2 (the arena floor freezing outward, changing friction; Momentum stronger
on ice) and P3 (shatters into three ice-mirrors, only one real, wrong-target
damage heals it).** P3 especially needs an idea nothing in the sim has an
analogue for: a *decoy* body indistinguishable from the real one by anything
the simulation itself can query — "which one casts a shadow" is a
rendering-only tell with no sim-side equivalent today. Once `bossPhase`
reaches 1, `RimefatherSystem` stops casting and clears any live telegraph —
the same posture every other boss's own undone phases already take.

**`BossRoomComposer` now maps chapter 6 to `rimefather`** — the sixth
confirmation of ADR 0021's own predicted two-line integration cost.

## Consequences

Six bosses now exist. The player can now, for the first time, be stopped
from moving entirely by an enemy — any future mechanic wanting the same
("frozen solid", "entangled", a trap) should reuse `DrawState.rootRemaining`
rather than inventing its own timer, the same way Draw-lock is already
shared. Arclight (Storm) is the next natural check against an existing
element family, per ADR 0025's own closing note.
