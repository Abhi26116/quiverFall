# 05 — Complete Enemy Design

## 5.0 How to read this document

**HP** is expressed as a multiplier on the base curve from [02 §2.6](02-economy.md):
`HP(G) = 44 · growth(G)`. So a ×3.0 enemy at global stage 40 has `3.0 · 44 · 1.072^39 ≈ 2,020` HP.

**Speed** is in world units per second. **The player's base move speed is 3.20 u/s.** An arena is
16 × 9 units. Any enemy above 3.2 can catch a fleeing player; that is a deliberate and rare
property.

**Damage** is a percentage of the player's *max* HP, not a flat number. This is the only way to
keep threat constant across a 300× power curve, and it means the balance team tunes one number
per enemy for the whole game rather than a table per chapter.

**Gold** is a share of the room's budget; a room pays out `gold(c,s)/rooms` distributed by these
weights.

Every enemy answers three design questions, and if it cannot answer all three it does not ship:

1. **What does it punish?** (the mistake it exists to catch)
2. **What is its counter-play?** (the thing the player learns)
3. **What does it look like from 40 cm away on a 5.5" screen?** (readability)

---

## 5.1 Family: DRIFT — the fodder

Slow, dumb, numerous. Exist to be the canvas the player paints Windlines on. All Drift enemies
die to a single Tier-II shot at expected power, always.

### 1. Mote
| | |
|---|---|
| HP | ×1.0 · Speed 1.60 · Contact 6 % |
| AI | Direct seek. No avoidance, no prediction. Repaths every 0.5 s. |
| Attack | Contact only. 0.8 s damage cooldown. |
| Weakness | Everything. Dies to one Tier-I shot at expected power. |
| Reward | 1.0 gold weight, 4 % T1 material |
| Visual | Fist-sized floating ink blot, single trailing wisp, dull violet core. Pulses on the beat of the music. |

Punishes: nothing. Teaches: aiming and auto-fire exist. Present in every chapter, at every
difficulty, forever — a game like this needs constant harmless traffic so that the *dangerous*
things read as dangerous by contrast.

### 2. Swarmling
| | |
|---|---|
| HP | ×0.45 · Speed 2.60 · Contact 4 % |
| AI | Flocking (separation/alignment/cohesion, radius 1.2 u). Spawns in packs of 6–10. |
| Attack | Contact, 0.5 s cooldown. Individually trivial, collectively lethal. |
| Weakness | Pierce and AoE. A Tier-III piercing shot through a flock is the intended answer, and it feels fantastic. |
| Reward | 0.3 gold weight each, 1 % T1 |
| Visual | Thumb-sized, sharp triangular silhouette, amber eye. The flock reads as one moving shape. |

Punishes: single-target builds with no pierce. Counter-play: line them up, or use Confluence AoE.

### 3. Wisp
| | |
|---|---|
| HP | ×0.70 · Speed 2.00 · Contact 5 % |
| AI | Seeks the player but overlays a 2.4 Hz sine perpendicular to its travel vector — a genuine zigzag, not a random walk. |
| Attack | Contact. |
| Weakness | Wide arrows, multishot, or predicting the sine. Immune to nothing; just hard to hit. |
| Reward | 1.4 gold weight, 6 % T1 |
| Visual | Torn ribbon of pale cyan light, no solid body, leaves a short afterimage that mirrors the player's Windline visually. |

Punishes: slow projectiles and narrow arrows. This is the enemy that makes *Arrow Velocity* and
*Wide Nock* (Spire nodes 16 and 18) feel worth buying.

### 4. Cinder Mote
| | |
|---|---|
| HP | ×1.0 · Speed 1.60 · Contact 6 % · **Death blast 14 % in 2.2 u** |
| AI | As Mote, but accelerates ×1.6 within 3 u of the player. |
| Attack | Detonates on death **and** on contact. 0.6 s fuse with an amber ring telegraph. |
| Weakness | Kill at range. Frost prevents the detonation entirely (freeze suppresses the fuse) — a taught elemental interaction. |
| Reward | 1.6 gold weight, 8 % T1 |
| Visual | Mote with a swelling orange core visible through translucent skin; the core brightens with the fuse. |

