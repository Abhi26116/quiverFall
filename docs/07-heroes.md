# 07 — Hero Design

## 7.0 Framework

**Heroes are sidegrades.** A ★6 Common and a ★1 Legendary land within ~15 % of each other in raw
throughput. Rarity buys *complexity and ceiling*, not power. This is the design decision that
lets heroes be the gacha object without violating Design Law 2.

**Stat baseline.** All values are indices against a reference Warden:
ATK 100 · HP 100 · Move 3.20 u/s · Fire rate 2.20 /s.
`heroBase(lvl) = statAtL1 · (1 + 0.085·(lvl−1))`; +12 % per star.

**Ultimate.** Charged by damage dealt: `charge% = 100 · damageDealt / (14 · heroATK · fireRate)`.
At expected power this is one ultimate per **~40–50 s**, i.e. roughly one per room and two per
boss. Ultimates are manual — a single large button, right thumb, never auto-cast.

**Talents.** Three nodes at ★1 / ★3 / ★5, each a choice of two exclusive branches (T1a/T1b …).
Choices are re-specable for free 3×/day.

**Rarity distribution:** 4 Common · 8 Rare · 6 Epic · 2 Legendary.

---

## 7.1 Common heroes

### 1 · Wren, the First Warden · Common · Generalist
`ATK 100 · HP 100 · Move 3.20 · Rate 2.20`
**Unlock:** free, starting hero.

- **Passive — Trueshot:** +8 % crit chance. Tier III shots cannot miss a moving target
  (mild homing, 12°).
- **Ultimate — Volley Fan:** 7 arrows in a 90° arc, each at 80 % damage, each laying a full
  Windline. Instantly creates a lattice — the game's clearest teaching tool for Confluence.
- **T1:** *Steady Hand* (+12 % crit dmg) / *Fleet* (+10 % move speed)
- **T3:** *Wide Fan* (Ultimate 11 arrows, 60 % dmg) / *Focused Fan* (3 arrows, 220 % dmg, pierce 3)
- **T5:** *Warden's Lattice* (Ultimate Windlines last 4 s) / *Warden's Fury* (Ultimate refunds 30 % charge on kill)

**Strengths:** no bad matchups, teaches the game, strong at every stage.
**Weaknesses:** never the best answer to anything. Deliberately — the starter must remain viable
without ever being optimal, or the roster is dead on arrival.

### 2 · Bram, the Siegewright · Common · Area damage
`ATK 118 · HP 110 · Move 2.95 · Rate 1.85`
**Unlock:** clear chapter 2.

- **Passive — Heavy Ordnance:** arrows detonate for 45 % splash in 1.6 u. Splash does not apply
  elements (or he would trivialise every elemental interaction).
- **Ultimate — Mortar Rain:** 12 shells over 3 s across the arena, each 130 %, amber-telegraphed.
- **T1:** *Wider Blast* (radius 2.2 u) / *Denser Blast* (65 % splash, radius 1.2 u)
- **T3:** *Concussion* (splash staggers Rush enemies) / *Incendiary* (splash applies Burn at 40 %)
- **T5:** *Saturation* (Mortar Rain 20 shells) / *Precision Strike* (4 shells, 500 %, boss-seeking)

**Strengths:** Swarmlings, Skarn, crowd floors. **Weaknesses:** slow fire rate makes Shellback and
Bulwark miserable; splash cannot break Husk plating.

### 3 · Kestrel, the Quickstring · Common · Speed
`ATK 78 · HP 88 · Move 3.55 · Rate 2.95`
**Unlock:** clear chapter 3.

- **Passive — Hummingbird:** +25 % fire rate, −15 % damage per arrow. **Draw tiers advance 30 %
  faster** — reaches Tier III in 0.77 s instead of 1.10 s.
- **Ultimate — Flurry:** 4 s of ×3 fire rate at Tier III regardless of movement. Movement no longer
  drops the tier for the duration.
- **T1:** *Lighter Draw* (Tier time −45 % total) / *Sharper Nock* (recover the −15 % damage penalty at Tier III)
- **T3:** *Windrunner* (Windline duration +0.6 s — more shots means more lattice) / *Bleed* (every 4th arrow applies a 3 s bleed)
- **T5:** *Endless Flurry* (Flurry 7 s, ×2.2 rate) / *Perfect Flurry* (Flurry 3 s, ×3 rate, +100 % Confluence damage)

