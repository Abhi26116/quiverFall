import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/logger.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/models/player_save.dart';

/// One forward step, from schema version [from] to `from + 1`.
///
/// Migrations operate on untyped JSON, never on [PlayerSave]. A save written by
/// an older schema may not parse into today's model at all — that is the whole
/// reason a migration is needed.
abstract interface class SaveMigration {
  int get from;

  Map<String, dynamic> apply(Map<String, dynamic> json);
}

/// Applies migrations in order until a save reaches the current schema version.
///
/// Rules, from docs/13-database.md §13.12:
///
///  - Forward-only. There is no downgrade path, by design.
///  - A save from a *newer* schema is refused, never "fixed". Silently
///    downgrading a forward-versioned save is how players lose accounts after a
///    staged rollout.
///  - Every step must have a test with a real captured save from the previous
///    shipped version.
class SaveMigrator {
  SaveMigrator({
    required List<SaveMigration> migrations,
    required Logger logger,
    int targetVersion = PlayerSave.currentSchemaVersion,
  })  : _logger = logger,
        _targetVersion = targetVersion,
        _byFrom = <int, SaveMigration>{
          for (final SaveMigration m in migrations) m.from: m,
        } {
    assert(
      _byFrom.length == migrations.length,
      'Duplicate migration `from` versions: '
      '${migrations.map((SaveMigration m) => m.from).toList()}',
    );
  }

  final Map<int, SaveMigration> _byFrom;
  final Logger _logger;
  final int _targetVersion;

  int get targetVersion => _targetVersion;

  /// Brings [json] up to [targetVersion].
  Result<Map<String, dynamic>, AppError> migrate(
    Map<String, dynamic> json,
    int fromVersion,
  ) {
    if (fromVersion > _targetVersion) {
      return Err<Map<String, dynamic>, AppError>(
        MigrationError.futureVersion(
          saveVersion: fromVersion,
          supportedVersion: _targetVersion,
        ),
      );
    }

    if (fromVersion == _targetVersion) {
      return Ok<Map<String, dynamic>, AppError>(json);
    }

    Map<String, dynamic> current = json;
    for (int v = fromVersion; v < _targetVersion; v++) {
      final SaveMigration? step = _byFrom[v];
      if (step == null) {
        return Err<Map<String, dynamic>, AppError>(
          MigrationError.missingStep(from: v, to: v + 1),
        );
      }

      try {
        current = step.apply(current);
        current['schemaVersion'] = v + 1;
        _logger.i('Migrated save v$v -> v${v + 1}', tag: 'save');
      } catch (error) {
        return Err<Map<String, dynamic>, AppError>(
          MigrationError.stepFailed(from: v, to: v + 1, cause: error),
        );
      }
    }

    return Ok<Map<String, dynamic>, AppError>(current);
  }
}

/// The registered migration chain.
///
/// Empty at v1 because v1 is the first shipped schema. When schema v2 lands,
/// add a `_V1ToV2` here and a fixture test alongside it — never edit an existing
/// step, because saves in the field have already been through it.
const List<SaveMigration> kSaveMigrations = <SaveMigration>[];