Punishes: melee-range greed and careless AoE clears. Teaches: kill order matters, and Frost has
a use beyond damage.

---

## 5.2 Family: CARAPACE — the armour puzzle

The Draw mechanic's reason to exist. Every Carapace enemy is a directional or timing puzzle that
only Tier II/III solves.

### 5. Husk
| | |
|---|---|
| HP | ×3.0 · Speed 1.00 · Contact 9 % |
| AI | Slow direct seek, always facing the player. |
| Attack | Contact. |
| Special | **Frontal plate.** Tier-I arrows deal 10 % damage and produce a metallic *clang* with no damage number. Tier II deals 55 %. Tier III breaks through at 100 %. |
| Weakness | Tier III, or flanking (rear hitbox takes full damage from any tier). |
| Reward | 4.0 gold weight, 18 % T1 |
| Visual | Broad hunched figure, huge overlapping shoulder plate lit with a cold rim-light. The plate is a *different colour from the body* — the single most important readability decision on this enemy. |

**This is the tutorial enemy for the Draw** (§3.1, beat 1:10). It appears in every chapter so the
lesson never fades.

### 6. Bulwark
| | |
|---|---|
| HP | ×6.0 · Speed 0.00 (stationary) · Contact — |
| AI | Rotates its 180° shield toward the player at 90°/s. Never moves. |
| Attack | None directly. Blocks the room exit until killed. |
| Weakness | **Flanking.** Out-rotate it. Also: ricochet and Confluence arcs curve around the shield. |
| Reward | 6.0 gold weight, 30 % T1, 8 % T2 |
| Visual | Kneeling monolith, tower shield planted, faint runic seam down the shield face that glows brighter as HP drops. |

Punishes: stationary play. Uniquely, this is the one enemy where **Tier III is wrong** — you must
keep moving to flank, which means Momentum, which means Tier I. A deliberate inversion so the
player never learns "Tier III always."

### 7. Shellback
| | |
|---|---|
| HP | ×4.0 · Speed 1.20 · Contact 10 % |
| AI | Seek. On plate break, retreats for 2.0 s then re-engages. |
| Special | Plate **regenerates 2.0 s** after breaking. Sustained pressure required. |
| Weakness | High fire rate; burst-and-wait builds lose to it. |
| Reward | 4.5 gold weight, 20 % T1, 5 % T2 |
| Visual | Segmented beetle-plate that visibly cracks in three stages, each with its own sprite. |

### 8. Ironmaw
| | |
|---|---|
| HP | ×5.0 · Speed 1.40 → **3.90 enraged** · Contact 13 % |
| AI | Slow seek while plated. On plate break: **enrages** — screen-shake, red rim-light, speed ×2.8 for 5 s. |
| Weakness | Kite the enrage; it cannot turn faster than 120°/s while enraged. Frost freeze cancels enrage. |
| Reward | 7.0 gold weight, 25 % T2 |
| Visual | Squat armoured jaw-beast. Enrage is signalled by the plate seams flooding crimson **0.4 s before** the speed change — the telegraph precedes the threat, always. |

Punishes: breaking armour without an escape plan. Teaches: think one step past the kill.

---

## 5.3 Family: RUSH — the movement tax

Force the player out of Tier III. Every Rush enemy is a timer on how long you may stand still.

### 9. Lancer
| | |
|---|---|
| HP | ×1.4 · Speed 3.40, **charge 8.0** · Charge hit 12 % |
| AI | Approach to 5 u → 0.7 s wind-up with a bright **amber line** drawn along the charge path → dash 6 u → 1.1 s recovery (fully vulnerable). |
| Weakness | Sidestep the line; punish the recovery. Freeze during wind-up cancels the charge. |
| Reward | 2.2 gold weight, 10 % T1 |
| Visual | Lean quadruped with a single forward horn. The amber charge line is the game's canonical "this will hurt" language — introduced here in chapter 1 and reused by every boss. |

