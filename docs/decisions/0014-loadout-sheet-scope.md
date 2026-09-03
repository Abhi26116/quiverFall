# ADR 0014 — The Loadout Sheet claims a run; GameScreen still ignores it

**Phase** 10
**Date** 2026-09-03
**Status** Accepted as a deliberate scope boundary, not a bug.
**Severity** Medium. The screen this ADR is about works completely; what it
hands off to does not consume everything it's given yet.

---

## What's built

`LoadoutScreen` (docs/10-ui-ux.md §10.5's Loadout Sheet, reached in the nav
graph as `LevelSel --> Loadout --> Game`) lets the player pick an unlocked
hero and an owned arrow, previews both, persists the choice to
`PlayerProfile.equippedHeroId`/`equippedArrowId` (the same effect the Hero
and Gear screens' own EQUIP buttons already have), claims the run slot
through `RunCoordinator.tryBeginStart`/`completeStart` — the "RunCoordinator
handshake" `GameScreen`'s own doc comment already named as still missing —
and constructs a real `RunSnapshot` before navigating to `/game`. Every one
of those steps is real: the `/game` route guard (`RouteGuards.game`) genuinely
requires an active run, and this is the first code in the app that claims
one.

## What's deliberately not built here

**`GameScreen` and `StageRunner` do not read the claimed `RunSnapshot` at
all.** `GameScreen`'s constructor still only takes `chapter`/`stage`/
`playerId` — no `heroId`, no `arrowId` — and constructs its `SimWorld`
without ever calling `HeroLoadoutResolver.apply`. So today, picking Kade and
Twinfang in the Loadout Sheet and tapping DESCEND does start a real,
guard-passing run — running whatever hero-less baseline `GameScreen`'s sim
already runs, not Kade with Twinfang equipped.

Wiring that up means giving `GameScreen` a `heroId`/`arrowId` (or a whole
`RunSnapshot`), threading them into whatever constructs its `SimWorld`, and
calling `HeroLoadoutResolver.apply` there — a change to the gameplay
screen's own construction, not to a menu-reachable picker screen. That is a
materially different piece of work than "build the Loadout Sheet", the
roadmap line this task is scoped against, and `GameScreen`'s own doc comment
already flags the gap as pre-existing rather than something this task
introduced.

**Vigor is not spent on DESCEND, and the stage's Vigor-sufficiency guard is
not checked.** `RouteGuards.stage` bundles both together, and
`VigorState.current` is explicitly *not* the live authoritative value — its
own doc comment says Vigor "is *computed* from [`lastTickAt`] on read, never
stored as a ticking value" — so spending it correctly needs the same
regen-then-deduct step a real Vigor service would supply, which does not
exist yet either. Rather than deduct from a field that is already known to
be stale, DESCEND checks only the simple, complete, correct half of the
guard — `RouteGuards.chapter` — and leaves Vigor spend to whichever phase
builds that service.

## Consequences

The next piece of work this unblocks — giving `GameScreen` a loadout — is
now well-scoped by this ADR: read `RunCoordinator.activeRun` (or accept a
`RunSnapshot` constructor argument) for `heroId`/`arrowId`, and call
`HeroLoadoutResolver.apply` alongside whatever already builds the `SimWorld`.
Vigor spend is the other flagged half, sitting next to it.
