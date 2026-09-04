# ADR 0053 — The Hollow Warden's own P3: Discord was already possible the moment P2 shipped

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. The Hollow Warden now has P1+P2+P3, complete end to
end.
**Severity** High. The mechanic flagged from this boss's own P1 landing
as needing "an idea nothing in the sim has any analogue for" — a hazard
whose source is a crossing between two independently-owned trail sets —
turned out to need no new storage at all, only a new query over data that
already existed.

---

## What was missing

docs/06 §4, The Hollow Warden: P1 (ADR 0031) and P2 (ADR 0043) are both
already built. P3 — "Both Windline sets are live. Crossing *your* line
through *its* line creates a Discord — a neutral detonation that damages
whoever is closer. The most mechanically interesting fight in the first
half of the game, and the one that most rewards actually understanding
Confluence."

## Decision — "both sets are live" was already true

P2's own ADR (0043) already discovered that `WindlineStore` was never
architecturally player-only — only every *consumer* of it was, until this
boss started laying its own lines under its own owner index. "Both
Windline sets are live" is not a new state to build; it is a description
of what P2 already shipped. What P3 actually adds is one new *query* over
that already-coexisting data: does a segment from one owner ever
geometrically cross a segment from the other?

`_tickDiscord` answers this incrementally rather than rescanning
everything every tick: `comboStep`/`bossActiveChildIndex` (both free —
nothing else in this system touches either) hold each side's own
last-seen `WindlineStore` serial, the identical "read the store's own
serial ordering" trick this boss's own P2 Confluence sweep already uses.
Each tick, any segment newer than its own side's checkpoint is tested
against every live segment owned by the *other* side; two passes (new
player segments against every Warden segment, then new Warden segments
against only the *older* player segments) together cover every possible
pair exactly once, whichever side laid the later of the two — so a pair
that stays alive and overlapping for its whole lifetime never
re-triggers, without needing a separate "already discorded" set.

**The intersection math already existed too, almost.**
`ConfluenceSystem.segmentsIntersect` already does this exact parametric
test — but only ever returns whether two segments cross, never *where*.
A new `_segmentCrossing`, reimplementing the same shape rather than
extending that method's own signature, returns the actual point. It
deliberately drops two of that method's own rules: the near-miss
tolerance and the parallel-rejection angle test. Both exist there to stop
a rapid-fire player's own consecutive arrows from Confluencing with
themselves at the bow — a degenerate case specific to one entity firing
many nearly-identical lines from one origin, which has no analogue for
two independently-drawn trail sets belonging to different bodies.

## "Whoever is closer" can mean the boss itself

This is the one genuinely new capability: nothing in the game has ever
needed an enemy to damage *itself*. `_resolveDiscord` compares the
crossing point's own distance to the player against its distance to the
Warden's own body and applies the roster's own derived heavy hit (a
sixth reuse of `0.09 × 2.10`) to whichever is closer — the player through
the ordinary `EnemyAttack.damagePlayer`, the Warden through a direct
`store.health` subtraction sized against its own max health. No plate,
Momentum, or Boon mitigation applies to the self-damage path, correctly:
none of those systems have ever had anything to say about an enemy
taking damage from anything but a player's own arrow, and a neutral
detonation is exactly that — neither side's own attack.

## Verified in both directions, and against re-triggering

Four tests: P1/P2 confirmed still running unmodified in P3 (the Draw
still ramps); a controlled crossing with the player parked on the
intersection point and the Warden left far away, landing the exact
derived-heavy-hit damage on the player; the identical setup with the
positions swapped, landing the identical damage on the Warden's own
health instead, with the player untouched; and the same live pair held
alive across sixty ticks, confirming the damage lands exactly once, not
once per tick. All four passed on the first real run.

## Consequences

Ten of twelve campaign bosses now have a real P1+P2+P3 (every campaign
boss except The Quiverfall itself). This is the second time this session
a P3 flagged from the very start as needing "an idea nothing in the sim
has an analogue for" turned out to be buildable without new storage
(Rimefather's own decoy mirrors, ADR 0050, was the first) — worth
checking, before assuming a genuinely novel-sounding mechanic needs a
wide, risky new primitive, whether the data it needs is already sitting
in an existing store under a filter nobody has queried yet. Only The
Quiverfall's own P3 remains — "the only fight that requires Confluence,"
now the very last piece of the entire twelve-boss campaign roster.
