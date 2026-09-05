# ADR 0095 — Marks, Part 1: content, equip slots, and 6 wired effects

**Phase** 13 (meta progression), Part 4.
**Date** 2026-09-06
**Status** Resolved for the scope below; unlock-condition checking and 3
effects explicitly out of scope.
**Severity** Medium.

---

## What was missing

docs/04 §4.5 names 9 of "25 Marks total" explicitly, each with an "Earned
by" condition and an effect, and states the equip rule: "6 equippable at
once (slots at account levels 12/20/30/45/65/90)." `MarkState`
(`progress`, `unlockedIds`) and `PlayerProfile.equippedMarkIds`
(doc-commented with the same six thresholds) already existed on
`PlayerSave`. Nothing else did.

## Decision — the 9 named Marks, not 25

The doc's own words are "…16 more" — an authorial placeholder for content
that does not exist yet, not an oversight this session can resolve by
interpretation the way an ambiguous number or an unstated geometry can be.
`assets/data/marks.json` catalogues exactly the 9 the doc names; the
catalogue's own validator asserts `length == 9`, not 25, so this is a
visible, honest constraint rather than a silent gap.

## Decision — equip slots are built and generic, unlock-checking is not

**`MarkEquipWorkshop`** is the "already have it, put it in a slot" half —
`slotsFor(accountLevel)` counts how many of the six thresholds an account
has passed (zero below level 12, matching the doc's own first threshold
literally), and `equip`/`unequip` enforce it against
`PlayerProfile.equippedMarkIds`, reading `save.marks.unlockedIds` but never
writing it.

**Deciding *whether* a Mark is unlocked — "Trigger 500 Confluences", "Clear
a chapter without taking damage", and so on — is a separate, cross-cutting
task this Part does not attempt.** Each condition needs its own event hook
into a different system (a Confluence trigger count, a landed Tier-III hit
count, a max-Momentum-reached count, a room-damage-taken tally, a stage
clear timer) that nothing in the codebase currently tracks, the same class
of gap ADR 0093 found for the Research Lab's Boon Banking and Shrine
Ledger. `MarkState.unlockedIds` is treated exactly like `SpireState
.nodeLevels`/`ResearchState.completedIds` already are — an externally-set
save field this Part's workshops read and mutate, not one they derive.

## Decision — 6 of 9 effects wired, 3 deferred

Every wired Mark composes into the same shared `combined` stat block a
Spire node or hero talent already does — none of the nine is its own
separate multiplicative ATK term the way Warden's Might is, so there is no
Mark-side equivalent of `spireMight` folding into `baseAttack`.

| Mark | Channel(s) | Wireable? |
|---|---|---|
| Mark of the Thread | `confluenceDamage` | yes |
| Mark of the Thread II | `confluenceDamage` + `windlineDuration` | yes |
| Mark of Stillness | `tierThreeDamage` | yes |
| Mark of the Gale | `maxMomentum` | yes |
| Mark of the Swift | `fireRate` | yes |
| Mark of Ruin | `damage` | yes |
| Mark of the Unbroken | — | no — needs a player-HP-conditional damage channel ("while at full HP"); the existing conditionals (`vsWounded`, `vsDying`) are all enemy-HP-scoped |
| Mark of the Choir | — | no — needs a boss-scoped damage channel, the identical gap ADR 0092 found for the Spire's own Iron Resolve |
| Mark of the Ninefold | — | no — `boonCardCount` is read from `BoonInventory.stats` directly (`boon_pool.dart`), not `world.combat`; the identical Wing-IV-style integration gap ADR 0092 found for the Spire's own economy nodes |

Every deferred Mark is still real, catalogued content with its own
`balanceNote` — the same posture ADR 0092 and ADR 0093 already established
for their own deferred entries.

## Verified

`mark_catalogue_test.dart`: 9 Marks, ids 1-9, the 6/3
implemented/deferred split with balance notes, Mark of the Thread II's own
two-channel contribution. `mark_equip_workshop_test.dart`: the slot count
at every one of the six thresholds (including zero below 12), unknown/
not-unlocked/already-equipped/slots-full failure paths, a second slot at
level 20 genuinely allowing a second Mark. `mark_effects_test.dart`: each
of the six wired Marks measured in isolation via `HeroLoadoutResolver
.apply`, the same way a Spire node already is in `spire_effects_test
.dart`; two Marks composing independently; an unlisted key ignored rather
than throwing.

## Consequences

Marks can be equipped and (for six of nine) meaningfully change a build
today; nothing yet grants one in the first place. Whoever builds the
unlock-condition tracking next has a concrete, itemised list of exactly
which system each of the nine conditions needs a hook into, and inherits a
working equip/effect pipeline to grant into rather than building both at
once. Research Lab's ten deferred items and Ascension's Emberdust tree
remain Phase 13's other open pieces.
