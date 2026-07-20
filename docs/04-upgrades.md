# 04 — Complete Upgrade System

Six independent progression axes. They are deliberately on different currencies and different
clocks so that a player blocked on one is never blocked on all.

| Axis | Currency | Resets on Ascension | Clock |
|---|---|---|---|
| **The Spire** (towers) | Gold + Insight gates | **Yes** | Per session |
| **Heroes** | Gold + Shards | No | Per few days |
| **Arrows** | Materials + Gold | No | Per few days |
| **Research Lab** | Insight | No | Per week |
| **Marks** (passives) | Mastery only — unpurchasable | No | Per week |
| **Ascension** | Emberdust | — | Per 3–5 weeks |

## 4.1 The master power formula

Every source of power in the game feeds exactly one of these terms. Anything that does not fit
this formula does not get built.

```
ATK   = heroBase(lvl) · arrowMult · (1 + spireMight) · (1 + researchAtk)
              · (1 + ascensionAtk) · (1 + Σ boonAtk)

DPS   = ATK · fireRate · drawTierMult · (1 + confluenceMult)
              · (1 + critChance · (critDmg − 1)) · pierceEffective

EHP   = heroHP(lvl) · (1 + spireVit) · (1 + ascensionVit)
              / (1 − DR)          where DR = 1 − Π(1 − dr_i), hard-capped at 0.75
```

Three rules keep this from exploding:

1. **Additive within a source, multiplicative across sources.** All Boon attack bonuses sum into
   one term; they do not multiply each other. This is what stops a 20-Boon run from producing a
   10,000× number.
2. **Damage reduction is combined multiplicatively and capped at 75 %.** Never additive — additive
   DR reaches 100 % and breaks the game.
3. **One hard ceiling per multiplier class**, enforced in code: `drawTierMult ≤ 2.1`,
   `confluenceMult ≤ 1.6`, `goldMult ≤ 6.0`.

## 4.2 The Spire — 24 nodes, 4 wings

The Spire is the tower you defend and the tower you upgrade — the meta hub is the fiction. Wings
unlock at account levels 1 / 5 / 9 / 14. Every node is level 1–80, cost
`base · 1.145^(n−1)` (see [02](02-economy.md)).

### Wing I — The Armory (offence) · unlocks L1

| # | Node | Effect / level | Base cost | Cap at L80 |
|---|---|---|---|---|
| 1 | Warden's Might | +2.0 % attack | 60 | +160 % |
| 2 | Keen Edge | +0.35 % crit chance | 90 | +28 % |
| 3 | Executioner | +1.5 % crit damage | 90 | +120 % |
| 4 | Quickdraw | −0.6 % Draw tier time | 140 | −48 % |
| 5 | Piercing Study | +1 pierce / 16 levels | 220 | +5 pierce |
| 6 | Elemental Focus | +2.0 % elemental damage | 110 | +160 % |

### Wing II — The Bulwark (survival) · unlocks L5

| # | Node | Effect / level | Base cost | Cap at L80 |
|---|---|---|---|---|
| 7 | Vitality | +2.5 % max HP | 70 | +200 % |
| 8 | Warded Hide | +0.45 % damage reduction | 130 | +36 % |
| 9 | Momentum Mastery | +0.3 % per stack; +1 max stack / 20 lvl | 160 | +4 stacks |
| 10 | Second Wind | +0.35 % HP healed on room clear | 100 | +28 % |
| 11 | Iron Resolve | −0.5 % elite & boss damage taken | 180 | −40 % |
| 12 | Last Light | +0.25 % chance to survive a lethal hit at 1 HP (60 s cd) | 300 | 20 % |

### Wing III — The Fletchery (mechanics) · unlocks L9

| # | Node | Effect / level | Base cost | Cap at L80 |
|---|---|---|---|---|
| 13 | Swiftshot | +0.5 % fire rate | 120 | +40 % |
| 14 | Windline Weaving | +0.018 s Windline duration | 150 | +1.44 s |
| 15 | Confluence Study | +1.2 % Confluence damage | 200 | +96 % |
| 16 | Arrow Velocity | +0.8 % projectile speed | 80 | +64 % |
| 17 | Deflection | +0.25 % ricochet chance | 190 | +20 % |
| 18 | Wide Nock | +0.3 % arrow hitbox | 110 | +24 % |

