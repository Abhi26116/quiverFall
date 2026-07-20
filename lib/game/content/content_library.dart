import 'dart:convert';

import 'package:quiverfall/game/content/enemy_definition.dart';

/// A problem found while loading content.
class ContentError {
  const ContentError(this.file, this.path, this.message);

  final String file;

  /// Where in the document, e.g. `enemies[3].speed`.
  final String path;

  final String message;

  @override
  String toString() => '$file: $path — $message';
}

/// All static game content, parsed and indexed.
///
/// **Content is not player state.** It ships as versioned JSON in
/// `assets/data/`, is read-only at runtime, and is overlaid by remote config so
/// live-ops can retune balance without a client release. Keeping it in a
/// separate system from the save is what makes that safe — see
/// docs/13-database.md §13.0.
///
/// **This class does no I/O.** It takes strings. The Flutter layer fetches them
/// from `rootBundle`; the headless balance harness reads them with `dart:io`;
/// tests pass literals. That is what keeps the game layer pure and the harness
/// possible.
class ContentLibrary {
  ContentLibrary._({
    required this.enemies,
    required this.enemyIndexById,
    required List<int> enemyIndexByArchetype,
  }) : _byArchetype = enemyIndexByArchetype;

  /// Ordered enemy table. Entities reference definitions by *index* into this
  /// list (`EntityStore.contentIndex`), not by string id, so the hot path never
  /// touches a map lookup or a string comparison.
  final List<EnemyDefinition> enemies;

  final Map<String, int> enemyIndexById;

  /// Archetype ordinal to table index. The AI resolves a definition on every
  /// enemy on every tick, so this has to be an array read.
  final List<int> _byArchetype;

  static ContentLibrary empty() => ContentLibrary._(
        enemies: const <EnemyDefinition>[],
        enemyIndexById: const <String, int>{},
        enemyIndexByArchetype:
            List<int>.filled(EnemyArchetype.values.length, -1),
      );

  /// Parses and validates content.
  ///
  /// Returns errors rather than throwing, so the build-time validator can
  /// report *every* problem in one run instead of one per invocation.
  static (ContentLibrary?, List<ContentError>) parse({
    required String enemiesJson,
  }) {
    final List<ContentError> errors = <ContentError>[];

    final List<EnemyDefinition> enemies = _parseEnemies(enemiesJson, errors);
    if (errors.isNotEmpty) return (null, errors);

    final Map<String, int> byId = <String, int>{};
    final List<int> byArchetype =
        List<int>.filled(EnemyArchetype.values.length, -1);

    for (int i = 0; i < enemies.length; i++) {
      final String id = enemies[i].id;
      if (byId.containsKey(id)) {
        errors.add(
          ContentError('enemies.json', 'enemies[$i].id', 'duplicate id "$id"'),
        );
        continue;
      }
      byId[id] = i;
      byArchetype[enemies[i].archetype.index] = i;
    }
    if (errors.isNotEmpty) return (null, errors);

    _validateRoster(enemies, byId, errors);
    if (errors.isNotEmpty) return (null, errors);

    return (
      ContentLibrary._(
        enemies: enemies,
        enemyIndexById: byId,
        enemyIndexByArchetype: byArchetype,
      ),
      const <ContentError>[],
    );
  }

  static List<EnemyDefinition> _parseEnemies(
    String source,
    List<ContentError> errors,
  ) {
    const String file = 'enemies.json';
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      errors.add(ContentError(file, '<root>', 'not valid JSON: $e'));
      return const <EnemyDefinition>[];
    }

    if (decoded is! Map<String, dynamic>) {
      errors.add(const ContentError(file, '<root>', 'expected an object'));
      return const <EnemyDefinition>[];
    }

    final Object? list = decoded['enemies'];
    if (list is! List) {
      errors.add(const ContentError(file, 'enemies', 'expected an array'));
      return const <EnemyDefinition>[];
    }

