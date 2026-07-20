import 'package:quiverfall/core/rng.dart';
import 'package:test/test.dart';

void main() {
  group('determinism', () {
    test('same seed produces the same sequence', () {
      final List<int> a =
          List<int>.generate(500, (_) => Rng(12345).nextInt(1000));
      final Rng single = Rng(12345);
      final List<int> b = List<int>.generate(500, (_) => single.nextInt(1000));

      // Every fresh Rng(12345) starts at the same place.
      expect(a.first, b.first);

      final Rng x = Rng(999);
      final Rng y = Rng(999);
      for (int i = 0; i < 1000; i++) {
        expect(x.nextInt64(), y.nextInt64(), reason: 'diverged at $i');
      }
    });

    test('different seeds diverge immediately', () {
      final Rng a = Rng(1);
      final Rng b = Rng(2);
      final List<int> first =
          List<int>.generate(10, (_) => a.nextInt(1 << 20));
      final List<int> second =
          List<int>.generate(10, (_) => b.nextInt(1 << 20));
      expect(first, isNot(equals(second)));
    });

    test('small seeds are well distributed', () {
      // xorshift128+ seeded naively from a small integer produces a visibly
      // poor first few outputs. SplitMix64 expansion is what prevents that, and
      // seeds 0/1/2 are exactly what tests use.
      final List<int> firsts = <int>[
        for (int seed = 0; seed < 8; seed++) Rng(seed).nextInt(1000000),
      ];
      expect(firsts.toSet().length, 8, reason: 'seeds collided');
    });

    test('state capture and restore resumes mid-stream', () {
      final Rng original = Rng(7);
      for (int i = 0; i < 50; i++) {
        original.nextInt64();
      }

      final RngState captured = original.state;
      final List<int> expected =
          List<int>.generate(20, (_) => original.nextInt64());

      final Rng restored = Rng.fromState(captured);
      final List<int> actual =
          List<int>.generate(20, (_) => restored.nextInt64());

      expect(actual, expected);
    });

    test('state survives a JSON round trip', () {
      final Rng rng = Rng(42);
      rng.nextInt64();
      final RngState state = rng.state;
      expect(RngState.fromJson(state.toJson()), state);
    });

    test('split produces independent streams', () {
      // Each subsystem gets its own stream from one run seed, so consuming an
      // extra Boon draw must not shift enemy composition in a later room.
      final Rng parent = Rng(2024);
      final Rng boons = parent.split(1);
      final Rng enemies = parent.split(2);

      final List<int> a = List<int>.generate(20, (_) => boons.nextInt(100));
      final List<int> b = List<int>.generate(20, (_) => enemies.nextInt(100));
      expect(a, isNot(equals(b)));
    });
  });

  group('distribution', () {
    test('nextInt covers its range without bias', () {
      final Rng rng = Rng(3);
      final List<int> buckets = List<int>.filled(7, 0);
      const int samples = 700000;
      for (int i = 0; i < samples; i++) {
        buckets[rng.nextInt(7)]++;
      }

      const double expected = samples / 7;
      for (final int count in buckets) {
        // 7 is not a power of two, so this is the rejection-sampling path.
        // A modulo implementation would show a measurable skew here.
        expect(
          (count - expected).abs() / expected,
          lessThan(0.02),
          reason: 'bucket skew: $buckets',
        );
      }
    });

    test('power-of-two ranges use the mask path correctly', () {
      final Rng rng = Rng(11);
      final Set<int> seen = <int>{};
      for (int i = 0; i < 10000; i++) {
        final int v = rng.nextInt(8);
        expect(v, inInclusiveRange(0, 7));
        seen.add(v);
      }
      expect(seen.length, 8);
    });

    test('nextDouble stays in [0,1)', () {
      final Rng rng = Rng(5);
      for (int i = 0; i < 100000; i++) {
        final double v = rng.nextDouble();
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });

    test('chance honours its probability', () {
      final Rng rng = Rng(17);
      int hits = 0;
      const int samples = 200000;
      for (int i = 0; i < samples; i++) {
        if (rng.chance(0.25)) hits++;
      }
      expect(hits / samples, closeTo(0.25, 0.005));
    });

    test('chance treats 0 and 1 as absolute', () {
      final Rng rng = Rng(1);
      for (int i = 0; i < 100; i++) {
        expect(rng.chance(0), isFalse);
        expect(rng.chance(1), isTrue);
      }
    });
  });

  group('weighted picking — the Boon rarity primitive', () {
    test('respects the weight distribution', () {
      // The launch rarity weights from docs/09-skills.md §9.1.
      final Rng rng = Rng(99);
      const List<double> weights = <double>[0.58, 0.27, 0.11, 0.035, 0.005];
      final List<int> counts = List<int>.filled(5, 0);
      const int samples = 400000;

      for (int i = 0; i < samples; i++) {
        counts[rng.pickWeightedIndex(weights)]++;
      }

      expect(counts[0] / samples, closeTo(0.58, 0.005));
      expect(counts[1] / samples, closeTo(0.27, 0.005));
      expect(counts[2] / samples, closeTo(0.11, 0.005));
      expect(counts[3] / samples, closeTo(0.035, 0.003));
      expect(counts[4] / samples, closeTo(0.005, 0.002));
    });

    test('never returns an index with zero weight', () {
      final Rng rng = Rng(4);
      const List<double> weights = <double>[1, 0, 1, 0];
      for (int i = 0; i < 10000; i++) {
        expect(weights[rng.pickWeightedIndex(weights)], greaterThan(0));
      }
    });
  });

  group('shuffle', () {
    test('is a permutation', () {
      final Rng rng = Rng(8);
      final List<int> items = List<int>.generate(100, (int i) => i);
      rng.shuffle(items);
      expect(items.length, 100);
      expect(items.toSet(), List<int>.generate(100, (int i) => i).toSet());
    });

    test('is deterministic for a given seed', () {
      final List<int> a = List<int>.generate(50, (int i) => i);
      final List<int> b = List<int>.generate(50, (int i) => i);
      Rng(123).shuffle(a);
      Rng(123).shuffle(b);
      expect(a, b);
    });
  });
}
