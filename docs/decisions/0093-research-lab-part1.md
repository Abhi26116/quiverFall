# ADR 0093 — The Research Lab, Part 1: content, workshop, and two wired items

**Phase** 13 (meta progression), Part 2.
**Date** 2026-09-06
**Status** Resolved for the scope below; ten items explicitly deferred.
**Severity** Medium.

---

## What was missing

docs/04 §4.6 fully enumerates the Research Lab's 12 purchasable items
(Branch B's 7 systemic unlocks, Branch C's 5 quality-of-life ones — Branch
A, "Tier Gates", is the Spire's own per-node L20/L40/L60 gates, already
`SpireWorkshop.unlockTierBand` from ADR 0092). None of `lib/game/research/`
existed; `ResearchState` (`completedIds`, `insightSpent`) was already
modelled on `PlayerSave`, same as every other Phase 13 system.

## Decision — content and the generic one-time-unlock mechanic for all 12,
live effects for two

Every item follows the identical purchase shape regardless of what it
does: pay Insight once, add to `ResearchState.completedIds`, permanently.
`ResearchWorkshop.unlock` is that one mechanic for all 12 — the content
data (`assets/data/research.json`) carries every real number from the
table, whether or not this Part wires the item's own effect.

**Two items get a live effect this Part, both found by checking what
already exists rather than assumed to need new work:**

- **Windline Memory** ("Windlines persist through room transitions", 220
  Insight) is the *exact* effect *Lingering* (#62, a Boon) already has —
  `SimWorld.clearRoom()` already skips clearing Windlines for one flag.
  This adds a second, independent flag
  (`SimWorld.windlinesSurviveRoomTransition`) checked in the same `if`,
  because *Lingering* is a run-scoped Boon behaviour and Windline Memory is
  a permanent, account-level unlock — different lifetimes, same effect,
  not the same field. `ResearchLoadoutResolver.apply` is the one place a
  completed Research item becomes a `SimWorld` field, mirroring
  `HeroLoadoutResolver`/`LoadoutResolver`'s own seam.
- **Second Loadout** ("Save/swap a full hero + arrow + Mark set", 60
  Insight) needed no sim change at all — `PlayerProfile.loadouts` (a
  `List<Loadout>`) and the `equippedHeroId`/`equippedArrowId`/
  `equippedMarkIds` fields the Loadout Sheet already reads/writes were
  already modelled, just never read by anything. `LoadoutWorkshop` reads
  "second" literally — `maxLoadouts` is 1 without the research, 2 with it,
  not an open-ended list docs/04 never asked for.

## Decision — ten items deferred, and why each one specifically

- **Boon Banking** — which Boon gets banked on a failed run is not
  specified: an actual player choice needs a UI this Part does not build;
  an automatic policy (highest rarity? last taken?) would be invented, not
  derived from anything in docs/09 or docs/04.
- **Shrine Ledger** — "see the next Boon set before a reroll" needs a
  genuine new capability: previewing what a reroll *would* draw without
  consuming the reroll charge or advancing the run's own Boon RNG unless
  confirmed. `BoonPool`/`StageRunner`'s own reroll is destructive by
  design today; a non-committing peek is new API surface, not a flag.
- **Double Draw** — "Tier III can overcharge into a one-off Tier IV shot"
  is a fourth Draw tier. `DrawTier` is a 3-value enum load-bearing across
  `DrawState`, `ProjectileSystem`, and every hero/Boon that reads
  `DrawTier.three` by name — comparable in scope to a hero's own kit, not
  a research checkbox.
- **Elemental Codex, Auto-claim chests, Skip run intro, Damage-number
  toggle, Extra Vigor notification, Combat log** — six items that are
  purely presentational (a HUD preview, a settings toggle, a log view) or
  automate a UI flow (chest claiming, a run intro) that does not exist in
  this codebase yet to automate. None has a sim-side effect to wire at
  all; each is real content data with nothing here for `lib/game/sim` to
  do.
- **Deep Descent** — "unlock Endless Descent difficulty tiers 2-5" names a
  tier-select concept that does not exist anywhere in the Endless Descent
  systems that *are* built (`the_loom_system.dart`, `coilspine_system
  .dart`, `last_warden_system.dart`, `EndlessBossComposer`) — those scale
  by floor number, not by a selectable difficulty tier. Gating something
  that has no on/off switch yet is not a research unlock away from
  working.

Every deferred item is still real, purchasable content with its own
`balanceNote` — spending Insight on one today costs the same as a real
account would pay and unlocks nothing live yet, honestly, the same posture
ADR 0092's ten deferred Spire nodes already established.

## Verified

`research_catalogue_test.dart`: 12 items, ids 1-12, Branch A never appears
as a discrete entry, every implemented item's own `balanceNote` absence
checked, every deferred item's presence checked. `research_workshop_test
.dart`: the Insight cost matches the table exactly for a sample of items,
the account-level-9 lab gate, the already-completed guard, insufficient
Insight. `loadout_workshop_test.dart`: the 1-loadout cap without the
research and the 2-loadout cap with it, overwrite-by-name, delete,
equip changing exactly the three account fields it should. A new
`world_windline_memory_test.dart` (or folded into the existing Windline
test file) confirms a Windline survives `clearRoom()` when the flag is set
and does not otherwise, and composes correctly alongside *Lingering*
(either one alone is sufficient; neither is required for the other).

## Consequences

Two of Research Lab's twelve items are live; the ten that remain need
either a real design decision (Boon Banking's own selection policy), new
non-trivial API surface (Shrine Ledger's peek, Double Draw's fourth tier),
or nothing this session builds at all (presentational items, Deep
Descent's missing tier-select). Marks and Ascension remain the other two
open systems of Phase 13.
