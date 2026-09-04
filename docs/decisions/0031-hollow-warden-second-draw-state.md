# ADR 0031 — The Hollow Warden: the second Draw state, finally

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 (lays Windlines, gains Confluence off them)
and P3 (Discord — a neutral detonation from crossing trail sets) are not
built — a known, flagged gap.
**Severity** High. Genuinely new sim surface area — `SimWorld.
hollowWardenDraw`, a second live `DrawState` — plus two large, deliberate
scope cuts on an already-ambiguous card (arrow type, hero stats).

---

## What was missing

docs/06 §4, The Hollow Warden (chapter 4): "Tests: understanding your own
kit." "A mirror of the player's current hero, at 80% of the player's own
stats, using the player's own arrow type and a fixed Boon set." P1:
"Mirrors movement inverted (Echo AI). It Draws — its own arc is visible,
so the player can read exactly when its heavy shot lands." This was the
one campaign boss deliberately deferred all session (first named in Phase
11 part 1's own scoping notes) — the only fight whose own P1 needs a
second live Draw ramp, not just a new attack shape.

**`DrawState`'s own doc comment had already named this boss**, predating
this implementation by several phases: "A class rather than arrays because
there are very few of these: the player, and later the Hollow Warden
(docs/06 §6.1, boss 4) which mirrors the player's kit and therefore needs
its own instance." This ADR is that prediction actually landing.

## Decision — movement is the Echo's own math, reimplemented, not called

The ordinary Echo (docs/05 #24, `RiftbornTree._echo`) already mirrors the
player's own position inverted about the arena centre, falls back to the
player's own position when the mirror is unreachable, and lags the mirror
by a gain factor below 1.0 so it visibly trails. All of that is exactly
what "Mirrors movement inverted (Echo AI)" asks for — but `_echo` is a
private family-tree method that needs an `EnemyDefinition` to read its own
speed/gain from, which this bare boss body (`contentIndex = -1`, like
every other boss) does not have. `HollowWardenSystem._mirror` reimplements
the identical approach directly against `Steering`, reusing the Echo's own
numbers (2.4 u/s, `EnemyTuning.echoMirrorGain` = 0.9) as flat constants —
the same "reuse the *shape*, not the private function" posture Gaunt and
Vermillion already established for borrowed `Steering.moveToward` calls.

`_mirror` returns whether the Warden is still closing on its own mirror
point — which is exactly the `isMoving` boolean `DrawSystem.update`
already takes as an argument for the player. No new "am I moving" concept
needed; the same distance check that decides whether to keep chasing or
halt decides whether the Draw may ramp this tick.

## Decision — a second `DrawState`, not a second-class approximation

`SimWorld.hollowWardenDraw` is a plain second field, the same
always-present, reset-in-`clearRoom` shape `playerDraw` already has —
`AiContext.hollowWardenDraw` exposes it the identical nullable way
`AiContext.playerDraw` already is. `DrawSystem.update` is called on it
every tick this boss is in P1, fed the mirror's own `isMoving` signal —
the Warden ramps under **exactly** the player's own rule set (same
thresholds, same tiers, same "moving resets it completely" cliff), because
it is quite literally driven through the same system, not a parallel
approximation of it.

**The moment it reaches Tier III, one heavy bolt fires
(`EnemyAttack.fireBolt`, the same primitive the ordinary Echo already
fires with) and `drawSeconds` resets to zero.** "Its own arc is visible" is
the telegraph — the ramp itself is the tell, exactly as the card states, so
no separate wind-up/circle telegraph sits on top of it. Rendering that arc
is left to a later UI pass, the same "sim provides the data, a renderer
consumes it later" split every other boss's own VFX gap already carries.

## Two real, deliberate scope cuts on an inherently large card

**"Using the player's own arrow type" is not implemented.** Porting
arrow-specific behaviour (pierce, elemental procs, hitbox scaling by tier)
onto an enemy body would mean threading the player's own arrow-resolution
pipeline through `EnemyAttack`, a materially larger redesign this pass does
not attempt — and docs/06 does not itself specify what that should even
mean mechanically (does a Frost arrow root the *player*? does pierce matter
against a single target?). The heavy shot instead reuses the ordinary
enemy damage model every other boss's own attack already uses (a fraction
of the player's own max HP), with that fraction **derived**, not
guessed: the Echo's own `attackDamage` (6%) scaled by Tier III's own
2.10x damage multiplier — the same number the multiplier already means for
the player's own arrows, applied to the one existing anchor closest in
spirit to "this enemy already fires a bolt at the player."

**"80% of the player's own stats" is not implemented either** — no hero,
no stat block, no Boon set exists to scale from an enemy body today. The
Warden's own health is the ordinary `Curves.bossHp`-scaled boss pool every
other fight already uses, not a fraction of anything the player brought
into the room.

## What's deliberately not built here

**P2 (lays Windlines, gains Confluence off them; crossing them slows the
player) and P3 (both Windline sets live; crossing the player's own line
through the Warden's own creates a Discord — a neutral detonation
damaging whoever is closer).** P3 especially needs a genuinely new idea:
a hazard whose *source* is a crossing between two independently-drawn
trail sets, not a single enemy's own attack — nothing in `WindlineStore`
or `HazardStore` today expresses "two lines intersecting" as an event.
Once `bossPhase` reaches 1, the mirror halts (`Steering.halt`, called
every tick rather than once at the transition, so nothing can leave it
drifting) and the Draw ramp simply stops advancing wherever it was — the
same posture every other boss's own undone phases already take.

**`BossRoomComposer` now maps chapter 4 to `hollowWarden`** — the eleventh
confirmation of ADR 0021's own predicted two-line integration cost, and the
last of the campaign's own first eleven chapters to get one. Both places
this session has kept an "unbuilt chapter" fallback test alive
(`stage_runner_test.dart`, `level_generator_test.dart`) now point at
chapter 12 — The Quiverfall, the only campaign boss left.

## Consequences

Eleven of the twelve campaign bosses now exist. The one remaining —
The Quiverfall, chapter 12, the finale — is a different kind of large: its
own P2 references all eleven other bosses by name ("all eleven previous
bosses appear as 12s echoes, one at a time, using a single signature
attack each"), so building it last, now that every other boss actually has
a signature attack to echo, is not just convenient scheduling but close to
a hard dependency.
