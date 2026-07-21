import 'dart:convert';

import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/effects/arrow_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/sim/elements.dart';

/// The 12 arrows, parsed and indexed. Same shape as [HeroCatalogue] and
/// [BoonCatalogue], for the same reasons.
class ArrowCatalogue {
  ArrowCatalogue._(this.all, this._byId, this._byKey, this._byArchetype);

  final List<ArrowDefinition> all;
  final List<ArrowDefinition?> _byId;
  final Map<String, ArrowDefinition> _byKey;
  final List<ArrowDefinition?> _byArchetype;

  static ArrowCatalogue empty() => ArrowCatalogue._(
        const <ArrowDefinition>[],
        const <ArrowDefinition?>[],
        const <String, ArrowDefinition>{},
        List<ArrowDefinition?>.filled(ArrowArchetype.values.length, null),
      );

  bool get isEmpty => all.isEmpty;

  int get length => all.length;

  ArrowDefinition? byId(int id) =>
      id >= 0 && id < _byId.length ? _byId[id] : null;

  ArrowDefinition? byKey(String key) => _byKey[key];

  ArrowDefinition? byArchetype(ArrowArchetype a) => _byArchetype[a.index];

  /// docs/08 §8.3: twelve arrows.
  static const int expectedCount = 12;

  static (ArrowCatalogue?, List<ContentError>) parse(String source) {
    const String file = 'arrows.json';
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

    final Object? list = decoded['arrows'];
    if (list is! List) {
      errors.add(const ContentError(file, 'arrows', 'expected an array'));
      return (null, errors);
    }

    final List<ArrowDefinition> out = <ArrowDefinition>[];
    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'arrows[$i]', 'expected an object'));
        continue;
      }
      final ArrowDefinition? def = _parseOne(raw, 'arrows[$i]', errors);
      if (def != null) out.add(def);
    }
    if (errors.isNotEmpty) return (null, errors);

    _validate(out, errors);
    if (errors.isNotEmpty) return (null, errors);

    final int maxId =
        out.fold<int>(0, (int m, ArrowDefinition a) => a.id > m ? a.id : m);
    final List<ArrowDefinition?> byId =
        List<ArrowDefinition?>.filled(maxId + 1, null);
    final Map<String, ArrowDefinition> byKey = <String, ArrowDefinition>{};
    final List<ArrowDefinition?> byArchetype =
        List<ArrowDefinition?>.filled(ArrowArchetype.values.length, null);
    for (final ArrowDefinition a in out) {
      byId[a.id] = a;
      byKey[a.key] = a;
      byArchetype[a.archetype.index] = a;
    }

    return (
      ArrowCatalogue._(out, byId, byKey, byArchetype),
      const <ContentError>[],
    );
  }

  static ArrowDefinition? _parseOne(
    Map<String, dynamic> raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'arrows.json';
    void err(String field, String message) =>
        errors.add(ContentError(file, '$path.$field', message));

    final Object? id = raw['id'];
    if (id is! int) {
      err('id', 'expected an integer');
      return null;
    }

    final ArrowArchetype? archetype =
        _enumByName(ArrowArchetype.values, raw['archetype']);
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

    final ArrowContentTier? contentTier =
        _enumByName(ArrowContentTier.values, raw['contentTier']);
    if (contentTier == null) {
      err('contentTier', 'unknown tier "${raw['contentTier']}"');
      return null;
    }

    final Object? baseMult = raw['baseMult'];
    if (baseMult is! num || baseMult <= 0) {
      err('baseMult', 'expected a positive number');
      return null;
    }

    final ArrowCraftCost? craftCost =
        _parseCraftCost(raw['craftCost'], path, errors);
    if (craftCost == null) return null;

    SimElement? element;
    if (raw.containsKey('element')) {
      element = _enumByName(SimElement.values, raw['element']);
      if (element == null) {
        err('element', 'unknown element "${raw['element']}"');
        return null;
      }
    }

    final Object? elementPotency = raw['elementPotency'];
    if (elementPotency != null && elementPotency is! num) {
      err('elementPotency', 'expected a number');
      return null;
    }
    if (element == null && elementPotency != null) {
      err('elementPotency', 'set with no element to apply it to');
      return null;
    }

    ArrowBehaviour? behaviour;
    if (raw.containsKey('behaviour')) {
      behaviour = _enumByName(ArrowBehaviour.values, raw['behaviour']);
      if (behaviour == null) {
        err(
          'behaviour',
          'unknown behaviour "${raw['behaviour']}" — ArrowBehaviour is a '
              'closed list on purpose; add the enum value first',
        );
        return null;
      }
    }

    final List<StatModifier> modifiers =
        _modifiers(raw['modifiers'], file, path, errors);

    return ArrowDefinition(
      archetype: archetype,
      id: id,
      key: key,
      name: name,
      contentTier: contentTier,
      baseMult: baseMult.toDouble(),
      craftCost: craftCost,
      description: description,
      element: element,
      elementPotency: (elementPotency as num?)?.toDouble(),
      modifiers: List<StatModifier>.unmodifiable(modifiers),
      behaviour: behaviour,
      balanceNote:
          raw['balanceNote'] is String ? raw['balanceNote'] as String : '',
    );
  }

  static ArrowCraftCost? _parseCraftCost(
    Object? raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'arrows.json';
    if (raw is! Map<String, dynamic>) {
      errors.add(ContentError(file, '$path.craftCost', 'expected an object'));
      return null;
    }
    final Object? gold = raw['gold'];
    if (gold is! int || gold < 0) {
      errors.add(ContentError(
          file, '$path.craftCost.gold', 'expected a non-negative integer'));
      return null;
    }
    final Map<int, int> materials = <int, int>{};
    final Object? rawMaterials = raw['materialsByTier'];
    if (rawMaterials is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> e in rawMaterials.entries) {
        final int? tier = int.tryParse(e.key);
        if (tier == null || e.value is! int) {
          errors.add(ContentError(
            file,
            '$path.craftCost.materialsByTier',
            'keys must be tier numbers, values must be integers',
          ));
          return null;
        }
        materials[tier] = e.value as int;
      }
    }
    return ArrowCraftCost(gold: gold, materialsByTier: materials);
  }

  static List<StatModifier> _modifiers(
    Object? raw,
    String file,
    String path,
    List<ContentError> errors,
  ) {
    if (raw == null) return const <StatModifier>[];
    if (raw is! List) {
      errors.add(ContentError(file, '$path.modifiers', 'expected an array'));
      return const <StatModifier>[];
    }
    final List<StatModifier> out = <StatModifier>[];
    for (final Object? m in raw) {
      if (m is! Map<String, dynamic>) {
        errors.add(ContentError(file, '$path.modifiers', 'expected objects'));
        continue;
      }
      final StatChannel? channel = _enumByName(StatChannel.values, m['channel']);
      if (channel == null) {
        errors.add(ContentError(
            file, '$path.modifiers', 'unknown channel "${m['channel']}"'));
        continue;
      }
      final Object? value = m['value'];
      if (value is! num) {
        errors.add(
            ContentError(file, '$path.modifiers', 'value must be a number'));
        continue;
      }
      out.add(StatModifier(channel, value.toDouble()));
    }
    return out;
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final T v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static void _validate(
    List<ArrowDefinition> arrows,
    List<ContentError> errors,
  ) {
    const String file = 'arrows.json';

    if (arrows.length != expectedCount) {
      errors.add(ContentError(file, 'arrows',
          'docs/08 lists $expectedCount arrows, found ${arrows.length}'));
    }

    final Set<int> seenIds = <int>{};
    final Set<String> seenKeys = <String>{};
    final Set<ArrowArchetype> seenArchetypes = <ArrowArchetype>{};
    for (final ArrowDefinition a in arrows) {
      final String path = 'arrow ${a.id} (${a.key})';

      if (!seenIds.add(a.id)) {
        errors.add(ContentError(file, path, 'duplicate id'));
      }
      if (!seenKeys.add(a.key)) {
        errors.add(ContentError(file, path, 'duplicate key "${a.key}"'));
      }
      if (!seenArchetypes.add(a.archetype)) {
        errors.add(ContentError(
            file, path, 'duplicate archetype "${a.archetype.name}"'));
      }

      // docs/08 §8.5 rule 1: "No arrow may exceed x1.25 DPS over Ash Shaft".
      // Not a proof of that rule — the balance harness (Phase 12) actually
      // measures it — but a baseMult far outside any plausible range for a
      // starting-tier weapon is very likely a decimal-place typo, and this
      // catches it before the harness has to.
      if (a.baseMult < 0.5 || a.baseMult > 2.0) {
        errors.add(ContentError(
            file, path, 'baseMult ${a.baseMult} is outside a plausible range'));
      }
    }

    // Ash Shaft specifically must be the reference: docs/08 §8.3 "baseMult
    // 1.00 ... Exists so every other arrow can be described as a trade
    // against it."
    final ArrowDefinition? ashShaft = arrows
        .where((ArrowDefinition a) => a.archetype == ArrowArchetype.ashShaft)
        .firstOrNull;
    if (ashShaft != null && ashShaft.baseMult != 1.0) {
      errors.add(const ContentError(
          file, 'ashShaft', 'must be the 1.00 reference baseMult'));
    }
  }
}
