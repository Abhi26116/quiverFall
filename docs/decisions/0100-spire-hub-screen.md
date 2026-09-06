# ADR 0100 — The Spire hub screen: the first real UI for any Phase 13 system

**Phase** 13 (meta progression), Part 5.
**Date** 2026-09-06
**Status** Resolved.
**Severity** High — the last missing link making the Spire's own 14 wired
nodes (ADR 0092) and the account's ability to reach a real run with them
(ADR 0099) actually usable by a player.

---

## What was missing

`SpireWorkshop` was fully built and tested, and `GameScreen` was already
wired to read `save.spire` into a real run (ADR 0099) — but nothing let a
player ever set `save.spire` to anything but its own empty default.
`Routes.spire` resolved to a `PlaceholderScreen`. A correct, reachable
combat effect with no way to ever invest in it is functionally identical
to no Spire at all.

## Decision

**`SpireScreen`**, the same shape `HeroScreen`/`GearScreen` already
establish for this codebase's account screens: a `StatefulWidget` (well,
here a plain `StatelessWidget` — nothing it shows needs local state beyond
the save itself) wrapped in `ValueListenableBuilder<PlayerSave?>` on
`repository.saveNotifier`, with the identical `_apply(Result<PlayerSave,
EconomyError>)` helper those two screens already use to route a
`SpireWorkshop` call's success into `repository.mutate` and its failure
into a snackbar.

Four wing sections, each either a locked banner naming the exact account
level it needs (`HeroScreen`'s own "never just a lock icon" rule, applied
here too) or its own six node rows — name, description, current level,
and one button that is either a plain gold level-up or, once the next
level needs a tier gate not yet open, an Insight-priced gate-unlock
instead. `SpireWorkshop.requiredBandFor` (already public, ADR 0092) decides
which button to show; a new `SpireWorkshop.tierGateInsightCost(band)`
(the same table `unlockTierBand` already validated against, previously
private) lets the screen show a price before the player taps, not just
reject it after.

Wired at `Routes.spire` in place of the old `PlaceholderScreen`; the
`research` sub-route stays a placeholder — Research Lab's own hub is a
separate, smaller screen this ADR does not build.

## A second testing pitfall, distinct from ADR 0099's own

The first version of the verifying test built a save with every wing
unlocked (`accountLevel: 90`, all 24 nodes) and asserted all four wing
titles were present. Only the first wing's own title and nodes were ever
found — not a wiring bug, and not the `pumpWidget`-twice mistake ADR 0099
found either. A plain `ListView(children: [...])` still only *inflates*
elements near its own viewport — providing the whole widget list upfront
is not the same as building all of it into the element tree the way a
`Column` inside a `SingleChildScrollView` (what `HeroScreen`'s and
`GearScreen`'s own single-page-at-a-time layouts use) would. `find.text`
only ever sees what has actually been inflated. Fixed by giving the test
surface enough height (`setSurfaceSize(Size(400, 4000))`) to fit all 24
nodes without scrolling, rather than teaching every test to scroll first.

## Verified

`test/features/spire_screen_test.dart`, 8 tests: all four wing names
present; a locked wing shows its own account-level banner and hides its
nodes entirely; an unlocked wing shows its nodes; tapping a level-up
button spends the exact gold and raises the node's level; insufficient
gold disables the button; a node at its L20 boundary offers the gate
unlock instead of a level-up, and tapping it spends Insight and raises the
band; a maxed node shows no purchase control at all; the currency readout
shows both gold and Insight.

## Consequences

The Spire is now genuinely playable end to end: a real player can open the
screen, spend real gold, and see the effect in their next run. Marks,
Research, and Ascension still have no hub screen of their own — each is
real, tested, and reachable from a run the moment one exists, the same
state the Spire itself was in before this ADR.
