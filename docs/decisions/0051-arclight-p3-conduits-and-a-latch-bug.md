# ADR 0051 — Arclight's own P3: four conduits, and a respawn bug caught by its own death test

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for the untargetable orbit and the four conduits. The
"Confluence chains between conduits, ~2x lattice speed" bonus is not
built — a known, deliberately low-risk gap since the card itself frames
it as optional.
**Severity** Medium-high. A real, demonstrated infinite-respawn bug
caught by the death test this ADR's own discipline requires writing,
not by inspection — and a reusable lesson about which "idempotent spawn"
shape is safe for which kind of child.

---

## What was missing

docs/06 §7, Arclight: P1 (ADR 0027) and P2 (ADR 0039) are both already
built. P3 — "Becomes untargetable and orbits as pure light; four grounded
conduits must be destroyed. Confluence chains between conduits, making a
Windline lattice roughly twice as fast — the first fight where the depth
mechanic is dramatically better without being required."

## Decision — conduits replace the primary as the real target

Spawning, chains, and the grid all stop the instant `bossPhase` reaches
2 — P3 replaces the offence entirely, the same posture every other
undone phase in this roster already takes. `_tickP3` places four
ordinary, independently-healthed, **fully targetable** conduits around
the primary's own position (a quarter of its own max health each) and
makes the primary itself genuinely unkillable: `untargetable` alone only
gates auto-aim target *selection* (`AimAssist`'s own doc comment
confirms a manually-aimed shot still lands on an untargetable body), so
the primary is also given the identical full-circle, tiny-positive-flat-
factor plate every other conditional-invulnerability boss in this roster
already uses — the third reuse of that exact trick (Weeping Gate ADR
0042, the Green Mother ADR 0047). When the last conduit falls, the
primary's own health is zeroed directly so the ordinary death/reap pass
finishes it off, keeping the boss room's own zero-enemies clear
condition (ADR 0021) working without a second, boss-specific clear path.

## A real bug, caught by the death test this pattern requires

Every other placed-once child built this session (Silversong's pillars,
The Quiverfall's spokes, the Weeping Gate's P3 portals, Rimefather's
mirrors) guards its own one-time spawn by scanning for an existing
*alive* child with a matching `bossParent`. That shape is safe for a
child that is never actually meant to reach zero health (an untargetable
accounting anchor no live code path ever damages) — but conduits are
explicitly meant to be fought down to zero, and the moment all four are
dead, that same scan finds **no alive child at all** and reads as "none
have ever been placed" — silently respawning a fresh batch of four,
forever, the instant the last one died. The "killing every conduit kills
the primary" test (written per this session's own now-standard practice
of testing the primary's own death whenever a new killable child type is
introduced) failed against the first draft exactly this way, even with a
generous ten-tick margin. Fixed by switching `_spawnConduits` to a
genuine one-time latch (`bossActiveChildIndex`, free — P1/P2 never touch
it) checked once, rather than inferred from current alive state.

**This is worth remembering for any future placed child meant to die.**
The "scan for an alive child" idiom this roster has used seven times now
is only safe when the child is expected to *never* actually be reduced
to zero by anything in the game; the moment a placed child is a real,
intended kill target, it needs a true one-time latch instead.

## What's deliberately not built: the Confluence/lattice bonus

"Confluence chains between conduits, making a Windline lattice roughly
twice as fast" is framed by the card itself as a bonus, not a
requirement — "dramatically better *without being required*" — so
leaving it out does not affect whether the phase is winnable, unlike
every other deferred piece flagged this session (Weeping Gate's own 40s
timer, Vermillion's Frost-extinguish, Hollow Warden's Discord). What
"twice as fast" would even mean operationally — a Confluence stack bonus
for threading between two conduits? a literal lattice-formation-rate
concept nothing in the sim tracks today? — is real, separate design work
this pass does not attempt.

## Verified end to end

Four tests: the primary confirmed both `untargetable` and genuinely
plated (structural checks on `plateHalfArc`/`plateFlatFactor`, the same
shape Weeping Gate's/the Green Mother's own conditional-plate tests
already use, rather than firing real arrows and hoping for the best);
four conduits confirmed placed with independent health and distinct
ordinals; killing all four confirmed to kill the primary — the test that
caught the respawn bug above; and killing three of four confirmed to
leave the primary alive, ruling out an off-by-one in the survivor count.

## Consequences

Eight of twelve campaign bosses now have a real P1+P2+P3 (Cinder Choir,
Silversong, Thrall of the Nine, the Green Mother, the Weeping Gate,
Gaunt, Rimefather, Arclight). Four remain with an open P3: Vermillion
(sequenced trail detonation, Frost-extinguish — needs `HazardStore` to
carry an element), Hollow Warden (Discord — a hazard whose source is a
crossing between two independently-owned trail sets, still the one idea
this roster has no analogue for), and The Quiverfall (Confluence-gated
invulnerability driven by live Windline-lattice geometry — "the only
fight that requires Confluence," now with every other boss's own P3
built as reference for what a genuinely novel mechanic in this roster
looks like).
