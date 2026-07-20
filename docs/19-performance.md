# 19 — Performance Optimization

## 19.0 The law

**60 FPS on a 2019 budget Android.** A feature that cannot hold frame does not ship.

The reference device is a **Snapdragon 665 / 3 GB RAM / 720×1600** class phone — roughly a
Redmi Note 8. If it runs there, it runs everywhere. Designing for a flagship and optimising down
afterwards is how mobile games end up with a 25 % low-end refund rate.

## 19.1 Frame budget

At 60 FPS the whole frame is **16.6 ms**. Allocation:

| Stage | Budget | Notes |
|---|---|---|
| Sim tick (all systems) | **4.0 ms** | Fixed 60 Hz, [12 §12.4](12-architecture.md) |
| Flame component sync | 1.5 ms | Sim → view transforms |
| Render (Skia/Impeller) | **7.0 ms** | Sprites, particles, Windlines |
| Flutter HUD | 1.0 ms | Targeted repaints only |
| Audio | 0.5 ms | |
| Headroom | 2.6 ms | Absorbs GC, OS interrupts, thermal dips |

**The headroom is not spare budget.** It is what stops a 3 ms hiccup from becoming a dropped
frame. Any feature that eats into it needs an explicit trade.

Per-system sim budget at peak load (90 entities, 400 Windline segments, 60 arrows):

| System | Budget |
|---|---|
| Collision (spatial hash) | 0.9 ms |
| **Windline + Confluence** | **0.8 ms** |
| AI | 0.7 ms |
| Projectile | 0.5 ms |
| Damage + elements | 0.4 ms |
| Movement + Draw | 0.3 ms |
| Spawn, boon, cleanup | 0.4 ms |

## 19.2 The three hard problems

Almost all of this game's performance risk sits in three places. Everything else is routine.

### Problem 1 — Confluence intersection testing

Naively, every new arrow must be tested against every live Windline segment. At 60 arrows and
1,024 segments that is 61,440 segment-segment intersection tests per frame. Unshippable.

**Solution — four stacked reductions:**

1. **Spatial hash.** Windline segments are inserted into the same uniform 1.5 u grid as collision.
   An arrow tests only segments in the cells its swept path touches — typically 3–6 cells,
   reducing candidates from ~1,024 to ~20.
2. **Age filter.** An arrow can only Confluence with segments *older than itself*. Segments are
   stored newest-first in a ring buffer, so the scan short-circuits.
3. **Owner filter.** Only the player's own segments are eligible.
4. **Early-out AABB.** A cheap bounding-box reject before any line-segment maths.

Result: **~20 candidates → ~4 real intersection tests per arrow per frame.** Roughly 240 tests
per frame at peak, comfortably inside 0.8 ms.

**Ring buffer sizing is load-bearing.** 1,024 segments is a hard cap; when full, the oldest is
evicted regardless of its remaining lifetime. With *The Loom* (Windlines never expire) plus Iris
plus Mirelle duplication, a player can genuinely generate segments faster than they expire, and
an uncapped buffer would grow until the device died. The cap is the correctness fix, not an
optimisation.

### Problem 2 — Windline rendering

Up to 1,024 additive translucent line segments, each with a gradient and a fade. Naively that is
1,024 draw calls.

**Solution:** Windlines render as a **single batched triangle-strip mesh** in one draw call. Each
segment contributes 2 triangles with per-vertex colour and alpha; the whole mesh is rebuilt into a
pre-allocated `Float32List` each frame (no allocation) and submitted via `Canvas.drawVertices`.
Colour and fade are vertex attributes, not per-segment paint changes.

**One draw call for the game's signature visual.** This is what makes the mechanic affordable.

### Problem 3 — Garbage collection

Dart's generational GC produces a young-gen collection roughly every few hundred KB of
allocation. At 60 Hz, a combat system allocating even small objects per entity per frame will
cause visible periodic jank on a low-end device.

**Solution — zero steady-state allocation:**

- **Struct-of-arrays** entity storage. Components live in typed lists (`Float64List`,
  `Int32List`); a system iterates contiguous memory and mutates in place.
- **No `new` in any system's `update()`.** No temporary `Vector2`, no closures allocated per
  frame, no `.map()`/`.where()` chains in hot loops — plain indexed `for` loops throughout.
- **Everything pooled** ([12 §12.11](12-architecture.md)): arrows, segments, enemies, particles,
  damage numbers, SFX players.
- **Pre-allocated scratch buffers** for the vertex mesh, the spatial-hash bucket lists, and the
  event queue.
- **Enforced by test:** a profiling test runs 600 sim ticks at peak entity count and asserts the
  allocation delta is under a fixed threshold. It runs in CI and fails the build.

## 19.3 Rendering strategy

