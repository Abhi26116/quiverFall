# ADR 0022 — Skarn the Unmade: reusing the split, inventing the pressure

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for the split/pressure mechanic. P1's own attack is not
built — a known, flagged gap, not an oversight.
**Severity** Medium. One genuinely new primitive (`bossLastHitAgo`) plus a
few authored placeholders with no docs/06 anchor.

---

## What was missing

docs/06 §11, Skarn the Unmade (chapter 11): "P1: single heavy body, slow,
enormous telegraphs. P2: splits into two halves at 66%, sharing one HP pool.
Damaging only one causes the other to heal it at 3%/s. Both must be
pressured. P3: splits into four." Nothing about the *shared pool* half was
new — Cinder Choir already built exactly that primitive. What was missing
was the *pressure* half: a shared pool that anyone can passively regenerate
just by being ignored, which nothing in the sim could express yet.

## Decision — the split reuses Cinder Choir's primitives outright

Skarn's own primary **is** its P1 body — directly hittable, holding its own
real health — unlike Cinder Choir's invisible anchor, because P1 only ever
has one thing to hit at all. At each split (`bossPhase` reaching 1, then 2),
`SkarnSystem` spawns the missing bodies via the identical `linkedHealthSlot`/
`bossParent`/`bossChildIndex` fields ADR 0018-0020 already built and proved
generic. No new shared-pool machinery was needed — the ADR 0018 prediction
that Skarn's own split would be "a very close cousin" of Cinder Choir's P3
turned out to be exactly right for this half of the fight.

**Every split body's own ring position is fixed by its index into a full
4-slot ring, computed the same way regardless of how many bodies currently
exist.** P2's pair uses the two *opposite* slots (0 and 2); P3 fills the
remaining two (1 and 3). Nothing already on the field is ever moved when the
body count changes — a smaller, more deliberate version of the same "don't
invent motion nothing asked for" reasoning ADR 0019 used for the tether
sweep's own geometry.

## Decision — a new primitive for "damaging only one causes the other to heal"

**`EnemyStore.bossLastHitAgo`**: seconds since an enemy last took a nonzero
hit, reset to 0 by `ProjectileSystem._applyHit` and `ElementSystem.update`
on *any* damage that actually lands — on the hit slot itself, not the
health-redirect target, mirroring exactly how `linkedHealthSlot` already
keeps armour/plate/stagger on the hit slot while only the health write
follows the link. A boss's own system decides what "too long unhit" means
and what to do about it; the field only answers "how long ago", the same
split `bossTimer`'s own doc comment already drew between "one clock" and
"several consumers."

`SkarnSystem._tickPressure` runs this every tick once splitting has begun
(`bossPhase >= 1`; P1 has nothing to neglect and is explicitly excluded):
every currently-hittable body — the primary and every split-off child —
that has gone more than the neglect threshold without a hit heals the
shared pool **independently**, at docs/06's own stated 3%/s. Ignore two out
of two and both contribute their own 3%/s; that reading — not a single
shared "is anything being pressured" flag — is what makes "both must be
pressured" true as a mechanic and not just as flavour text, and it is
exactly what the four new tests in `skarn_system_test.dart` measure
directly (one neglected body heals; two neglected bodies heal at roughly
double the rate; pressuring both stops it entirely).

**Reused, not invented:** the 3%/s heal rate is docs/06's own number. **Not
anchored, and flagged:** the 1.0 s "how long is too long" neglect threshold
— docs/06 gives no window at all, only the outcome. "Tests: split
attention" reads as a short window rather than a forgiving one, so this is
authored deliberately tight, the same posture ADR 0019 took for its own
unstated warning window (there, at least, an existing magnitude was
available to reuse; here none was, so this is a genuine new placeholder to
revisit once playtesting exists).

## What's deliberately not built here

**P1's own attack.** "Slow, enormous telegraphs" needs a real wind-up and
slam, and this pass built none — P1 is currently a lone, undamaging body
until it splits at 66%. This does not block the fight's own doc-emphasised
centrepiece ("Tests: split attention"), which lives entirely in P2/P3, the
same reasoning that let Cinder Choir's P1/P2 land before its P3 did.

**Arena and encounter-count scope** are identical to Cinder Choir's own,
already recorded in ADR 0021 rather than repeated here: Skarn spawns at an
ordinary room's own arena centre (no bespoke boss arena exists), and
`Curves.bossHp`'s `encounterCount` is always 0 (`StageRunner` has no
`PlayerSave` access). `BossRoomComposer._builtByChapter` now maps chapter 11
to `skarnUnmade`, so a real run's chapter-11 stage 20 spawns it for real.

## Consequences

Two full multi-body bosses now exist, built on the same primitives, and
they disagree in exactly the way that matters: Cinder Choir's P3 *unshares*
its pool (`linkedHealthSlot = -1`, independent death per body); Skarn's
never does (every split body dies only when the primary's shared pool
does). Coilspine (24 segments) and Thrall (nine sigils) each have their own
question to answer against this pair rather than assuming either shape
applies unmodified — Skarn's own "no independent death, but active
self-healing" is the shape most likely to matter for a boss whose bodies
are meant to feel like flexible pressure points rather than individually
farmable kills.