### 10. Stalker
| | |
|---|---|
| HP | ×1.1 · Speed 2.80 · Lunge 10 % |
| AI | Orbits at 4 u radius, always moving to the player's **rear 120°**, then lunges. |
| Weakness | Turn to face it — the lunge only triggers from behind. Rewards camera awareness. |
| Reward | 2.0 gold weight, 9 % T1 |
| Visual | Low, four-limbed, near-black with two amber eye-slits — the only part visible in the player's peripheral vision, which is the point. |

### 11. Bounder
| | |
|---|---|
| HP | ×1.2 · Speed 2.20 · Slam 11 % in 1.8 u |
| AI | Leaps in a 1.0 s parabolic arc every 2.5 s. **Airborne = untargetable and immune to Windline slow.** |
| Weakness | Shoot the landing (amber ring marks it 0.5 s early), or hit it during the 0.6 s ground phase. |
| Reward | 2.4 gold weight, 11 % T1 |
| Visual | Coiled spring-legged frog silhouette; the shadow beneath it is the real telegraph. |

Punishes: pure auto-targeting reliance — auto-aim cannot lock an airborne Bounder, so the player
must lead manually for the only time in the game.

### 12. Ripper
| | |
|---|---|
| HP | ×2.0 · Speed 2.20 · Combo 5 % / 5 % / 14 % |
| AI | Closes and executes a 3-hit combo (0.35 s / 0.35 s / 0.8 s wind-up). **Staggers** if it takes >8 % of its max HP during the third wind-up. |
| Weakness | The stagger window. This is the game's parry — a skill expression with no button. |
| Reward | 3.0 gold weight, 14 % T1, 4 % T2 |
| Visual | Bipedal, twin blade-arms; the third swing raises both arms fully overhead, which is unmistakable. |

### 13. Thresher
| | |
|---|---|
| HP | ×3.5 · Speed 1.80 · Aura 9 % / 0.6 s in 2.4 u |
| AI | Continuous spin while moving. Never stops. No wind-up, no gap. |
| Weakness | Range. Pure and simple — it has no ranged option and no gap-closer. |
| Reward | 4.0 gold weight, 16 % T1, 6 % T2 |
| Visual | Whirling disc of blades, motion-blurred, with a **hard-edged crimson circle on the ground** marking its exact aura. Lethal zones are always crimson. |

---

## 5.4 Family: SALVO — the position tax

Force the player to *move somewhere specific* rather than just move. Rush enemies say "don't
stand"; Salvo enemies say "don't stand *there*".

### 14. Spitter
| | |
|---|---|
| HP | ×1.0 · Speed 1.20 · Impact 7 %, puddle 4 %/s |
| AI | Maintains 6 u range, kites backward. Fires every 2.2 s. |
| Attack | Lobbed arc, 1.0 s flight, amber landing ring, leaves a 3.5 s acid puddle (crimson). |
| Weakness | It kites — corner it. Puddles do not stack. |
| Reward | 2.0 gold weight, 10 % T1 |
| Visual | Bloated sac-bodied crawler, translucent green belly that empties visibly as it fires. |

### 15. Nettle
| | |
|---|---|
| HP | ×0.9 · Speed 1.00 · 5 % per bolt |
| AI | Static-ish. Fires a 3-bolt 30° spread every 1.8 s. |
| Weakness | Strafe perpendicular; the spread has a wide safe gap at close range. Low HP — kill first. |
| Reward | 1.8 gold weight, 9 % T1 |
| Visual | Thorned plant-thing, three bud-muzzles that bloom before firing. |

### 16. Longeye
| | |
|---|---|
| HP | ×1.3 · Speed 0.80 · **22 %** |
| AI | Acquires the player, draws a **1.2 s amber tracking beam** that stops tracking for the final 0.4 s, then fires a hitscan lance. |
| Weakness | Break line of sight, or move laterally in the final 0.4 s. The heaviest-hitting non-boss enemy in the game and the one that most rewards reading. |
| Reward | 3.5 gold weight, 15 % T2 |
| Visual | Tall, thin, single enormous eye. The beam is the brightest thing on screen while charging. |

