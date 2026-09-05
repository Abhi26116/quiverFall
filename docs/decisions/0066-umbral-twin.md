# ADR 0066 — Umbral Twin: a mechanic that lives outside the sim entirely

**Phase** 11
**Date** 2026-09-05
**Status** Resolved for the sim's own share of this boss. Its actual
differentiating mechanic is presentation work, tracked separately.
**Severity** Low for the sim; the finding itself is the significant part.
**Consequence** All twenty boss archetypes now have some real sim
presence — this closes out Phase 11's own boss roster.

---

## What was missing

docs/06 §6.2, Umbral Twin, *The Long Night*: **"Fights in near-total
darkness; the arena is lit only by the player's own Windlines, so the
depth mechanic becomes the light source. Attacks are audible before
visible — the one fight with genuine audio-first design."**

## Decision — confirmed, not guessed: this card describes rendering and audio, not simulation

Both halves of this card were checked against what they actually name,
not assumed:

- **"The depth mechanic"** is docs/03-progression.md's own term for
  Confluence/Windlines — the section literally titled "Windline, taught
  by accident" ends "**Taught:** the depth mechanic, discovered rather
  than lectured." "The arena is lit only by the player's own Windlines"
  is therefore a *lighting* read of Windline positions the sim already
  tracks in full (`WindlineStore`, unchanged by this fight) — deciding
  which pixels render dark is a decision for whatever draws the arena,
  not a new fact the simulation needs to compute, store, or gate
  anything behind.
- **"Attacks are audible before visible"** is a feedback-sequencing
  question — cueing a sound ahead of a telegraph's own visual
  appearance, not a rule about when damage can land or be dodged.
  `FeedbackDirector`/`FeelTelemetry` already carry an explicit deferred
  no-op for every boss's own phase-transition VFX/audio (Phase 11's own
  opening commit); this is the identical category of work, not a new
  one.

Neither piece has any sim-level consequence a test in this file could
ever observe. `test/guards/architecture_guard_test.dart`'s own "sim
purity" check (`lib/game/sim` imports nothing from Flutter, Flame or
Riverpod) is exactly what makes rendering and audio the wrong layer for
this code to live in, independent of any per-boss judgement call.

## No attack is stated either

The third Event-tier boss in a row — after Bellweather (ADR 0064) and
The Pale Judge (ADR 0065) — whose own card names no attack shape. Three
for three reads as this tier's own consistent design (Event bosses test
reading/adaptation, not raw combat pressure, matching the Elite tier's
own Ashen Choir carrying real combat threat by contrast) rather than
three unrelated omissions. None is invented here either.

## What was actually built

The one thing every boss needs regardless of any of the above: a
correctly-statted (×58 HP, 80s target duration, docs/06's own numbers,
already in `bosses.json`), spawnable, non-attacking body, following the
identical six-step pattern every other boss in this roster uses.
`UmbralTwinSystem.update` is a genuine no-op, the same shape The Pale
Judge's own `update` already established (ADR 0065) for a card with
nothing left for the sim to tick once spawn is done.

## Verified end to end

Three tests: the shipping HP number lands correctly at spawn; `update`
never touches player health across a real run of ticks, confirming no
attack was accidentally invented; and the body never moves and never
crashes across every phase, including with `bossPhase` forced past its
own thresholds. All three passed on the first real attempt.

## Consequences

**All twenty boss archetypes named in docs/06 now have some real sim
presence.** Twelve campaign bosses have a complete P1+P2+P3; Ashen Choir
and Bellweather and The Pale Judge and Umbral Twin (Elite/Event tier) are
each complete for whatever their own card actually asks of the sim; all
four Endless-tier bosses, including The Last Warden's full five phases,
are complete as sim systems. What remains, tracked but not attempted
here: real-run spawn-path integration for Bellweather, The Pale Judge,
Umbral Twin, and the whole Endless tier (the same `EliteRoomComposer`/
floor-depth gaps ADR 0033/0017 already flagged); the actual darkness-
lighting and audio-first presentation work this ADR identifies as
belonging outside `lib/game/sim` entirely; bespoke boss arenas/entrance/
music for the whole roster; and the handful of already-flagged deferred
sub-mechanics within already-shipped fights (Vermillion's Frost-
extinguish, the Weeping Gate's 40s survival timer, Arclight's
Confluence-chain bonus, The Last Warden's own sudden-death timeout).
