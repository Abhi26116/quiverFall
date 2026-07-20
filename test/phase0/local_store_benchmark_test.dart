@Tags(<String>['phase0'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

/// Phase 0 — local store benchmark.
///
/// Isar was the other candidate and was rejected before benchmarking: it cannot
/// build at all under AGP 8.x (isar_flutter_libs declares no namespace) and has
/// been unmaintained since 2023. This measures Hive CE against the budgets the
/// GDD actually needs, rather than against a competitor that cannot ship.
///
/// Budgets from docs/12-architecture.md §12.7:
///   - Save writes are debounced to 400 ms and must not block a frame (16.6 ms).
///   - In-run room-boundary snapshots are ~2 KB and happen mid-gameplay, so they
///     are the latency-critical case.
///   - Boot must load the full save well inside the 2.5 s splash budget.
void main() {
  late Directory tempDir;
  late Box<String> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('quiverfall_bench_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('bench');
  });

  tearDownAll(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });

  test('room-boundary snapshot write stays well under one frame', () async {
    final String snapshot = _buildRunSnapshot();
    expect(
      snapshot.length,
      lessThan(8 * 1024),
      reason: 'RunSnapshot should stay small; it is written every room.',
    );

    // Warm up so we are not measuring first-write box growth.
    for (int i = 0; i < 20; i++) {
      await box.put('warm_$i', snapshot);
    }

    const int iterations = 200;
    final Stopwatch sw = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      await box.put('snapshot', snapshot);
    }
    sw.stop();

    final double perWriteMs = sw.elapsedMicroseconds / iterations / 1000.0;
    // ignore: avoid_print
    print('Hive CE snapshot write: ${perWriteMs.toStringAsFixed(3)} ms '
        '(${snapshot.length} bytes)');

    expect(
      perWriteMs,
      lessThan(4.0),
      reason: 'A mid-run snapshot must not risk a dropped frame.',
    );
  });

  test('full PlayerSave write and read meet the boot budget', () async {
    final String save = _buildPlayerSave();
    // ignore: avoid_print
    print('PlayerSave payload: ${save.length} bytes');

    final Stopwatch write = Stopwatch()..start();
    await box.put('player_save', save);
    await box.flush();
    write.stop();

    final Stopwatch read = Stopwatch()..start();
    final String? loaded = box.get('player_save');
    read.stop();

    // ignore: avoid_print
    print('PlayerSave write: ${write.elapsedMicroseconds / 1000} ms, '
        'read: ${read.elapsedMicroseconds / 1000} ms');

    expect(loaded, isNotNull);
    expect(loaded!.length, save.length);
    expect(
      write.elapsedMilliseconds,
      lessThan(250),
      reason: 'Full save write must fit inside the 400 ms debounce window.',
    );
    expect(
      read.elapsedMilliseconds,
      lessThan(150),
      reason: 'Save load is on the critical path of the 2.5 s splash budget.',
    );
  });

  test('survives a large mature save without degrading', () async {
    // A late-game player: 240 stage records, 20 heroes, full stat blocks.
    final String save = _buildPlayerSave(stageRecords: 240, heroes: 20);
    final Stopwatch sw = Stopwatch()..start();
    await box.put('mature_save', save);
    await box.flush();
    final String? loaded = box.get('mature_save');
    sw.stop();

    // ignore: avoid_print
    print('Mature save (${save.length} bytes) round-trip: '
        '${sw.elapsedMicroseconds / 1000} ms');

    expect(loaded, isNotNull);
    expect(sw.elapsedMilliseconds, lessThan(400));
  });
}

/// Approximates the RunSnapshot from docs/13-database.md §13.7.
String _buildRunSnapshot() {
  final Random rng = Random(7);
  return jsonEncode(<String, dynamic>{
    'runId': 'run_${rng.nextInt(1 << 32)}',
    'seed': rng.nextInt(1 << 32),
    'stage': <String, int>{'chapter': 7, 'stage': 12},
    'heroId': 'iris',
    'arrowId': 'twinfang',
    'roomIndex': 5,
    'boonIds': List<String>.generate(14, (int i) => 'boon_$i'),
    'currentHp': 2410,
    'runGold': 812,
    'runMaterials': <String, int>{'ashwood': 12, 'ironhead': 5},
    'elapsedMs': 214000,
    'startedAt': DateTime.now().toIso8601String(),
    'inputTape': List<int>.generate(600, (int i) => rng.nextInt(255)),
  });
}

/// Approximates the full PlayerSave root document from docs/13-database.md.
String _buildPlayerSave({int stageRecords = 100, int heroes = 12}) {
  final Random rng = Random(11);
  return jsonEncode(<String, dynamic>{
    'schemaVersion': 1,
    'playerId': 'p_${rng.nextInt(1 << 32)}',
    'profile': <String, dynamic>{
      'accountLevel': 42,
      'equippedHeroId': 'iris',
      'equippedMarkIds': <String>['thread_ii', 'stillness', 'gale'],
    },
    'wallet': <String, dynamic>{
      'gold': 1420300,
      'gems': 6400,
      'insight': 880,
      'emberdust': 214,
      'materials': <String, int>{
        'ashwood': 240,
        'ironhead': 88,
        'skyfeather': 41,
        'prismcore': 9,
      },
      'heroShards': <String, int>{
        for (int i = 0; i < heroes; i++) 'hero_$i': rng.nextInt(400),
      },
    },
    'spire': <String, dynamic>{
      'nodeLevels': <String, int>{
        for (int i = 1; i <= 24; i++) '$i': rng.nextInt(80),
      },
    },
    'heroes': <String, dynamic>{
      for (int i = 0; i < heroes; i++)
        'hero_$i': <String, dynamic>{
          'level': rng.nextInt(48),
          'stars': rng.nextInt(6),
          'talentChoices': <String, String>{'1': 'a', '3': 'b', '5': 'a'},
        },
    },
    'campaign': <String, dynamic>{
      'records': <String, dynamic>{
        for (int i = 0; i < stageRecords; i++)
          'c${i ~/ 20 + 1}s${i % 20 + 1}': <String, dynamic>{
            'stars': rng.nextInt(4),
            'bestTimeMs': 120000 + rng.nextInt(180000),
            'clearCount': rng.nextInt(30),
            'bestConfluenceCount': rng.nextInt(90),
            'enemiesSeen': <String>['mote', 'husk', 'lancer', 'spitter'],
          },
      },
    },
    'stats': <String, dynamic>{
      'confluencesTriggered': 41822,
      'tierThreeShotsLanded': 90210,
      'deathsByEnemyId': <String, int>{
        for (int i = 0; i < 26; i++) 'enemy_$i': rng.nextInt(50),
      },
    },
  });
}
