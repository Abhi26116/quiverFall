# 16 — Audio Direction

## 16.0 Concept

**"Struck metal and held breath."** The palette is bowed metal, prepared piano, taiko and frame
drums, granular choir, and a single detuned synth bass. No orchestral swell, no rock guitar — the
game is about tension and release at a two-second cadence, and the score has to breathe at that
rate.

**The governing rule: the mix belongs to gameplay.** Music sits at −14 LUFS and ducks under
combat SFX. A player who turns the music off must lose atmosphere but **never information** —
every mechanically important event has a visual counterpart, and every one also has a sound,
because roughly 40 % of mobile players run silent and the other 60 % should be rewarded for
listening.

## 16.1 Music

### Tracks

| Track | Length | Loop | Mood |
|---|---|---|---|
| **Main theme** (splash/title) | 1:40 | No | Solemn, single bowed motif that becomes the Windline sound |
| **Menu / The Spire** | 3:20 | Yes | Sparse, warm, low pulse. Must be tolerable for 20 minutes |
| **Battle — Chapters 1–4** | 2:40 | Yes | Mid-tempo 110 BPM, driving frame drum |
| **Battle — Chapters 5–8** | 2:50 | Yes | 122 BPM, layered choir |
| **Battle — Chapters 9–12** | 3:00 | Yes | 132 BPM, distorted bass |
| **Elite room** | 1:20 | Yes | Held dissonance, tempo unchanged from the battle track |
| **Boss — standard** | 3:30 | Yes | 3 layered stems, one per phase |
| **Boss — The Quiverfall** | 4:10 | Yes | Bespoke, full choir |
| **Boss — The Last Warden** | 4:40 | Yes | 5 stems, one per phase; reprises the main theme |
| **Endless Descent** | 5:00 | Yes | Slowly detuning; the deeper you go the more it drifts |
| **Victory** | 0:12 | No | Rising fifth, resolves |
| **Defeat** | 0:09 | No | Falls to a single unresolved note |
| **Event themes** | 2:30 ea | Yes | 4 at launch |

**14 tracks, ~38 minutes.**

### Adaptive layering

Battle tracks are **3-stem vertical layers**, not linear loops:

- **Base** — drums + bass. Always playing.
- **Mid** — melodic layer. Fades in above 40 % room progress.
- **High** — choir + lead. Fades in above 75 % progress, or instantly when the player reaches
  **Draw Tier III**.

Tying the high stem to Tier III is the score's best idea: the music physically rewards the
player's core mechanic. Standing still to Draw makes the music bloom. It costs nothing to
implement and it teaches the mechanic subconsciously.

**Boss phases** crossfade stems at the 66 % and 33 % transitions over 1.2 s, timed to land on a
bar boundary — the transition sounds composed rather than cut.

## 16.2 SFX — combat

### The player

| Sound | Character |
|---|---|
| Draw Tier I fire | Dry snap, short, ~90 ms |
| Draw Tier II fire | Deeper snap + a low tail |
| **Draw Tier III fire** | Heavy thrum with a metallic bloom — unmistakable, this is the reward sound |
| Draw tier-up tick | Soft rising pip at each tier, plus a haptic |
| **Confluence ×1** | Clear bell, ~1.2 kHz |
| **Confluence ×2** | Bell + fifth |
| **Confluence ×3** | Bell + fifth + octave, with a short reverse-swell |
| **Confluence ×4/×5** (Iris) | Full chord, white-noise bloom |
| Momentum stack gain | Very soft wind-tick, barely audible, stacking pitch |
| Max Momentum | Low whoosh |
| Ultimate ready | Two-note rising chime |
| Ultimate cast | Per hero, 20 bespoke sounds |
| Hit taken | Muffled thud + a brief high-frequency duck of everything else |
| Death | Everything ducks to −30 dB, single sustained low tone |

**The Confluence bell chord is the single most important sound in the game.** It rises in pitch
and richness with stack count, so a skilled player hears their own execution improving. A player
with the screen half-obscured by their thumb still knows they threaded the shot.

### Arrows and elements

