# 06 — Boss Design

## 6.0 Boss design rules

Every boss in Quiverfall obeys these, without exception:

1. **Three phases minimum**, with a hard visual and musical transition at 66 % and 33 % HP.
2. **Every attack is telegraphed in amber before it exists.** Lethal geometry is crimson. No
   boss ever damages the player with something the player could not have seen.
3. **Each boss tests exactly one thing** the campaign has been teaching, and the fight is
   readable as a question with a correct answer.
4. **No boss requires Confluence** through chapter 8. Bosses 9+ have Confluence-optimal
   solutions but always a slower non-Confluence path.
5. **Target duration 50–90 s.** Longer than 90 s in a mobile session is a phone in a pocket.
6. **First-kill is a designed win.** Bosses are tuned to a ~55 % first-attempt clear at expected
   power — hard enough to matter, soft enough to not be a wall.
7. **A boss's HP is never its difficulty.** If a fight is too easy we add a mechanic, never HP.

**Scaling.** `bossHP = HP(G) · bossMult · (1 + 0.06 · encounterCount)`, where `encounterCount`
is how many times this player has already killed that boss (repeat kills get harder, so farming
a known boss stays engaging). Boss contact and attack damage never scales beyond its listed
% of player max HP — bosses get *tougher*, never *cheaper*.

---

## 6.1 Campaign bosses (chapters 1–12)

### 1 · The Cinder Choir — Chapter 1
**×22 HP · 55 s · Tests: the Draw**

Three linked effigies on a triangle, joined by burning tethers.

- **P1 (100–66 %):** Only the effigy whose eyes are lit is vulnerable; the other two are plated
  like a Husk. The lit one rotates every 6 s. *Tier III breaks plate, so an impatient player can
  brute-force it — slowly.*
- **P2 (66–33 %):** Tethers become damaging crimson lines that sweep the arena at 45°/s. Rotation
  drops to 4 s.
- **P3 (33–0 %):** All three light simultaneously and fire alternating 90° flame cones. Killing
  one permanently removes it — the fight gets easier as it gets more frantic, which is the note
  a first boss should end on.

**Rewards:** 100 gems (first), 40 Insight, 3 T1 mats, Wren shard ×10.

---

### 2 · Gaunt, the Iron Tide — Chapter 2
**×30 HP · 60 s · Tests: flanking**

A colossal shield-bearer. Frontal 180° arc takes 5 % damage.

- **P1:** Slow advance, shield always facing the player. Rotates 70°/s — beatable by circling.
- **P2:** Shield **slams**, sending a crimson shockwave ring outward (jumpable only by being
  outside 5 u — there is no jump, so this is a positioning check). Rotation rises to 110°/s.
- **P3:** Drops the shield entirely, gains +80 % speed and a Ripper-style 3-hit combo with a
  stagger window. The armour puzzle becomes a reflex test.

**Rewards:** 100 gems, 45 Insight, 5 T1, Ovrin shard ×10.

---

### 3 · Silversong — Chapter 3
**×34 HP · 62 s · Tests: Momentum as a build, not a fallback**

A resonant bell-figure that hunts the player's mechanic rather than their HP.

- **P1:** Cone screams inflict **Draw-lock 2.5 s**. Tier III is unavailable roughly half the time.
- **P2:** Adds standing crimson resonance pillars that Draw-lock on contact; the safe floor
  shrinks.
- **P3:** **Permanent Draw-lock.** The entire final third must be won at Tier I with maximum
  Momentum. The first fight in the game that says *the other half of the core mechanic is real*.

**Rewards:** 100 gems, 50 Insight, 4 T2, Kestrel shard ×12.

---

### 4 · The Hollow Warden — Chapter 4
**×36 HP · 70 s · Tests: understanding your own kit**

A mirror of the player's current hero, at 80 % of the player's own stats, using the player's own
arrow type and a fixed Boon set.

- **P1:** Mirrors movement inverted (Echo AI). It Draws — its own arc is visible, so the player
  can read exactly when its heavy shot lands.
- **P2:** It lays **Windlines** and gains Confluence off them. Crossing its Windlines slows the
  player.
- **P3:** Both Windline sets are live. Crossing *your* line through *its* line creates a
  **Discord** — a neutral detonation that damages whoever is closer. The most mechanically
  interesting fight in the first half of the game, and the one that most rewards actually
  understanding Confluence.

**Rewards:** 100 gems, 55 Insight, 5 T2, Mirelle shard ×12.

---

### 5 · Vermillion, the Long Burn — Chapter 5
**×40 HP · 65 s · Tests: Ember, and sustained-damage thinking**

