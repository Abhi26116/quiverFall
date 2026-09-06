# ADR 0099 — The Spire and Marks now actually reach a real run

**Phase** Direct follow-on to ADR 0092/0095, found while looking for the
next reachability gap after ADR 0098 closed the campaign-persistence one.
**Date** 2026-09-06
**Status** Resolved.
**Severity** Critical — the same class of bug as ADR 0090 and ADR 0096:
correct sim-layer code nothing in the real app ever calls.

---

## What was wrong

`HeroLoadoutResolver.apply` gained `spire`/`spireState` (ADR 0092) and
`marks`/`equippedMarkKeys` (ADR 0095) parameters, both fully tested in
isolation (`spire_effects_test.dart`, `mark_effects_test.dart`). But
`GameScreen._start()` — the one call site a real run actually goes
through — never passed either. A player's entire Spire investment and
every equipped Mark were silently inert in real play, exactly the same
shape of gap ADR 0096 found for campaign persistence: the primitive was
correct, reachable only from a test.

A second, smaller gap sat underneath it: `SpireCatalogue`/`MarkCatalogue`
were never loaded anywhere near `GameScreen` at all — `ContentLibrary`
(the one object `ContentLoader.load()` hands the screen) had no fields for
either.

## Decision

**`ContentLibrary` gains `spire`/`marks` fields**, loaded from
`assets/data/spire.json`/`marks.json` via two new optional `parse()`
parameters (`spireJson`, `marksJson`) — the identical optional-with-
`.empty()`-fallback shape `heroesJson`/`arrowsJson`/`affixesJson`/
`bossesJson` already use, so no existing caller (a test passing only
`enemiesJson`, the content validator) needs to change. `ContentLoader
.load()` fetches both new files the same way it already fetches
`bosses.json`. Following `ContentLibrary`'s own stated reasoning (its class doc comment)
for including bosses rather than boons — "the running app's screens need
it in one place to load" — the Spire and Marks belong here too:
`GameScreen`'s own loadout resolution needs both now, the same way it
already needs `heroes`/`arrows`/`affixes`.

**`GameScreen._start()` reads `widget.repository?.save` and forwards
`content.spire`/`save?.spire` and `content.marks`/
`save?.profile.equippedMarkIds`** into the same `HeroLoadoutResolver
.apply` call that already resolves hero and arrow — one more use of the
`repository` field ADR 0098 added for exactly this kind of "read real
account state from inside the screen" need. Null/empty (no repository, the
smoke test's and dev bench's own default) folds in nothing, the identical
graceful degradation `heroState`/`arrowInstance` already get.

## A real testing pitfall found along the way

An early version of the verifying test called `tester.pumpWidget(...)`
twice in one `testWidgets` block — once for a "before" `GameScreen`, once
for an "after" one — to compare `playerAttack` between them. Both readings
came back identical, at first read as a wiring bug. It was not: a second
`pumpWidget` inside the same test does not reliably re-run
`initState`/`_start()` against a `FlameGame`'s own widget/ticker lifecycle,
so the second boot's own game object was not what the assertion assumed it
was. Every existing `GameScreen` widget test in this codebase already
calls `boot()` exactly once per test — this ADR's own tests follow that
same rule, comparing each live reading against an independently-known
constant (Wren + Ash Shaft's own plain `heroAtk × arrowBaseMult`, computed
by hand from `Curves.heroStat` the same way `spire_effects_test.dart`'s own
control values are) rather than a second live boot.

## Verified

`test/view/game_screen_spire_marks_test.dart`, 5 tests, each a single real
`GameScreen` boot through a real stage: the plain hero+arrow baseline with
no investment at all; Warden's Might at L80 raising `playerAttack` by
exactly the documented factor; no equipped Marks leaving `flatDamage`
untouched; an equipped, unlocked Mark of Ruin raising it by exactly 10%;
and — the graceful-degradation case — no repository at all still starting
the run.

## Consequences

Every Spire node and Mark this session already wired to a combat effect
(ADR 0092, ADR 0095) now genuinely affects real play, not just a test
arena. The Spire and Marks hub screens themselves — where a player would
actually spend gold on a node or equip a Mark — remain unbuilt; this ADR
makes the investment matter the moment either screen exists to make one.
