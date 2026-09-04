# ADR 0037 — Vermillion's own P2: the fourth heavy hit, and a mover

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2. P3 (sequenced trail detonation; Frost
extinguishing) is not built — a known, flagged gap.
**Severity** Medium. Two composed mechanics (a discretised continuous
aura, a telegraphed movement attack) built entirely from existing
primitives, plus a real timing interaction between them worth recording
for whoever tests something similar next.

---

## What was missing

docs/06 §5, Vermillion, the Long Burn: P2: "Ignites in a 3u aura and
charges along amber lines. Safe floor is now ~50%." Vermillion's own P1
(ADR 0025) landed mid-session, well before the "P2/P3 backlog" pass this
ADR is part of.

## Decision — the aura is the trail's own damage rate, discretised

"Ignites in a 3u aura" is a continuous field, but applying `damagePlayer`
every raw simulation frame would fire Boon/on-hit triggers 60 times a
second for no reason. Reused the roster's own established 0.6s tick
magnitude instead — the aura evaluates `playerInCircle` once per tick
cycle, dealing the trail's own `burnPerSecond` rate scaled to that
interval (`0.04 * 0.6 = 2.4%`) rather than a fresh number. The radius
(3u) is GDD-stated, the second boss after Gaunt (ADR 0035) to get one
directly from the card rather than authoring it.

## Decision — the charge is this boss's first real movement attack

Every prior boss attack is stationary — the body stays put and a hazard
resolves around it. "Charges along amber lines" is the first campaign
mechanic where the *attacker* travels: a telegraphed line wind-up (reusing
the Weeping Gate's own "read the committed destination back out of the
telegraph" trick, `TelegraphStore.toXAt`/`toYAt`, ADR 0030 — necessary
here too, since the player could move during the 0.6s wind-up and the
charge's own aim must not follow them), then Vermillion's own position
snaps to the line's far end at resolve. P1's own walk halts for exactly
the wind-up's own duration, so the line drawn on screen and the line
Vermillion actually travels never disagree.

**The damage is the fourth boss to agree on "heavy hit."** Hollow Warden's
shot, Skarn's slam, and Gaunt's shockwave all use the Thresher's own 9%
scaled by Tier III's own 2.10x multiplier; the charge reuses the same
number a fourth time. This is no longer a coincidence worth re-justifying
per boss — it is this roster's standing answer to "how much does a
decisive hit cost," and any future boss whose card calls for one should
reach for it by default.

## A real timing interaction, worth remembering for the next mover

Because the charge always travels toward wherever the player was aimed at
wind-up start, and always covers a fixed 6u, **a player who starts within
the charge's own reach necessarily ends up within the *aura's* own 3u
reach of Vermillion's new position once the charge lands** — the
overshoot math is unavoidable for any starting distance between 3u and 6u.
Writing an isolated "the charge alone deals X" test surfaced this
directly: a naive test window that ran a few ticks past the resolve picked
up a second, aura-sourced hit the test wasn't accounting for. Fixed by
computing the exact tick the wind-up resolves (37, from a 0.6s timer) and
stopping the test window there, with the arithmetic spelled out in a
comment rather than asserted from feel. **Any boss whose own P2/P3 mixes a
persistent aura with a mover that can land inside that aura's own range
needs the identical care** — the two mechanics are not independent just
because they were built independently.

## What's deliberately not built here

**P3 ("Detonates the entire accumulated trail in sequence over 6s...
Frost arrows extinguish trail segments").** Sequencing needs to *track*
which hazard slots belong to this boss's own trail specifically (nothing
does that today), and extinguishing needs a hazard to carry its own
element (`HazardStore` has none) — both real, separate pieces of work
flagged back in ADR 0025 and still open. Once `bossPhase` reaches 2, all
of P1 and P2 freeze together: movement halts, trail stops, the aura stops,
and any live charge telegraph is cleared.

## Consequences

Three of twelve campaign bosses now have complete P1+P2 fights (Gaunt,
Silversong, Vermillion), plus Skarn's already-complete P1-through-P3. The
"a mover can re-enter its own aura" timing lesson here is the kind of
interaction worth checking explicitly — not just assuming independence —
the next time two of a boss's own mechanics run in the same tick loop.
