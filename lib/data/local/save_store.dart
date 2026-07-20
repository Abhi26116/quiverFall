import 'package:hive_ce/hive.dart';
import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/logger.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/local/save_codec.dart';
import 'package:quiverfall/data/local/save_migrations.dart';
import 'package:quiverfall/data/models/player_save.dart';

/// Outcome of a successful read, including whether it needed rescuing.
class SaveReadResult {
  const SaveReadResult({
    required this.save,
    required this.recoveredFromBackup,
    required this.migratedFrom,
  });

  final PlayerSave save;

  /// True when the primary slot failed and a backup was used instead. Reported
  /// to analytics as `save_recovered` so we can see this happening in the field
  /// rather than hearing about it in reviews.
  final bool recoveredFromBackup;

  /// Non-null when a migration ran, carrying the version we came from.
  final int? migratedFrom;
}

/// Persistence port for the player save.
///
/// An interface so tests, the headless balance harness, and the eventual cloud
/// backup can all substitute an implementation.
abstract interface class SaveStore {
  Future<Result<SaveReadResult, AppError>> read();

  Future<Result<void, AppError>> write(PlayerSave save);

  Future<Result<void, AppError>> clear();

  Future<void> flush();
}

/// Hive-backed store with three rotating backup slots.
///
/// Write strategy: the current primary is demoted through the backup ring
/// *before* the new primary is written. So at any instant the previous three
/// good saves survive, and a crash mid-write costs at most the newest state.
///
/// Read strategy: try primary, then backups newest-first. Any slot that fails
/// to decode or fails its integrity check is skipped rather than trusted. This
/// is what makes the "survives a corrupted primary" exit criterion true rather
/// than aspirational.
class HiveSaveStore implements SaveStore {
  HiveSaveStore({
    required Box<String> box,
    required SaveCodec codec,
    required SaveMigrator migrator,
    required Logger logger,
  })  : _box = box,
        _codec = codec,
        _migrator = migrator,
        _logger = logger;

  static const String boxName = 'quiverfall_save';
  static const String _primaryKey = 'save_primary';
  static const List<String> _backupKeys = <String>[
    'save_backup_1',
    'save_backup_2',
    'save_backup_3',
  ];

  final Box<String> _box;
  final SaveCodec _codec;
  final SaveMigrator _migrator;
  final Logger _logger;

  @override
  Future<Result<SaveReadResult, AppError>> read() async {
    final List<String> slots = <String>[_primaryKey, ..._backupKeys];

    AppError? lastError;
    for (int i = 0; i < slots.length; i++) {
      final String? raw = _box.get(slots[i]);
      if (raw == null) continue;

      final Result<SaveReadResult, AppError> attempt = _decodeSlot(raw);
      switch (attempt) {
        case Ok<SaveReadResult, AppError>(value: final SaveReadResult result):
          if (i > 0) {
            _logger.w(
              'Primary save unusable; recovered from ${slots[i]}',
              tag: 'save',
              error: lastError,
            );
          }
          return Ok<SaveReadResult, AppError>(
            SaveReadResult(
              save: result.save,
              recoveredFromBackup: i > 0,
              migratedFrom: result.migratedFrom,
            ),
          );
        case Err<SaveReadResult, AppError>(error: final AppError error):
          // A save from a future schema is not corruption — it is a real save
          // we must not touch. Stop immediately rather than falling back to an
          // older backup and silently reverting the player's progress.
          if (error is MigrationError &&
              error.code == 'migration_future_version') {
            return Err<SaveReadResult, AppError>(error);
          }
          lastError = error;
          _logger.w('Save slot ${slots[i]} unusable',
              tag: 'save', error: error);
      }
    }

    if (lastError != null) {
      return Err<SaveReadResult, AppError>(lastError);
    }
    return const Err<SaveReadResult, AppError>(SaveError.notFound());
  }

  Result<SaveReadResult, AppError> _decodeSlot(String raw) {
    final Result<int, AppError> version = _codec.peekVersion(raw);
    if (version case Err<int, AppError>(error: final AppError e)) {
      return Err<SaveReadResult, AppError>(e);
    }
    final int fromVersion = version.valueOrNull!;

    if (fromVersion > _migrator.targetVersion) {
      return Err<SaveReadResult, AppError>(
        MigrationError.futureVersion(
          saveVersion: fromVersion,
          supportedVersion: _migrator.targetVersion,
        ),
      );
    }

    final Result<Map<String, dynamic>, AppError> decoded =
        _codec.decodeToJson(raw);
    if (decoded
        case Err<Map<String, dynamic>, AppError>(
          error: final AppError e,
        )) {
      return Err<SaveReadResult, AppError>(e);
    }

    final Result<Map<String, dynamic>, AppError> migrated =
        _migrator.migrate(decoded.valueOrNull!, fromVersion);
    if (migrated
        case Err<Map<String, dynamic>, AppError>(
          error: final AppError e,
        )) {
      return Err<SaveReadResult, AppError>(e);
    }

    final Result<PlayerSave, AppError> parsed =
        _codec.fromJson(migrated.valueOrNull!);
    return parsed.map(
      (PlayerSave save) => SaveReadResult(
        save: save,
        recoveredFromBackup: false,
        migratedFrom:
            fromVersion == _migrator.targetVersion ? null : fromVersion,
      ),
    );
  }

  @override
  Future<Result<void, AppError>> write(PlayerSave save) async {
    try {
      final String encoded = _codec.encode(save);

      // Rotate oldest-first so no slot is overwritten before it has been
      // copied forward.
      for (int i = _backupKeys.length - 1; i > 0; i--) {
        final String? older = _box.get(_backupKeys[i - 1]);
        if (older != null) {
          await _box.put(_backupKeys[i], older);
        }
      }
      final String? currentPrimary = _box.get(_primaryKey);
      if (currentPrimary != null) {
        await _box.put(_backupKeys.first, currentPrimary);
      }

      await _box.put(_primaryKey, encoded);
      return const Ok<void, AppError>(null);
    } catch (error) {
      _logger.e('Save write failed', tag: 'save', error: error);
      return Err<void, AppError>(SaveError.writeFailed(error));
    }
  }

  @override
  Future<Result<void, AppError>> clear() async {
    try {
      await _box.deleteAll(<String>[_primaryKey, ..._backupKeys]);
      return const Ok<void, AppError>(null);
    } catch (error) {
      return Err<void, AppError>(SaveError.writeFailed(error));
    }
  }

  @override
  Future<void> flush() => _box.flush();

  /// Test seam: corrupts the primary slot to prove backup recovery works.
  ///
  /// Exercised by the Phase 1 exit criterion. Kept here rather than in the test
  /// so the corruption is written through the same box the store reads from.
  Future<void> debugCorruptPrimary() => _box.put(
        _primaryKey,
        '{"schemaVersion":1,"payload":"{',
      );
}
