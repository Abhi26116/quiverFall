import 'dart:convert';

import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// docs/09 §9.3. Three members and the set fires.
///
/// Members are counted **distinct**, never by copies: three Long Weaves is one
/// Weaver member, not three. Counting copies would let a single stacked Common
/// complete a set on its own, which turns "my build became a thing" into "I
/// took the same card three times".
class SynergySet {
  const SynergySet({
    required this.id,
    required this.name,
    required this.bonusText,
    this.members = const <int>[],
    this.category,
    this.modifiers = const <BoonModifier>[],
    this.behaviour,
    this.threshold = defaultThreshold,
  });

  /// docs/09 §9.3: "Collecting 3 Boons tagged to a set".
  static const int defaultThreshold = 3;

  final String id;
  final String name;

  /// The bonus, exactly as the flourish announces it.
  final String bonusText;

  /// Catalogue ids that count toward this set.
  final List<int> members;

  /// An alternative membership rule: any card of this category counts.
  /// *The Sacrifice* is "any 3 Cursed", which no id list can express without
  /// going stale the moment a Cursed card is added.
  final BoonCategory? category;

  final List<BoonModifier> modifiers;
  final BoonBehaviour? behaviour;

  final int threshold;

  bool countsMember(BoonDefinition def) =>
      category != null ? def.category == category : members.contains(def.id);

  @override
  String toString() => name;
}

/// docs/09 §9.4. A base card at max copies, plus a partner, becomes something
/// else.
///
/// Evolutions **replace** rather than add: the base card leaves the pool and
/// its modifiers stop applying, so a run cannot hold both halves of the trade.
class BoonEvolution {
  const BoonEvolution({
    required this.id,
    required this.name,
    required this.description,
    required this.replaces,
    required this.requirements,
    this.modifiers = const <BoonModifier>[],
    this.behaviour,
  });

  final String id;
  final String name;
  final String description;

  /// The catalogue id this evolution consumes.
  final int replaces;

  /// Every entry must be held at the stated number of copies.
  final List<EvolutionRequirement> requirements;

  final List<BoonModifier> modifiers;
  final BoonBehaviour? behaviour;

  @override
  String toString() => name;
}

class EvolutionRequirement {
  const EvolutionRequirement(this.id, this.copies);

  final int id;
  final int copies;
}

/// Sets and evolutions, parsed and validated against the Boon catalogue.
class SynergyCatalogue {
  const SynergyCatalogue._(this.sets, this.evolutions);

  final List<SynergySet> sets;
  final List<BoonEvolution> evolutions;

  static const SynergyCatalogue empty =
      SynergyCatalogue._(<SynergySet>[], <BoonEvolution>[]);

  /// docs/09 §9.3 lists ten sets and §9.4 lists six evolutions. Both are fixed
  /// counts; a missing one is content the player paid for and will never meet.
  static const int expectedSets = 10;
  static const int expectedEvolutions = 6;

  /// Parses `synergies.json`.
  ///
  /// [boons] is required rather than optional: every member id and every
  /// evolution requirement is checked against the real catalogue, because a
  /// typo'd id is a set that can never complete and nothing else would notice.
  static (SynergyCatalogue?, List<ContentError>) parse(
    String source, {
    required BoonCatalogue boons,
  }) {
    const String file = 'synergies.json';
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

    final List<SynergySet> sets =
        _parseSets(decoded['sets'], boons, errors);
    final List<BoonEvolution> evolutions =
        _parseEvolutions(decoded['evolutions'], boons, errors);
    if (errors.isNotEmpty) return (null, errors);

    _validate(sets, evolutions, boons, errors);
    if (errors.isNotEmpty) return (null, errors);

    return (SynergyCatalogue._(sets, evolutions), const <ContentError>[]);
  }

  static List<SynergySet> _parseSets(
    Object? raw,
    BoonCatalogue boons,
    List<ContentError> errors,
  ) {
    const String file = 'synergies.json';
    if (raw is! List) {
      errors.add(const ContentError(file, 'sets', 'expected an array'));
      return const <SynergySet>[];
    }

    final List<SynergySet> out = <SynergySet>[];
    for (int i = 0; i < raw.length; i++) {
      final Object? entry = raw[i];
      if (entry is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'sets[$i]', 'expected an object'));
        continue;
      }
      final String path = 'sets[$i]';

