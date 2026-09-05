# ADR 0077 — Torv's Overload and Thunderhead: two more reuses of existing per-enemy timers

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved.
**Severity** Low. Both talents extend `_applyTorvChain`'s own existing
per-target loop with parameters into fields two other heroes already use.

---

## What was missing

docs/07 §7.3, Torv T3: **"Overload: chain targets take +20 % damage for
4 s."** T5b: **"Thunderhead: Tempest also stuns 0.5 s per chain."** The
ledger's own note said Overload "needs a timed per-enemy debuff this hit
path does not track yet" and Thunderhead "needs a stun applied per chain
link" — both read, on a second look, as things this sim already has.

## Decision — reuse `markedRemaining` a third time, `frozenRemaining` a third time

**Overload** reuses `EnemyStore.markedRemaining` — the exact shared timer
`ProjectileSystem`'s own Marked-read block already branches on for Vane's
Marked (+25 %) versus Halden's Sentence (+20 %), on the established "only
one hero is ever equipped, so reading the right one's own bonus is
unambiguous" reasoning. That block gets a third branch for Torv's own
+20 %, and `_applyTorvChain` — which resolves every chain hit — gets an
optional `enemies`/`markDuration` pair, setting `markedRemaining[target] =
4.0` on every chained target when `torvOverload` is active.

**Thunderhead** reuses `StatusStore.frozenRemaining` the same way Rook's
own Anchor already borrows it from Frost (ADR 0070) — "the same
'velocity zeroed, telegraph cancelled' effect `AiSystem._freeze` already
gives any frozen enemy." `_applyTorvChain` gets a second optional
`status`/`stunDuration` pair, gated on `hero.tempestNockRemaining > 0` (so
the base Arc passive's own ordinary chains never stun, only Tempest Nock's
own window does) and guarded with the same "never shortens an active
effect" rule Anchor already established.

Both additions live in the exact same per-target loop inside
`_applyTorvChain` that already applies chain damage — no new call sites, no
new fields on `HeroRuntime`, nothing beyond two more parameters on an
existing method and two more constants.

**Conductive Lines (T3a) stays pending** — untouched by this ADR. It
specifically rewards a chain that "travels along Windlines," and
`_applyTorvChain`'s own doc comment already explains why chains do not
actually check Windline adjacency: "querying which enemies sit near a live
Windline segment is a relationship nothing in the sim currently indexes."
That gap is real and unrelated to what Overload/Thunderhead needed.

## Verified end to end

Six new tests: a chain hit marks its targets (`markedRemaining` becomes
positive); without Overload, chains never mark anything; a target already
carrying Overload's own mark takes +20 % more on its next hit (mirroring
Vane/Halden's own "seed the mark directly, then measure the ratio"
convention exactly); Tempest Nock's chains stun a target within the
window; without Thunderhead, they never do; and the base Arc passive
(Thunderhead picked, but Tempest Nock not active) never stuns outside the
Ultimate's own window. All six passed on the first real attempt.

## Consequences

`pendingHeroBehaviourWork` drops to 21. This is the fourth hero-behaviour
gap this session found to already have its own primitive waiting nearby
(Halden's damage-reduction second parameter, Rook's Anchor as a Frost
reuse, Ovrin's Riposte via a new but small primitive, Sela's Shatter via an
existing read-before-reset spot, and now Torv's own pair) — worth
continuing the same re-audit on what remains.
