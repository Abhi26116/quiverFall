# 12 — Technical Architecture

## 12.0 The load-bearing decision

**The game simulation is pure Dart with zero Flutter and zero Flame imports.**

`lib/game/sim/` computes every frame of combat — movement, Draw tiers, Windline geometry,
Confluence resolution, damage, AI, spawning — from a seeded RNG and an input stream. Flame reads
that state and draws it. Flame never owns a fact.

This one constraint buys us four things that are otherwise impossible:

1. **The balance harness** ([02 §2.6](02-economy.md), [09 §9.5](09-skills.md)) can run 10,000 runs
   in CI with no renderer, in seconds.
2. **Determinism** — the same seed plus the same input tape produces the same run, byte for byte.
   Replays, build sharing, and bug reproduction all fall out for free.
3. **Testability** — combat is tested with plain `dart test`, no widget pumping.
4. **Cheat resistance** — server-side run validation becomes possible later by replaying the
   input tape, without rewriting the game.

Anything that makes the sim depend on Flutter is rejected in review. This is the single most
important line in this document.

## 12.1 Toolchain

Verified on this machine (2026-07-19):

| | Version | Note |
|---|---|---|
| Flutter | **3.24.5** (stable) | at `~/development/flutter/bin`, **not on default PATH** — export it |
| Dart | **3.5.4** | |
| Android | Gradle **8.7**, AGP **8.3.2**, Kotlin **1.9.24** | required for the installed JDK 21 |
| iOS | platform **13.0** | Xcode 15.2 constraint (see below) |

**Constraints carried from previous projects on this machine:**
- `Color.withValues()` does **not** exist in 3.24.5 (3.27+ API). Use `withOpacity`.
- Firebase's iOS SDK does not build on Xcode 15.2. **Phase 0 must verify this before committing
  to Firebase Analytics**; the fallback is a pluggable `AnalyticsPort` with a Firebase adapter on
  Android and a deferred/queued adapter on iOS. The architecture below assumes the port exists
  either way, so this risk cannot become a rewrite.

**Package selection is deferred to Phase 0**, which does nothing but resolve and lock the
dependency set against Flutter 3.24.5 and record the result in `pubspec.lock` + a decision note.
Intended set: `flame` (render), `flutter_riverpod` (app state), `go_router` (routing),
`get_it` (composition root), `freezed` + `json_serializable` (models), `hive_ce` or `isar`
(local store — benchmarked in Phase 0), `google_mobile_ads`, `in_app_purchase`,
`audioplayers` or `flame_audio`, `firebase_*` (pending the iOS check). **I will not assert
version numbers I have not resolved** — Phase 0 produces them.

## 12.2 Folder structure

Feature-first, with a hard boundary between the simulation and everything else.

```
lib/
├─ main.dart                         # runApp only
├─ bootstrap.dart                    # DI, error zone, remote config, save load
│
├─ core/
│  ├─ di/                            # get_it registrations, one file per layer
│  ├─ routing/app_router.dart        # every route, one file (11 §11.5)
│  ├─ theme/                         # tokens.dart, typography, component themes
│  ├─ result.dart                    # Result<T,E>, no exceptions across layers
│  ├─ clock.dart                     # injectable Clock — never DateTime.now() directly
│  ├─ rng.dart                       # seeded xorshift128+, injectable
│  ├─ logger.dart
│  └─ errors/
│
├─ game/                             # ── PURE DART. No flutter/, no flame/. ──
│  ├─ sim/
│  │  ├─ world.dart                  # SimWorld: entities, tick(dt, input)
│  │  ├─ entity.dart                 # struct-of-arrays entity storage
│  │  ├─ systems/
│  │  │  ├─ movement_system.dart
│  │  │  ├─ draw_system.dart         # Draw tiers + Momentum
│  │  │  ├─ firing_system.dart
│  │  │  ├─ projectile_system.dart
│  │  │  ├─ windline_system.dart     # segment store + spatial index
│  │  │  ├─ confluence_system.dart   # intersection tests
│  │  │  ├─ damage_system.dart       # DamageResolver (08 §8.1)
│  │  │  ├─ element_system.dart      # statuses + reactions
│  │  │  ├─ ai_system.dart           # behaviour trees per enemy family
│  │  │  ├─ spawn_system.dart
│  │  │  ├─ collision_system.dart    # uniform spatial hash, 1.5u cells
│  │  │  └─ boon_system.dart
│  │  ├─ components/                 # plain data: Transform, Health, Draw, Element…
│  │  └─ events/                     # SimEvent stream consumed by the view
│  ├─ balance/                       # curves, formulas, constants — data-driven
│  ├─ content/                       # loaders for enemies/bosses/boons/heroes JSON
│  └─ harness/                       # headless runner for CI balance sims
│
├─ view/                             # ── Flame render layer. Reads sim, owns nothing. ──
│  ├─ quiverfall_game.dart           # FlameGame; ticks the sim, syncs components
│  ├─ renderers/                     # arena, arrows, windlines, enemies, VFX
│  ├─ pools/                         # ComponentPool<T>
│  ├─ camera/
│  └─ hud/                           # Flutter widgets overlaid via GameWidget
│
├─ features/                         # one folder per screen, each with
│  ├─ menu/ level_select/ gameplay/ spire/ heroes/ gear/ shop/
│  ├─ compete/ events/ pass/ achievements/ settings/ daily/ onboarding/
│  │   ├─ presentation/   # widgets + screen
│  │   ├─ application/    # riverpod controllers
│  │   └─ domain/         # feature-local models
│
├─ data/
│  ├─ models/                        # freezed models (13-database.md)
│  ├─ local/                         # save store, migrations, key-value
│  ├─ remote/                        # cloud save, leaderboard, remote config
│  └─ repositories/                  # the only thing features talk to
│
└─ services/
   ├─ audio/  ads/  iap/  analytics/  notifications/  remote_config/
   └─ ports/                         # abstract interfaces for all of the above
```

