# ADR 0094 — Ascension: the gate, the reset, and the Emberdust award

**Phase** 13 (meta progression), Part 3.
**Date** 2026-09-06
**Status** Resolved for the scope below; the Emberdust tree itself deferred.
**Severity** Medium.

---

## What was missing

docs/04 §4.7 fully specifies three things: the gate ("chapter 10 cleared
*and* account level 40"), an exact reset/survive list, and the Emberdust
award formula. `Curves.emberdustFor` already implemented that formula
exactly (predates this ADR, already tested in `sim_core_test.dart`).
Nothing else existed — no gate check, no reset, nothing reading
`AscensionState`.

## Decision — build exactly the three fully-specified pieces

`AscensionWorkshop.ascend` is one pure `PlayerSave -> Result<PlayerSave,
EconomyError>` function, the same shape every other workshop in this
codebase already uses:

- **Gate**: `currentChapter > 10` (cleared, the identical "cleared chapter
  N" reading `HeroWorkshop.unlock`'s own `chapterClear` case already uses)
  and `accountLevel >= 40`.
- **Reset**: Spire node levels (`SpireState()`, empty) and banked gold
  (`wallet.gold = 0`) only — docs/04 names exactly these two and nothing
  else.
- **Award**: `Curves.emberdustFor(highestChapterEver, ascensionCount)`,
  added to the existing Emberdust balance, not replacing it.

**`highestChapterEver` must be brought current before the award is
computed, not read as-is.** Nothing in the codebase writes to this field
outside this workshop (campaign-chapter advancement itself has no save
mutation wired anywhere yet — a separate, larger, pre-existing gap this
ADR does not attempt). Since the field's own contract is "never resets...
input to the Emberdust award formula," `ascend` takes
`max(existing, save.campaign.currentChapter)` before computing the award —
otherwise a second Ascension launched from a lower chapter than an earlier
peak would silently under-pay and permanently lose the correct peak.

**"Campaign progress → chapter 1" is read as position, not history.**
`CampaignState` holds more than the player's current chapter/stage —
`bossesDefeated`, `bossKillCounts`, `records`, and Endless progress all
live there too. Only `currentChapter`/`currentStage` reset to 1;
everything else in `CampaignState` survives. Two things point the same
direction: docs/04's own "what survives" list names "achievements", and a
Mark keyed to a lifetime total (its own example, "Defeat all 20 bosses") is
*stated* to survive Ascension — if `bossesDefeated` reset here, that Mark's
own progress would silently regress despite Marks being explicitly listed
as surviving. Every other Wallet field (gems, Insight, Emberdust,
materials, hero shards, event tokens) is left untouched for the identical
reason: docs/04 names only gold, and separately states Insight survives.

## Decision — the Emberdust tree itself is not built here

docs/04 §4.7's own table gives every one of the 5 branches an effect and a
max rank (Cinder +3% all damage/rank to 40, Ash +3% EHP/rank to 40, Spark
+4% gold/+2% mats per rank to 30, Ember "N free Spire levels" to 25, Pyre
12 one-off unlocks) — but unlike the Spire's own `Curves.spireNodeCost`,
**no per-rank Emberdust cost formula is stated anywhere in docs/02 or
docs/04**, and Pyre names only 4 of its own 12 nodes. Authoring a cost
curve here would be inventing a number with nothing to derive it from — a
different kind of gap than every other one this project's ADRs have
resolved, which have all had a real GDD number or an existing code pattern
to anchor an interpretation to. Left as the concrete next open question for
whoever picks up the Emberdust tree.

Two branches are also worth noting for whoever does: **Cinder** would need
the same separate-multiplicative-term treatment Warden's Might got in
ADR 0092 (`ascensionAtk` is its own factor in docs/04 §4.1's ATK formula,
distinct from `ΣboonAtk`); **Ash** would not (`ascensionVit` can join the
same shared `maxHealth` channel Spire's own Vitality already does, since
the EHP formula shows no separate boon-HP term to protect against
double-counting the way the ATK formula's own explicit `ΣboonAtk` term
does for Cinder).

## Verified

`test/game/ascension_workshop_test.dart`: the chapter and account-level
gates independently; Spire levels and gold reset while campaign history
(bosses/records), every other wallet currency, heroes, and account level
all survive untouched; the award matches `Curves.emberdustFor` exactly and
adds to rather than replaces an existing balance; the count increments and
the timestamp records; `emberdustRanks` itself never resets; and —the one
correctness-critical case — ascending from a chapter *below* an earlier
recorded peak still awards and stores the true peak, not the current
chapter.

## Consequences

The Ascension cycle is real end to end except for spending Emberdust —
gate, reset, and reward all work, are tested, and are ready for a hub
screen. The tree, Marks (only 9 of 25 named in the GDD itself), and the
ten deferred Research Lab items remain Phase 13's other open pieces.
