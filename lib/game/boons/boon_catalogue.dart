import 'dart:convert';

import 'package:quiverfall/game/boons/boon_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/effects/boon_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// The 112 Boons, parsed and indexed.
///
/// Lives beside [ContentLibrary] rather than inside it because the catalogue is
/// large enough to deserve its own validation, and because the balance harness
/// loads Boons without needing enemies or arenas.
///
/// Definitions are indexed by *id* (1–112, matching docs/09 §9.2's numbering)
/// into a dense array with a leading hole at 0. Synergy sets and evolution
/// paths are authored against those numbers, so id is the stable identity and
/// the array read is what keeps draw and loadout composition off the map.
class BoonCatalogue {
  BoonCatalogue._(this.all, this._byId, this._byKey);

  /// Every Boon in authored order.
  final List<BoonDefinition> all;

  /// `_byId[id]` for id in 1..112. Index 0 is null.
  final List<BoonDefinition?> _byId;

  final Map<String, BoonDefinition> _byKey;

  static BoonCatalogue empty() => BoonCatalogue._(
        const <BoonDefinition>[],
        const <BoonDefinition?>[],
        const <String, BoonDefinition>{},
      );

  bool get isEmpty => all.isEmpty;

  int get length => all.length;

  /// The Boon with this catalogue number, or null.
  BoonDefinition? byId(int id) =>
      id >= 0 && id < _byId.length ? _byId[id] : null;

  BoonDefinition? byKey(String key) => _byKey[key];

  /// Every Boon of a rarity, in authored order. Built once at load rather than
  /// filtered per draw — a draw happens after every room clear and must not
  /// allocate a list each time.
  List<BoonDefinition> ofRarity(BoonRarity rarity) => _byRarity[rarity.index];

  late final List<List<BoonDefinition>> _byRarity = <List<BoonDefinition>>[
    for (final BoonRarity r in BoonRarity.values)
      List<BoonDefinition>.unmodifiable(
        all.where((BoonDefinition b) => b.rarity == r),
      ),
  ];

  /// The safe fallback pool for docs/09 §9.1's usability rule: unconditional
  /// Commons that are never a blank for anybody.
  late final List<BoonDefinition> safeFallbacks =
      List<BoonDefinition>.unmodifiable(
    all.where((BoonDefinition b) => b.isUniversallyUseful),
  );

  /// Parses `boons.json`.
  ///
  /// Returns errors rather than throwing, so the build-time validator reports
  /// every problem in one run.
  static (BoonCatalogue?, List<ContentError>) parse(String source) {
    const String file = 'boons.json';
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

    final Object? list = decoded['boons'];
    if (list is! List) {
      errors.add(const ContentError(file, 'boons', 'expected an array'));
      return (null, errors);
    }

    final List<BoonDefinition> out = <BoonDefinition>[];
    for (int i = 0; i < list.length; i++) {
      final Object? raw = list[i];
      if (raw is! Map<String, dynamic>) {
        errors.add(ContentError(file, 'boons[$i]', 'expected an object'));
        continue;
      }
      final BoonDefinition? def = _parseOne(raw, 'boons[$i]', errors);
      if (def != null) out.add(def);
    }
    if (errors.isNotEmpty) return (null, errors);

    _validate(out, errors);
    if (errors.isNotEmpty) return (null, errors);

    final int maxId =
        out.fold<int>(0, (int m, BoonDefinition b) => b.id > m ? b.id : m);
    final List<BoonDefinition?> byId =
        List<BoonDefinition?>.filled(maxId + 1, null);
    final Map<String, BoonDefinition> byKey = <String, BoonDefinition>{};
    for (final BoonDefinition b in out) {
      byId[b.id] = b;
      byKey[b.key] = b;
    }

    return (BoonCatalogue._(out, byId, byKey), const <ContentError>[]);
  }

