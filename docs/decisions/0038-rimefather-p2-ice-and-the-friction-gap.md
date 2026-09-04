# ADR 0038 — Rimefather's own P2: half a mechanic, built honestly

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for the half of P2 the sim can actually express.
"Reduces friction" is explicitly NOT implemented. P3 (three ice-mirrors)
is also not built.
**Severity** Medium-High. A real, deliberate partial build — the first
time this session has shipped half a documented phase rather than either
all of it or none of it, and said so plainly rather than quietly
approximating the missing half.

---

## What was missing

docs/06 §6, Rimefather: P2: "The arena floor freezes outward from the
boss; standing on ice reduces friction and makes precise positioning
hard. Momentum builds are *stronger* on ice." Two sentences, two different
mechanics — only one of which turned out to be buildable without a much
larger, riskier change.

## Decision — "stronger Momentum on ice" is real; "reduces friction" is not, and here is exactly why

Checked `SimWorld._applyInput` before writing anything: the player's own
velocity is set **directly from input** every tick — `entities.velX[i] =
input.stickX * inv * speed`, with an immediate snap to zero the instant
the stick releases. There is no acceleration, no deceleration, no
velocity persisting once input stops — the sim has never had a friction
concept to reduce. Building "ice" as real physics would mean adding
velocity persistence to the one function every movement-adjacent
interaction in the game already depends on (dashing, Windline-laying,
every enemy's own contact-avoidance check implicitly assumes instant
stop) — a materially larger and riskier change than anything else in this
P2/P3 pass, and one docs/06 does not specify precisely enough to build
blind (how much sliding? does it interact with a dash mid-slide? does
Draw ramping care whether the player is "moving" while sliding to a
stop?). Rather than guess at physics the GDD does not fully specify,
this half is flagged and left undone.

**"Momentum builds are stronger on ice" is a different kind of claim —
one the sim can express cleanly.** A new `DrawState.
momentumEffectivenessMultiplier` (default 1.0) scales `moveSpeedBonus`/
`damageReduction`, set fresh every tick by whichever system decides the
player currently qualifies — the same "recomputed live, never
accumulated" posture `EnemyStore.attackBuff` already uses for Chanter
auras, so nothing needs an explicit reset event when the player steps off
the ice. Rimefather sets it to an authored 1.5x while the player stands
inside its own spreading circle (`bossSweepAngle`, repurposed as a plain
scalar radius — P1 never uses it as an angle, so no conflict), 1.0x
otherwise.

## Decision — the ice field grows on a plain timer, capped

"Freezes outward from the boss" is modelled as a circle centred on
Rimefather's own (stationary) position, growing at an authored rate
(reaching an authored 6u cap in 15s — echoing Vermillion's own "~50% safe
floor" framing, ADR 0037, even though this card states no percentage).
Real tuning — growth rate, cap, the 1.5x multiplier itself — is
unverified, flagged the same way every other similarly-authored number
this session already is.

## A test bug caught while writing the freeze test, distinct from the field-name bug

A telegraph's own `telegraphSlot`/`telegraphSerial` handle does **not**
reset to -1 when the telegraph it points at naturally expires — only an
explicit `EnemyAttack.endTelegraph` call does that. `hasTelegraph()`
already accounts for this correctly (checking liveness via `isAlive` +
serial match, not the raw slot number), but a first draft of this boss's
own "past P2" test ran many cast cycles before checking `telegraphSlot ==
-1`, by which point the *last* cycle's own brief "lethal flash" telegraph
(a near-zero-duration `beginCone(..., 0, severity: lethal)`, the same
shape every boss's own resolve step already uses) had already expired
naturally on its own — leaving nothing live to explicitly clear, so the
stale slot number correctly stayed put. Every prior boss's own equivalent
test happened to check this on the very first wind-up, before any resolve
had a chance to leave a stale handle behind, so this was never exercised
until now. Fixed by rewriting the test to catch a genuinely live wind-up
(polling for `AiState.windUp` rather than assuming a fixed tick count) —
**worth remembering for any future "past PX" test that runs the boss for
a long time first**: check clearing against a live wind-up, not an
arbitrary later moment.

## What's deliberately not built here

**"Reduces friction"** — see above; needs a real movement-physics
primitive this pass does not attempt. **P3 ("Shatters into three
ice-mirrors, only one real, revealed by which one casts a shadow — a
purely visual read, no HUD marker; wrong-target damage heals it")** —
already flagged in this boss's own P1 ADR (0026) as needing a decoy body
indistinguishable from the real one by anything the simulation can query,
still true. Once `bossPhase` reaches 2, the cone stops, the ice stops
growing, and the Momentum multiplier resets to 1.0 — the same posture
every other boss's own undone phase already takes.

## Consequences

Four of twelve campaign bosses now have some form of complete-through-P2
fight (Gaunt, Silversong, Vermillion, and now Rimefather, the first with a
*partial* P2 rather than a full one). This is the session's first
explicit "half a phase, said so plainly" landing — worth treating as the
template for any future card whose own two mechanics split cleanly into
"buildable now" and "needs a new engine-level primitive first," rather
than silently skipping the whole phase or half-guessing the harder half.
