import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/device/quality_tier.dart';
import 'package:quiverfall/game/feel/damage_number_pool.dart';
import 'package:quiverfall/game/feel/feedback_director.dart';
import 'package:quiverfall/game/feel/feel_palette.dart';
import 'package:quiverfall/game/feel/juice.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/hazard_store.dart';
import 'package:quiverfall/game/sim/telegraph.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/view/camera/game_camera.dart';
import 'package:quiverfall/view/render/arena_layer.dart';
import 'package:quiverfall/view/render/particle_mesh.dart';
import 'package:quiverfall/view/render/windline_mesh.dart';

/// The greybox renderer.
///
/// Phase 6 asks for "a minimal Flame renderer — enough to *play*", with exactly
/// one exception: **the Windline and Confluence VFX ship near-final**, because
/// their readability is the mechanic under test and greyboxing them would make
/// the playtest measure the wrong thing (roadmap, Phase 6).
///
/// Everything else here is a shape with a flat fill and a dark outline, which
/// is not a placeholder for the real art so much as a rehearsal of it:
/// docs/15 §15.0 rule 1 says every unit must be identifiable as a pure black
/// silhouette, so if the game does not read at this fidelity, more art will not
/// save it.
///
/// Draw order, back to front, and each step is a decision:
///
///  1. Arena floor and walls — stage, never noise.
///  2. Telegraphs — under the units they belong to, so a body never hides the
///     warning it is about to act on.
///  3. Hazards, then entities.
///  4. **Windlines, additive, above the units.** Where two trails overlap the
///     crossing brightens, which is the player's first cue that a lattice is
///     forming. Putting them underneath would hide exactly the intersections
///     the game is teaching.
///  5. Bursts and particles.
///  6. Draw arc and Momentum chevrons — player state, always legible.
///  7. Damage numbers.
class WorldPainter {
  WorldPainter({
    required this.world,
    required this.director,
    GameCamera? camera,
  })  : camera = camera ?? GameCamera(shake: director.shake),
        mesh = WindlineMesh(),
        particleMesh = ParticleMesh();

  final SimWorld world;
  final FeedbackDirector director;

  /// Owns the letterbox transform and the shake. See [GameCamera].
  final GameCamera camera;

  /// The static floor and walls, recorded once per room.
  final ArenaLayer arenaLayer = ArenaLayer();

  final WindlineMesh mesh;
  final ParticleMesh particleMesh;

  /// The active graphics tier. Everything that scales reads from here.
  QualityTier quality = QualityTier.high;

  // Reused paints. A `Paint` per shape per frame is the kind of allocation that
  // shows up as periodic jank rather than as a slow frame.
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _additive = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;

  /// World units to logical pixels for the last frame painted.
  double get scale => camera.scale;

  void paint(Canvas canvas, Size size) {
    camera
      ..quality = quality
      ..resize(size)
      ..apply(canvas);

    arenaLayer.render(canvas, world.arena, quality);
    _paintTelegraphs(canvas);
    _paintHazards(canvas);
    _paintEntities(canvas);

    mesh
      ..rebuild(world.windlines, world.elapsedSeconds, world.windlineDuration)
      ..render(canvas);

    _paintBursts(canvas);

    particleMesh
      ..rebuild(director.particles, density: quality.particleDensity)
      ..render(canvas);

    _paintPlayerState(canvas);

    canvas.restore();

    // Damage numbers are drawn outside the world transform so their glyphs are
    // never scaled by the camera — text that grows with a zoom punch is
    // unreadable at exactly the moment it matters.
    _paintDamageNumbers(canvas);
  }

  void dispose() => arenaLayer.dispose();

  // ── Telegraphs ────────────────────────────────────────────────────────────

  /// Amber means "about to happen"; crimson means "lethal now". A two-word
  /// vocabulary, never violated (docs/15 §15.0 rule 5).
  void _paintTelegraphs(Canvas canvas) {
    final TelegraphStore telegraphs = world.telegraphs;
    final double now = world.elapsedSeconds;

    for (int i = 0; i < telegraphs.capacity; i++) {
      if (!telegraphs.isAlive(i)) continue;

      final bool lethal = telegraphs.severityAt(i) == TelegraphSeverity.lethal;
      final int argb = lethal ? FeelPalette.danger : FeelPalette.warn;
      final double progress = telegraphs.progressAt(i, now);

      switch (telegraphs.shapeAt(i)) {
        case TelegraphShape.circle:
          _telegraphCircle(canvas, telegraphs, i, argb, progress, lethal);
        case TelegraphShape.line:
          _telegraphLine(canvas, telegraphs, i, argb, progress);
        case TelegraphShape.cone:
          _telegraphCone(canvas, telegraphs, i, argb, progress);
      }
    }
  }

