/// Simulation constants.
///
/// Every number the simulation depends on lives here or in `game/balance/`.
/// Nothing in `game/sim/systems/` may declare a magic number — the balance
/// harness needs to sweep these, and a constant buried in a system is a constant
/// nobody can tune.
///
/// **Units.** Distances are world units (u). An arena is 16 x 9 u regardless of
/// screen size, so gameplay is identical on every device and only the render
/// scale changes. Time is seconds.
abstract final class SimConfig {
  // ── Time ──────────────────────────────────────────────────────────────────

  /// Fixed simulation step. 60 Hz, always, on every device.
  ///
  /// Determinism requires this to be constant — a variable step makes the same
  /// seed and the same inputs produce different runs, which breaks replays, the
  /// balance harness, and any future server-side validation.
  /// See docs/12-architecture.md §12.4.
  static const double fixedStep = 1.0 / 60.0;

  /// Maximum catch-up ticks per rendered frame.
  ///
  /// Beyond this the simulation deliberately runs in slow motion rather than
  /// spiralling: on a struggling device, trying to catch up makes each frame
  /// slower still, which makes the deficit larger. Slow motion is survivable;
  /// a death spiral is not.
  static const int maxCatchUpTicks = 2;

  /// Longest real frame the loop will believe. A stall longer than this (app
  /// backgrounded, debugger paused) is clamped rather than simulated.
  static const double maxFrameDelta = 1.0 / 30.0;

  // ── Arena ─────────────────────────────────────────────────────────────────

  /// Single-screen arena. No scrolling, no camera hunting — the whole fight is
  /// visible at once. See docs/14-level-design.md §14.1.
  static const double arenaWidth = 16.0;
  static const double arenaHeight = 9.0;

  // ── Capacities ────────────────────────────────────────────────────────────

  /// Hard ceiling on live entities.
  ///
  /// docs/14 caps a room at 90 simultaneous entities for readability and
  /// performance; this leaves headroom for projectiles and pickups on top.
  static const int maxEntities = 512;

  /// Enemies capable of dealing contact damage. Beyond this a phone screen is
  /// unreadable regardless of frame rate.
  static const int maxContactEnemies = 24;

  // ── Windline ──────────────────────────────────────────────────────────────

  /// Hard cap on live Windline segments.
  ///
  /// A correctness bound, not just a memory one: with *The Loom* (Windlines
  /// never expire) plus a high-fire-rate hero, segments can be created faster
  /// than they retire, so an unbounded store would grow without limit. The
  /// oldest is evicted on overflow. See docs/19-performance.md §19.2.
  ///
  /// Quality tiers scale this down (320 on Battery, 640 on Balanced). The cap
  /// is global — per-player Windline *duration* is never shortened, so a solo
  /// player never notices and the cap only bites in the densest multishot
  /// builds.
  static const int maxWindlineSegments = 1024;

  /// Base Windline lifetime, before hero and Boon modifiers.
  static const double windlineDuration = 1.2;

  /// Move-speed penalty applied to an enemy crossing a live Windline. Does not
  /// stack across segments.
  static const double windlineSlow = 0.08;

  /// How far from a segment counts as a crossing, for both Confluence and the
  /// enemy slow. Widened by Boon 61 (*Wide Thread*).
  static const double windlineHitWidth = 0.14;

  /// Minimum distance an arrow flies before laying another Windline segment.
  ///
  /// Emission is per *distance*, not per tick. Per-tick emission produced ~120
  /// segments for a two-second flight, filling the 1024-segment ring in a
  /// handful of shots and pushing the on-device Confluence sweep to 1.82 ms
  /// against a 0.8 ms budget. At 0.9 u the same flight lays ~30 segments.
  ///
  /// It also makes the geometry honest: a trail is a polyline the player can
  /// see and aim through, not a dense smear of near-identical fragments.
  static const double windlineSegmentLength = 0.9;

  // ── Spatial hash ──────────────────────────────────────────────────────────

  /// Cell edge length. Chosen so the largest common query radius spans at most
  /// 2x2 cells, which keeps neighbour lookups to ~4 buckets.
  static const double cellSize = 1.5;

  static const int gridCols = 11; // ceil(16 / 1.5)
  static const int gridRows = 6; //  ceil(9 / 1.5)
  static const int cellCount = gridCols * gridRows;

  /// Maximum entities tracked per cell.
  ///
  /// Sized to hold an entire room's worth of entities in a *single* cell, which
  /// makes overflow structurally impossible at the documented caps rather than
  /// merely unlikely.
  ///
  /// This is not paranoia. Clumping is the normal case, not the pathological
  /// one: enemy AI paths toward the player, so a room's worth of enemies
  /// converging on one point is the intended behaviour of half the roster. A
  /// Phase 2 probe found 90 entities settling into 4 cells at 30-per-cell with
  /// no AI at all — two short of the original limit of 32.
  ///
  /// Overflow drops entities from neighbour queries, which presents as arrows
  /// passing through enemies and auras failing to apply: severe, intermittent,
  /// and nearly undiagnosable from a player report. The memory cost of removing
  /// the possibility is 66 cells x 96 slots x 4 bytes = ~25 KB.
  static const int maxPerCell = 96;

  // ── Player defaults ───────────────────────────────────────────────────────

  /// Base move speed. Everything in docs/05-enemies.md is expressed relative to
  /// this, so changing it rebalances every enemy at once.
  static const double playerMoveSpeed = 3.20;

  /// Radius used for movement collision and contact damage.
  static const double playerRadius = 0.35;

  // ── Input ─────────────────────────────────────────────────────────────────

  /// Joystick deflection below this is treated as no input, so a resting thumb
  /// does not cancel a Draw.
  static const double stickDeadZone = 0.15;
}
