import 'dart:ui';

import 'package:quiverfall/game/device/quality_tier.dart';
import 'package:quiverfall/game/feel/feel_palette.dart';
import 'package:quiverfall/game/sim/arena.dart' as sim;

/// The static parts of the arena, recorded once.
///
/// docs/19 §19.3: "the background is a static composited layer, redrawn only
/// when the arena changes." The floor, its border and every wall are identical
/// on every frame of a room, so re-issuing those draw calls sixty times a
/// second is pure waste — a `Picture` is recorded when the room changes and
/// replayed thereafter.
///
/// The saving is modest in absolute terms and it is not why this exists. It
/// exists because docs/15 §15.0 rule 3 makes the background *stage, never
/// noise*: separating it into its own layer is what makes it impossible for a
/// gameplay-relevant colour to leak into it during a later change.
class ArenaLayer {
  Picture? _picture;
  sim.Arena? _recordedFor;
  QualityTier _recordedAt = QualityTier.high;

  /// Times the layer has been re-recorded. Should be one per room; anything
  /// higher means something is invalidating it every frame, which is the exact
  /// failure this class exists to prevent.
  int rerecordCount = 0;

  bool get isRecorded => _picture != null;

  /// Draws the arena, recording it first if the room or the tier changed.
  ///
  /// **Must be called inside the camera's world transform**, because the
  /// picture is recorded in world units. Recording in screen units would mean
  /// re-recording on every rotation and every shake frame.
  void render(Canvas canvas, sim.Arena arena, QualityTier quality) {
    if (!identical(arena, _recordedFor) || quality != _recordedAt) {
      _record(arena, quality);
    }
    final Picture? picture = _picture;
    if (picture != null) canvas.drawPicture(picture);
  }

  void _record(sim.Arena arena, QualityTier quality) {
    _picture?.dispose();

    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Paint fill = Paint()..style = PaintingStyle.fill;
    final Paint stroke = Paint()..style = PaintingStyle.stroke;

    fill.color = const Color(FeelPalette.arenaFloor);
    canvas.drawRect(Rect.fromLTWH(0, 0, arena.width, arena.height), fill);

    // High tier gets a faint grid. It is not decoration: docs/01 measures
    // everything in world units, and a visible metric makes distances like the
    // Thresher's 2.4 u aura learnable rather than guessed. Dropped on lower
    // tiers because it is the cheapest thing on screen to lose.
    if (quality == QualityTier.high) {
      stroke
        ..color = Color(FeelPalette.withAlpha(FeelPalette.arenaWall, 0.16))
        ..strokeWidth = 0.015;
      for (double x = 1; x < arena.width; x += 1) {
        canvas.drawLine(Offset(x, 0), Offset(x, arena.height), stroke);
      }
      for (double y = 1; y < arena.height; y += 1) {
        canvas.drawLine(Offset(0, y), Offset(arena.width, y), stroke);
      }
    }

    // A hard border, because players back into walls constantly and an
    // invisible boundary reads as the character sticking.
    stroke
      ..color = const Color(FeelPalette.arenaWall)
      ..strokeWidth = 0.05;
    canvas.drawRect(Rect.fromLTWH(0, 0, arena.width, arena.height), stroke);

    fill.color = const Color(FeelPalette.arenaWall);
    for (int i = 0; i < arena.wallCount; i++) {
      canvas.drawRect(
        Rect.fromLTRB(
          arena.wallLeft(i),
          arena.wallTop(i),
          arena.wallRight(i),
          arena.wallBottom(i),
        ),
        fill,
      );
    }

    _picture = recorder.endRecording();
    _recordedFor = arena;
    _recordedAt = quality;
    rerecordCount++;
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
    _recordedFor = null;
  }
}
