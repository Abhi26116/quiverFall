# ADR 0089 — The TTK harness's "expected power", and what it finds

**Phase** 12 (balance harness & CI), Part 1 — the TTK half of docs/02 §2.6.
**Date** 2026-09-05
**Status** Resolved, with one finding carried forward as a documented,
skipped CI gate rather than a silent pass.
**Severity** High. Defines the loadout every TTK reading in this codebase
will be taken against, and the one real balance signal it produces cannot be
made to disappear by picking different numbers here.

---

## What was missing

Phase 12 is "make balance a test rather than an opinion." docs/02 §2.6 gives
the TTK Law's exact math (`HP(G) = 44 · growth(G)`, already `Curves.enemyHp`)
and says the harness must measure DPS "for a player at the *expected* power
for that stage," defined as:

> hero at chapter level cap, Spire nodes at the tier band unlocked by that
> chapter, one crafted arrow of matching tier, and an average Boon draw at
> room 5.

Two of those four terms are exact, already-shipped formulas, not gaps at
all:

- **"Hero at chapter level cap"** is `Curves.heroLevelCap(chaptersCleared)`
  — already the real cap `hero_workshop.dart` enforces. A player now playing
  chapter `c` has cleared `c - 1` chapters, so this is
  `Curves.heroLevelCap(c - 1)`, no approximation needed.
- **"One crafted arrow"** — docs/08 uses "crafted" for an unrefined copy
  (refinement, I-V, is a separate per-copy axis). `ArrowInstance`'s own
  `refineLevel` already defaults to 0, which is exactly "crafted", not a
  stand-in for it.

Two terms are genuine gaps:

- **Star tier** has no chapter schedule anywhere in the GDD — only the
  shard-cost table (docs/04 §4.3), which prices tiers, not when a player is
  expected to reach one.
- **"Matching tier" arrow** — `ArrowContentTier` (t1-t4) is real content,
  but nothing states which chapters each tier "matches", and three of the
  four tiers have no single plain/elementless arrow to default to.

And one term is not a gap in the harness at all — it names a system that
does not exist yet:

- **Spire nodes at the tier band** — there is no Spire implementation
  anywhere in `lib/`. docs/04 §4.2 documents it as a 24-node meta-progression
  tower; the roadmap places it at Phase 13, one phase *after* this one.

## Decision — resolve what can be resolved, model zero for what can't yet

**Star tier floors at 1** (`ExpectedPower.heroStarsFloor`), the lowest tier a
hero can be at all. With no schedule to author from the GDD, floor is the
only value defensible without inventing one — and it is conservative in the
correct direction: any real player has *at least* this much star power, so
this cannot make a real fight look artificially fast.

**Matching-tier arrow, by chapter, from the boss-reward material schedule
docs/06 already gives**, not authored from nothing. Chapters 1-2 pay T1
mats, 3-6 pay T2, 7-9 pay T3, 10-12 pay T4 (`docs/06-bosses.md`'s own reward
lines) — the harness's chapter→tier boundary is exactly that schedule.
Within a tier, the plain arrow when one exists (T1: Ash Shaft); otherwise
the arrow with no bespoke coded [`ArrowBehaviour`], so a DPS-curve reading
is not skewed by one arrow's own mechanic (T2: Emberhead — all four T2
arrows are elemental, Emberhead's Ember is the doc's own first-listed
element; T3: Lancehead, the only T3 arrow with no `ArrowBehaviour`, versus
Skimmer's ricochet and Twinfang's converging split; T4: Ghostshaft over
Prismshaft — every T4 arrow carries a behaviour, and Prismshaft's own
element-cycling is inseparable from the Reactions system this Part 1 does
not model at all, where Ghostshaft's phase behaviour has no interaction with
per-hit damage).

**Spire contributes nothing** (`ExpectedPower`'s own doc comment states this
explicitly rather than picking a number to stand in for it). This is not the
same shape of approximation as the two above — there is no reasonable
non-zero value to author here that would not amount to re-deriving the
Spire's entire balance ahead of Phase 13 actually building it. Zero is
honest about what is missing, and it is conservative the same direction as
the star floor: omitting a source of *more* power cannot make a reading look
artificially fast, only artificially slow (or, as it turns out below,
artificially *very* slow).

