# ADR 0032 — The Quiverfall: the finale reuses the very first boss's own trick

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P1. P2 ("The Choir Reforms" — eleven boss echoes)
and P3 ("Quiverfall" — 40 fragments, Confluence-gated invulnerability) are
not built — a known, flagged gap. **All twelve campaign bosses now have
P1 built.**
**Severity** High. A real, proactively-caught correctness bug (spoke
anchors that would never despawn, permanently blocking the room-clear
condition) fixed before it shipped, and the retirement of the session's
own long-running "unbuilt chapter" fallback test now that no real campaign
chapter is left to point it at.

---

## What was missing

docs/06 §12, The Quiverfall (chapter 12): "Tests: mastery · Campaign
finale." "The sky itself, falling. Fought on a collapsing arena that loses
8% of its floor per phase." P1 — The First Shard: "A vast descending shard
fires converging amber lines from the arena edges. Safe space is the
intersection gaps." The last of the twelve campaign bosses, and the one
this session always intended to build last — its own P2 needs every other
boss to already exist.

## Decision — mechanically, this is Cinder Choir's own P2 tether sweep, grown up

"Converging lines... safe space is the intersection gaps" describes the
identical shape `CinderChoirSystem._tickTetherSweep` already built for the
very first boss of the phase (ADR 0019): several lines radiating from a
shared centre, rotating together, warning before lethal, one shared damage
cooldown. `TheQuiverfallSystem._tickSweep` **is** that function, copied
and scaled: eight spokes instead of three (authored — "the arena edges",
plural, read as more than a triangle), reusing every other number
unmodified (`_damage`/`_cooldown` = the same Thresher-derived 9%/0.6s
anchor; `_spokeWidth` = the same `SimConfig.windlineHitWidth`). The one
genuinely new number is the sweep rate, chosen to keep the *time* between
one line passing a fixed point and the next roughly comparable to Cinder
Choir's own, despite eight spokes packing closer together than three would
— authored, not derived from any GDD number, and explicitly unproven
pending the balance harness (Phase 14), the same honesty every other
similarly-picked cadence this session has carried (Green Mother's spawn
interval, Thrall's sigil health fraction, the Weeping Gate's tier-unlock
window).

**This reuse is deliberate, not just convenient**: the campaign's own
finale is framed as a "greatest hits" fight (P2 literally replays every
prior boss's own signature move), so having its own P1 visibly echo the
very first boss's own signature mechanic — at a grander scale, for the
last fight of the campaign — is in keeping with the card's own emotional
arc, not merely the path of least implementation effort.

## Decision — no floor collapse in P1

"Loses 8% of its floor per *phase*" is read as a phase-transition event —
something that happens *when* a new phase begins, not a process running
continuously through P1 itself. Under that reading, nothing shrinks during
P1 at all, so this pass builds no dynamic-geometry system whatsoever.
Building one regardless — `Arena` has no notion of changing shape mid-room
today — would be a real, separate capability, and is flagged alongside
P2/P3 rather than attempted here.

## A real bug, caught by writing the death test rather than by inspection alone

Every spoke's own telegraph needs to live on its own entity (an enemy owns
at most one telegraph at a time — the same constraint that gave Cinder
Choir its three children). The first draft of this system gave the eight
spoke anchors `bossParent`/`bossChildIndex` but **no death handling at
all** — nothing despawned them when the primary died. Since they are
`untargetable` (nothing can kill them directly) and have no independent
death condition of their own, they would have sat alive forever once the
primary fell, and the boss room's own "zero alive enemies" clear condition
(ADR 0021) would never fire — the room would never complete. Caught before
shipping by writing `the_quiverfall_system_test.dart`'s own "despawns every
spoke anchor" test against the first draft, which failed as expected;
fixed by adding the same `_despawnChildren` guard
`CinderChoirSystem.update` already runs on its own primary's health
reaching zero, called here for the identical reason.

## A naming note

This system is `TheQuiverfallSystem`, not `QuiverfallSystem` — every
other system in this directory drops a card's own leading "The"
(`GreenMotherSystem`, `WeepingGateSystem`), but "Quiverfall" bare is
already the game's own package name *and* an existing Boon
(`BoonBehaviour.quiverfall`, #19 — "every 10th arrow deals 2,000% but
stuns for 1s"). That collision exists in the design itself, not something
invented here; keeping the boss's own class name unambiguous in code
seemed worth the one inconsistency.

## The session's own "unbuilt chapter" test finally runs out of chapters

Every prior boss landing bumped `stage_runner_test.dart`'s and
`level_generator_test.dart`'s own "a chapter with no fight built yet"
tests forward to the next genuinely-unbuilt campaign chapter. With this
boss, there isn't one — all twelve exist. Both tests now target chapter
13, which names no real GDD campaign chapter at all (docs/06's own #13+
are Elite/Event bosses, spawned through an entirely different path this
composer never touches) — it exists purely to keep exercising
`BossRoomComposer.bossFor`'s own fallback for *any* chapter without a map
entry, a mechanism this session still wants covered even though every real
campaign chapter now has an answer.

## What's deliberately not built here

**P2 ("The Choir Reforms" — all eleven previous bosses appear as 12s
echoes, one at a time, each using a single signature attack) and P3
("Quiverfall" — the shard shatters into 40 fragments raining continuously;
the boss is invulnerable except when the player's own Windline lattice
connects three or more fragments, channelling them into the core — "the
only fight in the game that *requires* Confluence").** P2 needs a real
"echo" primitive this pass does not attempt to generalise from eleven
bespoke, already-built systems — a real, sizeable piece of design work in
its own right (does an echo reuse the exact numbers its own boss used, or
scale them to a 12s window? does it reuse that boss's own `EnemyStore`
fields, or need fresh ones per echo?). P3 needs a genuinely new kind of
conditional invulnerability, driven by the *player's* own live Windline
geometry rather than any timer or live-enemy-count this session has built
a boss's defence from before. Once `bossPhase` reaches 1, the sweep stops
and every live spoke telegraph is cleared — the same posture every other
boss's own undone phases already take.

**`BossRoomComposer` now maps chapter 12 to `quiverfall`** — the twelfth
and final confirmation of ADR 0021's own predicted two-line integration
cost, for the last campaign chapter that needed one.

## Consequences

**All twelve campaign bosses now have a real P1 built.** Phase 11's own
remaining scope is entirely P2/P3 work on already-built fights (Cinder
Choir's P3 already exists in full; most others' P2/P3 are open), Skarn's
own still-missing P1 attack, a real bespoke boss arena (ADR 0017/0021's
still-open gap, now touched by twelve different fights all sharing an
ordinary room's own arena), persistent encounter-count tracking, the
Elite/Event tier (#13-16), and the three remaining Endless/Warden bosses
(#17-19, The Last Warden). Building P2 for any boss going forward should
check this ADR's own "echo" gap first — The Quiverfall's own P2 is the one
piece of docs/06 that needs *every other boss's own signature attack* to
already be real, which as of this commit, for the first time, it is.
