import 'package:meta/meta.dart';

/// Base type for every expected failure in Quiverfall.
///
/// These travel inside [Result] rather than being thrown. Each carries a stable
/// [code] so analytics can aggregate failures without depending on message text
/// (which is subject to localisation and rewording).
@immutable
sealed class AppError {
  const AppError({required this.code, required this.message, this.cause});

  /// Stable, machine-readable identifier. Never localised, never reworded.
  final String code;

  /// Developer-facing description. Not shown to players verbatim.
  final String message;

  /// The underlying error, when this wraps one.
  final Object? cause;

  @override
  String toString() => '$runtimeType($code): $message'
      '${cause != null ? ' <- $cause' : ''}';
}

/// The save file could not be read, written, or trusted.
@immutable
final class SaveError extends AppError {
  const SaveError({
    required super.code,
    required super.message,
    super.cause,
    this.recoveredFromBackup = false,
  });

  const SaveError.notFound()
      : this(code: 'save_not_found', message: 'No save exists yet.');

  const SaveError.corrupt(Object? cause)
      : this(
          code: 'save_corrupt',
          message: 'Save data could not be decoded.',
          cause: cause,
        );

  const SaveError.integrityFailed()
      : this(
          code: 'save_integrity_failed',
          message: 'Save failed its integrity check.',
        );

  const SaveError.writeFailed(Object? cause)
      : this(
          code: 'save_write_failed',
          message: 'Save could not be written.',
          cause: cause,
        );

  /// Set when a read succeeded only by falling back to a backup slot. The
  /// player keeps playing, but this is reported so we can see it happening in
  /// the field.
  final bool recoveredFromBackup;
}

/// A schema migration could not be applied.
@immutable
final class MigrationError extends AppError {
  const MigrationError({
    required super.code,
    required super.message,
    super.cause,
    required this.fromVersion,
    required this.toVersion,
  });

  const MigrationError.missingStep({
    required int from,
    required int to,
  }) : this(
          code: 'migration_missing_step',
          message: 'No migration registered from v$from to v$to.',
          fromVersion: from,
          toVersion: to,
        );

  const MigrationError.stepFailed({
    required int from,
    required int to,
    Object? cause,
  }) : this(
          code: 'migration_step_failed',
          message: 'Migration v$from -> v$to threw.',
          cause: cause,
          fromVersion: from,
          toVersion: to,
        );

  /// A save written by a newer build than the one running.
  ///
  /// We refuse to touch it. Silently "fixing" a forward-versioned save is how
  /// players lose accounts after a staged rollout or a downgrade.
  const MigrationError.futureVersion({
    required int saveVersion,
    required int supportedVersion,
  }) : this(
          code: 'migration_future_version',
          message: 'Save is v$saveVersion but this build supports '
              'v$supportedVersion. Refusing to open it.',
          fromVersion: saveVersion,
          toVersion: supportedVersion,
        );

  final int fromVersion;
  final int toVersion;
}

/// Something went wrong in the storage layer itself.
@immutable
final class StorageError extends AppError {
  const StorageError({
    required super.code,
    required super.message,
    super.cause,
  });

  const StorageError.openFailed(Object? cause)
      : this(
          code: 'storage_open_failed',
          message: 'Local store could not be opened.',
          cause: cause,
        );
}

/// A precondition for entering a screen was not met.
@immutable
final class NavigationError extends AppError {
  const NavigationError({
    required super.code,
    required super.message,
    super.cause,
  });

  const NavigationError.guardRejected(String route, String reason)
      : this(
          code: 'nav_guard_rejected',
          message: 'Route $route rejected: $reason',
        );

  const NavigationError.runAlreadyActive()
      : this(
          code: 'nav_run_already_active',
          message: 'A run is already in progress.',
        );
}

/// Rejects a crafting, refinement, affix-reroll, hero-unlock, level-up, or
/// star-up spend before it touches [Wallet], [InventoryState], or
/// [HeroState] — see `ArrowWorkshop` (`lib/game/arrows/arrow_workshop.dart`)
/// and `HeroWorkshop` (`lib/game/heroes/hero_workshop.dart`). Every
/// constructor here names the exact precondition that failed, so a UI can
/// tell "not enough gold" from "not enough materials" from "that slot is
/// locked" without parsing [message].
@immutable
final class EconomyError extends AppError {
  const EconomyError({required super.code, required super.message, super.cause});

  const EconomyError.insufficientGold({required int need, required int have})
      : this(
          code: 'economy_insufficient_gold',
          message: 'Needs $need gold, have $have.',
        );

  const EconomyError.insufficientMaterials({
    required int tier,
    required int need,
    required int have,
  }) : this(
          code: 'economy_insufficient_materials',
          message: 'Needs $need tier-$tier materials, have $have.',
        );

  const EconomyError.unknownArrow(String arrowId)
      : this(
          code: 'economy_unknown_arrow',
          message: 'No arrow definition for "$arrowId".',
        );

  const EconomyError.arrowAlreadyOwned(String arrowId)
      : this(
          code: 'economy_arrow_already_owned',
          message: 'Arrow "$arrowId" is already owned.',
        );

  const EconomyError.arrowNotOwned(String arrowId)
      : this(
          code: 'economy_arrow_not_owned',
          message: 'Arrow "$arrowId" is not owned.',
        );

  const EconomyError.maxRefined(String arrowId)
      : this(
          code: 'economy_max_refined',
          message: 'Arrow "$arrowId" is already at its highest refinement.',
        );

  const EconomyError.slotOutOfRange(int slot)
      : this(
          code: 'economy_slot_out_of_range',
          message: 'Affix slot $slot does not exist on this arrow.',
        );

  const EconomyError.slotLocked(int slot)
      : this(
          code: 'economy_slot_locked',
          message: 'Affix slot $slot is locked against reroll.',
        );

  const EconomyError.lockLimitReached()
      : this(
          code: 'economy_lock_limit_reached',
          message: 'At most 2 affix slots may be locked at once.',
        );

  const EconomyError.unknownHero(String heroId)
      : this(
          code: 'economy_unknown_hero',
          message: 'No hero definition for "$heroId".',
        );

  const EconomyError.heroAlreadyUnlocked(String heroId)
      : this(
          code: 'economy_hero_already_unlocked',
          message: 'Hero "$heroId" is already unlocked.',
        );

  const EconomyError.heroNotUnlocked(String heroId)
      : this(
          code: 'economy_hero_not_unlocked',
          message: 'Hero "$heroId" is not unlocked yet.',
        );

  const EconomyError.chapterNotReached({required String heroId, required int chapter})
      : this(
          code: 'economy_chapter_not_reached',
          message: 'Hero "$heroId" unlocks at chapter $chapter.',
        );

  const EconomyError.chapterNotCleared({required String heroId, required int chapter})
      : this(
          code: 'economy_chapter_not_cleared',
          message: 'Hero "$heroId" unlocks on clearing chapter $chapter.',
        );

  const EconomyError.insufficientShards({
    required String heroId,
    required int need,
    required int have,
  }) : this(
          code: 'economy_insufficient_shards',
          message: 'Needs $need "$heroId" shards, have $have.',
        );

  const EconomyError.heroMaxStars(String heroId)
      : this(
          code: 'economy_hero_max_stars',
          message: 'Hero "$heroId" is already at ★6.',
        );

  const EconomyError.heroLevelCapped({required String heroId, required int cap})
      : this(
          code: 'economy_hero_level_capped',
          message: 'Hero "$heroId" is at its level cap ($cap) for the '
              'current campaign progress.',
        );
}
