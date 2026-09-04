# ADR 0028 — The Green Mother: the DPS check is free; a latent crash wasn't

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 (telegraphed root-eruption lines; stacking
poison on contact) and P3 (an 8s-cycle exposed-core window) are not built —
a known, flagged gap.
**Severity** Medium. Zero new sim primitives for the boss itself, but a
real, previously-latent crash bug in existing shared code
(`ChoirTree._isAlly`) was found and fixed getting here — the first time any
boss has put a Choir-family enemy in the same room as a boss body.

---

## What was missing

docs/06 §8, The Green Mother (chapter 8): "Tests: Toxin, and DPS checks."
P1: "Spawns Knitters continuously; the Mother heals from each. A raw DPS
check — fail it and the fight is literally unwinnable, which the game
states outright in the death screen." Structurally this is Arclight's own
add-spawning half again (ADR 0027) with no line-hazard mechanic layered on
top — `GreenMotherSystem` is *only* the Rift Maw's own wind-up→spawn→
cooldown cycle, authored to read as a steadier trickle (one Knitter/1.0s,
authored — not GDD-stated) rather than the Rift Maw's own periodic bursts,
still capped at 16 (the same "beyond this a phone screen is unreadable"
number, reused again).

## Decision — the healing itself needed no code at all

The Knitter (docs/05 #21) already heals "4% max HP/s to all allies within
4u" via `AiSystem._applyAuras`/`_heal`, built for Phase 9's ordinary roster
and used by nothing boss-related until now. That pass heals *any* alive
`EntityKind.enemy` entity within a Knitter's aura radius — it does not
check family, and does not check whether the healed entity has a content
definition at all. Spawn a real Knitter close enough to the Mother's own
body and she is healed by it, automatically, the instant it exists — no
call from `GreenMotherSystem` required. `_heal` already runs every heal
through `ctx.status.healingMultiplier`, which is Toxin's own
healing-reduction hook — so both of this card's own stated lessons (Toxin,
and the DPS check) are true from systems this pass did not touch at all.

**Multiple simultaneous Knitters correctly stack.** `_applyAuras` iterates
every aura-bearing entity independently and applies each one's own heal
separately — N live Knitters near the Mother contribute N times the heal,
which is exactly the "the longer this goes on, the harder it gets" pressure
the card's own wording describes. This was checked directly rather than
assumed: `green_mother_system_test.dart`'s own "more live Knitters heal
faster" test spawns several against a single Knitter under matched
conditions and confirms the difference.

## A real, previously-latent crash, found and fixed before it could ship

`ChoirTree._isAlly` (used by every Choir-family unit's own ally-seeking —
the Knitter's own "move to the most-damaged ally", the Weaver's shield
target, the Warden-Fell's pack centroid) called `ctx.definitionOf(other)`
**unconditionally** to read the candidate's own family, to exclude
Choir-on-Choir healing loops. `definitionOf` indexes `content.enemies` with
`entities.contentIndex[other]` — and every boss's own body has
`contentIndex = -1` since Phase 11's very first commit (ADR 0017). Nothing
had ever put an ordinary Choir-family enemy in the same room as a boss
before this fight, so the crash was unreachable until it wasn't: the very
first time a spawned Knitter's own `_mostDamagedAlly` search found the
Mother within range, `content.enemies[-1]` throws a `RangeError`.

Caught by writing the regression first: `enemy_behaviour_test.dart`'s own
new "a Knitter can seek and heal a definition-less entity... without
crashing on its own family check" test reproduced the exact `RangeError`
against `ChoirTree._isAlly` before any fix, using nothing Green-Mother-
specific — a bare `SimWorld.spawnAt` entity and an ordinary Knitter. Fixed
by guarding the `definitionOf` call behind `ctx.hasDefinition(other)`: a
bare entity has no family to exclude by, and is trivially a valid ally.
This is a fix to shared, pre-existing code, not to anything this boss's own
system contains — every future boss that wants a Choir-family add (or any
enemy near a Warden-Fell's suppression aura, or a Weaver's shield) benefits
from it too.

## What's deliberately not built here

**P2 (roots erupting along telegraphed lines; contact applying stacking
poison to the player) and P3 (retracts into a bloom; a 3s exposed-core
window every 8s, everything else invulnerable; "burst positioning
check").** P3 especially needs a new idea: "everything else is
invulnerable" is a state no boss built so far has needed — a body that
exists, can be targeted, but takes zero damage outside a specific window.
Once `bossPhase` reaches 1, spawning stops — the same posture every other
boss's own undone phases already take. Any Knitter still alive is not
despawned, the same "an add outlives its summoner" posture Arclight's own
Swarmlings already established (ADR 0027).

**The exact spawn cadence (one Knitter/1.0s) is an authored placeholder,
not a tuned one.** Whether a given power level can actually out-DPS this
rate before it becomes "literally unwinnable," as the card demands, is a
balance-harness question (Phase 14) this pass cannot answer — the same
category of honestly-flagged gap ADR 0025's own puddle cadence and ADR
0017's own Endless-boss numbers already are.

**`BossRoomComposer` now maps chapter 8 to `greenMother`** — the eighth
confirmation of ADR 0021's own predicted two-line integration cost.

## Consequences

Eight bosses now exist. The second boss in a row (after Arclight) requiring
zero new sim primitives of its own — and the first to surface a real bug in
*shared* code rather than in a boss system, simply by being the first to
combine two existing pieces (a boss body, a Choir-family aura unit) that
had never previously coexisted. Worth remembering for whatever boss comes
next: composing two existing mechanics is not risk-free just because
neither one is new.
