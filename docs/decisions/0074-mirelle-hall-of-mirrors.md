# ADR 0074 — Mirelle's Hall of Mirrors: guaranteed duplication plus the companion primitive

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Mirelle's own kit is now complete.
**Severity** Low-medium. One genuinely new mechanic (a guaranteed, timed
duplication distinct from Reflection's own probabilistic one) alongside a
straightforward extension of ADR 0071/0072/0073's own companion primitive.

---

## What was missing

docs/07 §7.3, Mirelle's own Ultimate: **"Hall of Mirrors: 8 s where every
arrow duplicates 3×, and a mirror clone of the player fights alongside at
60 % stats."** T5: *Endless Hall* (14 s) / *Twin Warden* (the clone lasts
the whole room at 80 % stats).

This reads as two genuinely separate mechanics bolted onto one Ultimate:
a fixed-count, guaranteed arrow duplication (nothing like it existed —
Reflection's own passive is probabilistic and geometric, not guaranteed and
flat), and a temporary companion clone.

## Decision — a new timed field for the guarantee, the existing primitive for the clone

**The guarantee.** `HeroRuntime.hallOfMirrorsRemaining` is a new timed field,
decremented once per tick the same way `caromsRemaining`/`tempestNockRemaining`
already are. `SimWorld._applyHallOfMirrorsDuplication`, called from
`_spawnArrow` right after the existing `_applyMirelleReflection`, spawns
exactly 3 more arrows at **full** damage whenever the field reads above zero
— no chance roll, unlike Reflection's own cascade, because the card states
none for this. It is gated to `depth == 0` so the guaranteed triplicate never
re-triggers on its own duplicates; each of the 3 still passes back through
`_applyMirelleReflection` at depth 1 and can cascade normally if Reflection's
own passive is also active, the same as any other ordinary duplicate would.
*Fractured* (T3b, "duplicates spread ±20°") is read as a general "duplicates
spread wider" rule rather than one scoped to Reflection specifically, so it
applies to these guaranteed duplicates too; *Silvered* (T3a) makes no
difference to them, since they already deal full damage with nothing to lift.

**The clone.** `_fireMirelleHallOfMirrors` joins `SimWorld._fireUltimate`'s
own identity switch, the same dispatch every other hero's Ultimate already
goes through, and spawns a `CompanionSystem` companion exactly like Zea's
Falconry (ADR 0073) does — Mirelle's own card-stated stat line ("ATK 100 ·
Rate 2.20") is what "60 %/80 % stats" scales, the same way `damageShare`
already scales `playerAttack` for every other companion.

**Twin Warden's "lasts the whole room"** has no literal room-boundary hook a
fire-time value can bind to — rooms vary in length and nothing exposes "how
long is left" at cast time. Rather than inventing one for a single talent,
the clone's own `lifetimeSeconds` is set to a long, generously-authored
duration (300 s) well past any real room's length; the room's own entity
wipe on clear removes it exactly on schedule regardless, so in practice this
reads as "the whole room" without a dedicated hook. This also sidesteps a
real collision: a permanent (`double.infinity`) companion is exactly what
`HeroLoadoutResolver`'s own despawn-and-resync sweep (ADR 0072) tears down on
an unrelated level-up, which a genuinely room-scoped clone must not suffer.

**The two ★5 branches stay independent of each other**, matching the card's
own separation: Endless Hall only extends `hallOfMirrorsRemaining` (the
duplication window); Twin Warden only changes the clone's own share and
lifetime. Neither branch touches the other's number.

## A test-hygiene trap, not a sim bug

The first version of the "every shot gets its guaranteed 3" test failed with
one shot reporting only 1 full-damage arrow instead of 4. Tracing it down
(temporary prints at both the duplication call site and every `_spawnArrow`
invocation) showed the sim was correct throughout — every real shot in the
window produced its guaranteed triplicate. The failure was the test's own
event-buffer hygiene: `_updateFiring` runs before `_updateUltimate` inside
`SimWorld.tick`, so the very tick that presses the Ultimate can also fire one
*ordinary* shot first, before the window is even set — correctly ungated.
The test never cleared `world.events` after that press tick, so that
leftover, correctly-unguaranteed arrow (plus whatever Reflection's own
passive happened to roll on it) leaked into the first tick the test actually
sampled. Clearing `events` right after the press tick fixed it. Worth
recording because it is exactly the kind of trap this session has hit before
with timer decay tolerances — a fixture detail, not a mechanic.

## Verified end to end

Five new tests: every shot during the window produces at least 4 full-damage
arrows (a hard per-tick floor, not a statistical average, checked across the
full window); the guarantee stops once the 8 s window actually expires; the
clone spawns at 60 % share and a derived fire rate for 8 s; Endless Hall
extends the window to 14 s without changing the clone; Twin Warden raises the
clone to 80 % share and a duration well past any room's length without
extending the duplication window.

## Consequences

Mirelle's entire eight-entry kit is now implemented — the seventh hero
(after Sable, Kade, Corvin, Lira, Halden, Zea) with nothing left in
`pendingHeroBehaviourWork`. `pendingHeroBehaviourWork` drops to 28.
