# ADR 0097 — Boss-defeat tracking, campaign bosses only

**Phase** Follow-on to ADR 0096, itself found investigating Marks (Phase
13).
**Date** 2026-09-06
**Status** Resolved for the 12 campaign bosses; Elite and Endless bosses
explicitly deferred.
**Severity** Medium. Unblocks one of the two concrete conditions ADR 0096's
own Consequences named as still open.

---

## What was missing

ADR 0096 built `CampaignProgressWorkshop.apply` — gold and campaign
position only — and named boss-defeat tracking as the concrete blocker for
Mark of the Choir's own unlock condition ("Defeat all 20 bosses").
`CampaignState.bossesDefeated`/`bossKillCounts` already existed with no
writer anywhere.

## Decision — campaign bosses, read off the room this ADR already observes

`RoomBlueprint.bossArchetype` is non-null for **both** a `RoomKind.boss`
slot with a built fight (`BossRoomComposer.bossFor`) and a `RoomKind.elite`
slot with one (`EliteRoomComposer.eliteFor`) — but only the boss-slot case
is a stage's own *last* room, which is exactly the room
`CampaignProgressWorkshop.apply` already reads at the moment a stage
completes. An Elite boss can clear mid-stage, several rooms before the run
itself ever reaches `StageStatus.complete` — tracking that defeat needs a
hook inside `StageRunner.update()`'s own room-advance step, a materially
different (and larger) change than extending a function that already only
runs once, at the very end of a run.

So this ADR resolves exactly the part that fits the existing hook: on a
genuine stage completion (`.complete`, never `.failed`) whose own last room
is `RoomKind.boss` with a real `bossArchetype`, its archetype name is added
to `bossesDefeated` and its own kill count incremented — 12 of the 20 named
in docs/06, the entire campaign roster. Elite (4) and Endless (4) tracking
are left as a named, separate follow-on, not silently folded in as "boss
tracking, done."

## Verified

Four new tests in `campaign_progress_workshop_test.dart`'s own "boss-defeat
tracking" group: a completed boss stage records the defeat and starts its
count at 1; defeating the same boss again increments the count without
duplicating the set entry; an ordinary stage clear leaves both fields
untouched; a failed run — even one that died inside the boss room itself —
never records a defeat.

## Consequences

Mark of the Choir's own condition is now checkable for the 12 campaign
bosses (`bossesDefeated.length >= 12` is not yet "all 20", but is real,
accurate progress toward it). Elite and Endless boss tracking, per-stage
records (Mark of the Swift), materials, and Endless floor tracking remain
open — the same list ADR 0096 already named, now one item shorter.
