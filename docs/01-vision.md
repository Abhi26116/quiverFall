# 01 — Game Vision

## 1.1 Core gameplay loop

### The second-to-second loop (combat)

```
threat appears  →  reposition (Momentum builds)  →  root  →  Draw ramps I→II→III
      →  fire through your own Windline  →  Confluence detonates  →  threat dies
      →  new threat appears
```

This is the loop the player physically feels. It runs at roughly a 2–4 second cadence and it is
the whole game. Everything else is scaffolding around it.

**Movement.** Left-thumb virtual joystick, free 8-way analogue movement, no grid. Character
never stops attacking *entirely* — but attacking is tiered.

**The Draw (original core mechanic).** The bow winds while the player is stationary:

| Tier | Stationary time | Damage | Fire rate | Extra |
|---|---|---|---|---|
| I | 0.00 – 0.45 s | 100 % | 2.2 /s | — |
| II | 0.45 – 1.10 s | 145 % | 2.0 /s | +1 pierce |
| III | 1.10 s + | 210 % | 1.7 /s | +2 pierce, guaranteed element proc, arrow hitbox ×1.5 |

Moving drops you to Tier I immediately. Critically, **moving is not a punishment** — it builds
**Momentum**:

| Momentum stacks | Gained | Effect | Decay |
|---|---|---|---|
| 0 → 5 | +1 per 0.35 s moving | +3 % move speed, +2 % damage reduction, each | all stacks lost 0.6 s after stopping |

So the player is always choosing between two *good* states, not between a good and a bad one.
Rooting is offence; moving is defence and mobility. The rhythm of a skilled player is a constant
oscillation, and reading enemy telegraphs tells you which side of the trade to be on. This is the
single most important difference from Archero, where standing still is simply correct and moving
is simply a loss.

**Windline + Confluence (original depth layer).** Every arrow leaves a translucent trail along its
flight path that persists **1.2 s** (hero- and Boon-modifiable). Effects:

- **On enemies:** an enemy crossing a live Windline takes 8 % move-speed slow (does not stack).
- **On your own arrows:** a new arrow whose path intersects a live Windline segment gains a
  **Confluence** stack.

| Confluence stacks | Damage | Visual |
|---|---|---|
| 1 | +40 % | Arrow gains a white-hot core |
| 2 | +90 % | Arrow doubles in width, sparks shed |
| 3 (max) | +160 %, +1 pierce | Arrow becomes a lance, screen-shake on impact |

Confluence rewards *aiming discipline and positioning*, not reflex speed — which makes it
readable on a phone and learnable over weeks. A newcomer never notices it. A 40-hour player
builds their whole positioning around laying lattices. It is the skill ceiling.

**Elements.** Four: **Ember** (burn DoT), **Frost** (chill → freeze at 100 stacks), **Storm**
(chain), **Toxin** (stacking poison, scales off enemy max HP). Confluence *merges* elements —
threading a Frost arrow through an Ember Windline produces **Steamburst** (AoE + 20 % defence
shred). Full reaction matrix in [08-arrows.md](08-arrows.md).

### The run loop (3–7 minutes)

```
Stage select → Room 1 (combat) → Boon choice (1 of 3) → Room 2 → Boon
→ Room 3 → Elite room → Boon (upgraded pool) → Room 4 → Shrine (spend gold mid-run)
→ Room 5 → Boss → Rewards screen → Spire
```

A stage is **6 rooms + 1 boss** at chapter start, growing to **10 + boss** by chapter 12.
Rooms are single-screen arenas — no scrolling, no camera hunting. The whole fight is visible.

Death is permanent for that run. You keep gold, materials, and stage progress up to your
furthest cleared room; you lose all Boons.

### The meta loop (session, 12–25 minutes)

```
Spend Vigor on runs → bank Gold / Shards / Insight
→ upgrade The Spire (permanent stats) → level the hero → craft arrows
→ Vigor empty → daily quests done → out
```

### The long loop (weeks)

```
Clear chapters → unlock heroes → max Spire wing → hit the Ascension gate
→ Ascend (reset Spire levels, keep heroes, gain Emberdust)
→ Emberdust buys permanent multipliers → clear chapters faster → repeat
```

## 1.2 Target audience

**Primary — "The Commuter Optimiser." 24–38, 60/40 male/female skew, mobile-first.**
Plays in 10–20 minute blocks, 2–3 blocks a day. Has played Archero, Survivor.io, Soul Knight,
Vampire Survivors, or Hades. Wants a build to think about, not a story to read. Will pay $5–20 a
month if it feels fair; will uninstall instantly over an interstitial that interrupts a run.

**Secondary — "The Theorycrafter." 18–30.** Reads spreadsheets, posts builds, drives the wiki
and Discord. Small in number, enormous in influence on retention of the primary group. Served
by Confluence depth, synergy sets, and the Research Lab.

**Tertiary — "The Casual Snacker." 30–55.** One run at a time, may never learn Confluence.
Must be able to clear chapters 1–6 purely on meta-progression and reflexes. Served by generous
auto-aim assist and the fact that Tier-III Draw alone is a viable strategy.

**Regions.** Launch: US, CA, UK, AU, DE, FR, BR, MX. Wave 2: JP, KR, TW, SEA. Design is
text-light and icon-heavy specifically so localisation is cheap (see [15](15-art-direction.md)).

