# 09 — Skill System (Boons)

**112 in-run Boons.** Offered 3 at a time (4 with *Mark of the Ninefold*, 5 with *Curator*) after
every room clear. A full run offers 7–11 choices, so a player sees ~30 of 112 per run.

## 9.1 Rarity, weights, and probability

| Rarity | Count | Base weight | Colour | Max copies |
|---|---|---|---|---|
| Common | 46 | 58 % | Slate | 3–5 |
| Rare | 34 | 27 % | Cyan | 2–3 |
| Epic | 20 | 11 % | Violet | 1–2 |
| Legendary | 9 | 3.5 % | Gold | 1 |
| Mythic | 3 | 0.5 % | White-hot | 1 |

**Depth scaling.** Weights shift with room index `r` (1-based) within a stage:

```
w_rare      = 0.27 + 0.018·(r−1)
w_epic      = 0.11 + 0.014·(r−1)
w_legendary = 0.035 + 0.006·(r−1)
w_mythic    = 0.005 + 0.0015·(r−1)
w_common    = 1 − (the above)
```

At room 1 the draw is 58 % Common; by room 9 it is ~35 % Common and ~19 % Epic. Runs therefore
*escalate* — the build gets loud near the end, which is where the power fantasy belongs.

**Modifiers:** Spire node 21 *Boon Insight* (+up to 32 % Rare+ weight), Elite room clears
(+40 % Rare+ for the next draw only), Shrine purchase (guaranteed Rare+).

**Anti-frustration rules, all enforced in the draw:**
- No duplicate card within a single set of 3.
- A Boon at max copies is removed from the pool entirely.
- **At least one card in every set must be usable by the current build** — a set of three pure
  Ember Boons cannot be offered to a player with no elemental source. Implemented as a tag-match
  filter with a fallback to a "safe" Common.
- Legendary and Mythic cannot appear before room 3.
- If a player has taken zero offence Boons in 4 consecutive draws, one offence card is forced.
  (Players who never take damage upgrades hit a DPS wall and quit; the game quietly protects them.)

## 9.2 The catalogue

Notation: **C**ommon / **R**are / **E**pic / **L**egendary / **M**ythic. `×n` = max copies.

### A · Offence — 25 Boons

| # | Name | R | Effect |
|---|---|---|---|
| 1 | Sharpened Points | C ×5 | +8 % damage |
| 2 | Keen Eye | C ×5 | +5 % crit chance |
| 3 | Cruel Edge | C ×5 | +15 % crit damage |
| 4 | Heavy Draw | C ×3 | +12 % Tier III damage |
| 5 | Rapid Nock | C ×5 | +7 % fire rate |
| 6 | Barbed Tips | C ×3 | +10 % damage to enemies below 50 % HP |
| 7 | Steady Aim | C ×4 | +6 % damage while stationary |
| 8 | Follow Through | C ×3 | +9 % damage to the last enemy you hit |
| 9 | Bloodgroove | C ×3 | +12 % damage to burning, poisoned, or frozen targets |
| 10 | Split Shot | R ×3 | +1 arrow, −15 % damage each |
| 11 | Pierce Study | R ×3 | +1 pierce |
| 12 | Executioner | R ×2 | +40 % damage below 25 % enemy HP |
| 13 | Overdraw | R ×2 | Tier III +35 %, Tier I −20 % |
| 14 | Rend | R ×3 | Hits reduce enemy armour 4 % (max 40 %) |
| 15 | Crescendo | R ×1 | +2 % damage per consecutive hit, max +40 %, resets on a miss |
| 16 | Marksman | R ×2 | +4 % damage per unit of distance, cap +60 % |
| 17 | Twin Nock | E ×1 | +2 arrows, −25 % damage each |
| 18 | Deadeye | E ×1 | Crits gain +2 pierce and full damage on pierce |
| 19 | Hammerfall | E ×1 | Every 8th arrow deals 400 % |
| 20 | Cull | E ×1 | Instantly kill non-elite enemies below 8 % HP |
| 21 | Siege Draw | E ×1 | +60 % damage to plated and shielded targets |
| 22 | Rain of Nocks | E ×1 | Tier III fires 3 extra arrows in a 40° fan at 70 % |
| 23 | Perfect Form | L ×1 | All shots count as Tier III (Draw meter still shown, cosmetically) |
| 24 | Ruin | L ×1 | +100 % damage, −50 % max HP |
| 25 | The Long Arrow | M ×1 | Arrows never despawn and never stop; infinite pierce, −40 % damage |