  static BoonDefinition? _parseOne(
    Map<String, dynamic> raw,
    String path,
    List<ContentError> errors,
  ) {
    const String file = 'boons.json';

    void err(String field, String message) =>
        errors.add(ContentError(file, '$path.$field', message));

    final Object? id = raw['id'];
    if (id is! int) {
      err('id', 'expected an integer');
      return null;
    }

    final Object? key = raw['key'];
    if (key is! String || key.isEmpty) {
      err('key', 'expected a non-empty string');
      return null;
    }

    final Object? name = raw['name'];
    if (name is! String || name.isEmpty) {
      err('name', 'expected a non-empty string');
      return null;
    }

    final Object? description = raw['description'];
    if (description is! String || description.isEmpty) {
      err('description', 'expected a non-empty string — this is card text the '
          'player reads, not an internal label');
      return null;
    }

    final BoonCategory? category =
        _enumByName(BoonCategory.values, raw['category']);
    if (category == null) {
      err('category', 'unknown category "${raw['category']}"');
      return null;
    }

    final BoonRarity? rarity = _enumByName(BoonRarity.values, raw['rarity']);
    if (rarity == null) {
      err('rarity', 'unknown rarity "${raw['rarity']}"');
      return null;
    }

    final Object? maxCopies = raw['maxCopies'];
    if (maxCopies is! int || maxCopies < 1) {
      err('maxCopies', 'expected a positive integer');
      return null;
    }

    BoonBehaviour? behaviour;
    if (raw.containsKey('behaviour')) {
      behaviour = _enumByName(BoonBehaviour.values, raw['behaviour']);
      if (behaviour == null) {
        err(
          'behaviour',
          'unknown behaviour "${raw['behaviour']}" — BoonBehaviour is a closed '
              'list on purpose; add the enum value first',
        );
        return null;
      }
    }

    final List<BoonModifier> modifiers = <BoonModifier>[];
    final Object? rawMods = raw['modifiers'];
    if (rawMods != null) {
      if (rawMods is! List) {
        err('modifiers', 'expected an array');
        return null;
      }
      for (int i = 0; i < rawMods.length; i++) {
        final Object? m = rawMods[i];
        if (m is! Map<String, dynamic>) {
          err('modifiers[$i]', 'expected an object');
          continue;
        }
        final StatChannel? channel =
            _enumByName(StatChannel.values, m['channel']);
        if (channel == null) {
          err('modifiers[$i].channel', 'unknown channel "${m['channel']}"');
          continue;
        }
        final Object? value = m['value'];
        if (value is! num) {
          err('modifiers[$i].value', 'expected a number');
          continue;
        }
        modifiers.add(BoonModifier(channel, value.toDouble()));
      }
    }

    final List<BuildTag>? requires = _tags(raw['requires'], 'requires', err);
    final List<BuildTag>? excludes = _tags(raw['excludes'], 'excludes', err);
    final List<BuildTag>? grants = _tags(raw['grants'], 'grants', err);
    if (requires == null || excludes == null || grants == null) return null;

    final Object? stacksByCopies = raw['stacksByCopies'] ?? false;
    if (stacksByCopies is! bool) {
      err('stacksByCopies', 'expected a boolean');
      return null;
    }

    final Object? downside = raw['downside'];
    if (downside != null && downside is! String) {
      err('downside', 'expected a string');
      return null;
    }

    return BoonDefinition(
      id: id,
      key: key,
      name: name,
      category: category,
      rarity: rarity,
      maxCopies: maxCopies,
      description: description,
      modifiers: List<BoonModifier>.unmodifiable(modifiers),
      behaviour: behaviour,
      requires: List<BuildTag>.unmodifiable(requires),
      excludes: List<BuildTag>.unmodifiable(excludes),
      grants: List<BuildTag>.unmodifiable(grants),
      downside: downside as String?,
      stacksByCopies: stacksByCopies,
    );
  }

