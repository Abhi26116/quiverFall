import 'dart:typed_data';

import 'package:quiverfall/game/sim/segment_hash.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/windline_store.dart';

/// Confluence stack values, from docs/01-vision.md §1.1.
///
/// The escalation is deliberately super-linear: the jump from x2 to x3 is
/// larger than x1 to x2, so threading a third line feels like a payoff rather
/// than an increment. x4 and x5 exist only for Iris (docs/07 §7.3).
abstract final class ConfluenceTuning {
  /// Damage bonus by stack count. Index 0 is "no Confluence".
  static const List<double> bonusByStacks = <double>[
    0.00, // 0
    0.40, // 1
    0.90, // 2
    1.60, // 3  — default cap
    2.30, // 4  — Iris
    3.20, // 5  — Iris, plus a 2u AoE
  ];

  static const int defaultMaxStacks = 3;
  static const int irisMaxStacks = 5;

  /// Extra pierce granted at maximum stacks — the arrow becomes a lance.
  static const int pierceAtMaxStacks = 1;

  static double bonusFor(int stacks) {
    if (stacks <= 0) return 0;
    if (stacks >= bonusByStacks.length) return bonusByStacks.last;
    return bonusByStacks[stacks];
  }
}

/// Detects arrows threading their own Windlines.
///
/// **This is the most performance-critical query in the game.** Naively, every
/// arrow tests against every live segment: at 60 arrows and 1,024 segments that
/// is 61,440 segment-segment intersections per tick. docs/19-performance.md
/// §19.2 budgets the whole thing at 0.8 ms.
///
/// Three filters run before any real geometry, in increasing cost order:
///
///  1. **Age** — an arrow may only Confluence with segments *older* than itself.
///     Without this an arrow would trigger on the line it is currently laying,
///     handing every shot a free stack.
///  2. **Owner** — only the player's own lines qualify. An enemy trail must
///     never buff the player.
///  3. **Early-out AABB** — a bounding-box reject before the intersection maths.
///
/// The result is a full scan of cheap array reads with roughly four genuine
/// intersection tests per arrow per tick.
///
/// **On the spatial index.** It was built because it was measured. The first
/// implementation relied on the three cheap filters alone and scanned every live
/// segment; at the documented worst case that came to **1.52 ms/frame against
/// the 0.8 ms budget**. [SegmentHash] cuts the candidate set to the cells the
/// arrow actually passes through. The linear path is kept as a fallback when no
/// index is supplied, which is what the correctness tests exercise — so the two
/// paths are checked against each other rather than the fast one being trusted
/// blindly.
abstract final class ConfluenceSystem {
  /// Result of one arrow's sweep. Mutable and reused — a fresh result object per
  /// arrow per tick would be exactly the steady-state allocation the whole
  /// simulation design forbids.
  static final ConfluenceResult result = ConfluenceResult();

  /// Reused candidate buffer for the spatial query. Static and pre-allocated:
  /// this is called once per arrow per tick, so a fresh list here would be the
  /// exact steady-state allocation the design forbids.
  static final Int32List _candidates =
      Int32List(SimConfig.maxWindlineSegments);

  /// Tests an arrow's swept path against live Windlines.
  ///
  /// [arrowSerial] is the serial of the segment this arrow is itself laying;
  /// only strictly older segments are eligible (reduction 2).
  ///
  /// Fills and returns the shared [result].
  static ConfluenceResult sweep({
    required WindlineStore lines,
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    required int arrowSerial,
    required int ownerIndex,
    required double hitWidth,
    required int maxStacks,
    required List<int> alreadyCrossed,
    required int crossedBase,
    required int crossedCount,
    SegmentHash? index,
  }) {
    result.reset();

    // Reduction 4, hoisted: the arrow's own bounding box, padded by hit width.
    final double minX = (fromX < toX ? fromX : toX) - hitWidth;
    final double maxX = (fromX > toX ? fromX : toX) + hitWidth;
    final double minY = (fromY < toY ? fromY : toY) - hitWidth;
    final double maxY = (fromY > toY ? fromY : toY) + hitWidth;

    // Reduction 1 — spatial. Narrows ~1,024 segments to the handful sharing a
    // cell with the arrow's path. Without it this loop measured 1.52 ms against
    // a 0.8 ms budget; with it, the candidate list is small enough that the
    // remaining filters are almost free.
    final int candidateCount = index == null
        ? -1
        : index.querySegment(fromX, fromY, toX, toY, hitWidth, _candidates);

    final int scanLimit = candidateCount < 0 ? lines.capacity : candidateCount;

    for (int c = 0; c < scanLimit; c++) {
      final int i = candidateCount < 0 ? c : _candidates[c];
      if (!lines.isAlive(i)) continue;

      // Reduction 2 — age. Strictly older, never equal.
      if (lines.serialAt(i) >= arrowSerial) continue;

      // Reduction 3 — ownership.
      if (lines.ownerAt(i) != ownerIndex) continue;

      final double sx0 = lines.x0(i);
      final double sy0 = lines.y0(i);
      final double sx1 = lines.x1(i);
      final double sy1 = lines.y1(i);

      // Reduction 4 — bounding box.
      if ((sx0 < minX && sx1 < minX) ||
          (sx0 > maxX && sx1 > maxX) ||
          (sy0 < minY && sy1 < minY) ||
          (sy0 > maxY && sy1 > maxY)) {
        continue;
      }

      // A *trail* may only ever grant one stack to a given arrow — not a
      // segment. One arrow's trail is many segments, and crossing it is one
      // crossing. Deduping per segment would let a single thread hand out a
      // full stack on its own, which is not the mechanic.
      final int serial = lines.trailAt(i);
      bool seen = false;
      for (int k = 0; k < crossedCount; k++) {
        if (alreadyCrossed[crossedBase + k] == serial) {
          seen = true;
          break;
        }
      }
      if (seen) continue;

      if (!segmentsIntersect(
        fromX,
        fromY,
        toX,
        toY,
        sx0,
        sy0,
        sx1,
        sy1,
        hitWidth,
      )) {
        continue;
      }

      result.addCrossing(serial, lines.elementAt(i));
      if (result.stacks >= maxStacks) break;
    }

    if (result.stacks > maxStacks) result.stacks = maxStacks;
    return result;
  }