**Strengths:** the best Confluence hero in the game because Windline density scales with fire
rate. **Weaknesses:** worst single-shot damage; loses hard to Husk/Ironmaw plating and to
Warden-Fell.

### 4 · Ovrin, the Bulwark · Common · Tank
`ATK 92 · HP 155 · Move 2.90 · Rate 2.00`
**Unlock:** clear chapter 2 (shards from Gaunt).

- **Passive — Aegis:** +55 % max HP. Each Momentum stack additionally grants a shield equal to
  2 % max HP (max 5 stacks = 10 %), refreshing while moving.
- **Ultimate — Aegis Pin:** plants a shield wall that blocks all enemy projectiles for 6 s and
  reflects 30 % of blocked damage as Storm.
- **T1:** *Thicker Plate* (+15 % HP) / *Faster Guard* (Momentum stacks build 40 % faster)
- **T3:** *Bastion* (shield per stack 4 %) / *Riposte* (breaking a shield deals 200 % AoE)
- **T5:** *Long Wall* (Aegis Pin 10 s) / *Mirror Wall* (Aegis Pin reflects 100 %, 3 s)

**Strengths:** the answer to Longeye, Mortarite, and every projectile boss. The recommended hero
for players stuck on a wall. **Weaknesses:** lowest damage ceiling; long fights.

---

## 7.2 Rare heroes

### 5 · Kade, the Emberhand · Rare · Ember
`ATK 108 · HP 100 · Move 3.15 · Rate 2.10` · **Unlock:** free at chapter 5 (tutorial grant)
- **Passive — Kindling:** Tier III arrows apply Burn (4 %/s of enemy max HP, 4 s, stacks 2×).
- **Ultimate — Pyre Line:** a burning wall along the aim vector for 8 s; enemies crossing take
  Burn ×3. Doubles as area denial and as a permanent Windline for Confluence.
- **T1:** *Hot Iron* (Burn on Tier II too) / *Deep Burn* (Burn 6 %/s, Tier III only)
- **T3:** *Wildfire* (Burn spreads to one enemy within 2 u on death) / *Slow Burn* (Burn 8 s, stacks 3×)
- **T5:** *Long Pyre* (Pyre Line 14 s) / *Twin Pyre* (two crossed walls — an instant Confluence intersection)

**Strengths:** Gravebound (burn denies revive), swarms, sustained fights. **Weaknesses:**
Warden-Fell, Rimefather, burst windows.

### 6 · Sela, the Rimebound · Rare · Frost
`ATK 102 · HP 105 · Move 3.10 · Rate 2.15` · **Unlock:** chapter 4 chest shards
- **Passive — Chill:** every hit applies 12 Chill; at 100 the enemy **freezes 1.6 s** and takes
  +30 % damage while frozen.
- **Ultimate — Glacier Nail:** a spike of ice at the target; freezes everything in 3.5 u for 3 s.
- **T1:** *Deeper Chill* (16/hit) / *Brittle* (+45 % damage to frozen)
- **T3:** *Shatter* (killing a frozen enemy deals 250 % in 2 u) / *Lingering Frost* (frozen enemies leave a 3 s slow field)
- **T5:** *Absolute Zero* (Glacier Nail 5 s, 5 u) / *Cascading Nail* (freeze chains to 3 more enemies)

**Strengths:** hard-counters Cinder Mote, Ironmaw enrage, Lancer charges, Vermillion.
**Weaknesses:** bosses with freeze immunity (all of P3s); slow against single high-HP targets.

### 7 · Torv, the Stormcalled · Rare · Storm
`ATK 105 · HP 98 · Move 3.20 · Rate 2.20` · **Unlock:** chapter 7
- **Passive — Arc:** every 5th arrow chains to 3 additional enemies at 60 % damage. Chains
  **travel along live Windlines**, which can extend the chain range enormously — the most
  mechanically integrated passive in the roster.
- **Ultimate — Tempest Nock:** 5 s where every arrow chains to 5 targets.
- **T1:** *Frequent Arc* (every 3rd arrow) / *Wide Arc* (5 targets)
- **T3:** *Conductive Lines* (chains along Windlines deal +80 %) / *Overload* (chain targets take +20 % damage for 4 s)
- **T5:** *Long Tempest* (8 s) / *Thunderhead* (Tempest also stuns 0.5 s per chain)

**Strengths:** grouped enemies, Arclight, Swarmlings, lattice play. **Weaknesses:** single-target,
Null, isolated bosses.

