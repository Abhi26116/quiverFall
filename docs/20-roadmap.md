# 20 — Development Roadmap

## 20.0 How to read this

**19 phases (0–18).** Each has objectives, the files it creates, an estimate, and its
dependencies. Estimates are in **working days for one developer** and assume the design work in
this GDD is already done (it is) and that art arrives as greybox until Phase 7.

**The rules of this roadmap:**

1. **Each phase ends with something runnable and tested.** No phase ends with "half of a system".
2. **`flutter analyze` clean and all tests green is the definition of phase-complete.** Not
   "mostly working".
3. **Phase 6 (Game Feel) is not compressible.** If the schedule slips, content phases shrink;
   Phase 6 does not. This category is won on feel, and a well-architected game that feels bad is
   a failure.
4. **Nothing after Phase 12 may break the balance harness.**
5. Phases are sequenced so the **core mechanic is provable by day ~35**, before any content
   investment. If the Draw/Confluence loop is not fun at Phase 6, we stop and redesign — cheaply.

**Total: ~205 working days (~10 months solo).** With a 3-person team (1 eng, 1 artist, 1
designer/producer) running Phases 7+ in parallel with art production, ~5.5 months to soft launch.

---

## Phase 0 — Toolchain & dependency lock · **2 days** · no deps

**Objectives.** Resolve every dependency against Flutter 3.24.5 / Dart 3.5.4 and lock it. Prove
the risky ones build on this machine *before* any architecture depends on them.

- Verify Flame's latest 3.24.5-compatible version; record it.
- **Verify whether Firebase iOS builds under Xcode 15.2** (it did not for `arrows-game`). Decide:
  upgrade Xcode, or ship the `AnalyticsPort` with a deferred iOS adapter.
- Benchmark Hive CE vs Isar for save read/write on the reference device; pick one.
- Android: Gradle 8.7 / AGP 8.3.2 / Kotlin 1.9.24 (JDK 21). iOS platform 13.0.
- Confirm `Color.withValues` is unavailable; add a lint rule banning it.