      final Object? id = entry['id'];
      final Object? name = entry['name'];
      final Object? bonusText = entry['bonusText'];
      if (id is! String || name is! String || bonusText is! String) {
        errors.add(ContentError(
            file, path, 'id, name and bonusText must all be strings'));
        continue;
      }

      final List<int> members = <int>[];
      final Object? rawMembers = entry['members'];
      if (rawMembers != null) {
        if (rawMembers is! List) {
          errors.add(ContentError(file, '$path.members', 'expected an array'));
          continue;
        }
        for (final Object? m in rawMembers) {
          if (m is! int) {
            errors.add(
                ContentError(file, '$path.members', 'expected integer ids'));
            continue;
          }
          if (boons.byId(m) == null) {
            errors.add(ContentError(file, '$path.members',
                'id $m is not in the Boon catalogue'));
            continue;
          }
          members.add(m);
        }
      }

      BoonCategory? category;
      final Object? rawCategory = entry['category'];
      if (rawCategory != null) {
        category = _byName(BoonCategory.values, rawCategory);
        if (category == null) {
          errors.add(ContentError(
              file, '$path.category', 'unknown category "$rawCategory"'));
          continue;
        }
      }

      if (members.isEmpty && category == null) {
        errors.add(ContentError(
            file, path, 'a set needs either members or a category rule'));
        continue;
      }

      final BoonBehaviour? behaviour =
          _behaviour(entry['behaviour'], file, path, errors);
      final List<BoonModifier> modifiers =
          _modifiers(entry['modifiers'], file, path, errors);

      if (behaviour == null && modifiers.isEmpty) {
        errors.add(ContentError(
            file, path, 'set "$id" grants nothing'));
        continue;
      }

