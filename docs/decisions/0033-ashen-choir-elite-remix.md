# ADR 0033 — The Ashen Choir: a remix, and a genuinely different integration gap

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for the fight mechanic itself. Real-run spawn
integration is explicitly NOT built — a different, larger kind of gap than
any campaign boss left behind.
**Severity** Medium. One genuinely new primitive (Windline-contact reveal,
reusing an existing private pattern), otherwise entirely subtractive/
additive against Cinder Choir. The open integration question is the more
consequential part of this ADR.

---

## What was missing

docs/06 §6.2, boss #13, The Ashen Choir: "Elite remix of #1. ×48 HP · 70s.
All three effigies lit permanently; tethers are lethal from the start; a
fourth invisible effigy exists, revealed only by Windline contact." The
first Elite/Event-tier boss (#13-16) attempted — a different category from
the twelve campaign bosses (docs/06 §6.1) this session just finished, with
no chapter number, no P1/P2/P3 breakdown, and (as it turned out) no
existing spawn path built for it at all.

## Decision — subtract the rotation, subtract the warning, add one reveal

"All three effigies lit permanently" removes Cinder Choir's own rotation
timer entirely — every plate stays at its `reset()`-default zero forever,
so `AshenChoirSystem` contains no rotation logic at all, a strict subset of
`CinderChoirSystem`'s own P1. "Tethers are lethal from the start" removes
the original P2's own 0.6s amber warning — every telegraph here begins
`TelegraphSeverity.lethal`, and the rest of `_tickTetherSweep` is Cinder
Choir's own P2 sweep verbatim (ADR 0019), reusing every number unmodified.

**The fourth invisible effigy is the one real new mechanic.** It spawns
near-zero radius, `untargetable`, and deliberately *not* health-linked
(`linkedHealthSlot` stays -1) — so before it is found, even a freak
accidental hit does nothing at all, no redirect, no consequence, which is
the honest way to make "invisible" actually mean invisible rather than
merely excluded from auto-aim (`untargetable` alone only gates target
*selection*, confirmed by checking every call site — it does not block
`ProjectileSystem`'s own collision resolution). Reveal is checked against
a live player Windline the same way `AiSystem._applyWindlineSlow` already
checks Bounder-slowing contact — `AiContext.lineIndex.querySegment` for a
broad-phase candidate list, then a precise point-to-segment distance test
— reimplemented here since that method is private, the same "the shape,
not the private function" posture Hollow Warden's own borrowed mirror-
movement already established (ADR 0031).

## Decision — no phase-gated content, on purpose

Every campaign boss's own undone phase gets frozen once `bossPhase >= 1`.
This fight has no undone phase to freeze *into* — docs/06 §6.2 describes
one flat, permanent state for the whole encounter, not an escalating
P1/P2/P3. `bossPhase` still advances (`BossPhaseSystem` runs generically
for every boss, for the visual/musical transition cue docs/06 §6.0
promises independent of what a phase *means*), but `AshenChoirSystem`
never reads it — the tether sweep and the reveal check both run
continuously for the entire fight, verified directly by a test that sets
`bossPhase` to 2 and confirms the sweep keeps going regardless.

## The real gap: this boss has nowhere to spawn in an actual run

Every campaign boss had an unambiguous trigger: chapter N's own stage 20.
The Ashen Choir has none. Reading `RoomComposer.compose(isElite: true)`
(the *existing* Elite-room path, built for Phase 8, used by every ordinary
Riftborn elite) makes the mismatch concrete: it is a pure, allocation-free
function that returns a `RoomPlan` — data, generated ahead of time,
validated, and replayed — built around `PlannedEnemy(contentIndex, ...)`,
one ordinary content-catalogue entry per enemy. It has no notion of "one
pick spawns four entities sharing a health pool," which is the entire
premise of every boss system this session has built. Wiring The Ashen
Choir into a real run needs either a live spawn hook parallel to
`BossRoomComposer` (triggered from *somewhere* — which chapter, which
frequency, replacing an ordinary Elite pick how often?) or a deeper change
to how Elite rooms themselves get composed — and docs/06 §6.2 states no
trigger condition at all to build either against. Left explicitly
unresolved rather than guessed at; `SimWorld.spawnAshenChoir` exists as
the same test/tool entry point every other boss's own convenience method
already is, fully tested, simply not yet reachable from a real run.

## Consequences

The fight mechanic itself is done, tested, and cheap — genuinely the
smallest boss build this session, reusing almost all of Cinder Choir's own
code. The *integration* question it raises is real and larger than
anything the twelve campaign bosses needed: docs/06's own Elite/Event tier
(#13-16) and the reachability of any of them depends on a design decision
this pass does not make. Whoever picks up boss #14 (Umbral Twin), #15
(Bellweather), or #16 (The Pale Judge) next should expect to hit the same
open question before writing any fight code at all.
