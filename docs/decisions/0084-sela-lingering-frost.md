# ADR 0084 — Sela's Lingering Frost: a slow genuinely independent of Windlines

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Sela is the thirteenth hero with nothing deferred.
**Severity** Medium. A new, small pair of `EnemyStore` fields — no shared
system was edited, and the existing Windline slow path stays untouched.

---

## What was missing

docs/07 §6, T3b: **"Lingering Frost: frozen enemies leave a 3 s slow
field."** No radius or magnitude is given. The sim's only existing enemy
slow — `EnemyStore.slowRemaining`/`windlineSlowFactor` — is Windline- and
Boon-specific by construction: `AiSystem._applyWindlineSlow` sets
`slowRemaining` only when an enemy is standing near a *live Windline
segment*, and `windlineSlowFactor` is written only by `BoonSystem`, reading
the *player's* own trail and a Boon's own `slow` stat. Faking Lingering
Frost by dropping a zero-length Windline segment at the freeze point would
have silently made the talent's own strength depend on whatever
slow-related Boon the player happened to be holding that run, not on Sela
at all — a real, if easy to miss, correctness bug rather than a
placeholder.

## Decision — two small, purpose-built `EnemyStore` fields

**`lingeringFrostRemaining`** (source-side) is set the instant an enemy's
own Chill discharges into a freeze — detected in
`ProjectileSystem._applyHit` as a before/after transition
(`status.isFrozen(target)` false, then true, spanning both the ordinary
per-arrow element path and Sela's own innate-Chill path, since her usual
freezes come from the latter). **`lingeringFrostSlowRemaining`**
(target-side) is the field's actual movement effect, refreshed on every
enemy within radius by `SimWorld._tickSelaLingeringFrost`, and read in
`Steering.speedOf` as its own independent multiplier — stacking with, not
replacing, Windline slow and `windlineSlowFactor`.

**Two fields, not one, deliberately.** A single shared "I am both source
and target" timer would let the field propagate outward through a packed
swarm indefinitely — enemy A radiates onto B, B (now non-zero) radiates
onto C, and so on — which "a field left behind by *this* frozen enemy"
never promises. Keeping the roles on separate fields makes that
propagation structurally impossible: only an actual freeze transition ever
writes the source field, and the target field never writes the source
one.

**Numbers**, since docs/07 states only the 3 s duration:
- **Radius: 3.5 u**, reusing Glacier Nail's own base freeze radius — "the
  same reach as her own freeze" — rather than a second number for the same
  hero's kit.
- **Slow: 30 %** (`EnemyTuning.lingeringFrostSlow`), authored fresh rather
  than reusing the ambient `SimConfig.windlineSlow` (8 %) — that number is
  deliberately small because it applies everywhere a Windline exists, all
  the time; Lingering Frost is a rare, targeted zone that only exists near
  a freshly-frozen enemy, so a heavier number is what makes it read as the
  dedicated crowd-control pick a T3 talent is meant to be, not a rounding
  error on top of ordinary play.
- **Does not stack**: several overlapping fields all just set the same
  target field to its own fixed duration, the identical "set, don't
  accumulate, while in range" shape `_applyWindlineSlow` already uses for
  its own slow.

`EnemyTuning.lingeringFrostSlow` lives in `lib/game/balance/enemy_tuning.dart`
rather than as a private constant in `steering.dart` itself, honouring
that file's own stated rule: nothing in `game/sim/ai/` may declare a magic
number.

## Verified end to end

Five new tests: a freeze reached through ordinary combat (not a seeded
`frozenRemaining`, since the trigger is the *transition*, which a seeded
value never produces) radiates a field; without the talent, the same
freeze never does; a bystander within 3.5 u picks up the slow timer, one
outside it does not; and a genuinely moving nearby enemy's own velocity
magnitude drops by close to the documented 30 % once the field is live.

## Consequences

`pendingHeroBehaviourWork` drops to 3: Torv's *Conductive Lines* (needs
Windline-travel-along indexing — a bigger structural feature, nothing in
the sim currently indexes "which enemies sit near a live Windline
segment"), Nyx's *Twin Step* (needs the shared single-charge Ultimate
meter restructured — an unanswered design question, not merely unbuilt),
and Oriel's own *White Light* (blocked on the same missing
elemental/reaction damage-bonus wiring as *Attuned* and *Resonance*).
