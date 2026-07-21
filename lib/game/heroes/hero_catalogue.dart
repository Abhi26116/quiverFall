import 'dart:convert';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// The 20 heroes, parsed and indexed.
///
/// Lives beside [BoonCatalogue] in shape rather than in package, for the same
/// reasons: this is content, the content is as much the thing under test as
/// the code that reads it, and the balance harness (Phase 12) loads it
/// independently of everything else.
class HeroCatalogue {
  HeroCatalogue._(this.all, this._byId, this._byKey, this._byArchetype);

  final List<HeroDefinition> all;
  final List<HeroDefinition?> _byId;
  final Map<String, HeroDefinition> _byKey;
  final List<HeroDefinition?> _byArchetype;

  static HeroCatalogue empty() => HeroCatalogue._(
        const <HeroDefinition>[],
        const <HeroDefinition?>[],
        const <String, HeroDefinition>{},
        List<HeroDefinition?>.filled(HeroArchetype.values.length, null),
      );

  bool get isEmpty => all.isEmpty;

  int get length => all.length;

  HeroDefinition? byId(int id) => id >= 0 && id < _byId.length ? _byId[id] : null;

  HeroDefinition? byKey(String key) => _byKey[key];

  HeroDefinition? byArchetype(HeroArchetype a) => _byArchetype[a.index];

  /// docs/20 Phase 10's own exit criterion: 20 heroes.
  static const int expectedCount = 20;

