# ADR 0001 — Toolchain & dependency lock

**Phase** 0
**Date** 2026-07-19
**Status** Accepted
**Machine** MacBook, Intel (x86_64), macOS 13.7.8

---

## Context

Phase 0 exists to resolve every dependency against the installed Flutter and to
prove the risky ones build *before* any architecture depends on them. Two prior
projects on this machine (`arrows-game`, `screw_jam_universe`) lost significant
time to toolchain problems that a lock phase would have caught.

Every finding below was verified by an actual build, not by reading changelogs.

## Environment (measured)

| | Version |
|---|---|
| Flutter | 3.24.5 stable (`~/development/flutter/bin`, **not on default PATH**) |
| Dart | 3.5.4 |
| macOS | 13.7.8 (x86_64) |
| Xcode | 15.2 (build 15C500b) — **capped by macOS 13; Xcode 16 needs macOS 14.5+** |
| iOS SDK | 17.2 |
| Xcode max device support | **iOS 16.4** |
| CocoaPods | 1.12.1 |
| JDK | 21.0.10 (bundled with Android Studio 2025.3) |
| Android SDK | 36.1.0 |

## Decisions

### D1 — Stay on Flutter 3.24.5

**Accepted.** Everything is verified working on Android at this version. Flame
1.22.0 is fully capable of everything in the GDD; nothing needs 1.23+. Upgrading
would cost half a day re-verifying what is already proven, and would not fix the
iOS device problem (D6), which is the actual constraint.

Revisit if we hit a real wall, or when macOS is upgraded.

### D2 — Android toolchain: Gradle 8.7 / AGP 8.6.0 / Kotlin 2.1.0 / compileSdk 35

**This supersedes the pins carried over from `screw_jam_universe`**
(AGP 8.3.2 / Kotlin 1.9.24), which work for a bare project but *not* with this
dependency set. Two forcing constraints, both found by build failure:

- **Kotlin 2.1.0 is required, not optional.** `firebase_analytics` pulls
  `play-services-measurement 22.5.0`, whose Kotlin metadata is version 2.1.0.
  Against Kotlin 1.9.x it fails with
  `Module was compiled with an incompatible version of Kotlin`.
- **compileSdk 35 is required** by `audioplayers_android`, which in turn forces
  **AGP ≥ 8.6.0**. AGP 8.6.0 is the highest AGP that still works with Gradle 8.7.

Also set: `minSdk 24`, `targetSdk 35`, Java 17 source/target, core library
desugaring, NDK pinned to `25.1.8937393` (11 plugins request it explicitly),
R8 + resource shrinking on release.

### D3 — Local store: Hive CE. Isar rejected.

**Isar was rejected before benchmarking, on build viability.** `isar_flutter_libs
3.1.0+1` declares no AGP namespace and therefore cannot build under AGP 8.x:

```
Could not create an instance of type LibraryVariantBuilderImpl.
> Namespace not specified.
```

Upstream Isar has been unmaintained since 2023. A store that cannot build is not
a candidate regardless of its performance.

Hive CE was then measured against the real budgets from `docs/12-architecture.md`
(`test/phase0/local_store_benchmark_test.dart`):

| Operation | Payload | Measured | Budget | Headroom |
|---|---|---|---|---|
| Room-boundary snapshot write | 2,575 B | **0.43 ms** | 4 ms | 9× |
| Full PlayerSave write | 14,938 B | **2.6 ms** | 250 ms | 95× |
| Full PlayerSave read | 14,938 B | **0.32 ms** | 150 ms | 460× |
| Mature save round-trip | 33,784 B | **1.2 ms** | 400 ms | 330× |

Comfortable on every budget. Note the `RunSnapshot` measured at 2,575 bytes,
which confirms the GDD's ~2 KB estimate.

### D4 — Flame pinned to exactly 1.22.0

`flame: ^1.0.0` resolves to **1.23.0, which does not compile on Flutter 3.24.5** —
it calls `Color.withValues` and `Color.a` internally (Flutter 3.27+ APIs).

**The dangerous part: `flutter pub get` succeeds and `flutter analyze` reports
"No issues found".** The failure only appears during the AOT kernel snapshot,
i.e. at release-build time. Pinned to an exact version, not a caret range, so a
future `pub upgrade` cannot silently reintroduce this.

### D5 — `Color.withValues` is banned, enforced by test

Because analyze does not catch it (D4), `test/guards/architecture_guard_test.dart`
greps `lib/` for `.withValues(` and fails the build. Use `withOpacity`.

### D6 — iOS: build-verified, device-blocked. Android-first.

Four separate iOS findings, in the order they were hit:

1. **CocoaPods 1.12.1 × Xcode 15** → `DT_TOOLCHAIN_DIR cannot be used to
   evaluate LIBRARY_SEARCH_PATHS`. **Fixed**, project-locally, by a `post_install`
   hook in `ios/Podfile` that rewrites the generated `.xcconfig` files. Patching
   `build_settings` alone is insufficient — per-pod xcconfigs are written
   straight to disk from each podspec. Fixed locally rather than by upgrading
   CocoaPods globally, because that would affect `arrows-game` and
   `screw_jam_universe` on this machine.

