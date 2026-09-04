# ADR 0020 — Cinder Choir P3: un-sharing the pool, alternating cones

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. Cinder Choir's full fight (P1/P2/P3) is now built.
**Severity** Medium. Two real primitives (a permanent parent link, distinct
from the mutable health link; a per-child attack state machine reusing
existing fields) plus one real bug caught by an existing, unrelated test.

---

## What was missing

docs/06 §1 P3: "All three light simultaneously and fire alternating 90°
flame cones. Killing one permanently removes it." Two things ADR 0018 left
explicitly open: whether the shared pool (`EnemyStore.linkedHealthSlot`)
gets a "later un-shares" mode, and what "killing one" even means for a boss
whose `BossPhaseSystem`-tracked HP has, until now, always lived on one
entity.

## Decision — un-share into three equal, independent pools

**The first tick `bossPhase` reaches 2, each still-linked child gets
`linkedHealthSlot = -1`** (its own health field becomes the real one) **and
`store.health[j] = store.maxHealth[j] = remaining / 3`**, `remaining` being
whatever the shared pool held at that exact moment. Plate is cleared on all
three ("all three light simultaneously" — no more plate distinction at all,
not even the full-circle one ADR 0018 built for P1/P2). From that tick on, a
child is an ordinary, independently-healthed bare entity: player damage
lands on it directly (no redirect to chase), and when its own health reaches
zero, the *existing*, unmodified `AiSystem._resolveDeaths` → `_reap` path
removes it — "killing one permanently removes it" needed no new death logic
at all, only for the child to stop being a redirect target.

**`store.health[primary]` (which `BossPhaseSystem` and the death check both
still read as this boss's real HP) is kept as the live sum of whichever
children are still alive**, recomputed every tick. This is a derived value
now, not any single field's own truth — the primary "dies" exactly when
that sum reaches zero, i.e. exactly when the last child does, and the
existing bare-entity reap path handles the primary's own removal
unmodified too.

**New field: `EnemyStore.bossParent`**, permanent, set once at spawn,
never changed. `linkedHealthSlot` answers "where does my damage go *right
now*" and stops meaning anything once P3 un-shares it; `bossParent` answers
"whose child am I, structurally" and keeps meaning that for the rest of the
child's life — every P3 method (the split itself, the health sum, the cone
turn-order, the cleanup on the primary's death) needs the second question,
not the first, which is exactly the gap ADR 0018's own "Consequences"
section flagged without resolving.

## Decision — alternating cones reuse the ordinary enemy state machine

**Each cone attack is tracked on its own attacking child's own
`EnemyStore.state`/`stateTimer`** — `AiState.windUp` while the amber cone
telegraphs, then a one-tick lethal flash and a `playerInCone` damage check
on expiry, the identical shape the Screecher's own scream already uses
(`salvo_tree.dart`) down to the "second `beginCone` call with
`resolvesAt: now`" flash pattern. These fields exist on every enemy
already and sit completely unused on a bare boss child until P3 claims
them — no new per-child state was needed.

**"Alternating" is a strict round-robin with no gap**: the moment one
child's cone resolves, the next living child's own wind-up begins in the
same tick, tracked via `bossActiveChildIndex` (P1/P2's own rotation-order
field, free to mean something else once P1/P2 stop using it) rather than a
separate cadence timer. A child that dies mid-wind-up simply never resolves
— the next tick finds no one in `windUp` at that ordinal and hands the turn
to whoever is still alive, self-correcting within one tick with no special
case written for it.

## Four more numbers, all reused

Continuing ADR 0019's own posture (this boss's whole kit draws from one
small set of anchors rather than a new invented number per mechanic):

| What | Value | Source |
|---|---|---|
| Cone half-angle | 45° | docs/06 itself — "90° flame cones" is the one real number P3 states |
| Cone wind-up | 0.6 s | Reuses P2's own `_p2TetherCooldown`/`_p2WarningSeconds` magnitude |
| Cone damage | 9% max HP | Reuses P2's own tether damage (itself from the Thresher) |
| Cone range | 9.0 u | Reuses P2's own spoke length |

## A real bug this pass found and fixed

`boss_phase_system_test.dart` — written for ADR 0017, before any of this
existed — spawns a Cinder Choir-archetype boss through the *generic*
`SimWorld.spawnBoss` specifically to test `BossPhaseSystem` in isolation,
with no effigies at all. The first version of the P3 sum-sync above
overwrote `store.health[primary]` unconditionally, including with a sum of
*zero* children for that childless test scaffold — zeroing a boss's real,
correctly-computed health the instant it reached P3, which the ordinary
death path then reaped, resetting `bossPhase` back to 0 via
`AiSystem._reap`'s own `enemies.reset(slot)` call and silently failing two
already-passing, unrelated tests. Fixed by only overwriting
`store.health[primary]` when at least one `bossParent`-linked child was
actually found — a boss with real children (every real fight) behaves
identically; a childless test scaffold is simply left alone. Caught by
running the full suite, not just this feature's own tests — the standing
instruction to always do so before calling a slice done.

## Consequences

Cinder Choir's fight is now fully built end to end — the first complete
boss in the game. The multi-body patterns proven here
(`linkedHealthSlot`/`bossParent`'s split between "current" and "permanent"
relationships, reusing `state`/`stateTimer` for a bare child's own attack
cycle) are the concrete answers ADR 0018 asked Skarn, Coilspine and Thrall
to come back and check against — Skarn's own 1→2/4 split in particular
looks like a very close cousin of this exact split, done twice.
