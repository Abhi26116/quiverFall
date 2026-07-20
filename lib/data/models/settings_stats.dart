import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:quiverfall/data/models/converters.dart';

part 'settings_stats.freezed.dart';
part 'settings_stats.g.dart';

enum GraphicsQuality { auto, battery, balanced, high }

/// Aim assist strength. Exposed as a player-facing setting rather than a hidden
/// constant: `standard` for most, `off` for players who want the full skill
/// ceiling, `strong` as an accessibility affordance.
enum AutoAimStrength { off, light, standard, strong }

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(0.7) double musicVolume,
    @Default(1.0) double sfxVolume,
    @Default(1.0) double uiVolume,
    @Default(true) bool haptics,
    @Default(true) bool screenShake,
    @Default(true) bool damageNumbers,
    @Default(false) bool reduceMotion,
    @Default(GraphicsQuality.auto) GraphicsQuality graphicsQuality,
    @Default(60) int fpsCap,
    @Default(1.0) double particleDensity,
    @Default(AutoAimStrength.standard) AutoAimStrength autoAim,
    @Default(false) bool leftHanded,
    @Default(false) bool oneHandedMode,
    @Default(false) bool autoUltimate,
    @Default(1.0) double joystickScale,
    @Default('en') String locale,
    @Default(false) bool notificationsEnabled,

    /// Replaces the amber/crimson hue distinction with shape cues (dashed
    /// outlines vs solid hatching), since that distinction carries gameplay
    /// information. See docs/10-ui-ux.md §10.0.
    @Default(false) bool colorBlindMode,

    /// Honoured for real: this stops collection, not just transmission.
    @Default(false) bool analyticsOptOut,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, dynamic> json) =>
      _$SettingsStateFromJson(json);
}

/// Lifetime counters.
///
/// Several of these are not merely telemetry — they drive Marks
/// (docs/04-upgrades.md §4.5) and the mastery stats we show back to the player,
/// which is the cheapest durable retention mechanic available to a skill-based
/// game.
@freezed
class StatsState with _$StatsState {
  const factory StatsState({
    @Default(0) int runsStarted,
    @Default(0) int runsWon,
    @Default(0) int runsLost,
    @Default(0) int enemiesKilled,
    @Default(0) int bossesKilled,
    @Default(0) int elitesKilled,

    /// Drives Mark of the Thread, and is shown on every Victory screen.
    @Default(0) int confluencesTriggered,
    @Default(0) int maxConfluenceStack,

    /// Drives Mark of Stillness.
    @Default(0) int tierThreeShotsLanded,

    /// Drives Mark of the Gale.
    @Default(0) int maxMomentumReached,
    @DurationConverter() @Default(Duration.zero) Duration totalPlayTime,
    @Default(0) int goldEarnedLifetime,
    @Default(0) int gemsEarnedLifetime,
    @Default(<String, int>{}) Map<String, int> heroUsageSeconds,

    /// Powers the "What got you" coaching on the defeat screen.
    @Default(<String, int>{}) Map<String, int> deathsByEnemyId,
  }) = _StatsState;

  factory StatsState.fromJson(Map<String, dynamic> json) =>
      _$StatsStateFromJson(json);

  const StatsState._();

  double get winRate => runsStarted == 0 ? 0 : runsWon / runsStarted;
}
