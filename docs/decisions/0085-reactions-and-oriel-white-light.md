# ADR 0085 — Reactions actually fire in real gameplay, plus Oriel's White Light

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Oriel is the fourteenth hero with nothing deferred —
and the last of the Phase 10 hero-behaviour ledger's "just needs building"
entries; the two that remain are architecture-level questions, not
implementation gaps.
**Severity** High. This is not a narrow Oriel fix. Docs/08 §8.2 calls
Reactions "the deepest idea in the game," and they had never once fired in
real gameplay — five already-shipped, already-selectable Boons, an
already-shipped affix, and two of Oriel's own talents were silently doing
nothing, for every player, in every run, before this.

---

## What was actually missing

The ledger's own note on `orielWhiteLight` said the gap was "Reaction/
elementalBonus damage wiring that does not exist anywhere yet." Tracing it
found the gap was bigger than that sentence implies:

- `ElementSystem.resolveReaction` (docs/08 §8.2's own element-pairing
  logic — Steamburst, Firestorm, Blightfire, Superconduct, Rime Rot,
  Corrosive Arc, Prismbreak) existed, was fully unit-tested in
  `elements_test.dart`, and was called by **nothing** outside that test
  file. `ConfluenceSystem`'s own sweep already collects exactly the raw
  material a reaction needs (`ConfluenceResult.elements` — the distinct
  elements crossed) but nothing downstream of it ever asked "did these two
  elements react?"
- `DamageResolver.resolve`'s own step 6, "Elemental / reaction bonus," is
  a real, already-clamped term in the documented damage formula
  (docs/08 §8.1) — but its `elementalBonus` parameter was fed exclusively
  from `ProjectileStore.elementalBonus`, a field nothing ever set to
  anything but its own reset value of zero.
- Six `StatChannel` entries (`emberDamage`, `frostEffect`, `stormDamage`,
  `toxinDamage`, `allElementDamage`, `reactionDamage`) composed correctly
  from Boons, affixes and hero talents into `BoonStats` — Layer 1 of
  `boon_effects_test.dart`'s own coverage already proved that — but
  **nothing read any of them.** Five Boons (*Kindling* #77, *Rime* #78,
  *Charge* #79, *Blight* #80, *Conductor* #82, *Reactive* #87, *Catalysis*
  #89) and one affix (*Resonant*) were live in the game, pickable, and
  worth exactly nothing every time.

## Decision — wire the trigger and the multiplier; leave each reaction's bespoke secondary effect for later

**`ProjectileSystem._applyHit` now calls `ElementSystem.resolveReaction`**
whenever an arrow's own `confluenceElementMask` is non-zero — it has
threaded at least one coloured Windline this flight — passing that mask as
the crossed side and the arrow's own single element (`element`, not
`elementMask`) as `incoming`. Gated on a non-zero mask specifically so the
overwhelming majority of hits, which never touch a Windline at all, never
pay for `status.canReact`'s own per-enemy cooldown check.

