# 02 — Complete Economy Design

All numbers here are launch targets. Every one is a tunable in a single remote-config document
(`economy_v1`) so live-ops can rebalance without a client release — see
[12-architecture.md](12-architecture.md).

## 2.1 Currency table

| Currency | Type | Cap | Primary source | Primary sink | Purchasable |
|---|---|---|---|---|---|
| **Gold** | Soft | none | Runs, chests, quests | Spire upgrades, Shrine, crafting | Indirectly (bundles) |
| **Gems** | Hard | none | Quests, first-clears, events, IAP | Vigor, chests, hero unlock, Pact | Yes |
| **Vigor** | Energy | 30 (→50) | Time (1 / 6 min) | Repeat runs | Yes (gems) |
| **Hero Shards** | Per-hero | none | Chests, events, Spire Sanctum | Hero unlock & star-up | Via chests only |
| **Insight** | Progression | 9,999 | Boss first-kills, dailies, weeklies | Research Lab | **No** |
| **Emberdust** | Prestige | none | Ascension | Ascension multipliers | **No** |
| **Ashwood / Ironhead / Skyfeather / Prismcore** | Materials T1–T4 | 9,999 ea. | Runs by chapter tier | Arrow crafting & refinement | Via bundles |
| **Event tokens** | Seasonal | expires | Active event only | Event shop | Sometimes |