## 1.3 Art style

**"Luminous ink."** Hand-inked silhouettes with bold, weighty outlines over flat colour, lit
entirely by emissive VFX. Think a woodblock print struck by lightning.

- **Characters and enemies:** strong readable silhouettes, 2–4 flat colour zones, thick dark
  outline. No rendered gradients on units — all depth comes from lighting.
- **Environments:** desaturated, low-contrast, cool. Backgrounds are *stage*, never *noise*.
  Arena floor is deliberately dim so arrows and telegraphs pop.
- **VFX:** the entire colour budget. Arrows, Windlines, Confluence, elemental procs and boss
  telegraphs own saturated colour. Nothing else in the frame competes.
- **Palette discipline:** every enemy telegraph is **amber**; every player-beneficial pickup is
  **cyan**; every lethal zone is **crimson**. Learned in 30 seconds, never violated. This is an
  accessibility decision as much as an art one — plus a colour-blind mode that swaps hue cues
  for shape cues (see [10](10-ui-ux.md)).
- **Resolution:** authored at 4× for a 1080p-tall reference; sprite atlases at 2048².

Why this style: it is (a) cheap to produce consistently, (b) extremely readable on a 5.5" screen
in daylight, (c) cheap to render — flat fills and additive particles, no per-pixel lighting —
which directly serves the 60 FPS law, and (d) it does not look like anything else in the
category, which is a store-listing advantage.

## 1.4 Unique Selling Points

**USP 1 — The Draw / Momentum trade.** Both movement states are rewarded. The genre's defining
awkwardness (standing still is correct, so the game is about *not moving*) is inverted into a
live tactical decision every two seconds.

**USP 2 — Windline & Confluence.** A genuine mechanical skill ceiling in a genre that has almost
none. Your own past shots are a resource on the battlefield. No competitor has this.

**USP 3 — Elemental merging through Confluence.** Reactions are produced by *player aim*, not by
passively stacking two elemental items. Build-crafting becomes an execution problem.

**USP 4 — The Shrine.** A mid-run gold sink that makes in-run currency matter *this run* rather
than being a post-run trickle. Creates a real "push or bank" decision.

**USP 5 — Honest economy.** No energy-gate paywall on progression, no gacha for raw power,
no mid-run ads. Marketed explicitly. In a category defined by predatory pacing this is a
positioning wedge, not just ethics.

## 1.5 Competitive analysis

| | Archero | Survivor.io | Vampire Survivors (mobile) | Soul Knight | **Quiverfall** |
|---|---|---|---|---|---|
| Core input | Move-to-stop, auto-fire | Move only, full auto | Move only, full auto | Twin-stick | Move + **Draw tiers** |
| Skill ceiling | Low (positioning only) | Low–mid | Low | Mid (aim) | **High (Confluence lattice)** |
| Run length | 4–8 min | 15 min | 30 min | 10 min | **3–7 min** |
| Session fit | Good | Poor (long runs) | Poor | Mid | **Excellent** |
| Meta depth | High | High | Low | Mid | **High** |
| Monetisation | Aggressive; energy wall | Aggressive; battle pass heavy | Premium + DLC | Mild | **Moderate, transparent** |
| Art | Cartoon 3D | Cartoon 3D | Pixel | Pixel | **Inked 2D + emissive** |
| Biggest weakness | Repetition, RNG walls | Run length vs mobile session | No meta hook | Thin meta | *Unproven mechanic* |

**Where we win.** Session length exactly matches how phones are actually used (3–7 min). A
mechanic with a real ceiling gives the game a reason to be discussed, which is how this category
grows — Archero has no "clip-worthy" moment; a triple-Confluence lance through six enemies is one.

**Where we are at risk.** Confluence is unproven and could read as noise on a small screen.
Mitigation: it is entirely optional for chapters 1–6, is taught through a dedicated tutorial
room, has a distinct audio signature, and its visual is tuned in a dedicated playtest phase
(Phase 6). If it fails testing, the game is still a solid Draw/Momentum roguelite — the mechanic
is additive, not load-bearing.

**Where we must not lose.** Feel. This category is won on hit-feedback, not features. Phase 6 is
reserved entirely for game feel and is not compressible.

## 1.6 Why players keep playing

Six independent hooks, deliberately on different clocks so a lapse in one doesn't end the session:

1. **Mastery (minutes).** Confluence execution measurably improves for ~40 hours.
2. **Build variety (per run).** 112 Boons, 20 heroes, 12 arrow types → no two runs identical.
3. **Permanent progress (daily).** Every run banks something. There is no wasted run — even a
   room-1 death returns gold, and the failure screen shows exactly what was earned.
4. **The next unlock (weekly).** Hero unlocks and Spire wings are paced so something opens
   roughly every 2–3 days for the first month.
5. **Ascension (monthly).** The prestige reset re-opens the whole power curve with a multiplier,
   converting a solved game back into an unsolved one.
6. **Events and leaderboards (seasonal).** Weekly rotating modifier runs with their own ladder.

**The retention thesis in one line:** short sessions with a high skill ceiling and an honest
economy produce a player who returns because they *want to get better*, not because a timer
told them to. Every system in this document is subordinate to that sentence.
