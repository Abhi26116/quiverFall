# 15 — Art Direction & Asset Manifest

## 15.0 The style: "Luminous ink"

Hand-inked silhouettes with heavy outlines over flat colour, lit entirely by emissive VFX.
A woodblock print struck by lightning.

**Five rules that define the look:**

1. **Silhouette first.** Every character and enemy must be identifiable as a pure black shape. If
   it isn't, the design is wrong — not the rendering.
2. **Flat fills only on units.** 2–4 colour zones plus a thick dark outline. No gradients, no
   rendered lighting, no normal maps. Depth comes from overlap and from emissive VFX.
3. **The background is stage, never noise.** Desaturated, cool, low contrast. It sits ~35 % value
   below anything gameplay-relevant.
4. **VFX own the entire colour budget.** Arrows, Windlines, Confluence, elements, and telegraphs
   are the only saturated things on screen.
5. **The semantic palette is inviolable.** Amber = incoming threat. Crimson = lethal now.
   Cyan = yours/good. Violet = rare. Gold = currency and mastery. Learned in 30 seconds, never
   broken anywhere in the game.

This style is chosen as much for production reality as for aesthetics: flat fills and additive
particles are cheap to draw at 60 FPS on a 2019 Android, cheap to author consistently, cheap to
recolour for variants, and readable on a 5.5" screen in daylight.

## 15.1 Colour

| Role | Hex | Use |
|---|---|---|
| Void | `#080B12` | Deepest background |
| Slate | `#1B2436` | Arena floor |
| Ash | `#39435A` | Walls, cover |
| Bone | `#E8EDF7` | Highlights, UI text |
| **Amber** | `#FFB03A` | **All telegraphs, everywhere** |
| **Crimson** | `#FF4D5E` | **All lethal geometry** |
| **Cyan** | `#3FE0D0` | Player-positive, base Windline |
| Ember | `#FF6B2C` | Fire element |
| Rime | `#5CC8FF` | Frost element |
| Storm | `#B58BFF` | Storm element |
| Blight | `#8FE04A` | Toxin element |
| White-hot | `#FFFFFF` | Confluence, crits, Mythic |
| Gold | `#F5C542` | Currency, mastery |

Enemy families are colour-coded by hue family so a player reads threat type peripherally:
Drift = violet-grey, Carapace = steel-blue, Rush = rust-red, Salvo = ochre, Choir = pale green,
Riftborn = black with the element's accent.

## 15.2 Asset manifest

### Characters (heroes)

Per hero (×20):

| Asset | Frames / spec |
|---|---|
| Idle | 8 frames, loop |
| Run (8-dir, sheared 2-dir + flip) | 8 frames |
| Draw tier I / II / III poses | 3 static + 4-frame transitions |
| Fire | 4 frames |
| Ultimate cast | 12 frames |
| Hit | 2 frames |
| Death | 10 frames |
| Portrait (menu) | 1 × 512² |
| Portrait (HUD) | 1 × 128² |
| Silhouette icon | 1 × 64² |

**≈ 51 sprites/hero × 20 = ~1,020 hero sprites.** Authored at 4× on a 96 px reference height.
Star tiers recolour trim only — no new art.

### Enemies

Per enemy (×26 base):

| Asset | Frames |
|---|---|
| Idle | 4 |
| Move | 6 |
| Attack / telegraph | 6 |
| Hit | 2 |
| Death | 8 |
| Special (plate break, enrage, revive, adapt) | 4–8 where applicable |
| Bestiary portrait | 1 × 256² |

**≈ 30 sprites/enemy × 26 = ~780.** The 4 Variants (Frenzied, Bloated, Voidtouched, Twinned) are
**shader/tint + scale only — zero new art**, which is how 26 enemies become ~104 encounters.

### Bosses

Per boss (×20): 3 phase forms × (idle 6, move 6, 3 attacks × 8, transition 12, death 20)
≈ **110 sprites/boss ≈ 2,200 total**. Authored at 3× the size of a normal enemy.
Bosses 13–20 reuse campaign boss skeletons with new silhouette parts and full VFX replacement —
roughly 40 % of the cost of an original.

### Backgrounds

12 chapters × 3 parallax layers × 2 variants = **72 background plates** at 2048 × 1152.
Plus 60 arena floor/wall tilesets (shared across chapters, recoloured per chapter).
Chapter identity comes from palette + one silhouette motif, not from unique geometry.

### Effects & particles

