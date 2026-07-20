# ADR 0003 — Enemy behaviour model

**Phase** 5
**Date** 2026-07-20
**Status** Accepted
**Severity** Structural. Every boss in Phase 11 is built on this.

---

## Context

Phase 5 had to deliver all 26 enemies from [05](../05-enemies.md), fully
data-driven, plus spawning and the composition rules — without turning the
simulation into a switch statement with 26 arms and no shared vocabulary. The
constraint that shaped every decision below is that **Phase 11 adds 20 bosses**,
each with three phases and a bespoke attack scheduler, and every one of them
reuses this machinery. Anything convenient-but-special-cased here becomes twenty
copies of itself later.

## Decisions

### 1. The content `id` *is* the archetype

`assets/data/enemies.json` has no separate `archetype` field. `id` is parsed
directly into `EnemyArchetype`, so an enemy that is not in the enum cannot be
authored, and an archetype with no data cannot ship. The redundant `family` key
is kept for readability and cross-checked by the loader.

**Rejected:** a free-text id plus a behaviour key. It permits exactly one bug —
data and behaviour drifting apart — and that bug surfaces as "the chapter 7 elite
acts like a Mote", which is close to undiagnosable from a player report.

### 2. Behaviour *switches* live in code; behaviour *numbers* live in JSON

Whether a Lancer charges is an enum arm. How hard, how far, how long it
telegraphs, and how long it lies vulnerable afterwards are all table values.
This is what makes the remote-config overlay safe: live-ops may retune any
enemy's difficulty and cannot change what an enemy fundamentally does.

A third category — the *shape* of a behaviour rather than its strength (flocking
weights, the Wisp's oscillation, the Ripper's stagger threshold) — lives in
`lib/game/balance/enemy_tuning.dart`. It is swept by the Phase 12 harness but not
exposed to remote config, for the same reason.

### 3. Six family trees over one nine-state machine

Every enemy runs the same `AiState` machine; the family tree decides which
states it uses. The payoff is that the telegraph rule becomes *structural*:
`windUp` is the only state from which damage may be scheduled, so an attack
without a wind-up is difficult to write rather than merely discouraged. The
content loader enforces the same rule from the other side, and
`enemy_content_test.dart` names the two documented exemptions (Thresher, Echo).

### 4. Telegraphs are owned by the simulation, not the renderer

`TelegraphStore` lives in `lib/game/sim/`. A wind-up duration is balance and a
telegraph's shape is a hitbox, so the headless harness has to be able to measure
both, and a replay without a renderer has to behave identically.

Three shapes — circle, line, cone — cover the entire roster and every boss in
[06](../06-bosses.md). Two severities, amber and crimson, and the vocabulary is
never violated: amber means "about to happen", crimson means "standing here
damages you now".

**Consequence:** a dropped telegraph is an undodgeable attack, so
`TelegraphStore.dropped` is counted and the soak test asserts it stays zero.

### 5. One death routine, in `AiSystem`

Deaths are resolved in a single pass at the end of the AI system. The projectile
system and the element system leave corpses; they do not reap them.

This is the only arrangement in which a Cinder Mote detonates, a Gravebound goes
down instead of dying, and a Twinned variant splits *regardless of which system
landed the killing tick*. The alternative — each damage source handling death —
was tried first and immediately produced two death paths that disagreed about
whether Frost suppresses a detonation.

`ElementSystem` keeps a `deferDeath` flag so it can still be unit-tested
standalone; the world always sets it.

### 6. Freeze is resolved centrally

`AiSystem._freeze` stops movement, cancels any wind-up, and clears any temporary
speed buff. Three separate documented interactions — Frost suppresses a Cinder
Mote's fuse, cancels a Lancer's charge, cancels an Ironmaw's enrage — fall out of
one rule rather than three archetypes each remembering to check.

Airborne and downed states are exempt: a Bounder mid-leap has to land (freezing
it would leave it permanently untargetable) and a corpse is not steering.

### 7. Enemy ordnance is not entities

`HazardStore` is separate from `EntityStore`. Hazards never collide with each
other, never take damage and are never targeted, so putting them in the entity
pool would mean every system filtering them out of every query — and would let a
dense Mortarite room exhaust the pool that enemies and arrows share.

### 8. The composition rules are a validator, not care inside the generator

`RoomComposer` satisfies [05 §5.7](../05-enemies.md) structurally — the
safe-threat floor is met by allocating the budget in two parts before anything is
picked — and `CompositionValidator` checks the result anyway.

That is not redundancy. The validator is what makes Phase 8's level generator,
remote-config retuning, and hand-authored rooms all subject to the same rules,
and it is what lets the test suite assert 10,000 generated rooms break none of
them.

## Open questions for later phases

- **Plate health is a flat 45 % of max HP** (`EnemyTuning.plateHealthFraction`).
  It has not been playtested. Phase 6 should confirm that a Tier-I plinker
  breaking a Husk's plate feels like a slow correct answer rather than a
  punishment.
- **The Husk's 110°/s turn rate** is what makes flanking possible, and it is a
  guess. Phase 6 measures whether players actually flank or simply Draw.
- **Variant threat multipliers** (1.30–1.55) are unvalidated. Phase 12's harness
  is the first point at which chapters 9–12 can be measured rather than
  estimated.
- Elemental application currently ignores `ElementTuning.emberApplyChance` and
  applies on every hit that carries an element. Phase 10 owns arrow elements and
  should introduce the roll — including Tier III's guarantee.
