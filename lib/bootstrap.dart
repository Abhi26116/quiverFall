import 'dart:async';
import 'dart:math' as math;

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:quiverfall/core/clock.dart';
import 'package:quiverfall/core/di/service_locator.dart';
import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/logger.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/core/routing/app_router.dart';
import 'package:quiverfall/data/local/save_codec.dart';
import 'package:quiverfall/data/local/save_migrations.dart';
import 'package:quiverfall/data/local/save_store.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/data/repositories/player_repository.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:quiverfall/services/device/device_benchmark.dart';
import 'package:quiverfall/services/device/quality_controller.dart';

/// How far bootstrap got, for error reporting.
enum BootstrapStage { core, data, services, game, loadSave }

class BootstrapFailure {
  const BootstrapFailure({required this.stage, required this.error});

  final BootstrapStage stage;
  final AppError error;
}

/// Composition root.
///
/// Four ordered phases, per docs/12-architecture.md §12.3. The order matters:
/// data must be open and migrated before services that read it, and the game
/// layer must not exist before either.
///
/// Returns a [Result] rather than throwing so `main` can render a real error
/// screen with a retry rather than a frozen splash.
Future<Result<void, BootstrapFailure>> bootstrap() async {
  final Logger logger = _registerCore();

  final Result<void, BootstrapFailure> data = await _registerData(logger);
  if (data.isErr) return data;

  _registerServices();
  _registerGame();

  return _loadSave(logger);
}

Logger _registerCore() {
  const Logger logger = ConsoleLogger();
  final Clock clock = SystemClock();

  locator
    ..registerSingleton<Logger>(logger)
    ..registerSingleton<Clock>(clock)
    ..registerSingleton<TrustedClock>(TrustedClock(clock));

  return logger;
}

Future<Result<void, BootstrapFailure>> _registerData(Logger logger) async {
  try {
    await Hive.initFlutter();
    final Box<String> box = await Hive.openBox<String>(HiveSaveStore.boxName);

    const SaveCodec codec = SaveCodec(integritySalt: _integritySalt);
    final SaveMigrator migrator = SaveMigrator(
      migrations: kSaveMigrations,
      logger: logger,
    );

    final SaveStore store = HiveSaveStore(
      box: box,
      codec: codec,
      migrator: migrator,
      logger: logger,
    );

    locator
      ..registerSingleton<SaveStore>(store)
      ..registerSingleton<PlayerRepository>(
        PlayerRepository(
          store: store,
          clock: locator<Clock>(),
          logger: logger,
        ),
      );

    return const Ok<void, BootstrapFailure>(null);
  } catch (error) {
    logger.e('Data layer failed to open', tag: 'boot', error: error);
    return Err<void, BootstrapFailure>(
      BootstrapFailure(
        stage: BootstrapStage.data,
        error: StorageError.openFailed(error),
      ),
    );
  }
}

void _registerServices() {
  final Logger logger = locator<Logger>();

  // The graphics tier is decided here, once, at boot (docs/19 §19.4). It runs
  // during the splash where nothing else needs the frame, and it is
  // deliberately a measurement rather than a device allow-list: an allow-list
  // is wrong on launch day for hardware that did not exist when it was written,
  // and says nothing about a phone that is hot or sharing the CPU.
  final BenchmarkResult benchmark = const DeviceBenchmark().run();
  logger.i('$benchmark', tag: 'device');

  locator.registerSingleton<QualityController>(
    QualityController(logger: logger)..applyBenchmark(benchmark.tier),
  );

  // Audio, ads, IAP, analytics, notifications and remote config are registered
  // here from Phase 16/17. They are deliberately absent now: ADR 0001 defers the
  // ads and Firebase packages so the iOS build stays green, and nothing in
  // Phases 1–15 may depend on them.
}

void _registerGame() {
  locator.registerSingleton<RunCoordinator>(RunCoordinator());
  locator.registerLazySingleton<AppRouter>(
    () => AppRouter(
      repository: locator<PlayerRepository>(),
      runs: locator<RunCoordinator>(),
    ),
  );
}

Future<Result<void, BootstrapFailure>> _loadSave(Logger logger) async {
  final PlayerRepository repository = locator<PlayerRepository>();

  final Result<PlayerSave, AppError> loaded = await repository.load(
    newPlayerIdFactory: _generatePlayerId,
  );

  switch (loaded) {
    case Ok<PlayerSave, AppError>():
      if (repository.lastLoadRecoveredFromBackup) {
        logger.w('Save was recovered from a backup slot', tag: 'boot');
      }
      // A run left in the save means the app died mid-descent. Phase 8 wires
      // the resume prompt; for now the snapshot is restored into the coordinator
      // so the /game guard reflects reality.
      final RunSnapshot? active = repository.save.activeRun;
      if (active != null) {
        locator<RunCoordinator>().tryResume(active);
      }
      return const Ok<void, BootstrapFailure>(null);

    case Err<PlayerSave, AppError>(error: final AppError error):
      return Err<void, BootstrapFailure>(
        BootstrapFailure(stage: BootstrapStage.loadSave, error: error),
      );
  }
}

/// Tears down every registration and disposes owned resources.
///
/// Used between tests, and by the bootstrap error screen's retry — a retry must
/// start from a clean container, or the second attempt hits
/// "already registered" on everything the first attempt managed to register.
Future<void> disposeContainer() async {
  if (locator.isRegistered<PlayerRepository>()) {
    locator<PlayerRepository>().dispose();
  }
  if (locator.isRegistered<RunCoordinator>()) {
    locator<RunCoordinator>().dispose();
  }
  await locator.reset();
}

/// Not a secret — see the note on [SaveCodec]. Present to stop casual save
/// editing, not to secure the economy.
const String _integritySalt = 'qf.v1.6f2a91c4';

String _generatePlayerId() {
  // UUID v4 shape without pulling in a dependency for one call site.
  const String hex = '0123456789abcdef';
  final math.Random rng = math.Random.secure();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < 32; i++) {
    if (i == 12) {
      buffer.write('4');
      continue;
    }
    if (i == 16) {
      buffer.write(hex[8 + rng.nextInt(4)]);
      continue;
    }
    buffer.write(hex[rng.nextInt(16)]);
  }
  final String raw = buffer.toString();
  return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-'
      '${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20)}';
}
