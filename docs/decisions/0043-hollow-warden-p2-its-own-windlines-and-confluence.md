# ADR 0043 — The Hollow Warden's own P2: its own Windlines, its own Confluence, and a new slow on the player

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2. P3 ("both Windline sets live; crossing your
line through its line creates a Discord — a neutral detonation damaging
whoever is closer") is not built — a known, flagged gap the codebase has
been anticipating since before this boss existed at all.
**Severity** Medium-high. The clearest case yet of a card that the sim's
own architecture had already been quietly built to receive:
`WindlineStore`'s own doc comment names this exact boss by number, and
`BoonSystem.applyWindlineField`'s own ownership check explicitly exists
"for when the Hollow Warden arrives."

---

## What was missing

docs/06 §4, The Hollow Warden: P1 (ADR 0031, this session) already
resolved the mirror movement and the second live `DrawState`. P2's own
card: "It lays Windlines and gains Confluence off them. Crossing its
Windlines slows the player." — additive on top of P1's own mirror/Draw/
heavy-shot loop, which this decision keeps running completely unchanged.

## The mechanic was already half-built, on purpose

Reading `WindlineStore` and `ConfluenceSystem` before writing anything (the
same discipline the plate investigation for Weeping Gate's own P2 just
established) turned up something unusual: this codebase's Windline layer
was never player-only in its actual data model, only in every *consumer*
of it so far.

- `WindlineStore._owner`'s own doc comment: "an enemy's trail must never
  buff the player. **The Hollow Warden's trails (docs/06, boss 4) interact
  through a separate Discord rule.**"
- `BoonSystem.applyWindlineField`'s own ownership filter, on the line that
  decides whether an enemy standing on a segment is affected: "Only the
  player's own trails... the owner check is what makes that stay true
  **when the Hollow Warden arrives.**"
- `ConfluenceSystem.sweep` itself takes `ownerIndex` as a plain parameter,
  never hardcoded to the player — the player-only behaviour lives entirely
  in `ProjectileSystem`'s own call site (`ownerIndex: _playerOwner`, a
  private `0`), not in the shared primitive.

So the actual work here was smaller than it looked: give the Warden its
own lines with its own owner index, and reuse every primitive verbatim.

## Decision — reuse the primitives directly, add exactly one new field

**Laying a line.** Each heavy shot (the same Tier-III-triggered bolt P1
already fires) now also calls `ctx.lines.add` with `ownerIndex: slot` —
the Warden's own entity slot, not `_playerOwner` — spanning the shot's
full theoretical flight path (`_boltRange` along the fired angle), the
same "one shot, one segment" shape a single hazard bolt naturally admits
without needing `_layForcedSegment`'s own per-tick periodic-cut machinery
(that machinery exists because a real `ProjectileStore` entry moves
continuously across many ticks; `EnemyAttack.fireBolt`'s own hazard does
not carry the position-history bookkeeping to lay incremental cuts, and
one segment per shot is a faithful, much simpler read of "it lays
Windlines").

**Gaining Confluence off them.** Before adding that segment, `_fireHeavyShot`
sweeps `ConfluenceSystem.sweep` against the Warden's own already-live lines
(`ownerIndex: slot`), using `ctx.lines.nextSerial` as the sweeping shot's
own not-yet-assigned serial — swept *before* insertion, so every currently
alive Warden-owned segment is automatically strictly older, with no second
counter needed. A found stack scales `_heavyShotDamage` by
`1 + ConfluenceTuning.bonusFor(stacks)`, the identical formula
`ProjectileSystem._resolveConfluence` already uses for the player. No
`minThreadDistance` gate was ported: that rule exists to stop a
rapid-fire, any-direction shooter from crossing its own trail at the bow;
the Warden fires in exactly one direction per shot (always at the player),
so two shots along an unchanged line are *parallel*, and
`ConfluenceSystem`'s own 25° parallel-rejection already throws those out
for free. The gate would have been redundant here, not protective.

**Slowing the player.** This is the one genuinely new piece, because nothing
in the existing Windline layer runs in this direction: `BoonSystem.
applyWindlineField` slows *enemies* standing on the *player's* lines, never
the reverse. `DrawState` gained `windlineSlowFactor` (default `1.0`,
reset alongside `momentumEffectivenessMultiplier` — the field Rimefather's
own P2 (ADR 0038) already added there, the same "recomputed live every
tick by whichever system currently cares" posture, not an event-driven
reset), multiplying `SimWorld._applyInput`'s own speed calculation directly
— a different lever from `momentumEffectivenessMultiplier`, which only
scales Momentum's *reward*, not raw speed. A new `HollowWardenSystem.
_tickPlayerSlow`, run every P2 tick, checks the player's own current
position against the Warden's own live lines using `_pointNearSegment` —
reimplemented against the query, not called into `BoonSystem`'s own
private method of the same name, the identical "reuse the shape, not the
private function" rule this file's own doc comment already states for
movement — and sets the factor to `1.0 - SimConfig.windlineSlow` (0.08,
the exact constant the enemy-side slow already uses) or back to `1.0`.
Because `_applyInput` runs earlier in the tick than `HollowWardenSystem.
update`, this is a one-tick-lagged read, the same acceptable lag
`momentumEffectivenessMultiplier` already carries.

## The freeze boundary migration, again

The now-familiar move: the pre-existing "stops past P1" test lived at
`bossPhase >= 1`; that boundary now means "P2 is live," so the freeze
moved to `bossPhase >= 2`, with the player's own `windlineSlowFactor`
explicitly reset to `1.0` in that branch alongside the mirror halt and the
Draw freeze — a frozen-mid-P2 run must never leave the player permanently
slowed.

## Verified with exact numbers, not just structurally

`_heavyShotDamage = 0.06 * 2.10 = 0.126` (12.6% of max health). A test
seeds a single perpendicular Warden-owned line across the (deterministic,
since the mirror settles instantly at this test's chosen player position)
horizontal shot path and asserts the resulting health to the exact cent:
`100 - 100 * 0.126 * 1.40 = 82.36` (one stack, `bonusByStacks[1] = 0.40`).
A sibling test with no seeded line asserts the bare `87.4`. Both matched
on the first run — real confirmation the sweep, the bonus formula, and the
damage application all compose correctly end to end, not just that a line
gets added somewhere.

## Consequences

Nine of twelve campaign bosses now have some form of P1+P2. This is the
first P2 to consume a piece of architecture that was already sitting in
the codebase, purpose-built and waiting, rather than needing a new
mechanism invented from scratch — worth remembering that not every "gap"
this session finds is actually a gap; sometimes it's a comment naming
exactly which future ADR would close it. It's also the first P2 to add a
genuinely new multiplicative lever to the player's own movement speed
(`DrawState.windlineSlowFactor`) rather than only ever touching an enemy's
own fields — the reverse-direction Windline interaction P3 will need
(Discord: a detonation between *both* trail sets) has a much shorter
distance to cover now that both sides can independently lay, own, and be
affected by lines.