Per arrow type (×12): release, flight loop, impact, and a Windline "sustain" bed. Elements each
carry ignition, tick, and expiry sounds. The seven reactions each have a bespoke one-shot —
Steamburst hisses, Superconduct cracks, Prismbreak is a chord.

**Prismshaft's four element sounds are tuned to a rising major arpeggio**, so a full four-shot
cycle is musically satisfying. This is the kind of detail that makes an arrow feel good to use
independently of its numbers.

### Enemies

Per enemy (×26): spawn, idle/move loop, **attack telegraph**, attack, hit, death.
**≈ 156 enemy sounds.**

The telegraph sound is the most important of the six. Every telegraph has a distinct, rising,
directional cue — a Lancer's charge wind-up, a Longeye's charging whine, a Mortarite's launch
thump. **A player should be able to survive a room with their eyes closed for two seconds.**
Family-shared timbres mean 26 enemies read as 6 recognisable threat classes.

### Bosses

Per boss (×20): entrance roar, 3 phase-transition stingers, 3–5 attack telegraphs, 3–5 attacks,
hit, stagger, death. **≈ 300 boss sounds.**

## 16.3 SFX — UI

Tap, back, tab switch, toggle, slider detent, error, disabled-tap.
Currency: gold tick (rapid, pitched-up per 10), gem chime, material clink.
Rewards: chest open (3 escalating tiers by rarity), star-up, level-up, achievement, Mark unlock,
**Boon card reveal (5 rarity-specific stings — Mythic is a held white-noise swell that stops the
music for 400 ms)**.
Menus: Spire upgrade purchase (a satisfying mechanical clunk, deliberately over-designed since
players trigger it hundreds of times), hero equip, arrow refine, affix reroll.

**≈ 45 UI sounds.**

Every count-up on the Victory screen is **audio-synced to the number animation**, and the pitch
rises with the total. It is the cheapest dopamine in game development and there is no reason not
to do it well.

## 16.4 Ambience

Per chapter (×12): a background bed — wind, distant collapse, embers, dripping. Sits at −32 dB,
mono, and exists to make silence not feel like a bug.

## 16.5 Mix

| Bus | Default | Notes |
|---|---|---|
| Master | 0 dB | |
| Music | −14 LUFS | Ducks 4 dB under combat |
| SFX | −8 LUFS | |
| UI | −10 LUFS | Never ducked — feedback must always land |
| Ambience | −32 dB | |

**Rules:**
- 24 concurrent voices maximum, priority-evicted. Confluence and telegraph sounds hold the
  highest priority and are never evicted.
- Identical sounds within 40 ms collapse into one at +2 dB rather than stacking — essential when
  Mirelle is firing 8 duplicated arrows a second.
- Sidechain: player-hit ducks everything 6 dB for 180 ms.
- **The OS silent switch is respected on iOS.** Non-negotiable.
- Audio is ducked and restored around ads, calls, and other apps' playback.

## 16.6 Haptics

Haptics carry a real information channel, not just flavour:

| Event | Pattern |
|---|---|
| Draw Tier II | Light tick |
| **Draw Tier III** | Medium tick — the player feels the ramp without looking |
| Confluence | Sharp double-tick, scaling with stacks |
| Hit taken | Heavy thud |
| Low HP (< 25 %) | Slow rhythmic pulse, 1/s |
| Kill | None (far too frequent) |
| Boss phase change | Long heavy |
| Reward claim | Light double |

Fully disableable, and disabled by default on devices with poor haptic hardware (detected at
boot).

## 16.7 Production

| Item | Count | Notes |
|---|---|---|
| Music | 14 tracks, ~38 min | Composed as stems from the start |
| Combat SFX | ~180 | |
| Enemy SFX | ~156 | Family-shared timbres |
| Boss SFX | ~300 | |
| UI SFX | ~45 | |
| Ambience | 12 | |
| **Total** | **~700 assets, ~48 MB** | OGG Vorbis q5 for SFX, q7 for music |

**Sequencing:** placeholder audio from Phase 2 (real sounds only for Draw tiers and Confluence,
because their *feel* is part of what Phase 6 is testing). Full pass in Phases 13 and 17.
Localisation: no voice acting anywhere in the game, which removes localisation cost entirely and
is a deliberate scope decision.