### 17. Mortarite
| | |
|---|---|
| HP | ×2.2 · Speed 0.60 · 11 % per shell |
| AI | Fires 3 shells in a triangle around the player's **predicted** position, 1.4 s flight, amber rings. |
| Weakness | Keep moving — prediction always leads, so a direction change beats it. Punishes rooting hard. |
| Reward | 3.2 gold weight, 14 % T2 |
| Visual | Squat siege-shelled artillery, three barrels that recoil independently. |

### 18. Screecher
| | |
|---|---|
| HP | ×1.5 · Speed 1.40 · 6 % + **Draw-lock 2.0 s** |
| AI | Closes to 5 u, emits a 60° cone scream every 3 s. |
| Special | **Draw-lock**: the player cannot gain Draw tiers for 2 s. Momentum still works. |
| Weakness | The cone is narrow and slow to turn — flank it. |
| Reward | 3.0 gold weight, 13 % T2 |
| Visual | Hollow-headed shrieker; the cone is drawn as concentric amber sound rings. |

The only enemy that attacks the player's *mechanic* rather than their HP. Screechers are the
reason Momentum builds exist as a viable alternative rather than a fallback.

---

## 5.5 Family: CHOIR — the priority tax

Never dangerous alone. Make everything else dangerous. Exist to teach target selection.

### 19. Weaver
| | |
|---|---|
| HP | ×1.6 · Speed 1.00 · Contact 5 % |
| AI | Stays behind the nearest ally, maintains a visible shield tether. |
| Special | Grants the nearest ally a shield equal to **40 %** of that ally's max HP; reapplies 3 s after it breaks. |
| Weakness | Kill it first. The tether is a bright cyan line pointing directly at it — the game is *telling* you the answer. |
| Reward | 3.0 gold weight, 14 % T2 |
| Visual | Robed, faceless, hands raised; the tether is its whole read. |

### 20. Chanter
| | |
|---|---|
| HP | ×1.4 · Speed 1.00 · Contact 4 % |
| AI | Retreats from the player, keeps allies inside a 5 u aura. |
| Special | **+30 % attack** to all allies in the aura. |
| Weakness | Kill first. Aura is a subtle amber ground ring. |
| Reward | 2.8 gold weight, 13 % T2 |
| Visual | Tall, thin, floating; mouth permanently open. |

### 21. Knitter
| | |
|---|---|
| HP | ×1.8 · Speed 1.20 · Contact 5 % |
| AI | Moves to the most-damaged ally. |
| Special | Heals **4 % max HP/s** to all allies within 4 u. Can out-heal an underpowered player — the game's clearest DPS check. |
| Weakness | Toxin (heal reduction 50 %) or simply killing it. |
| Reward | 3.4 gold weight, 15 % T2 |
| Visual | Many-armed, weaving green threads to each ally it heals. |

### 22. Warden-Fell
| | |
|---|---|
| HP | ×2.5 · Speed 0.90 · Contact 6 % |
| AI | Interposes itself between the player and the pack. |
| Special | **Nullifies all elemental procs** within a 5 u aura. Confluence still works; only element application is suppressed. |
| Weakness | Physical damage, or pulling enemies out of its aura. |
| Reward | 4.2 gold weight, 18 % T3 |
| Visual | Grey monolithic robe, aura rendered as a desaturation post-effect inside its radius — the world literally goes grey. |

The build-check enemy: a pure elemental build must have a physical answer. It appears from
chapter 6, exactly when players have committed to an element.

---

## 5.6 Family: RIFTBORN — the elites

Appear in Elite rooms (1 per stage from chapter 3) and as mini-bosses. Always accompanied by a
**crimson arena border** and a distinct musical stinger.