### B · Defence — 19 Boons

| # | Name | R | Effect |
|---|---|---|---|
| 26 | Toughened Hide | C ×5 | +10 % max HP |
| 27 | Warded | C ×4 | +4 % damage reduction |
| 28 | Second Skin | C ×4 | Heal 4 % max HP on room clear |
| 29 | Bulwark Stance | C ×3 | +8 % damage reduction while stationary |
| 30 | Vital Surge | C ×1 | +15 % max HP and heal to full |
| 31 | Thorns | C ×3 | Reflect 15 % of contact damage |
| 32 | Lifedraw | R ×3 | 3 % lifesteal |
| 33 | Shieldweave | R ×3 | Each Momentum stack grants a 2 % max HP shield |
| 34 | Guardian Angel | R ×1 | Survive one lethal hit at 1 HP |
| 35 | Absorption | R ×2 | −35 % elemental damage taken |
| 36 | Regrowth | R ×2 | Heal 0.8 % max HP/s while moving |
| 37 | **Warding Line** | R ×1 | Your Windlines block enemy projectiles |
| 38 | Stonewall | E ×1 | +25 % damage reduction, −15 % move speed |
| 39 | Aegis | E ×1 | Block the next 3 hits entirely; recharges each room |
| 40 | Phoenix Heart | E ×1 | Revive once at 50 % HP |
| 41 | Blood Pact | E ×1 | 30 % of damage taken is delayed and dealt over 4 s (cancelled by a kill) |
| 42 | Immortal Draw | L ×1 | Invulnerable while at Tier III, −30 % damage |
| 43 | Covenant | L ×1 | Take no damage for the first 8 s of each room |
| 44 | The Unbroken | M ×1 | No single hit may deal more than 8 % of your max HP |

### C · Mobility & Momentum — 14 Boons

| # | Name | R | Effect |
|---|---|---|---|
| 45 | Fleetfoot | C ×5 | +8 % move speed |
| 46 | Gale Step | C ×3 | +1 max Momentum stack |
| 47 | Quick Recovery | C ×3 | Momentum decays 40 % slower |
| 48 | Light Boots | C ×3 | Momentum builds 25 % faster |
| 49 | Dash | C ×1 | Double-tap the stick to dash 3 u (4 s cd) |
| 50 | Slipstream | R ×3 | +3 % damage per Momentum stack |
| 51 | Kiting | R ×2 | +15 % damage for 2 s after moving 3 u |
| 52 | Windwalk | R ×1 | Immune to all slows and roots |
| 53 | Blink | R ×1 | Dash becomes a teleport with 2 charges |
| 54 | Momentum Engine | E ×1 | Momentum never decays within a room |
| 55 | Runner's High | E ×1 | At max Momentum: +30 % fire rate |
| 56 | Ghost Step | E ×1 | Dash grants 0.8 s of invulnerability |
| 57 | Stormfoot | L ×1 | At max Momentum, all arrows chain to 2 targets |
| 58 | Perpetual | M ×1 | Draw and Momentum build **simultaneously**, moving or not |

*Boon 58 is the single most powerful card in the game and is Mythic for that reason — it deletes
the core trade-off, which is only acceptable as a 0.5 %-weight, once-per-many-runs celebration.*

### D · Windline & Confluence — 18 Boons

The signature category. Roughly 16 % of the pool, deliberately over-represented relative to its
"share of systems", because this is the mechanic we want players discovering.