  void _telegraphCircle(
    Canvas canvas,
    TelegraphStore t,
    int i,
    int argb,
    double progress,
    bool lethal,
  ) {
    final Offset centre = Offset(t.xAt(i), t.yAt(i));
    final double radius = t.radiusAt(i);

    // The outline states the area; the fill states the time remaining. Together
    // they answer both questions a player has about an incoming attack without
    // needing a number.
    _fill.color = Color(FeelPalette.withAlpha(argb, lethal ? 0.20 : 0.13));
    canvas.drawCircle(centre, radius, _fill);

    if (!lethal) {
      _fill.color = Color(FeelPalette.withAlpha(argb, 0.28));
      canvas.drawCircle(centre, radius * progress, _fill);
    }

    _stroke
      ..color = Color(FeelPalette.withAlpha(argb, 0.85))
      ..strokeWidth = 0.045;
    canvas.drawCircle(centre, radius, _stroke);
  }

  void _telegraphLine(
    Canvas canvas,
    TelegraphStore t,
    int i,
    int argb,
    double progress,
  ) {
    final Offset from = Offset(t.xAt(i), t.yAt(i));
    final Offset to = Offset(t.toXAt(i), t.toYAt(i));
    final double width = t.radiusAt(i);

    _stroke
      ..color = Color(FeelPalette.withAlpha(argb, 0.30))
      ..strokeWidth = width * 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, _stroke);

