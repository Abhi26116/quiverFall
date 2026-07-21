# ADR 0006 — which "heroATK" and "fireRate" the Ultimate charge formula means

**Phase** 10
**Date** 2026-07-21
**Status** Resolved. Denominator reads as the hero's own base kit, not the composed build.
**Severity** Medium. Changes how fast every hero's Ultimate charges, for every build.

---

## What was found

docs/07-heroes.md §7.0 gives the Ultimate charge formula as:

> `charge% = 100 · damageDealt / (14 · heroATK · fireRate)`

Two of its three symbols are ambiguous against the rest of the codebase's own
vocabulary:

- **`ATK`**, capitalised, is docs/04 §4.1's name for the fully composed master
  formula output — `heroBase(lvl) · arrowMult · (1+spireMight) · (1+researchAtk)
  · (1+ascensionAtk) · (1+Σboonatk)`. `heroATK` here is lower-case and reads
  as a different, narrower quantity, but the doc never defines it separately.
- **`fireRate`** could mean the hero's own stat-block number (docs/07's per-hero
  baseline, e.g. Wren's 2.20) or `world.fireRateMultiplier`'s fully composed
  result after every Boon, Spire and arrow modifier.

Both readings are defensible, and they produce materially different play:
denominator = base kit means an aggressively-built character (Boon damage,
crit, elemental riders) charges the Ultimate *faster*, because the numerator
(actual damage dealt) grows with the build while the denominator stays fixed
at character-select time. Denominator = composed build means charge rate is
closer to build-invariant — always "N seconds of average combat" regardless
of how strong the run has gotten.

## Decision

**The denominator is the hero's own base stat block — ATK and fire rate as
scaled by level and stars (`Curves.heroStat`), before the arrow, before any
Boon, before Spire/Research/Ascension.** `HeroLoadoutResolver.apply` computes
`heroAtk` and `heroFireRate` for exactly this purpose already (they also feed
`baseAttack` and `baseFireRateMultiplier`); `HeroRuntime.chargePerDamage` is
set from those same two numbers, not from `world.playerAttack` or
`world.fireRateMultiplier` after Boons apply.

Reasons:

- It is the more literal reading. The formula's own `ATK` (master, composed)
  and `heroATK` (this formula, lower-case) read as intentionally different
  names for intentionally different things — if the author meant the composed
  value they had a name for it already and did not use it here.
- It makes the Ultimate feel like a *reward for playing well*, not a
  slow-charging cooldown identical for every build. A player stacking damage
  Boons should see their Ultimate come around faster — that is the entire
  point of a damage-dealt-gated resource rather than a timer.
- It is stable and cheap: computed once at loadout time, not re-derived from
  a build that can change every room.

## Consequences

- If playtesting shows Ultimates charging too fast on heavily-boosted late-run
  builds, the fix is to re-derive `chargePerDamage` from the composed
  `world.playerAttack` / `world.fireRateMultiplier` instead — a one-line change
  in `HeroLoadoutResolver.apply`, isolated by this ADR.
- `chargePerDamage` is recomputed every time `HeroLoadoutResolver.apply` runs
  (level-up, star-up, talent change, arrow swap), so a levelled hero's
  Ultimate charges faster in absolute terms even under this reading — level
  and star growth raise `heroAtk`/`heroFireRate` too, which raises
  `damageDealt` roughly in step with the denominator. The reading only isolates
  *loadout-time* choices (Boons, arrow, Spire) from the charge rate, not
  progression.
