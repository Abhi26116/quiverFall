# ADR 0009 — Weave's 5th-stack AoE names a radius but no share

**Phase** 10
**Date** 2026-07-21
**Status** Resolved. The AoE deals the hit's own already-resolved damage in
full, not a fraction of it.
**Severity** Low. Only reachable at Iris's own 5-stack Confluence ceiling —
the rarest, hardest-to-earn state in the build.

---

## What was found

docs/07-heroes.md §7.3's line for Iris's passive, Weave:

> "Windlines last 2.6 s (vs 1.2 s base), and Confluence stacks cap at 5
> instead of 3 (4th: +230 %, 5th: +320 % and 2 u AoE)."

The 4th/5th-stack damage bonuses and the AoE's radius are both stated. What
the AoE itself deals is not — every other splash/AoE effect already shipped
this phase (Bram's Heavy Ordnance, Rook's grouping bonus) states its own
percentage explicitly; this is the first one that names a radius and
nothing else.

## Decision

**The AoE deals the triggering hit's own fully-resolved damage
(`toHealth`) in full**, applied via the same linear-scan splash helper
Bram's Heavy Ordnance already uses (`_applyBramSplash`, radius 2 u), rather
than inventing an arbitrary percentage. Reasons:

- Every existing splash in the codebase (Bram's 45 %/65 %) is an
  *always-on* passive that fires on nearly every hit; discounting it below
  100 % is what keeps a constant proc balanced. A 5th Confluence stack is
  the opposite: it requires Iris specifically, a raised stack cap, and
  threading five distinct Windlines with one arrow before landing — the
  rarest state reachable in the game. A full-strength payoff fits how hard
  it is to earn, and a partial one would read as double-dipping the
  gate docs/07 already put on this specific stack.
- No design document or existing implementation suggests a specific
  fraction; this is a free choice absent a data-driven anchor.

## Consequences

- If playtesting shows the 5-stack AoE is over- or under-tuned, docs/07
  needs its own explicit share and this file is the record of what shipped
  in its absence — search for `irisWeave` in
  `lib/game/sim/systems/projectile_system.dart`.
- The AoE never applies elements or triggers a second Confluence check,
  the same restriction Bram's splash already carries — it is a flat damage
  hit, not a second arrow.
