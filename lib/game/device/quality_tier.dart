/// The three graphics tiers, from docs/19-performance.md §19.4.
///
/// Assigned by the boot benchmark, overridable in Settings, and dropped one
/// step by the thermal watchdog or a memory warning. Everything the renderer
/// scales — particle density, the Windline budget, shake, parallax depth —
/// reads from here, so a tier change is one assignment rather than a sweep
/// through the render layer.
///
/// Pure Dart, because the simulation reads two of these values (the segment
/// budget and the enemy cap) and may not import Flutter.
///
/// **The Windline segment cap is a quality setting, and that is a real design
/// compromise.** A Battery-tier player has a globally smaller segment budget
/// and therefore a genuinely harder time chaining Confluence in dense builds.
/// The mitigation is that the cap scales the *global* budget while per-player
/// Windline **duration** is untouched — a solo player never notices, and it
/// only bites in the densest multishot builds. docs/19 §19.4 records this
/// explicitly so nobody later "fixes" it by capping duration instead, which
/// would break the mechanic rather than scale it.
enum QualityTier {
  /// 30 FPS target. Weak GPU, no post, minimal everything.
  battery(
    targetFps: 30,
    particleDensity: 0.25,
    windlineBudget: 320,
    shake: ShakeLevel.off,
    parallaxLayers: 1,
    damageNumbers: DamageNumberPolicy.critsOnly,
    enemyCap: 60,
  ),

  /// 60 FPS target. The default assumption for a mid-tier 2019 Android.
  balanced(
    targetFps: 60,
    particleDensity: 0.6,
    windlineBudget: 640,
    shake: ShakeLevel.light,
    parallaxLayers: 2,
    damageNumbers: DamageNumberPolicy.standard,
    enemyCap: 90,
  ),

  /// 60 FPS, or 120 where the display offers it.
  high(
    targetFps: 60,
    particleDensity: 1.0,
    windlineBudget: 1024,
    shake: ShakeLevel.full,
    parallaxLayers: 3,
    damageNumbers: DamageNumberPolicy.all,
    enemyCap: 90,
  );

  const QualityTier({
    required this.targetFps,
    required this.particleDensity,
    required this.windlineBudget,
    required this.shake,
    required this.parallaxLayers,
    required this.damageNumbers,
    required this.enemyCap,
  });

  final int targetFps;

  /// Multiplier on every particle count. Never on particle *lifetime* — short
  /// particles read as a glitch, whereas fewer particles read as a style.
  final double particleDensity;

  /// Global live-segment ceiling. See the note on this enum.
  final int windlineBudget;

  final ShakeLevel shake;

  final int parallaxLayers;

  final DamageNumberPolicy damageNumbers;

  /// Contact-capable enemies allowed on screen at once.
  final int enemyCap;

  /// Frame budget in milliseconds implied by [targetFps].
  double get frameBudgetMs => 1000.0 / targetFps;

  /// One tier down, for the thermal watchdog and memory warnings. Battery is
  /// the floor — there is nowhere below it to go, and pretending otherwise
  /// would mean a device that degrades forever.
  QualityTier get degraded => switch (this) {
        QualityTier.high => QualityTier.balanced,
        QualityTier.balanced => QualityTier.battery,
        QualityTier.battery => QualityTier.battery,
      };

  bool get isLowest => this == QualityTier.battery;
}

/// How much the camera is allowed to move.
///
/// A level rather than a boolean because "off" is an accessibility requirement
/// (Reduce Motion, docs/10 §10.0) *and* a performance tier, and those two
/// reasons want different defaults for the middle case.
enum ShakeLevel {
  off(0.0),
  light(0.55),
  full(1.0);

  const ShakeLevel(this.scale);

  /// Multiplier on trauma-derived offsets.
  final double scale;
}

enum DamageNumberPolicy {
  /// Battery tier. Crits and Confluence only — the two that carry information
  /// rather than confirmation.
  critsOnly,

  /// Hits above the 5 % noise floor, plus crits and Confluence.
  standard,

  /// Everything, for players who want the spreadsheet.
  all,
}
