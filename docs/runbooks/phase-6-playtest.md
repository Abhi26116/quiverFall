# Runbook — the Phase 6 game-feel gate

**Status** Ready to run. The build is done; the gate is not.
**Owner** You. This is the one Phase 6 deliverable that cannot be written.

---

## What this is

The roadmap is explicit that Phase 6 ends in **a decision gate, not a
checklist**:

> Playtest with 8+ people who have not seen the game. Measure: does the median
> tester trigger Confluence within 7 minutes unprompted? Does
> `draw_tier_distribution` show real Tier II/III usage? **If Confluence reads as
> noise, we redesign now**, having spent ~35 days instead of 200.

Everything the code can do to prepare for that is done. What follows is how to
actually run it, because a gate measured casually is a gate that passes for the
wrong reasons.

## Before the session

1. `flutter run --release` on a real phone. **Not the simulator and not a debug
   build** — game feel is frame timing, and a debug build lies about it. If you
   only have one device, use it; if you have a weak Android, prefer it.
2. Confirm the arena loads from the main menu (`/game`).
3. Confirm the telemetry overlay is visible in the top-left. It is on by default
   (`GameScreen.showTelemetry`).
4. Charge the phone. Thermal throttling on a hot phone is itself a finding, but
   not one you want mixed into this measurement.

## What to say to each tester

Say exactly this, and nothing else:

> "This is an archer game. Move with your left thumb. It shoots by itself.
> Play for ten minutes."

**Do not** explain the Draw. **Do not** mention Windlines, Confluence, or that
standing still does anything. The entire question is whether the game teaches
those things without you. Every hint you give is a data point destroyed.

If a tester asks a direct question, answer only after the session.

## What to record, per tester

Read these off the overlay when they stop. The Exit button also prints the same
summary to the log.

| Field | Where from | Why it matters |
|---|---|---|
| Time to first Confluence | overlay, `first` | **The primary gate.** Target: under 7 minutes, unprompted. |
| Draw tier split | overlay, `draw I / II / III` | The secondary gate. Tier II+III should be ≥ 20 % of session time. |
| Confluence count and rate | overlay, `confluence N ... /min` | Distinguishes "found it once by accident" from "started doing it on purpose". |
| Moving share | overlay, `moving %` | A tester at ~100 % has not discovered the trade at all. |
| Deaths, rooms | overlay | Context. A tester dying constantly is measuring difficulty, not feel. |

And **write down, in their words**:

- The moment they first *noticed* the trails. Not triggered — noticed.
- Whether they ever said anything like "wait, what did I just do?"
- Anything they said about the character feeling slow, sticky, or unresponsive.

## Reading the result

**Pass.** Median time-to-first-Confluence under 7 minutes, and Tier II+III above
20 %. Proceed to Phase 7.

**Partial — reachable but not legible.** They trigger it, but never notice they
did, and the rate never rises across the session. This is the ADR 0002 residual
risk: reachability is solved, legibility is not. Fixes are cheap and are all in
`lib/game/feel/juice.dart` — a bigger burst, a longer freeze, a brighter arrow.
Re-run with 4 people before committing to anything larger.

**Fail — reads as noise.** They trigger it and it makes the screen harder to
read. This is the outcome the phase exists to catch. docs/01 §1.5's fallback
applies: the game remains a solid Draw/Momentum roguelite and the mechanic is
cut. Better to know now than at month eight.

**Fail — Tier II/III unused.** Nobody stands still. This is *not* a Confluence
problem; it is a Rush-family tuning problem, and it lives in
`assets/data/enemies.json`, not in the feel layer. Enemies are pressuring the
player out of the Draw faster than the Draw pays for itself.

## Known gaps that will affect the session

Be honest with yourself about these when reading the results.

- **There is no sound.** Not muted — absent. docs/16 makes the Confluence bell
  chord the single most important sound in the game, and it is exactly the
  channel that tells a player they threaded a shot while their thumb is over
  the crossing. A tester who never notices Confluence *may* be telling you the
  VFX are insufficient, or may just be missing half the feedback stack. The
  audio port and the full cue catalogue are wired
  (`lib/services/audio/audio_port.dart`); only the files are missing.
- **The art is greybox.** That is by design for everything except the Windline
  and Confluence VFX, which ship near-final precisely so this session measures
  the real thing.
- **One room, no progression.** No Boons, no ultimate, no room-to-room flow.
  Testers will get bored around ten minutes; that is expected and is not a
  finding.
- **Joystick reversal costs up to two deflection-widths** of thumb travel,
  because the origin trails the thumb. If several testers say the character is
  slow to turn around, that is the cause, and it is a one-constant change
  (`Juice.joystickOriginFollows`).

## After the gate

Whatever the verdict, write it up as `docs/decisions/0004-game-feel-gate.md`
with the raw per-tester numbers. The decision that matters most in this project
is the one this session produces, and in six months nobody will remember the
numbers unless they are written down.
