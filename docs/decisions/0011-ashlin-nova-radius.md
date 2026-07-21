# ADR 0011 — Ashlin's Nova names no radius

**Phase** 10
**Date** 2026-07-21
**Status** Resolved. Reuses Sela's Glacier Nail radius — 3.5 u.
**Severity** Medium. Changes how many enemies a revive or an Ultimate cast
actually reaches.

---

## What was found

docs/07-heroes.md §7.3's lines for Ashlin:

> Rekindle: "Once per run, on lethal damage, revive at 45 % HP with a
> 350 % AoE nova and 3 s of invulnerability."
>
> Rebirth Nova (Ultimate): "500 % AoE, heals 25 %, and refreshes Rekindle
> if already used."
>
> Supernova (T5b): "Nova 1,200 %, no refresh."

Every one of these names a damage percentage. None of them names how far
the nova reaches. Three separate cards share the same unstated number —
the passive's own revive-nova, the Ultimate's base cast, and Supernova's
replacement — which is itself a hint that they are meant to share one
answer rather than each needing an independent guess.

## Decision

**Reuse Sela's Glacier Nail radius — 3.5 u** — the closest existing
"instant burst centred on a point" AoE already shipped, rather than
inventing a new one. Reasons:

- It is an *instant* burst, the same shape as a nova, unlike Sable's Miasma
  (5 u) which is a *lingering zone* — the wrong analogue for something that
  resolves in a single tick.
- Bram's splash (1.6 u) is sized for an *always-on* passive that procs on
  nearly every hit; a once-per-run revive or a full Ultimate cast reads as
  a much bigger moment than a splash arrow, so anchoring to a dedicated
  burst-shaped Ultimate (Glacier Nail) fits the moment better than Bram's
  number would.
- Reusing one number for all three Ashlin cards that need it keeps her own
  kit internally consistent, which matters more here than getting the
  absolute size exactly right on the first guess.

## Consequences

- If playtesting shows Ashlin's nova reads as too small or too large for a
  revive/Ultimate moment specifically (as opposed to a targeted freeze),
  docs/07 needs its own explicit number and this file is the record of
  what shipped in its absence — search for `_ashlinNovaRadius` in
  `lib/game/sim/world.dart`.
- Rekindle's own nova, Rebirth Nova's base cast, and Supernova's bigger
  cast all use the same radius; only their damage percentage differs.
