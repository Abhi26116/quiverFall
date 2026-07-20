# 14 — Level Design System

## 14.0 The hybrid model

Neither pure-handcrafted (too expensive for 240 stages) nor pure-procedural (too soulless, and
the genre's most common failure). Quiverfall uses **handcrafted arenas assembled procedurally**:

- **Arenas are authored.** ~60 hand-designed layouts — geometry, cover, spawn points, sight
  lines. A human decides where the walls are, because wall placement is what makes Corvin's
  ricochet and Iris's lattice interesting.
- **Encounters are generated.** Which enemies, how many, when they arrive, and in what waves —
  chosen by a seeded, constrained generator against a threat budget.
- **Stage structure is templated.** Room count, elite placement, Shrine and boss position come
  from a per-chapter template.

So every room *looks* designed (because it is), while every run *plays* differently (because the
encounter is not). This is the same split that makes Hades and Dead Cells work, and it is
affordable for a small team.

## 14.1 Handcrafted layer

### Arenas

Every arena is a **16 × 9 unit single screen**. No scrolling, no camera hunting, the whole fight
visible at once. Authored in a Tiled-style JSON (`arenas.json`) with:

| Field | Purpose |
|---|---|
| `bounds`, `walls[]` | Collision geometry, and the ricochet surfaces |
| `cover[]` | Blocks projectiles but not movement — the Longeye counter |
| `spawnPoints[]` | Tagged `edge` / `interior` / `elite`, each with a family whitelist |
| `playerStart` | Always ≥ 4 u from every spawn point |
| `hazards[]` | Static lethal geometry (crimson), used sparingly |
| `latticeHints` | Designer-marked wall pairs that make good Confluence geometry |
| `tags` | `open` / `enclosed` / `corridor` / `pillared` / `arena` |

**~60 arenas**, distributed 4–6 per chapter with cross-chapter reuse under different lighting and
tint — a chapter-9 arena reskinned reads as new for a fraction of the cost.

**The `latticeHints` field is the most important authored data in the game.** It is how a level
designer says "this room rewards Windline play", and the generator uses it to weight arena
selection toward lattice-friendly geometry in chapters 5+ as the player learns the mechanic.

### Fully handcrafted content

Some things are never generated:

- **The 8 tutorial rooms** (chapter 1, stages 1–2) — every spawn scripted to the beat sheet in
  [03 §3.1](03-progression.md).
- **All 20 boss arenas** — bespoke geometry per fight, built around that boss's mechanics.
- **The first room of every chapter** — an authored "here is what this chapter is about" statement.
- **Every Elite room's arena** — elites need guaranteed space.
- **Event arenas.**

Roughly **70 handcrafted rooms** in total. Everything else is assembled.

## 14.2 Procedural layer

### Stage template

```
Chapter c, stage s  →  StageBlueprint

rooms      = 6 + floor(c / 3)                      // 6 at ch.1, 10 at ch.12
elite      = at room ceil(rooms * 0.6)             // from chapter 3
shrine     = after room 4                          // from chapter 2
boss       = stage 20 only
seed       = hash(playerId, chapter, stage, attemptSalt)
```

`attemptSalt` changes per attempt so a retry is a *different* run, not the same one again. This
matters enormously: replaying an identical failed room is demoralising; replaying a fresh version
of the same *challenge* is a second chance.

### Room generation

```
1. Pick arena       — weighted by chapter tag pool, excluding the last 2 used,
                      biased toward latticeHints from chapter 5+
2. Compute budget   — TB = 100 · 1.04^(G−1)          (G = global stage index)
3. Fill budget      — draw enemies from the chapter's unlocked roster by threat cost,
                      subject to the composition rules in 05 §5.7
4. Assign waves     — 1–3 waves; wave 2 at 60% cleared, wave 3 at 30%
5. Place spawns     — respecting family whitelists and the 3.5u player-distance rule
6. Validate         — reject and reroll if any constraint fails (max 8 attempts,
                      then fall back to a known-good authored encounter)
```

**Step 6 is why this is safe.** The generator is allowed to fail; it is not allowed to ship a bad
room. Every blueprint is validated before the room loads, and a validated fallback always exists.

### Validation constraints

A generated room is rejected if any of these are true:

- More than 2 Choir units.
- No Drift or Rush enemies (nothing safe to shoot).
- Drift + Rush share less than 40 % of the threat budget.
- Screecher and Longeye co-present before chapter 8.
- Any spawn point within 3.5 u of `playerStart`.
- Estimated clear time outside 18–55 s at expected power (from the balance harness's model).
- More than 60 % of the budget in a single enemy type (monotony check).
- Total simultaneous entity count would exceed 90 (performance ceiling).

## 14.3 Difficulty balancing

**The single governing invariant** is the TTK Law: a common enemy dies in 0.8–1.6 s at expected
power, everywhere in the game. Difficulty is *not* delivered by HP inflation. It is delivered by:

| Lever | How it scales |
|---|---|
| **Enemy variety** | 4 new types per chapter through chapter 8, then Variants |
| **Composition complexity** | More families per room; Choir units appear from chapter 2 |
| **Threat density** | `TB = 100 · 1.04^(G−1)` — more enemies, not tougher ones |
| **Room count** | 6 → 10 rooms, so runs demand sustained execution |
| **Mechanical demands** | Chapter 3 needs flanking; 6 needs element rotation; 9 needs target priority |
| **Arena pressure** | Later chapters favour enclosed and pillared arenas with less safe space |

**Difficulty spikes are placed deliberately**, not emergently: stage 20 (boss) of every chapter,
plus a designed wall at chapters 5, 8, and 11. A wall is where a player is expected to stop and
upgrade — and the game says so explicitly, on the defeat screen, with a specific suggestion.

**Anti-frustration, all measured:**
- 3 consecutive failures on a stage → next attempt grants a free Boon reroll and reveals the room
  contents.
- 5 consecutive failures → the stage's threat budget drops 8 % for that player until they clear
  it, silently. This is invisible mercy, and it exists because a churned player learns nothing.
- **First attempt at a new stage always costs 0 Vigor** ([02 §2.2](02-economy.md)).

## 14.4 Spawn balancing

**Wave pacing.** Enemies never all appear at once. Wave 1 is ~55 % of the budget, wave 2 ~30 %,
wave 3 ~15 %. Waves trigger on remaining-enemy thresholds, not timers, so a fast player is
rewarded with a faster room rather than made to wait.

**Spawn telegraphing.** Every off-screen spawn gets a 0.4 s edge-flash at the exact spawn
position. Nothing ever appears behind the player without warning. This is a hard rule; a
generated room that would violate it is rejected in validation.

**Family placement rules:**
- Salvo units spawn at range and at the arena's edges — never inside the player's engagement ring.
- Rush units spawn at mid-distance so their approach is readable.
- Choir units spawn *behind* their pack, which is also what makes them visually identifiable as
  the priority target.
- Riftborn (elites) spawn centrally with a 1.2 s entry animation and a musical stinger.

**Density cap.** Never more than 90 simultaneous entities (performance, [19](19-performance.md)),
and never more than 24 enemies capable of dealing contact damage — beyond that a mobile screen is
unreadable regardless of frame rate.

## 14.5 Boss frequency

| Content | Boss cadence |
|---|---|
| Campaign | 1 per chapter (stage 20) — 12 total |
| Elites | 1 per stage from chapter 3 (mid-stage Riftborn room) |
| Mini-boss | Every 5th stage from chapter 3 |
| Events | 1 event boss per week |
| Endless Descent | 1 per 10 floors |

An engaged player meets a proper boss roughly **every 9 minutes** and an elite every ~4. Frequent
enough to be the rhythm of the game; rare enough that the stinger still raises a pulse.

## 14.6 Reward balancing per room

Room payout weights within a stage (summing to the stage's `gold(c,s)`):

| Room type | Gold share | Material chance | Notes |
|---|---|---|---|
| Normal | 8–12 % each | Base | |
| Elite | 22 % | ×2.5 | Plus guaranteed T(n) material |
| Shrine | — | — | A **sink**, not a source |
| Boss | 30 % | ×4 | Plus gems and Insight on first kill |

**Partial credit is mandatory.** A run that dies in room 5 of 8 banks
`Σ(cleared room shares) × 0.7`. The 0.7 factor is the only "loss" for dying, and it is small on
purpose — see [10 §10.9](10-ui-ux.md).

## 14.7 Endless Descent

Unlocked after Ascension 1. The terminal content, and the answer to "I finished the game".

- Infinite floors. `HP × 1.09^floor`, `TB × 1.05^floor`.
- **Weekly global seed** — every player descends the identical sequence, which makes the ladder a
  fair comparison and turns the week into a shared conversation about one specific run.
- Boss every 10 floors (bosses 17–20, cycling).
- Every 5 floors: choose one of three **Descent Modifiers** — permanent for that run, escalating
  risk for escalating reward (e.g. *enemies +30 % speed, gold ×1.4*).
- No Vigor cost. No revives. One life, one seed, one ladder.
- Rewards scale with depth and pay Emberdust past floor 30, which links the terminal content back
  into the prestige loop rather than leaving it as a dead-end score attack.

## 14.8 Event level design

One major event per week, each a **rule mutation** rather than new content — this is what makes
weekly events affordable to run indefinitely.

| Event | Mutation |
|---|---|
| **The Long Night** | Arena unlit; Windlines are the only light source |
| **Tollings** | A bell inverts one rule every 10 s |
| **Assize** | Enemies gain immunity to your dominant element |
| **Glasswork** | You and every enemy die in one hit |
| **The Deluge** | 3× enemy count, 3× gold, 0.5× enemy HP |
| **Stillwater** | Movement is disabled; pure Draw and positioning-by-aim |
| **The Weaver's Trial** | Damage is dealt *only* by Confluence — the mechanic as the whole game |

Each reuses existing arenas, enemies, and bosses with modified rules, so an event costs a
designer days rather than weeks. **Stillwater and The Weaver's Trial exist specifically to teach**
— an event that forces mastery of one half of the core mechanic is the best tutorial we can build,
and players opt into it for rewards.

## 14.9 Authoring pipeline

1. Designer builds an arena in a Tiled-compatible editor → exports JSON.
2. A CI script validates geometry (reachability, spawn distance, no sealed regions) and computes
   `latticeHints` candidates automatically for the designer to confirm.
3. The arena enters the chapter pool via `chapters.json`.
4. The balance harness runs 2,000 seeded runs including the new arena and reports clear-time and
   death-location distributions.
5. Any arena whose death rate deviates more than ±35 % from the chapter median is flagged for
   review before it ships.

Level design is thereby **measured, not guessed** — which is the only way 240 stages stay
balanced with a small team.
