import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/balance/enemy_tuning.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/spawn/composition_validator.dart';
import 'package:quiverfall/game/spawn/room_composer.dart';
import 'package:quiverfall/game/spawn/wave_plan.dart';
import 'package:test/test.dart';

import 'enemy_test_support.dart';

/// Every composition rule in docs/05 §5.7 has a test here.
///
/// They come in pairs: one proving the validator *catches* a hand-built
/// violation, and one proving the composer never *produces* it. A validator
/// nobody violates is untested, and a generator nobody audits is unproven.
void main() {
  late ContentLibrary content;

  setUpAll(() {
    content = loadEnemies();
  });

  int index(EnemyArchetype a) => content.indexOfArchetype(a);

  RoomPlan handBuilt(
    List<EnemyArchetype> enemies, {
    int chapter = 8,
    int globalStage = 40,
    bool isElite = false,
    List<EnemyVariant>? variants,
  }) {
    final List<PlannedEnemy> planned = <PlannedEnemy>[];
    for (int i = 0; i < enemies.length; i++) {
      planned.add(
        PlannedEnemy(
          index(enemies[i]),
          variants == null ? EnemyVariant.none : variants[i],
        ),
      );
    }
    return RoomPlan(
      waves: <WavePlan>[WavePlan(planned)],
      threatBudget: Curves.threatBudget(globalStage),
      chapter: chapter,
      globalStage: globalStage,
      isElite: isElite,
    );
  }

  group('§5.7 threat budget', () {
    test('a room that overspends is rejected', () {
      final RoomPlan plan = handBuilt(
        List<EnemyArchetype>.filled(20, EnemyArchetype.ironmaw),
        globalStage: 1,
      );
      expect(
        CompositionValidator.validate(plan, content)
            .map((CompositionViolation v) => v.rule),
        contains('threat budget'),
      );
    });

    test('the composer never overspends', () {
      final Rng rng = Rng(7);
      for (int stage = 1; stage <= 60; stage++) {
        final RoomPlan plan = RoomComposer.compose(
          content: content,
          rng: rng,
          chapter: 1 + (stage - 1) ~/ 20,
          globalStage: stage,
        );
        expect(
          plan.threatIn(content),
          lessThanOrEqualTo(plan.threatBudget + 1e-6),
          reason: 'stage $stage overspent',
        );
      }
    });
  });

  group('§5.7 max 2 Choir units per room', () {
    test('three healers is not difficulty, it is a wall', () {
      final RoomPlan plan = handBuilt(<EnemyArchetype>[
        EnemyArchetype.knitter,
        EnemyArchetype.knitter,
        EnemyArchetype.knitter,
        EnemyArchetype.mote,
      ]);
      expect(
        CompositionValidator.validate(plan, content)
            .map((CompositionViolation v) => v.rule),
        contains('max 2 Choir units'),
      );
    });

    test('two is allowed', () {
      final RoomPlan plan = handBuilt(<EnemyArchetype>[
        EnemyArchetype.knitter,
        EnemyArchetype.weaver,
        EnemyArchetype.mote,
        EnemyArchetype.mote,
        EnemyArchetype.lancer,
        EnemyArchetype.lancer,
        EnemyArchetype.lancer,
      ]);
      expect(
        CompositionValidator.validate(plan, content)
            .map((CompositionViolation v) => v.rule),
        isNot(contains('max 2 Choir units')),
      );
    });
  });

  group('§5.7 no Screecher + Longeye before chapter 8', () {
    test('the pairing is rejected in chapter 7', () {
      final RoomPlan plan = handBuilt(
        <EnemyArchetype>[
          EnemyArchetype.screecher,
          EnemyArchetype.longeye,
          EnemyArchetype.mote,
        ],
        chapter: 7,
      );
      expect(
        CompositionValidator.validate(plan, content).map(
          (CompositionViolation v) => v.rule,
        ),
        contains(
          'no Screecher + Longeye before chapter '
          '${CompositionValidator.screecherLongeyeChapter}',
        ),
      );
    });

    test('and allowed in chapter 8', () {
      final RoomPlan plan = handBuilt(
        <EnemyArchetype>[
          EnemyArchetype.screecher,
          EnemyArchetype.longeye,
          EnemyArchetype.mote,
        ],
      );
      expect(
        CompositionValidator.validate(plan, content).map(
          (CompositionViolation v) => v.rule,
        ),
        isNot(
          contains(
            'no Screecher + Longeye before chapter '
            '${CompositionValidator.screecherLongeyeChapter}',
          ),
        ),
      );
    });

    test('the composer never assembles it early', () {
      final Rng rng = Rng(11);
      for (int i = 0; i < 400; i++) {
        final RoomPlan plan = RoomComposer.compose(
          content: content,
          rng: rng,
          chapter: 6 + i % 2,
          globalStage: 100 + i,
        );
        final bool both = plan.contains(content, EnemyArchetype.screecher) &&
            plan.contains(content, EnemyArchetype.longeye);
        expect(both, isFalse, reason: 'assembled the banned pairing');
      }
    });
  });

  group('§5.7 at least 40% of threat is Drift or Rush', () {
    test('a room of pure artillery is rejected', () {
      final RoomPlan plan = handBuilt(<EnemyArchetype>[
        EnemyArchetype.mortarite,
        EnemyArchetype.longeye,
        EnemyArchetype.spitter,
        EnemyArchetype.nettle,
      ]);
      expect(
        CompositionValidator.validate(plan, content)
            .map((CompositionViolation v) => v.rule),
        contains('>= 40% Drift or Rush threat'),
      );
    });

    test('the composer always leaves something safe to shoot', () {
      final Rng rng = Rng(23);
      for (int chapter = 1; chapter <= 12; chapter++) {
        for (int i = 0; i < 40; i++) {
          final RoomPlan plan = RoomComposer.compose(
            content: content,
            rng: rng,
            chapter: chapter,
            globalStage: chapter * 20 - 10,
          );
          expect(
            plan.safeThreatShare(content),
            greaterThanOrEqualTo(CompositionValidator.minSafeThreatShare - 1e-9),
            reason: 'chapter $chapter room had nothing safe to shoot',
          );
        }
      }
    });
  });

  group('§5.7 Elite rooms', () {
    test('a normal room may not contain a Riftborn', () {
      final RoomPlan plan = handBuilt(<EnemyArchetype>[
        EnemyArchetype.echo,
        EnemyArchetype.mote,
      ]);
      expect(
        CompositionValidator.validate(plan, content)
            .map((CompositionViolation v) => v.rule),
        contains('Riftborn only in Elite rooms'),
      );
    });

    test('an Elite room contains exactly one', () {
      final RoomPlan two = handBuilt(
        <EnemyArchetype>[EnemyArchetype.echo, EnemyArchetype.gravebound],
        isElite: true,
      );
      expect(
        CompositionValidator.validate(two, content)
            .map((CompositionViolation v) => v.rule),
        contains('Elite rooms contain exactly one Riftborn'),
      );
    });

    test('support is capped at 30% of the normal budget', () {
      final RoomPlan plan = handBuilt(
        <EnemyArchetype>[
          EnemyArchetype.echo,
          ...List<EnemyArchetype>.filled(12, EnemyArchetype.ironmaw),
        ],
        isElite: true,
        globalStage: 1,
      );
      expect(
        CompositionValidator.validate(plan, content)
            .map((CompositionViolation v) => v.rule),
        contains('Elite support <= 30% of budget'),
      );
    });

    test('the composer builds legal Elite rooms from chapter 3', () {
      final Rng rng = Rng(31);
      for (int chapter = 3; chapter <= 12; chapter++) {
        final RoomPlan plan = RoomComposer.compose(
          content: content,
          rng: rng,
          chapter: chapter,
          globalStage: chapter * 20,
          isElite: true,
        );
        expect(plan.isElite, isTrue);
        expect(plan.countOfFamily(content, EnemyFamily.riftborn), 1);
        expect(CompositionValidator.validate(plan, content), isEmpty);
      }
    });

    test('an Elite request before chapter 3 degrades to a normal room', () {
      // There is no Riftborn to build one from. Producing an "Elite" room with
      // no elite in it would be worse than producing a normal one.
      final RoomPlan plan = RoomComposer.compose(
        content: content,
        rng: Rng(3),
        chapter: 2,
        globalStage: 25,
        isElite: true,
      );
      expect(plan.isElite, isFalse);
      expect(CompositionValidator.validate(plan, content), isEmpty);
    });
  });

  group('§5.8 chapter schedule and variants', () {
    test('nothing appears before the chapter that introduces it', () {
      final RoomPlan plan = handBuilt(
        <EnemyArchetype>[EnemyArchetype.nullborn],
        chapter: 2,
        isElite: true,
      );
      expect(
        CompositionValidator.validate(plan, content)
            .map((CompositionViolation v) => v.rule),
        contains('chapter introduction schedule'),
      );
    });

    test('variants are rejected before chapter 9', () {
      final RoomPlan plan = handBuilt(
        <EnemyArchetype>[EnemyArchetype.mote, EnemyArchetype.mote],
        chapter: 5,
        variants: <EnemyVariant>[EnemyVariant.frenzied, EnemyVariant.none],
      );
      expect(
        CompositionValidator.validate(plan, content).map(
          (CompositionViolation v) => v.rule,
        ),
        contains('variants from chapter ${EnemyVariant.firstChapter}'),
      );
    });

    test('the composer uses variants in the late campaign and not before', () {
      final Rng rng = Rng(97);
      bool sawLateVariant = false;

      for (int chapter = 1; chapter <= 12; chapter++) {
        for (int i = 0; i < 30; i++) {
          final RoomPlan plan = RoomComposer.compose(
            content: content,
            rng: rng,
            chapter: chapter,
            globalStage: chapter * 20,
          );
          for (final WavePlan wave in plan.waves) {
            for (final PlannedEnemy e in wave.enemies) {
              if (e.variant == EnemyVariant.none) continue;
              expect(
                chapter,
                greaterThanOrEqualTo(EnemyVariant.firstChapter),
                reason: 'variant leaked into chapter $chapter',
              );
              sawLateVariant = true;
            }
          }
        }
      }

      expect(
        sawLateVariant,
        isTrue,
        reason: 'chapters 9-12 recombine the roster; none did',
      );
    });
  });

  group('generated rooms', () {
    test('10,000 rooms across the campaign break no rule', () {
      final Rng rng = Rng(20260720);
      final List<String> failures = <String>[];

      for (int i = 0; i < 10000; i++) {
        final int chapter = 1 + i % 12;
        final int globalStage = 1 + (chapter - 1) * 20 + i % 20;
        final bool isElite = i % 7 == 0;

        final RoomPlan plan = RoomComposer.compose(
          content: content,
          rng: rng,
          chapter: chapter,
          globalStage: globalStage,
          isElite: isElite,
        );

        final List<CompositionViolation> violations =
            CompositionValidator.validate(plan, content);
        if (violations.isNotEmpty) {
          failures.add('chapter $chapter stage $globalStage: $violations');
        }
      }

      expect(failures, isEmpty, reason: failures.take(5).join('\n'));
    });

    test('every room is winnable — it contains something', () {
      final Rng rng = Rng(5);
      for (int stage = 1; stage <= 240; stage += 7) {
        final RoomPlan plan = RoomComposer.compose(
          content: content,
          rng: rng,
          chapter: 1 + (stage - 1) ~/ 20,
          globalStage: stage,
        );
        expect(plan.totalEnemies, greaterThan(0), reason: 'stage $stage empty');
      }
    });

    test('no wave exceeds the on-screen enemy cap', () {
      final Rng rng = Rng(13);
      for (int stage = 1; stage <= 240; stage += 3) {
        final RoomPlan plan = RoomComposer.compose(
          content: content,
          rng: rng,
          chapter: 1 + (stage - 1) ~/ 20,
          globalStage: stage,
        );
        for (final WavePlan wave in plan.waves) {
          expect(wave.size, lessThanOrEqualTo(SimConfig.maxContactEnemies));
        }
      }
    });

    test('the same seed produces the same room', () {
      RoomPlan build() => RoomComposer.compose(
            content: content,
            rng: Rng(4242),
            chapter: 9,
            globalStage: 170,
          );

      final RoomPlan a = build();
      final RoomPlan b = build();

      expect(a.totalEnemies, b.totalEnemies);
      for (int w = 0; w < a.waves.length; w++) {
        for (int i = 0; i < a.waves[w].size; i++) {
          expect(
            a.waves[w].enemies[i].contentIndex,
            b.waves[w].enemies[i].contentIndex,
          );
          expect(a.waves[w].enemies[i].variant, b.waves[w].enemies[i].variant);
        }
      }
    });
  });
}
