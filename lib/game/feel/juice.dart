/// Every game-feel number in the project, in one file.
///
/// **This is the file Phase 6 exists to edit.** The roadmap calls Phase 6 the
/// phase the game lives or dies on, and it is not compressible; what it
/// actually consists of is sitting with a device and moving these numbers until
/// the game feels good. Scattering them across twenty render files would make
/// that job impossible, so nothing in `lib/view/` may declare a feel constant of
/// its own.
///
/// Pure Dart, deliberately. Feel is *timing*, and timing has to be testable
/// without pumping a widget tree.
///
/// Sources: docs/10-ui-ux.md §10.6 (the feedback stack), docs/15-art-direction.md
/// §15.0 (what may be coloured), docs/16-audio-direction.md §16.6 (haptics).
abstract final class Juice {
  // ── Hit feedback stack ────────────────────────────────────────────────────
  //
  // docs/10 §10.6 specifies all four, every time: a hit-flash on the sprite, a
  // directional impact particle, a 40 ms freeze-frame on kills only, and a
  // haptic. They are listed there as a set because they only work as one — a
  // flash without a particle reads as a rendering glitch, and a particle
  // without a flash reads as decoration.

  /// How long a struck enemy renders white-hot.
  ///
  /// Short enough to read as an impact rather than a state change. Two frames
  /// at 60 Hz is the floor at which players reliably notice it at all.
  static const double hitFlashSeconds = 0.075;

  /// The freeze-frame on a kill. **Kills only** — on every hit it becomes
  /// stutter rather than punctuation.
  static const double killFreezeSeconds = 0.040;

  /// A Confluence kill is the game's best moment, so it holds fractionally
  /// longer. Still under the threshold where a player reads it as a hitch.
  static const double confluenceFreezeSeconds = 0.070;

  /// Freeze-frames never accumulate. Ten kills in one tick is one freeze, not
  /// ten — the alternative is a room clear that locks the game for half a
  /// second.
  static const double maxFreezeSeconds = 0.090;

  // ── Screen shake ──────────────────────────────────────────────────────────
  //
  // Trauma-based, following the standard "trauma squared" model: shake is
  // proportional to the *square* of accumulated trauma, so small events barely
  // register and large ones bloom. Linear shake feels mushy because every
  // event produces a visible nudge.

  /// Maximum camera offset at full trauma, in world units. The arena is 16x9,
  /// so this is deliberately tiny — screen shake in a single-screen arena
  /// moves the whole playfield, and anything larger costs the player their
  /// read on enemy positions.
  static const double shakeMaxOffset = 0.22;

  /// Maximum camera roll at full trauma, in radians.
  static const double shakeMaxRoll = 0.018;

  /// Trauma decays linearly to zero over this long.
  static const double shakeDecaySeconds = 0.45;

  /// Frequency of the shake noise, in Hz. High enough to read as an impact,
  /// low enough not to alias into a shimmer at 60 Hz.
  static const double shakeFrequency = 24.0;

  // Trauma added per event. These are the numbers a playtest moves first.
  static const double traumaOnKill = 0.16;
  static const double traumaOnPlayerHit = 0.42;
  static const double traumaOnConfluence = 0.20;
  static const double traumaOnReaction = 0.30;
  static const double traumaOnDeathBlast = 0.34;

  /// Trauma is clamped so a room clear cannot stack six kills into a
  /// screen-destroying shake.
  static const double maxTrauma = 0.75;

  // ── Camera ────────────────────────────────────────────────────────────────

  /// The arena is single-screen by design (docs/14 §14.1) — no scrolling, no
  /// camera hunting, the whole fight visible at once. The camera exists only to
  /// shake and to punch.

  /// Zoom impulse on a Confluence, as a fraction of base zoom.
  static const double punchOnConfluence = 0.022;

  static const double punchOnPlayerHit = 0.030;

  /// Seconds for a zoom punch to return to rest.
  static const double punchRecoverySeconds = 0.22;

  // ── Draw and Momentum ─────────────────────────────────────────────────────

  /// The Draw arc's radius around the player's feet, in world units.
  static const double drawArcRadius = 0.62;

