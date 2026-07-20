import 'dart:ui';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/device/quality_tier.dart';
import 'package:quiverfall/game/feel/feedback_director.dart';
import 'package:quiverfall/game/feel/feel_palette.dart';
import 'package:quiverfall/game/feel/particle_pool.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/windline_store.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/view/render/particle_mesh.dart';
import 'package:quiverfall/view/render/windline_mesh.dart';
import 'package:quiverfall/view/render/world_painter.dart';
import 'package:test/test.dart';

/// The Phase 7 render gate.
///
/// **What this measures, and what it does not.** Recording into a
/// `PictureRecorder` measures the Dart-side cost of *issuing* draw calls —
/// building vertex buffers, walking the stores, computing geometry. It does not
/// measure rasterisation, which happens on the GPU and needs a real device.
///
/// That split is the honest one. The Phase 7 exit criterion is "90 entities +
/// 1,024 segments hold 60 FPS on the reference low-end device", and no CI
/// machine can answer that. What CI *can* answer is whether the render layer
/// issues its work in bounded, batched, allocation-free time — and if that
/// regresses, the device test was never going to pass either.
///
/// Lives in `benchmark/` rather than `test/` so a bare `flutter test` never
/// runs it: these are wall-clock numbers and the default runner executes files
/// in parallel. Run with `dart run tool/bench.dart`.
void main() {
  /// The documented peak from docs/19 §19.1.
  const int peakSegments = SimConfig.maxWindlineSegments;
  const int peakEntities = 90;

  WindlineStore fullStore() {
    final WindlineStore lines = WindlineStore();
    for (int i = 0; i < peakSegments; i++) {
      final double x = (i % 40) * 0.4;
      final double y = ((i ~/ 40) % 22) * 0.4;
      lines.add(
        fromX: x,
        fromY: y,
        toX: x + 0.6,
        toY: y + 0.5,
        expiresAt: 1e9,
        ownerIndex: 0,
        trailId: i,
        elementIndex: i % 5 - 1,
      );
    }
    return lines;
  }

  double timeMs(int iterations, void Function() body) {
    for (int i = 0; i < 20; i++) {
      body();
    }
    final Stopwatch watch = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      body();
    }
    watch.stop();
    return watch.elapsedMicroseconds / 1000 / iterations;
  }

  group('Windline mesh', () {
    test('builds 1,024 segments well inside the frame budget', () {
      final WindlineStore lines = fullStore();
      final WindlineMesh mesh = WindlineMesh();

      final double ms = timeMs(200, () => mesh.rebuild(lines, 0, 1.2));

      // ignore: avoid_print
      print('windline mesh: $peakSegments segments in '
          '${ms.toStringAsFixed(4)} ms');

      expect(mesh.segmentsBuilt, peakSegments);
      // A slice of the 7.0 ms render budget. Generous because this is the
      // build, not the raster — if buffer construction alone approaches a
      // millisecond, batching has stopped being the win it was supposed to be.
      expect(ms, lessThan(1.0));
    });

    test('scans only the active prefix when the budget is lowered', () {
      final WindlineStore lines = fullStore();
      final WindlineMesh mesh = WindlineMesh();

      final double full = timeMs(200, () => mesh.rebuild(lines, 0, 1.2));

      lines.budget = QualityTier.battery.windlineBudget;
      final double battery = timeMs(200, () => mesh.rebuild(lines, 0, 1.2));

      // ignore: avoid_print
      print('windline mesh: full ${full.toStringAsFixed(4)} ms, '
          'battery ${battery.toStringAsFixed(4)} ms');

      expect(mesh.segmentsBuilt, lessThanOrEqualTo(320));
      // The tier that can least afford wasted work must actually do less of it.
      expect(battery, lessThan(full));
    });
  });

  group('Particle mesh', () {
    test('builds a full pool in one buffer', () {
      final ParticlePool pool = ParticlePool();
      pool.burst(
        atX: 8,
        atY: 4.5,
        count: pool.capacity,
        argb: FeelPalette.whiteHot,
      );

      final ParticleMesh mesh = ParticleMesh();
      final double ms = timeMs(200, () => mesh.rebuild(pool));

      // ignore: avoid_print
      print('particle mesh: ${pool.liveCount} particles in '
          '${ms.toStringAsFixed(4)} ms');

      expect(mesh.built, greaterThan(0));
      expect(ms, lessThan(0.5));
    });

    test('density thins the buffer without touching the pool', () {
      final ParticlePool pool = ParticlePool();
      pool.burst(atX: 8, atY: 4.5, count: 400, argb: FeelPalette.whiteHot);

      final ParticleMesh mesh = ParticleMesh()..rebuild(pool);
      final int atFull = mesh.built;

      mesh.rebuild(pool, density: QualityTier.battery.particleDensity);
      final int atBattery = mesh.built;

      expect(atBattery, lessThan(atFull));
      // The pool is a faithful record of what happened; only the *drawing* is
      // thinned, so raising the tier takes effect on the next frame.
      expect(pool.liveCount, greaterThanOrEqualTo(atFull));
    });
  });

  group('the full render pass', () {
    test('a peak-load frame records inside the render budget', () {
      final SimWorld world = SimWorld(
        seed: 77,
        content: ContentLibrary.empty(),
      )..autoFire = true;
      world.spawnPlayer(SimConfig.arenaWidth / 2, SimConfig.arenaHeight / 2);

      for (int i = 0; i < peakEntities - 1; i++) {
        final int slot = world
            .spawnAt(
              EntityKind.enemy,
              0.8 + (i % 14) * 1.05,
              0.7 + (i ~/ 14) * 1.25,
              radius: 0.3,
              health: 1e9,
            )
            .index;
        world.entities.velX[slot] = ((i % 5) - 2) * 0.4;
      }

      final FeedbackDirector director = FeedbackDirector(world: world);
      final WorldPainter painter =
          WorldPainter(world: world, director: director);

      // Fill the arena with everything a heavy frame contains.
      final InputSnapshot moving = InputSnapshot()..set(0.7, 0.4);
      for (int i = 0; i < 400; i++) {
        world.tick(moving);
        director.drainEvents();
        world.events.clear();
      }
      director.particles.burst(
        atX: 8,
        atY: 4.5,
        count: 400,
        argb: FeelPalette.whiteHot,
      );

      // Windlines expire in 1.2 s, so simulating alone leaves a handful alive
      // and the frame is not the peak it claims to be. The ring is filled
      // directly, with expiries far in the future, so this really is the
      // documented worst case.
      for (int i = 0; i < peakSegments; i++) {
        final double x = (i % 40) * 0.4;
        final double y = ((i ~/ 40) % 22) * 0.4;
        world.windlines.add(
          fromX: x,
          fromY: y,
          toX: x + 0.6,
          toY: y + 0.5,
          expiresAt: 1e9,
          ownerIndex: 0,
          trailId: i,
          elementIndex: i % 5 - 1,
        );
      }
      expect(world.windlines.liveCount, peakSegments);

      const Size size = Size(844, 390);
      final double ms = timeMs(120, () {
        final PictureRecorder recorder = PictureRecorder();
        painter.paint(Canvas(recorder), size);
        recorder.endRecording().dispose();
      });

      // ignore: avoid_print
      print('render pass: ${world.entities.liveCount} entities, '
          '${world.windlines.liveCount} segments, '
          '${director.particles.liveCount} particles -> '
          '${ms.toStringAsFixed(3)} ms to record');

      // docs/19 §19.1 gives rendering 7.0 ms of a 16.6 ms frame. Issuing the
      // draw calls should be a small fraction of that; the rest belongs to the
      // GPU, which this cannot see.
      expect(ms, lessThan(3.0));

      painter.dispose();
    });

    test('the static arena is recorded once, not every frame', () {
      // The whole point of the layer. If this number climbs with frame count,
      // something is invalidating the picture and the optimisation is inverted.
      final SimWorld world = SimWorld(seed: 1, content: ContentLibrary.empty());
      world.spawnPlayer(4, 4.5);

      final FeedbackDirector director = FeedbackDirector(world: world);
      final WorldPainter painter =
          WorldPainter(world: world, director: director);

      const Size size = Size(844, 390);
      for (int i = 0; i < 60; i++) {
        final PictureRecorder recorder = PictureRecorder();
        painter.paint(Canvas(recorder), size);
        recorder.endRecording().dispose();
      }

      expect(painter.arenaLayer.rerecordCount, 1);
      painter.dispose();
    });
  });
}
