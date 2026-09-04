# ADR 0055 — Elite-tier boss integration: the twelve-times-proven pattern, a thirteenth time

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. The Ashen Choir now spawns in a real run. Only three
of the twenty roster archetypes have no real-run spawn path left: Umbral
Twin, Bellweather, and The Pale Judge (docs/06 #14-16) — none of which
have a fight built yet at all.
**Severity** High. The specific gap ADR 0033 flagged as this session's
"real finding": Ashen Choir had a complete, tested fight and nowhere in
the game to spawn it.

---

## What was missing

ADR 0033 built The Ashen Choir's own fight but left it unreachable:
"this boss has NOWHERE TO SPAWN in an actual run... the existing
Elite-room path (`RoomComposer.compose(isElite: true)`) is a pure,
allocation-free `RoomPlan` generator built around ONE content-index per
enemy; it has no notion of 'one pick spawns four entities sharing a
health pool.' Wiring this in for real needs a design decision (which
chapter, what frequency, replacing an ordinary elite how often) docs/06
doesn't state."

## Decision — reuse the campaign-boss integration exactly, once the frequency question is answered

Investigating `StageRunner`'s own boss-spawn call before writing anything
found the real shape of the problem already solved for the campaign
tier: `StageRunner` reads `RoomBlueprint.bossArchetype` *generically* —
never checking `RoomKind.boss` specifically — and calls
`BossRoomComposer.spawn(world, boss, ...)` whenever it is non-null. Since
`BossArchetype.ashenChoir` is a plain member of the exact same enum every
campaign boss already is, and `bosses.json` already has a full entry for
it (`hpMultiplier: 48`, from ADR 0033's own earlier work), the entire
spawn mechanism needed **zero changes**. The only real work was the
*decision* half: which room becomes an Ashen Choir room, and how the
generator gets told.

`LevelGenerator._assemble`'s own boss check (`slot.kind == RoomKind.boss
? BossRoomComposer.bossFor(chapter) : null`) became a `switch` adding one
more arm for `RoomKind.elite`, consulting a new, parallel
`EliteRoomComposer.eliteFor(globalStage)` — the exact same "one map, a
chapter (or stage) with no entry falls through to the ordinary path"
shape `BossRoomComposer.bossFor` already proved twelve times over (ADR
0021), now proven a thirteenth.

## Why `globalStage`, not `chapter`

`BossRoomComposer.bossFor` keys by chapter alone because a campaign boss
always sits on that chapter's own fixed stage 20 — one occurrence per
chapter, by construction. An Elite room instead exists on *every*
non-boss stage from chapter 3 onward (`StageBlueprint.eliteIndex`), so
keying `EliteRoomComposer` by chapter would have made Ashen Choir replace
the ordinary Elite pick on roughly nineteen consecutive stages — a
routine occurrence for a card written as a rare, heavier encounter than
an ordinary "one Riftborn plus scraps" room. Keying by the exact
`globalStage` instead gives it precisely the one occurrence its own
rarity implies, with no new mechanism needed beyond a finer-grained map
key.

## The placement itself is authored, not GDD-stated

docs/06 gives Endless bosses an explicit cadence ("every 10 floors") but
none at all for the Elite/Event tier. Chapter 3, stage 10
(`globalStage = 50`) is chosen deliberately, not arbitrarily: chapter 3 is
the very first chapter with any Elite room at all
(`StageBlueprint.firstEliteChapter`), and stage 10 is roughly its own
midpoint — "an Elite remix of the very first boss you fought, the first
time the game shows you what an Elite room can be." Real placement tuning
(should it recur? scale with the player's own progress? sit earlier or
later?) is explicitly a Phase 14 balance-harness question, the same
honesty every other authored-not-derived number this session has carried.

## Verified end to end, and at the exact boundary

Two new tests, alongside a 10,000-blueprint generator fuzz run
(`level_generator_test.dart`, unmodified, already exercising `globalStage
50` many times over and reporting zero new violations): chapter 3's own
stage 10 confirmed to actually spawn a real Ashen Choir primary through
the full `StageRunner` pipeline, and the immediately adjacent stage 9 —
same chapter, same room index, one stage over — confirmed to still
compose an ordinary Elite room, ruling out an off-by-one in the
`globalStage` arithmetic rather than merely testing the happy path.

## Consequences

The Ashen Choir is now a real, reachable encounter, not just a tested
system. Extending `EliteRoomComposer._builtByGlobalStage` is now the
entire cost of giving Umbral Twin, Bellweather, or The Pale Judge a real
spawn path once each gets a fight built — none of the three exist yet at
all (no sim system, no bespoke mechanic resolved for any of the three
GDD gaps their own cards describe: total-darkness-lit-by-Windlines,
rule-inversion-on-a-bell-toll, build-reading-immunity). Building one of
those from scratch is real, separate boss-design work, not integration
work — this ADR closes only the "nowhere to spawn it" half of the gap,
for the one Elite-tier boss that already has a fight behind it.
