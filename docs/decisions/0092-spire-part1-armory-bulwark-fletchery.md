# ADR 0092 — The Spire, Part 1: content, workshop, and 14 reused-channel nodes

**Phase** 13 (meta progression), Part 1.
**Date** 2026-09-05
**Status** Resolved for the scope below; ten nodes explicitly deferred.
**Severity** High. This is the term docs/02 §2.6's own derivation chain names
as the missing lever behind ADR 0089's TTK finding — closing part of it is
exactly what turns that finding from "a gap" into "a gap with a fix landing."

---

## Why now, not strictly in roadmap order

Phase 12's own TTK harness (ADR 0089) found the game's real TTK curve
diverges hard from chapter 4 on, and identified the cause precisely:
"`required Spire investment`" is a real term in docs/02 §2.6's own
derivation chain, and the Spire has zero implementation. Phase 13 (Meta
progression, this ADR) is the very next phase in the roadmap regardless —
this is not a reordering, just the most load-bearing reason to start it now
rather than pursuing Phase 12's own harder-to-model remainder (Boon Power
Score, pick-rate — both blocked on a survival-capable bot or a
player-preference model, neither of which exists; a real, separate
undertaking flagged rather than guessed at).

## What already existed, unexamined until now

The save-schema layer for all four of Phase 13's systems was already fully
modelled: `SpireState` (`nodeLevels`, `tierGatesUnlocked`,
`totalGoldSpent`), `ResearchState`, `AscensionState`, `MarkState` all exist
on `PlayerSave` with docs/04-citing doc comments, `PlayerProfile
.accountLevel` exists (the Spire's own wing-unlock gate), and
`Wallet.insight` exists (the tier-gate currency). `Curves.spireNodeCost`/
`spireCumulativeCost` already implement docs/02's own cost curve exactly.
None of `lib/game/spire/`, `research/`, `ascension/`, or `marks/` exist —
the content, the workshop (buy/level mechanics), and every node's actual
effect are all genuinely new work, but on a foundation that turned out far
more complete than "zero implementation" suggested.

## Decision — 14 of 24 nodes wired to a real combat effect this Part

Every node maps onto docs/04 §4.1's own three-term power formula
(`ATK = ... · (1 + spireMight) · ...`), and **`StatChannel` already has an
entry for nearly every quantity the table names** — Boons and hero talents
already read/write the exact same crit chance, crit damage, max HP,
draw-speed, fire rate, pierce, elemental damage, Windline duration,
Confluence damage, projectile speed, and arrow-radius channels this table's
own wording describes. Reuse, not new plumbing, for these fourteen:

| # | Node | Channel | Per-level | Cap check (×80) |
|---|---|---|---|---|
| 1 | Warden's Might | *(folds into `baseAttack` directly — see below)* | 2.0 % | 160 % ✓ |
| 2 | Keen Edge | `critChance` | 0.35 % | 28 % ✓ |
| 3 | Executioner | `critDamage` | 1.5 % | 120 % ✓ |
| 4 | Quickdraw | `drawSpeed` (multiplicative) | −0.6 % | −48 % ✓ |
| 5 | Piercing Study | `pierce` (stepped, /16 levels) | +1 | +5 ✓ |
| 6 | Elemental Focus | `allElementDamage` | 2.0 % | 160 % ✓ |
| 7 | Vitality | `maxHealth` | 2.5 % | 200 % ✓ |
| 8 | Warded Hide | `damageReduction` | 0.45 % | 36 % ✓ |
| 10 | Second Wind | `healOnRoomClear` | 0.35 % | 28 % ✓ |
| 13 | Swiftshot | `fireRate` | 0.5 % | 40 % ✓ |
| 14 | Windline Weaving | `windlineDuration` (seconds, additive) | 0.018 s | 1.44 s ✓ |
| 15 | Confluence Study | `confluenceDamage` | 1.2 % | 96 % ✓ |
| 16 | Arrow Velocity | `projectileSpeed` | 0.8 % | 64 % ✓ |
| 18 | Wide Nock | `arrowRadius` | 0.3 % | 24 % ✓ |

Every docs/04-stated "cap at L80" figure was recomputed from its own
per-level number and checked against the table before trusting it — all
fourteen land exactly, confirming the table itself has no internal
inconsistency to inherit.

**Warden's Might is architecturally different from the other thirteen**,
and docs/04 §4.1 says so directly: `spireMight` is its own parenthesised
multiplicative term on `ATK`, the same standing `arrowMult` and
`(1 + Σ boonAtk)` have — not one more line inside the single summed
`combined` block hero talents, arrow modifiers, and every other Spire node
in this table already share. `HeroLoadoutResolver.apply` composes it by
multiplying `heroAtk * arrowBaseMult` by `(1 + spireMight)` **before** that
product becomes `baseAttack` — the exact point [ADR 0090](0090-boon-pick-loadout-collapse.md) made durable
against a later Boon pick.

**Spire's own 80 levels of one node are one source, not eighty** — docs/04
§4.1 rule 1 ("additive within a source") applies to the *node*, not the
*level*: Quickdraw's own cap (`0.6 % × 80 = 48 %`) is only exact if all 80
levels sum into one flat 48 % reduction and get applied as *one*
multiplicative factor (`0.52×`), not compounded 80 times
(`0.994⁸⁰ ≈ 0.618`, a 38 % reduction — the wrong number, and provably not
what the docs' own stated cap says). `SpireNodeDefinition.contributionAt`
sums first, composes once.

## Decision — ten nodes deferred, and why each one specifically

None of these are "not yet gotten to" placeholders — each hit a real,
checked reason a straight `StatChannel` reuse does not apply:

- **Momentum Mastery** (#9) — "+0.3 % per stack" would need to scale
  `DrawState.moveSpeedBonus`/`damageReduction`'s own **per-stack**
  constants (`moveSpeedPerStack`, `damageReductionPerStack`), which are
  hardcoded numbers on `DrawState` itself, not read from any `StatChannel`
  at all — no Boon or hero talent has ever needed to touch them, so no
  reusable hook exists. Its own second half ("+1 max stack / 20 lvl") maps
  cleanly to the already-consumed `StatChannel.maxMomentum` — deferred
  alongside the first half anyway, since a Spire node whose two halves ship
  in different Parts would need its own flag on top of `implemented`, for a
  single node not worth the complexity.
- **Iron Resolve** (#11) — "−0.5 % elite & boss damage taken" needs a
  target-*category*-scoped damage-taken channel; the one that exists,
  `damageTakenMultiplier`, applies to every hit regardless of who dealt it.
- **Last Light** (#12) — "survive a lethal hit at 1 HP, 60 s cooldown" is a
  proc-and-cooldown mechanic with no existing analogue anywhere in the
  player's own kit (every proc-and-cooldown primitive in this codebase is
  on the *enemy* side). New primitive, not a reuse.
- **Deflection** (#17) — "+0.25 % ricochet chance" implies a per-hit roll
  granting a ricochet to *any* arrow. The only ricochet machinery that
  exists (`ProjectileStore.ricochetsLeft`) is a fixed count set once at
  spawn for Skimmer's own arrow specifically — there is no generic per-hit
  proc path to hang a chance on yet.
- **Fortune, Prospector, Boon Insight, Shrine Favour, Shardseeker**
  (#19, #20, #21, #22, #24 — the whole of Wing IV bar Vigor Well) — a real,
  checked architectural finding, not a guess: `shrineDiscount` and
  `rarePlusWeight` (the two of these five channels actually read anywhere)
  are read **directly off `BoonInventory.stats`**
  (`stage_runner.dart`'s own Shrine pricing, `boon_pool.dart`'s own draw
  weighting) — not through `world.combat`, the object
  `HeroLoadoutResolver.apply`/`LoadoutResolver.apply` compose. Folding
  Spire into `combined` the way the fourteen nodes above do would have zero
  effect on either read site. `goldMultiplier`, `materialMultiplier`, and
  `shardDropRate` are not read *anywhere* yet — Boons that grant them exist
  in the channel enum with no consumer at all. Wing IV needs its own
  integration pass into the reward/Shrine-pricing path, not this Part's
  combat-loadout one; a real scope boundary, not a shortcut.
- **Vigor Well** (#23) — `+1 max Vigor / 20 levels` targets
  `VigorState.max`, a `PlayerSave`-level field with its own regen service
  outside the combat sim entirely — a different integration point again.

Every deferred node still has full, correct content data
(`assets/data/spire.json`) and is fully purchasable through
`SpireWorkshop` — `implemented: false` only suppresses
`contributionAt`, so a player spending on one of these ten today loses
nothing that was ever live and gains nothing yet, honestly, rather than the
purchase silently doing nothing while looking identical to a working node.

## Tier gates — the one genuinely ambiguous number, resolved

docs/02 §2.11 and §4.2 both state "25/90/300 Insight, at L20/L40/L60" but
neither states which side of the boundary "at" falls on. Read as "buying
the *next* level past a boundary needs that boundary's own gate already
unlocked" — level 20 itself (reached by the 20th purchase) needs no gate;
the 21st purchase (crossing into the 21-40 band) needs the L20 gate
unlocked first. `SpireWorkshop.requiredBand(int n)` (`n` = the level about
to be bought, 1-based, matching `Curves.spireNodeCost`'s own convention)
implements exactly this: `0` for `n ≤ 20`, `20` for `21 ≤ n ≤ 40`, `40` for
`41 ≤ n ≤ 60`, `60` for `n > 60`.

## Verified

`test/game/spire_catalogue_test.dart`: all 24 nodes parse, ids 1-24 with no
gaps, every wing's own unlock level matches docs/04, every "cap at L80"
figure independently recomputed and checked against the table (the same
verification this ADR's own table above performed, now pinned in code so a
future data-entry typo fails the suite instead of only this document).
`test/game/spire_workshop_test.dart`: cost curve matches `Curves
.spireNodeCost` exactly, the level-80 ceiling, the tier-gate boundary at
exactly level 21/41/61 (not 20/40/60), wing-unlock-by-account-level,
insufficient-gold and insufficient-Insight paths. `test/game
/hero_behaviour_test.dart`'s own convention extended with a `spireArena`
group: each of the fourteen wired nodes measured in isolation the same way
every hero passive in this codebase already is — a maxed (L80) node's own
measured bonus checked against its own table cap, independently per node.

## Consequences

The Spire now measurably changes a build for the first time — `ExpectedPower`
(ADR 0089) can be extended to include a real, non-zero Spire contribution
once a policy for "how much Spire should an expected-power player have at
chapter N" is decided (a genuine, separate design question, not attempted
here). Ten flagged nodes and three of Phase 13's four systems (Research,
Marks, Ascension) remain open — this ADR closes the Spire's own
content/workshop/fourteen-node vertical slice, not the whole phase.