### 8 · Sable, the Wither · Rare · Toxin
`ATK 88 · HP 102 · Move 3.20 · Rate 2.35` · **Unlock:** chapter 8
- **Passive — Toxin:** hits stack Toxin (max 10). Each stack deals **0.9 % of enemy max HP/s** and
  reduces healing 5 %. Toxin scales off *enemy* HP, so Sable is the designated boss-killer and
  is intentionally weak against fodder.
- **Ultimate — Miasma:** a 5 u cloud for 8 s applying 2 stacks/s.
- **T1:** *Virulence* (12 max stacks) / *Fast Acting* (stacks apply 2× faster, max 8)
- **T3:** *Contagion* (on death, half the stacks jump to the nearest enemy) / *Corrosion* (each stack also −2 % enemy damage)
- **T5:** *Lasting Miasma* (14 s) / *Concentrated Miasma* (3 u, 5 stacks/s)

**Strengths:** every boss, Knitter, The Green Mother. **Weaknesses:** trash clear, short fights,
Warden-Fell.

### 9 · Lira, the Verdant · Rare · Sustain
`ATK 94 · HP 118 · Move 3.20 · Rate 2.25` · **Unlock:** chapter 6
- **Passive — Lifebound:** 4 % lifesteal; +2 % additional while at Tier III.
- **Ultimate — Verdant Bloom:** heals 40 % max HP over 4 s and grants +25 % damage during it.
- **T1:** *Deep Roots* (6 % lifesteal) / *Bloom Speed* (Ultimate charges 25 % faster)
- **T3:** *Overheal* (excess healing becomes a shield up to 30 % HP) / *Sanctuary* (standing still heals 1.5 %/s)
- **T5:** *Endless Bloom* (Bloom 8 s, 60 % heal) / *Blood Bloom* (Bloom converts healing to +80 % damage)

**Strengths:** the survivability crutch for a stuck player; Endless Descent attrition.
**Weaknesses:** low ceiling; burst damage bypasses sustain.

### 10 · Corvin, the Caroms · Rare · Ricochet
`ATK 96 · HP 96 · Move 3.25 · Rate 2.30` · **Unlock:** chapter 5 chest
- **Passive — Bounce:** arrows ricochet once off walls or enemies, and **a ricocheted arrow lays a
  new Windline**, so Corvin generates lattice geometry the player did not aim.
- **Ultimate — Caroms:** 6 s where arrows bounce 4×.
- **T1:** *True Bounce* (ricochets seek the nearest enemy) / *Hard Bounce* (ricochet deals 120 %)
- **T3:** *Angle Study* (+35 % Confluence damage) / *Double Bounce* (2 ricochets base)
- **T5:** *Endless Carom* (10 s) / *Perfect Carom* (during Ultimate, ricochets never lose damage)

**Strengths:** enclosed arenas, Bulwark (bounces around the shield), lattice builds.
**Weaknesses:** open arenas, predictability.

### 11 · Vane, the Longsight · Rare · Sniper
`ATK 125 · HP 86 · Move 3.05 · Rate 1.70` · **Unlock:** chapter 9
- **Passive — Distance:** +6 % damage per unit of distance to target, capped at +90 %. Below 3 u,
  −30 %.
- **Ultimate — Piercing Horizon:** a full-arena-width lance, 600 % damage, infinite pierce,
  leaving a Windline across the whole arena.
- **T1:** *Farsight* (cap +130 %) / *Steady* (no close-range penalty)
- **T3:** *Marked* (enemies hit beyond 8 u take +25 % for 5 s) / *Overpenetration* (+3 pierce)
- **T5:** *Twin Horizon* (two lances, 90° apart — an instant Confluence cross) / *Sundering Horizon* (1,400 %, single line)

**Strengths:** bosses, Longeye duels, open arenas. **Weaknesses:** anything in her face; the most
punishing hero for a careless player.

### 12 · Thane, the Bloodtide · Rare · Berserker
`ATK 112 · HP 92 · Move 3.30 · Rate 2.40` · **Unlock:** chapter 10
- **Passive — Bloodtide:** +1.2 % damage per 1 % missing HP (max +85 %). Cannot be healed above
  70 % max HP by any source.
- **Ultimate — Red Draw:** costs 20 % current HP; 6 s of +120 % damage and +30 % fire rate.
- **T1:** *Deeper Tide* (max +120 %) / *Tempered* (heal cap 90 %)
- **T3:** *Last Stand* (below 25 % HP: +40 % damage reduction) / *Frenzy* (below 25 % HP: +50 % fire rate)
- **T5:** *Long Red* (10 s) / *Crimson Draw* (Red Draw also makes all shots Tier III)

