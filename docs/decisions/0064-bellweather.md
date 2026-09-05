# ADR 0064 — Bellweather: four rule-inversions, no invented attack

**Phase** 11
**Date** 2026-09-05
**Status** Resolved. Bellweather (docs/06 §6.2, Event boss #15) is fully
built — the fourteenth boss in the roster, and the first Event-tier boss
built since Ashen Choir.
**Severity** Medium-High. The only boss so far whose own mechanic requires
touching `SimWorld`'s own shared, per-tick player-input/Draw code
directly, not just observing it.

---

## What was missing

docs/06 §6.2, Bellweather, *Tollings*: **"Every 10s a bell tolls and
inverts one rule for the next 10s (movement reversed / Draw inverted so
moving charges it / Windlines damage the player / healing damages)."**
The card names no attack of its own.

## Decision — no invented attack; the toll is the whole fight

Unlike The Ashen Choir (#13, explicitly "Elite remix of #1", reusing
Cinder Choir's own attack), Bellweather's card gives no attack shape at
all. Rather than invent one, this follows the same posture Silversong's
own explicit "not about HP" and the Weeping Gate's own explicit "never
directly attacks" already established for a card that says nothing about
dealing HP damage directly: the four rule-inversions ARE the fight's
entire mechanical identity. `BellweatherSystem` picks one of the four at
random every 10s (`ctx.rng` — docs/06 states no selection order, and a
fixed round-robin would let a player memorise and pre-empt a fight named
for surprise) and holds it until the next toll replaces it — `comboStep`
(free) encodes which of five states is live, `bossTimer` (free) counts
down, both continuous across every phase, the same "no phase-gated
content, one flat mechanic" posture Ashen Choir already established.

## Two rules needed new, shared, player-facing surface — not a bypass

"Movement reversed" and "Draw inverted so moving charges it" are the
first mechanics in this whole roster that cannot be built by a boss
system alone, since the code they need to change (`SimWorld._applyInput`,
and the player's own `DrawSystem.update` call site) runs earlier in the
tick, outside the boss-systems block entirely. Rather than adding an
archetype-specific branch to either shared function — a change every
other boss in this roster has deliberately avoided — this adds two new
`DrawState` fields (`movementReversed`, `drawChargesWhileMoving`), read
generically at the exact point each already lives: `_applyInput` negates
the resulting velocity/facing when the first is set;the Draw-update call
site inverts `isMoving` before passing it to `DrawSystem.update` when the
second is set. This is the identical shape `DrawState.rootRemaining`
(Rimefather's root, ADR 0026) and `DrawState.windlineSlowFactor` (Hollow
Warden's own slow, ADR 0043) already established: a boss sets a flag on
the player's own live state; the one place that state already changes
things reads it. `wantsToMove` itself, read by several *other* systems
this same tick (Kiting's own distance odometer, First Blood's window),
is deliberately left unflipped — the card names the Draw specifically,
not movement-derived state generally.

## The other two rules needed no shared-code change at all

"Windlines damage the player" reuses the exact "standing on a live
player-owned Windline" check the Hollow Warden's own P2 and The Last
Warden's own P4 already built (`_pointNearSegment`, independently
reimplemented per this roster's own established "small copies, not a
shared utility" posture, ADR 0057) — inverted to punish rather than
protect, on The Loom's own established damage/cooldown magnitude (9%,
0.6s). "Healing damages" needed no audit of the several scattered
player-heal call sites (Bloom regen inline in `SimWorld.tick`, lifesteal
inside `ProjectileSystem`, Lira's own Overheal) at all — it reuses the
roster's own "observe and correct after the fact" shape (Rimefather's
decoy mirrors, ADR 0050) instead: a tick-to-tick health baseline (free —
`bossLastHitAgo`, refreshed every tick regardless of which rule is live
so it is never more than one tick stale the moment this rule actually
becomes active) is diffed, and any net *gain* is inverted into an equal-
sized loss while the rule is live — covering every present and future
heal source with zero per-source wiring.

## Verified end to end

Fifteen tests: no rule active before the first toll; the first toll at
10s picks one of the four and sets exactly the matching `DrawState`
flags; a later toll correctly replaces and clears them; the cycle
continues unmodified across every phase; movement reversal flips the
resulting velocity (and leaves it alone when off); continuous movement
ramps the Draw instead of resetting it under the inverted rule (and
standing still now builds Momentum instead); standing on a Windline
deals damage on a cooldown only while that rule is live, and is
otherwise always safe; and a heal is inverted only while "healing
damages" is live, a loss is always left alone, and the inversion lands
at the exact magnitude. All fifteen passed on the first real attempt.

## Consequences

Fourteen of the twenty boss archetypes now have a real, built fight. The
two remaining Elite/Event bosses (Umbral Twin, #14; The Pale Judge, #16)
are unbuilt — Umbral Twin's own card is almost entirely a presentation/
lighting concern the pure sim layer has no natural hook for, and is
flagged as the harder of the two remaining. Bellweather has no real-run
spawn path yet, the same gap ADR 0033 already flagged for Ashen Choir
before its own integration (ADR 0055) — `EliteRoomComposer`'s own map is
the entire remaining cost once a placement decision is made.