**An arrow carrying several of its own elements at once (Prism, a
multi-element Boon) passes `incoming: null`.** `resolveReaction` takes one
incoming element, not a mask, and guessing which of several to prefer for
a case this rare was not worth the complexity — three or more *crossed*
elements still collapses to Prismbreak regardless of what the arrow itself
carries, so the highest-value case (Oriel's own Prism) still reaches a
reaction; only a pairwise reaction is unreachable while an arrow's own
mask is already full, a narrow, documented gap.

**`CombatModifiers.elementalBonusFor` is the new home for step 6**, mirroring
`damageSumFor`'s own shape for step 5 exactly: composed once per loadout
from the six channels above, read per hit against the arrow's own element
mask and whatever reaction (if any) it triggered. Elemental and reaction
bonuses sum together before entering the one multiplicative term
`DamageResolver` already reserves for them — the identical
additive-within-a-source rule every other term in this formula follows.

**Deliberately not implemented: each reaction's own bespoke secondary
effect.** `Reaction`'s own doc comments describe more than a number —
Steamburst is "AoE plus an armour shred," Firestorm's chains "ignite,
chain count rises," Superconduct's chains "cannot miss," Rime Rot "extends
the freeze," Corrosive Arc's chains "spread Toxin." `Reaction.areaRadius`
even carries real, tuned values (2.5 for Steamburst, 4.0 for Prismbreak)
that nothing has ever read. This ADR wires the trigger and the shared
damage multiplier — the part every reaction has in common, and the part
every StatChannel above was actually waiting on. The six bespoke effects
are a real, larger follow-on scope (a new AoE-on-reaction primitive, a
chain-count modifier, a DoT-rate-doubling flag, a freeze-duration
extension) deliberately left for their own pass rather than guessed at
here alongside an already-large change to the hottest path in the game.

## Oriel's own two remaining gaps, now unblocked

**Attuned (T1b, `allElementDamage`) and Resonance (T3a, `reactionDamage`)**
needed no hero-specific code at all — both are pure `StatModifier`s with no
`behaviour` field, so as soon as `CombatModifiers` composed and read their
channels, they simply work, the same way `vaneFarsight`/`liraDeepRoots`
never needed a `HeroBehaviour` entry either.

**White Light (T5b) — "Prism 6 s but reactions deal x3"** needed one more
piece: `hero.prismRemaining` now reads 6.0 instead of the base 10.0
(`_orielWhiteLightPrismDuration`, mutually exclusive with *Endless Prism*'s
own 16 s, the same way the two ★5 branches always are), and while that
window is live, a triggered reaction's own bonus portion — not the whole
hit, and not *Resonance*'s separate +50 %, which composes on top through
the ordinary channel — is multiplied by 3 before entering
`elementalBonusFor`'s sum. "Reactions deal x3" reads as the reaction's own
contribution scaling, not a fresh independent bonus, the same reading
Resonance's own "+50%" already established for the identical bonus.

## Verified end to end

Four new tests in `confluence_test.dart`'s own "end to end in a live world"
group: an Ember arrow through a live Frost trail now emits
`reactionTriggered` (something this codebase's own test suite could not
have asserted true before this change); an isolated same-element-vs-
different-element comparison confirms the reaction's own 1.80x lands
almost exactly on the triggering hit, isolated from Confluence's own stack
bonus by holding the crossing geometry identical between the two runs; no
trail element at all behaves identically to a matching one.

Ten new tests in `boon_effects_test.dart`'s new "elemental and reaction
bonus resolves per hit" group, mirroring `damageSumFor`'s own Layer-2
style exactly: each of the four elemental Boons raises only its own
element; an arrow with no element gets none of them; Conductor/Reactive/
Catalysis all correctly require an actual reaction to have something to
add to; the two bonus classes sum rather than multiply.

Four new tests in `hero_behaviour_test.dart`'s "Spectrum and Prism" group:
Attuned's own +30% (isolated by pinning both sides of the comparison to
the same star level — `heroAtk`'s own scaling would otherwise leak into
the ratio, the same care `Steady (★1b)`'s own existing test already
takes); Resonance's own +50% on top of a real Steamburst; White Light's
own 6 s window; and White Light tripling a live Prismbreak's own bonus
portion specifically (autoFire held off until Prism is confirmed live, so
the very first arrow measured is guaranteed a Prism arrow rather than an
ordinary one that happened to fire the same tick as the cast itself).

## Consequences

`pendingHeroBehaviourWork` drops to 2: Torv's *Conductive Lines* (needs
Windline-travel-along indexing) and Nyx's *Twin Step* (needs the shared
single-charge Ultimate meter restructured — an unanswered design question,
not merely unbuilt). Both are architecture-level decisions rather than
"build the obvious thing"; the entire Phase 10 hero roster that could be
built without one now is.

A genuine, larger follow-on now exists and is worth its own future ADR:
each reaction's own bespoke secondary effect (the AoE bursts, the chain
modifications, the DoT-rate doublings, the freeze extension) that
`Reaction`'s own doc comments and `areaRadius` field describe but this
change deliberately does not implement.
