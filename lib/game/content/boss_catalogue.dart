import 'dart:convert';

import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';

/// The 20 bosses, parsed and indexed.
///
/// Lives beside [HeroCatalogue] in shape, for the same reason: this is
/// content, as much under test as the code that reads it, loaded once at
/// bootstrap through [ContentLibrary].
class BossCatalogue {
  BossCatalogue._(this.all, this._byArchetype);

  final List<BossDefinition> all;

  /// Archetype ordinal to table index, -1 if absent. `EnemyStore.bossIndex`
  /// stores exactly this — an index into [all] — not the archetype's own
  /// ordinal, so a boss's row in `bosses.json` can be reordered without
  /// silently changing what a stored index means.
  final List<int> _byArchetype;

  static BossCatalogue empty() => BossCatalogue._(
        const <BossDefinition>[],
        List<int>.filled(BossArchetype.values.length, -1),
      );

  bool get isEmpty => all.isEmpty;

  int get length => all.length;

  /// Index into [all], or -1 if this archetype has no entry. What
  /// `SimWorld.spawnBoss` stores on `EnemyStore.bossIndex`.
  int indexOfArchetype(BossArchetype a) => _byArchetype[a.index];

  BossDefinition? byArchetype(BossArchetype a) {
    final int i = _byArchetype[a.index];
    return i < 0 ? null : all[i];
  }

  /// docs/06 lists 20 bosses across all three tiers.
  static const int expectedCount = 20;

  static (BossCatalogue?, List<ContentError>) parse(String source) {
    const String file = 'bosses.json';
    final List<ContentError> errors = <ContentError>[];

    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      errors.add(ContentError(file, '<root>', 'not valid JSON: $e'));
      return (null, errors);
    }
    if (decoded is! Map<String, dynamic>) {
      errors.add(const ContentError(file, '<root>', 'expected an object'));
      return (null, errors);
    }

    final Object? list = decoded['bosses'];
    if (list is! List) {
      errors.add(const ContentError(file, 'bosses', 'expected an array'));
      return (null, errors);
    }

    final List<BossDefinition> out = <BossDefinition>[];
    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'bosses[$i]', 'expected an object'));
        continue;
      }
      final BossDefinition? def = _parseOne(raw, 'bosses[$i]', errors);
      if (def != null) out.add(def);
    }
    if (errors.isNotEmpty) return (null, errors);

    _validate(out, errors);
    if (errors.isNotEmpty) return (null, errors);

    final List<int> byArchetype =
        List<int>.filled(BossArchetype.values.length, -1);
    for (int i = 0; i < out.length; i++) {
      byArchetype[out[i].archetype.index] = i;
    }

    return (BossCatalogue._(out, byArchetype), const <ContentError>[]);
  }

  static BossDefinition? _parseOne(
    Map<String, dynamic> raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'bosses.json';
    void err(String field, String message) =>
        errors.add(ContentError(file, '$path.$field', message));

    final Object? id = raw['id'];
    final BossArchetype? archetype =
        id is String ? _enumByName(BossArchetype.values, id) : null;
    if (archetype == null) {
      err('id', 'unknown boss id "$id" — BossArchetype is a closed list on '
          'purpose; add the enum value first');
      return null;
    }

    final Object? name = raw['name'];
    if (name is! String || name.isEmpty) {
      err('name', 'expected a non-empty string');
      return null;
    }

    final BossTier? tier = _enumByName(BossTier.values, raw['tier']);
    if (tier == null) {
      err('tier', 'unknown tier "${raw['tier']}"');
      return null;
    }

    final Object? hpMultiplier = raw['hpMultiplier'];
    final Object? duration = raw['targetDurationSeconds'];
    if (hpMultiplier is! num || hpMultiplier <= 0) {
      err('hpMultiplier', 'expected a positive number');
      return null;
    }
    // Optional — see BossDefinition.targetDurationSeconds's own doc comment:
    // three Endless bosses have no stated per-boss figure in docs/06, only
    // the tier's aggregate range.
    if (duration != null && (duration is! num || duration <= 0)) {
      err('targetDurationSeconds', 'expected a positive number if present');
      return null;
    }

    final Object? rawThresholds = raw['phaseThresholds'];
    if (rawThresholds is! List || rawThresholds.isEmpty) {
      err('phaseThresholds', 'expected a non-empty array');
      return null;
    }
    final List<double> thresholds = <double>[];
    double previous = 1.0;
    bool thresholdsOk = true;
    for (int i = 0; i < rawThresholds.length; i++) {
      final Object? t = rawThresholds[i];
      if (t is! num || t <= 0 || t >= previous) {
        err('phaseThresholds[$i]',
            'must be a number in (0, $previous), strictly descending');
        thresholdsOk = false;
        continue;
      }
      thresholds.add(t.toDouble());
      previous = t.toDouble();
    }
    if (!thresholdsOk) return null;

    final Object? chapter = raw['chapter'];
    if (chapter != null && chapter is! int) {
      err('chapter', 'expected an integer');
      return null;
    }

    return BossDefinition(
      archetype: archetype,
      name: name,
      tier: tier,
      hpMultiplier: hpMultiplier.toDouble(),
      targetDurationSeconds: (duration as num?)?.toDouble(),
      phaseThresholds: List<double>.unmodifiable(thresholds),
      chapter: chapter as int?,
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final T v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static void _validate(
    List<BossDefinition> bosses,
    List<ContentError> errors,
  ) {
    const String file = 'bosses.json';

    if (bosses.length != expectedCount) {
      errors.add(ContentError(file, 'bosses',
          'docs/06 lists $expectedCount bosses, found ${bosses.length}'));
    }

    final Set<BossArchetype> seen = <BossArchetype>{};
    final Set<int> seenChapters = <int>{};
    for (final BossDefinition b in bosses) {
      final String path = 'boss ${b.id}';

      if (!seen.add(b.archetype)) {
        errors.add(ContentError(file, path, 'duplicate id "${b.id}"'));
      }

      if (b.tier == BossTier.campaign) {
        if (b.chapter == null) {
          errors.add(
              ContentError(file, path, 'campaign boss has no chapter'));
        } else if (!seenChapters.add(b.chapter!)) {
          errors.add(ContentError(
              file, path, 'duplicate campaign chapter ${b.chapter}'));
        }
      } else if (b.chapter != null) {
        errors.add(ContentError(
            file, path, '${b.tier.name} boss should not set chapter'));
      }
    }
  }
}
