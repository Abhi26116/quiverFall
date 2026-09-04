# ADR 0024 — Silversong: a boss that never touches HP

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 (resonance pillars) and P3 (permanent
Draw-lock) are not built — a known, flagged gap.
**Severity** Low. Every real primitive this boss needs already existed; the
only judgment call is one unstated cooldown number.

---

## What was missing

docs/06 §3, Silversong (chapter 3): "A resonant bell-figure that hunts the
player's mechanic rather than their HP... Cone screams inflict Draw-lock
2.5s. Tier III is unavailable roughly half the time." Nothing about this
needed a new sim primitive — the entire mechanic already exists, and
already runs on a boss-shaped enemy in miniature.

## Decision — reuse the Screecher's own shape outright

`DrawState.applyDrawLock` and the "cone telegraph → `EnemyAttack
.playerInCone` → resolve" cycle are not new: the Screecher (docs/05 §5.4,
chapter 6) already screams a cone that inflicts Draw-lock, and
`DrawState.drawLockRemaining`'s own doc comment already names both the
Screecher and Silversong as its two intended consumers — this ADR is that
prediction being fulfilled, not a new primitive being invented. Reused
directly from the Screecher's own numbers rather than invented fresh:
30° cone half-angle, 5 u range, 0.6 s wind-up. `SilversongSystem` is a
single-body version of the exact windUp→resolve→cooldown cycle Cinder
Choir's own P3 cones already established (ADR 0020), just with one
attacker instead of taking turns among several.

**One real difference from the Screecher: no damage at all.** The
Screecher's own scream deals 6% HP alongside its lock; docs/06 §3 states
only the lock, and frames the whole fight around *not* being about HP
("hunts the player's mechanic rather than their HP"). Silversong's own
scream is implemented as a pure utility attack — the first boss mechanic in
the game with zero HP cost, which is exactly the point: a player standing
still at max Momentum with a badly-timed Draw feels this boss's threat
without ever watching a health bar move.

## Decision — the one number that isn't reused: cooldown

Neither docs/06 nor the Screecher's own numbers state a scream cadence for
Silversong. **The cooldown between screams is set equal to the lock's own
duration (2.5 s)**, anchored directly to the card's own "roughly half the
time" line rather than an unrelated existing number: a scream that resolves,
then waits 2.5 s before its next wind-up begins, produces a full attack
cycle of roughly `0.6 + 2.5 = 3.1` s, of which the player is locked for 2.5
— genuinely close to half once the 0.6 s wind-up (during which Tier III is
still reachable if the player was already mid-charge) is counted against
the "free" side. This is an authored choice, not a derived one, and the
first real number to revisit once this fight is actually played.

## What's deliberately not built here

**P2's standing resonance pillars and P3's permanent Draw-lock.** Both are
real, separate mechanics — pillars need their own persistent hazard
geometry, and "permanent" lock is a genuinely different state
(`applyDrawLock(double.infinity)` would technically work, but *removing* it
again at the right moment is a P3-specific question this pass did not
need to answer). Once `bossPhase` reaches 1, `SilversongSystem` stops
screaming and clears any live telegraph rather than leaving one frozen on
screen — the same posture every other boss's own undone phases already
take.

**`BossRoomComposer` now maps chapter 3 to `silversong`** alongside
chapters 1, 2 and 11 — the fourth boss to confirm ADR 0021's own predicted
two-line integration cost.

## Consequences

Four bosses now exist. Silversong is the first proof that a boss's own
mechanic can be built almost entirely from an *existing enemy's* own
primitive rather than a new one — the Screecher was carrying this whole
design already, just at common-enemy scale. The next boss whose card
echoes an existing enemy family (Rimefather/Frost, Arclight/Storm,
Vermillion/Ember) should be checked against its own family's existing
mechanics the same way, before assuming a new primitive is needed.
