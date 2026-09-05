# ADR 0065 — The Pale Judge: immunity for free, from an existing primitive

**Phase** 11
**Date** 2026-09-05
**Status** Resolved. The Pale Judge (docs/06 §6.2, Event boss #16) is
fully built — the fifteenth boss in the roster.
**Severity** Low. The smallest real boss build this whole session — a
card that reads as needing a new mechanic turned out to need none.

---

## What was missing

docs/06 §6.2, The Pale Judge, *Assize*: **"Reads the player's build at
fight start and gains a matching immunity — an Ember build faces a
fire-immune Judge. Explicitly designed to punish mono-builds and to sell
the second loadout slot honestly."** No attack of its own is described.

## Decision — `EnemyStore.adaptTo`, the Voidtouched's own primitive, reused verbatim

`EnemyStore.adaptTo`'s own doc comment already named this exact shape:
*"a duration of zero clears any adaptation — the Voidtouched variant
passes `double.infinity` once at spawn and is never touched again."* The
Voidtouched (docs/05 §5.6) is a permanently element-immune enemy built
the identical way; the only difference here is which element gets passed
in is read from the player's own current build rather than fixed at
content-authoring time. `resistsElement` — already the single choke
point `ProjectileSystem._applyOneElement` checks before applying any
Burn/Frost/Toxin/Storm status, for both arrow-carried elements and
hero-innate ones — needed no changes at all. This is a third instance
this session of a card that reads as a brand-new mechanic needing no new
one (after Rimefather's decoy mirrors and Hollow Warden's Discord),
found by reading the target primitive's own doc comment before assuming
anything needed building.

## "The player's build" means what the sim already means by it

Read at spawn time, not live from `AiContext` each tick — matching "at
fight start" literally, and the same "the real work is the caller's job"
split The Last Warden's own `echoArchetypes` parameter already
established (ADR 0061): `PaleJudgeSystem.spawn` takes an already-resolved
`playerElement`, and `SimWorld.spawnPaleJudge` supplies it from
`boons.attunedElement ?? arrowElement` — the identical priority
`SimWorld._arrowElementIndex` already uses to decide what a fired arrow's
own element is. A player carrying no element at all faces a Judge immune
to nothing — an honest degrade, not a guessed default.

## No attack of its own is invented

The card describes no attack shape, the same silence Bellweather's own
card left (ADR 0064). Rather than invent one, this follows the identical
posture: the immunity itself is the entire fight. `PaleJudgeSystem.
update` exists for consistency with every other boss in this roster's own
six-step pattern, but its body is a genuine no-op — the whole mechanic
already happened once, at spawn.

## Verified end to end

Eight tests: a null build grants no immunity to any of the four elements;
a real build's own element is matched exactly, and only that one; an
attuned Boon takes priority over the equipped arrow, the identical rule
the sim itself already uses for a fired shot; the immunity survives a
long fight unmodified; a fired arrow carrying the immune element never
triggers `elementApplied` against it, end to end through the real firing
pipeline; the same fight, switching to a *different* element after spawn,
applies it normally — proving the immunity is locked at spawn and does
not update after the fact; and `update` never touches player health.
One test-writing lesson caught mid-build, not a sim bug: an early draft
of the "applies normally" test set `arrowElement` to the *same* element
before spawning and expected it to land — of course it didn't, since that
is exactly the immunity working as designed; fixed by firing a genuinely
different element after spawn instead. All eight passed once corrected.

## Consequences

Fifteen of the twenty boss archetypes now have a real, built fight. Only
Umbral Twin (#14) remains among the Elite/Event tier — its own card is
almost entirely a presentation/lighting concern the pure sim layer has no
natural hook for, the hardest of the sixteen non-Endless bosses to give
real sim mechanics to. The Pale Judge has no real-run spawn path yet, the
same gap Ashen Choir had before its own integration (ADR 0055) —
`EliteRoomComposer`'s own map is the entire remaining cost.