Wing III is **the mastery wing** — every node makes Confluence easier to execute. It is
intentionally the most expensive wing, and intentionally the one that rewards players who
already understand the mechanic. Skill and investment compound; that is the point.

### Wing IV — The Sanctum (economy) · unlocks L14

| # | Node | Effect / level | Base cost | Cap at L80 |
|---|---|---|---|---|
| 19 | Fortune | +0.9 % gold | 150 | +72 % |
| 20 | Prospector | +0.7 % material drop rate | 160 | +56 % |
| 21 | Boon Insight | +0.4 % Rare+ Boon weight | 240 | +32 % |
| 22 | Shrine Favour | −0.5 % Shrine prices | 130 | −40 % |
| 23 | Vigor Well | +1 max Vigor / 20 levels | 400 | +4 |
| 24 | Shardseeker | +0.8 % hero shard drop | 260 | +64 % |

### Tier gates

Each node is banded. Advancing past **L20 / L40 / L60** requires Insight spent at the Research
Lab: **25 / 90 / 300** per node. This is the anti-whale brake described in
[02 §2.11](02-economy.md). It also creates a healthy rhythm: gold makes you stronger daily,
Insight makes you stronger weekly.

## 4.3 Heroes

Three sub-axes per hero. Full roster in [07-heroes.md](07-heroes.md).

**Level** (1 → chapter-gated cap): `cost = 90 · 1.11^(lvl−1)` gold.
`heroBase(lvl) = statAtL1 · (1 + 0.085·(lvl−1))`. Cap rises by 8 per chapter cleared, so hero
levelling can never outrun campaign progress and become a gold dump with no purpose.

**Stars** (★1 → ★6): costs shards. 40 to unlock, then 30 / 80 / 180 / 400 / 900.
Each star: +12 % hero base stats, and **★3 and ★5 unlock the hero's second and third talent**.

**Talent tree** (3 nodes, unlocked at ★1 / ★3 / ★5). Each node is a choice of two mutually
exclusive branches — e.g. Kade's ★3 node is *Wildfire* (Burn spreads to one nearby enemy) vs
*Slow Burn* (Burn lasts 2× and stacks 3×). 20 heroes × 3 nodes × 2 branches = **120 distinct
build-defining decisions** in the meta layer alone.

**Heroes are sidegrades, not upgrades.** A ★6 Common hero and a ★1 Legendary are within 15 % of
each other in raw power; they differ in *how* they play. This is what allows heroes to be the
gacha object without the gacha being pay-to-win.

## 4.4 Arrows

Full spec in [08-arrows.md](08-arrows.md). Summary of the upgrade axis:

- **12 arrow types**, each crafted from materials at the Fletchery.
- **Tiers I–V** per arrow: refinement costs materials of matching tier + gold.
  `refineCost(t) = 800 · 4.2^(t−1)` gold plus `3·t` mats of tier `ceil(t·0.8)`.
- **Refinement affixes**: each refine rolls one affix from a pool of 18 (e.g. *+9 % Confluence
  damage*, *Windline +0.3 s*, *+2 % burn chance*). Rerolling an affix is the deliberate escalating
  gold sink from [02 §2.4](02-economy.md).
- Only **one arrow is equipped at a time**, so arrows are a build choice, not a stat stack.

## 4.5 Skills (in-run) vs Marks (passive)

**Skills** are the 112 in-run Boons — fully specified in [09-skills.md](09-skills.md). They exist
only for the duration of a run and are the primary source of run-to-run variance.

**Marks** are the permanent passive layer, and they are the one system in the game that
**cannot be bought at any price, with any currency**. Marks are earned by mastery achievements:

