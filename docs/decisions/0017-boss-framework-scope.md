# ADR 0017 — The boss framework's first slice: content + phase machine, not a fight

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for what this slice covers. What it deliberately does not
cover is listed below, not silently missing.
**Severity** Low. Every number here is either taken straight from docs/06 or
flagged as an inferred placeholder nothing yet reads for real gameplay
consequence.

---

## What was missing

Nothing in the codebase read or handled `RoomKind.boss` — no content model, no
phase state, no spawn path. Phase 11's roadmap line is "20 total bosses...
telegraph choreography... bespoke arenas" — a twelve-day estimate spanning
work this session cannot respect by rushing all of it into one pass, so this
ADR scopes the *first* slice rather than the whole phase, the same posture
ADR 0013/0015/0016 already took for their own tasks.

Two real, favourable discoveries shaped that scope. `lib/game/sim/telegraph.dart`
and `hazard_store.dart` already exist, are already generic, and are already
explicitly documented as meant for every boss — the roadmap's "telegraph
choreography" bullet is largely pre-built. `Curves.bossHp` — docs/06 §6.0's
exact `HP(G) · bossMult · (1 + 0.06 · encounterCount)` formula — already
exists in `lib/game/balance/curves.dart` too, unused until now. What did not
exist anywhere was a boss *content* model and the one mechanic true of every
boss regardless of its own fight: "three phases minimum, with a hard visual
and musical transition at 66% and 33% HP" (docs/06 §6.0 rule 1).

## Decision

**Built:** `BossArchetype`/`BossDefinition`/`BossCatalogue`
(`lib/game/content/boss_definition.dart`, `boss_catalogue.dart`), deliberately
leaner than `EnemyDefinition` — a boss's fight is bespoke code, not
data-driven numbers plugged into a shared family tree, so the content row
only carries what's true regardless of what the fight does: identity, tier,
chapter, HP multiplier, target duration, phase thresholds.
`assets/data/bosses.json` carries all 20, `ContentLibrary.bosses` loads it at
bootstrap alongside `heroes`/`arrows`/`affixes`. `BossPhaseSystem`
(`lib/game/sim/systems/boss_phase_system.dart`) advances
`EnemyStore.bossPhase` as `EntityStore.health/maxHealth` crosses
`BossDefinition.phaseThresholds`, slotted into `SimWorld.tick` right after
`element` (a DoT tick can cross a threshold exactly like a direct hit) and
before `ai` (so a boss's own family tree reads this tick's phase) —
`SystemOrder` and its guard test both updated. `SimWorld.spawnBoss` is the
test/tool entry point, built on the bare `spawnAt` path rather than
`EnemySpawner.spawn` since a boss has no `EnemyDefinition` to pull radius or
speed from.

**Two numbers in `bosses.json` are inferred, not stated, and both are flagged
in code comments pointing back here:**

1. **Three Endless bosses have no per-boss duration.** docs/06 §6.3 states an
   exact duration for every campaign, elite and event boss, and for Endless
   boss #20 (The Last Warden, 150s) — but #17-19 (The Loom, Coilspine, Mother
   of Motes) only ever get the tier's aggregate "90-150s" range in the §6.4
   summary table. Rather than invent a number nothing anchors, their own
   `targetDurationSeconds` is left absent — the field is nullable for exactly
   this reason (`BossDefinition.targetDurationSeconds`'s own doc comment).
   Nothing reads it yet, so this costs nothing today.

2. **The Last Warden's own phase thresholds are not stated.** docs/06 §6.3
   says "Five phases, not three" but gives percentages for none of them —
   worse, P5 ("One HP each. Pure duel... sudden death") is not a
   fractional-HP transition at all, it is an absolute-value end state that
   this ADR's threshold model cannot express. `bosses.json` fills in
   `[0.8, 0.6, 0.4, 0.2]` — an even split of the default 66/33 spacing
   pattern, invented for structural completeness only. **When The Last
   Warden is actually built, P1-P4's real thresholds and P5's sudden-death
   rule both need their own design pass**, not this placeholder promoted
   silently to real.

## What's deliberately not built here

**No boss has a fight.** `BossPhaseSystem` advances a phase number; nothing
yet reads that number to change an attack pattern, split a body, or invert a
rule. Building Cinder Choir's actual "only the lit effigy is vulnerable,
rotating every 6s" mechanic — the multi-body/shared-vulnerability question
this session weighed and did not resolve — is real, boss-specific design and
code, the same category of work as a single hero's kit, and belongs in its
own pass with its own tests, not bundled into the generic primitive's own
commit. **Update, same day:** that pass happened next — see ADR 0018, which
resolved the question this paragraph left open (a shared pool across several
physical bodies, `EnemyStore.linkedHealthSlot`) for P1/P2. P3 is still open.

**No spawn integration.** `RoomKind.boss` still spawns nothing — `spawnBoss`
is a direct test/tool entry point, not wired into `room_composer.dart` or
`StageRunner`. A real boss room needs an arena, an entrance, and (per docs/06
§6.0) a hitbox and movement `BossDefinition` intentionally does not carry —
see its own doc comment. That wiring is the natural next slice once a boss
actually has a fight to spawn into.

**No VFX/audio for the phase transition itself.** `SimEventType.bossPhaseChanged`
fires; `FeedbackDirector` and `FeelTelemetry` both have an explicit no-op
case for it (comment points here) rather than a placeholder screen-shake —
docs/06 rule 1's "hard visual and musical transition" is real presentation
work that wants an actual boss's actual look to cut to, not a generic flash
built ahead of any boss needing one.

**`tool/validate_content.dart` still only validates `enemies.json`.** This
predates bosses — `heroes.json`/`arrows.json`/`affixes.json` were left out
when each was added too — so `bosses.json` joining that same gap is
consistent with existing precedent, not a new one. Widening the build-time
validator to cover all five content files is a real follow-up, better done
once (covering all of them) than piecemeal per content type.

## Consequences

The next boss-framework slice has a clear starting point: pick one boss
(Cinder Choir, chapter 1, is the thematically obvious one) and build its
actual phase-conditional attack behaviour, reading `EnemyStore.bossPhase`
the same way a family tree already reads `EnemyStore.state`. The multi-body
question (Cinder Choir's three effigies, Skarn's 1→2→4 split, Coilspine's 24
segments) is real design work every one of those bosses will re-raise; this
slice deliberately spent no effort resolving it in the abstract ahead of a
concrete first case forcing the answer.