| # | Name | R | Effect |
|---|---|---|---|
| 59 | Long Weave | C ×5 | +0.25 s Windline duration |
| 60 | Bright Thread | C ×5 | +8 % Confluence damage |
| 61 | Wide Thread | C ×3 | +20 % Windline intersection width (easier to hit) |
| 62 | Lingering | C ×1 | Windlines persist through room transitions |
| 63 | Tangle | C ×3 | Windline slow 8 % → 16 % |
| 64 | Thread Study | R ×3 | +15 % Confluence damage |
| 65 | Deep Weave | R ×1 | Confluence cap +1 (→4) |
| 66 | Cutting Lines | R ×2 | Windlines deal 1.5 % enemy max HP/s |
| 67 | Crossbind | R ×1 | Confluence also applies your equipped element |
| 68 | Anchor Line | R ×1 | A Windline is drawn at your position at room start |
| 69 | Echo Thread | R ×2 | Killing an enemy leaves a short Windline at its position |
| 70 | Lattice | E ×1 | Confluence cap +2 (→5) |
| 71 | Living Thread | E ×1 | Windlines drift slowly toward the nearest enemy |
| 72 | Resonant Weave | E ×1 | Each Confluence triggers a 1.5 u AoE at 80 % damage |
| 73 | Sunthread | E ×1 | Windlines damage and blind enemies that cross them |
| 74 | Weaver's Grace | L ×1 | Every shot begins with 1 free Confluence stack |
| 75 | The Loom | L ×1 | Windlines never expire within a room |
| 76 | Total Confluence | M ×1 | Every shot is at max Confluence, −35 % base damage |

### E · Elemental — 18 Boons

| # | Name | R | Effect |
|---|---|---|---|
| 77 | Kindling | C ×4 | +12 % Ember damage |
| 78 | Rime | C ×4 | +12 % Frost effect |
| 79 | Charge | C ×4 | +12 % Storm damage |
| 80 | Blight | C ×4 | +12 % Toxin damage |
| 81 | Elemental Tips | C ×1 | Arrows gain a random element (if you have none) |
| 82 | Conductor | C ×3 | +15 % reaction damage |
| 83 | Wildfire | R ×1 | Burn spreads to one nearby enemy on death |
| 84 | Deep Freeze | R ×2 | Freeze duration +0.8 s |
| 85 | Forked Arc | R ×2 | Storm chains +2 targets |
| 86 | Virulence | R ×2 | Toxin max stacks +5 |
| 87 | Reactive | R ×1 | Reactions have no cooldown, −20 % reaction damage |
| 88 | Attunement | R ×1 | Choose one element: +35 % to it |
| 89 | Catalysis | E ×1 | Reactions deal +60 % |
| 90 | Elemental Overload | E ×1 | Every 6th arrow carries all four elements |
| 91 | Frostfire | E ×1 | Arrows carry both Ember and Frost |
| 92 | Stormblight | E ×1 | Arrows carry both Storm and Toxin |
| 93 | The Fourfold | L ×1 | All four elements on every arrow, each at 50 % potency |
| 94 | Prismbreak | L ×1 | Reactions chain to 3 nearby enemies |

### F · Economy & Utility — 12 Boons

| # | Name | R | Effect |
|---|---|---|---|
| 95 | Prospector | C ×4 | +15 % gold this run |
| 96 | Scavenger | C ×4 | +12 % material drops |
| 97 | Lucky Find | C ×3 | +8 % chance of a 4th Boon card |
| 98 | Vigor Draught | C ×1 | Refund 2 Vigor on run completion |
| 99 | Insightful | C ×2 | +1 Insight per elite killed |
| 100 | Bargainer | R ×2 | −25 % Shrine prices |
| 101 | Shard Sense | R ×2 | +20 % hero shard drop |
| 102 | Second Choice | R ×2 | +1 Boon reroll |
| 103 | Greed | R ×1 | +50 % gold, −10 % max HP |
| 104 | Treasure Sense | R ×1 | Reveal room contents and Boon rarities before entering |
| 105 | Golden Arrow | E ×1 | 5 % chance an arrow drops gold on hit |
| 106 | Curator | E ×1 | Choose from 5 Boon cards instead of 3 |

### G · Cursed — 6 Boons

Always rendered with a **crimson border and an explicit downside line**. Never hidden, never a
trap — a Cursed Boon that surprises the player is a broken promise.

| # | Name | R | Effect |
|---|---|---|---|
| 107 | Glass Draw | R ×1 | +45 % damage, −40 % max HP |
| 108 | Blind Fury | R ×1 | +35 % fire rate, auto-aim assist disabled |
| 109 | Hollow Bones | E ×1 | +60 % move speed, +50 % damage taken |
| 110 | Bloodprice | E ×1 | Every future Boon costs 12 % max HP and is upgraded one rarity |
| 111 | The Bargain | L ×1 | Start each room at 25 % HP, +120 % damage |
| 112 | Quiverfall | M ×1 | Every 10th arrow deals 2,000 % but stuns you for 1 s |

