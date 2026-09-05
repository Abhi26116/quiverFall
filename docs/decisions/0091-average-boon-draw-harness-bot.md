# ADR 0091 — "An average Boon draw at room 5", made concrete

**Phase** 12 (balance harness & CI), Part 2 — the fourth term of docs/02
§2.6's "expected power", deliberately deferred by ADR 0089's own Part 1.
**Date** 2026-09-05
**Status** Resolved.
**Severity** Medium. Affects only the harness's own reading, not shipping
gameplay — unlike ADR 0090, found while building this same Part.

---

## What was missing

ADR 0089 built three of "expected power"'s four terms (hero level, arrow
tier, Spire — the last as an explicit zero) and named the fourth,
"an average Boon draw at room 5", as needing a real bot rather than a
number. Three genuine questions stood between that phrase and code:

1. **What does "average" mean for a draw?** No player-choice model exists
   anywhere in the codebase or the docs — "average" could mean an optimal
   player's picks, a popularity-weighted pick, or a plain uniform one.
2. **What happens at a Shrine room?** A real run can spend banked gold there
   on a heal, a reroll, or a guaranteed Rare+ Boon purchase — a policy
   question with no stated answer.
3. **What does "room 5" count?** A room index, or the fifth Boon actually
   taken?

## Decision

**Uniform-random among the offered cards** (`Rng.pick`, off a dedicated
split stream so which Boon ties never perturb crit rolls, AI phase, or
anything else seeded). Modelling an optimal player would mean building a
Boon-value heuristic — an entire second, unvalidated model layered on top
of the one thing this harness exists to measure honestly. A plain,
seed-varying uniform pick is the least additional modelling this phrase can
be resolved with, and it is the right kind of "average" for a distribution
report: run enough seeds and the reading already reflects the game's actual
mix of good, mediocre, and Cursed draws — including runs where a weak or
actively harmful card gets taken, which a real player sometimes does too.

**A Shrine room is left immediately, no purchases** (`leaveShrine()` on
sight). The harness does not model a gold-spending policy at all — banking
gold versus spending it at a Shrine is a real decision with no stated
"average" behaviour, and inventing one here would be exactly the kind of
unvalidated modelling the Boon-pick decision above was just rejected for.

**"Room 5" is a room index, not a count of Boons taken** — confirmed the
hard way, not assumed: an early attempt counted Boon picks and found
chapter 2 (and every chapter whose stage has exactly `StageBlueprint
.roomCount`'s own floor of 6 rooms) could never reach 5, because
`StageRunner.update`'s own `isLastRoom` check completes the stage on the
final room's own clear *without* ever offering a Boon — a 6-room stage
offers at most 5 choices in total, and a Shrine room occupying one of the
first five slots lowers that further. Counting picks made "room 5"
literally unreachable on exactly the short early chapters a reading is most
needed from. Reading "room 5" the plain way it is written — the room
whose *index* is 5 — sidesteps this entirely: `roomCount(chapter) = 6 +
chapter div 3` never falls below 6, so room index 5 always exists.

**Stage 10** — an ordinary mid-chapter stage on every chapter, not gated by
any of the special-room placement rules the boss stage (20) or the
Ashen-Choir-carrying stage 10-of-chapter-3 exception (ADR 0055) have. Named
a stage at all only because "expected power" needs *some* one to sample
Boons from; docs/02 §2.6 does not itself name one.

## Implementation

`HarnessBot.playToRoom(runner, world, targetRoomIndex:)` — reuses
`stage_runner_test.dart`'s own proven root-then-roam fighting rhythm
(copied, not imported: that file is a test, this is `lib/`), extended to
resolve `StageStatus.awaitingBoonChoice` (uniform pick) and `.awaitingShrine`
(immediate `leaveShrine()`) in the same loop. `TtkWithBoonsProbe.measure`
composes it with `TtkProbe`: builds a real stage, applies the
`ExpectedPower` loadout via `HeroLoadoutResolver.apply` +
`StageRunner.setBaseLoadout` (ADR 0090's own fix is what makes this
survive past the first Boon at all), plays to room 5, then hands the same
live world — Boons and all — to `TtkProbe.measureAgainstFreshMote`, the
same clean-fight core `TtkProbe.measure` itself now shares.

## Verified

Run directly across chapters 1-4, several seeds each: room 5 is reached in
every run (`status: fighting`, `roomIndex: 5`) where the underlying TTK
Law itself would allow it — chapters 3-4 already show the identical
timeout pattern ADR 0089 found without any Boons involved, confirming this
is the same known, expected gap, not a new one. Real, seed-driven variance
appears exactly where it should: chapter 1 reads anywhere from 0.55s (a
draw that did nothing for damage) to 3.03s (a draw that actively hurt it,
e.g. a Cursed card) — genuine signal a fixed, no-Boon reading could never
show.

## Consequences

All four terms of "expected power" now have a real, ADR-documented
resolution; `TtkWithBoonsProbe` is the version of the TTK reading that
folds every one of them in, ready for the same per-chapter distribution and
hard-band gate ADR 0089's `TtkHarness` already reports, once wired the same
way. The Boon Power Score / pick-rate / super-additive-pair work docs/09
§9.5 describes is a separate, larger measurement this ADR does not attempt
— it needs a win/loss outcome across many full runs, not one TTK reading.