**Strengths:** highest damage ceiling of any Rare; skilled players only. **Weaknesses:** unforgiving,
anti-synergy with Lira-style sustain, high variance.

---

## 7.3 Epic heroes

### 13 · Nyx, the Umbral · Epic · Assassin
`ATK 130 · HP 84 · Move 3.40 · Rate 2.15` · **Unlock:** 40 shards (Astral chests)
- **Passive — First Blood:** +70 % damage to enemies above 90 % HP. Kills grant 1.5 s of +25 %
  move speed.
- **Ultimate — Umbral Step:** teleport to the furthest enemy, become untargetable 1.5 s, next
  3 shots are guaranteed crits at 300 %.
- **T1:** *Executioner's Eye* (+35 % below 20 % HP too) / *Deeper Shadow* (Step 2.5 s)
- **T3:** *Shadowline* (Windlines laid while untargetable deal damage) / *Chain Kill* (kill speed buff stacks to 3)
- **T5:** *Twin Step* (2 charges) / *Perfect Step* (Step arrows at 600 %, 1 shot)

### 14 · Iris, the Latticeweaver · Epic · **The Confluence specialist**
`ATK 98 · HP 100 · Move 3.20 · Rate 2.45` · **Unlock:** 40 shards
- **Passive — Weave:** Windlines last **2.6 s** (vs 1.2 s base), and Confluence stacks cap at
  **5** instead of 3 (4th: +230 %, 5th: +320 % and 2 u AoE).
- **Ultimate — The Lattice:** instantly draws a 6-line web across the arena, persisting 10 s.
  Every shot through it caps out at 5 Confluence.
- **T1:** *Long Weave* (3.4 s Windlines) / *Bright Weave* (+25 % Confluence damage)
- **T3:** *Cutting Lines* (Windlines damage enemies 2 %/s) / *Binding Lines* (Windline slow 8 % → 35 %)
- **T5:** *Grand Lattice* (10 lines, 16 s) / *Living Lattice* (the Lattice follows the player)

**The hero the whole game is designed around.** Highest skill ceiling; genuinely weak in the hands
of a player who does not understand the mechanic, which is exactly right.

### 15 · Zea, the Falconer · Epic · Summoner
`ATK 90 · HP 104 · Move 3.20 · Rate 2.20` · **Unlock:** 40 shards (Thrall drops)
- **Passive — Skyhawk:** a spirit hawk companion attacks independently for 35 % of hero ATK at
  1.5/s, and its shots lay Windlines the player can Confluence through.
- **Ultimate — Falconry:** summons 4 hawks for 12 s.
- **T1:** *Sharper Talons* (50 % ATK) / *Swift Hawk* (2.4/s)
- **T3:** *Bonded* (hawk crits when the player is at Tier III) / *Flock* (2 permanent hawks at 25 %)
- **T5:** *Skydarken* (8 hawks, 12 s) / *Great Hawk* (1 hawk, 250 % ATK, 20 s, taunts)

### 16 · Rook, the Gravebinder · Epic · Control
`ATK 106 · HP 112 · Move 3.00 · Rate 2.05` · **Unlock:** 40 shards
- **Passive — Pull:** crits pull the target 1.2 u toward the impact point. Grouped enemies take
  +12 % damage each (max +48 %).
- **Ultimate — Singularity:** a 4 s well pulling everything in 6 u to a point, then detonating for
  400 %.
- **T1:** *Stronger Pull* (2.0 u) / *Denser Grouping* (+18 % per enemy)
- **T3:** *Crush* (grouped enemies take stacking 5 %/s) / *Anchor* (pulled enemies are rooted 0.6 s)
- **T5:** *Twin Singularity* (2 wells) / *Collapsing Singularity* (1 well, 6 s, 900 %)

### 17 · Halden, the Judgement · Epic · Boss-killer
`ATK 120 · HP 108 · Move 3.10 · Rate 1.95` · **Unlock:** Weeping Gate shards
- **Passive — Verdict:** +40 % damage to bosses and elites. Boss attacks deal −15 % to Halden.
- **Ultimate — Judgment Spear:** a 900 % single strike; +100 % more if the target is below 40 %.
- **T1:** *Zealot* (+55 % boss damage) / *Warded* (−28 % boss damage taken)
- **T3:** *Sentence* (Ultimate marks the boss: +20 % damage taken 10 s) / *Swift Judgment* (Ultimate charges 40 % faster on bosses)
- **T5:** *Final Verdict* (below 25 % HP the Spear executes at 3,000 %) / *Twin Spear* (2 spears, 600 % each)

