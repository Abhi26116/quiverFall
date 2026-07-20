# ADR 0002 — Confluence reachability

**Phase** 4 (found) → 5 (resolved)
**Date** 2026-07-19, resolved 2026-07-20
**Status** **Resolved in code.** Reachability is fixed and measured; *legibility*
remains a Phase 6 question — see "Resolution" at the end.
**Severity** High. This is the game's USP.

---

## What was found

Confluence is implemented and correct. Measured in a live world with the current
base kit, its natural trigger rate is **0%**.

Two measurements, both wrong in opposite directions, taken an hour apart:

| Rule | Trigger rate | Verdict |
|---|---|---|
| Proximity only (no angle constraint) | **50 of 52 shots (96 %)** | Meaningless — a flat damage buff |
| Proximity + 25° minimum crossing angle | **0 of 52 shots (0 %)** | Unreachable |

Both were measured across four scenarios: stationary vs one target, stationary
inside a ring of eight, strafing, and circling.

## Why each extreme happens

**The 96 % case.** A stationary player auto-aiming at one target sends every
arrow down nearly the same path. Each new arrow lies within the hit width of its
predecessor's trail along the *whole length*, so the closest-approach fallback
fires every time. Retracing a line is not threading it, but the geometry test
could not tell the difference.

**The 0 % case.** With the angle rule added, crossings require two trails to
meet at 25° or more. But every trail radiates outward from a single origin — the
player — toward whichever target auto-aim selected. Rays from a common origin
*diverge*; they do not cross. Where two shots do converge, they converge **at the
target**, and the arrow despawns on impact before reaching the crossing.

The angle rule itself is verified correct: 90°, 56° and 30° register; 15° does
not.

## Why this matters

docs/01-vision.md §1.5 already lists this as the project's biggest risk —
"Confluence is unproven and could read as noise" — and Phase 6 exists as the
go/no-go gate. This finding sharpens the risk from *readability* to
**reachability**: the concern is no longer whether players notice the effect, but
whether the base kit can produce it at all.

It also invalidates the assumption behind docs/03-progression.md §3.1 beat 6:00,
where the tutorial expects a first Confluence to fire *accidentally* by ~7
minutes. On current geometry that cannot happen.

## Options for Phase 6

Not decided here — this needs playtesting, which is what Phase 6 is for.

1. **Lean on the kit.** The design already contains Confluence-generating tools:
   Twinfang (converging paths that cross at 6 u), Wren's Volley Fan, Corvin's
   ricochets, Iris's Lattice, Skimmer's wall bounces. Accept a near-zero base
   rate and treat Confluence as build-gated. *Risk:* contradicts the tutorial
   beat and makes the USP invisible for the first several hours.
2. **Make arrows survive their target.** If arrows pierce or pass through on
   kill, converging fire crosses just past the target. *Risk:* changes pierce
   economics everywhere.
3. **Persist trails at the impact point.** A short trail stub left where an
   arrow died would give converging fire something to cross. Cheap; needs
   playtesting for readability.
4. **Lower the angle threshold** (25° → 12–15°). Cheap, but re-approaches the
   96 % failure mode; the two rates are closer than they look.
5. **Arena geometry.** docs/14 §14.1 already has designers marking
   `latticeHints` — wall pairs that make good Confluence geometry. Ricochets off
   those walls create genuine crossings. *This is the option the design
   anticipated.*

## Decision taken now

Ship Phase 4 with the angle rule at 25°. A mechanic that fires on 96 % of shots
is strictly worse than one that fires rarely: the first is a hidden flat buff
that teaches players nothing, the second is an unfinished feature that Phase 6
is scheduled to finish.

`ConfluenceSystem._maxParallelCos` is a single tunable, and the probe scenarios
are cheap to re-run against any of the options above.

## Consequences

- Phase 6 must resolve this before the game-feel gate can pass. It is now the
  first item in that phase, ahead of hit feedback and VFX tuning.
- The Phase 4 end-to-end test asserts the *wiring* works using constructed
  geometry, and says explicitly that it does not claim ordinary play produces
  crossings. That distinction must survive future edits to the test.
