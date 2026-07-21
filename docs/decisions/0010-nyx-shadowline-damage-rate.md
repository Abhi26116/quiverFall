# ADR 0010 — Nyx's Shadowline names no damage rate

**Phase** 10
**Date** 2026-07-21
**Status** Resolved. Reuses Iris's Cutting Lines rate — 2 % max HP/s.
**Severity** Low. A T3 talent, reachable only during Umbral Step's own
untargetable window.

---

## What was found

docs/07-heroes.md §7.3's line for Nyx's T3a talent, Shadowline:

> "Windlines laid while untargetable deal damage."

That a Windline should deal damage at all is stated; how much is not. Every
other card that grants a Windline a damage tick states its own number —
Iris's own Cutting Lines (T3a, "Windlines damage enemies 2 %/s") and the
pre-existing Boon of the same name (#66) both do — but Shadowline's own
line stops at "deal damage."

## Decision

**Reuse the 2 % max HP/s rate Iris's Cutting Lines and Boon #66 both
already ship**, rather than inventing an unrelated number. Reasons:

- It is the only "a Windline damages whatever stands on it" rate already
  authored anywhere in the game, for the exact same mechanic (a Windline
  segment ticking damage per second) rather than a loosely-related one.
- Nothing in docs/07 or docs/08 suggests Shadowline's tagged segments
  should hit harder or softer than an ordinary damaging Windline — the
  card's own hook is *which* segments qualify (only ones laid while
  untargetable), not a different rate for the ones that do.

## Consequences

- If playtesting shows Shadowline's window is too narrow (Nyx is
  untargetable for only 1.5–2.5 s, so only a few segments ever qualify) for
  2 %/s to matter, docs/07 needs its own explicit number and this file is
  the record of what shipped in its absence — search for
  `_nyxShadowlineDamageFraction` in `lib/game/sim/windline_store.dart` and
  `lib/game/sim/systems/boon_system.dart`.
- Tagged segments still expire on the same `windlineDuration` timer as any
  other segment; Shadowline changes which segments damage, not how long
  they live.
