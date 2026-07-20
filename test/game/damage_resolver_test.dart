import 'package:quiverfall/core/rng.dart';
import 'package:quiverfall/game/balance/damage.dart';
import 'package:test/test.dart';

/// The damage chain from docs/08-arrows.md §8.1.
///
/// Structure of this file:
///
///  - **Hand-verified cases** prove the formula is arithmetically correct. The
///    expected values are computed by hand in the comments, not by running the
///    code and pasting the output.
///  - **Clamp cases** prove each ceiling holds independently.
///  - **A 600-case golden table** locks the whole surface against silent
///    regression. It cannot prove correctness (it is generated from this
///    implementation), which is exactly why the hand-verified cases exist.
void main() {
  group('hand-verified arithmetic', () {
    test('a plain tier-I hit is attack x arrow coefficient', () {
      // 100 * 1.0 * 1.00 = 100
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.0,
          drawTierMultiplier: 1.00,
        ),
        closeTo(100.0, 1e-9),
      );
    });

    test('tier III triples nothing — it is exactly 2.10x', () {
      // 100 * 1.0 * 2.10 = 210
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.0,
          drawTierMultiplier: 2.10,
        ),
        closeTo(210.0, 1e-9),
      );
    });

    test('Broadhead at tier II', () {
      // Broadhead baseMult 1.28, tier II 1.45.
      // 100 * 1.28 * 1.45 = 185.6
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.28,
          drawTierMultiplier: 1.45,
        ),
        closeTo(185.6, 1e-9),
      );
    });

    test('tier III with a x3 Confluence', () {
      // 100 * 1.0 * 2.10 * (1 + 1.60) = 210 * 2.6 = 546
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.0,
          drawTierMultiplier: 2.10,
          confluenceBonus: 1.60,
        ),
        closeTo(546.0, 1e-9),
      );
    });

    test('the full chain composes in the documented order', () {
      // 100 * 1.0 * 2.10 * 2.60 * 1.80 * 1.25 * 1.10 * 0.85^2 * 1.0
      //   = 546 * 1.8            = 982.8
      //   * 1.25                 = 1228.5
      //   * 1.10                 = 1351.35
      //   * 0.7225               = 976.350375
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.0,
          drawTierMultiplier: 2.10,
          confluenceBonus: 1.60,
          isCrit: true,
          boonDamageSum: 0.25,
          elementalBonus: 0.10,
          pierceIndex: 2,
        ),
        closeTo(976.350375, 1e-6),
      );
    });

    test('a Husk plate reduces a tier-I hit to a tenth', () {
      // 100 * 1.0 * 1.00 * 0.10 = 10
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.0,
          drawTierMultiplier: 1.00,
          armourFactor: ArmourFactor.plateBlocked,
        ),
        closeTo(10.0, 1e-9),
      );
    });

    test('plate damage is non-zero on purpose', () {
      // A hard zero would read as "my weapon is broken" rather than "I need a
      // heavier shot" — see docs/05 §5.2.
      expect(ArmourFactor.plateBlocked, greaterThan(0));
    });
  });

  group('additive Boons, multiplicative sources', () {
    test('twenty Boons sum rather than compounding', () {
      // The rule that stops a long run producing a five-figure multiplier
      // (docs/04 §4.1). Twenty 8% Boons are +160%, not 1.08^20 = +366%.
      const double each = 0.08;
      const int count = 20;

      final double additive = DamageResolver.resolve(
        attack: 100,
        arrowBaseMultiplier: 1.0,
        drawTierMultiplier: 1.0,
        boonDamageSum: each * count,
      );

      double compounded = 100;
      for (int i = 0; i < count; i++) {
        compounded *= 1 + each;
      }

      expect(additive, closeTo(260.0, 1e-9));
      expect(compounded, greaterThan(460));
      expect(additive, lessThan(compounded * 0.6));
    });
  });

  group('clamps', () {
    test('the Draw tier multiplier cannot exceed 2.10', () {
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.0,
          drawTierMultiplier: 99.0,
        ),
        closeTo(210.0, 1e-9),
      );
    });

    test('Confluence is capped at +160% by default', () {
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.0,
          drawTierMultiplier: 1.0,
          confluenceBonus: 99.0,
        ),
        closeTo(260.0, 1e-9),
      );
    });

    test('Iris may exceed the default Confluence ceiling', () {
      // Her passive raises the *stack cap* to 5, worth +320%, and the resolver
      // is told so explicitly rather than the global ceiling being loosened for
      // everyone.
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.0,
          drawTierMultiplier: 1.0,
          confluenceBonus: 3.20,
          confluenceCeiling: DamageResolver.maxConfluenceIris,
        ),
        closeTo(420.0, 1e-9),
      );
    });

    test('a negative Boon sum cannot invert damage', () {
      final double d = DamageResolver.resolve(
        attack: 100,
        arrowBaseMultiplier: 1.0,
        drawTierMultiplier: 1.0,
        boonDamageSum: -50.0,
      );
      expect(d, greaterThanOrEqualTo(0));
      expect(d, closeTo(5.0, 1e-9)); // clamped to -0.95
    });

    test('armour factor is confined to [0,1]', () {
      expect(
        DamageResolver.resolve(
          attack: 100,
          arrowBaseMultiplier: 1.0,
          drawTierMultiplier: 1.0,
          armourFactor: 5.0,
        ),
        closeTo(100.0, 1e-9),
      );
    });
  });

  group('pierce falloff', () {
    test('converges rather than exploding', () {
      // Boon 25 (*The Long Arrow*) grants infinite pierce. Falloff is what makes
      // that strong rather than unbounded.
      expect(DamageResolver.pierceFalloff(0), 1.0);
      expect(DamageResolver.pierceFalloff(1), closeTo(0.85, 1e-9));
      expect(DamageResolver.pierceFalloff(9), closeTo(0.2316, 1e-4));

      // Even at 50 targets the total is bounded.
      double total = 0;
      for (int i = 0; i < 50; i++) {
        total += DamageResolver.pierceFalloff(i);
      }
      expect(total, lessThan(1 / (1 - DamageResolver.pierceFalloffPerHit)));
    });
  });

  group('damage reduction', () {
    test('combines multiplicatively, never additively', () {
      // Three 40% sources: additive would be 120% and heal the player.
      // Multiplicative is 1 - 0.6^3 = 78.4%, then capped at 75%.
      final double taken = DamageResolver.applyDamageReduction(
        100,
        <double>[0.4, 0.4, 0.4],
      );
      expect(taken, closeTo(25.0, 1e-9));
    });

    test('is capped at 75%', () {
      final double taken = DamageResolver.applyDamageReduction(
        100,
        <double>[0.9, 0.9, 0.9, 0.9],
      );
      expect(taken, closeTo(25.0, 1e-9));
      expect(taken, greaterThan(0), reason: 'the player is never invulnerable');
    });

    test('the two-source fast path agrees with the list version', () {
      for (final List<double> pair in <List<double>>[
        <double>[0.0, 0.0],
        <double>[0.2, 0.3],
        <double>[0.5, 0.5],
        <double>[0.7, 0.6],
      ]) {
        expect(
          DamageResolver.applyDamageReduction2(100, pair[0], pair[1]),
          closeTo(DamageResolver.applyDamageReduction(100, pair), 1e-9),
        );
      }
    });
  });

  group('golden table', () {
    test('600 cases are stable', () {
      // Locks the whole surface against silent regression. Generated from a
      // fixed seed so the case set never drifts.
      //
      // This proves *stability*, not correctness — it is produced by the code
      // under test. Correctness is the hand-verified group above. If a change
      // here is intentional, the checksum below is updated deliberately and the
      // diff is reviewed; that is the point.
      final Rng rng = Rng(80808);
      final StringBuffer digest = StringBuffer();
      int nonZero = 0;

      for (int i = 0; i < 600; i++) {
        final double damage = DamageResolver.resolve(
          attack: rng.nextDoubleRange(1, 5000),
          arrowBaseMultiplier: rng.nextDoubleRange(0.7, 1.4),
          drawTierMultiplier: rng.pick(<double>[1.00, 1.45, 2.10]),
          confluenceBonus: rng.pick(<double>[0, 0.40, 0.90, 1.60]),
          isCrit: rng.chance(0.3),
          boonDamageSum: rng.nextDoubleRange(0, 2.5),
          elementalBonus: rng.nextDoubleRange(0, 0.8),
          pierceIndex: rng.nextInt(6),
          armourFactor: rng.pick(<double>[
            ArmourFactor.plateBlocked,
            ArmourFactor.platePartial,
            ArmourFactor.none,
          ]),
        );

        expect(damage.isFinite, isTrue, reason: 'case $i produced $damage');
        expect(damage, greaterThanOrEqualTo(0), reason: 'case $i');
        if (damage > 0) nonZero++;

        digest.write(damage.toStringAsFixed(6));
        digest.write(';');
      }

      expect(nonZero, 600, reason: 'no case should resolve to zero damage');

      final int checksum = _fnv1a(digest.toString());
      expect(
        checksum,
        _goldenChecksum,
        reason: 'The damage chain changed. If that was intentional, review the '
            'diff and update _goldenChecksum. If it was not, something '
            'reordered or rescaled a term.',
      );
    });

    test('the chain is monotonic in attack', () {
      // A sanity property no reordering can preserve by accident.
      double previous = -1;
      for (int atk = 1; atk <= 500; atk++) {
        final double d = DamageResolver.resolve(
          attack: atk.toDouble(),
          arrowBaseMultiplier: 1.1,
          drawTierMultiplier: 1.45,
          confluenceBonus: 0.9,
          boonDamageSum: 0.4,
          pierceIndex: 1,
        );
        expect(d, greaterThan(previous));
        previous = d;
      }
    });
  });
}

/// Regenerate deliberately, never reflexively. See the golden-table test.
const int _goldenChecksum = 2833635684;

/// FNV-1a, 32-bit.
///
/// Deliberately not `String.hashCode`: Dart makes no stability guarantee for it
/// across SDK versions or platforms, so a golden value built on it would fail
/// spuriously after a toolchain upgrade — the worst kind of test failure,
/// because it trains people to update the constant without reading the diff.
int _fnv1a(String s) {
  int hash = 0x811C9DC5;
  for (int i = 0; i < s.length; i++) {
    hash ^= s.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