- **P1:** Leaves a persistent burning trail; arena floor progressively becomes lethal.
- **P2:** Ignites in a 3 u aura and charges along amber lines. Safe floor is now ~50 %.
- **P3:** Detonates the entire accumulated trail in sequence over 6 s, creating a moving safe
  window the player must chase. **Frost arrows extinguish trail segments** — a hard elemental
  counter that rewards bringing the right tool.

**Rewards:** 100 gems, 60 Insight, 6 T2, Kade shard ×15, *Ember Codex* (unlocks Ember arrow T3).

---

### 6 · Rimefather — Chapter 6
**×44 HP · 70 s · Tests: Frost, and forced movement**

- **P1:** Freezing cone; a player hit twice within 4 s is rooted for 1.2 s.
- **P2:** The arena floor freezes outward from the boss; standing on ice reduces friction and
  makes precise positioning hard. Momentum builds are *stronger* on ice.
- **P3:** Shatters into three ice-mirrors, only one of which is real (revealed by which one casts
  a shadow — a purely visual read, no HUD marker). Wrong-target damage heals it.

**Rewards:** 100 gems, 65 Insight, 6 T2, Sela shard ×15, *Frost Codex*.

---

### 7 · Arclight — Chapter 7
**×48 HP · 68 s · Tests: Storm, and spacing**

- **P1:** Chains lightning between itself and any active Swarmlings; killing adds breaks the chain.
- **P2:** Charges the arena floor in a grid; alternating grid cells go live on a 1.5 s cycle. Pure
  pattern-reading.
- **P3:** Becomes untargetable and orbits as pure light; four grounded conduits must be destroyed.
  **Confluence chains between conduits**, making a Windline lattice roughly twice as fast — the
  first fight where the depth mechanic is dramatically better without being required.

**Rewards:** 100 gems, 70 Insight, 7 T3, Torv shard ×15, *Storm Codex*.

---

### 8 · The Green Mother — Chapter 8
**×52 HP · 75 s · Tests: Toxin, and DPS checks**

- **P1:** Spawns Knitters continuously; the Mother heals from each. A raw DPS check —
  fail it and the fight is literally unwinnable, which the game states outright in the death screen.
- **P2:** Roots erupt along telegraphed lines; contact applies stacking poison to the *player*.
- **P3:** Retracts into a bloom with a 3 s window every 8 s where the core is exposed. Everything
  else is invulnerable. Burst positioning check.

**Rewards:** 100 gems, 75 Insight, 7 T3, Sable shard ×15, *Toxin Codex*.

---

### 9 · Thrall of the Nine — Chapter 9
**×56 HP · 80 s · Tests: target priority under pressure**

- **P1:** Nine floating sigils orbit; each grants the Thrall one ability. Destroying a sigil
  removes that ability permanently. The player chooses which of the nine threats to delete —
  and there is time to remove only about four.
- **P2:** Remaining sigils accelerate and the Thrall uses two abilities simultaneously.
- **P3:** Absorbs all remaining sigils for +25 % damage each. **A player who destroyed five
  sigils fights a fundamentally different, easier phase 3.** The fight is a live conversation
  about the choices you made 60 seconds ago.

**Rewards:** 100 gems, 85 Insight, 8 T3, Zea shard ×18.

---

### 10 · The Weeping Gate — Chapter 10
**×70 HP · 85 s · Tests: everything from chapters 1–9 · Ascension gate**

A stationary arch that never moves and never directly attacks.

- **P1:** Opens portals spawning waves that escalate through the full enemy roster.
- **P2:** Portals now spawn **Riftborn elites** in pairs. The Gate's own plating opens only while
  fewer than three enemies are alive — a deliberate tension between clearing adds and racing.
- **P3:** All portals open at once, permanently. Survival check for 40 s while burning the core.

**Rewards:** 100 gems, 120 Insight, 10 T4, **unlocks Ascension**, Halden shard ×20.

---

### 11 · Skarn the Unmade — Chapter 11
**×62 HP · 85 s · Tests: split attention**

- **P1:** Single heavy body, slow, enormous telegraphs.
- **P2:** **Splits into two halves** at 66 %, sharing one HP pool. Damaging only one causes the
  other to heal it at 3 %/s. Both must be pressured — pierce, AoE, ricochet, or Confluence
  through both.
- **P3:** Splits into four. The fight becomes an argument for build breadth, and it is the
  clearest signal in the game that single-target builds have a ceiling.

**Rewards:** 100 gems, 100 Insight, 10 T4, Rook shard ×20.

---

### 12 · The Quiverfall — Chapter 12
**×90 HP · 110 s · Tests: mastery · Campaign finale**

The sky itself, falling. Fought on a collapsing arena that loses 8 % of its floor per phase.

- **P1 — The First Shard:** A vast descending shard fires converging amber lines from the arena
  edges. Safe space is the intersection gaps.