**Dependency rule:** `features → repositories → data sources`, and `features → game/sim` for
read-only run state. `game/sim` depends on **nothing**. `services/` are reached only through
`ports/` interfaces so every one of them is fakeable in tests and swappable at runtime.

## 12.3 Dependency injection

`get_it` as the composition root, registered in `bootstrap.dart` in four ordered phases:

```dart
Future<void> bootstrap() async {
  registerCore();        // Clock, Rng, Logger, Result plumbing
  await registerData();  // local store open + migrate, repositories
  registerServices();    // audio, ads, iap, analytics, remote config (via ports)
  registerGame();        // content loaders, balance tables, sim factory
}
```

Riverpod providers read from `get_it` at the edge; nothing inside a feature news up a dependency.
Every service is registered as its **port interface**, never its implementation, so:

- Tests inject `FakeAdsService`, `FrozenClock`, `SeededRng`.
- The balance harness registers a null audio/ads/analytics set and runs headless.
- The iOS Firebase risk (§12.1) is absorbed by swapping one registration.

## 12.4 The game loop

```
Flutter vsync
   └─ FlameGame.update(dt)
        ├─ clamp dt to 33.3ms                     (never simulate a stall)
        ├─ accumulate into fixed-step accumulator
        ├─ while (acc >= 1/60):  sim.tick(1/60, inputSnapshot)   ← FIXED STEP
        │      └─ systems run in a fixed, documented order
        ├─ drain sim.events → view (spawn VFX, play SFX, shake)
        └─ interpolate render transforms by (acc / step)          ← smooth at any FPS
```

**Fixed 60 Hz simulation with render interpolation.** Non-negotiable, because determinism
(§12.0) requires it. A 120 Hz device renders interpolated frames of a 60 Hz sim; a struggling
device runs at most 2 catch-up ticks per frame and then accepts slow-motion rather than a
spiral of death.

**System order** (fixed, and asserted in a test):
input → movement → draw/momentum → firing → projectile → windline → confluence → collision →
damage → element → ai → spawn → boon → cleanup.

## 12.5 State management

Three tiers, deliberately different technologies, because they have genuinely different needs:

| Tier | Holds | Tech | Rebuild rate |
|---|---|---|---|
| **Sim state** | Everything in a live run | Plain Dart objects in `SimWorld` | 60 Hz |
| **HUD state** | HP, Draw tier, ult charge, room, gold | `ValueNotifier`s pushed from sim events | ~10 Hz, targeted |
| **App state** | Save, currencies, roster, settings, shop | Riverpod `AsyncNotifier` | On change only |

**The HUD does not rebuild at 60 Hz.** Each HUD element listens to its own `ValueNotifier`, so a
Draw-tier change repaints a 40 dp ring and nothing else. Rebuilding a widget tree every frame is
the number-one cause of jank in Flutter games and we design it out rather than optimise it later.

**Riverpod never touches the sim.** A provider that reads live combat state would rebuild the
tree at 60 Hz; the boundary is enforced by the fact that `game/sim` has no Riverpod import.

## 12.6 Asset loading

Three tiers by urgency:

| Tier | Contents | When | Budget |
|---|---|---|---|
| **Boot** | UI atlas, fonts, menu music, tokens, save | Splash | < 2.5 s, < 24 MB |
| **Stage** | Chapter atlas, enemy atlases for that chapter's roster, battle track | Level Select → Loadout | < 1.2 s, < 40 MB |
| **Lazy** | Boss atlas, rare VFX, cosmetics | Prefetched during the previous room | off the critical path |

- **Texture atlases** are packed per chapter and per enemy family; a single arena draws from
  ≤ 4 atlases so the batcher rarely breaks.
- **Boss assets prefetch during room N−1**, so the boss transition never stutters.
- **Everything is bundled** — no runtime downloads at launch, no CDN dependency for core play.
  (This is a direct lesson from the `arrows-game` post-mortem, where runtime font fetching broke
  the app offline.)
- Unused chapter atlases are evicted on Menu return, capped at 3 resident chapters.

## 12.7 Save system

**Local is the source of truth. Cloud is a backup.** Never the reverse — a network hiccup must
never cost progress.

