# ADR 0046 — Thrall of the Nine's own P3: absorbed, not despawned

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. Thrall of the Nine now has P1+P2+P3, complete end to
end.
**Severity** Low-medium. A real interpretation call (does "absorbs" mean
the sigils are literally removed, or is it flavour for a locked-in
number) resolved in favour of the cheaper, equally faithful reading —
continuing the theme ADR 0041 already established for this boss's own P2.

---

## What was missing

docs/06 §9, Thrall of the Nine: P1 (ADR 0029) and P2 (ADR 0041) are both
already built. P3 — "Absorbs all remaining sigils for +25% damage each. A
player who destroyed five sigils fights a fundamentally different, easier
phase 3. The fight is a live conversation about the choices you made 60
seconds ago."

## Decision — "absorbs" is flavour for a locked-in number, not a despawn

The literal reading — the surviving sigil *bodies* vanish, folded into the
Thrall itself — would have meant rebuilding the entire rotation mechanism
P1/P2 already established (`_nextAliveSigilIndex`/`_findSigil`, both real
entity lookups) into something that iterates a *remembered set of
ordinals* instead, since there would be no bodies left to query. The
cheaper, equally faithful reading: P3 changes nothing about the orbit or
the rotation — docs/06 states no change to either — and simply locks in
one new number. The sigils keep orbiting, keep being individually
damageable, and the rotation keeps skipping whichever have died, exactly
as before; "absorbed" describes *where the bonus came from*, not a literal
removal of the bodies carrying it.

**The bonus itself is a one-time snapshot, not a live count.** The card's
own framing — "a player who destroyed *five* sigils," past tense, "the
choices you made 60 seconds ago" — is explicit that this is about
decisions already made by the time P3 begins, not an ongoing incentive to
keep hunting sigils during P3 itself. A new `_tickP3DamageBonus` counts
however many sigils are alive at the *exact* tick `bossPhase` first reads
2, multiplies by the card's own stated 25%, and locks the result in
`bossLastHitAgo` (unused anywhere in this file until now) — a genuine
one-time latch, gated by `bossChildIndex[primary]` (free: every other use
of that field in this system is on a *child's* own slot, never the
primary's) flipping from its default 0 to 1. A sigil killed later, during
P3 itself, still shortens the rotation (one fewer ability available that
turn) but no longer touches the locked bonus.

`_resolve`'s own damage line reads `_abilityDamage * (1.0 + bonus)`, where
`bonus` is `bossLastHitAgo[primary]` — zero for the entire P1/P2 run of
this system (that field is never otherwise touched), so this is a pure
addition with no risk of changing already-shipped P1/P2 damage numbers.

## Verified end to end, not just structurally

Three tests: one collapses the fight down to a single surviving sigil
(so exactly one ability, not two, can possibly fire that turn — sidestepping
P2's own "two abilities land independently" arithmetic entirely) and
asserts the *exact* resulting health, `100 − 0.09 × 1.25 × 100 = 88.75`
(one survivor, `1 + 0.25×1`). A second test locks the bonus in with all
nine sigils alive (`0.25 × 9 = 2.25`, read directly off `bossLastHitAgo`),
then kills every remaining sigil during P3 and confirms the stored bonus
is untouched — the mechanism's own defining property, not just its
headline number. A third confirms the orbit keeps visibly moving through
P3, unlike every other boss's own undone-phase freeze this session has
built so far.

## Consequences

Three of twelve campaign bosses now have a real P1+P2+P3 (Cinder Choir,
Silversong, Thrall of the Nine). This is the second P3 in a row (after
Silversong's) that needed no new sim primitive at all — worth checking,
before reaching for new mechanism on the next P3, whether the card's own
"hard"-sounding verb (absorbs, shatters, retracts) is describing a state
change to an *existing* mechanic's own inputs rather than a structurally
new one.
