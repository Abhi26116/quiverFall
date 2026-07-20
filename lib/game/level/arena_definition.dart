import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/arena.dart';
import 'package:quiverfall/game/sim/sim_config.dart';

/// What kind of space an arena is.
///
/// The generator weights its arena pool by these, and later chapters favour
/// `enclosed` and `pillared` because less safe space is one of the levers
/// docs/14 §14.3 uses to raise difficulty *without* inflating HP.
enum ArenaTag {
  /// Wide, few obstructions. Kiting is easy; Salvo enemies are the threat.
  open,

  /// Walled in. Rush enemies are far harder to escape.
  enclosed,

  /// Long and narrow. Pierce is excellent, flanking is expensive.
  corridor,

  /// Scattered cover. The Longeye counter, and the best Confluence geometry.
  pillared,

  /// Ringed, central. Bosses and elites.
  arena,
}

/// Where an enemy may be placed, and what may be placed there.
///
/// docs/14 §14.4 sets the family placement rules, and they are the difference
/// between a room that reads and a room that ambushes: Salvo at the edges,
/// Rush at mid-distance so its approach is legible, Choir *behind* its pack so
/// the priority target is visually obvious, Riftborn centrally.
enum SpawnKind {
  /// Arena perimeter. Salvo and Rush arrive here.
  edge,

  /// Inside the playfield. Drift fodder and Choir support.
  interior,

  /// Reserved for Riftborn. Central, with room for an entrance.
  elite,
}

class SpawnPoint {
  const SpawnPoint({
    required this.x,
    required this.y,
    required this.kind,
    required this.families,
  });

  factory SpawnPoint.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['families'];
    return SpawnPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      kind: SpawnKind.values.byName(json['kind'] as String),
      families: raw is List
          ? raw
              .map((Object? f) => EnemyFamily.values.byName(f! as String))
              .toSet()
          : EnemyFamily.values.toSet(),
    );
  }

  final double x;
  final double y;
  final SpawnKind kind;

  /// Which families may use this point. An empty whitelist would mean a spawn
  /// nothing can use, which the validator rejects rather than silently skips.
  final Set<EnemyFamily> families;

  bool accepts(EnemyFamily family) => families.contains(family);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'x': x,
        'y': y,
        'kind': kind.name,
        'families': families.map((EnemyFamily f) => f.name).toList()..sort(),
      };
}

/// A wall pair a designer has marked as good Confluence geometry.
///
/// **The most important authored data in the game** (docs/14 §14.1). It is how
/// a level designer says "this room rewards Windline play", and from chapter 5
/// the generator biases arena selection toward rooms that have them — which is
/// the point in the campaign where a player is ready to learn the lattice.
///
/// ADR 0002 changed what this is *for*. It was written as the rescue plan for a
/// mechanic that could not fire at all; now that Confluence is reachable from
/// the base kit, a lattice hint is an amplifier rather than a lifeline.
class LatticeHint {
  const LatticeHint({
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
  });

  factory LatticeHint.fromJson(Map<String, dynamic> json) => LatticeHint(
        ax: (json['ax'] as num).toDouble(),
        ay: (json['ay'] as num).toDouble(),
        bx: (json['bx'] as num).toDouble(),
        by: (json['by'] as num).toDouble(),
      );

  final double ax;
  final double ay;
  final double bx;
  final double by;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'ax': ax, 'ay': ay, 'bx': bx, 'by': by};
}

/// One authored arena.
///
/// Every arena is a **16 x 9 unit single screen** — no scrolling, no camera
/// hunting, the whole fight visible at once (docs/14 §14.1). That constraint is
/// what makes the game readable on a phone and what lets the same room be a
/// fair fight on every screen size.
class ArenaDefinition {
  const ArenaDefinition({
    required this.id,
    required this.tags,
    required this.chapters,
    required this.playerStartX,
    required this.playerStartY,
    this.walls = const <ArenaRect>[],
    this.cover = const <ArenaRect>[],
    this.spawnPoints = const <SpawnPoint>[],
    this.latticeHints = const <LatticeHint>[],
  });

