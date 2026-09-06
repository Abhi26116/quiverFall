# ADR 0098 — Wiring `CampaignProgressWorkshop` into the real game screen

**Phase** Direct follow-on to ADR 0096.
**Date** 2026-09-06
**Status** Resolved.
**Severity** Critical — the same severity as ADR 0096 itself. A correct
workshop nothing calls is exactly as broken, in practice, as no workshop at
all.

---

## What was missing

ADR 0096 built `CampaignProgressWorkshop.apply` and deliberately left
`GameScreen` untouched — it still rendered `SizedBox.shrink()` for both
`StageStatus.complete` and `.failed`, so nothing in the real app ever
called the fix. This closes that specific, named gap.

## Decision

**`RunOutcome`** — a new widget, the same shape `BoonChoice`/`Shrine`
already are: shows `finalGold` and a `RETURN TO MENU` button. Deliberately
minimal, matching ADR 0096's own scope — no stars, no boss banner, no
material drops, each a real separate follow-on.

**`GameScreen` gains two new, nullable constructor fields** —
`PlayerRepository? repository`, `RunCoordinator? runs` — resolved by
`AppRouter` from the same `_repository`/`_runs` it already holds, the
identical pattern `heroId`/`arrowId` already use (concrete values resolved
at the router, not fetched by the screen itself via `locator`). Null (the
smoke test's and dev bench's own default) means the screen still shows
`RunOutcome`, it just has nothing to persist into — the same graceful
degradation `HeroLoadoutResolver.apply` already gets from a null build.

**The mutation applies via a `runStatus` listener, not inside `build()`.**
`QuiverfallGame.runStatus` is a `ValueNotifier<StageStatus>` already updated
exactly once per real status change (`_afterTick`, guarded by
`StageRunner.update()`'s own return value); a listener attached once
`_game` exists reacts to that transition directly, independent of whether
anything is currently rebuilding the widget tree — the safer alternative to
a side effect inside a `ValueListenableBuilder`'s own `builder:` callback,
which runs during `build()` and risks re-entering it if the mutation's own
notification chain rebuilds an ancestor synchronously. A `bool
_outcomeApplied` guard makes the call idempotent regardless — the listener
can fire more than once at the same terminal status (a stray rebuild, a
tick landing before `QuiverfallGame.halted` takes effect).

**`mutateAndFlush`, not `mutate`.** `PlayerRepository.mutateAndFlush`'s own
doc comment names "run results" directly as a reason to flush immediately
rather than debounce — losing a genuine clear's gold and campaign advance
to a crash in the following seconds is exactly the failure mode that
comment exists to prevent. Not awaited: the outcome screen shows
immediately regardless of whether the flush has finished.

**`QuiverfallGame.halted` now also covers `.complete`/`.failed`.** It
already halted `_afterTick` for the two interstitials; extending it to the
two terminal statuses for the identical reason (`r.update()` returns
`false` on every subsequent tick once the run has ended, but a `false`
return does nothing to stop the *simulation* itself from ticking a dead
world every frame) is a one-line, same-shape addition alongside them, not
a new mechanism.

## Verified

`test/view/game_screen_run_outcome_test.dart`: a full clear renders
`RunOutcome` and, given a real (fake-store-backed) repository, actually
persists gold and campaign advance — checked against the live
`repository.save`, not just the widget tree; `RETURN TO MENU` clears
`RunCoordinator.activeRun`; with no repository at all, `RunOutcome` still
renders rather than crashing. All three exercise a *real* `GameScreen`
through a *real* stage clear via `WidgetTester`, the same fidelity
`game_screen_shrine_test.dart`/`game_screen_boon_choice_test.dart` already
established for the Shrine and Boon Choice.

## Consequences

A cleared or failed stage is now visible and genuinely persisted end to
end in the real app, not just provable in a headless test. Stars, boss
banners, material rewards, and the still-open Emberdust/Marks/Research
follow-ons ADR 0096 and 0097 already named remain exactly as open as
before — this closes only the "nothing calls the fix" half of the gap.