### 18 · Ashlin, the Rekindled · Epic · Revival
`ATK 104 · HP 96 · Move 3.20 · Rate 2.25` · **Unlock:** Ashen Choir shards
- **Passive — Rekindle:** once per run, on lethal damage, revive at 45 % HP with a 350 % AoE nova
  and 3 s of invulnerability.
- **Ultimate — Rebirth Nova:** 500 % AoE, heals 25 %, and **refreshes Rekindle** if already used.
- **T1:** *Bright Rekindle* (revive at 70 %) / *Twice Kindled* (2 revives, 30 % each)
- **T3:** *Ember Body* (3 s of invulnerability after any room clear) / *Phoenix Trail* (invulnerability leaves burning Windlines)
- **T5:** *Eternal* (Ultimate refresh has no cooldown) / *Supernova* (Nova 1,200 %, no refresh)

---

## 7.4 Legendary heroes

### 19 · Mirelle, the Mirrored · Legendary · Duplication
`ATK 100 · HP 100 · Move 3.20 · Rate 2.20` · **Unlock:** 40 shards (Prism chests / Hollow Warden)
- **Passive — Reflection:** 25 % chance for each arrow to duplicate. Duplicates can duplicate
  (geometric, capped at 4 arrows). **Duplicates lay their own Windlines**, so Mirelle's Confluence
  rate scales quadratically with the proc.
- **Ultimate — Hall of Mirrors:** 8 s where every arrow duplicates 3×, and a mirror clone of the
  player fights alongside at 60 % stats.
- **T1:** *Truer Mirror* (35 % chance) / *Deeper Mirror* (cap 6 arrows)
- **T3:** *Silvered* (duplicates deal 100 % instead of 85 %) / *Fractured* (duplicates spread ±20°, wider coverage)
- **T5:** *Endless Hall* (14 s) / *Twin Warden* (the clone lasts the whole room at 80 % stats)

**Strengths:** everything, moderately. **Weaknesses:** high variance; a bad RNG stretch feels
awful, which is the tax on the highest theoretical output in the game.

### 20 · Oriel, the Prism · Legendary · Elemental mastery
`ATK 110 · HP 105 · Move 3.20 · Rate 2.20` · **Unlock:** guaranteed from chapter 12 completion
- **Passive — Spectrum:** arrows cycle Ember → Frost → Storm → Toxin, one element per shot.
  Because Confluence merges the elements of the arrows it joins, **Oriel triggers elemental
  reactions constantly and effortlessly** — the payoff hero for a player who has learned
  everything.
- **Ultimate — Prism:** 10 s where every arrow carries **all four** elements simultaneously,
  triggering every reaction on every hit.
- **T1:** *Faster Cycle* (cycle every shot even at Tier III multishot) / *Attuned* (+30 % elemental damage)
- **T3:** *Resonance* (reactions deal +50 %) / *Saturation* (elements persist 2× longer on enemies)
- **T5:** *Endless Prism* (16 s) / *White Light* (Prism 6 s but reactions deal ×3)

Hard-counters **Null** (adaptive immunity cannot keep up with four elements) and is the intended
Endless Descent hero. The capstone reward for finishing the campaign, and a genuine "I earned
this" moment rather than a purchase.

---

## 7.5 Roster balance matrix

| Role | Heroes | Design intent |
|---|---|---|
| Generalist | Wren, Mirelle | Always viable, never optimal |
| Burst / single target | Vane, Halden, Nyx, Thane | Boss answers |
| Area / crowd | Bram, Torv, Rook, Zea | Swarm answers |
| Sustain / defensive | Ovrin, Lira, Ashlin | The wall-breaker picks |
| Elemental | Kade, Sela, Sable, Oriel | Reaction builds |
| **Mechanic-native** | **Iris, Kestrel, Corvin** | Confluence specialists — the skill-expression lane |

**Coverage audit.** Every enemy in [05](05-enemies.md) has at least three hero answers, and no
hero answers everything. Every boss in [06](06-bosses.md) is clearable by all 20 heroes at
expected power — clear times vary by up to 2.2×, but nothing is a hard lock. A roster with hard
locks becomes a roster where the correct move is to buy the right hero, which is exactly the
pay-to-win outcome Design Law 2 forbids.