  factory ArenaDefinition.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) {
      final Object? raw = json[key];
      if (raw is! List) return <T>[];
      return raw
          .map((Object? e) => build(e! as Map<String, dynamic>))
          .toList(growable: false);
    }

    final Map<String, dynamic> start =
        json['playerStart'] as Map<String, dynamic>;

    return ArenaDefinition(
      id: json['id'] as String,
      tags: (json['tags'] as List<dynamic>)
          .map((Object? t) => ArenaTag.values.byName(t! as String))
          .toSet(),
      chapters: (json['chapters'] as List<dynamic>)
          .map((Object? c) => (c! as num).toInt())
          .toSet(),
      playerStartX: (start['x'] as num).toDouble(),
      playerStartY: (start['y'] as num).toDouble(),
      walls: parse('walls', ArenaRect.fromJson),
      cover: parse('cover', ArenaRect.fromJson),
      spawnPoints: parse('spawnPoints', SpawnPoint.fromJson),
      latticeHints: parse('latticeHints', LatticeHint.fromJson),
    );
  }

  final String id;
  final Set<ArenaTag> tags;

  /// Chapters this arena may appear in. Cross-chapter reuse is deliberate:
  /// docs/14 §14.1 reskins a chapter-9 arena under different lighting and it
  /// reads as new for a fraction of the cost.
  final Set<int> chapters;

  final double playerStartX;
  final double playerStartY;

  /// Blocks movement and projectiles.
  final List<ArenaRect> walls;

  /// Blocks projectiles but not movement — the Longeye counter, and the reason
  /// "break line of sight" is a real tactic rather than advice.
  final List<ArenaRect> cover;

  final List<SpawnPoint> spawnPoints;
  final List<LatticeHint> latticeHints;

  bool get hasLatticeHints => latticeHints.isNotEmpty;

  bool allowsChapter(int chapter) => chapters.contains(chapter);

  /// Spawn points a family may use.
  List<SpawnPoint> pointsFor(EnemyFamily family) => spawnPoints
      .where((SpawnPoint p) => p.accepts(family))
      .toList(growable: false);

  /// Builds the simulation's collision geometry.
  ///
  /// [ArenaDefinition] is authored data and [Arena] is a packed, allocation-free
  /// runtime structure. Keeping them separate means the loader can validate
  /// freely without the simulation ever carrying a validation concern.
  Arena toSimArena() => Arena(
        width: SimConfig.arenaWidth,
        height: SimConfig.arenaHeight,
        walls: walls.map((ArenaRect r) => r.toRect()).toList(growable: false),
        cover: cover.map((ArenaRect r) => r.toRect()).toList(growable: false),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'tags': (tags.map((ArenaTag t) => t.name).toList()..sort()),
        'chapters': (chapters.toList()..sort()),
        'playerStart': <String, double>{
          'x': playerStartX,
          'y': playerStartY,
        },
        if (walls.isNotEmpty)
          'walls': walls.map((ArenaRect r) => r.toJson()).toList(),
        if (cover.isNotEmpty)
          'cover': cover.map((ArenaRect r) => r.toJson()).toList(),
        'spawnPoints': spawnPoints.map((SpawnPoint p) => p.toJson()).toList(),
        if (latticeHints.isNotEmpty)
          'latticeHints':
              latticeHints.map((LatticeHint h) => h.toJson()).toList(),
      };
}

/// An axis-aligned rectangle, as authored.
///
/// Separate from the simulation's [Rect] so the loader can validate a shape
/// before the sim ever sees it — and because authored data is left/top/right/
/// bottom while the sim wants a packed float array.
class ArenaRect {
  const ArenaRect(this.left, this.top, this.right, this.bottom);

  factory ArenaRect.fromJson(Map<String, dynamic> json) => ArenaRect(
        (json['l'] as num).toDouble(),
        (json['t'] as num).toDouble(),
        (json['r'] as num).toDouble(),
        (json['b'] as num).toDouble(),
      );

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;

  double get height => bottom - top;

  double get area => width * height;

  bool get isValid => right > left && bottom > top;

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  /// True if a circle at this point would overlap the rectangle.
  bool overlapsCircle(double x, double y, double radius) {
    final double cx = x < left ? left : (x > right ? right : x);
    final double cy = y < top ? top : (y > bottom ? bottom : y);
    final double dx = x - cx;
    final double dy = y - cy;
    return dx * dx + dy * dy < radius * radius;
  }

  Rect toRect() => Rect(left, top, right, bottom);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'l': left,
        't': top,
        'r': right,
        'b': bottom,
      };
}