- **P2 — The Choir Reforms:** All eleven previous bosses appear as 12 s echoes, one at a time,
  using a single signature attack each. A greatest-hits phase that only lands emotionally
  because the player fought all of them.
- **P3 — Quiverfall:** The shard shatters into 40 fragments raining continuously. The boss is
  invulnerable except when the player's Windline lattice **connects three or more fragments**,
  which channels them into the core. The only fight in the game that *requires* Confluence, and
  it arrives at chapter 12, ~15 hours in, long after the mechanic has been mastered.

**Rewards:** 300 gems, 200 Insight, 15 T4, **Oriel** (Legendary hero, guaranteed), campaign
completion achievement, *Mark of the Choir* progress.

---

## 6.2 Elite & event bosses (13–16)

### 13 · The Ashen Choir — Elite remix of #1
**×48 HP · 70 s.** All three effigies lit permanently; tethers are lethal from the start; a
fourth invisible effigy exists, revealed only by Windline contact. Rewards: 60 Insight, T3 mats,
Ashlin shard ×15.

### 14 · Umbral Twin — Event: *The Long Night*
**×58 HP · 80 s.** Fights in near-total darkness; the arena is lit only by the player's own
Windlines, so the depth mechanic becomes the light source. Attacks are audible before visible —
the one fight with genuine audio-first design. Rewards: event tokens, Nyx shard ×20, cosmetic.

### 15 · Bellweather — Event: *Tollings*
**×54 HP · 75 s.** Every 10 s a bell tolls and **inverts one rule** for the next 10 s (movement
reversed / Draw inverted so moving charges it / Windlines damage the player / healing damages).
Rewards: event tokens, *Bell* cosmetic set, 90 Insight.

### 16 · The Pale Judge — Event: *Assize*
**×66 HP · 90 s.** Reads the player's **build** at fight start and gains a matching immunity —
an Ember build faces a fire-immune Judge. Explicitly designed to punish mono-builds and to sell
the second loadout slot honestly. Rewards: event tokens, Halden shard ×25.

---

## 6.3 Endless Descent bosses (17–20)

Appear every 10 floors in Endless Descent, scaling with floor depth via `1.09^floor`.

### 17 · The Loom — Floor 10, 30, 50…
**×75 HP.** Weaves a slowly tightening lattice of crimson threads across the arena; the survivable
area shrinks to ~15 % by phase 3. **Player Windlines cut threads.** The purest expression of the
game's mechanic as a survival tool rather than a damage tool.

### 18 · Coilspine — Floor 20, 60…
**×85 HP.** A 24-segment serpent. Each segment is individually damageable; destroying segments
shortens it and changes its movement pattern. Killing head-first is fast but enrages it; killing
tail-first is slow but safe. A genuine risk/reward strategy choice with no correct answer.

### 19 · Mother of Motes — Floor 40, 80…
**×70 HP.** Spawns 200+ Motes over the fight. Pure crowd-clear check and the game's designated
"look how strong I've become" power fantasy — the fight exists so that a maxed build feels
absurd, on purpose.

### 20 · The Last Warden — Floor 100, then every 50
**×140 HP · 150 s · The true final boss**

The Warden who held the Spire before you. Five phases, not three.

- **P1:** Draw/Momentum duel at parity — it plays the game exactly as the player does.
- **P2:** Gains the player's *own current* Boon set, mirrored.
- **P3:** Summons echoes of three bosses the player has beaten most often (read from telemetry).
- **P4:** Arena floor is removed; combat on floating Windline-drawn platforms **the player
  creates by firing**. The mechanic becomes the terrain.
- **P5:** One HP each. Pure duel — first hit wins, 20 s timer, sudden death.

**Rewards:** *Mark of Ruin*, Legendary cosmetic set, ladder title, 500 gems (first kill only).

---

## 6.4 Difficulty scaling summary

| Chapter | Boss HP × | Duration | Phases | Confluence |
|---|---|---|---|---|
| 1–3 | 22 – 34 | 55–62 s | 3 | Irrelevant |
| 4–6 | 36 – 44 | 65–70 s | 3 | Helpful |
| 7–9 | 48 – 56 | 68–80 s | 3 | Strongly favoured |
| 10–12 | 62 – 90 | 85–110 s | 3–4 | Required at 12 only |
| Endless | 70 – 140 | 90–150 s | 3–5 | Assumed |

**Boss frequency:** one per stage-20 of each chapter, plus one Elite mini-boss every 5 stages
from chapter 3, plus one event boss per week, plus one Endless boss per 10 floors. An engaged
player meets a boss roughly **every 9 minutes** — frequent enough to be the rhythm of the game,
rare enough to stay an event.