**Average Boon draw at room 5 is not modelled in this Part 1 at all.**
`TtkProbe` measures the loadout alone against one fresh
[`EnemyArchetype.mote`] — no room, no run, no Boons. A later Part of this
phase adds `HarnessBot`, extending the proven root-then-roam bot in
`stage_runner_test.dart` with boon auto-picking via
`StageRunner.pickBoon`, to fold this fourth term in.

**Reference hero: Wren.** Every reading in `TtkProbe` uses her specifically
— no elemental application, chain, or AoE hook of her own to skew a
measurement meant to characterise the campaign's curve rather than any one
hero's kit, the same reasoning behind picking each tier's least-exotic
arrow.

**What does vary across the "seeded runs"**: with Boons out of scope for
this Part 1, nothing about the loadout itself is random — but the fight
still is not deterministic. `DamageResolver`'s crit roll, and Emberhead's
own Ember application chance, both draw from the world's seeded RNG per
hit. Sweeping the seed is what turns "one fight" into the actual
distribution docs/02 asks for, even before Boons are added.

## What the harness found, run as designed

Running `TtkHarness.measureChapter` for every campaign chapter, sampling
each chapter's own hardest common-enemy HP (its boss stage, global stage
`20·chapter`):

| Chapter | Global stage | p50 TTK | Hard band [0.6, 2.2]? |
|---|---|---|---|
| 1 | 20 | 0.55 s | fails low, by 0.05 s |
| 2 | 40 | 0.90 s | passes |
| 3 | 60 | 1.40 s | passes |
| 4 | 80 | 2.43 s | **fails high** |
| 5 | 100 | 3.60 s | **fails high** |
| 6 | 120 | 5.60 s | **fails high** |
| 7+ | 140+ | *(timeout, >12 s)* | **fails high** |

This is not a harness bug. docs/02 §2.6 states the derivation chain
outright: *"enemy HP curve → required player DPS curve → required power
level curve → **required Spire investment** → required gold → gold earn
rate."* Enemy HP grows exponentially in global stage; hero level (and this
harness's own `Curves.heroStat`) grows only linearly in level, and the level
cap itself grows only linearly in chapter. Nothing in a hero's own kit is
supposed to close that gap alone — **the Spire is the term in the design
that is supposed to close it**, and it does not exist yet. Chapters 1-3
still pass because early growth is gentle enough for hero level alone to
keep up; the divergence starts exactly where sustained Spire investment
would start mattering.

This is the expected, intermediate state for where the roadmap places this
phase: Phase 12 (this one) comes immediately before Phase 13 (Spire). The
finding is the harness doing its job — it will not read differently until
Phase 13 gives `ExpectedPower` a real, non-zero Spire contribution to model.

The two directions are not symmetric, and Phase 13 should not be assumed to
fix both. A zero-Spire, zero-Boon model is conservative in one direction
only: every real player has *at least* this much power, never less, so a
*low*-side miss (chapter 1, above) can only get worse once Spire and Boons
are folded in — a real player kills that mote faster still, not slower. A
*high*-side miss (chapter 4 on) is the one Spire is actually meant to close.
Chapter 1's reading is therefore carried forward as its own flagged line in
the skipped test below, not folded into "pending Phase 13" along with the
rest — closing it may need an early-game tuning look independent of the
Spire.

## Consequences

- The real CI gate (`TtkDistribution.withinHardBounds` swept over all 12
  chapters) is written in full in `test/harness/ttk_probe_test.dart`, but
  kept `skip:`-marked with a reason citing this ADR, rather than either
  silently passing (which would misreport the game's actual state) or
  turning the whole suite red for a gap this phase did not create and
  cannot close on its own. Phase 13 removing the skip, once the Spire gives
  `ExpectedPower` something real to add, is the concrete exit condition.
- `tool/balance_report.dart` prints the real distribution and PASS/FAIL per
  chapter unconditionally — a human reading the report sees the actual
  numbers above, not a laundered summary. Its own exit code is non-zero
  whenever a chapter is out of band, matching the roadmap's stated exit
  criterion for the tool itself; `.github/workflows/ci.yaml`'s `balance` job
  runs it as a non-blocking, informational step for the same reason the test
  is skipped rather than failing the build.
- Everything else `ExpectedPower` resolves (level cap, crafted-not-refined,
  matching-tier arrow, star floor) is exact or GDD-grounded, not a source of
  this divergence — swapping in a real Spire contribution later is a change
  to `ExpectedPower` alone; nothing about `TtkProbe` or `TtkDistribution`
  should need to move.
