# ADR 0081 — Thane's Tempered and Ashlin's Eternal: a heal ceiling and a once-per-room refresh gate

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Two small, unrelated gaps, bundled here because each
needed only a few lines and neither justified its own ADR.
**Severity** Low-medium. Both are single, well-contained decisions; neither
touches a shared hot-path system.

---

## Gap 1 — Bloodtide's own healing ceiling

docs/07 §12, Thane's passive: **"Cannot be healed above 70 % max HP by any
source."** T1b *Tempered* raises this to 90 %. Bloodtide itself (the missing-
HP damage bonus) and Red Draw were already implemented; the heal ceiling was
left pending because "by any source" sounded like it demanded a check
threaded into every heal path — lifesteal, `BoonSystem` regen and shields, a
room-clear heal, Vital Surge's own heal-to-full — with no stated answer for
which of those actually count.

**Decision — one ceiling clamp at the end of `tick`, not a check per source.**
"By any source" is taken literally: a single clamp run once per tick, after
every heal source that tick has already applied, cannot miss a source the
way N scattered checks eventually would, and needs no per-source judgment
call about which ones are exempt. It runs *after* Vital Surge's own
heal-to-full too — that heal is applied directly by
`LoadoutResolver.apply`, outside `tick()` entirely, but the next tick's own
clamp still catches the resulting health value regardless of how it got
there. `Tempered` (T1b) is the same clamp reading a raised constant (90 %
instead of 70 %), not a second code path.

## Gap 2 — Rebirth Nova's refresh needs a real once-per-room limit

docs/07 §18, Ashlin's Ultimate: **"Rebirth Nova: 500 % AoE, heals 25 %, and
refreshes Rekindle if already used."** T5: *Eternal* — **"Ultimate refresh
has no cooldown."** The AoE, the heal and the refresh itself were already
implemented with no restriction, which left *Eternal* with nothing to
remove: a cooldown that already doesn't exist cannot be lifted, so the
talent was flagged pending rather than implemented as a no-op that would
have promised a difference the base kit never had.

**Decision — an authored once-per-room gate, the same shape as every other
"only once until the next room" restriction in this game.** Casting Rebirth
Nova a second time in the same room still fires the AoE and the heal in
full — only the Rekindle-refresh clause is gated, matching the card's own
wording, which restricts nothing but "refreshes Rekindle." A new
per-room flag (`HeroRuntime.rebirthNovaRefreshedThisRoom`) tracks whether
the refresh has already fired since the last room boundary; *Eternal*
simply ignores the flag outright, which is now a real, verifiable
difference rather than an invented one.

## A pre-existing bug this gap's own test caught

Verifying the new flag's room-boundary reset (`beginRoom()` already clears
it, alongside Flurry, Umbral Step, Prism, Bloom, Red Draw, Tempest Nock,
Caroms, Hall of Mirrors, Miasma, Pyre Line, Aegis Pin, both Singularity
wells and the Lattice) surfaced that `HeroRuntime.beginRoom()` itself has
never been called from `SimWorld` since it was added in Phase 10 part 3 —
`beginRoomForTest()` called `boons.beginRoom()` but not `hero.beginRoom()`.
Every one of those room-scoped hero timers has been carrying over into the
next room in real play this whole time, not just Rebirth Nova's new flag.
Fixed alongside this ADR's own work, in `SimWorld.beginRoomForTest()`.

## Verified end to end

Four new Bloodtide/Tempered tests (the ceiling catches an arbitrary heal, a
heal that lands below the ceiling is left untouched, Vital Surge's own
heal-to-full is caught the same way, Tempered raises the ceiling to 90 %);
the existing damage-scaling and Red Draw tests were re-based off 65 % HP
since 100 % is no longer a reachable state for Thane to test from. Three
new Rebirth Nova tests (the refresh fires once per room and a second cast
does not re-fire it, a room boundary resets the gate, Eternal ignores the
gate on a second same-room cast) — the last one incidentally the test that
caught the `beginRoom()` wiring bug above.

## Consequences

`pendingHeroBehaviourWork` drops to 11.
