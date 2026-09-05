import 'dart:convert';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/marks/mark_definition.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// The 9 named Marks, parsed and indexed. Same shape as
/// [SpireCatalogue]/[ResearchCatalogue], for the same reasons.
class MarkCatalogue {
  MarkCatalogue._(this.all, this._byId, this._byKey, this._byArchetype);

  final List<MarkDefinition> all;
  final List<MarkDefinition?> _byId;
  final Map<String, MarkDefinition> _byKey;
  final List<MarkDefinition?> _byArchetype;

  static MarkCatalogue empty() => MarkCatalogue._(
        const <MarkDefinition>[],
        const <MarkDefinition?>[],
        const <String, MarkDefinition>{},
        List<MarkDefinition?>.filled(MarkArchetype.values.length, null),
      );

  bool get isEmpty => all.isEmpty;

  int get length => all.length;

  MarkDefinition? byId(int id) => id >= 0 && id < _byId.length ? _byId[id] : null;

  MarkDefinition? byKey(String key) => _byKey[key];

  MarkDefinition? byArchetype(MarkArchetype a) => _byArchetype[a.index];

  /// docs/04 §4.5 names 9 of the roster's own 25 — see ADR 0095.
  static const int expectedCount = 9;

  static (MarkCatalogue?, List<ContentError>) parse(String source) {
    const String file = 'marks.json';
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

    final Object? list = decoded['marks'];
    if (list is! List) {
      errors.add(const ContentError(file, 'marks', 'expected an array'));
      return (null, errors);
    }

    final List<MarkDefinition> out = <MarkDefinition>[];
    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'marks[$i]', 'expected an object'));
        continue;
      }
      final MarkDefinition? def = _parseOne(raw, 'marks[$i]', errors);
      if (def != null) out.add(def);
    }
    if (errors.isNotEmpty) return (null, errors);

    _validate(out, errors);
    if (errors.isNotEmpty) return (null, errors);

    final int maxId =
        out.fold<int>(0, (int m, MarkDefinition d) => d.id > m ? d.id : m);
    final List<MarkDefinition?> byId =
        List<MarkDefinition?>.filled(maxId + 1, null);
    final Map<String, MarkDefinition> byKey = <String, MarkDefinition>{};
    final List<MarkDefinition?> byArchetype =
        List<MarkDefinition?>.filled(MarkArchetype.values.length, null);
    for (final MarkDefinition d in out) {
      byId[d.id] = d;
      byKey[d.key] = d;
      byArchetype[d.archetype.index] = d;
    }

    return (
      MarkCatalogue._(out, byId, byKey, byArchetype),
      const <ContentError>[],
    );
  }

  static MarkDefinition? _parseOne(
    Map<String, dynamic> raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'marks.json';
    void err(String field, String message) =>
        errors.add(ContentError(file, '$path.$field', message));

    final Object? id = raw['id'];
    if (id is! int) {
      err('id', 'expected an integer');
      return null;
    }

    final MarkArchetype? archetype =
        _enumByName(MarkArchetype.values, raw['archetype']);
    if (archetype == null) {
      err('archetype', 'unknown archetype "${raw['archetype']}"');
      return null;
    }

    final Object? key = raw['key'];
    final Object? name = raw['name'];
    final Object? earnedBy = raw['earnedBy'];
    final Object? description = raw['description'];
    if (key is! String || key.isEmpty) {
      err('key', 'expected a non-empty string');
      return null;
    }
    if (name is! String || name.isEmpty) {
      err('name', 'expected a non-empty string');
      return null;
    }
    if (earnedBy is! String || earnedBy.isEmpty) {
      err('earnedBy', 'expected a non-empty string');
      return null;
    }
    if (description is! String || description.isEmpty) {
      err('description', 'expected a non-empty string');
      return null;
    }

    StatChannel? channel;
    if (raw.containsKey('channel')) {
      channel = _enumByName(StatChannel.values, raw['channel']);
      if (channel == null) {
        err('channel', 'unknown channel "${raw['channel']}"');
        return null;
      }
    }
    StatChannel? secondaryChannel;
    if (raw.containsKey('secondaryChannel')) {
      secondaryChannel = _enumByName(StatChannel.values, raw['secondaryChannel']);
      if (secondaryChannel == null) {
        err('secondaryChannel',
            'unknown channel "${raw['secondaryChannel']}"');
        return null;
      }
    }

    final bool implemented =
        raw.containsKey('implemented') ? raw['implemented'] == true : true;

    if (implemented && channel == null) {
      err('channel', 'implemented with no channel — nothing for '
          'contribution() to compose');
      return null;
    }

    return MarkDefinition(
      archetype: archetype,
      id: id,
      key: key,
      name: name,
      earnedBy: earnedBy,
      description: description,
      channel: channel,
      value: (raw['value'] as num?)?.toDouble() ?? 0,
      secondaryChannel: secondaryChannel,
      secondaryValue: (raw['secondaryValue'] as num?)?.toDouble() ?? 0,
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

  static void _validate(List<MarkDefinition> marks, List<ContentError> errors) {
    const String file = 'marks.json';

    if (marks.length != expectedCount) {
      errors.add(ContentError(file, 'marks',
          'docs/04 names $expectedCount Marks, found ${marks.length}'));
    }

    final Set<int> seenIds = <int>{};
    final Set<String> seenKeys = <String>{};
    final Set<MarkArchetype> seenArchetypes = <MarkArchetype>{};
    for (final MarkDefinition d in marks) {
      final String path = 'mark ${d.id} (${d.key})';
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
    }
  }
}