2. **Firebase iOS 11.x requires Swift 6 / Xcode 16** →
   `Access level on imports require '-enable-experimental-feature AccessLevelOnImport'`.
   Downgrading to the 10.x SDK compiles but then fails at link. *This is the
   root cause of the `arrows-game` Firebase problem, now precisely diagnosed.*

3. **`google_mobile_ads` needs Xcode 15.4+** → Google-Mobile-Ads-SDK 11.13 links
   against `MarketplaceKit`, absent from Xcode 15.2:
   `Undefined symbols: enum case for MarketplaceKit.AppDistributor.testFlight`.

4. **The connected iPhone runs iOS 26.5; Xcode 15.2 supports up to iOS 16.4.**
   On-device iOS testing is impossible on this machine and **cannot be fixed in
   software** — it needs macOS 15 + a modern Xcode.

**Decision (confirmed with the project owner): build Android-first.**

The important positive result: **with `google_mobile_ads` and `firebase_*`
removed, the iOS release build succeeds** (`Runner.app`, 61.7 MB). The core game
— Flame, Hive, audio, IAP, path_provider — is iOS-viable today. Only the Phase
16/17 SDKs are blocked, and both already sit behind ports (`AdsPort`,
`AnalyticsPort`) per `docs/12-architecture.md`.

So `google_mobile_ads` and `firebase_*` are **deferred out of `pubspec.yaml`
until Phase 16/17**. Both are verified working on Android (release APK builds
with the full stack). Keeping them out is what keeps iOS buildable through
Phases 1–15. A guard test fails the build if they are re-added without revisiting
this ADR.

**Action required before Phase 16:** upgrade macOS to 15+ and Xcode to 16+, or
accept an Android-only launch.

### D7 — Strict analysis

`analysis_options.yaml` enables `strict-casts`, `strict-inference`,
`strict-raw-types`, promotes unused-code and `unawaited_futures` to errors, and
makes `missing_enum_constant_in_switch` an error (enemy families, Draw tiers,
rarities and boss phases are all closed sets where a missed case is a silent
gameplay bug).

### D8 — Architecture guards exist before the code they guard

`test/guards/architecture_guard_test.dart` is written in Phase 0, before Phase 2
creates `lib/game/sim/`, so the sim-purity rule from `docs/12-architecture.md`
§12.0 can never be violated even once. It currently no-ops on the missing
directory by design.

## Verification results

| Check | Result |
|---|---|
| `flutter analyze` (strict) | ✅ No issues |
| `dart test test/` | ✅ 6/6 passing |
| Android release APK | ✅ 40.2 MB |
| Android release APK, full stack incl. Firebase + Ads | ✅ 43.0 MB |
| iOS release build (core game) | ✅ 61.7 MB `Runner.app` |
| iOS release build with Ads or Firebase | ❌ Blocked — see D6 |
| **iOS simulator — installed, launched, rendering** | ✅ iPhone 14, iOS 17.2 sim |
| **Android physical device — installed, launched, rendering** | ✅ Vivo V2204, Android 12 (API 31), arm64-v8a |

The Flame smoke test renders correctly on both platforms: an additive-blended
cyan trail fading over the void background — a crude stand-in for the Windline,
chosen specifically because it exercises per-frame geometry generation and
additive blending, the two things the real renderer depends on.

## Known environment issues (not project blockers)

- **The Android emulator does not work on this Intel Mac.** The Pixel_8 AVD
  (API 35, x86_64, Play Store image) never completes boot — `sys.boot_completed`
  never sets, despite correct architecture (x86_64 on x86_64). Do not rely on it.
  **Use the physical device.** This is fine, and arguably better: the Phase 6
  game-feel gate and all Phase 19 performance work need real hardware anyway.
- **Test device is a Vivo V2204** (Android 12, API 31, arm64-v8a). Note this sits
  above the GDD's reference low-end target (Snapdragon 665 class), so it is not a
  substitute for the low-end verification required in Phase 19 — a weaker device
  will be needed before the performance gates can be signed off.
- `adb shell dumpsys gfxinfo` reports 0 frames for Flutter apps because Flutter
  renders to its own surface. Frame profiling must go through
  `flutter run --profile` + DevTools; set this up in Phase 6.
- `cmdline-tools` missing and Android licenses unaccepted in `flutter doctor`.
  Does not block Gradle builds; worth fixing before CI setup in Phase 12.
- CocoaPods 1.12.1 is below Flutter's recommended 1.13.0. Worked around locally
  (D6.1) rather than upgraded globally.

## Consequences

- Phases 1–15 proceed on Android with iOS kept build-green as a secondary target.
- Ads and analytics are port-only until Phase 16, which the architecture already
  assumed — this validates that design choice rather than straining it.
- The exact-pinned Flame version and the `withValues` guard mean the two silent
  failure modes found here cannot recur.
- The Android pins here supersede those in the `screw_jam_universe` notes.
