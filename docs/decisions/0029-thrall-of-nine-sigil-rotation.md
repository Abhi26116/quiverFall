# ADR 0029 — Thrall of the Nine: nine sigils, three reused shapes, one rotation

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 ("two abilities simultaneously") and P3
("absorbs all remaining sigils for +25% damage each") are not built — a
known, flagged gap.
**Severity** Medium-High. A real, previously undocumented GDD gap resolved
(what the nine abilities actually are), a new multi-body shape (independent
side-resource sigils, not a shared pool), and an authored balance number
with no way to verify it against the card's own stated target this pass.

---

## What was missing

docs/06 §9, Thrall of the Nine (chapter 9): "Tests: target priority under
pressure." P1: "Nine floating sigils orbit; each grants the Thrall one
ability. Destroying a sigil removes that ability permanently. The player
chooses which of the nine threats to delete — and there is time to remove
only about four." **docs/06 never says what the nine abilities actually
are** — a real gap, unlike every prior boss's own card, which at minimum
named a shape ("cone", "line", "tether"). Building this fight required
deciding that first.

## Decision — three of the roster's own shapes, three sigils each

Rather than invent nine distinct mechanics, the nine sigils are assigned
one of three already-established attack shapes round-robin by their own
fixed index (`sigilIndex % 3`): cone (Silversong/Rimefather's own numbers,
ADR 0024/0026), line (Cinder Choir's own tether anchor, ADR 0019), circle
(a new authored radius — no existing "burst AoE from an enemy's own body"
anchor existed to reuse a number from). **Every shape deals the same
damage** — the Thresher-derived 9% anchor, reused a fifth time — the same
"one damage anchor, several shapes" choice Cinder Choir's own P2/P3 already
made (ADR 0019/0020), so the nine abilities differ only in footprint and
range, not in threat weight. This keeps "which four do I delete" a spatial
and tactical question (which shapes can I live with) rather than a hidden
numbers question.

**The attack fires from the Thrall's own body, not the orbiting sigil.**
"Each grants the Thrall one ability" reads as the sigil being a permission
source, not an independent attacker — so P1 needed only one state machine
(`state`/`stateTimer` on the Thrall's own primary slot), cycling through
whichever *living* sigil's turn is next. That "next alive child" lookup is
`CinderChoirSystem._tickCones`'s own P3 pattern (ADR 0020) verbatim, just
against nine slots instead of three via `bossActiveChildIndex`/
`bossChildIndex`. **"Destroying a sigil removes that ability permanently"
needed no extra code once framed this way** — a dead sigil is simply never
found by the next-alive lookup again, the same free consequence Cinder
Choir's own alternating cones already got.

## Decision — sigils hold independent health, not a shared pool

Every prior multi-body boss either shares one pool (Cinder Choir P1/P2,
Skarn) or, after a one-time split, holds an independent chunk of the
*original* pool (Cinder Choir P3). A sigil is neither: its own death is a
side-resource elimination that must **not** touch the Thrall's own HP bar
at all, so a sigil's `linkedHealthSlot` is deliberately left at its default
(-1, "no redirect") — its own `health`/`maxHealth` are the real, only
truth. This is simpler than every prior multi-body boss, not more complex:
no redirect logic anywhere in the damage pipeline needed to change, since a
sigil is just an ordinary bare entity with real health, structurally
parented to the Thrall (`bossParent`, for orbit tracking and cleanup) but
financially independent of it. Sigil health itself is an authored fraction
of the Thrall's own max health (5% each) — flagged below, not GDD-derived.

## The orbit reuses `bossSweepAngle` for literal motion, not a sweep

`bossSweepAngle` already means "one continuously-incrementing angle,
several evenly-spaced points derived from it" for Cinder Choir's own tether
sweep (ADR 0019). Nine sigils orbiting together at a fixed relative spacing
is the identical shape — one shared angle, nine points at
`2π·sigilIndex/9 + sweepAngle` — reused directly rather than adding a
per-sigil orbital field.

## A real ordering subtlety, not a bug — the same class ADR 0023 already named

Killing a sigil the *exact* tick a new turn is being selected can let that
now-dead sigil's ability fire one more time: `ThrallOfNineSystem.update`
runs before `AiSystem`'s own death pass reaps it that same tick, so the
"next alive" lookup can still see a sigil whose health already reads zero.
This is the identical fixed-system-order staleness ADR 0023/0025 already
documented and accepted for a boss's own halt-on-phase-transition — here
it is one possible extra ability activation, at most once, for a sigil the
player has already permanently removed going forward; the rotation moves
on for real the very next turn. `thrall_of_nine_system_test.dart`'s own
"destroying a sigil" test accounts for this the same way Gaunt's/
Vermillion's own tests already do: the observation window begins *after*
that one stale turn has had a chance to complete, not immediately.

## What's deliberately not built here

**P2 ("remaining sigils accelerate and the Thrall uses two abilities
simultaneously") and P3 ("absorbs all remaining sigils for +25% damage
each" — a player who destroyed five sigils fights a fundamentally
different, easier phase 3).** P2 needs a genuinely new shape: two
concurrent turns rather than one state machine. P3 needs a damage
multiplier keyed to however many sigils survived to that point — real,
scoped work, not attempted here. Once `bossPhase` reaches 1, both the
orbit and the rotation freeze and any live telegraph is cleared — the same
posture every other boss's own undone phases already take.

**The sigil health fraction (5% of the Thrall's own max HP) is an
unverified placeholder.** "Time to remove only about four" is a real,
specific balance target — how long a given power level takes to kill one
sigil, weighed against surviving the Thrall's own rotation meanwhile — that
a single implementation pass has no way to check without the balance
harness (Phase 14). Flagged the same way Green Mother's own spawn cadence
already is (ADR 0028).

**`BossRoomComposer` now maps chapter 9 to `thrallOfNine`** — the ninth
confirmation of ADR 0021's own predicted two-line integration cost.

## Consequences

Nine bosses now exist, in yet another distinct shape: independent
side-resource children or­biting a single real body, cycling a shared
attack through whichever still survive. The "three shapes, reused numbers,
round-robin turn order" recipe here is itself reusable — any future boss
whose card describes several interchangeable "sub-threats" that can be
individually neutralized (rather than a shared health pool) should be
checked against this shape before inventing a new one.
