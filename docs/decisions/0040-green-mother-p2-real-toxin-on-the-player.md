# ADR 0040 — Green Mother's own P2: real Toxin, inflicted on the player for the first time

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2. P3 (a 3s exposed-core window every 8s;
everything else invulnerable) is not built — a known, flagged gap.
**Severity** Medium. Reuses `StatusStore.apply` directly rather than
building a parallel status system — the first time any boss applies a
*real*, shared status effect to the player, not a boss-specific approximation
of one.

---

## What was missing

docs/06 §8, The Green Mother: P2: "Roots erupt along telegraphed lines;
contact applies stacking poison to the player." Green Mother's own P1
(ADR 0028) already established this fight as one built almost entirely
from *existing* systems reaching the player/boss in ways nothing had
combined before; P2 continues that pattern in a new direction — applying
an *enemy* status onto the *player*.

## Decision — reuse `StatusStore.apply`, not a parallel "poison stacks" field

Before writing anything boss-specific, checked whether Toxin's own real
machinery could be reused directly rather than approximated. It can:
`StatusStore.toxinStacks` is a plain `Uint8List` sized to every entity in
the sim, player included, and `StatusStore.apply(slot, SimElement.toxin)`
already stacks it identically regardless of source (an arrow's own
element, a Boon, or now a root) — capped at `ElementTuning.toxinMaxStacks`,
the same number every other Toxin source already respects. So "stacking
poison to the player" needed **zero new storage and zero new stacking
logic** — `ctx.status.apply(ctx.player, SimElement.toxin)` on contact is
the entire implementation. This is a materially different move from
Rimefather's own "Frost" (ADR 0026/0038, thematic only, no real elemental
status touches the player) — here the real primitive turned out to already
reach the player's own slot, it had simply never been *called* that way
before.

## Decision — the tick damage is genuinely new, and deliberately not routed through `ElementSystem`

`ElementSystem`'s own DoT pass is gated to `EntityKind.enemy` only — Toxin
(and every other element) has only ever been something the player
inflicts, never receives, so widening that gate to also process the player
would be a real change to a shared, foundational system, for the sake of
one boss. Instead, `GreenMotherSystem` applies the tick damage itself,
directly: `ElementTuning.toxinPerStackPerSecond` (0.9%/stack/s), the exact
same rate and the same *continuous, not discretised* cadence
`ElementSystem` already uses for every ordinary DoT — matched deliberately,
so a player standing in accumulated poison from this boss feels
identical to poison from anywhere else in the game, even though the code
path applying it is different. **Toxin stacks are permanent, matching the
existing system's own behaviour** — nothing in `StatusStore` decays Toxin
today (unlike Burn, which has its own duration/decay), so this boss does
not invent a special decaying variant just for itself.

## Decision — roots deal no direct damage of their own

The card names only the poison; it never says the eruption itself hits.
Read the same way Silversong's own "no HP damage at all" card was read
(ADR 0024) — build only what is stated rather than adding an unstated
damage component "because every other line hazard has one." The ongoing
Toxin DoT is real, continuous damage in its own right; it does not need a
second, separate burst on top of it to feel consequential.

## Structure — three one-shot roots, not a persistent hazard

Each eruption spawns three fresh, untargetable, bare children (Cinder
Choir's own "one telegraph per owning child" shape, ADR 0018), placed via
`EnemySpawner.findSpawnPoint` at a random point and a random aim, each
warning then resolving once and **despawning itself** immediately after —
a one-shot event, unlike Silversong's own persistent pillars (ADR 0036)
or Cinder Choir's own permanent tether anchors. The resolved line's own
committed endpoints are read back out of the telegraph
(`xAt`/`yAt`/`toXAt`/`toYAt`), the fourth boss to reuse that exact trick
(Weeping Gate, Vermillion, and now this one). A stray splash hit on a
still-forming root is harmless the same way every other bare boss child's
own oversized health margin already makes it — sized to the primary's own
max health.

## Consequences

Six of twelve campaign bosses now have some form of P1+P2 (Gaunt,
Silversong, Vermillion, Rimefather, Arclight, Green Mother). This is the
first boss to demonstrate that a *shared, entity-agnostic* primitive
(`StatusStore`) can sometimes already reach the player correctly even when
the *system that acts on it* (`ElementSystem`) cannot — worth checking
specifically, not just assuming, the next time a card asks an enemy to
inflict something the game already lets the player inflict on enemies.

**Not built here: P3** (the 3s exposed-core window, everything else
invulnerable) — needs a real "invulnerable outside a window" state no
boss has needed yet, the same open gap Green Mother's own P1 ADR (0028)
already named. Once `bossPhase` reaches 2, spawning and root eruptions
both stop, matching every other boss's own undone-phase posture.
