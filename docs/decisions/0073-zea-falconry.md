# ADR 0073 — Zea's Falconry: temporary companions from the Ultimate

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Zea's own kit is now complete.
**Severity** Low. A straightforward extension of ADR 0071/0072's own
primitives, dispatched the identical way every other hero's Ultimate
already is.

---

## What was missing

docs/07 §7.3, Zea's own Ultimate: **"Falconry: summons 4 hawks for
12 s."** T5: *Skydarken* (8 hawks, 12 s) / *Great Hawk* (1 hawk, 250 %
ATK, 20 s, taunts).

## Decision — the same companion primitive, a finite lifetime instead of a permanent one

`_fireZeaFalconry` joins `SimWorld._fireUltimate`'s own identity switch
(`hero.has(HeroBehaviour.zeaFalconry)`), the same dispatch every other
hero's Ultimate already goes through. It spawns `CompanionSystem`
companions exactly like the passive Skyhawk (ADR 0072) does, differing
only in `lifetimeSeconds` — a real number instead of `double.infinity` —
which is also what keeps `HeroLoadoutResolver`'s own despawn-and-resync
sweep from ever touching them: that sweep only clears permanent
companions, so a mid-Falconry level-up correctly leaves the temporary
flock alone.

**Sharper Talons, Swift Hawk and Bonded apply to the summoned flock too**
— the identical "blanket hawk rule" reading ADR 0072 already established
for the passive, verified directly rather than assumed twice. Skydarken
and Great Hawk are this Ultimate's own two ★5 branches, mutually
exclusive by construction (an `if`/`else` on which is active, never
both). The four (or eight) summoned hawks are placed in a circle around
the player, each keeping that same offset as its own follow point — an
authored formation radius, since docs/07 states none, the identical
"spread rather than stack" reasoning the passive's own single hawk
already used for its own offset.

**Great Hawk's own "taunts" stays unbuilt**, the same flagged gap ADR
0071 already named for the primitive itself: no enemy AI in this roster
has ever targeted anything but the player directly, so redirecting enemy
fire toward a companion would be new AI-targeting infrastructure, not a
one-line addition. Its own stat half — one hawk, 250 % ATK, 20 s — is
real.

## Verified end to end

Five new tests: Falconry summons exactly four temporary hawks at the
passive's own base numbers, alongside the permanent one; those four
expire at 12 s while the permanent hawk survives; Skydarken summons
eight instead of four; Great Hawk summons exactly one hawk at 250 %
for 20 s, replacing the ordinary flock entirely; and Sharper Talons plus
Bonded both carry over onto the summoned flock. All five passed on the
first real attempt.

## Consequences

Zea's entire eight-entry kit is now implemented — the sixth hero (after
Sable, Kade, Corvin, Lira, Halden) with nothing left in
`pendingHeroBehaviourWork`. Mirelle's own Hall of Mirrors, Endless Hall
and Twin Warden remain the one other companion-shaped gap: a mirror
clone "fighting alongside... at 60 % stats" needs the identical temporary-
companion dispatch this ADR just proved, the natural next part.
