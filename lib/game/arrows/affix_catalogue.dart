import 'dart:convert';

import 'package:quiverfall/game/arrows/affix_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/effects/affix_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// The 17 affixes, parsed and indexed. Same shape as [ArrowCatalogue] and
/// [HeroCatalogue], for the same reasons.
class AffixCatalogue {
  AffixCatalogue._(this.all, this._byKey, this._byArchetype);

  final List<AffixDefinition> all;
  final Map<String, AffixDefinition> _byKey;
  final List<AffixDefinition?> _byArchetype;

  static AffixCatalogue empty() => AffixCatalogue._(
        const <AffixDefinition>[],
        const <String, AffixDefinition>{},
        List<AffixDefinition?>.filled(AffixArchetype.values.length, null),
      );

  bool get isEmpty => all.isEmpty;

  int get length => all.length;

  AffixDefinition? byKey(String key) => _byKey[key];

  AffixDefinition? byArchetype(AffixArchetype a) => _byArchetype[a.index];

  /// docs/08 §8.4's own table — see ADR 0012 for why this is 17, not the
  /// doc's own stated 18.
  static const int expectedCount = 17;

  static (AffixCatalogue?, List<ContentError>) parse(String source) {
    const String file = 'affixes.json';
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

    final Object? list = decoded['affixes'];
    if (list is! List) {
      errors.add(const ContentError(file, 'affixes', 'expected an array'));
      return (null, errors);
    }

    final List<AffixDefinition> out = <AffixDefinition>[];
    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'affixes[$i]', 'expected an object'));
        continue;
      }
      final AffixDefinition? def = _parseOne(raw, 'affixes[$i]', errors);
      if (def != null) out.add(def);
    }
    if (errors.isNotEmpty) return (null, errors);

    _validate(out, errors);
    if (errors.isNotEmpty) return (null, errors);

    final Map<String, AffixDefinition> byKey = <String, AffixDefinition>{};
    final List<AffixDefinition?> byArchetype =
        List<AffixDefinition?>.filled(AffixArchetype.values.length, null);
    for (final AffixDefinition a in out) {
      byKey[a.key] = a;
      byArchetype[a.archetype.index] = a;
    }

    return (
      AffixCatalogue._(out, byKey, byArchetype),
      const <ContentError>[],
    );
  }

  static AffixDefinition? _parseOne(
    Map<String, dynamic> raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'affixes.json';
    void err(String field, String message) =>
        errors.add(ContentError(file, '$path.$field', message));

    final AffixArchetype? archetype =
        _enumByName(AffixArchetype.values, raw['archetype']);
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

    final AffixRarity? rarity =
        _enumByName(AffixRarity.values, raw['rarity']);
    if (rarity == null) {
      err('rarity', 'unknown rarity "${raw['rarity']}"');
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

    AffixBehaviour? behaviour;
    if (raw.containsKey('behaviour')) {
      behaviour = _enumByName(AffixBehaviour.values, raw['behaviour']);
      if (behaviour == null) {
        err(
          'behaviour',
          'unknown behaviour "${raw['behaviour']}" — AffixBehaviour is a '
              'closed list on purpose; add the enum value first',
        );
        return null;
      }
    }

    if ((channel == null) == (behaviour == null)) {
      err('channel', 'exactly one of channel or behaviour must be set');
      return null;
    }

    final Object? rawMin = raw['minValue'];
    final Object? rawMax = raw['maxValue'];
    if (rawMin is! num || rawMax is! num) {
      err('minValue', 'expected numeric minValue/maxValue');
      return null;
    }
    final double minValue = rawMin.toDouble();
    final double maxValue = rawMax.toDouble();
    if (maxValue < minValue) {
      err('maxValue', 'must be >= minValue');
      return null;
    }

    return AffixDefinition(
      archetype: archetype,
      key: key,
      name: name,
      rarity: rarity,
      description: description,
      channel: channel,
      minValue: minValue,
      maxValue: maxValue,
      behaviour: behaviour,
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
    List<AffixDefinition> affixes,
    List<ContentError> errors,
  ) {
    const String file = 'affixes.json';

    if (affixes.length != expectedCount) {
      errors.add(ContentError(file, 'affixes',
          'expected $expectedCount affixes (ADR 0012), found ${affixes.length}'));
    }

    final Set<String> seenKeys = <String>{};
    final Set<AffixArchetype> seenArchetypes = <AffixArchetype>{};
    for (final AffixDefinition a in affixes) {
      final String path = a.key;

      if (!seenKeys.add(a.key)) {
        errors.add(ContentError(file, path, 'duplicate key "${a.key}"'));
      }
      if (!seenArchetypes.add(a.archetype)) {
        errors.add(ContentError(
            file, path, 'duplicate archetype "${a.archetype.name}"'));
      }
    }

    // Every AffixBehaviour must be reachable from the catalogue — the
    // reverse of ArrowCatalogue's own check, and the same reasoning: a
    // behaviour with nothing pointing at it is dead code nobody would
    // notice.
    for (final AffixBehaviour b in AffixBehaviour.values) {
      final bool found = affixes.any((AffixDefinition a) => a.behaviour == b);
      if (!found) {
        errors.add(ContentError(
            file, '<root>', 'no affix declares behaviour "${b.name}"'));
      }
    }
  }
}