  /// Minimum angle between an arrow and a Windline for the crossing to count.
  ///
  /// **This is a game-design constant, not a numerical tolerance.** Confluence
  /// rewards threading a *lattice* — crossing your trails at an angle. Retracing
  /// a line you already drew is not threading it.
  ///
  /// Without this rule the mechanic collapses: a player standing still and
  /// auto-aiming sends every arrow down nearly the same path, so each shot
  /// "crosses" its predecessor's trail along the whole length. Measured, that
  /// produced Confluence on **50 of 52 shots** — a mechanic that fires by
  /// default is not a skill expression, it is a flat damage buff with extra
  /// steps.
  ///
  /// Stored as the cosine so the test is a dot-product compare with no trig.
  /// 25 degrees.
  static const double _maxParallelCos = 0.906;

  /// True if two segments genuinely cross.
  ///
  /// Handles the proper-crossing case exactly, then falls back to a
  /// closest-approach test so a near-miss within the arrow's hit width still
  /// registers — "my arrow clearly went through the line but nothing happened"
  /// is the worst thing that could happen to this mechanic's credibility.
  ///
  /// Near-parallel pairs are rejected outright regardless of proximity; see
  /// [_maxParallelCos].
  static bool segmentsIntersect(
    double ax0,
    double ay0,
    double ax1,
    double ay1,
    double bx0,
    double by0,
    double bx1,
    double by1,
    double tolerance,
  ) {
    final double d1x = ax1 - ax0;
    final double d1y = ay1 - ay0;
    final double d2x = bx1 - bx0;
    final double d2y = by1 - by0;

    final double len1Sq = d1x * d1x + d1y * d1y;
    final double len2Sq = d2x * d2x + d2y * d2y;

    // Degenerate (point) segments have no direction, so the angle rule cannot
    // apply and proximity is the only meaningful test.
    final bool bothHaveDirection = len1Sq > 1e-12 && len2Sq > 1e-12;

    if (bothHaveDirection) {
      final double dot = d1x * d2x + d1y * d2y;
      final double cosSq = (dot * dot) / (len1Sq * len2Sq);
      if (cosSq >= _maxParallelCos * _maxParallelCos) {
        return false;
      }
    }

    final double denom = d1x * d2y - d1y * d2x;

    if (denom.abs() > 1e-12) {
      final double ex = bx0 - ax0;
      final double ey = by0 - ay0;
      final double t = (ex * d2y - ey * d2x) / denom;
      final double u = (ex * d1y - ey * d1x) / denom;
      if (t >= 0 && t <= 1 && u >= 0 && u <= 1) return true;
    }

    // Near miss at a legal angle: fall back to closest approach.
    final double tolSq = tolerance * tolerance;
    return _pointSegmentDistSq(ax0, ay0, bx0, by0, bx1, by1) <= tolSq ||
        _pointSegmentDistSq(ax1, ay1, bx0, by0, bx1, by1) <= tolSq ||
        _pointSegmentDistSq(bx0, by0, ax0, ay0, ax1, ay1) <= tolSq ||
        _pointSegmentDistSq(bx1, by1, ax0, ay0, ax1, ay1) <= tolSq;
  }

  static double _pointSegmentDistSq(
    double px,
    double py,
    double x0,
    double y0,
    double x1,
    double y1,
  ) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double lenSq = dx * dx + dy * dy;

    double t;
    if (lenSq <= 1e-12) {
      t = 0;
    } else {
      t = ((px - x0) * dx + (py - y0) * dy) / lenSq;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
    }

    final double gx = px - (x0 + dx * t);
    final double gy = py - (y0 + dy * t);
    return gx * gx + gy * gy;
  }
}

/// Outcome of one arrow's Confluence sweep.
class ConfluenceResult {
  static const int maxTrackedElements = 4;

  int stacks = 0;

  /// Serials of the segments crossed this sweep, so the caller can record them
  /// against the arrow.
  final List<int> crossedSerials = <int>[];

  /// Distinct elements picked up from crossed lines. Three or more collapse to
  /// Prismbreak.
  final List<int> elements = <int>[];

  void reset() {
    stacks = 0;
    crossedSerials.clear();
    elements.clear();
  }

  void addCrossing(int serial, int elementIndex) {
    stacks++;
    crossedSerials.add(serial);
    if (elementIndex >= 0 &&
        !elements.contains(elementIndex) &&
        elements.length < maxTrackedElements) {
      elements.add(elementIndex);
    }
  }

  double get damageBonus => ConfluenceTuning.bonusFor(stacks);

  bool get isMaxed => stacks >= ConfluenceTuning.defaultMaxStacks;
}
