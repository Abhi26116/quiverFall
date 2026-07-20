# 08 — Arrow System

The arrow is the player's **one equipped build choice** carried into a run. Only one arrow is
equipped at a time, so arrows are a decision, not a stat stack.

## 8.1 The master damage formula

```
finalDamage =
      ATK                                  // from 04 §4.1
    · arrow.baseMult                       // 0.72 – 1.40, per arrow type
    · drawTierMult                         // 1.00 / 1.45 / 2.10   (cap 2.10)
    · (1 + confluenceMult)                 // 0.40 / 0.90 / 1.60   (cap 1.60)
    · (isCrit ? critDmg : 1)               // critDmg base 1.80
    · (1 + Σ boonDamage)                   // additive across all Boons
    · (1 + elementalBonus)                 // reaction-dependent
    · pierceFalloff(n)                     // 1.00, 0.85, 0.72, 0.61 …  (0.85^n)
    · armourFactor                         // 0.10 / 0.55 / 1.00 vs plated
```

Ordering matters and is fixed: **multiplicative terms are evaluated in this exact sequence** and
each is clamped at its own ceiling before the next is applied. The whole expression is computed
in one pure function, `DamageResolver.resolve()`, which is unit-tested against a golden table of
600 cases. Damage is never computed ad-hoc anywhere else in the codebase.

**Pierce falloff** exists so that infinite-pierce builds converge rather than explode: an arrow
through 10 enemies deals `0.85^9 ≈ 23 %` to the tenth.

## 8.2 The four elements

| Element | Application | Effect | Scales off |
|---|---|---|---|
| **Ember** | On hit, 25 % (100 % at Tier III for Kade) | Burn: 4 % enemy max HP/s, 4 s, stacks ×2 | Enemy max HP |
| **Frost** | Every hit, 12 Chill | 100 Chill → Freeze 1.6 s, +30 % damage taken | Flat |
| **Storm** | Every 5th arrow | Chain to 3 targets at 60 %; travels along Windlines | Player ATK |
| **Toxin** | On hit, 1 stack (max 10) | 0.9 % enemy max HP/s per stack, −5 % healing per stack | Enemy max HP |

Two scale off enemy max HP (good against bosses, weak against fodder) and two scale off player
ATK (the reverse). This is what keeps element choice meaningful across the whole game rather
than one element dominating late.

### Reactions — triggered by Confluence

When Confluence merges two arrows carrying **different** elements, a reaction fires. This is the
only way to produce reactions, which is why Confluence is the deepest system in the game.

| A + B | Reaction | Effect |
|---|---|---|
| Ember + Frost | **Steamburst** | 2.5 u AoE, 180 % damage, −20 % enemy armour for 5 s |
| Ember + Storm | **Firestorm** | Chain targets are ignited; chain count +2 |
| Ember + Toxin | **Blightfire** | Burn and Toxin both tick at 2× for 3 s |
| Frost + Storm | **Superconduct** | Chains cannot miss; frozen targets take 2× chain damage |
| Frost + Toxin | **Rime Rot** | Freeze duration +1 s; Toxin stacks are not lost on freeze |
| Storm + Toxin | **Corrosive Arc** | Chains spread 3 Toxin stacks to each target |
| Any 3+ (Oriel) | **Prismbreak** | 4 u AoE, 400 %, applies all four elements at max stacks |

Reactions have a **0.6 s per-enemy internal cooldown** so that high-fire-rate heroes cannot turn
them into a continuous damage stream.

## 8.3 The twelve arrows

`baseMult` is the arrow's damage coefficient. Balance intent is noted for each.

### Tier-1 arrows (available from chapter 1)

**1 · Ash Shaft** — `baseMult 1.00` · no element · **Craft: free (starting arrow)**
The reference arrow. Perfectly average, no drawback. Exists so every other arrow can be
described as a trade against it.
*VFX:* thin white streak, plain Windline. *SFX:* dry snap, mid-range thwip.

**2 · Broadhead** — `baseMult 1.28` · fire rate −18 % · pierce 0
Slower, heavier. Net DPS ≈ +5 % vs Ash Shaft but far better against plated enemies since single
hits clear the Tier-II threshold sooner.
*VFX:* thick amber-tipped shaft, heavy Windline. *SFX:* deep thud on impact.
*Balance:* the anti-Husk pick. Weak with Kestrel (fire rate anti-synergy) by design.

**3 · Splitshaft** — `baseMult 0.72` · fires 2 arrows at ±8°
Two Windlines per shot. The cheapest entry into Confluence play and the arrow the tutorial nudges
toward at chapter 3.
*VFX:* forked pale-green streaks. *SFX:* doubled snap, slight chorus.
*Balance:* 1.44× total damage but requires both arrows to connect; against single targets at
range it is a downgrade. Intentionally spikes with Iris.

### Tier-2 arrows (chapter 4+)

**4 · Emberhead** — `baseMult 0.92` · **Ember**, 35 % application
*VFX:* orange core, embers shed along the Windline which itself glows warm. *SFX:* soft ignition
whoosh, crackle on burn tick.

**5 · Rimeshaft** — `baseMult 0.90` · **Frost**, 15 Chill/hit
*VFX:* pale blue, frost crystals bloom at impact, Windline reads as a vapour trail. *SFX:* glassy
chime, cracking on freeze.

**6 · Stormnock** — `baseMult 0.88` · **Storm**, chains every 4th arrow
*VFX:* violet-white, arcs visibly jump; Windlines carry a faint current. *SFX:* electrical snap,
rising whine on chain.

