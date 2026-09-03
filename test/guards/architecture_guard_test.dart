@Tags(<String>['guard'])
library;

import 'dart:io';
import 'dart:ui';

import 'package:quiverfall/core/theme/tokens.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/feel/feel_palette.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

/// Architecture guards.
///
/// These enforce structural invariants that are cheap to state and expensive to
/// discover you have broken. They run in CI on every build.
void main() {
  group('sim purity', () {
    // docs/12-architecture.md §12.0 — the single most important constraint in
    // the project. The simulation must stay pure Dart so the balance harness
    // can run headless, runs stay deterministic and replayable, and combat is
    // testable without pumping widgets.
    const List<String> forbidden = <String>[
      'package:flutter/',
      'package:flame',
      'package:flutter_riverpod/',
      'dart:ui',
      'dart:html',
    ];

    test('lib/game/sim imports nothing from Flutter, Flame or Riverpod', () {
      final Directory simDir = Directory('lib/game/sim');
      if (!simDir.existsSync()) {
        // Phase 2 creates this directory. The guard is written first, on
        // purpose, so the rule is enforced from the moment the sim exists.
        return;
      }

      final List<String> violations = <String>[];

      for (final FileSystemEntity entity in simDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final List<String> lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i].trim();
          if (!line.startsWith('import ') && !line.startsWith('export ')) {
            continue;
          }
          for (final String banned in forbidden) {
            if (line.contains(banned)) {
              violations.add('${entity.path}:${i + 1}  $line');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/game/sim must remain pure Dart.\n'
            'See docs/12-architecture.md §12.0.\n'
            'Violations:\n${violations.join('\n')}',
      );
    });
  });

  group('system order', () {
    // docs/12-architecture.md §12.4. The tick order is a behaviour contract,
    // not a style choice: running damage before collision, or spawn before
    // movement, produces a different game from the same inputs and silently
    // invalidates every recorded replay and every balance measurement.
    //
    // This test exists so that reordering is a deliberate, reviewed act. If you
    // are here because it failed, the question is not "what do I change to make
    // it pass" but "which replays and which balance numbers did I just void".
    test('SimWorld runs its systems in the documented order', () {
      expect(
        SystemOrder.values.map((SystemOrder s) => s.name).toList(),
        <String>[
          'input',
          'movement',
          'draw',
          'collision',
          'firing',
          // Phase 10. Right after ordinary firing, before the projectile step
          // sweeps whatever either one spawned this tick. No pre-Phase-10 run
          // is affected: no world before now could ever hold a hero, so
          // `_updateUltimate` is a no-op for every one of them.
          'ultimate',
          'projectile',
          'windlineExpiry',
          'element',
          // Phase 11. After element (a DoT tick can cross a phase threshold
          // exactly like a direct hit), before ai (so a boss's own family
          // tree reads this tick's phase). No-op for every pre-Phase-11
          // seeded run — nothing before now could ever spawn a boss.
          'bossPhase',
          'ai',
          'hazard',
          'spawn',
          // Phase 9. Inserted at the slot SystemOrder had reserved for it since
          // Phase 3, immediately before cleanup: after everything that could
          // have changed the player's state this frame, so a Momentum shield is
          // sized from this tick's stacks rather than last tick's.
          //
          // **No replay or balance number was voided by this.** BoonSystem
          // returns immediately unless a Boon behaviour is live, and nothing
          // before Phase 9 could hold one — so every pre-existing seeded run
          // produces byte-identical output with the slot occupied.
          'boon',
          'cleanup',
        ],
      );
    });
  });

  group('palette', () {
    // `Tokens` is the single source of truth for colour and imports Flutter,
    // which `game/feel` may not — the feedback stack stays pure Dart so it can
    // be unit-tested without a widget tree. Duplicating a palette is normally
    // how it rots; duplicating it under a test that fails the build on
    // divergence is how you get purity without the rot.
    //
    // The semantic entries matter most: docs/15 §15.0 rule 5 makes amber /
    // crimson / cyan a *gameplay contract*, and a renderer drawing a telegraph
    // in a slightly different amber from the HUD is a gameplay bug.
    test('FeelPalette matches Tokens exactly', () {
      final Map<String, (int, Color)> pairs = <String, (int, Color)>{
        'accent': (FeelPalette.accent, Tokens.accent),
        'warn': (FeelPalette.warn, Tokens.warn),
        'danger': (FeelPalette.danger, Tokens.danger),
        'whiteHot': (FeelPalette.whiteHot, Tokens.whiteHot),
        'ink': (FeelPalette.ink, Tokens.ink),
        'inkDim': (FeelPalette.inkDim, Tokens.inkDim),
        'arenaFloor': (FeelPalette.arenaFloor, Tokens.arenaFloor),
        'arenaWall': (FeelPalette.arenaWall, Tokens.arenaWall),
        'bgDeep': (FeelPalette.bgDeep, Tokens.bgDeep),
        'ember': (FeelPalette.ember, Tokens.ember),
        'rime': (FeelPalette.rime, Tokens.rime),
        'storm': (FeelPalette.storm, Tokens.storm),
        'blight': (FeelPalette.blight, Tokens.blight),
        'familyDrift': (FeelPalette.familyDrift, Tokens.familyDrift),
        'familyCarapace': (FeelPalette.familyCarapace, Tokens.familyCarapace),
        'familyRush': (FeelPalette.familyRush, Tokens.familyRush),
        'familySalvo': (FeelPalette.familySalvo, Tokens.familySalvo),
        'familyChoir': (FeelPalette.familyChoir, Tokens.familyChoir),
        'familyRiftborn': (FeelPalette.familyRiftborn, Tokens.familyRiftborn),
      };

      for (final MapEntry<String, (int, Color)> entry in pairs.entries) {
        expect(
          entry.value.$1,
          entry.value.$2.value,
          reason: '${entry.key} has drifted between FeelPalette and Tokens',
        );
      }
    });

    test('every element and family has a colour', () {
      // Indexed by enum ordinal in the renderer's hot loop, so a short list is
      // a range error on the frame a Toxin arrow first lands.
      expect(FeelPalette.byElement, hasLength(SimElement.values.length));
      expect(FeelPalette.byFamily, hasLength(EnemyFamily.values.length));
    });
  });

  group('toolchain guards', () {
    test('no use of Color.withValues anywhere in lib/', () {
      // Color.withValues landed in Flutter 3.27. This project is pinned to
      // 3.24.5, where it does not exist. Critically, `flutter analyze` does NOT
      // catch this — it only surfaces during the AOT kernel snapshot, i.e. at
      // release-build time, which is the worst moment to find out.
      final List<String> violations = <String>[];

      for (final FileSystemEntity entity
          in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart') ||
            entity.path.endsWith('.freezed.dart')) {
          continue;
        }

        final List<String> lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains('.withValues(')) {
            violations.add('${entity.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Color.withValues does not exist in Flutter 3.24.5. '
            'Use withOpacity instead.\n'
            'See docs/decisions/0001-toolchain.md.\n'
            'Violations:\n${violations.join('\n')}',
      );
    });

    test('pubspec does not re-add the Phase 16/17 iOS-breaking packages', () {
      // google_mobile_ads and firebase_* both build fine on Android but break
      // the iOS build under Xcode 15.2. They are deliberately deferred so that
      // iOS stays buildable through Phases 1–15. If you are reading this in
      // Phase 16, resolve the toolchain question first, then delete this test.
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final List<String> active = pubspec
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('#'))
          .join('\n')
          .split('\n')
          .where(
            (String l) =>
                l.contains('google_mobile_ads:') || l.contains('firebase_'),
          )
          .toList();

      expect(
        active,
        isEmpty,
        reason: 'These packages break the iOS build on Xcode 15.2.\n'
            'See docs/decisions/0001-toolchain.md before re-adding.\n'
            'Found:\n${active.join('\n')}',
      );
    });
  });
}
