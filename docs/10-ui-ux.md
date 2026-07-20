# 10 — Complete UI / UX

## 10.0 System rules

**Design tokens** (single source of truth, `lib/core/theme/tokens.dart`):

| Token | Value | Use |
|---|---|---|
| `bgDeep` | `#080B12` | App background |
| `bgPanel` | `#111725` | Cards, sheets |
| `bgRaised` | `#1B2436` | Elevated rows |
| `ink` | `#E8EDF7` | Primary text |
| `inkDim` | `#8E9AB4` | Secondary text |
| `accent` | `#3FE0D0` | **Cyan — player-positive, all primary CTAs** |
| `warn` | `#FFB03A` | **Amber — telegraphs, timers, warnings** |
| `danger` | `#FF4D5E` | **Crimson — lethal, destructive, cursed** |
| `gold` | `#F5C542` | Currency: gold |
| `gem` | `#8B6BFF` | Currency: gems |
| Rarity | slate / cyan / violet / gold / white-hot | Common → Mythic |

**Type.** Two families only. Display: a condensed geometric sans (weights 600/800) for numbers,
titles, and currency. Body: a humanist sans (400/600) for everything else. Scale:
32 / 24 / 18 / 15 / 13 / 11. Numbers are always tabular-figure so counters don't jitter.

**Spacing.** 4 pt base grid, steps 4 / 8 / 12 / 16 / 24 / 32.
**Radius.** 8 (chips) / 14 (cards) / 22 (sheets).
**Touch targets.** Minimum 48 × 48 dp, no exceptions. Anything smaller fails review.

**Safe areas.** All HUD respects notch and gesture insets. The bottom 96 dp of the gameplay
screen is a **no-UI zone** because it is where the left thumb lives.

**Motion.** 180 ms standard, 90 ms for taps, 320 ms for screen transitions, all
`Curves.easeOutCubic`. A "Reduce motion" setting drops all of these to 0 and disables screen
shake and parallax.

**Accessibility (not optional, gated in QA):**
- Colour-blind mode replaces the amber/crimson hue distinction with **shape**: telegraphs become
  dashed outlines, lethal zones become solid-hatched.
- Left-handed mode mirrors the HUD.
- Text scale respects OS setting up to 130 % without clipping.
- All interactive elements carry semantic labels for screen readers on menu screens.
- Damage numbers can be disabled entirely.
- One-handed mode moves all bottom-sheet CTAs within 60 % of screen height.

---

## 10.1 Splash

Full-bleed `bgDeep`. Studio mark centred, then the Quiverfall mark drawn as a single animated
Windline stroke that resolves into the logo (900 ms). No text, no tap-to-continue.

**Duration:** exactly as long as `AppBootstrap` takes, minimum 700 ms, maximum 2,500 ms — after
which the loading screen takes over so the player never stares at a static image.
**Failure state:** if bootstrap throws, this screen shows a retry button and the error code, not
a frozen logo.

## 10.2 Loading

Only shown if bootstrap exceeds 2.5 s (cold start on low-end devices, or a content update).

```
┌──────────────────────────────┐
│                              │
│         [ Windline ]         │   animated stroke, loops
│                              │
│   Preparing the Spire…       │   inkDim, 15pt
│   ▓▓▓▓▓▓▓▓▓▓░░░░░░  62%      │   accent bar, 4dp
│                              │
│   "Momentum builds while     │   rotating gameplay tip
│    you move."                │   every 3.5s
└──────────────────────────────┘
```

Tips are real mechanical advice, rotated from a pool of 40, weighted toward mechanics the player
demonstrably under-uses (read from local telemetry). A loading screen is a free teaching surface.

## 10.3 Login / Account

**Never shown on first launch.** Appears at ~22 minutes (see [03](03-progression.md)) and from
Settings.

```
┌──────────────────────────────┐
│              ✕               │  dismiss is always present, top-left
│   Keep your Warden safe      │  24pt
│   Cloud save across devices  │  15pt inkDim
│                              │
│  [  Continue with Apple  ]   │  iOS only, first on iOS
│  [  Continue with Google ]   │
│  [  Continue with Email  ]   │
│                              │
│         Not now              │  text button, full width, 48dp
└──────────────────────────────┘
```

Guest play is fully featured forever. The only thing an account buys is cloud save and
leaderboards. **"Not now" is a real button with the same tap target as the sign-in buttons** —
not grey 11 pt text in a corner.

## 10.4 Main Menu (The Spire)

The hub. Rendered as a Flame scene (the actual Spire, parallaxed, with the player's equipped
hero idling on a balcony) with Flutter UI overlaid.

