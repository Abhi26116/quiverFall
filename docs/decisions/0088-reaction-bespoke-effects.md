# ADR 0088 — Every reaction's own bespoke effect, not just its shared multiplier

**Phase** 10 (hero behaviours) / core systems follow-on to ADR 0085
**Date** 2026-09-05
**Status** Resolved.
**Severity** High. Touches the armour computation and the DoT tick — both
per-hit, both already core, hot paths — plus `ElementSystem.resolveReaction`'s
own public signature.

---

## What was missing

ADR 0085 wired the trigger and the shared damage multiplier every reaction
grants, deliberately leaving each reaction's own bespoke secondary effect
(docs/08 §8.2's own "Effect" column) as flagged, separate follow-on work.
That table gives an exact number for every one of the seven:

| Reaction | Effect |
|---|---|
| Steamburst | 2.5 u AoE, -20% enemy armour for 5s |
| Firestorm | Chain targets are ignited; chain count +2 |
| Blightfire | Burn and Toxin both tick at 2x for 3s |
| Superconduct | Chains cannot miss; frozen targets take 2x chain damage |
| Rime Rot | Freeze duration +1s; Toxin stacks are not lost on freeze |
| Corrosive Arc | Chains spread 3 Toxin stacks to each target |
| Prismbreak | 4 u AoE, applies all four elements at max stacks |

None of the AoE, the armour shred, the doubled DoT, the freeze bonus, the
element-maxing, or any of the three "chain" modifiers existed. `Reaction
.areaRadius` (2.5/4.0) was real, tuned data nothing had ever read.

## Decision — a `Reaction?` alongside the multiplier, and two families of effect

**`ElementSystem.resolveReaction` now returns `({double multiplier,
Reaction? reaction})`** instead of a bare multiplier — a caller needs to
know *which* reaction fired to apply its own effect, not just how much
extra damage it grants. All eight existing call sites (`elements_test.dart`)
were updated to destructure the record; the multiplier half is
byte-for-byte the same value as before.

**Four effects land on the triggering hit's own target directly** —
`ProjectileSystem._applyReactionEffect`, called once per hit that resolved
a reaction, regardless of hero:

- **Steamburst**/**Prismbreak**'s own AoE reuses `_applyBramSplash` at the
  hit's own already-resolved damage in full — the identical "no fraction
  stated, reuse the hit" reasoning ADR 0009 already established for Iris's
  Weave AoE. The splash stays a flat number, no armour interaction, matching
  that function's own existing contract; the armour debuff below applies
  only to the struck target, not everyone the blast catches.
- **Steamburst**'s "-20% armour for 5s" is a new, *timed* field
  (`EnemyStore.steamburstArmourRemaining`), deliberately not folded into
  `armourShred` — that field is a *permanent*, Boon-accumulated stat with
  no notion of expiry, and repurposing it would have made a Rend-stacked
  build's own permanent shred silently start decaying.
- **Blightfire**'s "tick at 2x for 3s" is a new timed field
  (`EnemyStore.blightfireRemaining`), read once in `ElementSystem.update`
  and multiplied into both the Burn and the Toxin tick.
- **Rime Rot**'s "freeze duration +1s" adds 1.0 to `frozenRemaining`
  directly — a fresh brief freeze from nothing is exactly what "+1s"
  promises even when the target was not already frozen. Its own second
  clause, "Toxin stacks are not lost on freeze," needed no code at all:
  Toxin already never expires on its own (`StatusStore`'s own class doc —
  "Toxin: stacks and persists"), so nothing was ever there to lose.
- **Prismbreak**'s "applies all four elements at max stacks" sets Burn and
  Toxin to their own max-stack constants and Frost straight to a full
  freeze; Storm has nothing to set, since it already resolves instantly on
  every hit with no lingering state of its own.

**Three effects modify a *chain* instead of the hit** — Firestorm,
Superconduct and Corrosive Arc all read "Chain[s] ...". The only chain
mechanic in this sim is Torv's own Arc/Tempest Nock, so these three are
applied inside `_applyTorvChain` itself, per link, gated on whichever
`Reaction?` the *triggering* hit resolved to (passed straight through from
`_applyHit`):

- **Firestorm**: every chained target is ignited (`_applyOneElement`, so
  it respects `resistsElement` and emits the same event any other Burn
  application does), and the chain's own target count gets +2 before the
  chain even resolves — read on the same trigger, not fired independently.
- **Superconduct**: "cannot miss" needed nothing — nothing in this sim
  ever makes a chain fail to connect once a target is found, so the clause
  was already true. The frozen-target 2x is checked *before* that same
  link's own stun (if any, from Thunderhead) could freeze it, so a target
  only just rooted by this very chain never retroactively qualifies.
- **Corrosive Arc**: every chained target picks up 3 Toxin stacks via
  `_applyOneElement`'s existing `toxinStacksPerHitOverride`, the same
  per-hit-count override Sable's own Fast Acting already uses for a
  different number.

A reaction fired by a non-Torv hero simply has nothing for its own
chain-modifying clause to act on — the shared multiplier still applies in
full; only the chain-specific rider degrades to a no-op, which is the
correct, sensible outcome for a mechanic Torv is the only hero to have at
all.

## Verified end to end

Four new tests in `confluence_test.dart`'s own "reaction bespoke effects"
group (Steamburst's armour timer plus its AoE reaching a bystander;
Blightfire's timer plus a doubled tick measured against the plain
`ElementTuning` rate; Rime Rot's +1s freeze from a single Frost hit that
alone cannot reach the freeze threshold; Prismbreak's all-four-at-max plus
its own 4 u AoE). Four new tests in `hero_behaviour_test.dart`'s "Arc and
Tempest Nock" group (Firestorm reaching all 7 of 7 nearby targets — versus
exactly 5 of 7 without it — and igniting every one; Superconduct's frozen
target taking almost exactly double an ordinary target's own chain
damage, measured at the very first trigger to avoid the reaction's own
per-enemy cooldown diluting a later one; Corrosive Arc spreading 3 Toxin
stacks to every chained target).

## Consequences

Every reaction in docs/08 §8.2 now has its full, documented effect —
shared multiplier and bespoke rider both — live in real gameplay. This
closes the one follow-on ADR 0085's own "Consequences" section flagged;
nothing about docs/08 §8.2 is deferred anymore.