    final List<EnemyDefinition> out = <EnemyDefinition>[];
    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'enemies[$i]', 'expected an object'));
        continue;
      }
      try {
        final EnemyDefinition def = EnemyDefinition.fromJson(raw);
        _validateEnemy(def, raw, i, errors);
        out.add(def);
      } catch (e) {
        errors.add(ContentError(file, 'enemies[$i]', 'malformed: $e'));
      }
    }
    return out;
  }

  /// Range checks that encode real design rules, not just type safety.
  ///
  /// A malformed enemy entry must fail the build, never crash a player's phone
  /// in chapter 7 (docs/13 §13.11).
  static void _validateEnemy(
    EnemyDefinition d,
    Map<String, dynamic> raw,
    int i,
    List<ContentError> errors,
  ) {
    const String file = 'enemies.json';
    void bad(String field, String message) =>
        errors.add(ContentError(file, 'enemies[$i].$field', message));

    if (d.hpMultiplier <= 0) bad('hpMultiplier', 'must be > 0');
    if (d.speed < 0) bad('speed', 'must be >= 0');
    if (d.radius <= 0) bad('radius', 'must be > 0');
    if (d.threatCost <= 0) bad('threatCost', 'must be > 0');
    if (d.goldWeight <= 0) bad('goldWeight', 'must be > 0');

    // The `family` key is redundant with the archetype and exists purely so the
    // table reads as a design document. Cross-checking it is what stops it from
    // quietly becoming a lie during a copy-paste.
    final Object? declaredFamily = raw['family'];
    if (declaredFamily != null && declaredFamily != d.family.name) {
      bad(
        'family',
        'declared "$declaredFamily" but ${d.id} is ${d.family.name}',
      );
    }

    // Contact damage is a fraction of player max HP. Anything at or above 0.5
    // two-shots the player, which no common enemy may do — the heaviest hitter
    // in the game (Longeye) sits at 0.22.
    if (d.contactDamage < 0 || d.contactDamage >= 0.5) {
      bad('contactDamage', 'must be in [0, 0.5) — it is a fraction of max HP');
    }

    if (d.materialChance < 0 || d.materialChance > 1) {
      bad('materialChance', 'must be a probability in [0, 1]');
    }

    // A stationary Rush enemy, or a Drift enemy faster than the player, means
    // the family tag and the stats disagree — almost always a copy-paste error.
    if (d.family == EnemyFamily.rush && d.speed <= 0) {
      bad('speed', 'a rush enemy must move');
    }
    if (d.family == EnemyFamily.drift && d.speed > 3.20) {
      bad('speed', 'a drift enemy must not outrun the player (3.20)');
    }

    if (d.plateRegenSeconds > 0 && !d.hasFrontalPlate) {
      bad('plateRegenSeconds', 'set without hasFrontalPlate');
    }
    if (d.hasFrontalPlate &&
        (d.plateArcDegrees <= 0 || d.plateArcDegrees >= 360)) {
      bad('plateArcDegrees', 'must be in (0, 360) — 360 leaves no flank');
    }

    if (d.introducedInChapter < 1 || d.introducedInChapter > 12) {
      bad('introducedInChapter', 'must be in [1, 12]');
    }

    _validateCombat(d, i, errors);
  }

  static void _validateCombat(
    EnemyDefinition d,
    int i,
    List<ContentError> errors,
  ) {
    const String file = 'enemies.json';
    final EnemyCombat c = d.combat;
    void bad(String field, String message) =>
        errors.add(ContentError(file, 'enemies[$i].combat.$field', message));

    if (c.attackDamage < 0 || c.attackDamage >= 0.5) {
      bad('attackDamage', 'must be in [0, 0.5) — it is a fraction of max HP');
    }
    if (c.deathBlastDamage < 0 || c.deathBlastDamage >= 0.5) {
      bad('deathBlastDamage', 'must be in [0, 0.5)');
    }
    if (c.contactCooldown <= 0) {
      bad('contactCooldown', 'must be > 0, or contact damage ticks every frame');
    }

    // **Every damaging special has a telegraph.** This is the single rule the
    // whole enemy roster is built on (docs/05 §5.2): the telegraph precedes the
    // threat, always. An attack that arrives unannounced is not difficulty, it
    // is a bug the player experiences as unfairness.
    //
    // Two archetypes are exempt, and both are exempt in the design rather than
    // by oversight. The Thresher's aura is permanent, always visible as a
    // hard-edged crimson ring, and has no wind-up because it has no gap. The
    // Echo fires exactly when the player fires, so the player's own shot *is*
    // the telegraph — which is the whole joke of the enemy.
    if (c.attackDamage > 0 &&
        c.windUpSeconds <= 0 &&
        d.archetype != EnemyArchetype.thresher &&
        d.archetype != EnemyArchetype.echo) {
      bad('windUpSeconds', 'a damaging attack must telegraph');
    }

    if (c.attackDamage > 0 && c.attackCooldown <= 0) {
      bad('attackCooldown', 'a repeating attack needs a cadence');
    }
    if (c.attackDamage > 0 && c.attackRange <= 0) {
      bad('attackRange', 'an attack needs a range');
    }

    if (c.projectileCount > 0 &&
        c.projectileSpeed <= 0 &&
        c.flightSeconds <= 0) {
      bad(
        'projectileSpeed',
        'projectiles need either a speed or a fixed flight time',
      );
    }
    if (c.spreadDegrees < 0 || c.spreadDegrees > 360) {
      bad('spreadDegrees', 'must be in [0, 360]');
    }

    if (c.auraRadius > 0 && c.auraStrength <= 0) {
      bad('auraStrength', 'an aura with no strength does nothing');
    }
    if (c.auraStrength > 0 && c.auraRadius <= 0) {
      bad('auraRadius', 'an aura needs a radius');
    }

    if (c.deathBlastDamage > 0 && c.deathBlastRadius <= 0) {
      bad('deathBlastRadius', 'a blast needs a radius');
    }

    if (c.reviveCount > 0 &&
        (c.reviveHealthFraction <= 0 || c.reviveHealthFraction > 1)) {
      bad('reviveHealthFraction', 'must be in (0, 1]');
    }

    if (c.spawnsId != null && (c.spawnCount <= 0 || c.spawnCap <= 0)) {
      // Uncapped summoning is how a procedural room becomes unwinnable.
      bad('spawnCap', 'a summoner needs both a count and a cap');
    }
  }

  /// Whole-table rules: completeness and cross-references.
  static void _validateRoster(
    List<EnemyDefinition> enemies,
    Map<String, int> byId,
    List<ContentError> errors,
  ) {
    const String file = 'enemies.json';

    // Every archetype must be authored. A behaviour branch with no data behind
    // it is a crash waiting for the chapter that first spawns it.
    for (final EnemyArchetype a in EnemyArchetype.values) {
      if (!byId.containsKey(a.name)) {
        errors.add(
          ContentError(file, 'enemies', 'no entry for archetype "${a.name}"'),
        );
      }
    }

    for (int i = 0; i < enemies.length; i++) {
      final String? spawns = enemies[i].combat.spawnsId;
      if (spawns != null && !byId.containsKey(spawns)) {
        errors.add(
          ContentError(
            file,
            'enemies[$i].combat.spawnsId',
            'unknown enemy "$spawns"',
          ),
        );
      }
    }
  }

  EnemyDefinition? enemyById(String id) {
    final int? i = enemyIndexById[id];
    return i == null ? null : enemies[i];
  }

  int indexOfArchetype(EnemyArchetype archetype) =>
      _byArchetype[archetype.index];

  EnemyDefinition byArchetype(EnemyArchetype archetype) =>
      enemies[_byArchetype[archetype.index]];

  /// Enemies available by a given chapter. Used by the room generator.
  List<EnemyDefinition> enemiesUpToChapter(int chapter) => enemies
      .where((EnemyDefinition e) => e.introducedInChapter <= chapter)
      .toList(growable: false);
}
