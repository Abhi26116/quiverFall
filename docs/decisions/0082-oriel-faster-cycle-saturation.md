# ADR 0082 — Oriel's Faster Cycle and Saturation: a real per-shot grouping, and a generic duration multiplier

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved.
**Severity** Medium. Faster Cycle required changing the base Spectrum
passive's own behaviour, not just adding a talent beside it.

---

## Gap 1 — Faster Cycle only means something if the base passive groups by shot

docs/07 §20, Oriel's passive: **"Spectrum: arrows cycle Ember → Frost →
Storm → Toxin, one element per shot."** T1: *Faster Cycle* — **"cycle every
shot even at Tier III multishot."** Spectrum and Prism were already
implemented, cycling `HeroRuntime.cycleIndex` once per arrow spawned — which
is also, incidentally, exactly what Faster Cycle's own card text asks for.
That left the talent with nothing to add: a base passive that already
cycles every arrow cannot be improved by a talent that makes it cycle every
arrow.

**Decision — "one per shot" is the base passive's real behaviour; multishot
sharing one element is what Faster Cycle removes.** `SimWorld._spawnVolley`
— "releases one shot, which may be several arrows" — is the shot boundary
that already exists in this codebase for exactly this reason (Split
Shot/Twin Nock's `extraArrows`, Rain of Nocks' own Tier-III-only fan). It
now rolls `cycleIndex` once per call, before any arrows spawn, and every
arrow that single call produces — however many — carries that one shared
element; `cycleIndex` itself only advances once. *Faster Cycle* (T1a) skips
that sharing, falling back to `_applyOrielElementCycle`'s own per-arrow
advance, so each arrow within one multishot release gets its own next
element in the rotation. Prism still wins over both, unconditionally — it
never reads `cycleIndex` at all.

A single-arrow shot (`extraArrows == 0`, no Rain of Nocks) behaves
identically either way, so this is invisible to every hero except when
Oriel's own Spectrum or Prismshaft's own copy of the same rotation
(`ArrowBehaviour.prismshaftCycle`) is actually cycling and a shot happens
to be more than one arrow.

## Gap 2 — Saturation as a generic duration multiplier, not an Oriel-only branch

docs/07 §20, T3: *Saturation* — **"elements persist 2x longer on
enemies."** Nothing before now needed a status duration to scale rather
than override, so no such parameter existed.

**Decision — `StatusStore.apply` gained a plain `durationMultiplier`
(default 1.0), read only by Ember's own `burnRemaining` and Frost's own
`frozenRemaining` once discharged.** Toxin has no duration to extend at
all — it stacks and persists until cleared, never on a timer — and Storm
resolves instantly with no lingering state, so both correctly ignore the
parameter outright rather than needing a special case to skip it. The
multiplier is computed once in `ProjectileSystem._applyElement` (the
generic per-arrow element path every one of Oriel's cycling arrows already
goes through) from `hero.has(HeroBehaviour.orielSaturation)`, not threaded
into `_applyHeroInnateElements` — that path is gated on Kade's Kindling,
Sela's Chill and Sable's Toxin, each conditioned on a hero Oriel is never
also equipped as, so it would never fire there regardless.

Chill's own *accumulation* toward the freeze threshold is deliberately
untouched: "persist longer" reads as the payoff status lasting longer once
applied, not the build-up to it happening slower — the same distinction
`chillPerHitOverride` already draws from `burnDurationOverride` for a
different reason (a per-hit rate vs. a duration).

## Verified end to end

`elements_test.dart` gained three low-level tests directly on
`StatusStore.apply`'s new parameter: Burn lasts twice as long, a freeze
(once reached, in the same number of hits as ever) lasts twice as long, and
Toxin's stack count is unaffected. `hero_behaviour_test.dart` gained four:
Faster Cycle cycles every arrow across a forced 3-arrow multishot; without
it, the same multishot's three arrows share one element and the next
shot's three share the next; Saturation doubles a real Burn application's
own `burnRemaining` to 8 s; without it, the same hit lasts the ordinary 4 s.

## Consequences

`pendingHeroBehaviourWork` drops to 9. Only Oriel's own *White Light* (T5b)
remains pending for this hero — still blocked on the same missing
elemental/reaction damage-bonus wiring (`projectiles.elementalBonus` set
and never read) the ledger already names for *Attuned* and *Resonance*.
