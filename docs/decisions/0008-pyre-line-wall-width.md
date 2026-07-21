# ADR 0008 — Kade's Pyre Line names no width for its "wall"

**Phase** 10
**Date** 2026-07-21
**Status** Resolved. Reuses `SimConfig.windlineHitWidth` as the wall's hit
tolerance.
**Severity** Low. Changes how forgiving the Ultimate is to stand in, not
whether it exists or what it does once triggered.

---

## What was found

docs/07-heroes.md §7.1's line for Kade's Ultimate, Pyre Line:

> "A burning wall along the aim vector for 8 s; enemies crossing take
> Burn ×3."

The wall's own length and its cross-section (how far off the centre line an
enemy can stand and still be "crossing" it) are both unstated. Length is a
smaller gap — Vane's Piercing Horizon already establishes "far enough to
reach across the arena" as the working answer for a line effect fired along
the aim vector, and Pyre Line reuses that same number. Width has no anchor
at all in docs/07 or docs/08.

## Decision

**Reuse `SimConfig.windlineHitWidth` (0.14 u)** — the tolerance every
Windline segment already uses for "is this entity standing on the line" —
rather than inventing a new "wall width" constant. Pyre Line is described as
a wall, which reads wider than an arrow's own trail, but:

- It is the only "how close counts as touching this line" number already
  shipped for a line-shaped hazard. A hero-specific wall width would be a
  free invention with no balance data behind it either way; reusing the
  existing tolerance keeps every line-shaped thing in the sim consistent
  rather than picking a second, unrelated number for one Ultimate.
- The wall is stationary for its whole 8 s (14 s with Long Pyre) window, not
  a single frame-thin projectile sweep — a slow-moving or repositioning
  enemy has the entire duration to walk into the line, which offsets a
  narrow cross-section in practice.

## Consequences

- If playtesting shows Pyre Line reads as "impossible to actually stand
  in", docs/07 needs its own explicit width and this file is the record of
  what shipped in its absence — search for `_kadePyreLineHalfWidth` in
  `lib/game/sim/world.dart`.
- Twin Pyre (T5b) crosses two such walls at the player's own position; each
  wall keeps this same width independently.