Two currencies — **Insight** and **Emberdust** — are deliberately unpurchasable at any price.
They are the spine of long-term progression, which guarantees Design Law 2 ("money buys pace,
not power") has teeth rather than being marketing copy.

## 2.2 Vigor (energy) — and why it never blocks progress

- Max **30**, +2 per 10 account levels to a hard cap of **50**.
- Regenerates **1 per 6 minutes** (full 30 → 3 hours; full 50 → 5 hours).
- Offline regen accrues, capped at max. No over-cap banking.
- **A stage you have never cleared costs 0 Vigor.** Repeating a cleared stage to farm costs
  **6 Vigor**. Boss re-runs cost 10.

That single rule is the most important line in this document. It means a player can *always*
push the campaign forward, forever, for free. Vigor throttles **farming velocity**, which is a
legitimate pacing lever, and never throttles **progression**, which is where energy systems in
this category turn predatory. It also removes the single biggest one-star review driver in the
genre.

Refills: **40 gems** for a full refill, price rising +20 gems each refill within a rolling 24 h
(40 → 60 → 80 → 100, capped). One **free** refill per day via a rewarded ad.

Practical daily budget for a free player: ~30 stored + ~24 regenerated ≈ 54 Vigor ≈ **9 farm
runs**, plus unlimited campaign-push attempts. ≈ 35–50 minutes of play. That is the intended
daily session ceiling; anything past it should be diminishing, not blocked.

## 2.3 Gold — earn curve

Full-clear gold for a stage in chapter *c*, stage *s* (1–20):

```
gold(c, s) = round( 110 · 1.26^(c-1) · (1 + 0.02·(s-1)) · variance )
variance ∈ [0.92, 1.08]  (seeded per-run, shown as a "haul" number, never hidden)
```

| Chapter | Gold / full clear | Typical clear time | Gold / min |
|---|---|---|---|
| 1 | 110 – 154 | 3:10 | ~42 |
| 2 | 139 – 194 | 3:30 | ~48 |
| 4 | 220 – 308 | 4:00 | ~66 |
| 6 | 350 – 490 | 4:40 | ~90 |
| 8 | 555 – 777 | 5:20 | ~125 |
| 10 | 881 – 1,233 | 6:00 | ~176 |
| 12 | 1,398 – 1,957 | 6:45 | ~248 |

Partial runs pay **per room cleared**, at `gold(c,s) / rooms · 0.7`. A run that dies in room 2 of
7 still banks ~20 % of the full haul. **There is no zero-reward run** — this is a hard rule and
the defeat screen must say the number out loud.

Modifiers that stack multiplicatively on the haul:
- Rewarded ad "Double Haul" after a run: **×2** (cap 5/day)
- Warden's Pact subscription: **×1.5** permanently
- In-run "Prospector" Boons: up to **×1.6**
- Event weekends: **×1.25 – ×2**

Hard ceiling on stacked gold multipliers: **×6.0**. Enforced in code, not by convention.

## 2.4 Gold — sink curve

### The Spire (primary sink, ~78 % of lifetime gold)

Every Spire node uses:

```
cost(n) = base · 1.145^(n-1)          n = level being purchased, 1-indexed
```

Sample — **Warden's Might** (+2 % attack per level, base 60):

| Level | Cost | Cumulative |
|---|---|---|
| 1 | 60 | 60 |
| 10 | 205 | 1,320 |
| 25 | 1,540 | 11,200 |
| 40 | 11,600 | 84,900 |
| 60 | 181,000 | 1,330,000 |
| 80 | 2,830,000 | 20,800,000 |

24 nodes across 4 wings. Full lifetime Spire cost before Ascension ≈ **310 M gold**, which is
deliberately unreachable in one Ascension cycle — you Ascend at ~8–12 % completion. See
[04-upgrades.md](04-upgrades.md).

**Tier gates.** Every node is soft-capped in bands of 20 levels. Passing L20 / L40 / L60 requires
spending **Insight** (25 / 90 / 300) at the Research Lab. Since Insight is unpurchasable and
time-gated, this is the structural brake on whale runaway: a player who buys 100× the gold of a
free player still cannot exceed them by more than one tier band.

### Other sinks

| Sink | Cost | Purpose |
|---|---|---|
| **The Shrine** (mid-run) | 40 – 900 gold, scales with chapter | Buy a Boon, heal 35 %, reroll next Boon set, or gamble |
| Arrow crafting | 800 – 45,000 | See [08-arrows.md](08-arrows.md) |
| Arrow refinement reroll | 1,200 + 15 % per reroll same session | Deliberate escalating sink |
| Hero level-up | 90 · 1.11^(level-1) | Per hero, so it scales with roster size |
| Loadout respec | Free ×3/day, then 250 gold | Encourages experimentation, prevents spam |

**The Shrine deserves a note.** It appears once mid-run (after room 4). It is the only place
in-run gold matters *during* the run, which converts gold from a passive trickle into a live
"push or bank" decision: spend 600 on a heal now, or keep it for the Spire tonight. Shrine
spending is drawn from your banked gold, so it is a genuine choice with a cost outside the run.

## 2.5 Gems — full ledger

### Free income (no spend)

| Source | Gems | Cadence | Monthly |
|---|---|---|---|
| Daily quest set (4 quests) | 30 | Daily | 900 |
| Daily login | 5 – 60 (28-day cycle) | Daily | ~500 |
| Weekly quest set | 120 | Weekly | 480 |
| Chapter first-clear | 100 | ~1 per 3 days early | ~600 (month 1) |
| Boss first-kill | 40 each | 20 total | 800 (lifetime) |
| Achievements | 10 – 500 | One-off | ~1,400 (lifetime) |
| Events | 200 – 600 | Weekly | ~1,600 |
| Free battle pass track | 300 | Per 6-week season | ~200 |
| **Total, active free player** | | | **≈ 4,400 / month** |

A free player earns roughly a **$25 gem pack per month** in value. That is deliberately generous
and is the mechanism by which Design Law 2 is true: free players reach every gem-gated thing,
they just reach it later.

### Gem sinks

| Sink | Cost |
|---|---|
| Vigor refill | 40 / 60 / 80 / 100 (rolling 24 h) |
| Astral Chest | 270 |
| Astral Chest ×10 | 2,430 (10 % off, 1 Epic+ guaranteed) |
| Prism Chest | 600 |
| Hero direct unlock (Rare) | 900 |
| Hero direct unlock (Epic) | 2,400 |
| Battle Pass premium track | 990 |
| Boon reroll token (in-run, max 2) | 30 |
| Continue after death (max 1/run, once/day free) | 80 |
| Cosmetic skin | 600 – 1,800 |
| Extra loadout slot | 400 |

**Continue-after-death is capped at one per run and one free per day.** Uncapped continues are
the fastest way to destroy a roguelite's tension and, downstream, its retention. We take the
revenue hit knowingly.

## 2.6 Reward balancing model

The whole economy is derived from the **TTK Law** (Design Law 1). The chain is:

```
enemy HP curve  →  required player DPS curve  →  required power level curve
                →  required Spire investment  →  required gold  →  gold earn rate
```

**Enemy HP** (common enemy, global stage index `G = (c-1)·20 + s`):

```
HP(G) = 44 · growth(G)
growth(G) = 1.072^(G-1)                    for G ≤ 80    (chapters 1–4)
          = 1.072^79 · 1.054^(G-80)        for G > 80    (chapters 5+)
```

The growth-rate step-down at chapter 5 is intentional: early chapters need to *feel* like fast
power gain, late chapters need a curve flat enough that a session's worth of Spire levels is
still perceptible. Without the step-down, late-game upgrades feel like nothing — the single most
common late-game churn cause in this category.

**Player DPS** must satisfy `TTK = HP(G) / DPS(G) ∈ [0.8, 1.6]` for a player at the
*expected* power for that stage. Expected power is defined as: hero at chapter level cap, Spire
nodes at the tier band unlocked by that chapter, one crafted arrow of matching tier, and an
average Boon draw at room 5.

The balance harness is a headless Dart simulator (Phase 12) that runs 10,000 seeded runs per
chapter and reports the TTK distribution. **Any build where the p10–p90 TTK band escapes
[0.6, 2.2] fails CI.** Balance is a test, not an opinion.

## 2.7 Daily rewards

28-day repeating cycle, resets on completion. Missing a day does not reset the cycle — it just
doesn't advance. (Streak-punishment reset is a dark pattern and is banned by Design Law 6.)

| Day | Reward | | Day | Reward |
|---|---|---|---|---|
| 1 | 500 gold | | 15 | 2 T3 mats |
| 2 | 10 gems | | 16 | 40 gems |
| 3 | 5 Vigor | | 17 | 1 Astral Chest |
| 4 | 3 T1 mats | | 18 | 12,000 gold |
| 5 | 20 gems | | 19 | 15 Vigor |
| 6 | 1,200 gold | | 20 | 60 gems |
| 7 | **1 Astral Chest** | | 21 | **1 Prism Chest** |
| 8 | 15 gems | | 22 | 30 Insight |
| 9 | 3,000 gold | | 23 | 25,000 gold |
| 10 | 10 Vigor | | 24 | 3 T4 mats |
| 11 | 2 T2 mats | | 25 | 80 gems |
| 12 | 30 gems | | 26 | 20 Vigor |
| 13 | 6,000 gold | | 27 | 40,000 gold |
| 14 | **20 hero shards (choice)** | | 28 | **Guaranteed Epic hero shard pack (60)** |

Day 7 / 14 / 21 / 28 are the anchors. The **choice** on day 14 matters — letting the player
direct shards at a hero they want converts a login reward into a goal.

## 2.8 Chest rewards

No chest contains raw combat power directly. Chests contain **hero shards, materials, gold, and
cosmetics**. Heroes are sidegrades, not upgrades (see [07-heroes.md](07-heroes.md)) — this is
what keeps us out of loot-box-for-power territory, and out of regulatory trouble in several
markets.

| Chest | Cost | Contents (weighted) |
|---|---|---|
| **Wooden** | Free, 4 h timer | 200–600 gold, 2–5 T1 mats, 5 % common shards |
| **Iron** | 8,000 gold or ad | 1–3k gold, T1–T2 mats, 15 % Rare shards |
| **Astral** | 270 gems | 4 items. Rare 68 % / Epic 27 % / Legendary 5 % |
| **Prism** | 600 gems | 5 items. Epic 72 % / Legendary 25 % / Mythic cosmetic 3 % |

**Pity.** Astral: guaranteed Epic+ within 10 pulls, Legendary within 40. Prism: Legendary within
12. Pity counters are **displayed on the chest UI** — the player always knows exactly how far
they are. Odds are shown on the purchase screen in all regions, not just the ones that legally
require it.

## 2.9 Ad rewards

| Placement | Reward | Daily cap |
|---|---|---|
| Post-run Double Haul | ×2 gold + mats | 5 |
| Free Vigor refill | Full bar | 1 |
| Iron Chest | 1 chest | 3 |
| Boon reroll (in-run, between rooms only) | 1 reroll | 2 |
| Revive (in-run, between rooms only) | Full HP continue | 1 |
| Shop daily gem drop | 15 gems | 1 |
| Offline haul doubler | ×2 idle gold | 1 |

**Total available: 16 ads/day ≈ 190 gems-equivalent of value.** All ads are *opt-in rewarded*.
There is exactly one non-rewarded placement in the entire game (see
[17-monetization.md](17-monetization.md)), and it never fires mid-run.

## 2.10 Premium economy

| SKU | Price | Contents | Notes |
|---|---|---|---|
| Starter Pact | $2.99 | 800 gems + Kade + 5k gold | Once, offered at first defeat past ch. 2 |
| Gem pack S / M / L / XL | $4.99 / $9.99 / $24.99 / $49.99 | 500 / 1,150 / 3,200 / 7,000 | Standard ladder, +15 % first purchase |
| **Warden's Pact** (sub) | $7.99 / mo | ×1.5 gold, +10 Vigor cap, 100 gems/day, 1 free continue/day, no banner ads | The core offer |
| Battle Pass | $9.99 / season (6 wk) | 60 tiers, ~2,600 gems, cosmetics, shards | |
| Chapter bundle | $4.99 – $19.99 | Mats + gold + shards, scaled to your chapter | Contextual, 1 active max |

**Monthly ARPPU target $14–18. Conversion target 3.5–5 %.** The Pact subscription is the
strategic centre — it is the offer that converts a fair economy into a business, because a
player who believes the game is fair will subscribe to *support pace* in a way they will never
spend on a paywall.

## 2.11 Inflation prevention

Idle/roguelite economies die of gold inflation: income compounds faster than sinks, gold becomes
meaningless, and the upgrade screen — the primary retention surface — stops mattering. Seven
mechanisms:

1. **Matched geometrics.** Income grows at 1.26/chapter; Spire costs at 1.145/level with
   ~7 levels bought per chapter (1.145^7 ≈ 2.6 vs income 1.26 per chapter over ~2 chapters ≈
   1.59 — sinks intentionally outpace income by ~1.6×). The player is always slightly poor. Being
   slightly poor is what makes a reward feel like a reward.
2. **Insight tier gates.** Unpurchasable, time-gated Insight caps how far gold alone can take
   you. This is the hard ceiling on both inflation and pay-to-win.
3. **Ascension as a hard reset.** Ascension zeroes Spire levels and gold. It is the largest sink
   in the game — it deletes the entire accumulated stock, on a ~3–5 week cycle, in exchange for a
   permanent multiplier. Stock never compounds across cycles; only multipliers do.
4. **Escalating within-session reroll costs.** Reroll sinks grow +15 % per use per session, so
   surplus gold has an uncapped drain that scales with how rich you are.
5. **No flat-gold ads.** Ads pay *multipliers on earned gold*, never flat amounts. A whale
   watching ads cannot outrun the curve; the reward is proportional to play.
6. **Multiplier ceiling ×6.0.** Enforced in code. Prevents multiplicative stacking from ever
   creating a gold explosion via an unforeseen Boon + event + Pact combination.
7. **Live telemetry alarm.** `economy_gold_balance` is logged per session ([18](18-analytics.md)).
   If median banked gold at any chapter exceeds 3× the cost of the next expected Spire purchase
   for 3 consecutive days, live-ops is alerted. Inflation is monitored, not assumed away.

**Deflation is also a failure mode** and is watched with the same alarm inverted: if the median
player cannot afford *any* Spire node for 5 consecutive sessions, the curve is too steep and the
game feels like a wall. Both bounds are dashboarded from day one.
