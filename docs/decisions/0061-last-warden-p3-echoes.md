# ADR 0061 — The Last Warden, P3: real echoes, not a bespoke mechanic

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P3 only. P1 (ADR 0059) and P2 (ADR 0060) are done;
P4-P5 remain.
**Severity** Medium-High. The one phase in this fight whose own card
depends on state the pure sim layer cannot itself hold.

---

## What was missing

docs/06 §6.3, The Last Warden, P3: **"Summons echoes of three bosses the
player has beaten most often (read from telemetry)."**

## Decision — telemetry resolution stays outside the sim; the echo itself is free

`lib/game/sim` is deliberately pure (`test/guards/architecture_guard_test
.dart`'s own "sim purity" check enforces it) — it never reads save data,
so it cannot itself consult `Progression.bossKillCounts` (the field
already exists for exactly this, added early and never wired up until
now — dormant, not built). Resolving "the three bosses beaten most often"
is therefore the caller's own job, the identical "test/tool entry point,
real work happens elsewhere" split every other `SimWorld.spawnX` wrapper
in this roster already draws. `LastWardenSystem.spawn` accepts
`echoArchetypes`, up to three already-chosen `BossArchetype` values;
wiring an actual `StageRunner`-side read of `Progression.bossKillCounts`
into that parameter is deferred with the rest of the Endless tier's own
spawn-path integration (ADR 0017 — none of Mother of Motes, The Loom, or
Coilspine have that wiring either).

**The echo itself needed no new mechanic at all.** Each archetype named is
spawned through *that boss's own real `System.spawn`* — not a
generic/simplified stand-in. Since every boss system in this roster reads
`bossIndex`/`archetype` off a plain table scan (`for every alive enemy,
if its archetype matches mine, tick it`), never caring how or by whom an
entity was created, an echo spawned this way is picked up automatically
by its own already-existing, already-tested system the instant it
appears — the same discovery that made Elite-tier integration (ADR 0055)
cheap. Scaled to 8% of the Warden's own max health (three simultaneous
full-HP bosses is not what "echo" reads as) and placed in the same small
triangle staging shape Cinder Choir's own effigies and Rimefather's own
mirrors already use.

## Scope of the dispatcher

`_spawnEchoOf` covers the twelve built campaign archetypes plus Ashen
Choir — every boss with a real `spawn` function to call. The three
still-unbuilt Elite/Event bosses (Umbral Twin, Bellweather, the Pale
Judge) have none; the other three Endless-tier archetypes (The Loom,
Coilspine, Mother of Motes) and the Warden's own are excluded as not what
"beaten most often" plausibly names for a boss fought at floor 100+. Any
archetype outside that set — or an empty slot, the honest state for a
save with fewer than three distinct boss kills — is silently skipped
rather than guessed at.

## Storage

The three chosen archetypes are stashed as plain indices in three
otherwise-free per-primary `EnemyStore` fields at spawn time
(`comboStep`, `bossActiveChildIndex`, `bossChildIndex` — none used by P1
or P2, and a primary has no children of its own to need `bossParent`-
adjacent fields for). `state` (also free — this boss has no wind-up
cycle) doubles as the one-time "already spawned" latch, checked once
`bossPhase >= 2`.

## Verified end to end

Five new tests, seventeen total for this boss: no echoes exist before P3
even with archetypes given; once P3 begins, every given archetype
appears as its own real, independently-alive boss at exactly the
authored health fraction; echoes are spawned exactly once across many
ticks, not re-summoned; fewer than three archetypes leaves the remaining
slots genuinely empty rather than filling them with something invented;
and an archetype with no dispatcher case does not crash the tick. All
five passed on the first real attempt.

## Consequences

P4 (the arena floor removed, Windline-drawn platforms as terrain) and P5
(one HP each, 20s sudden death) remain entirely unbuilt. Wiring
`Progression.bossKillCounts` into an actual `echoArchetypes` argument at
a real spawn call site is tracked alongside the rest of the Endless
tier's own deferred floor-depth gating (ADR 0017), not attempted here.
