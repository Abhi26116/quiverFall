import 'dart:typed_data';

import 'package:quiverfall/game/sim/sim_config.dart';

/// A safe handle to an entity.
///
/// Packs a slot index with a generation counter. When a slot is recycled its
/// generation increments, so a handle held across the death of its entity
/// resolves as stale rather than silently addressing whatever now occupies the
/// slot. That class of bug — a projectile homing onto a corpse's replacement —
/// is nearly impossible to debug from a report, so it is designed out.
///
/// An extension type, so this is a plain `int` at runtime with no allocation.
extension type const EntityId(int raw) {
  static const EntityId none = EntityId(-1);

  static const int _indexBits = 20;
  static const int _indexMask = (1 << _indexBits) - 1;

  factory EntityId.of(int index, int generation) =>
      EntityId((generation << _indexBits) | (index & _indexMask));

  int get index => raw & _indexMask;

  int get generation => raw >> _indexBits;

  bool get isNone => raw < 0;
}

/// What an entity fundamentally is.
///
/// Kept deliberately coarse. Behavioural variation (which enemy, which arrow)
/// lives in data, not in this enum — otherwise every new enemy would mean a new
/// switch case in every system.
enum EntityKind {
  player,
  enemy,
  projectile,
  pickup,
  hazard,
}

/// Struct-of-arrays entity storage.
///
/// Components live in parallel typed arrays rather than in objects. Two reasons,
/// both from docs/19-performance.md:
///
///  1. **No per-entity allocation.** Dart's generational GC collects after a few
///     hundred KB; a system allocating per entity per frame at 60 Hz produces
///     visible periodic jank on a low-end device.
///  2. **Cache locality.** A system iterating `posX`/`posY` walks contiguous
///     memory instead of chasing pointers through 90 scattered objects.
///
/// The cost is ergonomics: there is no `Entity` object to hold. That is the
/// trade, and it is why this class carries the accessors it does.
class EntityStore {
  EntityStore({int capacity = SimConfig.maxEntities})
      : _capacity = capacity,
        alive = Uint8List(capacity),
        kind = Uint8List(capacity),
        generation = Int32List(capacity),
        posX = Float64List(capacity),
        posY = Float64List(capacity),
        velX = Float64List(capacity),
        velY = Float64List(capacity),
        radius = Float64List(capacity),
        facing = Float64List(capacity),
        health = Float64List(capacity),
        maxHealth = Float64List(capacity),
        contentIndex = Int32List(capacity),
        _freeList = Int32List(capacity),
        _freeCount = capacity {
    // Seed the free list in reverse so the first allocations come out in
    // ascending index order, which keeps iteration order stable and therefore
    // deterministic.
    for (int i = 0; i < capacity; i++) {
      _freeList[i] = capacity - 1 - i;
    }
  }

  final int _capacity;

  // ── Hot components ────────────────────────────────────────────────────────

  final Uint8List alive;
  final Uint8List kind;
  final Int32List generation;

  final Float64List posX;
  final Float64List posY;
  final Float64List velX;
  final Float64List velY;
  final Float64List radius;

  /// Heading in radians. Used for shielded enemies (Husk, Bulwark) whose armour
  /// only faces one way, and for directional telegraphs.
  final Float64List facing;

  final Float64List health;
  final Float64List maxHealth;

  /// Index into the loaded content table for this entity's kind — which enemy
  /// definition, which arrow type. Keeps per-entity data out of the hot arrays.
  final Int32List contentIndex;

  final Int32List _freeList;
  int _freeCount;

  /// Highest slot index ever used, so systems iterate `0..highWater` instead of
  /// the full capacity. With 12 live entities this is the difference between 12
  /// iterations and 512.
  int _highWater = 0;

  int _liveCount = 0;

  int get capacity => _capacity;

  int get liveCount => _liveCount;

  /// Exclusive upper bound for iteration.
  int get highWater => _highWater;

  bool isAlive(EntityId id) {
    if (id.isNone) return false;
    final int i = id.index;
    if (i >= _capacity) return false;
    return alive[i] == 1 && generation[i] == id.generation;
  }

  /// Claims a slot. Returns [EntityId.none] when full.
  ///
  /// Returning none rather than growing is deliberate: growing allocates, and
  /// allocation during combat is what this whole design exists to avoid. A full
  /// store means the spawn system tried to exceed a documented cap, which is a
  /// bug in the caller.
  EntityId spawn(EntityKind entityKind) {
    if (_freeCount == 0) return EntityId.none;

    final int index = _freeList[--_freeCount];
    alive[index] = 1;
    kind[index] = entityKind.index;

    posX[index] = 0;
    posY[index] = 0;
    velX[index] = 0;
    velY[index] = 0;
    radius[index] = 0;
    facing[index] = 0;
    health[index] = 0;
    maxHealth[index] = 0;
    contentIndex[index] = -1;

    _liveCount++;
    if (index >= _highWater) _highWater = index + 1;

    return EntityId.of(index, generation[index]);
  }

  /// Releases a slot and invalidates every outstanding handle to it.
  void despawn(EntityId id) {
    if (!isAlive(id)) return;
    final int index = id.index;

    alive[index] = 0;
    // Bumping the generation is what makes stale handles detectable. It wraps
    // at 2^11 which, at any realistic spawn rate, is far more than enough for a
    // handle to have gone out of scope.
    generation[index] = (generation[index] + 1) & 0x7FF;
    _freeList[_freeCount++] = index;
    _liveCount--;

    if (index == _highWater - 1) {
      // Pull the water line back over any trailing dead slots.
      int newHigh = _highWater - 1;
      while (newHigh > 0 && alive[newHigh - 1] == 0) {
        newHigh--;
      }
      _highWater = newHigh;
    }
  }

  /// Empties the store. Used between rooms and between simulated runs.
  void clear() {
    for (int i = 0; i < _highWater; i++) {
      alive[i] = 0;
    }
    for (int i = 0; i < _capacity; i++) {
      _freeList[i] = _capacity - 1 - i;
    }
    _freeCount = _capacity;
    _liveCount = 0;
    _highWater = 0;
  }

  EntityKind kindOf(int index) => EntityKind.values[kind[index]];

  /// Handle for a slot index, for systems that iterate by index and need to
  /// publish an event.
  EntityId idAt(int index) => EntityId.of(index, generation[index]);
}
