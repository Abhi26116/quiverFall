# ADR 0083 — Bram's whole kit: a new player-owned telegraph primitive, plus two splash riders

**Phase** 10 (hero behaviours)
**Date** 2026-09-05
**Status** Resolved. Bram is the twelfth hero with nothing deferred.
**Severity** Medium-high. *Mortar Rain* is the first player-owned entry
into `TelegraphStore` — every telegraph before this one belonged to an
enemy or a boss — but it stays a thin, self-contained addition: no shared
system was edited to make room for it.

---

## Gap 1 — Concussion needed a way to ask "is this enemy Rush family?" from the hit loop

docs/07 §2, T3a: **"Concussion: splash staggers Rush enemies."** No
duration is given, and nothing in `ProjectileSystem` — which resolves
Heavy Ordnance's own splash — had a way to ask an enemy's family without a
content-table lookup on the hottest path in the game.

**Decision — denormalise `rush` onto `EnemyStore` exactly the way `elite`
already is.** `elite[slot]` is set once at spawn from
`def.family == EnemyFamily.riftborn` specifically so *Cull* (#20) can ask
"is this an elite?" on every hit without a `ContentLibrary` lookup;
`EnemyStore.rush` (and `isRush`) is the identical pattern for
`EnemyFamily.rush`, set in the same `EnemySpawner.spawn` line. The stagger
itself reuses Rook's own Anchor duration (`_rookAnchorDuration`, 0.6 s) —
the same short, already-balanced root — through the identical
`StatusStore.frozenRemaining` hard-stop every other non-elemental CC in
`ProjectileSystem` already borrows from Frost, "never shortens a longer
effect already running" included.

## Gap 2 — Incendiary's "40 %" is a per-arrow roll, not a per-enemy one

docs/07 §2, T3b: **"Incendiary: splash applies Burn at 40 %."** "40 %"
reads as a chance, matching how every other percentage-chance card in this
game (Reflection's own duplicate chance, a crit) already resolves.

**Decision — rolled once per arrow, at release, exactly like Crit.** The
crit roll's own doc comment states the reasoning outright: "an RNG call
belongs at the bow, never inside the hit loop" — rolling per splash-caught
enemy instead would put an RNG call inside `_applyBramSplash`'s own loop
over however many enemies one blast catches, and would make one arrow's
splash inconsistently igniting some victims and not others read as a bug
rather than a proc. `ProjectileStore.willIgniteSplash` is the tag,
`SimWorld._applyBramIncendiary` the roll (its own seeded `Rng` stream, the
same isolation every chance-based hero effect already gets) — one Boolean
decided before flight, read by every enemy that one arrow's splash
catches.

## Gap 3 — Mortar Rain needed a genuinely new primitive

docs/07 §2, the Ultimate: **"Mortar Rain: 12 shells over 3 s across the
arena, each 130 %, amber-telegraphed."** T5: *Saturation* (20 shells) /
*Precision Strike* (4 shells, 500 %, boss-seeking). Nothing before this
hero has asked the sim for a player-triggered, telegraphed, delayed AoE —
every existing `TelegraphStore` entry and every `HazardStore`/
`HazardSystem` resolution path is built to warn about and then damage the
*player*, from an enemy-owned attack.

**Decision — a small, self-contained shell array on `HeroRuntime`, not an
extension of `HazardStore`.** Reusing `HazardStore`/`HazardSystem` would
have meant either teaching that pipeline a new "friendly fire, backwards"
direction or forking it — both bigger and riskier than the alternative:
`HeroRuntime.bramShellRemaining/X/Y` (sized 20, the largest branch,
mirroring `latticeLines`' own "one array-shaped bundle, sized for the
biggest variant" shape) plus a telegraph `(slot, serial)` pair per shell.
`SimWorld._fireBramMortarRain` claims a `TelegraphStore.add` warning ring
for every shell **at cast time, all at once** — the player reads the whole
coming bombardment as one pattern rather than a series of surprises — and
`_tickBramMortarRain` resolves each one independently as its own countdown
reaches zero, through `_detonateAt`: the exact flat-AoE-at-an-arbitrary-
point primitive Rook's own Singularity detonation already established, so
Mortar Rain needed zero new damage-application code, only the timing
scaffold around calling it 12 (or 20, or 4) times instead of once.

**Scatter geometry is uniform-random across the whole arena.** Docs/07
says only "across the arena," nothing about targeting or clustering, so
this is the literal reading — `Arena.width` × `Arena.height`, its own
seeded `Rng` stream (`_bramShellRng`) so adding this hero's own rolls
never perturbs any other seeded sequence. Impact radius reuses
`ProjectileSystem._bramSplashRadius` (1.6 u) — Bram's own already-
established blast size — rather than inventing a second number for the
same idea; *Wider Blast*/*Denser Blast* do not touch it, since those
modify Heavy Ordnance's own splash, a different ability from the
Ultimate.

**Each shell's own delay staggers evenly across the 3 s window**
(`(i + 1) / count * 3.0`), so shell 1 of 12 lands at 0.25 s and shell 12 at
3.0 s — "12 shells over 3 s" read as a spread, not a simultaneous volley.

**Precision Strike's "boss-seeking" targets the live boss if one exists,
falling back to the nearest enemy** — the same "an Ultimate that fizzled
because nothing was in range would feel like the button ate the charge for
nothing" reasoning `_fireWrenVolleyFan`'s own comment already gives for a
different Ultimate. All 4 shells converge on that one point rather than
spreading — "seeking" reads as aimed, not scattered — so a target that
holds still under all 4 takes the full 2,000 %.

**A room boundary or a mid-run loadout swap simply zeroes
`HeroRuntime.bramShellCount`**, the same "clears only what a room boundary
resets" shape `HeroRuntime.beginRoom` already uses for Singularity's own
wells — without proactively releasing any telegraph still live from an
in-flight cast. A stray warning ring outliving its own cancelled shell by
at most 3 s is a cosmetic edge case (no damage, no danger) far narrower
than building a cross-reset telegraph-release path for it, and
`TelegraphStore.expire` cleans it up on its own regardless.

## Verified end to end

Five new Heavy-Ordnance-splash tests (Concussion staggers a Rush enemy
caught in splash and never a non-Rush one; without the talent, splash
never staggers even a Rush enemy; Incendiary applies Burn within a bounded
number of hits at the documented 40 %; without it, splash never ignites).
Seven new Mortar Rain tests: the base cast claims 12 owned, amber, circular
telegraphs; an isolated shell (the rest suppressed, so a second shell can
never land on the same point by chance and inflate the reading) deals
exactly 130 % in its own radius and nothing beyond it; every shell resolves
and releases its telegraph inside the 3 s window; Saturation casts 20;
Precision Strike aims all 4 at a boss set up the same way ADR 0069's own
Halden tests fake one (`bossIndex` set directly on an ordinary enemy via
`bossContent`), for a verified 2,000 % total, and falls back to the nearest
enemy with no boss present.

## Consequences

`pendingHeroBehaviourWork` drops to 4: Sela's own *Lingering Frost* (needs
a slow-zone primitive independent of Windlines), Torv's *Conductive Lines*
(needs Windline-travel-along indexing), Nyx's *Twin Step* (needs the
shared single-charge Ultimate meter restructured — an unanswered design
question, not merely unbuilt), and Oriel's own *White Light* (blocked on
the same missing elemental/reaction damage-bonus wiring as *Attuned* and
*Resonance*).