    // The bright leading edge sweeps down the path as the wind-up completes,
    // so the player reads *when* as well as *where*. This is the canonical
    // charge line the whole game reuses (docs/05 §5.3, Lancer).
    _stroke.color = Color(FeelPalette.withAlpha(argb, 0.95));
    canvas.drawLine(from, Offset.lerp(from, to, progress)!, _stroke);
  }

  void _telegraphCone(
    Canvas canvas,
    TelegraphStore t,
    int i,
    int argb,
    double progress,
  ) {
    final double x = t.xAt(i);
    final double y = t.yAt(i);
    final double range = t.radiusAt(i);
    final double half = t.halfAngleAt(i);
    final double facing = t.angleAt(i);

    final Rect bounds = Rect.fromCircle(center: Offset(x, y), radius: range);
    final Path path = Path()
      ..moveTo(x, y)
      ..arcTo(bounds, facing - half, half * 2, false)
      ..close();

    _fill.color = Color(FeelPalette.withAlpha(argb, 0.14 + 0.20 * progress));
    canvas.drawPath(path, _fill);

    _stroke
      ..color = Color(FeelPalette.withAlpha(argb, 0.85))
      ..strokeWidth = 0.04;
    canvas.drawPath(path, _stroke);
  }

  // ── Hazards ───────────────────────────────────────────────────────────────

  void _paintHazards(Canvas canvas) {
    final HazardStore hazards = world.hazards;

    for (int i = 0; i < hazards.capacity; i++) {
      if (!hazards.isAlive(i)) continue;

      switch (hazards.kindAt(i)) {
        case HazardKind.puddle:
          _fill.color = Color(FeelPalette.withAlpha(FeelPalette.danger, 0.22));
          canvas.drawCircle(
            Offset(hazards.x[i], hazards.y[i]),
            hazards.radius[i],
            _fill,
          );
        case HazardKind.bolt:
          _additive.color =
              Color(FeelPalette.withAlpha(FeelPalette.warn, 0.95));
          canvas.drawCircle(
            Offset(hazards.x[i], hazards.y[i]),
            hazards.radius[i],
            _additive,
          );
        case HazardKind.shell:
          // Lifted along its arc by the flight progress, so the shell reads as
          // airborne rather than as sliding along the floor toward its ring.
          final double t = hazards.progressAt(i);
          final double lift = 1.1 * math.sin(t * math.pi);
          _additive.color = Color(FeelPalette.withAlpha(FeelPalette.warn, 0.9));
          canvas.drawCircle(
            Offset(hazards.x[i], hazards.y[i] - lift),
            0.16,
            _additive,
          );
      }
    }
  }

  // ── Entities ──────────────────────────────────────────────────────────────

  void _paintEntities(Canvas canvas) {
    final EntityStore entities = world.entities;
    final int high = entities.highWater;

    for (int i = 0; i < high; i++) {
      if (entities.alive[i] == 0) continue;

      switch (entities.kindOf(i)) {
        case EntityKind.enemy:
          _paintEnemy(canvas, i);
        case EntityKind.projectile:
          _paintArrow(canvas, i);
        case EntityKind.player:
          _paintPlayer(canvas, i);
        case EntityKind.pickup:
        case EntityKind.hazard:
          break;
      }
    }
  }

  void _paintEnemy(Canvas canvas, int i) {
    final EntityStore entities = world.entities;
    final EnemyStore enemies = world.enemies;
    final Offset at = Offset(entities.posX[i], entities.posY[i]);
    final double radius = entities.radius[i];

    final double flash = director.flashAt(i);
    final bool downed = enemies.stateOf(i) == AiState.downed;
    final bool airborne = enemies.stateOf(i) == AiState.airborne;

    int base = FeelPalette.inkDim;
    final int content = entities.contentIndex[i];
    if (content >= 0 && content < world.content.enemies.length) {
      final EnemyFamily family = world.content.enemies[content].family;
      base = FeelPalette.byFamily[family.index];
    }

    // An airborne Bounder is untargetable, so it must *look* untargetable —
    // otherwise the player reads their auto-aim refusing to lock as a bug.
    final double bodyAlpha = airborne ? 0.45 : (downed ? 0.35 : 1.0);

    _fill.color = Color.lerp(
      Color(FeelPalette.withAlpha(base, bodyAlpha)),
      const Color(FeelPalette.whiteHot),
      flash,
    )!;
    canvas.drawCircle(at, radius, _fill);

    // Heavy dark outline. docs/15 §15.0 rule 1: silhouette first.
    _stroke
      ..color = const Color(0xCC080B12)
      ..strokeWidth = 0.055;
    canvas.drawCircle(at, radius, _stroke);

    _paintPlate(canvas, i, at, radius);
    _paintShield(canvas, i, at, radius);
    _paintHealthPip(canvas, i, at, radius);
  }

  /// The frontal plate, drawn as a thick arc across the enemy's facing.
  ///
  /// docs/05 §5.2 calls the plate being *a different colour from the body* the
  /// single most important readability decision on the Husk — the whole enemy
  /// is a directional puzzle, and a player who cannot see which way the armour
  /// faces cannot solve it.
  void _paintPlate(Canvas canvas, int i, Offset at, double radius) {
    if (!world.enemies.isPlated(i)) return;

    final double half = world.enemies.plateHalfArc[i];
    if (half <= 0) return;

    final double facing = world.entities.facing[i];
    _stroke
      ..color = const Color(0xF2C9D6EE)
      ..strokeWidth = 0.11
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: at, radius: radius + 0.06),
      facing - half,
      half * 2,
      false,
      _stroke,
    );
  }

  /// A Weaver's shield. The tether itself is drawn from the Weaver's side so
  /// the bright cyan line points at the answer (docs/05 §5.5).
  void _paintShield(Canvas canvas, int i, Offset at, double radius) {
    if (world.enemies.shield[i] <= 0) return;

    _stroke
      ..color = Color(FeelPalette.withAlpha(FeelPalette.accent, 0.75))
      ..strokeWidth = 0.05;
    canvas.drawCircle(at, radius + 0.14, _stroke);

    final int source = world.enemies.shieldedBy[i];
    if (source < 0 || world.entities.alive[source] == 0) return;

    _stroke
      ..color = Color(FeelPalette.withAlpha(FeelPalette.accent, 0.45))
      ..strokeWidth = 0.03;
    canvas.drawLine(
      at,
      Offset(world.entities.posX[source], world.entities.posY[source]),
      _stroke,
    );
  }

  void _paintHealthPip(Canvas canvas, int i, Offset at, double radius) {
    final double max = world.entities.maxHealth[i];
    if (max <= 0) return;
    final double fraction = (world.entities.health[i] / max).clamp(0.0, 1.0);
    if (fraction >= 0.999) return;

    const double width = 0.62;
    final double top = at.dy - radius - 0.22;

    _fill.color = const Color(0x99080B12);
    canvas.drawRect(
      Rect.fromLTWH(at.dx - width / 2, top, width, 0.075),
      _fill,
    );
    _fill.color = const Color(FeelPalette.danger);
    canvas.drawRect(
      Rect.fromLTWH(at.dx - width / 2, top, width * fraction, 0.075),
      _fill,
    );
  }

  void _paintArrow(Canvas canvas, int i) {
    final EntityStore entities = world.entities;
    final double stacks = world.projectiles.confluenceStacks[i].toDouble();

    // A threaded arrow is white-hot and visibly fatter. The player should be
    // able to see that *this specific shot* is carrying a bonus, in flight,
    // before it lands — that is what turns Confluence from a damage number
    // into a thing you aimed.
    final int argb = stacks > 0 ? FeelPalette.whiteHot : FeelPalette.accent;
    final double length = 0.34 + 0.06 * stacks;
    final double facing = entities.facing[i];

    final Offset head = Offset(entities.posX[i], entities.posY[i]);
    final Offset tail =
        head - Offset(math.cos(facing) * length, math.sin(facing) * length);

    _stroke
      ..color = Color(FeelPalette.withAlpha(argb, 0.95))
      ..strokeWidth = entities.radius[i] * (stacks > 0 ? 2.6 : 1.8)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, head, _stroke);
  }

  void _paintPlayer(Canvas canvas, int i) {
    final EntityStore entities = world.entities;
    final Offset at = Offset(entities.posX[i], entities.posY[i]);
    final double radius = entities.radius[i];

    _fill.color = Color.lerp(
      const Color(0xFFD8E2F3),
      const Color(FeelPalette.whiteHot),
      director.flashAt(i),
    )!;
    canvas.drawCircle(at, radius, _fill);

    _stroke
      ..color = const Color(0xEE080B12)
      ..strokeWidth = 0.06;
    canvas.drawCircle(at, radius, _stroke);

    // Facing nock, so the player can see which way they will fire when no
    // target is in range.
    final double facing = entities.facing[i];
    _stroke
      ..color = const Color(FeelPalette.accent)
      ..strokeWidth = 0.07
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      at,
      at + Offset(math.cos(facing), math.sin(facing)) * (radius + 0.18),
      _stroke,
    );
  }

  // ── VFX ───────────────────────────────────────────────────────────────────

  void _paintBursts(Canvas canvas) {
    for (int i = 0; i < director.bursts.capacity; i++) {
      if (!director.bursts.isAlive(i)) continue;

      final double a = director.bursts.alpha(i);
      final Offset at = Offset(director.bursts.x[i], director.bursts.y[i]);
      final int argb = director.bursts.colour[i];
      final int stacks = director.bursts.rank[i];

      _additive
        ..color = Color(FeelPalette.withAlpha(argb, a * 0.9))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06 + 0.03 * stacks;
      canvas.drawCircle(at, director.bursts.radius[i], _additive);

      // One concentric ring per stack. Size alone is a poor channel on a 5.5"
      // screen, so a x3 is legible as *three rings* rather than merely bigger.
      for (int s = 1; s < stacks; s++) {
        _additive.color = Color(FeelPalette.withAlpha(argb, a * 0.45 / s));
        canvas.drawCircle(
          at,
          director.bursts.radius[i] * (1.0 - 0.22 * s),
          _additive,
        );
      }

      _additive.style = PaintingStyle.fill;
    }
  }

  // Particles are drawn by [ParticleMesh] — one `drawVertices` for all of them.
  // The per-particle `drawCircle` this replaced was 512 draw calls against a
  // 7.0 ms render budget (docs/19 §19.1).

  // ── Player state: the Draw arc and Momentum chevrons ──────────────────────

  void _paintPlayerState(Canvas canvas) {
    if (!world.entities.isAlive(world.player)) return;

    final int p = world.player.index;
    final Offset at = Offset(world.entities.posX[p], world.entities.posY[p]);
    final DrawState draw = world.playerDraw;

    _paintDrawArc(canvas, at, draw);
    _paintMomentum(canvas, at, draw);
  }

  /// A thin ring around the character's feet, filling clockwise, changing
  /// colour at each tier and snapping at Tier III (docs/10 §10.6).
  ///
  /// This is the readout for half the game's core trade, so it is drawn last
  /// and never occluded.
  void _paintDrawArc(Canvas canvas, Offset at, DrawState draw) {
    final Rect bounds = Rect.fromCircle(
      center: at,
      radius: Juice.drawArcRadius,
    );

    _stroke
      ..color = const Color(0x66111725)
      ..strokeWidth = Juice.drawArcThickness
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(bounds, 0, math.pi * 2, false, _stroke);

    final int argb = switch (draw.tier) {
      DrawTier.one => FeelPalette.inkDim,
      DrawTier.two => FeelPalette.accent,
      DrawTier.three => FeelPalette.whiteHot,
    };

    // Draw-lock is the Screecher's whole contribution, so it has to be visible
    // as a *state* rather than as the arc mysteriously refusing to fill.
    final bool locked = draw.isDrawLocked;
    _stroke.color = Color(
      FeelPalette.withAlpha(locked ? FeelPalette.danger : argb, 0.95),
    );

    final double sweep = math.pi * 2 * draw.tierProgress;
    canvas.drawArc(bounds, -math.pi / 2, sweep, false, _stroke);

    if (director.tierSnap > 0) {
      final double t = director.tierSnap / Juice.tierSnapSeconds;
      _additive
        ..color = Color(
          FeelPalette.withAlpha(FeelPalette.whiteHot, t * 0.7),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = Juice.drawArcThickness * (1 + 3 * (1 - t));
      canvas.drawCircle(
        at,
        Juice.drawArcRadius + (1 - t) * 0.45,
        _additive,
      );
      _additive.style = PaintingStyle.fill;
    }
  }

  /// Up to five small marks trailing the character (docs/10 §10.6).
  ///
  /// They trail *behind the direction of travel*, so the player reads them as
  /// the speed they have built rather than as an abstract counter.
  void _paintMomentum(Canvas canvas, Offset at, DrawState draw) {
    if (draw.momentumStacks <= 0) return;

    final int p = world.player.index;
    final double vx = world.entities.velX[p];
    final double vy = world.entities.velY[p];
    final double speed = math.sqrt(vx * vx + vy * vy);
    final double angle =
        speed > 1e-6 ? math.atan2(vy, vx) : world.entities.facing[p];

    final double backX = -math.cos(angle);
    final double backY = -math.sin(angle);

    for (int s = 0; s < draw.momentumStacks; s++) {
      final double distance =
          world.entities.radius[p] + 0.22 + s * Juice.chevronTrailSpacing;
      final double alpha = 0.9 - s * 0.12;

      _additive.color = Color(
        FeelPalette.withAlpha(
          draw.isAtMaxMomentum ? FeelPalette.whiteHot : FeelPalette.accent,
          alpha,
        ),
      );
      canvas.drawCircle(
        at + Offset(backX * distance, backY * distance),
        Juice.chevronSize * (1 - s * 0.1),
        _additive,
      );
    }
  }

  // ── Damage numbers ────────────────────────────────────────────────────────

  void _paintDamageNumbers(Canvas canvas) {
    final DamageNumberPool pool = director.damageNumbers;

    for (int i = 0; i < pool.capacity; i++) {
      if (!pool.isAlive(i)) continue;

      final DamageNumberKind kind = pool.kindAt(i);
      final bool confluence = kind == DamageNumberKind.confluence;

      // Battery tier shows crits and Confluence only (docs/19 §19.4). The pool
      // still records everything, so raising the tier takes effect on the next
      // frame rather than on the next fight.
      if (quality.damageNumbers == DamageNumberPolicy.critsOnly &&
          kind == DamageNumberKind.normal) {
        continue;
      }

      final String text = confluence
          ? 'x${pool.stacks[i]} CONFLUENCE'
          : pool.value[i].round().toString();

      final Color colour = Color(
        FeelPalette.withAlpha(
          confluence ? FeelPalette.whiteHot : FeelPalette.ink,
          pool.alpha(i),
        ),
      );

      final Offset screen =
          camera.toScreen(Offset(pool.x[i], pool.y[i] - pool.rise(i)));

      // TextPainter allocates. At most 24 of these are live and the sim's
      // zero-allocation guarantee is unaffected, but Phase 7's pooling pass
      // should replace this with a glyph atlas.
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: colour,
            fontSize: confluence ? 15 : 13,
            fontWeight: confluence ? FontWeight.w800 : FontWeight.w600,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            shadows: const <Shadow>[
              Shadow(color: Color(0xCC080B12), blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(canvas, screen - Offset(painter.width / 2, 0));
      painter.dispose();
    }
  }
}
