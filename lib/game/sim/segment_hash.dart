import 'dart:typed_data';

import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/windline_store.dart';

/// Spatial index over Windline segments.
///
/// Separate from [SpatialHash] because the contents are fundamentally
/// different: entities are points and land in exactly one cell, whereas a
/// segment spans a range of cells and must be inserted into all of them.
///
/// **This exists because it was measured, not assumed.** The first
/// implementation of [ConfluenceSystem] scanned all live segments linearly,
/// relying on cheap age/owner/AABB rejects. Benchmarked at the documented worst
/// case — 60 arrows against 1,024 segments — that came to **1.52 ms/frame
/// against a 0.8 ms budget**. docs/19-performance.md §19.2 called for this index
/// and was right.
///
/// Sizing note: [maxPerCell] is deliberately large enough to hold *every*
/// segment in a single cell. A player standing still and firing in one direction
/// piles their whole trail into a handful of cells, and overflow here would mean
/// a silently missed Confluence — which would make the game's signature mechanic
/// feel arbitrary. ~270 KB is a cheap price for removing that failure mode.
class SegmentHash {
  SegmentHash({
    this.cols = SimConfig.gridCols,
    this.rows = SimConfig.gridRows,
    this.cellSize = SimConfig.cellSize,
    this.maxPerCell = SimConfig.maxWindlineSegments,
  })  : _cellCount = cols * rows,
        _buckets = Int32List(cols * rows * maxPerCell),
        _counts = Int32List(cols * rows),
        _seen = Int32List(SimConfig.maxWindlineSegments);

  final int cols;
  final int rows;
  final double cellSize;
  final int maxPerCell;

  final int _cellCount;
  final Int32List _buckets;
  final Int32List _counts;

  /// Per-query dedupe marks. A segment spanning several cells would otherwise be
  /// returned once per overlapping cell; stamping it with the query id makes
  /// deduplication O(1) with no clearing pass between queries.
  final Int32List _seen;
  int _queryStamp = 0;

  int overflowCount = 0;

  void clear() {
    for (int i = 0; i < _cellCount; i++) {
      _counts[i] = 0;
    }
    overflowCount = 0;
  }

  /// Rebuilds from every live segment. Called once per tick.
  void rebuild(WindlineStore lines) {
    clear();
    // Only the active prefix can hold live segments — see WindlineStore.budget.
    for (int i = 0; i < lines.activeSlots; i++) {
      if (!lines.isAlive(i)) continue;
      _insertSegment(i, lines.x0(i), lines.y0(i), lines.x1(i), lines.y1(i));
    }
  }

  void _insertSegment(
    int slot,
    double x0,
    double y0,
    double x1,
    double y1,
  ) {
    final int minCx = _clampCol(((x0 < x1 ? x0 : x1) / cellSize).floor());
    final int maxCx = _clampCol(((x0 > x1 ? x0 : x1) / cellSize).floor());
    final int minCy = _clampRow(((y0 < y1 ? y0 : y1) / cellSize).floor());
    final int maxCy = _clampRow(((y0 > y1 ? y0 : y1) / cellSize).floor());

    for (int cy = minCy; cy <= maxCy; cy++) {
      final int rowBase = cy * cols;
      for (int cx = minCx; cx <= maxCx; cx++) {
        final int cell = rowBase + cx;
        final int count = _counts[cell];
        if (count >= maxPerCell) {
          overflowCount++;
          continue;
        }
        _buckets[cell * maxPerCell + count] = slot;
        _counts[cell] = count + 1;
      }
    }
  }

  /// Collects segment slots whose cells overlap a swept path.
  ///
  /// Results are written into [out] and the count returned. Deduplicated, so a
  /// segment spanning several of the queried cells appears once.
  int querySegment(
    double x0,
    double y0,
    double x1,
    double y1,
    double pad,
    Int32List out,
  ) {
    _queryStamp++;
    int found = 0;

    final int minCx = _clampCol((((x0 < x1 ? x0 : x1) - pad) / cellSize).floor());
    final int maxCx = _clampCol((((x0 > x1 ? x0 : x1) + pad) / cellSize).floor());
    final int minCy = _clampRow((((y0 < y1 ? y0 : y1) - pad) / cellSize).floor());
    final int maxCy = _clampRow((((y0 > y1 ? y0 : y1) + pad) / cellSize).floor());

    for (int cy = minCy; cy <= maxCy; cy++) {
      final int rowBase = cy * cols;
      for (int cx = minCx; cx <= maxCx; cx++) {
        final int cell = rowBase + cx;
        final int count = _counts[cell];
        final int base = cell * maxPerCell;
        for (int k = 0; k < count; k++) {
          final int slot = _buckets[base + k];
          if (_seen[slot] == _queryStamp) continue;
          _seen[slot] = _queryStamp;
          if (found >= out.length) return found;
          out[found++] = slot;
        }
      }
    }
    return found;
  }

  int countInCell(int cell) => _counts[cell];

  int _clampCol(int v) => v < 0 ? 0 : (v >= cols ? cols - 1 : v);

  int _clampRow(int v) => v < 0 ? 0 : (v >= rows ? rows - 1 : v);
}