```
┌───────────────────────────────────────┐
│ ⚡28/30  🪙 14,２30  💎 640      ⚙  │  top bar, 56dp
├───────────────────────────────────────┤
│                                       │
│        [ 3D-ish Spire scene ]         │  Flame layer
│         hero idle animation           │
│                                       │
│   ┌─────────────────────────────┐     │
│   │      ▶  DESCEND             │     │  primary CTA, accent, 64dp
│   │   Chapter 7 · Stage 12      │     │  resumes exactly where you left
│   └─────────────────────────────┘     │
│                                       │
├───────────────────────────────────────┤
│  🏹     🗼     🎒     🛒     🏆       │  bottom nav, 5 tabs, 64dp
│ Heroes  Spire  Gear  Shop  Compete    │
└───────────────────────────────────────┘
```

**Two-tap rule:** DESCEND is one tap from launch and starts the next unplayed stage. Every other
destination is exactly one tap from here. Nothing in the meta is ever more than two taps deep
from the play button.

**Badges** appear on nav icons only for *claimable* things (a free chest, an affordable upgrade,
an unclaimed quest) — never for offers. A badge that turns out to be an ad is how you teach
players to ignore badges.

**Events rail:** a horizontally scrolling strip above the bottom nav appears only when an event
is live. It is dismissible for the session.

## 10.5 Level Select

```
┌───────────────────────────────────────┐
│ ←   CHAPTER 7 · ARCLIGHT REACH   ⓘ   │
├───────────────────────────────────────┤
│  ●━━●━━●━━◆━━●━━●━━●━━★              │  vertical scrolling path
│  1  2  3  4  5  6  7  BOSS            │  ● normal ◆ elite ★ boss
│                                       │
│  ┌─────────────────────────────┐      │  selected stage card
│  │ Stage 12                    │      │
│  │ ★★☆  Best 2:14              │      │
│  │ Threats: Longeye, Chanter…  │      │  known enemies, from your history
│  │ Drops: T3 mats, Torv shards │      │
│  │ Cost: 6 ⚡  (free — uncleared)│     │
│  │      [   DESCEND   ]        │      │
│  └─────────────────────────────┘      │
└───────────────────────────────────────┘
```

Chapters are horizontally paged; stages scroll vertically within one. The **threat preview is the
key UX decision** — the player picks their hero and arrow with knowledge, which turns loadout
selection from guesswork into strategy. Enemies you have not yet met show as `???`.

Stars: 1 = cleared, 2 = no more than 2 damage instances, 3 = cleared under the par time.

## 10.6 Gameplay

The most important screen in the game. **Rule: at most 12 % of the screen area is UI.**

```
┌───────────────────────────────────────┐
│ ███████████░░░  Room 4/7   🪙 312     │  HP bar (left), room, run gold
│ ┌─┐                                   │  hero portrait + ult charge ring
│ └─┘                                   │
│                                       │
│              [ ARENA ]                │  Flame render, 100% of remaining
│                                       │
│        ← Windlines drawn here →       │
│                                       │
│                                       │
│                              ┌───┐    │
│   ◎                          │ULT│    │  joystick zone (invisible until   
│  (floating joystick)         └───┘    │  touched); ult button right-thumb
└───────────────────────────────────────┘
```

**HUD elements, exhaustively:**
- **HP bar** top-left, 6 dp tall, with a delayed white "damage taken" ghost bar so hits are legible.
- **Draw arc** — a thin ring around the character's feet, filling clockwise. Changes colour at each
  tier (inkDim → accent → white-hot) and *snaps* with a haptic tick at Tier III.
- **Momentum chevrons** — up to 5 small marks trailing the character.
- **Ultimate button** bottom-right, 72 dp, with a radial charge fill. Pulses when ready.
- **Room counter** and **run gold**, top-centre and top-right, 11 pt, low contrast.
- **Damage numbers** — off by default for numbers under 5 % of enemy max HP; crits and Confluence
  hits always show. Confluence hits show `×2 CONFLUENCE` in white-hot.
- **No minimap** (single-screen arenas), **no ability bar** (one ultimate), **no inventory**.

**Joystick:** floating, appears wherever the left thumb lands in the bottom-left 45 % of the
screen, dead zone 8 dp, full deflection at 48 dp. Invisible until touched.

**Feedback stack per hit** (all four, every time): hit-flash on the sprite, a directional impact
particle, a 40 ms freeze-frame on kills only, and a haptic. This is the game-feel budget and
Phase 6 exists to tune it.

## 10.7 Pause

Slides down over a blurred, **fully frozen** game. Opened by a 44 dp button top-right that is
deliberately slightly awkward to hit — accidental pauses mid-fight are worse than a slow
deliberate one.

