import 'dart:convert';

import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/content/boss_catalogue.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/level/arena_definition.dart';
import 'package:quiverfall/game/marks/mark_catalogue.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/spire/spire_catalogue.dart';

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
    this.arenas = const <ArenaDefinition>[],
    required this.heroes,
    required this.arrows,
    required this.affixes,
    required this.bosses,
    required this.spire,
    required this.marks,
  }) : _byArchetype = enemyIndexByArchetype;

  /// Ordered enemy table. Entities reference definitions by *index* into this
  /// list (`EntityStore.contentIndex`), not by string id, so the hot path never
  /// touches a map lookup or a string comparison.
  final List<EnemyDefinition> enemies;

  final Map<String, int> enemyIndexById;

  /// Authored arenas. Empty is legal — the Phase 5 composer and every headless
  /// test work without geometry, and only the level generator needs them.
  final List<ArenaDefinition> arenas;

  /// The 20 heroes, 12 arrows, and 17 affixes — docs/07 and docs/08. Each is
  /// independently parseable and independently tested (own
  /// `xxx_catalogue_test.dart`); [ContentLibrary] only aggregates the ones
  /// the running app's Hero/Gear/Loadout screens need in one place to load,
  /// the way the folder structure in docs/12-architecture.md §12.2 always
  /// named this directory for ("loaders for enemies/bosses/boons/heroes
  /// JSON"). The Boon pool is deliberately not here — `StageRunner` already
  /// takes its own `BoonCatalogue` (plus the separate `SynergyCatalogue`
  /// boons.json alone does not cover), so folding a second, narrower Boon
  /// load in here would just be a second source of truth for the same
  /// content. A feature that only needs one catalogue (a test, the balance
  /// harness) can keep constructing it directly instead — nothing requires
  /// going through [ContentLibrary]. Bosses, unlike Boons, *are* here
  /// ([bosses] below) — `BossPhaseSystem` sits on the sim's own hot tick
  /// path the same way enemy AI does, so it needs the identical
  /// load-once-at-bootstrap treatment [enemies] already gets, not a
  /// feature-local load a screen might skip.
  final HeroCatalogue heroes;
  final ArrowCatalogue arrows;
  final AffixCatalogue affixes;

  /// The 20 bosses of docs/06-bosses.md. Kept in its own [BossCatalogue]
  /// rather than a plain list, the same shape [heroes]/[arrows]/[affixes]
  /// use, since a boss's own phase system needs to look one up by
  /// [BossArchetype] on the hot path (`BossPhaseSystem`) the way enemy AI
  /// resolves an [EnemyDefinition].
  final BossCatalogue bosses;

  /// The Spire's 24 nodes (docs/04 §4.2, ADR 0092) and the 9 named Marks
  /// (docs/04 §4.5, ADR 0095) — kept here for the identical reason
  /// [heroes]/[arrows]/[affixes] are: `GameScreen`'s own loadout resolution
  /// needs both to fold a real account's investment into a real run, not
  /// just the Spire/Marks hub screens that read them the way the Hero/Gear
  /// screens already read [heroes]/[arrows].
  final SpireCatalogue spire;
  final MarkCatalogue marks;

  /// Archetype ordinal to table index. The AI resolves a definition on every
  /// enemy on every tick, so this has to be an array read.
  final List<int> _byArchetype;

  static ContentLibrary empty() => ContentLibrary._(
        enemies: const <EnemyDefinition>[],
        enemyIndexById: const <String, int>{},
        enemyIndexByArchetype:
            List<int>.filled(EnemyArchetype.values.length, -1),
        heroes: HeroCatalogue.empty(),
        arrows: ArrowCatalogue.empty(),
        affixes: AffixCatalogue.empty(),
        bosses: BossCatalogue.empty(),
        spire: SpireCatalogue.empty(),
        marks: MarkCatalogue.empty(),
      );

  /// Parses and validates content.
  ///
  /// Returns errors rather than throwing, so the build-time validator can
  /// report *every* problem in one run instead of one per invocation.
  static (ContentLibrary?, List<ContentError>) parse({
    required String enemiesJson,
    String? arenasJson,
    String? heroesJson,
    String? arrowsJson,
    String? affixesJson,
    String? bossesJson,
    String? spireJson,
    String? marksJson,
  }) {
    final List<ContentError> errors = <ContentError>[];

    final List<EnemyDefinition> enemies = _parseEnemies(enemiesJson, errors);
    if (errors.isNotEmpty) return (null, errors);

    final List<ArenaDefinition> arenas = arenasJson == null
        ? <ArenaDefinition>[]
        : _parseArenas(arenasJson, errors);
    if (errors.isNotEmpty) return (null, errors);

    final HeroCatalogue heroes = heroesJson == null
        ? HeroCatalogue.empty()
        : _unwrap(HeroCatalogue.parse(heroesJson), errors, HeroCatalogue.empty());
    if (errors.isNotEmpty) return (null, errors);

    final ArrowCatalogue arrows = arrowsJson == null
        ? ArrowCatalogue.empty()
        : _unwrap(ArrowCatalogue.parse(arrowsJson), errors, ArrowCatalogue.empty());
    if (errors.isNotEmpty) return (null, errors);

    final AffixCatalogue affixes = affixesJson == null
        ? AffixCatalogue.empty()
        : _unwrap(AffixCatalogue.parse(affixesJson), errors, AffixCatalogue.empty());
    if (errors.isNotEmpty) return (null, errors);

    final BossCatalogue bosses = bossesJson == null
        ? BossCatalogue.empty()
        : _unwrap(BossCatalogue.parse(bossesJson), errors, BossCatalogue.empty());
    if (errors.isNotEmpty) return (null, errors);

    final SpireCatalogue spire = spireJson == null
        ? SpireCatalogue.empty()
        : _unwrap(SpireCatalogue.parse(spireJson), errors, SpireCatalogue.empty());
    if (errors.isNotEmpty) return (null, errors);

    final MarkCatalogue marks = marksJson == null
        ? MarkCatalogue.empty()
        : _unwrap(MarkCatalogue.parse(marksJson), errors, MarkCatalogue.empty());
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
        arenas: arenas,
        heroes: heroes,
        arrows: arrows,
        affixes: affixes,
        bosses: bosses,
        spire: spire,
        marks: marks,
      ),
      const <ContentError>[],
    );
  }

  /// Folds one sub-catalogue's own parse errors into the caller's [errors]
  /// list and hands back a usable value regardless — the caller checks
  /// `errors.isNotEmpty` right after and bails before this fallback would
  /// ever reach a returned [ContentLibrary].
  static T _unwrap<T>(
    (T?, List<ContentError>) result,
    List<ContentError> errors,
    T fallback,
  ) {
    errors.addAll(result.$2);
    return result.$1 ?? fallback;
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
      bad('contactCooldown',
          'must be > 0, or contact damage ticks every frame');
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

  // ── Arenas ────────────────────────────────────────────────────────────────

  static List<ArenaDefinition> _parseArenas(
    String source,
    List<ContentError> errors,
  ) {
    const String file = 'arenas.json';
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      errors.add(ContentError(file, '<root>', 'not valid JSON: $e'));
      return const <ArenaDefinition>[];
    }

    if (decoded is! Map<String, dynamic>) {
      errors.add(const ContentError(file, '<root>', 'expected an object'));
      return const <ArenaDefinition>[];
    }

    final Object? list = decoded['arenas'];
    if (list is! List) {
      errors.add(const ContentError(file, 'arenas', 'expected an array'));
      return const <ArenaDefinition>[];
    }

    final List<ArenaDefinition> out = <ArenaDefinition>[];
    final Set<String> seen = <String>{};

    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'arenas[$i]', 'expected an object'));
        continue;
      }
      try {
        final ArenaDefinition arena = ArenaDefinition.fromJson(raw);
        if (!seen.add(arena.id)) {
          errors.add(
            ContentError(file, 'arenas[$i].id', 'duplicate id "${arena.id}"'),
          );
          continue;
        }
        _validateArena(arena, i, errors);
        out.add(arena);
      } catch (e) {
        errors.add(ContentError(file, 'arenas[$i]', 'malformed: $e'));
      }
    }
    return out;
  }

  /// Geometry rules that are cheap to state and expensive to discover in play.
  ///
  /// A spawn point inside a wall produces an enemy that cannot move; one too
  /// close to the player start produces unavoidable damage, which docs/14 §14.4
  /// calls a hard rule. Both are authoring mistakes, and both are invisible
  /// until the room that draws them comes up — so they fail the build instead.
  static void _validateArena(
    ArenaDefinition a,
    int i,
    List<ContentError> errors,
  ) {
    const String file = 'arenas.json';
    void bad(String field, String message) =>
        errors.add(ContentError(file, 'arenas[$i].$field', message));

    if (a.id.isEmpty) bad('id', 'must not be empty');
    if (a.tags.isEmpty) bad('tags', 'an arena needs at least one tag');
    if (a.chapters.isEmpty) bad('chapters', 'an arena nobody can draw is dead');

    for (final int chapter in a.chapters) {
      if (chapter < 1 || chapter > 12) {
        bad('chapters', 'chapter $chapter is outside [1, 12]');
      }
    }

    if (!_insideArena(a.playerStartX, a.playerStartY)) {
      bad('playerStart', 'outside the 16x9 arena');
    }
    for (final ArenaRect wall in a.walls) {
      if (!wall.isValid) bad('walls', 'a wall must have positive extent');
      if (wall.overlapsCircle(
        a.playerStartX,
        a.playerStartY,
        SimConfig.playerRadius,
      )) {
        bad('playerStart', 'the player would start inside a wall');
      }
    }
    for (final ArenaRect c in a.cover) {
      if (!c.isValid) bad('cover', 'cover must have positive extent');
    }

    if (a.spawnPoints.isEmpty) {
      bad('spawnPoints', 'an arena with no spawn points can never populate');
      return;
    }

    // docs/14 §14.1: playerStart is always >= 4u from every spawn point. That
    // is stricter than the 3.5u runtime rule on purpose — authored geometry
    // should not sit on the boundary the simulation enforces.
    const double authoredMinimum = 4.0;
    for (final SpawnPoint point in a.spawnPoints) {
      if (!_insideArena(point.x, point.y)) {
        bad('spawnPoints', 'a spawn point is outside the arena');
        continue;
      }
      if (point.families.isEmpty) {
        bad('spawnPoints', 'a spawn point no family may use is dead data');
      }
      final double dx = point.x - a.playerStartX;
      final double dy = point.y - a.playerStartY;
      final double distance = _distance(dx, dy);
      if (distance < authoredMinimum) {
        bad(
          'spawnPoints',
          'a spawn point is ${distance.toStringAsFixed(2)}u from the player '
              'start; the authored minimum is ${authoredMinimum}u, which is '
              'deliberately stricter than the runtime rule',
        );
      }
      for (final ArenaRect wall in a.walls) {
        if (wall.overlapsCircle(point.x, point.y, 0.4)) {
          bad('spawnPoints', 'a spawn point sits inside a wall');
          break;
        }
      }
    }

    // Every family must have somewhere legal to stand, or a room that draws one
    // is unplaceable and the generator burns all eight attempts on it.
    for (final EnemyFamily family in EnemyFamily.values) {
      if (a.pointsFor(family).isEmpty) {
        bad('spawnPoints', 'no point accepts ${family.name}');
      }
    }
  }

  static bool _insideArena(double x, double y) =>
      x >= 0 &&
      y >= 0 &&
      x <= SimConfig.arenaWidth &&
      y <= SimConfig.arenaHeight;

  static double _distance(double dx, double dy) {
    final double sq = dx * dx + dy * dy;
    if (sq <= 0) return 0;
    double g = sq > 1 ? sq : 1.0;
    for (int i = 0; i < 24; i++) {
      g = 0.5 * (g + sq / g);
    }
    return g;
  }

  /// Arenas a chapter may draw from.
  List<ArenaDefinition> arenasForChapter(int chapter) => arenas
      .where((ArenaDefinition a) => a.allowsChapter(chapter))
      .toList(growable: false);

  ArenaDefinition? arenaById(String id) {
    for (final ArenaDefinition a in arenas) {
      if (a.id == id) return a;
    }
    return null;
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