## 9.3 Synergy sets

Collecting 3 Boons tagged to a set grants a free bonus, announced with a full-screen flourish.
Sets are the mid-run "my build became a thing" moment, and they are what makes a random draw
feel authored.

| Set | Any 3 of | Bonus |
|---|---|---|
| **The Weaver** | 59, 60, 63, 64, 65, 69, 70 | Confluence cap +1 and +25 % Confluence damage |
| **The Storm** | 45, 46, 47, 48, 50, 51, 55 | Momentum stacks are permanent for the room |
| **The Furnace** | 77, 83, 89, 91, 9 | Burn ignites the ground beneath the target |
| **The Deep Winter** | 78, 84, 91, 35 | Frozen enemies shatter for 200 % AoE |
| **The Conduit** | 79, 85, 92, 57 | Chains travel along Windlines at full damage |
| **The Rot** | 80, 86, 92, 6 | Toxin stacks are never lost and transfer on death |
| **The Executioner** | 3, 12, 18, 20, 2 | Crits below 30 % enemy HP instantly kill non-elites |
| **The Fortress** | 26, 27, 29, 38, 39 | Damage reduction cap raised 75 % → 82 % |
| **The Sacrifice** | any 3 Cursed | Downsides reduced by half |
| **The Prism** | 90, 93, 94, 82, 89 | Every reaction becomes Prismbreak |

Sets are **discovered, not listed** — the collection screen fills in a set's name and members as
the player encounters them, which turns the catalogue itself into long-term content.

## 9.4 Upgrade paths (Boon evolution)

Six Boons **evolve** when their prerequisites are met mid-run, replacing themselves with a
stronger card and a distinct visual:

| Base (at max copies) | + Condition | Evolves into |
|---|---|---|
| Split Shot ×3 | + Twin Nock | **Storm of Nocks** — 7 arrows, −30 % each, all lay Windlines |
| Long Weave ×5 | + The Loom | **Eternal Weave** — Windlines persist for the entire stage |
| Lifedraw ×3 | + Regrowth ×2 | **Bloodwell** — lifesteal heals a shield above max HP |
| Fleetfoot ×5 | + Runner's High | **Windborn** — leave a damaging trail while moving |
| Kindling ×4 | + Catalysis | **Everburn** — Burn never expires |
| Bright Thread ×5 | + Weaver's Grace | **First Light** — every shot starts at max Confluence, no penalty |

Evolutions are the run's climax. They are deliberately reachable only in rooms 8+ of a long
stage, which gives late-run rooms a distinct feel from early ones.

## 9.5 Balancing method

**Power budget.** Every Boon is assigned a **Power Score (PS)** measured by the simulator as the
percentage win-rate delta it produces in a reference chapter-8 run, averaged over 5,000 seeded
runs and all 20 heroes.

| Rarity | Target PS | Tolerance |
|---|---|---|
| Common | 3.0 | ±1.0 |
| Rare | 7.5 | ±2.0 |
| Epic | 15.0 | ±3.5 |
| Legendary | 28.0 | ±6.0 |
| Mythic | 45.0 | ±12.0 |

**CI gates (Phase 12 harness):**
- Any Boon outside its rarity tolerance fails the build.
- Any Boon with a **pick rate below 12 %** when offered is flagged as dead content and rewritten.
- Any Boon with a pick rate **above 78 %** is flagged as mandatory and nerfed — a card everyone
  always takes is not a choice.
- Any *pair* of Boons whose combined PS exceeds 2.4× the sum of their individual PS is flagged as
  a degenerate combo and one side is capped.

**The explicit design tension:** synergy sets and evolutions are *intentionally* super-additive.
The 2.4× rule exists to separate designed spikes (which are listed above and playtested) from
emergent ones (which are usually bugs). The simulator reports the top 30 super-additive pairs
every build; new entries on that list get human review before shipping.

**Live tuning.** All 112 Boons are defined in `assets/data/boons.json`, hot-swappable via remote
config. Weights, values, and max copies are tunable without a client update; only genuinely new
*behaviour* requires a release.