| Mark | Earned by | Effect |
|---|---|---|
| Mark of the Thread | Trigger 500 Confluences | +5 % Confluence damage |
| Mark of the Thread II | 5,000 Confluences | +12 % Confluence damage, +0.2 s Windline |
| Mark of Stillness | Land 1,000 Tier-III shots | +4 % Tier III damage |
| Mark of the Gale | Reach max Momentum 2,000 times | +1 max Momentum |
| Mark of the Unbroken | Clear a chapter without taking damage | +6 % damage while at full HP |
| Mark of the Swift | Clear any stage in under 2:30 | +5 % fire rate |
| Mark of the Choir | Defeat all 20 bosses | +8 % boss damage |
| Mark of Ruin | Reach Endless floor 50 | +10 % all damage |
| Mark of the Ninefold | Ascend 9 times | +1 Boon choice (4 cards instead of 3) |
| …16 more | | |

25 Marks total, 6 equippable at once (slots at account levels 12/20/30/45/65/90). Marks are the
answer to "what does a skilled player have that a spending player cannot get", and the honest
answer needs to be *something real*.

## 4.6 The Research Lab

Unlocks at account level 9. Spends **Insight** (from boss first-kills, dailies, weeklies —
never purchasable, ~180/week for an active player).

Three branches:

**Branch A — Tier Gates.** Unlock L20/L40/L60 bands on Spire nodes. Consumes ~70 % of lifetime
Insight. Deliberately the boring-but-necessary sink.

**Branch B — Systemic unlocks** (one-time, permanent, powerful):

| Research | Insight | Effect |
|---|---|---|
| Second Loadout | 60 | Save/swap a full hero + arrow + Mark set |
| Boon Banking | 120 | Carry 1 Boon from a failed run into the next |
| Shrine Ledger | 150 | See the next Boon set before buying a reroll |
| Windline Memory | 220 | Windlines persist through room transitions |
| Double Draw | 400 | Tier III can overcharge into a one-off Tier IV shot |
| Elemental Codex | 300 | See exact reaction previews on the HUD |
| Deep Descent | 500 | Unlock Endless Descent difficulty tiers 2–5 |

**Branch C — Quality of life** (cheap, unlocked early, deliberately not monetised):
auto-claim chests (30), skip run intro (20), damage-number toggle (free), extra Vigor
notification (25), combat log (40).

## 4.7 Ascension (prestige / rebirth)

**Gate.** Available after clearing chapter 10 *and* reaching account level 40. Visible — as a
locked door with its rewards stated — from account level 5.

**What resets:** all 24 Spire node levels → 0, all banked gold → 0, campaign progress → chapter 1.
**What survives:** heroes (levels, stars, talents), arrows, Marks, Research, account level,
achievements, cosmetics, Insight, battle pass, friends, ladder history.

**What you gain:** **Emberdust**, awarded as

```
emberdust = floor( 12 · (highestChapter − 8)^1.35 · (1 + 0.08 · ascensionCount) )
```

Ascending at chapter 10 yields ~34; waiting until chapter 14 yields ~140. So there is a real
"ascend now or push further" decision every cycle — the same push-or-bank tension as the Shrine,
at a 3-week scale.

**The Emberdust tree** — 5 branches, permanent, never reset:

| Branch | Node examples | Max |
|---|---|---|
| **Cinder** (offence) | +3 % all damage / rank | 40 ranks |
| **Ash** (defence) | +3 % EHP / rank | 40 ranks |
| **Spark** (economy) | +4 % gold, +2 % mats / rank | 30 ranks |
| **Ember** (velocity) | Start each Ascension with N Spire levels pre-bought | 25 ranks |
| **Pyre** (unique) | One-off unlocks: extra Boon reroll, +1 loadout, Endless tiers, 4th Boon card | 12 nodes |

The **Ember** branch is what makes cycle N+1 faster than cycle N without making it trivial: you
begin each new Ascension with up to 25 free levels on every Spire node, so re-clearing chapters
1–10 takes ~90 min on cycle 2 versus ~6 h on cycle 1, and ~35 min by cycle 5.

**Cycle length target:** Ascension 1 at week 3–5, then 2.5 weeks, 2 weeks, 10 days, converging to
a ~7-day cadence by cycle 6. A converging (not diverging) cycle is what keeps prestige from
becoming a treadmill — each loop is meaningfully faster, and the player can feel it.

**Ascension 9** grants *Mark of the Ninefold* (4 Boon cards per choice), which is the single
biggest quality-of-life change in the game and is the designed long-term carrot for the top 2 %
of players.