**7 · Blightbarb** — `baseMult 0.84` · **Toxin**, 1 stack/hit, max 12
*VFX:* sickly green, dripping trail, Windline sags slightly. *SFX:* wet hiss, bubbling DoT tick.

*Balance note on elementals:* all four sit at 0.84–0.92 baseMult, i.e. a 8–16 % raw damage tax
paid for the elemental rider. They out-damage Ash Shaft from roughly chapter 5 onward, which is
exactly when they unlock — an arrow should never be a downgrade at the moment you earn it.

### Tier-3 arrows (chapter 7+)

**8 · Skimmer** — `baseMult 0.86` · ricochets 2× off walls/enemies
Each ricochet lays a new Windline. The highest lattice-generation arrow in the game.
*VFX:* flat silver disc-shaft, sharp angular Windlines. *SFX:* ping on each bounce, pitch rising.

**9 · Lancehead** — `baseMult 1.15` · pierce +3 · projectile speed +40 %
*VFX:* long white lance, straight bright Windline. *SFX:* sharp whistle, metallic punch-through.
*Balance:* the Vane/Bram line-clear arrow; poor against dispersed enemies.

**10 · Twinfang** — `baseMult 0.80` · fires 2 arrows on **converging** paths that cross at 6 u
The crossing point is a **guaranteed Confluence** every shot. This is the arrow that teaches the
mechanic to players who never figured it out organically — the game hands them a reliable ×1.4
if they simply stand at the right distance.
*VFX:* twin crimson threads that flare white at the crossing. *SFX:* two snaps, then a chime at
convergence.

### Tier-4 arrows (chapter 10+)

**11 · Ghostshaft** — `baseMult 0.94` · passes through walls and shields; **ignores plating
entirely**
*VFX:* semi-transparent, no impact particles, ghostly slow-fading Windline. *SFX:* muffled,
reversed-sounding release; no impact sound at all (deliberately unsettling).
*Balance:* trivialises Husk/Bulwark/Gaunt. Compensated by having no pierce and a short 8 u range.

**12 · Prismshaft** — `baseMult 0.96` · cycles all four elements, one per shot
*VFX:* the arrow's colour shifts per shot; Windlines retain their element's colour, so the
player's lattice becomes a genuine four-colour weave — the most visually striking thing in the
game. *SFX:* the four element sounds in rotation, tuned to a rising major arpeggio so a full
cycle is musically satisfying.
*Balance:* the reaction-engine arrow. Weakest raw damage of the T4s; highest ceiling with
Confluence. Requires Prismcore ×12 to craft, which is the single largest material cost in the
game.

## 8.4 Crafting and refinement

**Craft cost** by tier: T1 free/800 gold · T2 3,400 gold + 12 T1 mats · T3 14,000 + 10 T2 ·
T4 45,000 + 8 T3 + 4 T4.

**Refinement** — each arrow refines I → V:

```
refineCost(t) = 800 · 4.2^(t-1) gold  +  3·t materials of tier ceil(t·0.8)
```

| Refine | Cost (gold) | Effect |
|---|---|---|
| I → II | 800 | +8 % baseMult, 1 affix slot |
| II → III | 3,360 | +17 %, 2 affix slots |
| III → IV | 14,100 | +27 %, 3 affix slots |
| IV → V | 59,300 | +40 %, 4 affix slots, arrow VFX gains a gold trim |

**Affixes** roll from an 18-entry pool on each refine, weighted by tier:

| Affix | Range | Notes |
|---|---|---|
| Sharpened | +4–9 % damage | Common |
| Keen | +2–5 % crit chance | Common |
| Swift | +3–7 % fire rate | Common |
| Wide | +5–12 % hitbox | Common |
| Fleet | +4–10 % projectile speed | Common |
| **Weaving** | +0.15–0.40 s Windline | Rare — the mechanic affix |
| **Confluent** | +6–15 % Confluence damage | Rare |
| Piercing | +1 pierce | Rare |
| Kindled / Rimed / Charged / Blighted | +5–12 % that element | Rare |
| Executioner | +8–20 % crit damage | Rare |
| Fortune | +3–8 % gold | Rare |
| **Threaded** | Confluence cap +1 | Epic — build-defining |
| **Resonant** | Reactions deal +20–35 % | Epic |
| **Echoing** | 8–15 % chance to fire a second arrow | Epic |

Rerolling a single affix costs **1,200 gold, +15 % per reroll in the same session** — the
escalating sink from [02 §2.11](02-economy.md). Affixes can be individually locked (2 locks max),
which is the honest version of this system: the player is never forced to gamble away a good roll
to fix a bad one.

## 8.5 Balance guardrails

1. **No arrow may exceed ×1.25 DPS over Ash Shaft** at equal refinement against the *reference
   encounter* (a chapter-8 mixed room, simulated). Arrows differentiate by matchup, not by power.
2. **Every arrow must be top-3 against at least one enemy family** and bottom-3 against at least
   one. An arrow with no weakness gets one added.
3. **Ghostshaft's range cap is load-bearing.** It is the only hard counter to the entire Carapace
   family; if playtesting shows it is universally correct, the range drops to 6 u before its
   damage is touched — removing the *ability* would remove the fantasy.
4. **Twinfang's guaranteed Confluence must not exceed the ceiling** a skilled Iris player reaches
   manually. It grants ×1 Confluence reliably; manual play reaches ×3 (×5 with Iris). The
   training-wheels arrow must never beat the mastery it trains.
5. Simulated in the balance harness (Phase 12): 12 arrows × 5 refinements × 20 heroes × 12
   chapters, 10,000 seeded runs. Any arrow whose win-rate deviates more than ±8 % from the
   arrow-set median fails CI.
