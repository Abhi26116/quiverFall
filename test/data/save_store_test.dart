import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:quiverfall/core/errors/app_error.dart';
import 'package:quiverfall/core/logger.dart';
import 'package:quiverfall/core/result.dart';
import 'package:quiverfall/data/local/save_codec.dart';
import 'package:quiverfall/data/local/save_migrations.dart';
import 'package:quiverfall/data/local/save_store.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Box<String> box;
  late HiveSaveStore store;
  late RecordingLogger logger;

  const SaveCodec codec = SaveCodec(integritySalt: 'test-salt');
  final DateTime now = DateTime.utc(2026, 7, 19, 12);

  PlayerSave makeSave({int gold = 0, String playerId = 'p1'}) {
    return PlayerSave.initial(playerId: playerId, now: now)
        .copyWith(wallet: Wallet(gold: gold));
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qf_save_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>(HiveSaveStore.boxName);
    logger = RecordingLogger();
    store = HiveSaveStore(
      box: box,
      codec: codec,
      migrator: SaveMigrator(migrations: kSaveMigrations, logger: logger),
      logger: logger,
    );
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('round trip', () {
    test('writes and reads back an identical save', () async {
      final PlayerSave original = makeSave(gold: 12345);

      expect((await store.write(original)).isOk, isTrue);

      final Result<SaveReadResult, AppError> read = await store.read();
      expect(read.isOk, isTrue);

      final SaveReadResult result = read.valueOrNull!;
      expect(result.save, equals(original));
      expect(result.recoveredFromBackup, isFalse);
      expect(result.migratedFrom, isNull);
    });

    test('preserves nested state through the round trip', () async {
      final PlayerSave original = makeSave().copyWith(
        spire: const SpireState(
          nodeLevels: <String, int>{'1': 42, '7': 13},
          tierGatesUnlocked: <String, int>{'1': 40},
          totalGoldSpent: 998877,
        ),
        campaign: CampaignState(
          currentChapter: 7,
          currentStage: 12,
          records: <String, StageRecord>{
            'c7s11': StageRecord(
              stars: 3,
              bestTime: const Duration(minutes: 2, seconds: 14),
              clearCount: 5,
              bestConfluenceCount: 34,
              firstClearedAt: now,
              enemiesSeen: const <String>{'mote', 'longeye'},
            ),
          },
          bossesDefeated: const <String>{'cinder_choir'},
        ),
      );

      await store.write(original);
      final SaveReadResult result = (await store.read()).valueOrNull!;

      expect(result.save.spire.levelOf(1), 42);
      expect(result.save.spire.bandOf(1), 40);
      expect(result.save.campaign.records['c7s11']!.bestTime,
          const Duration(minutes: 2, seconds: 14));
      expect(result.save.campaign.records['c7s11']!.enemiesSeen,
          contains('longeye'));
      expect(result.save.campaign.totalStars, 3);
    });

    test('reports notFound when nothing has been written', () async {
      final Result<SaveReadResult, AppError> read = await store.read();
      expect(read.isErr, isTrue);
      expect(read.errorOrNull!.code, 'save_not_found');
    });
  });

  group('corruption recovery — the Phase 1 exit criterion', () {
    test('recovers from a corrupted primary slot', () async {
      // Two writes so a backup exists holding the older state.
      await store.write(makeSave(gold: 100));
      await store.write(makeSave(gold: 200));

      await store.debugCorruptPrimary();

      final Result<SaveReadResult, AppError> read = await store.read();
      expect(read.isOk, isTrue, reason: 'must fall back to a backup slot');

      final SaveReadResult result = read.valueOrNull!;
      expect(result.recoveredFromBackup, isTrue);
      // The most recent surviving backup is the gold=100 write, which was
      // demoted when gold=200 became primary.
      expect(result.save.wallet.gold, 100);
      expect(logger.hasMessageContaining('recovered from'), isTrue);
    });

    test('rejects a save whose integrity tag does not match', () async {
      await store.write(makeSave(gold: 500));

      // Tamper with the payload while leaving the tag intact — the exact shape
      // of a hand-edited save file.
      final String raw = box.get('save_primary')!;
      final Map<String, dynamic> envelope =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, dynamic> payload =
          jsonDecode(envelope['payload'] as String) as Map<String, dynamic>;
      (payload['wallet'] as Map<String, dynamic>)['gold'] = 99999999;
      envelope['payload'] = jsonEncode(payload);
      await box.put('save_primary', jsonEncode(envelope));

      final Result<SaveReadResult, AppError> read = await store.read();

      // No backup exists, so the read fails outright rather than granting the
      // edited gold.
      expect(read.isErr, isTrue);
      expect(read.errorOrNull!.code, 'save_integrity_failed');
    });

    test('falls through multiple bad slots to the last good one', () async {
      await store.write(makeSave(gold: 1));
      await store.write(makeSave(gold: 2));
      await store.write(makeSave(gold: 3));
      await store.write(makeSave(gold: 4));

      // Destroy primary and the two newest backups.
      await box.put('save_primary', 'not json at all');
      await box.put('save_backup_1', '{}');
      await box.put('save_backup_2', '{"schemaVersion":1}');

      final Result<SaveReadResult, AppError> read = await store.read();
      expect(read.isOk, isTrue);
      expect(read.valueOrNull!.recoveredFromBackup, isTrue);
      expect(read.valueOrNull!.save.wallet.gold, 1);
    });

    test('backup ring keeps the three previous saves', () async {
      for (int gold = 1; gold <= 5; gold++) {
        await store.write(makeSave(gold: gold));
      }

      Map<String, dynamic> goldOf(String key) {
        final Map<String, dynamic> envelope =
            jsonDecode(box.get(key)!) as Map<String, dynamic>;
        return jsonDecode(envelope['payload'] as String)
            as Map<String, dynamic>;
      }

      expect((goldOf('save_primary')['wallet'] as Map<String, dynamic>)['gold'],
          5);
      expect(
          (goldOf('save_backup_1')['wallet'] as Map<String, dynamic>)['gold'],
          4);
      expect(
          (goldOf('save_backup_2')['wallet'] as Map<String, dynamic>)['gold'],
          3);
      expect(
          (goldOf('save_backup_3')['wallet'] as Map<String, dynamic>)['gold'],
          2);
    });
  });

  group('migration', () {
    test('refuses a save from a newer schema instead of downgrading it',
        () async {
      // Simulate a save written by a future build.
      final String raw = codec.encode(
        makeSave(gold: 777).copyWith(schemaVersion: 99),
      );
      await box.put('save_primary', raw);

      final Result<SaveReadResult, AppError> read = await store.read();

      expect(read.isErr, isTrue);
      expect(read.errorOrNull!.code, 'migration_future_version');
    });

    test('a future-version primary does not silently revert to a backup',
        () async {
      // This is the dangerous case: a player on a newer build downgrades. If we
      // fell back to an old backup here they would lose real progress and think
      // the game ate their account.
      await store.write(makeSave(gold: 10));
      await box.put(
        'save_primary',
        codec.encode(makeSave(gold: 999).copyWith(schemaVersion: 99)),
      );

      final Result<SaveReadResult, AppError> read = await store.read();

      expect(read.isErr, isTrue);
      expect(read.errorOrNull!.code, 'migration_future_version');
    });

    test('applies a registered migration chain in order', () {
      final SaveMigrator migrator = SaveMigrator(
        migrations: <SaveMigration>[_AddField(from: 1), _AddField(from: 2)],
        logger: logger,
        targetVersion: 3,
      );

      final Result<Map<String, dynamic>, AppError> result = migrator.migrate(
        <String, dynamic>{'schemaVersion': 1},
        1,
      );

      expect(result.isOk, isTrue);
      final Map<String, dynamic> json = result.valueOrNull!;
      expect(json['schemaVersion'], 3);
      expect(json['added_at_v1'], isTrue);
      expect(json['added_at_v2'], isTrue);
    });

    test('reports a missing step rather than corrupting the save', () {
      final SaveMigrator migrator = SaveMigrator(
        migrations: <SaveMigration>[_AddField(from: 1)],
        logger: logger,
        targetVersion: 3,
      );

      final Result<Map<String, dynamic>, AppError> result = migrator.migrate(
        <String, dynamic>{'schemaVersion': 1},
        1,
      );

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.code, 'migration_missing_step');
    });

    test('reports a throwing step rather than swallowing it', () {
      final SaveMigrator migrator = SaveMigrator(
        migrations: <SaveMigration>[_Exploding(from: 1)],
        logger: logger,
        targetVersion: 2,
      );

      final Result<Map<String, dynamic>, AppError> result = migrator.migrate(
        <String, dynamic>{'schemaVersion': 1},
        1,
      );

      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.code, 'migration_step_failed');
    });
  });

  group('clear', () {
    test('removes every slot', () async {
      await store.write(makeSave(gold: 1));
      await store.write(makeSave(gold: 2));

      expect((await store.clear()).isOk, isTrue);

      final Result<SaveReadResult, AppError> read = await store.read();
      expect(read.errorOrNull!.code, 'save_not_found');
    });
  });
}

class _AddField implements SaveMigration {
  _AddField({required this.from});

  @override
  final int from;

  @override
  Map<String, dynamic> apply(Map<String, dynamic> json) =>
      <String, dynamic>{...json, 'added_at_v$from': true};
}

class _Exploding implements SaveMigration {
  _Exploding({required this.from});

  @override
  final int from;

  @override
  Map<String, dynamic> apply(Map<String, dynamic> json) =>
      throw StateError('boom');
}