- **Atlas discipline:** ≤ 4 texture binds per arena. Atlases are packed per chapter and per enemy
  family; the whole roster of a given room comes from at most 2 sprite atlases plus 1 VFX atlas
  plus 1 UI atlas.
- **Draw order is sorted once per frame** into a pre-allocated index list, by layer then by atlas,
  so batches never break unnecessarily.
- **Particles are a single batched system**, same `drawVertices` approach as Windlines.
- **No runtime shader compilation.** All shaders are warmed during the loading screen — shader
  jank on first-use is one of the most common and most avoidable Flutter game stutters.
- **Impeller** on iOS; on Android, Impeller where supported with a Skia fallback, decided by the
  boot benchmark.
- **The background is a static composited layer**, redrawn only when the arena changes.

## 19.4 Quality tiers

Assigned by a boot-time benchmark (`device_benchmark` event), overridable in Settings.

| | Battery | Balanced | High |
|---|---|---|---|
| Target FPS | 30 | 60 | 60 (120 if available) |
| Particle density | 0.25 | 0.6 | 1.0 |
| Max Windline segments | 320 | 640 | 1,024 |
| Screen shake | Off | Light | Full |
| Background parallax layers | 1 | 2 | 3 |
| Damage numbers | Crits only | Standard | All |
| Bloom / post | Off | Off | Light |
| Enemy cap | 60 | 90 | 90 |

**The Windline segment cap is a quality setting, and this is a real design compromise.** A
Battery-tier player has shorter-lived Windlines and therefore a genuinely harder time chaining
Confluence. Mitigation: the cap scales the *global* segment budget, while per-player Windline
*duration* is unchanged — a solo player never notices, and the cap only bites in the densest
multishot builds. This trade is documented here so nobody "fixes" it later by capping duration
instead, which would break the mechanic.

## 19.5 Memory

**Target: under 400 MB resident on the reference device; hard ceiling 512 MB.**

| Segment | Budget |
|---|---|
| Engine + Flutter framework | 90 MB |
| UI atlas + fonts | 24 MB |
| Current chapter atlases | 110 MB |
| VFX atlas | 30 MB |
| Audio (streamed music + resident SFX) | 45 MB |
| Sim + pools | 25 MB |
| Save + content JSON | 8 MB |
| Headroom | 68 MB |

- **At most 3 chapters resident.** Others are evicted on return to Menu.
- **Music streams**, never fully decoded into memory.
- Boss atlases load during room N−1 and unload on Victory.
- `memory_warning` triggers an immediate eviction pass and drops one quality tier for the session.

## 19.6 Low-end Android specifics

| Issue | Mitigation |
|---|---|
| Slow storage (eMMC) | Sequential asset reads, one packed file per chapter rather than thousands of small files |
| Thermal throttling | After 8 min of sustained load, if p95 frame time degrades >25 %, silently drop one quality tier and log it |
| 3 GB RAM, aggressive OOM killer | Stay under 400 MB; snapshot run state at every room boundary so a kill costs at most one room |
| No Vulkan / weak GPU | Skia fallback; no post-processing on Battery tier |
| Slow cold start | Splash begins rendering before bootstrap completes; boot assets under 24 MB |
| Small screens (720p) | UI authored at a 360 dp logical width; minimum 48 dp touch targets verified at that width |
| Old WebView / no Play Services | Ads, cloud save, and leaderboards all degrade gracefully; the game never blocks on them |

## 19.7 Verification

**Automated, in CI, per build:**

1. **Allocation test** — 600 sim ticks at peak load, assert allocation delta under threshold.
2. **Sim performance test** — 10,000 ticks at peak, assert mean tick under 4.0 ms on the CI
   reference.
3. **Balance harness** — 10,000 seeded runs per chapter; asserts the TTK band and the Boon power
   scores from [09 §9.5](09-skills.md).
4. **Golden damage table** — 600 cases through `DamageResolver`.
5. **Memory ceiling test** — load the heaviest chapter, assert resident under budget.

**Manual, per milestone, on real hardware:**

- The reference low-end device, plus a mid-tier and a flagship, plus the oldest supported iPhone.
- 20-minute sustained-play thermal test with frame-time capture.
- Battery drain measurement — **target under 9 %/hour** on the reference device.
- Cold-start timing from a cleared cache.

**Shipping gates. A build fails release if any of these are true:**

- p95 frame time on the low-tier reference exceeds **16.6 ms** in a chapter-8 elite room.
- Crash-free sessions below **99.5 %**.
- Cold start above **3.2 s** to interactive on the reference device.
- Resident memory above **512 MB** at any point.
- Any CI performance or balance test failing.

These are thresholds, not aspirations. The 60 FPS law is only real if something enforces it, and
this section is that something.
