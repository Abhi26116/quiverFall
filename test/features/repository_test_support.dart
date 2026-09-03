import 'package:quiverfall/core/clock.dart';
import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/logger.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/local/save_store.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';

/// A [SaveStore] that never touches disk.
///
/// `read()` is never exercised by these tests — [buildTestRepository] sets
/// [PlayerRepository.saveNotifier] directly rather than calling `load()` — so
/// it fails predictably rather than returning a made-up save. `write`/`clear`
/// always succeed, so a screen's real, debounced flush after a real mutation
/// has somewhere harmless to land instead of erroring into the logger.
class FakeSaveStore implements SaveStore {
  @override
  Future<Result<SaveReadResult, AppError>> read() async =>
      const Err<SaveReadResult, AppError>(SaveError.notFound());

  @override
  Future<Result<void, AppError>> write(PlayerSave save) async =>
      const Ok<void, AppError>(null);

  @override
  Future<Result<void, AppError>> clear() async => const Ok<void, AppError>(null);

  @override
  Future<void> flush() async {}
}

/// A ready-to-use [PlayerRepository] carrying [save] — for widget tests that
/// need a screen to read and mutate a save with no real persistence
/// underneath. Mutations behave exactly like production (debounced flush to
/// [FakeSaveStore], which just discards them).
PlayerRepository buildTestRepository(PlayerSave save) {
  final PlayerRepository repository = PlayerRepository(
    store: FakeSaveStore(),
    clock: FakeClock(DateTime.utc(2026)),
    logger: const NullLogger(),
  );
  repository.saveNotifier.value = save;
  return repository;
}
