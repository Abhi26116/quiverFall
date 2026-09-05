# ADR 0071 — The companion-entity primitive, not yet a hero's own kit

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved for the primitive itself. Wiring it into Zea's own
Skyhawk/Falconry and Mirelle's own Hall of Mirrors is a separate, later
piece — see below.
**Severity** Medium-High. The first genuinely new entity category this
session has added (`EntityKind.companion`), not a new field on an
existing one.

---

## What was missing

Eleven `pendingHeroBehaviourWork` entries across two heroes are blocked
on the identical missing piece. Zea, the Falconer (docs/07 §7.3):
*"Skyhawk: a spirit hawk companion attacks independently for 35 % of hero
ATK at 1.5/s, and its shots lay Windlines the player can Confluence
through. Ultimate — Falconry: summons 4 hawks for 12 s,"* plus four
talents building on it. Mirelle, the Mirrored: *"Ultimate — Hall of
Mirrors: 8 s where every arrow duplicates 3×, and a mirror clone of the
player fights alongside at 60 % stats,"* plus two talents. Nothing in the
sim could represent "a friendly body that exists, moves, and attacks on
its own" before now.

## Decision — a fourth `EntityKind`, deliberately generic

`EntityKind.companion` is a real, new case in the entity-kind enum, not a
flag bolted onto `EntityKind.enemy` or `EntityKind.projectile`. Dart's
own exhaustive-switch checking is what made this safe to add: the only
place that needed a new case at all was `world_painter.dart`'s own
render switch (a plain accent-coloured marker for now — real per-hero art
is presentation work for whenever a kit actually ships); every other
`kind[i] == EntityKind.X.index` guard throughout the codebase already
excludes a companion by construction, with nothing to update. In
particular, `FiringSystem.selectTarget`'s own `kind != enemy` filter
already keeps a companion from ever being auto-targeted by the player,
and no enemy AI in this roster targets anything but the player directly
— a companion is safe from enemy fire with no extra work, the honest
reason Great Hawk's own "taunts" (T5b) is not attempted here (see below).

`CompanionStore` (new) carries only what makes a companion a companion —
`damageShare`, `fireIntervalSeconds`, `attackCooldown`, `remaining`
(lifetime; `double.infinity` for a permanent companion), `alwaysCrit`,
and a follow offset — the same "one struct-of-arrays row per new fact,
not per new entity" shape `ProjectileStore`/`EnemyStore` already use.
Position, radius and health live on the shared `EntityStore` like any
other entity. `CompanionSystem.spawn`/`.update` are generic: nothing in
either file names Zea or Mirelle. `AiContext.playerAttack` is the one
small, additive context field this needed — `SimWorld.playerAttack`
mirrored the same way `playerMaxHealth` already is — so a companion's own
damage share tracks the player's current build live.

## Companion damage is deliberately simple, not routed through `ProjectileSystem`

Every companion card states a bare percentage of ATK or of the player's
own stats, never a number modified by the player's own current Draw
tier, Boon `boonSum`, or pierce falloff. Routing a companion's hit
through `ProjectileSystem`'s own pipeline — built for the player's own
arrow — would silently let it inherit bonuses no card asks for (an
"every arrow explodes" Boon, an elemental arrow's own element) and would
mean threading a new "this is not really the player's own arrow" branch
through the single most shared, most heavily tested function in the
combat pipeline, the exact class of risk this roster has avoided
everywhere else (Bellweather's own rule inversions, The Last Warden's own
damage reduction, all resolved the same way). A companion's own shot
instead resolves *instantly* the moment its own cooldown allows — no
travelling arrow to sweep-collide — through shield, then plate, then
health, the identical order `ProjectileSystem._applyHit` already uses,
with no `boonSum` term at all.

## "Lays Windlines the player can Confluence through" needed no new Confluence logic

A companion's own segment is added under `ownerIndex: 0` — the exact
sentinel every consumer of `WindlineStore.ownerAt` already treats as "the
player's own trail" (`ProjectileSystem`'s own `_playerOwner`, `BoonSystem
.applyWindlineField`, and now this). It is therefore indistinguishable
from a segment the player laid themselves everywhere Confluence already
checks — the same "read the store's own existing owner convention" trick
this roster has reused for every Windline-laying enemy so far (Hollow
Warden's own P2, The Last Warden's own P4).

## What is deliberately not built here

**No hero is actually wired to this yet.** `SimWorld.spawnCompanion` is
a test/tool entry point, the same role every other `spawnX` wrapper in
this roster plays — deciding *when* a companion should exist for a real
Zea or Mirelle run (on loadout apply? on room start, mirroring how
`BossRoomComposer.spawn` places a boss once a room loads?) is a real,
separate integration question, matching the exact "primitive first, wire
the hero-specific numbers next" split `EndlessBossComposer` (ADR 0068)
already drew for its own tier. Building it now would mean guessing at
that lifecycle question rather than answering it deliberately.

**Great Hawk's own "taunts" (T5b) is flagged, not attempted.** Nothing in
this roster has ever redirected enemy targeting away from the player —
every enemy AI targets `ctx.player` directly, never a spatial scan over
candidate targets. A real taunt would need that scan built for the first
time, a materially larger change than the companion primitive itself.

## Verified end to end

Ten tests: a companion spawns as a real, distinctly-kinded entity;
follows the player at its own offset; halts without crashing when the
player is gone; fires on its own cooldown for `playerAttack *
damageShare`, laying a player-owned Windline; holds its cooldown ready
(not overflowing) when no target exists; fires again only once its own
cooldown has actually elapsed; a Bonded-style crit lands only while the
player is at Tier III, at the player's own live crit multiplier; a
finite-lifetime companion despawns on schedule; a permanent one never
does; and `clearRoom` despawns every companion the same way it does
every other entity. All ten passed after one tolerance loosening (a
follow-movement test's own margin was tighter than `Steering.moveToward`
actually closes in the ticks given).

## Consequences

Eleven `pendingHeroBehaviourWork` entries are now buildable in principle
— Zea's whole kit (Skyhawk, Falconry, Sharper Talons, Swift Hawk, Bonded,
Flock, Skydarken, Great Hawk) and Mirelle's own Hall of Mirrors/Endless
Hall/Twin Warden — but none of them are implemented yet. The natural next
part: wire Zea's own passive Skyhawk into a real loadout, answering the
lifecycle question this ADR deliberately left open, then extend to
Falconry and the remaining talents.