```
│  PAUSED                        │
│                                │
│  Hero: Iris ★4   Arrow: Twinfang│
│  Boons this run:               │
│  [icon grid, tap for detail]   │  ← the real reason players pause
│                                │
│  🔊 ▓▓▓▓░  🎵 ▓▓░░░  📳 on     │  inline, no submenu
│                                │
│  [    RESUME    ]              │  accent
│  [  Abandon run  ]             │  danger outline, needs confirm
```

Showing the current build is the primary function. Settings are secondary. Abandon requires a
second confirmation naming what will be lost and what will be kept.

## 10.8 Victory

```
│         STAGE CLEAR             │
│         ★ ★ ☆                   │  stars animate in, staggered
│         2:41                    │
│                                 │
│  🪙  +412   ▓▓▓▓▓▓▓  (counting) │  count-up, ~1.2s, audio-synced
│  ⛏  +6 Ironhead                 │
│  💎  +3                         │
│  🔮  +2 Insight                 │
│                                 │
│  Confluences: 34  ·  Best ×3    │  ← mastery feedback, always shown
│                                 │
│  [ ▶ NEXT STAGE ]               │  accent, primary
│  [ 📺 DOUBLE HAUL ]             │  gold outline, secondary
│  [ Return to Spire ]            │  text
```

The **Confluence count** is deliberately given equal weight to the currencies. Telling players
their mastery stat every single run is the cheapest retention mechanic available to us
(see [03 §3.5](03-progression.md)).

The ad button is never the primary CTA and never auto-focused.

## 10.9 Defeat

```
│         YOU FELL                │  not "GAME OVER" — softer framing
│  Room 5 of 7 · The Green Mother │
│                                 │
│  YOU KEEP:                      │  ← leads with the positive, always
│  🪙 186   ⛏ 4 Ironhead   🔮 +1  │
│                                 │
│  ── What got you ──             │
│  Knitter healing outpaced your  │  contextual, from run telemetry
│  damage. Try Toxin or kill      │
│  healers first.                 │
│                                 │
│  [ 📺 REVIVE (free today) ]     │
│  [    RETRY    ]                │
│  [ Return to Spire ]            │
```

**"What got you"** is generated from the run's telemetry — the killing enemy, the dominant damage
source, and whether a known counter existed. It is a coach, not a taunt. This screen is where
players decide whether to quit the session, and a screen that explains rather than blames is
worth more than any offer we could put here.

## 10.10 Shop

Four tabs: **Daily · Gems · Bundles · Cosmetics**. Never a modal, never interruptive, never on
the run path.

- **Daily**: 6 slots, rotating, 2 free (one ad-gated), timer to reset.
- **Gems**: the price ladder, with a clear "best value" tag on the honest best value.
- **Bundles**: max 3 active, each with a real timer that never resets to create fake urgency.
- **Cosmetics**: skins, Windline colour sets, arrival effects. Purely visual, permanently owned.

**Every purchasable shows odds where randomness is involved, in every region.** Pity counters are
displayed on the chest itself, not hidden in a legal sheet.

## 10.11 Inventory / Gear

```
│ ← GEAR                          │
│ ┌───────────────────────────┐   │
│ │  ⟶  TWINFANG  ★IV         │   │  equipped arrow, large
│ │  1.14× dmg · 3 affixes    │   │
│ │  ▸ Weaving +0.32s  🔒     │   │  affix rows with lock toggles
│ │  ▸ Confluent +11%         │   │
│ │  ▸ Keen +3.4%      [↻250] │   │  reroll with live price
│ └───────────────────────────┘   │
│                                 │
│  ALL ARROWS                     │
│  [grid of 12, locked ones dim]  │
│                                 │
│  MATERIALS                      │
│  Ashwood 240 · Ironhead 88 …    │
```

## 10.12 Hero screen

```
│ ← HEROES              [Compare] │
│  ┌────┐  IRIS ★4                │
│  │art │  The Latticeweaver      │
│  └────┘  Lv 42 / 48             │
│  ATK 1,204  HP 2,880  ⚡3.20     │
│                                 │
│  PASSIVE · Weave                │
│  Windlines last 2.6s. Confluence│
│  caps at 5.                     │
│                                 │
│  ULTIMATE · The Lattice   [▶]   │  [▶] plays a 3s preview clip
│                                 │
│  TALENTS                        │
│  ★1 ◉ Long Weave  ○ Bright Weave│  radio pairs, tap to swap
│  ★3 ◉ Cutting     ○ Binding     │
│  ★5 🔒 unlock at ★5             │
│                                 │
│  [ LEVEL UP  90🪙 ]  [ ★ UP 80⧫]│
│  [        EQUIP          ]      │
```

