import 'dart:typed_data';

import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/sim_config.dart';

/// Uniform-grid spatial index over the arena.
///
/// Every neighbour query in the game routes through this: contact damage,
/// projectile hits, AI target selection, aura radii, and — most importantly —
/// Confluence intersection tests, which are the single heaviest query in the
/// game (docs/19-performance.md §19.2 budgets it at 0.8 ms with up to 60 arrows
/// against 1,024 Windline segments).
///
/// **Fully pre-allocated.** Buckets are a flat `Int32List` of
/// `cellCount * maxPerCell`, so rebuilding the index each tick costs zero
/// allocation. A cell that overflows drops the surplus rather than growing —
/// growing mid-tick is exactly the allocation this design exists to avoid, and
/// `maxPerCell` (32) is far above any legitimate density given the 90-entity
/// room cap.
class SpatialHash {
  SpatialHash({
    this.cols = SimConfig.gridCols,
    this.rows = SimConfig.gridRows,
    this.cellSize = SimConfig.cellSize,
    this.maxPerCell = SimConfig.maxPerCell,
  })  : _cellCount = cols * rows,
        _buckets = Int32List(cols * rows * maxPerCell),
        _counts = Int32List(cols * rows),
        _queryResult = Int32List(SimConfig.maxEntities);

  final int cols;
  final int rows;
  final double cellSize;
  final int maxPerCell;

  final int _cellCount;
  final Int32List _buckets;
  final Int32List _counts;

  /// Reusable output buffer. Callers must consume results before the next
  /// query — documented rather than defended, because returning a fresh list
  /// would allocate on every query and there are thousands per tick.
  final Int32List _queryResult;
  int _queryCount = 0;

  /// Number of insertions dropped due to cell overflow since the last [clear].
  /// Non-zero means either a density bug or a cap that needs raising; the sim
  /// surfaces it rather than failing silently.
  int overflowCount = 0;

  int get cellCount => _cellCount;

  void clear() {
    for (int i = 0; i < _cellCount; i++) {
      _counts[i] = 0;
    }
    overflowCount = 0;
    _queryCount = 0;
  }

  int cellIndexFor(double x, double y) {
    int cx = (x / cellSize).floor();
    int cy = (y / cellSize).floor();
    if (cx < 0) cx = 0;
    if (cy < 0) cy = 0;
    if (cx >= cols) cx = cols - 1;
    if (cy >= rows) cy = rows - 1;
    return cy * cols + cx;
  }

  /// Inserts an entity slot index at a position.
  void insert(int entityIndex, double x, double y) {
    final int cell = cellIndexFor(x, y);
    final int count = _counts[cell];
    if (count >= maxPerCell) {
      overflowCount++;
      return;
    }
    _buckets[cell * maxPerCell + count] = entityIndex;
    _counts[cell] = count + 1;
  }

  /// Rebuilds the index from live entities. Called once per tick.
  void rebuild(EntityStore store) {
    clear();
    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      insert(i, store.posX[i], store.posY[i]);
    }
  }

  /// Collects entity indices within [radius] of a point.
  ///
  /// Returns the count; read results via [resultAt]. This shape avoids
  /// allocating a list per query.
  ///
  /// Results are *candidates* — everything in the overlapping cells. Callers
  /// still do the exact distance test. That is the point of a broad phase.
  int queryRadius(double x, double y, double radius) {
    _queryCount = 0;

    final int minCx = _clampCol(((x - radius) / cellSize).floor());
    final int maxCx = _clampCol(((x + radius) / cellSize).floor());
    final int minCy = _clampRow(((y - radius) / cellSize).floor());
    final int maxCy = _clampRow(((y + radius) / cellSize).floor());

    for (int cy = minCy; cy <= maxCy; cy++) {
      final int rowBase = cy * cols;
      for (int cx = minCx; cx <= maxCx; cx++) {
        final int cell = rowBase + cx;
        final int count = _counts[cell];
        final int base = cell * maxPerCell;
        for (int k = 0; k < count; k++) {
          if (_queryCount >= _queryResult.length) return _queryCount;
          _queryResult[_queryCount++] = _buckets[base + k];
        }
      }
    }
    return _queryCount;
  }

  /// Collects entity indices in the cells a segment passes through.
  ///
  /// Used by projectile sweeps and by Confluence, where an arrow's flight path
  /// must be tested against Windline segments. Walks the segment's bounding
  /// cells rather than a true DDA: for the short per-tick sweeps involved
  /// (a fast arrow travels ~0.3 u per tick, well under one cell) the bounding
  /// box is at most 2x2 cells, so a DDA would cost more than it saves.
  int querySegment(double x0, double y0, double x1, double y1, double pad) {
    _queryCount = 0;

    final double minX = (x0 < x1 ? x0 : x1) - pad;
    final double maxX = (x0 > x1 ? x0 : x1) + pad;
    final double minY = (y0 < y1 ? y0 : y1) - pad;
    final double maxY = (y0 > y1 ? y0 : y1) + pad;

    final int minCx = _clampCol((minX / cellSize).floor());
    final int maxCx = _clampCol((maxX / cellSize).floor());
    final int minCy = _clampRow((minY / cellSize).floor());
    final int maxCy = _clampRow((maxY / cellSize).floor());

    for (int cy = minCy; cy <= maxCy; cy++) {
      final int rowBase = cy * cols;
      for (int cx = minCx; cx <= maxCx; cx++) {
        final int cell = rowBase + cx;
        final int count = _counts[cell];
        final int base = cell * maxPerCell;
        for (int k = 0; k < count; k++) {
          if (_queryCount >= _queryResult.length) return _queryCount;
          _queryResult[_queryCount++] = _buckets[base + k];
        }
      }
    }
    return _queryCount;
  }

  int resultAt(int i) => _queryResult[i];

  /// Live occupancy of a cell. Test seam.
  int countInCell(int cell) => _counts[cell];

  int _clampCol(int v) => v < 0 ? 0 : (v >= cols ? cols - 1 : v);

  int _clampRow(int v) => v < 0 ? 0 : (v >= rows ? rows - 1 : v);
}