### 23. Rift Maw
| | |
|---|---|
| HP | ×4.0 · Speed 0.00 · Contact 10 % |
| AI | Stationary. Spawns 4 Swarmlings every 4.0 s, capped at 16 alive. |
| Weakness | Ignore the adds, burn the Maw. Teaches "kill the source" — a lesson every boss reuses. |
| Reward | 8.0 gold weight, 40 % T2, 10 % T3 |
| Visual | Torn hole in space with a ringed maw of teeth; the tear pulses before each spawn. |

### 24. Echo
| | |
|---|---|
| HP | ×2.0 · Speed 2.40 · Contact 9 % |
| AI | **Mirrors the player's movement vector, inverted**, about the arena centre. Fires when the player fires. |
| Weakness | Stand still — it stands still. Or exploit the mirror to walk it into your own Windlines. The mechanically richest common enemy in the game. |
| Reward | 6.0 gold weight, 30 % T3 |
| Visual | A desaturated silhouette of the player's current hero, outlined in crimson, trailing an inverted Windline. |

### 25. Gravebound
| | |
|---|---|
| HP | ×3.0 · Speed 1.60 · Contact 11 % |
| AI | Standard seek. On death, collapses, then **revives once at 40 % HP after 2.5 s** with +40 % speed. |
| Weakness | Ember burn applied at death prevents the revive (the corpse is consumed). A taught interaction, surfaced by the Elemental Codex research. |
| Reward | 6.5 gold weight, 32 % T3 |
| Visual | Wrapped, broken figure; the revive is telegraphed by a green ember rising from the corpse — killable in that window with any AoE. |

### 26. Null
| | |
|---|---|
| HP | ×2.8 · Speed 2.00 · Contact 10 % |
| AI | Seek. Becomes **immune to the last element that damaged it** for 6 s, indicated by its outline taking that element's colour. |
| Weakness | Element rotation. Confluence merging (which applies two elements in one hit) beats it outright — the payoff enemy for the game's deepest mechanic. |
| Reward | 7.5 gold weight, 35 % T3, 6 % T4 |
| Visual | Faceted crystal humanoid; each facet takes the colour of the element it has adapted to. |

---

## 5.7 Composition rules

Rooms are assembled by the generator ([14](14-level-design.md)) under these constraints, which
exist to prevent the procedural system from producing unfair or boring rooms:

- **Threat budget** per room: `TB = 100 · 1.04^(G-1)`. Each enemy has a threat cost.
- **Max 2 Choir units** per room. Three healers is not difficulty, it is a wall.
- **Never Screecher + Longeye together** before chapter 8 (Draw-lock into a 22 % hitscan is an
  unfair combination for a learning player).
- **At least 40 % of the threat budget must be Drift or Rush** — the player must always have
  something safe to shoot, or the room stops feeling like an action game.
- **Elite rooms** contain exactly one Riftborn plus ≤ 30 % of the normal threat budget in support.
- **No enemy spawns within 3.5 u of the player.** Off-screen spawns are announced by a 0.4 s
  edge-flash at the spawn location.

## 5.8 Chapter introduction schedule

| Ch | New enemies |
|---|---|
| 1 | Mote, Husk, Lancer, Spitter |
| 2 | Swarmling, Stalker, Nettle, Weaver |
| 3 | Wisp, Ripper, Bulwark, **Rift Maw** |
| 4 | Cinder Mote, Bounder, Longeye, Chanter |
| 5 | Shellback, Thresher, Mortarite, **Echo** |
| 6 | Ironmaw, Screecher, Knitter, **Warden-Fell** |
| 7 | **Gravebound** |
| 8 | **Null** |
| 9–12 | No new base types — instead **Variants**: Frenzied (+60 % speed), Bloated (+120 % HP), Voidtouched (immune to one element), Twinned (splits into two halves on death). Variants recombine the existing 26 into ~104 effective encounters without new art. |

Deliberately front-loaded: all 26 base enemies are seen by chapter 8, so the second half of the
campaign is about *combinations and mastery*, not memorising new sprites. Novelty in the late
game comes from Variants, Boons, and bosses — which are far cheaper to author than new units.