  static List<BuildTag>? _tags(
    Object? raw,
    String field,
    void Function(String, String) err,
  ) {
    if (raw == null) return const <BuildTag>[];
    if (raw is! List) {
      err(field, 'expected an array');
      return null;
    }
    final List<BuildTag> out = <BuildTag>[];
    for (final Object? entry in raw) {
      final BuildTag? tag = _enumByName(BuildTag.values, entry);
      if (tag == null) {
        err(field, 'unknown build tag "$entry"');
        return null;
      }
      out.add(tag);
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

  /// Catalogue-wide invariants.
  ///
  /// These are the rules that no single card can violate on its own, so they
  /// cannot live in [_parseOne]. Every one of them has been a real bug in some
  /// shipped game.
  static void _validate(
    List<BoonDefinition> boons,
    List<ContentError> errors,
  ) {
    const String file = 'boons.json';

    // ── Identity ────────────────────────────────────────────────────────────
    final Set<int> seenIds = <int>{};
    final Set<String> seenKeys = <String>{};
    final Set<String> seenNames = <String>{};
    for (final BoonDefinition b in boons) {
      if (!seenIds.add(b.id)) {
        errors.add(ContentError(file, 'boon ${b.id}', 'duplicate id'));
      }
      if (!seenKeys.add(b.key)) {
        errors.add(ContentError(file, 'boon ${b.id}', 'duplicate key "${b.key}"'));
      }
      if (!seenNames.add(b.name)) {
        // Two cards with the same name is a UI bug that only shows up when both
        // are offered in the same set, which is rare enough to ship.
        errors.add(
          ContentError(file, 'boon ${b.id}', 'duplicate name "${b.name}"'),
        );
      }
    }

    // The catalogue is a fixed set, and docs/09 opens by promising 112 of them.
    // A missing card means a synergy set or evolution path silently references
    // nothing.
    if (boons.length != expectedCount) {
      errors.add(
        ContentError(
          file,
          '<root>',
          'expected $expectedCount Boons, found ${boons.length}',
        ),
      );
    }
    for (int id = 1; id <= expectedCount; id++) {
      if (!seenIds.contains(id)) {
        errors.add(ContentError(file, 'boon $id', 'missing from the catalogue'));
      }
    }

    for (final BoonDefinition b in boons) {
      final String path = 'boon ${b.id} (${b.key})';

      // ── A card must actually do something ────────────────────────────────
      if (b.modifiers.isEmpty && b.behaviour == null) {
        errors.add(
          ContentError(file, path, 'has neither modifiers nor a behaviour'),
        );
      }

      // ── Cursed cards state their cost, and only Cursed cards do ──────────
      // docs/09 §9.2 G. A Cursed Boon that surprises the player is a broken
      // promise, and a non-Cursed card with a downside line renders a crimson
      // border it has not earned.
      if (b.category == BoonCategory.cursed && (b.downside?.isEmpty ?? true)) {
        errors.add(
          ContentError(file, path, 'Cursed Boons must state their downside'),
        );
      }
      if (b.category != BoonCategory.cursed && b.downside != null) {
        errors.add(
          ContentError(
            file,
            path,
            'only Cursed Boons carry a downside line',
          ),
        );
      }

      // ── Requirements must be satisfiable ─────────────────────────────────
      for (final BuildTag tag in b.requires) {
        if (b.excludes.contains(tag)) {
          errors.add(
            ContentError(
              file,
              path,
              'requires and excludes the same tag "${tag.name}" — can never '
                  'be offered',
            ),
          );
        }
      }

      // ── Copies must make sense ───────────────────────────────────────────
      // A behaviour is on or off; taking it twice does nothing, so offering a
      // second copy wastes a card slot in a draw.
      if (b.maxCopies > 1 &&
          b.behaviour != null &&
          b.modifiers.isEmpty &&
          !b.stacksByCopies) {
        errors.add(
          ContentError(
            file,
            path,
            'a pure-behaviour Boon cannot stack (maxCopies ${b.maxCopies}); '
                'set stacksByCopies if the behaviour reads its own copy count',
          ),
        );
      }
      if (b.stacksByCopies && b.behaviour == null) {
        errors.add(
          ContentError(file, path, 'stacksByCopies with no behaviour to stack'),
        );
      }

      // Legendary and Mythic are once-per-run by design (docs/09 §9.2 marks
      // every one ×1); a stacking Legendary would blow the power budget.
      if (b.rarity.index >= BoonRarity.legendary.index && b.maxCopies != 1) {
        errors.add(
          ContentError(
            file,
            path,
            '${b.rarity.name} Boons must be ×1',
          ),
        );
      }

      // ── Integral channels must carry whole numbers ───────────────────────
      for (final BoonModifier m in b.modifiers) {
        if (m.channel.isIntegral && m.value != m.value.roundToDouble()) {
          errors.add(
            ContentError(
              file,
              path,
              '${m.channel.name} is a count but the value is ${m.value}',
            ),
          );
        }
        // Multiplicative channels rest at 1.0. A 0 here would zero the stat
        // outright, and a 0.4 meant as "+40 %" would silently cut it by 60 %.
        if (m.channel.isMultiplicative && m.value <= 0) {
          errors.add(
            ContentError(
              file,
              path,
              '${m.channel.name} is multiplicative and must be > 0, got '
                  '${m.value}',
            ),
          );
        }
      }
    }

    // ── The pool must never be unable to fill a set ─────────────────────────
    // docs/09 §9.1's usability rule falls back to a "safe" Common. If none
    // exists the draw has no escape hatch and a build with no element could be
    // offered three blanks.
    final int safe =
        boons.where((BoonDefinition b) => b.isUniversallyUseful).length;
    if (safe < minSafeFallbacks) {
      errors.add(
        ContentError(
          file,
          '<root>',
          'only $safe universally-useful Commons; the draw needs at least '
              '$minSafeFallbacks to fill a set for any build',
        ),
      );
    }
  }

  /// docs/09's opening line: 112 in-run Boons.
  static const int expectedCount = 112;

  /// Enough unconditional Commons to fill the largest possible card set
  /// (5, with *Curator*) without repeating.
  static const int minSafeFallbacks = 5;
}
