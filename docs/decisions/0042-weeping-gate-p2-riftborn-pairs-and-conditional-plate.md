# ADR 0042 — The Weeping Gate's own P2: Riftborn pairs and a conditional plate

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2. P3 ("all portals open at once, permanently; a
40s survival check while burning the core") is not built — a known,
flagged gap.
**Severity** Medium. The first P2 in this roster read as a genuine
*replacement* of its own P1 logic rather than an addition to it, and
introduced a live-population-gated defensive mechanic (a plate that opens
and shuts based on how many other enemies are currently alive) that no
other boss in the roster has needed yet.

---

## What was missing

docs/06 §10, The Weeping Gate: P1 (ADR 0030) already resolved the roster
escalation and the four-plate-quadrant reveal is P3's own gimmick. P2's own
card: "Portals now spawn Riftborn elites in pairs. The Gate's own plating
opens only while fewer than three enemies are alive — a deliberate tension
between clearing adds and racing." Two separate mechanics on one card: what
spawns, and when the body can be hit at all.

## Decision 1 — P2 replaces the spawn logic, it does not add to it

Every other P2 built this session ("Remaining sigils accelerate...",
"lays Windlines...", "Momentum stronger on ice...") read as *additive* —
P1's own mechanic keeps running, unmodified, with something layered on
top. This card reads differently: "Portals **now** spawn Riftborn elites
**in pairs**" describes the SAME spawn system doing something different,
not a second system running alongside the first. `_tickSpawns` gained an
`inP2` parameter that switches which content pool and which cadence apply
(`_riftbornIds`/`_p2SpawnIntervalSeconds` vs. `_rosterIds`/
`_spawnIntervalSeconds`), and which summon function resolves the wind-up
(`_summonRiftbornPair` vs. `_summon`) — the wind-up/telegraph machinery
itself (`EnemyAttack.beginCircle`, the portal's own committed x/y read
back via `ctx.telegraphs.xAt`/`yAt`, per the trick this boss's own P1
already established) is untouched and shared by both.

`_summonRiftbornPair` spawns two enemies, drawn independently (with
replacement) from the four Riftborn archetypes docs/05 names as chapter
3/5/7/8 elites (`riftMaw`, `echo`, `gravebound`, `nullborn`), offset 0.4u
either side of the portal's own position so they don't land fully
stacked.

## Decision 2 — the plate reuses Gaunt's own flat-factor trick, gated live

Reading `ProjectileSystem._armourFor` directly (rather than guessing) is
what this segment's prior cutoff was mid-way through, and it settled the
shape here: `isPlated()` requires `plateHealth[slot] > 0`, and
`plateFlatFactor` is only consulted when it reads greater than zero — a
literal `0.0` silently falls through to the ordinary tiered plate switch
instead of blocking damage outright. `spawn()` sets `plateHalfArc = pi`
(the whole body, no directional gap) and `plateFlatFactor = 0.0001` once,
permanently, for the fight's whole lifetime — a tiny positive epsilon that
reads as "as close to invulnerable as the armour system allows" without
ever tripping that fallthrough. The only thing that changes turn to turn
is `plateHealth` itself: `0` (unplated, since `isPlated` requires it
strictly positive) while open, `maxHealth[primary]` (plated, matching
every other boss's own "shed the whole plate pool to break it" plate
convention) while shut.

A new `_tickPlate`, called every P2 tick, counts every currently-alive
`EntityKind.enemy` entity in the room excluding the primary's own slot —
**every** enemy, not just this boss's own Riftborn spawns, matching the
card's own plain "fewer than three enemies" wording rather than a
narrower "fewer than three Riftborn" reading — and sets `plateHealth`
accordingly: open below `_plateOpenBelowEnemyCount` (3, the card's own
number), shut at or above it.

## The freeze boundary migration, again

The now-familiar move: this boss's own pre-existing "stops past P1" test
lived at `bossPhase >= 1`; P2 landing means that boundary now means "P2 is
live," so the freeze moved to `bossPhase >= 2`, with the plate forced back
open (`plateHealth = 0`) added to that branch alongside the existing
telegraph-clearing, so a run frozen mid-P2 (for a scripted cutscene, or a
dev/debug tool) never leaves the Gate permanently unhittable.

## Consequences

Eight of twelve campaign bosses now have some form of P1+P2. This is the
first P2 that reads as a genuine replacement of P1's own logic rather than
an addition — worth checking for on any future card that says a mechanic
happens "now" (implying a change to something ongoing) rather than
"also"/"gains"/"adds." It's also the first defensive (damage-gating,
not damage-dealing) P2 mechanic in the roster, and the first keyed to a
*live population count* read fresh every tick rather than an authored
timer or fixed angle — worth reaching for again the next time a card
describes a state that depends on the room's own current contents rather
than the boss's own internal clock.
