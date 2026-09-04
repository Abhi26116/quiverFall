# ADR 0035 — Gaunt's own P2: the third "heavy hit," and the first GDD-stated radius

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2. P3 (dropping the shield for +80% speed and a
3-hit combo with a stagger window) is not built — a known, flagged gap.
**Severity** Low. Pure composition; the freeze point simply moved from
`bossPhase >= 1` to `bossPhase >= 2`, updating one pre-existing test that
had encoded the old boundary as its own assumption.

---

## What was missing

docs/06 §2, Gaunt, the Iron Tide: P2: "Shield slams, sending a crimson
shockwave ring outward (jumpable only by being outside 5u — there is no
jump, so this is a positioning check). Rotation rises to 110°/s." Gaunt's
own P1 (ADR 0023) was one of the first bosses built this session, from
back when P2/P3 work across the whole roster was still entirely deferred.

## Decision — a ring is a rendering question; the sim only needs a circle

"Sending a crimson shockwave ring outward" describes an *animation* —
something expanding visibly over the wind-up before it resolves. The
actual hit test at the moment it matters is identical to every other
circle attack in the roster: `EnemyAttack.beginCircle`/`playerInCircle`,
evaluated once at resolve time. **This is the first boss whose own attack
radius is a GDD-stated number rather than an authored one** — "outside 5u"
is Gaunt's own card text, not a guess, so `_p2SlamRadius = 5.0` needed no
derivation at all.

**Not range-gated, unlike Skarn's own P1 slam (ADR 0034).** Skarn has to
close distance before its melee-range heavy hit means anything; Gaunt's
shockwave's own radius *is* the range question, so it fires on a plain
cooldown regardless of where the player currently stands — "outside 5u
when it resolves" is the entire dodge, which only makes sense if the
attack does not wait for the player to wander into range first.

## Decision — the third boss to agree on what "heavy" means

The wind-up (1.8s) and cooldown (2.0s) reuse Skarn's own "enormous
telegraph" magnitudes verbatim (ADR 0034) rather than a fresh pair of
guesses for the same kind of moment. The damage reuses the same derived
anchor a third time: the Thresher's own 9%, scaled by Tier III's own
2.10x multiplier — first established for Hollow Warden's own heavy shot
(ADR 0031), reused for Skarn's slam, now Gaunt's shockwave. Three
independent bosses' own "this hits hard" moments now agree on the same
number by construction, not by coincidence — worth treating as this
roster's actual answer to "how much damage is a heavy hit" going forward,
rather than re-deriving it a fourth time.

## The freeze point moved, and a pre-existing test had to move with it

Every prior "not built yet" gap in this boss lived at `bossPhase >= 1`
(the P1→P2 boundary), including a test asserting movement and turning
halt there. With P2 now real, that boundary moved to `bossPhase >= 2`
(the P2→P3 boundary, where P3's own still-undone drop-the-shield moment
would begin) — the pre-existing test's own premise became false, not
merely incomplete, the moment P2 landed. Caught immediately by running
this boss's own test file before touching anything else: renamed and
updated to set `bossPhase = 2` instead of `1`, keeping the exact same
"one transitional tick" capture discipline ADR 0023 already established.
This is worth remembering for every other boss whose P2 gets built next —
the "stops once past P1" test each one currently carries needs the
identical treatment.

## What's deliberately not built here

**P3 ("drops the shield entirely, gains +80% speed and a Ripper-style
3-hit combo with a stagger window")** — a genuinely different kind of
mechanic (the frontal-plate puzzle disappears entirely, replaced by a
melee combo with its own stagger window, which nothing in this boss's own
code has touched yet) rather than an escalation of what already exists.
Once `bossPhase` reaches 2, movement, turning and slamming all freeze —
the same posture the class's own P1 gap already took before P2 existed.

## Consequences

Two of twelve campaign bosses now have a complete-except-P3 fight (Gaunt,
Skarn's own P2/P3 are actually the OLDER pieces here — this ADR closes
Gaunt's own P2, leaving only its P3 open). The derived "heavy hit" number
is now a real, three-times-confirmed pattern worth reaching for by default
whenever a future P2/P3 needs one, rather than re-deriving from the
Thresher every time.
