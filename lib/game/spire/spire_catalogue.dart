import 'dart:convert';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/spire/spire_definition.dart';

/// The 24 Spire nodes, parsed and indexed. Same shape as [ArrowCatalogue]/
/// [HeroCatalogue], for the same reasons.
class SpireCatalogue {
  SpireCatalogue._(this.all, this._byId, this._byKey, this._byArchetype);

  final List<SpireNodeDefinition> all;
  final List<SpireNodeDefinition?> _byId;
  final Map<String, SpireNodeDefinition> _byKey;
  final List<SpireNodeDefinition?> _byArchetype;

  static SpireCatalogue empty() => SpireCatalogue._(
        const <SpireNodeDefinition>[],
        const <SpireNodeDefinition?>[],
        const <String, SpireNodeDefinition>{},
        List<SpireNodeDefinition?>.filled(
            SpireNodeArchetype.values.length, null),
      );

  bool get isEmpty => all.isEmpty;

  int get length => all.length;

  SpireNodeDefinition? byId(int id) =>
      id >= 0 && id < _byId.length ? _byId[id] : null;

  SpireNodeDefinition? byKey(String key) => _byKey[key];

  SpireNodeDefinition? byArchetype(SpireNodeArchetype a) =>
      _byArchetype[a.index];

  /// docs/04 §4.2: 24 nodes.
  static const int expectedCount = 24;

  static (SpireCatalogue?, List<ContentError>) parse(String source) {
    const String file = 'spire.json';
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

    final Object? list = decoded['nodes'];
    if (list is! List) {
      errors.add(const ContentError(file, 'nodes', 'expected an array'));
      return (null, errors);
    }

    final List<SpireNodeDefinition> out = <SpireNodeDefinition>[];
    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'nodes[$i]', 'expected an object'));
        continue;
      }
      final SpireNodeDefinition? def = _parseOne(raw, 'nodes[$i]', errors);
      if (def != null) out.add(def);
    }
    if (errors.isNotEmpty) return (null, errors);

    _validate(out, errors);
    if (errors.isNotEmpty) return (null, errors);

    final int maxId = out.fold<int>(
        0, (int m, SpireNodeDefinition n) => n.id > m ? n.id : m);
    final List<SpireNodeDefinition?> byId =
        List<SpireNodeDefinition?>.filled(maxId + 1, null);
    final Map<String, SpireNodeDefinition> byKey =
        <String, SpireNodeDefinition>{};
    final List<SpireNodeDefinition?> byArchetype =
        List<SpireNodeDefinition?>.filled(
            SpireNodeArchetype.values.length, null);
    for (final SpireNodeDefinition n in out) {
      byId[n.id] = n;
      byKey[n.key] = n;
      byArchetype[n.archetype.index] = n;
    }

    return (
      SpireCatalogue._(out, byId, byKey, byArchetype),
      const <ContentError>[],
    );
  }

  static SpireNodeDefinition? _parseOne(
    Map<String, dynamic> raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'spire.json';
    void err(String field, String message) =>
        errors.add(ContentError(file, '$path.$field', message));

    final Object? id = raw['id'];
    if (id is! int) {
      err('id', 'expected an integer');
      return null;
    }

    final SpireNodeArchetype? archetype =
        _enumByName(SpireNodeArchetype.values, raw['archetype']);
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

    final SpireWing? wing = _enumByName(SpireWing.values, raw['wing']);
    if (wing == null) {
      err('wing', 'unknown wing "${raw['wing']}"');
      return null;
    }

    final Object? baseCost = raw['baseCost'];
    if (baseCost is! num || baseCost <= 0) {
      err('baseCost', 'expected a positive number');
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

    final Object? valuePerLevel = raw['valuePerLevel'];
    if (valuePerLevel != null && valuePerLevel is! num) {
      err('valuePerLevel', 'expected a number');
      return null;
    }

    final Object? stepEvery = raw['stepEvery'];
    if (stepEvery != null && (stepEvery is! int || stepEvery <= 0)) {
      err('stepEvery', 'expected a positive integer');
      return null;
    }

    final bool isAttackMultiplier = raw['isAttackMultiplier'] == true;
    final bool implemented =
        raw.containsKey('implemented') ? raw['implemented'] == true : true;

    if (isAttackMultiplier && channel != null) {
      err('channel', 'an attack-multiplier node composes into baseAttack '
          'directly and must not also declare a channel');
      return null;
    }

    return SpireNodeDefinition(
      archetype: archetype,
      id: id,
      key: key,
      name: name,
      wing: wing,
      description: description,
      baseCost: baseCost.toDouble(),
      channel: channel,
      valuePerLevel: (valuePerLevel as num?)?.toDouble() ?? 0,
      stepEvery: (stepEvery as int?) ?? 1,
      isAttackMultiplier: isAttackMultiplier,
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
    List<SpireNodeDefinition> nodes,
    List<ContentError> errors,
  ) {
    const String file = 'spire.json';

    if (nodes.length != expectedCount) {
      errors.add(ContentError(file, 'nodes',
          'docs/04 lists $expectedCount nodes, found ${nodes.length}'));
    }

    final Set<int> seenIds = <int>{};
    final Set<String> seenKeys = <String>{};
    final Set<SpireNodeArchetype> seenArchetypes = <SpireNodeArchetype>{};
    int attackMultiplierCount = 0;

    for (final SpireNodeDefinition n in nodes) {
      final String path = 'node ${n.id} (${n.key})';

      if (!seenIds.add(n.id)) {
        errors.add(ContentError(file, path, 'duplicate id'));
      }
      if (!seenKeys.add(n.key)) {
        errors.add(ContentError(file, path, 'duplicate key "${n.key}"'));
      }
      if (!seenArchetypes.add(n.archetype)) {
        errors.add(ContentError(
            file, path, 'duplicate archetype "${n.archetype.name}"'));
      }
      if (n.isAttackMultiplier) attackMultiplierCount++;

      if (n.implemented && !n.isAttackMultiplier && n.channel == null) {
        errors.add(ContentError(
            file, path, 'implemented with no channel and not an '
            'attack multiplier — nothing for contributionAt to compose'));
      }
    }

    // docs/04 §4.1: exactly one node names spireMight, the ATK formula's own
    // dedicated multiplicative term.
    if (attackMultiplierCount != 1) {
      errors.add(ContentError(file, 'nodes',
          'expected exactly 1 attack-multiplier node (Warden\'s Might), '
          'found $attackMultiplierCount'));
    }
  }
}
