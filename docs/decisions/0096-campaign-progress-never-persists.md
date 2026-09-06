# ADR 0096 — Nothing ever persists a finished run

**Phase** Found while investigating Marks' unlock-condition tracking
(Phase 13); a foundational gap in the core game loop, not a meta-progression
gap.
**Date** 2026-09-06
**Status** Resolved for gold and campaign position; several real follow-ons
flagged.
**Severity** Critical. Without this, the campaign cannot actually be played
— a cleared stage never unlocks the next one.

---

## What was wrong

`GameScreen`'s own build method switches on `runner.status`:

```dart
StageStatus.fighting ||
StageStatus.complete ||
StageStatus.failed =>
  const SizedBox.shrink(),
```

Completing or failing a run renders nothing and calls nothing. Grepping the
whole of `lib/` for writers to `PlayerSave.campaign.currentChapter`,
`.currentStage`, or `.bossesDefeated` found none at all — every reader
(route guards, the hero level cap, the Menu's own chapter display) assumes
these fields advance, and nothing advances them. A player could clear
chapter 1 an unlimited number of times and chapter 2 would never unlock.
This is not a Phase 13 gap — it predates every meta-progression system this
session built and sits underneath all of them: [ADR 0094](0094-ascension-gate-reset-award.md)'s own
`highestChapterEver` fix only matters once real progress reaches the save
at all.

**A second, smaller bug was found while fixing the first.**
`StageRunner.bankedGold` — the only existing gold-payout getter — always
applies `Curves.partialGold`'s own 0.7 fraction, including on a genuine
full clear. That factor's own doc comment states it is "the entire penalty
for dying" (docs/14 §14.6); applying it to a stage that was not died in
would silently short every completed run by 30%.

## Decision

**`StageRunner.finalGold`** — a new getter, the same shape as `bankedGold`
it sits beside — reads `status` and pays `Curves.stageGold` (the real
full-clear figure, net of anything spent at the Shrine) on
`StageStatus.complete`, falling back to `bankedGold`'s own existing
partial-credit formula on `.failed`.

**`CampaignProgressWorkshop.apply(save, runner)`** — one pure
`(PlayerSave, StageRunner) -> PlayerSave` function, the same shape every
other workshop in this codebase already uses, called once a run has
genuinely ended:

- Banks `finalGold`.
- Advances `currentChapter`/`currentStage` to the next stage on a clear —
  but **only when the completed stage matches the save's own current
  frontier**. Replaying an already-cleared stage (there is no other reason
  a real save would ever complete a stage behind its own frontier) pays
  gold without moving position — the alternative, blindly overwriting
  `currentChapter`/`currentStage` from whatever stage was just played,
  would let a farming run on chapter 2 regress a chapter-9 save back to
  chapter 3.
- Clamps at chapter 12 / stage 20 rather than manufacturing a chapter 13
  that does not exist — docs/14 places Endless Descent, not more numbered
  campaign content, past the campaign's own last authored stage.
- Keeps `AscensionState.highestChapterEver` current with real progress
  (not just the act of ascending, which ADR 0094 already handles) — the
  same reasoning that ADR gives for why the field cannot be trusted as-is.

**Deliberately the smallest version of this that is genuinely correct.**
Boss-defeat tracking (`bossesDefeated`, `bossKillCounts` — Mark of the
Choir's own unlock condition, ADR 0095), per-stage records/best times
(Mark of the Swift's own condition), material rewards, and Endless Descent
floor tracking are all real gaps this ADR does not close — each needs its
own design pass (which room counts as "the boss room," what a "best time"
record should overwrite, how materials scale per room) beyond what gold
and chapter position needed. `GameScreen` itself is not touched — calling
`CampaignProgressWorkshop.apply` from the real `StageStatus.complete`/
`.failed` branch, and building the victory/defeat screen those branches
currently render nothing for, is presentation-layer work this ADR
deliberately leaves for whoever picks up the screen.

## Verified

`test/game/campaign_progress_workshop_test.dart`: a full clear pays
strictly more than the death formula would (catching the 30%-short bug
directly, not just asserting the new number); stage-to-stage and
chapter-to-chapter advancement; the campaign's own last stage clamps
rather than inventing a 13th chapter; replaying an old stage pays gold
without moving position; a failed run still pays something (docs/14's own
"no zero-reward run") via the pre-existing partial formula; `
highestChapterEver` rises to meet real progress and never regresses below
an earlier recorded peak.

## Consequences

The campaign can now genuinely be completed in code — gold and chapter
advancement both reach the save correctly once `GameScreen` is wired to
call this. Boss-defeat tracking, stage records, and materials remain open,
and are now the concrete, itemised blockers for the Marks whose own unlock
conditions depend on them (Choir, Swift) rather than a vague "unlock
checking isn't built yet."
