# ADR 0078 — Wren's Warden's Lattice and Warden's Fury: a per-arrow Ultimate tag

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Wren's own kit is now complete.
**Severity** Low. One new per-projectile field, read at two existing lay
sites and one existing death-pass hook.

---

## What was missing

docs/07 §7.3, Wren T5: **"Warden's Lattice: Ultimate Windlines last 4 s."**
**"Warden's Fury: Ultimate refunds 30 % charge on kill."** The ledger's own
note said both needed "per-ultimate-arrow tracking... that nothing before
Phase 10 built." Volley Fan itself (the base Ultimate and its two T3
branches) was already fully implemented.

## Decision — one per-projectile tag, read two different ways

`ProjectileStore.isUltimateArrow` — a `Uint8List`, the same shape as
`willMarkBoss`/`willChain` — is set unconditionally on every arrow
`_fireWrenVolleyFan` spawns, regardless of which talents are picked. The
two T5 branches each read a *different* consequence of it:

**Warden's Lattice** needed a per-arrow Windline duration, not a per-hero
one — `windlineDuration` is a plain `SimWorld` field threaded as a
parameter through several layers of `ProjectileSystem`, so a live
`hero.has(wrenWardensLattice)` check at the two actual lay sites
(`_layForcedSegment`, `_layFinalSegment`) would need `hero` added to both
signatures just to answer a question already known at spawn time. Instead,
`ProjectileStore.windlineDurationOverride` (a `Float64List`, 0 = "use the
ambient duration") is baked into each arrow once at spawn — a single new
`_effectiveWindlineDuration` helper reads it at both lay sites in place of
the raw `windlineDuration` parameter, and neither site needs a hero
reference at all.

**Warden's Fury** needed to know, at the moment an enemy actually dies,
whether the arrow that struck it last was one of the Ultimate's own —
"refunds charge on kill" reads as crediting the specific kill, not merely
"a Fury-tagged arrow existed somewhere in this fight." A new
`EnemyStore.lastHitWasUltimate` is copied from `isUltimateArrow`
**unconditionally** on every primary hit (not just when true) — the same
"reflects the most recent hit, not any past one" reasoning
`bossLastHitAgo`'s own reset-to-zero already uses — so an enemy that
survives an Ultimate hit and is later finished off by an ordinary arrow is
not credited to Fury. `AiSystem._reap` reads it right where Sela's own
Shatter and Wildfire/Contagion already read pre-reset corpse state, adding
`_wrenWardensFuryChargeRefund` (0.30) to `hero.ultimateCharge`, clamped the
identical way `chargeFromDamage` already clamps.

Splash and chain hits (Bram's, Torv's) do not update
`lastHitWasUltimate` — only the primary hit-resolution path does. Wren has
neither splash nor chain, so this is a non-issue in practice; noted rather
than solved generically, since generalising it for heroes that do not need
it would be speculative.

## Verified end to end

Four new tests: Warden's Lattice's own Windlines read ~4 s remaining at
creation (polled via `WindlineStore.expiryAt` against
`SimWorld.elapsedSeconds`, taking the maximum seen across a travel window
rather than a single snapshot, since a segment's own remaining time only
decreases after creation); without the talent, the same arrows use the
ordinary `SimConfig.windlineDuration` (1.2 s); a kill from the Ultimate's
own arrow adds +30 % more charge than the identical kill without Fury
(measured as a *difference* between two ★5 runs, not an absolute number —
comparing against a ★0 baseline would have silently mixed in
`Curves.heroStat`'s own star scaling, the exact trap an earlier Halden test
already hit once); and an ordinary-arrow kill adds nothing extra even with
Fury picked. The first attempt at the last two tests compared a ★0 run
against a ★5 run and failed by exactly the star-scaling amount — fixed by
levelling both sides to ★5.

## Consequences

Wren's entire kit is now implemented — the ninth hero with nothing
deferred. `pendingHeroBehaviourWork` drops to 19.