  static (HeroCatalogue?, List<ContentError>) parse(String source) {
    const String file = 'heroes.json';
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

    final Object? list = decoded['heroes'];
    if (list is! List) {
      errors.add(const ContentError(file, 'heroes', 'expected an array'));
      return (null, errors);
    }

    final List<HeroDefinition> out = <HeroDefinition>[];
    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'heroes[$i]', 'expected an object'));
        continue;
      }
      final HeroDefinition? def = _parseOne(raw, 'heroes[$i]', errors);
      if (def != null) out.add(def);
    }
    if (errors.isNotEmpty) return (null, errors);

    _validate(out, errors);
    if (errors.isNotEmpty) return (null, errors);

    final int maxId =
        out.fold<int>(0, (int m, HeroDefinition h) => h.id > m ? h.id : m);
    final List<HeroDefinition?> byId =
        List<HeroDefinition?>.filled(maxId + 1, null);
    final Map<String, HeroDefinition> byKey = <String, HeroDefinition>{};
    final List<HeroDefinition?> byArchetype =
        List<HeroDefinition?>.filled(HeroArchetype.values.length, null);
    for (final HeroDefinition h in out) {
      byId[h.id] = h;
      byKey[h.key] = h;
      byArchetype[h.archetype.index] = h;
    }

    return (
      HeroCatalogue._(out, byId, byKey, byArchetype),
      const <ContentError>[],
    );
  }

  static HeroDefinition? _parseOne(
    Map<String, dynamic> raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'heroes.json';
    void err(String field, String message) =>
        errors.add(ContentError(file, '$path.$field', message));

    final Object? id = raw['id'];
    if (id is! int) {
      err('id', 'expected an integer');
      return null;
    }

    final HeroArchetype? archetype =
        _enumByName(HeroArchetype.values, raw['archetype']);
    if (archetype == null) {
      err('archetype', 'unknown archetype "${raw['archetype']}"');
      return null;
    }

    final Object? key = raw['key'];
    final Object? name = raw['name'];
    final Object? epithet = raw['epithet'];
    if (key is! String || key.isEmpty) {
      err('key', 'expected a non-empty string');
      return null;
    }
    if (name is! String || name.isEmpty) {
      err('name', 'expected a non-empty string');
      return null;
    }
    if (epithet is! String || epithet.isEmpty) {
      err('epithet', 'expected a non-empty string');
      return null;
    }

    final HeroRarity? rarity = _enumByName(HeroRarity.values, raw['rarity']);
    if (rarity == null) {
      err('rarity', 'unknown rarity "${raw['rarity']}"');
      return null;
    }

    final Object? role = raw['role'];
    if (role is! String || role.isEmpty) {
      err('role', 'expected a non-empty string');
      return null;
    }

    final HeroStatBlock? stats = _parseStats(raw['stats'], path, errors);
    if (stats == null) return null;

    final HeroUnlock? unlock = _parseUnlock(raw['unlock'], path, errors);
    if (unlock == null) return null;

    final HeroAbility? passive =
        _parseAbility(raw['passive'], '$path.passive', errors);
    final HeroAbility? ultimate =
        _parseAbility(raw['ultimate'], '$path.ultimate', errors);
    if (passive == null || ultimate == null) return null;

    final Object? rawTalents = raw['talents'];
    if (rawTalents is! List) {
      err('talents', 'expected an array');
      return null;
    }
    final List<HeroTalentNode> talents = <HeroTalentNode>[];
    for (int i = 0; i < rawTalents.length; i++) {
      final HeroTalentNode? node =
          _parseTalentNode(rawTalents[i], '$path.talents[$i]', errors);
      if (node != null) talents.add(node);
    }
    if (talents.length != rawTalents.length) return null;

    return HeroDefinition(
      archetype: archetype,
      id: id,
      key: key,
      name: name,
      epithet: epithet,
      rarity: rarity,
      role: role,
      stats: stats,
      unlock: unlock,
      passive: passive,
      ultimate: ultimate,
      talents: List<HeroTalentNode>.unmodifiable(talents),
      strengths: raw['strengths'] is String ? raw['strengths'] as String : '',
      weaknesses:
          raw['weaknesses'] is String ? raw['weaknesses'] as String : '',
    );
  }

  static HeroStatBlock? _parseStats(
    Object? raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'heroes.json';
    if (raw is! Map<String, dynamic>) {
      errors.add(ContentError(file, '$path.stats', 'expected an object'));
      return null;
    }
    final Object? atk = raw['atk'];
    final Object? hp = raw['hp'];
    final Object? moveSpeed = raw['moveSpeed'];
    final Object? fireRate = raw['fireRate'];
    if (atk is! num || hp is! num || moveSpeed is! num || fireRate is! num) {
      errors.add(ContentError(
        file,
        '$path.stats',
        'atk, hp, moveSpeed and fireRate must all be numbers',
      ));
      return null;
    }
    return HeroStatBlock(
      atk: atk.toDouble(),
      hp: hp.toDouble(),
      moveSpeed: moveSpeed.toDouble(),
      fireRate: fireRate.toDouble(),
    );
  }

  static HeroUnlock? _parseUnlock(
    Object? raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'heroes.json';
    if (raw is! Map<String, dynamic>) {
      errors.add(ContentError(file, '$path.unlock', 'expected an object'));
      return null;
    }
    final HeroUnlockKind? kind =
        _enumByName(HeroUnlockKind.values, raw['kind']);
    if (kind == null) {
      errors.add(ContentError(
          file, '$path.unlock.kind', 'unknown kind "${raw['kind']}"'));
      return null;
    }

    final String? note = raw['note'] is String ? raw['note'] as String : null;

    if (kind == HeroUnlockKind.chapterClear) {
      final Object? chapter = raw['chapter'];
      if (chapter is! int) {
        errors.add(ContentError(
            file, '$path.unlock.chapter', 'expected an integer'));
        return null;
      }
      return HeroUnlock(kind: kind, chapter: chapter, note: note);
    }
    if (kind == HeroUnlockKind.shards) {
      final Object? shardCost = raw['shardCost'];
      if (shardCost is! int) {
        errors.add(ContentError(
            file, '$path.unlock.shardCost', 'expected an integer'));
        return null;
      }
      return HeroUnlock(
        kind: kind,
        shardCost: shardCost,
        source: raw['source'] is String ? raw['source'] as String : null,
        note: note,
      );
    }
    return HeroUnlock(
      kind: HeroUnlockKind.free,
      chapter: raw['chapter'] is int ? raw['chapter'] as int : null,
      note: note,
    );
  }

  static HeroAbility? _parseAbility(
    Object? raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'heroes.json';
    if (raw is! Map<String, dynamic>) {
      errors.add(ContentError(file, path, 'expected an object'));
      return null;
    }
    final Object? name = raw['name'];
    final Object? description = raw['description'];
    if (name is! String || name.isEmpty) {
      errors.add(ContentError(file, '$path.name', 'expected a non-empty string'));
      return null;
    }
    if (description is! String || description.isEmpty) {
      errors.add(ContentError(
          file, '$path.description', 'expected a non-empty string'));
      return null;
    }

    HeroBehaviour? behaviour;
    if (raw.containsKey('behaviour')) {
      behaviour = _enumByName(HeroBehaviour.values, raw['behaviour']);
      if (behaviour == null) {
        errors.add(ContentError(
          file,
          '$path.behaviour',
          'unknown behaviour "${raw['behaviour']}" — HeroBehaviour is a '
              'closed list on purpose; add the enum value first',
        ));
        return null;
      }
    }

    final List<StatModifier> modifiers =
        _modifiers(raw['modifiers'], file, path, errors);

    return HeroAbility(
      name: name,
      description: description,
      modifiers: List<StatModifier>.unmodifiable(modifiers),
      behaviour: behaviour,
    );
  }

  static HeroTalentNode? _parseTalentNode(
    Object? raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'heroes.json';
    if (raw is! Map<String, dynamic>) {
      errors.add(ContentError(file, path, 'expected an object'));
      return null;
    }
    final Object? starRequired = raw['starRequired'];
    if (starRequired is! int) {
      errors.add(
          ContentError(file, '$path.starRequired', 'expected an integer'));
      return null;
    }
    final Object? rawBranches = raw['branches'];
    if (rawBranches is! List) {
      errors.add(ContentError(file, '$path.branches', 'expected an array'));
      return null;
    }
    final List<HeroTalentBranch> branches = <HeroTalentBranch>[];
    for (int i = 0; i < rawBranches.length; i++) {
      final HeroTalentBranch? b =
          _parseBranch(rawBranches[i], '$path.branches[$i]', errors);
      if (b != null) branches.add(b);
    }
    if (branches.length != rawBranches.length) return null;

    return HeroTalentNode(
      starRequired: starRequired,
      branches: List<HeroTalentBranch>.unmodifiable(branches),
    );
  }

  static HeroTalentBranch? _parseBranch(
    Object? raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'heroes.json';
    if (raw is! Map<String, dynamic>) {
      errors.add(ContentError(file, path, 'expected an object'));
      return null;
    }
    final Object? key = raw['key'];
    final Object? name = raw['name'];
    final Object? description = raw['description'];
    if (key is! String || (key != 'a' && key != 'b')) {
      errors.add(ContentError(file, '$path.key', 'expected "a" or "b"'));
      return null;
    }
    if (name is! String || name.isEmpty) {
      errors.add(ContentError(file, '$path.name', 'expected a non-empty string'));
      return null;
    }
    if (description is! String || description.isEmpty) {
      errors.add(ContentError(
          file, '$path.description', 'expected a non-empty string'));
      return null;
    }

    HeroBehaviour? behaviour;
    if (raw.containsKey('behaviour')) {
      behaviour = _enumByName(HeroBehaviour.values, raw['behaviour']);
      if (behaviour == null) {
        errors.add(ContentError(
          file,
          '$path.behaviour',
          'unknown behaviour "${raw['behaviour']}"',
        ));
        return null;
      }
    }

    final List<StatModifier> modifiers =
        _modifiers(raw['modifiers'], file, path, errors);

    return HeroTalentBranch(
      key: key,
      name: name,
      description: description,
      modifiers: List<StatModifier>.unmodifiable(modifiers),
      behaviour: behaviour,
    );
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
        errors.add(
            ContentError(file, '$path.modifiers', 'expected objects'));
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
    List<HeroDefinition> heroes,
    List<ContentError> errors,
  ) {
    const String file = 'heroes.json';

    if (heroes.length != expectedCount) {
      errors.add(ContentError(file, 'heroes',
          'docs/07 lists $expectedCount heroes, found ${heroes.length}'));
    }

    final Set<int> seenIds = <int>{};
    final Set<String> seenKeys = <String>{};
    final Set<HeroArchetype> seenArchetypes = <HeroArchetype>{};
    for (final HeroDefinition h in heroes) {
      final String path = 'hero ${h.id} (${h.key})';

      if (!seenIds.add(h.id)) {
        errors.add(ContentError(file, path, 'duplicate id'));
      }
      if (!seenKeys.add(h.key)) {
        errors.add(ContentError(file, path, 'duplicate key "${h.key}"'));
      }
      if (!seenArchetypes.add(h.archetype)) {
        errors.add(
            ContentError(file, path, 'duplicate archetype "${h.archetype.name}"'));
      }

      // Every archetype must be authored, or the "id is the enemy's identity"
      // property this catalogue borrows from EnemyArchetype is broken — an
      // archetype with no data is one a switch statement can silently fall
      // through on.
      if (h.stats.atk <= 0 || h.stats.hp <= 0) {
        errors.add(ContentError(file, path, 'atk and hp must be positive'));
      }

      // docs/04 §4.3: exactly three talent nodes, at star 1 / 3 / 5, each with
      // exactly two branches keyed 'a' and 'b'.
      final List<int> expectedStars = <int>[1, 3, 5];
      if (h.talents.length != 3) {
        errors.add(
            ContentError(file, path, 'expected 3 talent nodes, found '
                '${h.talents.length}'));
      }
      final Set<int> seenStars = <int>{};
      for (final HeroTalentNode node in h.talents) {
        if (!seenStars.add(node.starRequired)) {
          errors.add(ContentError(
              file, path, 'duplicate talent node at ★${node.starRequired}'));
        }
        if (!expectedStars.contains(node.starRequired)) {
          errors.add(ContentError(file, path,
              'talent node at ★${node.starRequired}, expected 1, 3 or 5'));
        }
        if (node.branches.length != 2) {
          errors.add(ContentError(file, path,
              '★${node.starRequired} node has ${node.branches.length} '
                  'branches, expected 2'));
        }
        final Set<String> keys = <String>{};
        for (final HeroTalentBranch b in node.branches) {
          if (!keys.add(b.key)) {
            errors.add(ContentError(file, path,
                '★${node.starRequired} node has two branches keyed '
                    '"${b.key}"'));
          }
          if (b.modifiers.isEmpty && b.behaviour == null) {
            errors.add(ContentError(
                file, path, 'talent "${b.name}" does nothing'));
          }
        }
      }

      if (h.passive.modifiers.isEmpty && h.passive.behaviour == null) {
        errors.add(ContentError(file, path, 'passive does nothing'));
      }
      if (h.ultimate.behaviour == null) {
        // An ultimate with no coded effect is not a lesser ultimate, it is a
        // missing one — docs/07 §7.0 promises every hero a manually-triggered
        // Ultimate, and a stat-only "ultimate" would just be a passive with a
        // cooldown.
        errors.add(ContentError(file, path, 'ultimate has no behaviour'));
      }
    }
  }
}