Horizontal carousel across the roster; locked heroes show their shard progress and exactly where
those shards drop. **A locked hero always tells you how to get it** — never just a lock icon.

**Compare** overlays two heroes' stats side by side, which is the feature theorycrafters ask for
in every game in this genre and almost never get.

## 10.13 Settings

Grouped, flat, no nesting deeper than one level.

**Audio** — Music, SFX, UI volume (independent sliders), Haptics on/off.
**Graphics** — Quality (Auto / High / Balanced / Battery), FPS cap (30/60/120), Particle density,
Screen shake, Damage numbers, Reduce motion.
**Gameplay** — Auto-aim strength (Off / Light / Standard / Strong), Left-handed HUD, Joystick
size, One-handed mode, Auto-use ultimate.
**Account** — Sign in, Cloud save status with last-sync time, Restore purchases, Delete account.
**Legal** — Privacy, Terms, Ad consent (re-openable at any time), Data export.
**Support** — Player ID (tap to copy), Contact, Version + build hash.

**Auto-aim strength being a player-facing setting** matters: Standard for most, Off for the
players who want the full ceiling, Strong as an accessibility affordance.

## 10.14 Achievements

Three tabs: **Progress · Marks · Collection**.
- Progress: 180 achievements, categorised, each with a bar and a gem reward.
- **Marks**: the 25 mastery passives from [04 §4.5](04-upgrades.md), with 6 equip slots at top.
- Collection: heroes, arrows, enemies (a bestiary that fills in as you meet them, with the stats
  from [05](05-enemies.md)), Boons, and synergy sets discovered.

The bestiary is the quiet star here — it converts the enemy design work into player-facing
content at nearly zero extra cost, and it is where a stuck player goes to learn a counter.

## 10.15 Leaderboard / Compete

Three tabs: **Cohort · Global · Friends**.
- **Cohort** is the default: 50 players of similar power, re-drawn weekly. A mid-tier player sees
  themselves at rank 12 of 50, not 480,000 of 3 million.
- Endless Descent depth ladder, weekly event ladder, and speedrun ladders per chapter.
- Each entry shows hero, arrow, and depth — **tap any entry to view their build**. Build-sharing
  is free content and drives the metagame conversation.

## 10.16 Events

A hub with the live event's own art, rules, ladder, and shop. One major event at a time, max one
minor. Every event states its **end time in the player's local timezone** and its full reward
list up front.

## 10.17 Daily Rewards

A 28-tile grid, current day highlighted, anchors (7/14/21/28) rendered larger. Claim is a single
tap with a satisfying burst. **No streak-break punishment** — the copy says "Day 12 of 28", never
"Don't lose your streak!".

## 10.18 Battle Pass

```
│  SEASON 1 · THE LONG NIGHT      │
│  Tier 24/60      ends in 31d    │
│  ▓▓▓▓▓▓▓▓░░░░░░░  2,140/2,500   │
│                                 │
│  ┌──┬──┬──┬──┬──┐               │  horizontal scroll, current centred
│  │🪙│💎│⧫ │🎨│🏹│  FREE         │
│  ├──┼──┼──┼──┼──┤               │
│  │💎│⧫ │🎨│💎│👤│  PREMIUM 🔒   │
│  └──┴──┴──┴──┴──┘               │
│  [ UNLOCK PREMIUM · 990💎 ]     │
│  [ Claim all available ]        │
```

Progress comes from playing, not from daily-quest-only grinding. The free track is genuinely
worth claiming (~300 gems + materials per season), because a free track that is visibly worthless
makes the paid track feel like a hostage situation rather than an upgrade.

## 10.19 Screen inventory summary

| Screen | Type | Flame layer | Offline |
|---|---|---|---|
| Splash | Full | No | Yes |
| Loading | Full | No | Yes |
| Login | Sheet | No | N/A |
| Main Menu / Spire | Full | **Yes** | Yes |
| Level Select | Full | No | Yes |
| Gameplay | Full | **Yes** | Yes |
| Pause | Overlay | Frozen | Yes |
| Victory | Overlay | Frozen | Yes |
| Defeat | Overlay | Frozen | Yes |
| Shop | Full | No | Read-only |
| Inventory | Full | No | Yes |
| Hero | Full | **Yes** (portrait) | Yes |
| Settings | Full | No | Yes |
| Achievements | Full | No | Yes |
| Leaderboard | Full | No | Cached |
| Events | Full | No | Cached |
| Daily Rewards | Sheet | No | Yes |
| Battle Pass | Full | No | Cached |
| Spire (upgrades) | Full | **Yes** | Yes |

**19 screens.** The entire game except Shop, Leaderboard, Events, and Battle Pass is fully
playable offline, and those four degrade to cached read-only rather than blocking.
