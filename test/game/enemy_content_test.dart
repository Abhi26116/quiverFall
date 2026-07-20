import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:test/test.dart';

import 'enemy_test_support.dart';

void main() {
  late ContentLibrary content;

  setUpAll(() {
    content = loadEnemies();
  });

  group('the shipping enemy table', () {
    test('loads with no errors', () {
      // loadEnemies throws on any validation error, so reaching here is the
      // assertion. Repeated explicitly because this is the single most
      // load-bearing fact in the phase.
      expect(content.enemies, hasLength(EnemyArchetype.values.length));
    });

    test('authors all 26 archetypes exactly once', () {
      for (final EnemyArchetype archetype in EnemyArchetype.values) {
        expect(
          content.indexOfArchetype(archetype),
          greaterThanOrEqualTo(0),
          reason: '${archetype.name} has no entry in enemies.json',
        );
      }
      expect(content.enemies, hasLength(26));
    });

    test('every family has the roster docs/05 gives it', () {
      final Map<EnemyFamily, int> counts = <EnemyFamily, int>{};
      for (final EnemyDefinition d in content.enemies) {
        counts[d.family] = (counts[d.family] ?? 0) + 1;
      }
      expect(counts[EnemyFamily.drift], 4);
      expect(counts[EnemyFamily.carapace], 4);
      expect(counts[EnemyFamily.rush], 5);
      expect(counts[EnemyFamily.salvo], 5);
      expect(counts[EnemyFamily.choir], 4);
      expect(counts[EnemyFamily.riftborn], 4);
    });

    test('matches the chapter introduction schedule in docs/05 §5.8', () {
      for (final MapEntry<EnemyArchetype, int> entry
          in introductionSchedule.entries) {
        expect(
          content.byArchetype(entry.key).introducedInChapter,
          entry.value,
          reason: '${entry.key.name} should arrive in chapter ${entry.value}',
        );
      }
    });

    test('all 26 base types are available by chapter 8', () {
      expect(content.enemiesUpToChapter(8), hasLength(26));
      // Front-loaded on purpose: novelty after chapter 8 comes from Variants,
      // Boons and bosses, which are far cheaper to author than new units.
      expect(content.enemiesUpToChapter(7), hasLength(25));
    });

    test('every damaging special telegraphs, or is documented not to', () {
      const Set<EnemyArchetype> exempt = <EnemyArchetype>{
        // Permanent aura, permanently visible. No gap to telegraph.
        EnemyArchetype.thresher,
        // Fires when the player fires; the player's own shot is the telegraph.
        EnemyArchetype.echo,
      };

      for (final EnemyDefinition d in content.enemies) {
        if (d.combat.attackDamage <= 0) continue;
        if (exempt.contains(d.archetype)) continue;
        expect(
          d.combat.windUpSeconds,
          greaterThan(0),
          reason: '${d.name} attacks without a wind-up',
        );
      }
    });

    test('no enemy two-shots the player', () {
      // Threat is a fraction of max HP, so this holds at every point on a 300x
      // power curve rather than only at the tuning stage.
      for (final EnemyDefinition d in content.enemies) {
        expect(d.contactDamage, lessThan(0.5), reason: d.name);
        expect(d.combat.attackDamage, lessThan(0.5), reason: d.name);
        expect(d.combat.deathBlastDamage, lessThan(0.5), reason: d.name);
      }
      // The Longeye is the heaviest hitter in the game and sits at 22%.
      final double heaviest = content.enemies
          .map((EnemyDefinition d) => d.combat.attackDamage)
          .reduce((double a, double b) => a > b ? a : b);
      expect(heaviest, closeTo(0.22, 1e-9));
      expect(
        content.byArchetype(EnemyArchetype.longeye).combat.attackDamage,
        heaviest,
      );
    });

    test('only Rush enemies can outrun the player', () {
      for (final EnemyDefinition d in content.enemies) {
        if (d.speed <= SimConfig.playerMoveSpeed) continue;
        expect(
          d.family,
          EnemyFamily.rush,
          reason: '${d.name} outruns the player but is not Rush',
        );
      }
    });

    test('every attack fits inside the arena', () {
      // An attack that outranges the arena cannot be escaped by moving, which
      // makes its counter-play a lie.
      const double diagonal = 18.4; // sqrt(16^2 + 9^2), rounded up
      for (final EnemyDefinition d in content.enemies) {
        expect(d.combat.attackRange, lessThanOrEqualTo(diagonal), reason: d.name);
      }
    });

    test('every Carapace enemy has a plate and a flank', () {
      for (final EnemyDefinition d in content.enemies) {
        if (d.family != EnemyFamily.carapace) continue;
        expect(d.hasFrontalPlate, isTrue, reason: d.name);
        expect(d.plateArcDegrees, lessThan(360), reason: '${d.name} has no rear');
      }
    });

    test('a summoner cannot summon without a cap', () {
      for (final EnemyDefinition d in content.enemies) {
        if (d.combat.spawnsId == null) continue;
        expect(d.combat.spawnCap, greaterThan(0), reason: d.name);
        expect(content.enemyById(d.combat.spawnsId!), isNotNull);
      }
    });
  });

  group('content validation rejects', () {
    List<ContentError> errorsFor(String body) =>
        ContentLibrary.parse(enemiesJson: body).$2;

    String table(String enemy) => '{"enemies": [$enemy]}';

    const String validMote = '''
      {"id": "mote", "name": "Mote", "family": "drift", "hpMultiplier": 1.0,
       "speed": 1.6, "contactDamage": 0.06, "radius": 0.22, "threatCost": 4.0,
       "goldWeight": 1.0, "materialChance": 0.04}
    ''';

    test('an unknown enemy id', () {
      final List<ContentError> errors =
          errorsFor(table(validMote.replaceAll('"mote"', '"gribbly"')));
      expect(errors, isNotEmpty);
    });

    test('a family that disagrees with the archetype', () {
      final List<ContentError> errors =
          errorsFor(table(validMote.replaceAll('"drift"', '"riftborn"')));
      expect(
        errors.any((ContentError e) => e.path.endsWith('.family')),
        isTrue,
        reason: 'a mislabelled family must fail the build',
      );
    });

    test('contact damage that would two-shot the player', () {
      final List<ContentError> errors =
          errorsFor(table(validMote.replaceAll('0.06', '0.7')));
      expect(
        errors.any((ContentError e) => e.path.endsWith('.contactDamage')),
        isTrue,
      );
    });

    test('a Drift enemy that outruns the player', () {
      final List<ContentError> errors =
          errorsFor(table(validMote.replaceAll('"speed": 1.6', '"speed": 4.0')));
      expect(errors.any((ContentError e) => e.path.endsWith('.speed')), isTrue);
    });

    test('an undertelegraphed attack', () {
      const String sneaky = '''
        {"id": "lancer", "name": "Lancer", "family": "rush", "hpMultiplier": 1.4,
         "speed": 3.4, "contactDamage": 0.05, "radius": 0.3, "threatCost": 9.0,
         "goldWeight": 2.2, "materialChance": 0.1,
         "combat": {"attackDamage": 0.12, "attackRange": 5.0,
                    "attackCooldown": 1.2}}
      ''';
      final List<ContentError> errors = errorsFor(table(sneaky));
      expect(
        errors.any((ContentError e) => e.path.endsWith('.windUpSeconds')),
        isTrue,
        reason: 'the telegraph rule must be enforced by the loader',
      );
    });

    test('an incomplete roster', () {
      final List<ContentError> errors = errorsFor(table(validMote));
      expect(
        errors.where((ContentError e) => e.message.contains('no entry')),
        hasLength(EnemyArchetype.values.length - 1),
      );
    });
  });
}
