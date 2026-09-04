# ADR 0062 — The Last Warden, P4: the floor is removed, honestly

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P4 only. P1-P3 (ADRs 0059-0061) are done; P5
remains.
**Severity** High. The one phase in this fight that reads, literally, as
a request for real terrain physics this sim does not have.

---

## What was missing

docs/06 §6.3, The Last Warden, P4: **"Arena floor is removed; combat on
floating Windline-drawn platforms the player creates by firing. The
mechanic becomes the terrain."**

## Decision — the standing-on-a-line check is real; the floor itself is not

A literal reading needs a genuine fall-through/void-collision terrain
model: some notion of "off the platform," a consequence for being there,
and every other subsystem (movement, hazard placement, enemy pathing)
staying coherent against a floor that can vanish under them. Building
that means touching `SimWorld._applyInput`, the one function every other
interaction in the game already depends on — the identical class of
change ADR 0038 already declined for Rimefather's own "reduces friction"
half of its own P2, for the identical reason: a materially larger,
riskier redesign than a single phase of a single boss should force onto
shared code.

Instead, this reuses the "is the player standing on a live Windline"
check the Hollow Warden's own P2 already built and proved
(`_pointNearSegment`, reimplemented here against the player's own lines
rather than the Warden's — the same "small independent copies, not a
shared utility" posture ADR 0057 already settled for this exact class of
parametric check) as a real, working stand-in for "on/off a platform":
while the player is not standing on any live player-owned Windline
segment, they take the roster's own bare persistent-aura anchor (9%) on
the same shared cooldown The Loom's own threads already established
(0.6s).

**"The mechanic becomes the terrain" is genuinely true under this
reading** — the only way to stop taking damage is to keep firing, which
is exactly what lays a Windline in the first place — even though no
entity can ever literally fall through the arena floor, because the sim
has no such floor to fall through. The fiction survives; the physics
underneath it is honest about staying flat.

## What stays out of scope

The Warden's own movement is not affected — the card's own text describes
the arena, not a restated "at parity" rule, and giving the Warden its own
platform requirement (it does not fire Windlines today) would be a second,
uncalled-for mechanic. Whether P5 needs the arena to visually update (the
"floor removed" fiction rendered, not just felt through damage) is a
presentation-layer question this ADR does not touch.

## Verified end to end

Four new tests, twenty-one total for this boss: no void damage before
`bossPhase >= 3`; damage on a real cooldown once P4 begins (a hit, then a
second tick immediately after showing no further damage); standing on a
freshly-laid player Windline avoiding the damage entirely across a real
window of ticks; and a Windline whose `expiresAt` has already passed no
longer counting as a platform. All four passed on the first real
attempt.

## Consequences

P5 ("one HP each... first hit wins, 20s timer, sudden death") remains
entirely unbuilt — the fight's own final phase, and the only one whose
own card explicitly says it needs "its own end-of-fight rule" rather than
one of `BossPhaseSystem`'s ordinary fractional thresholds (`boss_
definition.dart`'s own doc comment, cited in ADR 0059).
