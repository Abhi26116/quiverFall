# ADR 0027 — Arclight: the chain runs through entities it creates, not itself

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 (grid-charging floor) and P3 (untargetable
orbit; four conduits; Confluence chaining) are not built — a known, flagged
gap.
**Severity** Medium. No new sim primitive at all — the first boss built
entirely by combining two *existing* mechanics end to end (Rift Maw's own
add-spawning, Cinder Choir's own tether sweep) rather than reusing one and
authoring a second half.

---

## What was missing

docs/06 §7, Arclight (chapter 7): "Tests: Storm, and spacing." P1: "Chains
lightning between itself and any active Swarmlings; killing adds breaks the
chain." Unlike every boss built so far, this mechanic is not something
Arclight's own body does — it is a relationship between Arclight and
entities that do not exist until the fight creates them. Nothing about P1
needed a new sim primitive; it needed two existing, unrelated ones wired
together for the first time.

## Decision — the add half is the Rift Maw, verbatim

The Rift Maw (docs/05 #22, chapter 3's own Riftborn elite) already does
exactly "tears open and spills Swarmlings on a fixed cadence, capped at 16
alive" — `RiftbornTree._riftMaw`/`_summon`, reading `EnemyCombat`'s own
`attackCooldown: 4.0`, `windUpSeconds: 0.5`, `spawnCount: 4`, `spawnCap: 16`
straight from `enemies.json`. `ArclightSystem._tickSpawns`/`_summon` is that
same cycle against the same `EnemySpawner.spawn`/`liveAdds`/`atEnemyCap`
machinery, with those same four numbers authored directly into the boss
system rather than read from an `EnemyCombat` record (a boss has none) — no
new spawning code, no new cap logic, no new cadence rule.

**The spawned Swarmling is a real, ordinary enemy** — `contentIndex >= 0`,
running its own `DriftTree._flock` behaviour every tick via the generic
`AiSystem`, unlike every other boss's own child so far (Cinder Choir's
effigies, Skarn's split bodies), which are all inert bare entities with
`contentIndex = -1` that no generic tree ever touches. This is the first
boss whose "child" is independently alive by the game's own ordinary rules.

## Decision — the chain half is Cinder Choir's own tether, aimed at a mover

`CinderChoirSystem._tickTetherSweep` (ADR 0019) already draws a warning
line, promotes it to lethal, keeps its damaging end updated every tick via
`EnemyAttack.retarget`, and gates one shared `damagePlayer` call behind one
cooldown, OR-ed across several simultaneous lines. Arclight's own
`_tickChains` is that same shape with one change: the sweeping tether's
"which way is it pointing now" question becomes "where did the Swarmling
walk to now" — `retarget`'s own contract (move the `toX/toY` endpoint,
leave the origin fixed) covers a wandering flock exactly as well as a
rotating angle, since Arclight itself never moves.

**One real difference from every prior chain/tether/aura in the roster: the
warning window is per-add, not boss-wide.** Cinder Choir's own tethers all
switch from warning to lethal at once, because P2 begins once, for
everybody, at the same moment. Swarmlings spawn staggered across the whole
fight — a Swarmling born at 40s into P1 deserves its own fresh warning, not
to inherit whatever state a Swarmling born at 4s already reached. So each
add's own chain telegraph lives on **that add's own `telegraphSlot`**, and
its own countdown lives on **that add's own `EnemyStore.bossTimer`** — a
different array index from Arclight's own `bossTimer[primary]`, which this
system repurposes as the shared damage-tick cooldown instead (the spawn
cadence already claimed `attackCooldown[primary]`, the field Cinder Choir's
tether used for that same role). Two boss-family fields, on two different
slots each, four uses, zero collisions — the pattern this session's ADRs
have been calling out since Skarn (0022) continuing to hold.

**Confirmed free before use, not assumed**: `DriftTree._flock` (the
Swarmling's own family-tree behaviour) touches `state`, `velX/velY`,
`facing`, and nothing else on its own slot — `stateTimer`, `attackCooldown`,
`comboStep`, and every `bossX` field are genuinely untouched by it, so
telegraph and timer bookkeeping on a live Swarmling's own row cannot be
stomped by its own movement AI running immediately afterward in the same
tick's `AiSystem.update`.

## "Killing adds breaks the chain" needed no code at all

`AiSystem._reap` already calls `EnemyAttack.endTelegraph` on every entity it
reaps, unconditionally — the same line that clears a Screecher's own
half-finished scream or a Cinder Choir effigy's own half-finished cone. A
Swarmling's own chain telegraph lives on its own slot, so its own death
already ends it, by a rule that predates this boss.

## A real, deliberate consequence: the boss room needs the adds gone too

`BossRoomComposer`'s own room-clear condition (ADR 0021) is "zero alive
`EntityKind.enemy` entities" — not "the boss died." An ordinary Rift Maw's
own summoned Swarmlings already outlive it under this same rule in a normal
room; Arclight's do too, deliberately not despawned on its own death or on
a `bossPhase` transition. A player who burns Arclight down while several
Swarmlings are still alive does not clear the room until those are also
dead — arguably the honest reading of "and spacing" continuing to matter
even after the boss itself falls, and consistent with how the Rift Maw
already behaves everywhere else in the game, rather than a special case
invented for this boss.

## What's deliberately not built here

**P2 (the arena floor charging in a grid, alternating cells on a 1.5s
cycle) and P3 (Arclight becomes untargetable and orbits; four grounded
conduits must be destroyed; Confluence chains between them, "the first
fight where the depth mechanic is dramatically better without being
required").** P3 especially is a real, larger piece of unbuilt work:
"untargetable while orbiting" needs the same `untargetable` flag Cinder
Choir's own invisible anchor already uses, but "four grounded conduits" are
a wholly new multi-target structure this pass does not attempt. Once
`bossPhase` reaches 1, spawning and every live chain stop — the same
posture every other boss's own undone phases already take.

**`BossRoomComposer` now maps chapter 7 to `arclight`** — the seventh
confirmation of ADR 0021's own predicted two-line integration cost.

## Consequences

Seven bosses now exist. This is the first one built with **zero** new sim
surface area — a genuine data point that the roster's own existing
primitives (summoning, line hazards, plate, shared pools, Draw-lock, root)
are starting to cover the boss list's own vocabulary faster than new
mechanics are needed. The next boss whose card names an *existing* enemy
family or mechanic by name — the way this one named Swarmlings and Storm —
is worth checking against that family first, same as every ADR since 0024
has been recommending.