  static const double drawArcThickness = 0.075;

  /// How long the Tier III snap flare lasts. This is the visual half of the
  /// tier-up haptic tick — the player should be able to feel the ramp without
  /// looking, and see it without listening.
  static const double tierSnapSeconds = 0.18;

  /// Momentum chevrons trail this far behind the player, in world units.
  static const double chevronTrailSpacing = 0.26;

  static const double chevronSize = 0.13;

  // ── Windline and Confluence VFX ───────────────────────────────────────────
  //
  // The one art exception in Phase 6 (roadmap): these ship near-final, because
  // their readability *is* the mechanic being tested. ADR 0002 made them
  // reachable; this is what decides whether they are legible.

  /// Half-width of a rendered Windline segment, in world units.
  ///
  /// Note this is a *visual* width and is intentionally wider than
  /// [SimConfig.windlineHitWidth]: a line the player can see but not reliably
  /// thread would be a lie, so the drawn line is the generous one.
  static const double windlineHalfWidth = 0.055;

  /// A segment fades out over the last fraction of its life. Trails that
  /// vanish instantly read as a bug; trails that linger at full brightness
  /// make the arena unreadable within two seconds.
  static const double windlineFadeFraction = 0.45;

  /// Peak alpha of a fresh Windline.
  static const double windlineAlpha = 0.72;

  /// Radius of the Confluence burst at the crossing point, in world units.
  ///
  /// The burst is drawn *at the crossing*, which is what tells the player which
  /// line they threaded. Brightening the crossed segment itself would say it
  /// more explicitly, but the sweep does not report which segments it matched
  /// and inventing an event for it before a playtest asks for one is
  /// speculative. Candidate for Phase 6 tuning if the burst alone reads as
  /// ambient.
  static const double confluenceBurstRadius = 0.55;

  /// Growth of the burst ring per stack. x3 should look meaningfully bigger
  /// than x1 from across a 5.5" screen.
  static const double confluenceBurstPerStack = 0.30;

  static const double confluenceBurstSeconds = 0.34;

  // ── Particles ─────────────────────────────────────────────────────────────

  /// Hard ceiling on live particles. Beyond this the arena stops being
  /// readable, which is a gameplay failure before it is a performance one.
  static const int maxParticles = 512;

  static const int particlesPerHit = 5;
  static const int particlesPerKill = 12;
  static const int particlesPerConfluence = 16;

  static const double particleSpeedMin = 1.6;
  static const double particleSpeedMax = 5.2;
  static const double particleLifeMin = 0.16;
  static const double particleLifeMax = 0.42;
  static const double particleDrag = 5.0;
  static const double particleSize = 0.055;

  // ── Damage numbers ────────────────────────────────────────────────────────

  /// Hits below this fraction of the target's max HP show no number by default
  /// (docs/10 §10.6). Crits and Confluence hits always show, regardless.
  static const double damageNumberThreshold = 0.05;

  static const double damageNumberSeconds = 0.70;
  static const double damageNumberRise = 0.9;

  // ── Input ─────────────────────────────────────────────────────────────────
  //
  // docs/10 §10.6: floating joystick, appears wherever the left thumb lands in
  // the bottom-left 45 % of the screen, dead zone 8 dp, full deflection 48 dp,
  // invisible until touched.

  static const double joystickDeadZoneDp = 8.0;
  static const double joystickFullDeflectionDp = 48.0;

  /// The joystick's origin follows the thumb when it travels beyond full
  /// deflection, so a drifting thumb never runs out of stick. Without this,
  /// long strafes die halfway through.
  static const bool joystickOriginFollows = true;

  /// Fraction of the screen width and height, from the bottom-left, in which a
  /// touch is treated as a joystick rather than as a UI tap.
  static const double joystickZoneWidth = 0.45;
  static const double joystickZoneHeight = 0.55;

  /// Deflection response curve exponent. Above 1.0 gives finer control near
  /// the centre, which is what makes small repositioning nudges possible
  /// without sacrificing full-speed strafes.
  static const double joystickCurve = 1.35;
}
