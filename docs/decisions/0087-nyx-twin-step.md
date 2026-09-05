# ADR 0087 — Nyx's Twin Step: overflow into a second charge

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved by the project owner's own explicit call. Nyx is the
sixteenth hero with nothing deferred — the entire Phase 10 hero-behaviour
roster now has nothing deferred.
**Severity** Medium-high. Touches `HeroRuntime.chargeFromDamage` and
`SimWorld._updateUltimate` — the single shared Ultimate meter every one of
the sixteen heroes reads and writes — not a hero-local addition.

---

## What was missing

docs/07 §7.4, Nyx's own T5a: **"Twin Step: 2 charges."** Every hero's
Ultimate reads one shared meter, `HeroRuntime.ultimateCharge` (0.0 to
1.0) — `ultimateReady` is `>= 1.0`, and firing resets it to exactly 0.
"2 charges" needed either a second, parallel meter, or letting this one
run past its usual ceiling — and docs/07 does not say which: does damage
dealt while already `ultimateReady` overflow into charging a second use,
or does it fill an entirely separate meter at its own independent rate?
The ledger's own note on this talent named the ambiguity explicitly and
declined to guess.

## Decision — raise the ceiling, spend one charge at a time

**The project owner's call: overflow into the second charge.** Rather
than a second meter, `chargeFromDamage`'s own ceiling rises from 1.0 to
2.0 specifically for a Nyx player holding this talent
(`has(HeroBehaviour.nyxTwinStep) ? 2.0 : 1.0`) — every other hero's own
ceiling is untouched, so the shared meter behaves identically for the
other fifteen. Firing the Ultimate now subtracts exactly 1.0 from
`ultimateCharge` rather than zeroing it outright — for every hero but Nyx
this is the identical operation, since their own ceiling never lets the
value exceed 1.0 in the first place, but for a Nyx player who banked a
full 2.0, firing once leaves 1.0 behind: `ultimateReady` never drops, and
pressing the button again fires a genuine second Ultimate rather than
requiring a re-charge.

**One existing site keeps its own hard 1.0 clamp deliberately.** Wren's
own *Warden's Fury* (T5b, "Ultimate refunds 30% charge on kill") reads
and clamps `hero.ultimateCharge` directly in `AiSystem`'s own death pass.
It is not raised to Twin Step's own ceiling, because that branch only
ever executes for a Wren player — who, being a different hero, is never
also a Nyx player holding Twin Step. The two ceilings can never actually
collide, so the simpler, narrower clamp stays exactly as it was.

## Verified end to end

Five new tests in the "Umbral Step" group: damage that would push charge
to 2.4 without a ceiling lands at exactly 2.0 with Twin Step, and at
exactly 1.0 without it (the pre-existing behaviour, unchanged); firing
with 2.0 banked leaves exactly 1.0 and `ultimateReady` still true; firing
twice in a row from 2.0 drains to exactly 0 and emits two separate
`ultimateUsed` events — two real casts, not one cast and a stray
re-charge; and, without the talent, a single charge still resets to
exactly 0 on fire, confirming the shared subtraction change is a no-op
for every other hero.

## Consequences

`pendingHeroBehaviourWork` is empty. Every hero behaviour declared,
parsed and registered on the runtime across all sixteen heroes in the
Phase 10 roster now has real gameplay behind it.

The one deliberately-scoped exception noted elsewhere remains: each
elemental Reaction's own bespoke secondary effect (ADR 0085's own
"Consequences" section — Steamburst's AoE and armour shred, Firestorm's
own chain, and so on) is real, larger follow-on work, not a Phase 10
hero-behaviour gap.