**Files.** `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `android/` + `ios/` config,
`docs/decisions/0001-toolchain.md`.

**Exit.** A hello-world Flame app builds and runs on a real Android device and an iOS simulator.

> This phase exists because two prior projects on this machine lost time to exactly these
> problems. Two days here saves two weeks later.

---

## Phase 1 — Core foundation · **6 days** · deps: 0

**Objectives.** The skeleton every other phase plugs into.

- `get_it` composition root, four-phase bootstrap.
- `go_router` with all 19 routes and their guards ([11 §11.5](11-screen-flow.md)).
- Design tokens, typography, component themes ([10 §10.0](10-ui-ux.md)).
- `Result<T,E>`, injectable `Clock`, seeded `Rng`, logger, error zone.
- All freezed models from [13](13-database.md).
- Local store, save/load, backup rotation, migration framework.

**Files.** `main.dart`, `bootstrap.dart`, `core/**`, `data/models/**`, `data/local/**`,
`data/repositories/**`. ~45 files.

**Exit.** App boots to a placeholder menu, writes and reloads a save, survives a forced corruption
of the primary slot. Migration framework has a passing test with a synthetic v1→v2 save.

---

## Phase 2 — Simulation skeleton · **7 days** · deps: 1

**Objectives.** The pure-Dart sim core. **Zero Flutter, zero Flame imports** — enforced by a test
that greps the import graph.

- `SimWorld`, struct-of-arrays entity storage, component definitions.
- Fixed-step tick loop, documented system order, `SimEvent` stream.
- Movement system, input snapshot model, spatial hash.
- Content loaders for `assets/data/*.json` + build-time schema validation.

**Files.** `game/sim/world.dart`, `entity.dart`, `components/**`, `systems/movement_system.dart`,
`systems/collision_system.dart`, `game/content/**`, `game/balance/**`. ~30 files.

**Exit.** A headless test moves an entity around an arena for 600 ticks, deterministically, with
allocation delta under threshold.

---

## Phase 3 — The core mechanic: Draw, Momentum, firing · **6 days** · deps: 2

**Objectives.** The heart of the game, headless.

- Draw tier state machine (I/II/III with the timings from [01](01-vision.md)).
- Momentum stacks, gain and decay.
- Firing system, fire-rate resolution, auto-aim with the four assist strengths.
- Projectile system with pierce and falloff.
- `DamageResolver` with the full formula from [08 §8.1](08-arrows.md).

**Files.** `systems/draw_system.dart`, `firing_system.dart`, `projectile_system.dart`,
`damage_system.dart`, `game/balance/curves.dart`. ~14 files.

**Exit.** Golden-table test of 600 damage cases passes. A headless test drives a full Draw ramp
and asserts tier timings and Momentum decay to the millisecond.

---

## Phase 4 — Windline & Confluence · **7 days** · deps: 3

**Objectives.** The USP. The riskiest system in the project, built early and in isolation.

- Windline segment ring buffer (1,024 cap), spatial-hash insertion, expiry.
- Confluence intersection with all four reductions from [19 §19.2](19-performance.md).
- Confluence stacking, damage multipliers, caps.
- Element application, status tracking, the 7 reactions with per-enemy cooldowns.

**Files.** `systems/windline_system.dart`, `confluence_system.dart`, `element_system.dart`,
`game/sim/geometry/**`. ~12 files.

**Exit.** Intersection correctness tests including degenerate cases (parallel, coincident,
zero-length). Performance test: 60 arrows × 1,024 segments resolves in under 0.8 ms.

---

## Phase 5 — Enemies, AI, spawning · **9 days** · deps: 4

**Objectives.** All 26 enemies from [05](05-enemies.md), fully data-driven.

- Behaviour trees per family (Drift/Carapace/Rush/Salvo/Choir/Riftborn).
- Telegraph system — the shared amber/crimson primitive every enemy and boss uses.
- Plating, shields, auras, healing, adaptation, revival.
- Wave-based spawn system with the composition validator.
- `enemies.json` fully authored.

**Files.** `systems/ai_system.dart`, `spawn_system.dart`, `game/sim/ai/**` (6 family trees),
`game/sim/telegraph.dart`, `assets/data/enemies.json`. ~26 files.

**Exit.** Headless: a generated room populates, all 26 AIs execute for 60 s without error, and
every composition rule from [05 §5.7](05-enemies.md) has a test.

---

## Phase 6 — 🔒 GAME FEEL · **10 days** · deps: 5 · **NOT COMPRESSIBLE**

**Objectives.** Make it feel good. This is the phase the game lives or dies on.

- Minimal Flame renderer — enough to *play*, greybox art.
- Hit feedback stack: flash, impact particle, 40 ms kill freeze-frame, haptic.
- **Near-final Windline and Confluence VFX** — the one art exception, because their readability
  *is* the mechanic being tested.
- Confluence audio: the bell chord, tuned across stack counts.
- Draw arc UI, Momentum chevrons, tier-up haptic ticks.
- Screen shake, camera punch, hit-stop tuning.
- Joystick feel: dead zone, deflection curve, floating origin.

**Files.** `view/quiverfall_game.dart`, `view/renderers/windline_renderer.dart`,
`view/renderers/vfx/**`, `view/hud/draw_arc.dart`, `services/audio/**`. ~28 files.

**Exit — this is a decision gate, not a checklist.** Playtest with 8+ people who have not seen the
game. Measure: does the median tester trigger Confluence within 7 minutes unprompted? Does
`draw_tier_distribution` show real Tier II/III usage? **If Confluence reads as noise, we redesign
now**, having spent ~35 days instead of 200.

---

## Phase 7 — Render layer & pooling · **8 days** · deps: 6

**Objectives.** Production-grade rendering.

- Batched Windline mesh (`drawVertices`, one draw call).
- Batched particle system.
- All pools from [12 §12.11](12-architecture.md), pre-warmed.
- Atlas loading, per-chapter tiering, eviction.
- Camera, parallax, arena compositing.
- Quality tiers + boot benchmark.

**Files.** `view/pools/**`, `view/renderers/**`, `view/camera/**`,
`services/device/benchmark.dart`. ~22 files.

**Exit.** 90 entities + 1,024 segments hold 60 FPS on the reference low-end device. Zero
allocation in the steady state, verified by CI.

---

## Phase 8 — Rooms, arenas, level generator · **8 days** · deps: 7

**Objectives.** [14](14-level-design.md), fully implemented.

- Arena JSON format + loader + geometry validator.
- `LevelGenerator` with the 6-step pipeline and the 8-constraint validator, with fallback.
- Stage templates, room progression, transitions.
- The first 20 arenas authored.
- `RunCoordinator` — the single-flight run lock from [11 §11.5](11-screen-flow.md).

**Files.** `game/level/**`, `assets/data/arenas.json`, `chapters.json`,
`features/gameplay/application/run_coordinator.dart`. ~20 files.

**Exit.** A full 7-room stage plays end to end. Generator produces 10,000 valid blueprints with
zero constraint violations and zero fallbacks in normal conditions.

---

## Phase 9 — Boon system · **7 days** · deps: 8

**Objectives.** All 112 Boons from [09](09-skills.md).

- Effect system: composable modifiers over the [04 §4.1](04-upgrades.md) formula.
- Draw logic with depth scaling and all five anti-frustration rules.
- Synergy set detection, evolution triggers.
- Boon choice UI, rerolls, the Shrine.
- `boons.json` + `synergies.json` fully authored.

**Files.** `systems/boon_system.dart`, `game/sim/effects/**`, `features/gameplay/presentation/
boon_choice.dart`, `shrine.dart`, `assets/data/boons.json`. ~24 files.

**Exit.** Every one of the 112 Boons has a test asserting its effect. Draw rules verified over
100,000 simulated draws.

---

## Phase 10 — Heroes, arrows, loadout · **9 days** · deps: 9

**Objectives.** All 20 heroes and 12 arrows from [07](07-heroes.md) and [08](08-arrows.md).

- Hero stats, 20 passives, 20 ultimates, 120 talent branches.
- Arrow types, crafting, refinement, 18 affixes, reroll with escalating cost.
- Levelling, star-ups, shard economy.
- Hero screen, gear screen, loadout sheet, compare view.

**Files.** `game/sim/heroes/**` (20 passive + 20 ultimate implementations),
`game/sim/arrows/**`, `features/heroes/**`, `features/gear/**`,
`assets/data/heroes.json`, `arrows.json`, `affixes.json`. ~55 files.

**Exit.** All 20 heroes playable with working ultimates. All 12 arrows craftable and refinable.

---

## Phase 11 — Bosses · **12 days** · deps: 10

**Objectives.** All 20 bosses from [06](06-bosses.md).

- Boss framework: phase state machine, attack scheduler, telegraph choreography.
- 12 campaign bosses (3 phases each).
- 4 elite/event bosses.
- 4 Endless bosses, including The Last Warden's 5 phases.
- Bespoke boss arenas, entrance sequences, music stem transitions.

**Files.** `game/sim/bosses/**` (20 implementations + framework),
`assets/data/bosses.json`, boss arena definitions. ~32 files.

**Exit.** All 20 bosses beatable, all phase transitions correct, every attack telegraphed. Each
boss has a test asserting phase thresholds and telegraph lead times.

---

## Phase 12 — Balance harness & CI · **6 days** · deps: 11

**Objectives.** Make balance a test rather than an opinion. **Everything after this phase must
keep it green.**

- Headless runner: 10,000 seeded runs per chapter, no renderer.
- TTK distribution reporting with the p10–p90 gate.
- Boon Power Score measurement + the pick-rate and 2.4× super-additive flags.
- Hero and arrow win-rate reporting.
- Full CI wiring: analyze, unit, golden damage table, allocation, sim perf, balance.

**Files.** `game/harness/**`, `tool/balance_report.dart`, `.github/workflows/ci.yaml`. ~14 files.

**Exit.** `dart run tool/balance_report.dart` produces the full report in under 3 minutes and CI
fails on any out-of-band Boon or TTK.

---

## Phase 13 — Meta progression · **8 days** · deps: 12

**Objectives.** [04](04-upgrades.md), fully implemented.

- The Spire: 24 nodes, 4 wings, cost curves, Insight tier gates.
- Research Lab: 3 branches.
- Marks: 25 mastery passives + tracking + 6 equip slots.
- Ascension: gate, projection screen, reset, Emberdust tree (5 branches).
- Spire hub scene (Flame) + upgrade UI.

**Files.** `features/spire/**`, `features/ascension/**`, `features/achievements/marks/**`,
`assets/data/spire.json`, `research.json`, `marks.json`. ~30 files.

**Exit.** A full Ascension cycle completes correctly: reset, Emberdust award, survivals verified
item-by-item against [04 §4.7](04-upgrades.md).

---

## Phase 14 — Economy & live systems · **7 days** · deps: 13

**Objectives.** [02](02-economy.md), fully implemented.

- All 7 currencies, wallet, transaction log.
- Vigor with server-time-preferred regen and the anti-clock-skew guard.
- Gold curves, run payouts, partial credit, the ×6.0 multiplier ceiling.
- Chests with visible pity counters, daily rewards (28-day, no streak punishment), quests.

**Files.** `features/economy/**`, `features/daily/**`, `features/quests/**`,
`data/repositories/wallet_repository.dart`, `assets/data/economy.json`. ~26 files.

**Exit.** Simulated 30-day player matches the projected income table within ±8 %. Clock-skew test
passes.

---

## Phase 15 — Full UI pass · **12 days** · deps: 14

**Objectives.** All 19 screens from [10](10-ui-ux.md) at production quality.

- Every screen, every state (loading, empty, error, offline).
- The FTUE beat sheet from [03 §3.1](03-progression.md), fully scripted.
- "What got you" defeat coaching, driven by run telemetry.
- Full accessibility pass: colour-blind mode, left-handed, one-handed, text scaling, reduce
  motion, semantic labels.

**Files.** `features/*/presentation/**` across all 19 features, `core/theme/**`,
`assets/data/onboarding.json`. ~85 files.

**Exit.** Every screen navigable, back-stack depth ≤ 3, the four critical paths hit their tap and
latency budgets, accessibility checklist signed off.

---

## Phase 16 — Monetization · **7 days** · deps: 15

**Objectives.** [17](17-monetization.md), fully implemented.

- AdMob: 7 rewarded placements, always-warm preload, transactional reward delivery, the
  run-active guard, the single interstitial placement.
- IAP: all SKUs, receipt verification, restore, pending-purchase reconciliation.
- Warden's Pact subscription with grace-period handling.
- Battle Pass: 60 tiers, both tracks, XP from play.
- Shop with odds disclosure and offer pacing.

**Files.** `services/ads/**`, `services/iap/**`, `features/shop/**`, `features/pass/**`. ~30 files.

**Exit.** Sandbox purchases succeed on both stores. **A test asserts `showRewarded()` cannot fire
while a run is active.** Reward-loss rate is zero under forced-crash testing.

---

## Phase 17 — Cloud, analytics, events · **8 days** · deps: 16

**Objectives.** Everything network-facing — and everything degrading gracefully without it.

- Cloud save with the explicit conflict-resolution sheet.
- Firestore security rules; the leaderboard-validating Cloud Function.
- Cohort leaderboards (50-player, weekly redraw), build viewer.
- All ~90 analytics events from [18](18-analytics.md), typed, queued, batched, killswitched.
- Remote config for `economy_v1` and the content overlay.
- Event framework + the 7 launch events; Endless Descent with weekly seeds.

**Files.** `services/analytics/**`, `services/remote_config/**`, `data/remote/**`,
`features/compete/**`, `features/events/**`, `functions/**`. ~40 files.

**Exit.** Full offline play verified end to end. Cloud conflict resolution tested with two real
devices. Every event fires with correct parameters.

---

## Phase 18 — Performance, polish, launch prep · **14 days** · deps: 17

**Objectives.** Ship it.

- All performance gates from [19 §19.7](19-performance.md) met on real hardware.
- Thermal, battery (< 9 %/h), and cold-start (< 3.2 s) verification.
- Play Asset Delivery / ODR for chapters 5–12; base bundle under 150 MB.
- Localisation: 8 launch languages, pseudo-locale testing.
- Store listings, screenshots, preview videos, ratings questionnaires, privacy labels.
- Crashlytics, alerting, live-ops dashboards, killswitch drill.
- **Soft launch** in 2 small markets; hold for the D1 ≥ 45 % / D7 ≥ 20 % gate before scaling.

**Files.** `l10n/**`, store assets, `docs/runbooks/**`, CI release pipeline. ~35 files.

**Exit.** All shipping gates green, soft-launch retention meeting the [03 §3.5](03-progression.md)
targets.

---

## 20.1 Summary

| Phase | Name | Days | Cumulative | Deps |
|---|---|---|---|---|
| 0 | Toolchain lock | 2 | 2 | — |
| 1 | Core foundation | 6 | 8 | 0 |
| 2 | Sim skeleton | 7 | 15 | 1 |
| 3 | Draw / Momentum / firing | 6 | 21 | 2 |
| 4 | Windline / Confluence | 7 | 28 | 3 |
| 5 | Enemies & AI | 9 | 37 | 4 |
| 6 | **🔒 Game feel** | 10 | 47 | 5 |
| 7 | Render & pooling | 8 | 55 | 6 |
| 8 | Rooms & generator | 8 | 63 | 7 |
| 9 | Boons | 7 | 70 | 8 |
| 10 | Heroes & arrows | 9 | 79 | 9 |
| 11 | Bosses | 12 | 91 | 10 |
| 12 | Balance harness | 6 | 97 | 11 |
| 13 | Meta progression | 8 | 105 | 12 |
| 14 | Economy | 7 | 112 | 13 |
| 15 | Full UI | 12 | 124 | 14 |
| 16 | Monetization | 7 | 131 | 15 |
| 17 | Cloud & analytics | 8 | 139 | 16 |
| 18 | Perf & launch | 14 | 153 | 17 |
| — | **Buffer (30 %)** | 52 | **205** | — |

**The 30 % buffer is not padding.** Phase 6 may send us back to Phase 3. Phase 0 may reveal a
Firebase problem that costs a week. Every schedule in this category that has no buffer ships
late *and* broken.

## 20.2 Critical path & risk

**The critical path runs 0 → 6.** Everything after Phase 6 is content and systems built on a
proven core; everything before it is proving the core. **47 days to know whether this game
works.**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Confluence reads as visual noise | Medium | **Severe** | Phase 6 gate; the game degrades to a solid Draw/Momentum roguelite without it |
| Firebase iOS / Xcode 15.2 | **High** (it already happened once here) | Medium | Phase 0 verification; `AnalyticsPort` abstraction absorbs it |
| Windline perf on low-end | Medium | High | Batched mesh + segment cap, proven in Phase 7 before content investment |
| Art scope (~4,000 sprites) | High | High | Greybox until Phase 7; variants via tint; chapters 5–12 shipped post-launch if needed |
| Balance across 20 heroes × 112 Boons | High | Medium | Phase 12 harness makes it measurable rather than intuited |
| Solo-dev burnout over 10 months | Medium | Severe | Phase boundaries are real stopping points; the game is shippable-with-less-content from Phase 15 |

## 20.3 Minimum shippable scope

If the schedule needs to compress, this is what ships and what waits — decided **now**, in
daylight, rather than in a panic at month 8:

**Must ship:** Phases 0–16. Chapters 1–8. 12 heroes. 8 arrows. 12 bosses. All 112 Boons. The
Spire, Ascension, economy, full UI, monetization.

**Can ship post-launch:** chapters 9–12, heroes 13–20, arrows 9–12, bosses 13–20, Endless
Descent, events beyond the first two, cohort leaderboards, cosmetics beyond the base set.

That reduced scope is **Phases 0–16 ≈ 131 days + buffer ≈ 170 days**, and it is a complete,
satisfying game — not a demo. Cutting content is survivable. Cutting Phase 6, the balance
harness, or the performance gates is not.
