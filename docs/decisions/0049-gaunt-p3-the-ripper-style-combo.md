# ADR 0049 — Gaunt's own P3: the Ripper's own combo, reimplemented and scaled up

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. Gaunt now has P1+P2+P3, complete end to end.
**Severity** Medium. The first P3 to name an existing ordinary-enemy
family by its own card text ("Ripper-style"), continuing the "echo an
existing enemy family" pattern this session's own P1/P2 work already
found paid off repeatedly (Silversong/Screecher, Vermillion/shell-linger
puddles) — now proven for a P3 too.

---

## What was missing

docs/06 §2, Gaunt, the Iron Tide: P1 (ADR 0023) and P2 (ADR 0035) are both
already built. P3 — "Drops the shield entirely, gains +80% speed and a
Ripper-style 3-hit combo with a stagger window. The armour puzzle becomes
a reflex test."

## Decision — reuse the shape, not the private function, a fourth time

"Ripper-style" names `RushTree._ripper` (docs/05) directly — a real
three-hit combo already fully built and tested for the ordinary roster:
two fast openers, a lethal overhead finisher, and a stagger window where
landing enough damage during the finisher's own wind-up cancels it
outright (`EnemyTuning.ripperStaggerFraction`/`ripperStaggerSeconds`/
`ripperComboLength`/`ripperSwingArcDegrees`/`ripperOpenerFraction`, all
reused verbatim). Gaunt has no `EnemyDefinition` to run that private tree
method with, so `_tickP3Combo`/`_beginP3Swing` reimplement its exact
control flow directly against `Steering`/`EnemyAttack` — the same posture
every borrowed-family mechanic in this roster already takes (the Echo's
own mirror math for Hollow Warden, ADR 0031; the Screecher's own cone for
Silversong/Rimefather, ADR 0024/0026).

**Timing stays fast; damage and reach scale up.** The ordinary Ripper's
own content data (0.35s/0.8s/0.7s/1.6s wind-up/heavy-wind-up/recovery/
cooldown) is reused unchanged — a genuinely fast combo is what makes it
read as "a reflex test" rather than another slow telegraph. What scales
for a boss-sized body: the finisher deals the same derived "heavy hit"
this boss's own P2 shockwave already uses (0.09 × 2.10, the anchor four
different bosses in this roster now share), openers scale off that by the
ordinary Ripper's own opener fraction (0.36) rather than a fresh ratio,
and the attack range doubles the ordinary Ripper's own 1.3u for a body
several times its size.

## "Drops the shield entirely" and "+80% speed" are both one-line changes

`plateHealth` is set to `0` every P3 tick (no one-time latch needed — the
assignment is idempotent and cheap) and never re-armed; "the armour
puzzle becomes a reflex test" is read as the puzzle being *gone*, not
merely bypassable by an angle the player has to keep finding. `_p1Speed ×
1.8` is the card's own stated multiplier applied to the one number this
fight has used for movement since P1 — no second speed constant needed.

## Verified end to end, not just structurally

Five tests: a frontal hit (the exact angle P1's own plate would have
reduced to 5%) now takes the full, unmitigated 1000 — the same
`playerAttack`/damage-comparison shape the pre-existing P1 tests already
established, applied to prove absence rather than presence this time. A
displacement test confirms the exact `1.8 u/s` chase speed over a
measured second. A full three-swing combo, landed from a fixed range that
needs no chase, produces the *exact* resulting health — `100 −
100×(0.06804×2 + 0.189) = 67.492` — two openers and a finisher, not three
equal hits. A dedicated stagger test polls forward to the exact tick the
finisher's own wind-up begins, injects enough `damageDuringWindUp` to
cross the threshold, and confirms both the state transition to
`staggered` *and* that the finisher's own damage never landed — the
mechanism's defining property, not just its trigger condition.

## Consequences

Six of twelve campaign bosses now have a real P1+P2+P3 (Cinder Choir,
Silversong, Thrall of the Nine, the Green Mother, the Weeping Gate, Gaunt).
This is the fourth time this session an ordinary enemy family's own
already-built mechanic (Screecher's cone, shell-linger puddles, and now
the Ripper's own combo) closed a boss's own gap outright — worth checking
a card's own vocabulary against `docs/05`'s own enemy roster by name
before assuming any "hard"-sounding mechanic needs inventing from
scratch, P1/P2/P3 alike.
