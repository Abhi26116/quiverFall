# ADR 0050 — Rimefather's own P3: a decoy, observed and corrected after the fact

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. Rimefather now has P1+P2+P3, complete end to end.
**Severity** Medium-high. The session's first genuine *decoy* mechanic —
flagged since ADR 0038 as needing "an idea the sim has no analogue for at
all" — resolved without touching the shared, heavily-tested damage
pipeline at all.

---

## What was missing

docs/06 §6, Rimefather: P1 (ADR 0026) and P2 (ADR 0038) are both already
built. P3 — "Shatters into three ice-mirrors, only one of which is real
(revealed by which one casts a shadow — a purely visual read, no HUD
marker). Wrong-target damage heals it."

## Decision — three targetable children, corrected after the fact

Three ordinary, independently-*targetable* children are placed in a small
triangle around the primary's own position the instant P3 begins
(`_spawnMirrors`, idempotent by the same "scan for an existing child"
shape every other placed-once child in this roster already uses) — a
genuinely different posture from every other placed child built this
session, all of which are deliberately `untargetable` accounting anchors.
Here the whole point is that the player *can* hit the wrong one, so all
three must be real, hittable bodies. `bossActiveChildIndex` (free — P1/P2
never touch it) holds which ordinal is real, chosen once at random.
"Which one casts a shadow" is a rendering-only tell this system
deliberately never encodes anywhere a consumer could query — the choice
lives only in this one field, read only by this system, which is what
keeps "no HUD marker" an honest claim rather than a promise the sim
quietly undermines by exposing the answer somewhere else.

**"Wrong-target damage heals it" does not intercept the hit.** The
tempting approach — redirect a fake mirror's own incoming damage before
it lands, the way `linkedHealthSlot` already redirects a *shared-pool*
hit to a different entity's health field — doesn't fit here, because the
outcome isn't "redirect the damage," it's "cancel the damage AND apply a
heal somewhere else," a strictly bigger change to the shared,
heavily-tested `ProjectileSystem`/`ElementSystem` damage-resolution code
every other enemy in the game also depends on. Instead, `_tickMirrors`
reads each mirror's own health *after* combat has already run this tick
and compares it against what it read *last* tick
(`bossLastHitAgo`, unused anywhere in this file until now, repurposed
per-mirror as a health baseline rather than a time) — the identical
"observe and correct after the fact" shape `AiSystem._applyAuras` already
uses to heal the Green Mother from her own Knitters (ADR 0028), just
reading a delta instead of a live proximity check. A drop on the real
mirror simply stands. A drop on a fake one is refunded to its own exact
prior value (the decoy is never actually killable) and the identical
amount heals the real mirror instead, capped at its own max health. The
primary's own `health` is kept mirrored to the real mirror's own value
every tick, so `BossPhaseSystem`'s generic health-fraction machinery and
the eventual death check both keep working completely unmodified — no
special-cased health path anywhere else in the sim needed to learn about
mirrors at all.

## The cone and the ice both stop

P3 reads as a pure target-discipline puzzle, not a third offensive layer
on top of P1's cone and P2's ice — both stop the instant `bossPhase`
reaches 2, the same posture this system's own prior "not built yet"
placeholder already took (the Momentum multiplier reset and the
telegraph-clearing tests written against that placeholder needed zero
changes, since both remain literally true — only their meaning, "frozen"
versus "P3 genuinely doesn't attack," changed).

## Verified end to end

Four new tests: three targetable mirrors confirmed placed with exactly
one flagged real; a direct hit on the real mirror confirmed to reduce
both its own health and the primary's own mirrored value; a direct hit on
a fake mirror confirmed to be refunded to the exact prior value *and* to
heal the real mirror by the identical amount (with deliberate headroom
left below max health so the heal is actually observable, not silently
clamped away); and the primary's own death confirmed to despawn every
mirror, the same "write the death test" discipline this session's own
room-clear bug class (ADR 0032, 0036) established.

## Consequences

Seven of twelve campaign bosses now have a real P1+P2+P3 (Cinder Choir,
Silversong, Thrall of the Nine, the Green Mother, the Weeping Gate,
Gaunt, Rimefather). This closes the first "the sim has no analogue for
this at all" gap this session's own P2/P3 sweep has actually attempted
rather than deferred — the answer turned out to be a system that watches
and corrects, not one that intercepts, which is worth reaching for again
the next time a card's own effect (redirect, cancel, convert) sounds like
it needs surgery on the shared combat pipeline itself.