- **Format:** binary via the local store, one `PlayerSave` root document + append-only run log.
- **Cadence:** on every meaningful mutation (purchase, level-up, run end), debounced to 400 ms;
  plus a full flush on `AppLifecycleState.paused`.
- **In-run snapshot:** the sim serialises a resume point at every room boundary (~2 KB). This is
  what powers crash recovery ([11 §11.4](11-screen-flow.md)).
- **Migrations:** every save carries `schemaVersion`. Migrations are ordered, forward-only, and
  each one has a test with a real captured save from the previous version.
- **Corruption:** three rotating backup slots. On a failed read, fall back to the newest valid
  slot and report `save_recovered` to analytics.
- **Cloud conflict:** never resolved silently. The player is shown both saves with timestamps and
  progress summaries and chooses ([11 §11.4](11-screen-flow.md)).
- **Integrity:** an HMAC over the save with a device-derived key. This deters casual editing; it
  is explicitly **not** anti-cheat. Real anti-cheat is server-side run replay, and it is a
  post-launch concern that §12.0 leaves the door open for.

## 12.8 Audio manager

`AudioService` behind `AudioPort`. Four buses — Music, SFX, UI, Ambience — each with an
independent volume, all multiplied by a master.

- **Music:** two decks with crossfade, so combat → boss is a 1.2 s musical transition rather than
  a cut. Boss stingers are layered on top of the running track (see [16](16-audio-direction.md)).
- **SFX:** pooled players, hard cap of **24 concurrent voices**, priority-based eviction (a
  Confluence chime always beats the 19th arrow impact).
- **Voice-limiting per sound:** identical SFX within 40 ms collapse into one at +2 dB rather than
  stacking into mush — critical for a game that fires 3 arrows/second with multishot.
- **Ducking:** ads, calls, and other-app audio duck to −40 dB and restore.
- **Respects the OS silent switch** on iOS. Games that ignore it get one-star reviews.

## 12.9 Ads manager

`AdsService` behind `AdsPort`.

- **Preloaded always:** one rewarded ad kept warm at all times, refilled immediately after use.
  A rewarded button that spins is a broken promise.
- **Never fires during a run.** Structurally enforced: `AdsPort.showRewarded()` throws in debug
  and no-ops in release if `RunCoordinator.isRunActive` is true.
- **Reward delivery is transactional** — the reward is written to the save *before* the ad UI
  dismisses, and pending rewards survive a crash.
- Consent (ATT / GDPR / UMP) is requested at the right moment, not on first launch, and is
  re-openable from Settings.
- **One interstitial placement in the whole game**, detailed in [17](17-monetization.md).

## 12.10 Analytics manager

`AnalyticsService` behind `AnalyticsPort`, with a **local queue** so events survive offline play
and are flushed in batches. Every event is a typed Dart class, never a raw string map — the
[18](18-analytics.md) schema is generated from those classes so the doc cannot drift from the
code. See §12.1 for the iOS Firebase contingency.

## 12.11 Object pooling

Pooling is not an optimisation here; it is the design. Allocation during combat is the primary
source of GC jank on low-end Android.

| Pool | Initial | Max | Notes |
|---|---|---|---|
| Arrows | 64 | 256 | Multishot + Mirelle duplication spike hard |
| Windline segments | 256 | 1,024 | The heaviest pool; ring buffer, oldest expires first |
| Enemies | 48 | 160 | Per-family sub-pools (different component sets) |
| Damage numbers | 32 | 96 | Aggressive recycle |
| Particles | 512 | 2,048 | Density scales with the graphics quality setting |
| SFX players | 24 | 24 | Fixed, matches the voice cap |

Rules: pools are pre-warmed during the loading screen, never grown mid-room (a miss returns a
no-op object and logs). `SimWorld` uses **struct-of-arrays** storage for hot components so a
system iterates contiguous memory instead of chasing object pointers.

**Zero-allocation target in the steady state:** no `new` in any system's `update()`. Enforced by
a profiling test that runs 600 sim ticks and asserts allocation delta is under a threshold.

## 12.12 Level generator

Detailed in [14](14-level-design.md). Architecturally: `LevelGenerator.generate(StageRef, seed)`
returns a fully-specified `StageBlueprint` (arena layouts, spawn tables, timings, Boon pools) as
plain data. It is pure, deterministic, and testable — and because it runs before the room does,
generation never costs frame time.

## 12.13 Performance strategy

Summarised here, detailed in [19](19-performance.md):

1. Fixed-step sim + render interpolation (§12.4).
2. Zero steady-state allocation (§12.11).
3. Targeted HUD repaints via `ValueNotifier`, never full-tree rebuilds (§12.5).
4. Atlas discipline: ≤ 4 texture binds per arena (§12.6).
5. Spatial hash for all collision and Confluence queries — never O(n²).
6. Windline intersection tests only against segments in adjacent hash cells, and only for
   segments newer than the arrow.
7. Quality tiers auto-selected from a device benchmark on first launch, overridable in Settings.
8. A frame-time budget assertion in profile builds that logs any frame over 16.6 ms with the
   system-level breakdown.
