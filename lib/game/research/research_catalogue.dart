import 'dart:convert';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/research/research_definition.dart';

/// The 12 Research Lab items, parsed and indexed. Same shape as
/// [SpireCatalogue]/[ArrowCatalogue], for the same reasons.
class ResearchCatalogue {
  ResearchCatalogue._(this.all, this._byId, this._byKey, this._byArchetype);

  final List<ResearchDefinition> all;
  final List<ResearchDefinition?> _byId;
  final Map<String, ResearchDefinition> _byKey;
  final List<ResearchDefinition?> _byArchetype;

  static ResearchCatalogue empty() => ResearchCatalogue._(
        const <ResearchDefinition>[],
        const <ResearchDefinition?>[],
        const <String, ResearchDefinition>{},
        List<ResearchDefinition?>.filled(ResearchArchetype.values.length, null),
      );

  bool get isEmpty => all.isEmpty;

  int get length => all.length;

  ResearchDefinition? byId(int id) =>
      id >= 0 && id < _byId.length ? _byId[id] : null;

  ResearchDefinition? byKey(String key) => _byKey[key];

  ResearchDefinition? byArchetype(ResearchArchetype a) => _byArchetype[a.index];

  /// docs/04 §4.6: 7 systemic + 5 quality-of-life items.
  static const int expectedCount = 12;

  static (ResearchCatalogue?, List<ContentError>) parse(String source) {
    const String file = 'research.json';
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

    final Object? list = decoded['items'];
    if (list is! List) {
      errors.add(const ContentError(file, 'items', 'expected an array'));
      return (null, errors);
    }

    final List<ResearchDefinition> out = <ResearchDefinition>[];
    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'items[$i]', 'expected an object'));
        continue;
      }
      final ResearchDefinition? def = _parseOne(raw, 'items[$i]', errors);
      if (def != null) out.add(def);
    }
    if (errors.isNotEmpty) return (null, errors);

    _validate(out, errors);
    if (errors.isNotEmpty) return (null, errors);

    final int maxId = out.fold<int>(
        0, (int m, ResearchDefinition d) => d.id > m ? d.id : m);
    final List<ResearchDefinition?> byId =
        List<ResearchDefinition?>.filled(maxId + 1, null);
    final Map<String, ResearchDefinition> byKey = <String, ResearchDefinition>{};
    final List<ResearchDefinition?> byArchetype =
        List<ResearchDefinition?>.filled(ResearchArchetype.values.length, null);
    for (final ResearchDefinition d in out) {
      byId[d.id] = d;
      byKey[d.key] = d;
      byArchetype[d.archetype.index] = d;
    }

    return (
      ResearchCatalogue._(out, byId, byKey, byArchetype),
      const <ContentError>[],
    );
  }

  static ResearchDefinition? _parseOne(
    Map<String, dynamic> raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'research.json';
    void err(String field, String message) =>
        errors.add(ContentError(file, '$path.$field', message));

    final Object? id = raw['id'];
    if (id is! int) {
      err('id', 'expected an integer');
      return null;
    }

    final ResearchArchetype? archetype =
        _enumByName(ResearchArchetype.values, raw['archetype']);
    if (archetype == null) {
      err('archetype', 'unknown archetype "${raw['archetype']}"');
      return null;
    }

    final Object? key = raw['key'];
    final Object? name = raw['name'];
    final Object? description = raw['description'];
    if (key is! String || key.isEmpty) {
      err('key', 'expected a non-empty string');
      return null;
    }
    if (name is! String || name.isEmpty) {
      err('name', 'expected a non-empty string');
      return null;
    }
    if (description is! String || description.isEmpty) {
      err('description', 'expected a non-empty string');
      return null;
    }

    final ResearchBranch? branch =
        _enumByName(ResearchBranch.values, raw['branch']);
    if (branch == null) {
      err('branch', 'unknown branch "${raw['branch']}"');
      return null;
    }

    final Object? insightCost = raw['insightCost'];
    if (insightCost is! int || insightCost < 0) {
      err('insightCost', 'expected a non-negative integer');
      return null;
    }

    final bool implemented =
        raw.containsKey('implemented') ? raw['implemented'] == true : true;

    return ResearchDefinition(
      archetype: archetype,
      id: id,
      key: key,
      name: name,
      branch: branch,
      insightCost: insightCost,
      description: description,
      implemented: implemented,
      balanceNote:
          raw['balanceNote'] is String ? raw['balanceNote'] as String : '',
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
    List<ResearchDefinition> items,
    List<ContentError> errors,
  ) {
    const String file = 'research.json';

    if (items.length != expectedCount) {
      errors.add(ContentError(file, 'items',
          'docs/04 lists $expectedCount items, found ${items.length}'));
    }

    final Set<int> seenIds = <int>{};
    final Set<String> seenKeys = <String>{};
    final Set<ResearchArchetype> seenArchetypes = <ResearchArchetype>{};
    for (final ResearchDefinition d in items) {
      final String path = 'item ${d.id} (${d.key})';

      if (!seenIds.add(d.id)) {
        errors.add(ContentError(file, path, 'duplicate id'));
      }
      if (!seenKeys.add(d.key)) {
        errors.add(ContentError(file, path, 'duplicate key "${d.key}"'));
      }
      if (!seenArchetypes.add(d.archetype)) {
        errors.add(ContentError(
            file, path, 'duplicate archetype "${d.archetype.name}"'));
      }
      if (d.branch == ResearchBranch.tierGates) {
        errors.add(ContentError(file, path,
            'Branch A (tier gates) is not a discrete catalogue item'));
      }
    }
  }
}
