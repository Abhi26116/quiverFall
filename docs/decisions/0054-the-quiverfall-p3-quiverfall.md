# ADR 0054 — The Quiverfall's own P3: the campaign's own last gap, closed

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. The Quiverfall now has P1+P2+P3, complete end to
end. **This closes the last open P3 across all twelve campaign bosses.**
**Severity** High. The card explicitly named as "the only fight in the
game that requires Confluence" — the campaign's own capstone mechanic,
and the last piece of docs/06 §6.1's own twelve entries still open.

---

## What was missing

docs/06 §12, The Quiverfall: P1 (ADR 0032) and P2 (ADR 0044) are both
already built. P3 — "Quiverfall: The shard shatters into 40 fragments
raining continuously. The boss is invulnerable except when the player's
Windline lattice connects three or more fragments, which channels them
into the core. The only fight in the game that *requires* Confluence,
and it arrives at chapter 12, ~15 hours in, long after the mechanic has
been mastered."

## Decision — fragments are geometry, not entities

Nothing about the forty fragments is ever independently targeted,
damaged, or killed — "channels them into the core" reads as a conduit for
the player's own arrows, not forty destructible bodies. So `_fragmentX`/
`_fragmentY` are pure functions of an ordinal, an authored 8×5 grid spread
across the arena's own bounds, computed on demand rather than forty extra
entities competing with the room's own actual threats for the shared
entity pool — the first "conduit" concept in this roster's own P3 sweep
that deliberately chose *not* to be an entity, after Arclight's own four
conduits (ADR 0051) were.

Every tick, each of the forty positions is queried against `ctx.lineIndex`
— the same rebuilt-every-tick spatial index Confluence and this boss's
own P2 slow already use — for a live *player*-owned Windline passing
within a small radius. The boss counts as connected while three or more
read positive; the conditional plate (a fourth reuse of the Weeping
Gate's/Green Mother's/Arclight's own trick: full-circle `plateHalfArc`, a
tiny positive `plateFlatFactor`) toggles open exactly while that holds and
shut otherwise. This is the whole mechanism behind "the only fight that
requires Confluence": the boss is only ever hittable while the player is
*actively holding* a real three-point lattice, not merely has threaded
one at some point in the past — verified directly, with a test confirming
an *enemy*-owned line near three fragments does not open the plate, only
a player-owned one does.

## "Raining continuously" is a separate, simpler layer

Rather than one more puzzle stacked on the lattice itself, the rain reads
as ongoing background pressure independent of it: a telegraphed circle at
a random fragment position, on a short repeating cooldown, dealing the
Thresher's own persistent-aura anchor (9%) — deliberately *not* this
roster's own "heavy hit," since this card's own difficulty is entirely in
the targeting puzzle, not in surviving a single strike.

## P3 replaces P2's echo cycle — and needs its own one-time cleanup

Unlike P2 (which continues P1's own sweep with no visible seam, ADR
0044), P3 genuinely replaces P2's echo cycling: "the shard shatters" is a
new, third state. This meant `_clearCurrentAttack` — previously called
every tick of the old frozen placeholder — could no longer run
unconditionally once P3's own rain mechanic needed the very same `state`/
`stateTimer`/`attackCooldown` fields for its own wind-up/cooldown cycle;
calling it every tick would have wiped the rain's own progress before it
ever advanced. Caught while writing the code, not by a failing test:
`bossActiveChildIndex` (free — nothing else in this system touches it)
now gates that cleanup to fire exactly once, on the transition itself.

## Verified end to end, including the exact committed rain position

Six tests: the transition cleanup; the plate confirmed shut with zero
connections; confirmed *still* shut at exactly two (the threshold
boundary, not just "some number"); confirmed open at exactly three;
confirmed an enemy-owned line near three fragments does not count; and
the rain's own damage measured deterministically by polling for a live
wind-up, reading its own committed position back out of the telegraph
(the same trick this roster has reused since Weeping Gate's own portals,
ADR 0030), and moving the player there rather than guessing where a
random draw might land. All six passed on the first real run.

## Consequences

**Every one of the twelve campaign bosses now has a complete, real
P1+P2+P3.** This closes the entire P2/P3 backlog the user's own "keep
going, do not stop, continue on the hard ones" directive was aimed at —
the phase's own remaining scope is now the Elite/Event spawn-integration
question (bosses #14-16, Ashen Choir still has nowhere to spawn in a real
run, ADR 0033), the four Endless bosses (#17-19 + The Last Warden's five
phases), bespoke boss arenas/entrance/music, and the handful of
explicitly-flagged sub-mechanics still deferred within already-shipped
phases (Vermillion's own Frost-extinguish, the Weeping Gate's own 40s
timer, Arclight's own Confluence-chain bonus) — each a real, separate,
honestly-scoped gap, none of them blocking any boss from being a
complete, winnable fight today.