- If Phase 6 cannot make Confluence reachable and legible, docs/01 §1.5's
  fallback applies: the game remains a Draw/Momentum roguelite and the mechanic
  is cut. Better to know at day ~47 than at day ~150.

---

## Resolution (2026-07-20, after Phase 5)

**Measured natural trigger rate is now 6.9 % across real composed rooms**, from
0 %. `dart run tool/confluence_probe.dart` reproduces the numbers; the floor is
locked in by `test/game/confluence_reachability_test.dart`.

Two changes did it, and the A/B separates them:

| | rooted | ch1 circling | ch4 circling | ch8 circling | overall |
|---|---|---|---|---|---|
| Phase 4, immortal dummies | 0 % | — | — | — | **0 %** |
| Phase 5 enemies, no stub | 0 % | 5.3 % | 1.5 % | 3.8 % | **2.7 %** |
| Phase 5 enemies + stub | 0 % | 11.5 % | 9.2 % | 9.2 % | **6.9 %** |

### The diagnosis was incomplete

The original analysis blamed diverging rays and arrows despawning on impact.
Both are real, but the dominant cause was narrower and entirely fixable:

**Windline segments are emitted per 0.9 u flown, so the final 0–0.9 u of every
trail was never emitted at all.** An arrow accumulated `sinceLastSegment` and
then died — on a hit, a wall, or expiry — and that remainder was discarded. The
missing stretch is the one nearest whatever the arrow hit, which is precisely
where converging fire meets. Every trail stopped short of the only place trails
cross.

That is ADR option 3 ("persist trails at the impact point"), but it is better
described as a **bug in trail emission than a design change**: a trail is the
path an arrow flew, and rounding it down to the last whole segment was an
artefact of distance-based emission, not a decision anybody took.

`ProjectileSystem._retire` now lays the remainder before releasing the slot. For
a pierce-consumed arrow the stub runs to the *swept* end, so a trail that ends in
an enemy actually reaches it; for a wall stop it runs to the last legal position,
so no stub is laid inside geometry.

### Why Phase 5 mattered on its own

Phase 4 could only measure against immortal dummies, and immortal dummies keep
auto-aim locked on one target forever — so every arrow retraced one line and the
angle rule correctly rejected all of them. Real enemies move, die, and are
replaced, which fans the player's fire naturally. **Half the fix was simply
having a game to measure.** The probe keeps the dummy scenarios as labelled
controls, and they still read 0 %, which is the point.

### What the numbers mean

- **Rooted on a single target: 0 %, and that is correct.** Standing still buys
  Tier III damage; it does not buy Confluence. Retracing a line is not threading
  it. The 96 % degenerate mode stays closed, and a test asserts it.
- **Moving well: ~9–12 %**, roughly one shot in nine. Visible, learnable, and
  with headroom for the kit that is *supposed* to amplify it — Twinfang, Wren's
  Volley Fan, Corvin's ricochets, Iris's Lattice.
- **First Confluence within 2–9 s** of ordinary movement, against
  docs/03 §3.1's tutorial beat of ~7 minutes. That beat is no longer at risk.

### Consequences

- Options 2 (arrows survive their target) and 4 (lower the angle threshold) are
  **not needed** and should not be taken. Option 2 would have changed pierce
  economics across the whole game; option 4 walks back toward the 96 % failure.
- Option 5 (arena `latticeHints` and ricochets) is now an *amplifier* rather
  than a rescue. Phase 8 should still build it, but nothing depends on it.
- `ConfluenceSystem._maxParallelCos` stays at 25°.
- The Confluence perf gate is unaffected: 0.725 ms against the 0.8 ms budget,
  measured after the change. One extra segment per arrow is noise against a
  1,024-segment cap.

### Still open for Phase 6

Reachability is not legibility. docs/01 §1.5 lists the risk as "Confluence reads
as noise", and that remains untested — it needs the VFX, the bell chord, and
eight people who have not seen the game. **The Phase 6 gate is unchanged.** What
has changed is that the gate can now actually be run: at 0 % there was nothing
for a playtester to notice.
