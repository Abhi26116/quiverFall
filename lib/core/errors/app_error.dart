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
