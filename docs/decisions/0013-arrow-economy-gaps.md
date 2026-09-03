# ADR 0013 — Three gaps in applying the crafting/refinement/reroll economy

**Phase** 10
**Date** 2026-09-03
**Status** Resolved, each independently — see the three decisions below.
**Severity** Low. Each is a mechanical detail the content docs assume but
never spell out; none change a stated number.

---

## 1. Material tier → wallet key

`ArrowCraftCost.materialsByTier` and `ArrowRefinement.materialTier` both
speak in numeric tiers (1–4) — the same numbers `assets/data/arrows.json`
was authored against. `Wallet.materials` (`lib/data/models/player_save.dart`)
is a `Map<String, int>` keyed by material *name*, and docs/02 §2.1 names
the four materials in tier order but never as explicit lowercase ids:
"Ashwood / Ironhead / Skyfeather / Prismcore — Materials T1–T4."

**Decision.** `MaterialTier.keyFor(tier)` (`lib/game/arrows/material_tier.dart`)
maps 1→`'ashwood'`, 2→`'ironhead'`, 3→`'skyfeather'`, 4→`'prismcore'` —
the doc's own listed order, lowercased verbatim. If a future content pass
gives these an explicit id elsewhere, this is the one place to update.

## 2. Rolling and rerolling never produce a duplicate affix on one arrow

docs/08 §8.4 says only "affixes roll from a 17-entry pool on each refine,
weighted by tier" (see ADR 0012 for the 17-not-18 count) and "rerolling a
single affix" — neither line says whether the pool for either draw excludes
whatever the arrow already carries.

**Decision.** Both draws exclude every *other* affix already on the arrow.
A fresh refine excludes all currently-equipped affixes; a reroll of slot
`i` excludes every slot except `i` itself, so a reroll may legitimately
land back on the same archetype it started with (an unlucky reroll, not a
duplicate) but can never produce two live copies of the same affix. Two
copies of a flat-value affix (Piercing's +1 pierce, Threaded's Confluence
cap +1) would double a fixed bonus for the price of one roll, well outside
what "weighted by tier" was ever meant to price — and no ARPG-style
itemization system this genre draws from allows a duplicate affix on one
item.  `AffixRoller.roll` (`lib/game/arrows/affix_roller.dart`) takes the
exclusion set as a required parameter rather than inferring it, so both
call sites in `ArrowWorkshop` state their own exclusion rule explicitly.

## 3. `rerollCountThisSession`'s reset is out of this ADR's scope

`InventoryState.rerollCountThisSession`'s own doc comment (written before
this ADR, in `lib/data/models/inventory.dart`) already says the escalating
reroll cost "resets daily." No daily-reset system exists yet anywhere in
the codebase — quests' own `dailyResetAt` field is unconsumed for the same
reason (docs/12's live-ops/daily-reset job is a separate, not-yet-built
piece). `ArrowWorkshop.rerollAffix` increments the counter and never
resets it, matching every other daily-scoped field's current state:
written, read, not yet reset by anything. Whatever daily-reset job Task 5
or a later phase eventually builds should zero this field alongside
`QuestState`'s own two reset timestamps, not invent a second, arrow-specific
reset path.