| Category | Count | Notes |
|---|---|---|
| Arrow trails | 12 | One per arrow type |
| **Windline** | 6 | Base + 4 elements + Confluence-charged |
| **Confluence** | 5 | ×1 through ×5, escalating |
| Elemental impacts | 4 × 6 frames | Ember / Rime / Storm / Blight |
| Reactions | 7 | Steamburst, Firestorm, Blightfire, Superconduct, Rime Rot, Corrosive Arc, Prismbreak |
| Telegraphs | 9 | Line, cone, ring, expanding ring, triangle, beam, grid cell, landing marker, tether |
| Hit sparks | 6 | By damage magnitude |
| Death bursts | 6 | One per enemy family |
| Ultimate VFX | 20 | One per hero, the most expensive VFX in the game |
| Boon pickup / set complete | 8 | |
| Environmental | 12 | Ash fall, embers, sparks, dust |
| UI particles | 10 | Currency bursts, level-up, star-up, chest open |

**≈ 150 effect definitions.** All additive-blended, all pooled, all density-scalable by the
graphics quality setting.

**The Windline and Confluence VFX are the highest-priority art in the entire project.** They are
the game's identity, they are on screen constantly, and if they read as noise the core mechanic
fails. They get a dedicated art review and are tuned in Phase 6 against real device screens in
daylight, not on a monitor.

### UI

| Category | Count |
|---|---|
| Icons — currencies, materials, stats | 40 |
| Icons — Boons | **112** (one per Boon, silhouette-based) |
| Icons — Marks, research, achievements | 235 |
| Icons — navigation, actions, system | 60 |
| Panels, frames, rarity borders (9-slice) | 35 |
| Buttons (5 states × 6 types) | 30 |
| Progress bars, meters, the Draw arc | 18 |
| Chest and reward art | 14 |
| Event and battle-pass banners | 20 per season |
| Store front | 1 icon set, 8 screenshots, 1 feature graphic, 2 preview videos, per platform |

**≈ 545 UI assets** at launch. Boon icons are the largest single art task in the UI and are
authored from a shared silhouette kit to keep them consistent and fast.

### Fonts

Two families, **bundled in the app, never fetched at runtime** — this is a direct lesson from
`arrows-game`, where runtime font fetching broke the UI offline.

- **Display:** condensed geometric sans, weights 600/800, tabular figures. Titles, numbers, currency.
- **Body:** humanist sans, 400/600. Everything else.
- Both must ship with Latin Extended, Cyrillic, and Greek; CJK is a separate lazily-bundled
  fallback loaded only for those locales.

### Animation

- **Sprite sheets** for all characters, enemies, and bosses. Packed into 2048² atlases, grouped
  per chapter and per family so an arena draws from ≤ 4 texture binds.
- **Skeletal animation is deliberately not used.** Sprite sheets cost more memory but far less CPU,
  and CPU is the binding constraint on our low-end target ([19](19-performance.md)).
- **UI animation is code-driven** (implicit animations + a small tween library), not exported
  clips.
- 60 FPS authoring for VFX, 24 FPS for character sprites — the eye does not need more, and it
  saves ~55 % of frame memory.

## 15.3 Total asset budget

| Category | Count | Est. packed size |
|---|---|---|
| Heroes | 1,020 sprites | 42 MB |
| Enemies | 780 sprites | 26 MB |
| Bosses | 2,200 sprites | 68 MB |
| Backgrounds | 72 plates + 60 tilesets | 55 MB |
| Effects | ~150 definitions | 18 MB |
| UI | ~545 assets | 12 MB |
| Fonts | 2 families | 3 MB |
| Audio | see [16](16-audio-direction.md) | 48 MB |
| **Total** | | **≈ 272 MB** |

**Ship target: under 180 MB installed.** Achieved by ASTC/ETC2 texture compression, shipping only
chapters 1–4 in the base bundle (~95 MB) and delivering chapters 5–12 via Play Asset Delivery /
On-Demand Resources, prefetched while the player is still in chapter 3. **The base download must
stay under 150 MB** so it installs over cellular without a warning — that threshold measurably
affects install conversion.

## 15.4 Production plan

| Wave | Content | Blocks |
|---|---|---|
| **W1 — Greybox** | Placeholder shapes for everything, real VFX for Windline/Confluence only | Phases 2–6 |
| **W2 — Vertical slice** | Chapter 1 final: 4 heroes, 8 enemies, 1 boss, 1 background set, full UI | Phase 7 |
| **W3 — Campaign** | Chapters 2–8, 12 more heroes, 18 enemies, 8 bosses | Phases 8–13 |
| **W4 — Endgame** | Chapters 9–12, 4 heroes, 11 bosses, Endless art | Phases 14–16 |
| **W5 — Polish** | Cosmetics, event art, store assets, localisation art | Phases 17–18 |

**Greybox first is not a compromise, it is the plan.** The Draw/Momentum feel and the Confluence
readability must be proven with placeholder art before a single final sprite is commissioned —
because if the mechanic changes, the art is wasted. The one exception is the Windline/Confluence
VFX, which must be near-final in Phase 6 precisely because *their readability is part of the
mechanic being tested*.
