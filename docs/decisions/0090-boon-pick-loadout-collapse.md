# ADR 0090 — A Boon pick was silently discarding the hero and arrow

**Phase** Found during Phase 12 harness work; a live gameplay bug, not a
harness gap.
**Date** 2026-09-05
**Status** Resolved.
**Severity** Critical. Affects every real run, from the moment the very
first Boon is taken — which is to say, almost the entirety of real play
time.

---

## What was wrong

`LoadoutResolver.apply`'s own doc comment states the contract plainly:

> The `base*` values are the loadout *before* Boons: hero, arrow, Spire,
> research and ascension already composed. They are passed rather than read
> back off the world so that applying twice is idempotent.

`HeroLoadoutResolver.apply` honours this — it composes `heroAtk *
arrowBaseMult` (and the matching fire-rate/max-HP/move-speed baselines) and
passes them in as `base*` every time it runs. But `StageRunner.pickBoon`,
the method every real Boon Choice screen calls, is a *second* caller of the
same contract — and it was hardcoding:

```dart
LoadoutResolver.applyBuild(
  world,
  boons,
  baseAttack: lawfulAttackFor(plan.blueprint.globalStage),
);
```

`lawfulAttackFor` is `stage_runner.dart`'s own pre-Phase-10 placeholder — "a
generic attack that lands TTK in band, for callers with no hero to supply."
`StageRunner` was written before heroes and arrows existed as a real system;
`pickBoon` was never updated when Phase 10 added them. The other three
`base*` parameters (`baseFireRateMultiplier`, `baseMaxHealth`,
`baseMoveSpeed`) were not passed at all, silently taking `applyBuild`'s own
generic defaults (`1.0`, `100.0`, `SimConfig.playerMoveSpeed`).

Since `LoadoutResolver.apply` **replaces** `world.playerAttack` outright
(`world.playerAttack = baseAttack;` — deliberately not multiplied by
anything, so a hero's own composed value can't be double-counted against a
Boon's separate damage-sum term), every one of those four fields was
completely overwritten, not merely left un-augmented, the instant a player
picked their first Boon of a run. Measured directly: a Wren build at level
40/★3 with a Broadhead reads `playerAttack = 751.16` right after
`HeroLoadoutResolver.apply`; the moment `pickBoon` runs once, it drops to
`223.24` — the same number a fresh, unbuilt account would have gotten with
no hero and no arrow at all.

This was invisible to the existing suite for an exact, checkable reason:
`stage_runner_boons_test.dart` never calls `HeroLoadoutResolver.apply` at
all — every one of its scenarios starts from `buildStageWorld`'s own
hero-blind `lawfulAttackFor` baseline, so `pickBoon`'s overwrite is a
complete no-op there (it was already at that value). No test in the whole
suite exercised "apply a real hero+arrow build, then pick a Boon via
`StageRunner`" together before this one.

## Decision — `StageRunner` remembers its own base loadout

`HeroLoadoutResolver.apply`'s return type changes from `void` to the same
four `base*` values it already computes and hands to `LoadoutResolver.apply`
— nothing new is derived, the numbers were already sitting in local
variables with nowhere to go. All 89 existing call sites use it as a plain
statement, so this is a non-breaking change.

`StageRunner` gains `setBaseLoadout({baseAttack, baseFireRateMultiplier,
baseMaxHealth, baseMoveSpeed})`, storing the four values in private fields
that default to exactly today's placeholder behaviour
(`lawfulAttackFor(plan.blueprint.globalStage)`, `1.0`, `100.0`,
`SimConfig.playerMoveSpeed`) — every existing test and tool that never calls
it is unaffected. `pickBoon` now reads from those stored fields instead of
recomputing the hero-blind placeholder fresh. `GameScreen._start()` forwards
`HeroLoadoutResolver.apply`'s own return value straight into
`runner.setBaseLoadout(...)`, right after applying the real build — the one
call site in the whole app that constructs a `StageRunner` with a real hero.

`LoadoutResolver.applyBuild` also gained the two `base*` parameters it was
missing (`baseFireRateMultiplier`, `baseMoveSpeed`) — it already accepted
`baseMaxHealth` but not the other two, both defaulting to `apply`'s own
existing defaults so its other callers (two test files, `baseAttack`-only)
are unaffected.

**What this does not fix**: a hero's own passive/talent/ultimate
`StatChannel` modifiers (Wren's crit chance, a talent's move-speed bonus,
anything composed into `HeroLoadoutResolver.apply`'s own `combined` object
beyond the four base scalars) are still not part of what `pickBoon`
recomposes — it rebuilds from `boons.stats` alone, not `combined`. This
narrower gap is real but far less severe: unlike the four base scalars, it
degrades a hero's own kit contribution on the affected channels rather than
replacing the entire loadout with a stranger's build, and closing it needs
`StageRunner` to hold onto the *whole* composed `BoonStats` object (or for
`HeroLoadoutResolver` and `BoonInventory` to share one), not just four
numbers — a larger, separate piece of work, flagged here rather than
attempted alongside a critical-severity fix.

## Verified

`test/game/stage_runner_boons_test.dart`'s new "a real hero+arrow loadout
survives a Boon pick" group: confirms the hero-composed attack is nowhere
near the placeholder (so the other assertions cannot pass by coincidence);
pins the *old* behaviour as a live regression check when `setBaseLoadout` is
deliberately not called (documents exactly what used to happen, so a future
refactor that reintroduces this cannot do so silently); confirms
`playerAttack` survives a pick bit-for-bit with `setBaseLoadout` wired, and
that `fireRateMultiplier`/move speed land on the *correct* post-Boon value
(hero baseline × whatever the drawn card now contributes — not asserted
unchanged, since a card touching those channels is legitimate); confirms
survival across three consecutive picks, not just the first. Full suite:
1485 passed (1481 + 4 new), 1 pre-existing skip, 0 failures.

## Consequences

Every real run's damage, fire rate, max HP and move speed now stay
hero-and-arrow-correct for the run's entire length, not just its first room.
Given Boon picks happen after nearly every room, this is the difference
between Phase 10's hero/arrow system mattering for one room in twenty and
mattering for the whole game. The narrower `combined`-channel gap above is
left as a known, flagged follow-on.