      out.add(SynergySet(
        id: id,
        name: name,
        bonusText: bonusText,
        members: List<int>.unmodifiable(members),
        category: category,
        modifiers: List<BoonModifier>.unmodifiable(modifiers),
        behaviour: behaviour,
      ));
    }
    return out;
  }

  static List<BoonEvolution> _parseEvolutions(
    Object? raw,
    BoonCatalogue boons,
    List<ContentError> errors,
  ) {
    const String file = 'synergies.json';
    if (raw is! List) {
      errors.add(const ContentError(file, 'evolutions', 'expected an array'));
      return const <BoonEvolution>[];
    }

    final List<BoonEvolution> out = <BoonEvolution>[];
    for (int i = 0; i < raw.length; i++) {
      final Object? entry = raw[i];
      if (entry is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'evolutions[$i]', 'expected an object'));
        continue;
      }
      final String path = 'evolutions[$i]';

      final Object? id = entry['id'];
      final Object? name = entry['name'];
      final Object? description = entry['description'];
      final Object? replaces = entry['replaces'];
      if (id is! String || name is! String || description is! String) {
        errors.add(ContentError(
            file, path, 'id, name and description must all be strings'));
        continue;
      }
      if (replaces is! int || boons.byId(replaces) == null) {
        errors.add(ContentError(
            file, '$path.replaces', 'must be a Boon catalogue id'));
        continue;
      }

      final List<EvolutionRequirement> requirements =
          <EvolutionRequirement>[];
      final Object? rawReqs = entry['requires'];
      if (rawReqs is! List || rawReqs.isEmpty) {
        errors.add(ContentError(
            file, '$path.requires', 'expected a non-empty array'));
        continue;
      }
      for (final Object? r in rawReqs) {
        if (r is! Map<String, dynamic>) {
          errors.add(
              ContentError(file, '$path.requires', 'expected objects'));
          continue;
        }
        final Object? rid = r['id'];
        final Object? copies = r['copies'];
        if (rid is! int || copies is! int || copies < 1) {
          errors.add(ContentError(
              file, '$path.requires', 'each entry needs an id and copies >= 1'));
          continue;
        }
        final BoonDefinition? def = boons.byId(rid);
        if (def == null) {
          errors.add(ContentError(
              file, '$path.requires', 'id $rid is not in the catalogue'));
          continue;
        }
        // A requirement above the card's own ceiling can never be met, which
        // would make the evolution unreachable and completely silent about it.
        if (copies > def.maxCopies) {
          errors.add(ContentError(
            file,
            '$path.requires',
            '#$rid ${def.name} caps at ×${def.maxCopies} but $copies are '
                'required — this evolution can never trigger',
          ));
          continue;
        }
        requirements.add(EvolutionRequirement(rid, copies));
      }

      final BoonBehaviour? behaviour =
          _behaviour(entry['behaviour'], file, path, errors);
      final List<BoonModifier> modifiers =
          _modifiers(entry['modifiers'], file, path, errors);

      if (behaviour == null && modifiers.isEmpty) {
        errors
            .add(ContentError(file, path, 'evolution "$id" grants nothing'));
        continue;
      }

      out.add(BoonEvolution(
        id: id,
        name: name,
        description: description,
        replaces: replaces,
        requirements: List<EvolutionRequirement>.unmodifiable(requirements),
        modifiers: List<BoonModifier>.unmodifiable(modifiers),
        behaviour: behaviour,
      ));
    }
    return out;
  }

  static BoonBehaviour? _behaviour(
    Object? raw,
    String file,
    String path,
    List<ContentError> errors,
  ) {
    if (raw == null) return null;
    final BoonBehaviour? b = _byName(BoonBehaviour.values, raw);
    if (b == null) {
      errors.add(
          ContentError(file, '$path.behaviour', 'unknown behaviour "$raw"'));
    }
    return b;
  }

  static List<BoonModifier> _modifiers(
    Object? raw,
    String file,
    String path,
    List<ContentError> errors,
  ) {
    if (raw == null) return const <BoonModifier>[];
    if (raw is! List) {
      errors.add(ContentError(file, '$path.modifiers', 'expected an array'));
      return const <BoonModifier>[];
    }
    final List<BoonModifier> out = <BoonModifier>[];
    for (final Object? m in raw) {
      if (m is! Map<String, dynamic>) {
        errors.add(ContentError(file, '$path.modifiers', 'expected objects'));
        continue;
      }
      final StatChannel? channel = _byName(StatChannel.values, m['channel']);
      final Object? value = m['value'];
      if (channel == null) {
        errors.add(ContentError(
            file, '$path.modifiers', 'unknown channel "${m['channel']}"'));
        continue;
      }
      if (value is! num) {
        errors
            .add(ContentError(file, '$path.modifiers', 'value must be a number'));
        continue;
      }
      out.add(BoonModifier(channel, value.toDouble()));
    }
    return out;
  }

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final T v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static void _validate(
    List<SynergySet> sets,
    List<BoonEvolution> evolutions,
    BoonCatalogue boons,
    List<ContentError> errors,
  ) {
    const String file = 'synergies.json';

    if (sets.length != expectedSets) {
      errors.add(ContentError(file, 'sets',
          'docs/09 §9.3 lists $expectedSets sets, found ${sets.length}'));
    }
    if (evolutions.length != expectedEvolutions) {
      errors.add(ContentError(
          file,
          'evolutions',
          'docs/09 §9.4 lists $expectedEvolutions evolutions, found '
              '${evolutions.length}'));
    }

    final Set<String> ids = <String>{};
    for (final SynergySet s in sets) {
      if (!ids.add(s.id)) {
        errors.add(ContentError(file, 'sets', 'duplicate set id "${s.id}"'));
      }
      // A set that cannot reach its own threshold is unreachable content.
      final int reachable = s.category != null
          ? boons.all
              .where((BoonDefinition b) => b.category == s.category)
              .length
          : s.members.length;
      if (reachable < s.threshold) {
        errors.add(ContentError(
          file,
          'sets',
          '"${s.name}" needs ${s.threshold} members but only $reachable '
              'cards can count toward it',
        ));
      }
    }

    final Set<String> evoIds = <String>{};
    final Set<int> replaced = <int>{};
    for (final BoonEvolution e in evolutions) {
      if (!evoIds.add(e.id)) {
        errors.add(
            ContentError(file, 'evolutions', 'duplicate id "${e.id}"'));
      }
      // Two evolutions consuming the same base card would race, and which one
      // won would depend on parse order.
      if (!replaced.add(e.replaces)) {
        errors.add(ContentError(file, 'evolutions',
            'two evolutions both replace #${e.replaces}'));
      }
      // The base card must itself be one of the requirements, or "replaces"
      // names a card the player need not even hold.
      if (!e.requirements.any((EvolutionRequirement r) => r.id == e.replaces)) {
        errors.add(ContentError(
          file,
          'evolutions',
          '"${e.name}" replaces #${e.replaces} but does not require it',
        ));
      }
    }
  }
}
