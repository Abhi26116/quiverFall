import 'package:quiverfall/core/routing/route_guards.dart';
import 'package:quiverfall/data/models/player_save.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:test/test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 7, 19);

  PlayerSave saveWith({
    int chapter = 1,
    int stage = 1,
    int vigor = 30,
    int accountLevel = 1,
    Map<String, StageRecord> records = const <String, StageRecord>{},
  }) {
    return PlayerSave.initial(playerId: 'p', now: now).copyWith(
      profile: PlayerProfile(accountLevel: accountLevel),
      vigor: VigorState(current: vigor, lastTickAt: now),
      campaign: CampaignState(
        currentChapter: chapter,
        currentStage: stage,
        records: records,
      ),
    );
  }

  late RunCoordinator runs;

  setUp(() => runs = RunCoordinator());
  tearDown(() => runs.dispose());

  group('bootstrap', () {
    test('every guard refuses before the save is loaded', () {
      expect(RouteGuards.chapter(null, 1), GuardRejection.bootstrapIncomplete);
      expect(RouteGuards.research(null), GuardRejection.bootstrapIncomplete);
      expect(
        RouteGuards.stage(null, const StageRef(chapter: 1, stage: 1),
            runs: runs),
        GuardRejection.bootstrapIncomplete,
      );
    });
  });

  group('chapter', () {
    test('allows chapters up to the current one', () {
      final PlayerSave save = saveWith(chapter: 5);
      expect(RouteGuards.chapter(save, 1), isNull);
      expect(RouteGuards.chapter(save, 5), isNull);
    });

    test('refuses chapters beyond progress', () {
      final PlayerSave save = saveWith(chapter: 5);
      expect(RouteGuards.chapter(save, 6), GuardRejection.chapterLocked);
    });

    test('refuses nonsense chapter numbers from a malformed deep link', () {
      expect(RouteGuards.chapter(saveWith(), 0), GuardRejection.chapterLocked);
      expect(RouteGuards.chapter(saveWith(), -3), GuardRejection.chapterLocked);
    });
  });

  group('research', () {
    test('opens at account level 9', () {
      expect(
        RouteGuards.research(saveWith(accountLevel: 8)),
        GuardRejection.accountLevelTooLow,
      );
      expect(RouteGuards.research(saveWith(accountLevel: 9)), isNull);
    });
  });

  group('Vigor — Design Law 2', () {
    test('an uncleared stage always costs zero', () {
      // The most important economic rule in the game: campaign progression can
      // never be energy-gated. See docs/02-economy.md §2.2.
      final PlayerSave save = saveWith(chapter: 3, stage: 7, vigor: 0);
      expect(
        RouteGuards.vigorCostFor(save, const StageRef(chapter: 3, stage: 7)),
        0,
      );
      expect(
        RouteGuards.stage(save, const StageRef(chapter: 3, stage: 7),
            runs: runs),
        isNull,
        reason: 'a player at 0 Vigor must still be able to push the campaign',
      );
    });

    test('a cleared stage costs 6 to re-run', () {
      final PlayerSave save = saveWith(
        chapter: 3,
        stage: 7,
        records: <String, StageRecord>{
          'c3s5': const StageRecord(clearCount: 1),
        },
      );
      expect(
        RouteGuards.vigorCostFor(save, const StageRef(chapter: 3, stage: 5)),
        6,
      );
    });

    test('a cleared boss stage costs 10', () {
      final PlayerSave save = saveWith(
        chapter: 3,
        stage: 20,
        records: <String, StageRecord>{
          'c3s20': const StageRecord(clearCount: 1),
        },
      );
      expect(
        RouteGuards.vigorCostFor(save, const StageRef(chapter: 3, stage: 20)),
        10,
      );
    });

    test('refuses a farm run when Vigor is short', () {
      final PlayerSave save = saveWith(
        chapter: 3,
        stage: 7,
        vigor: 3,
        records: <String, StageRecord>{
          'c3s5': const StageRecord(clearCount: 1),
        },
      );
      expect(
        RouteGuards.stage(save, const StageRef(chapter: 3, stage: 5),
            runs: runs),
        GuardRejection.insufficientVigor,
      );
    });
  });

  group('stage locking', () {
    test('refuses a stage beyond current progress in the current chapter', () {
      final PlayerSave save = saveWith(chapter: 3, stage: 7);
      expect(
        RouteGuards.stage(save, const StageRef(chapter: 3, stage: 8),
            runs: runs),
        GuardRejection.stageLocked,
      );
    });

    test('allows replaying an earlier stage in a completed chapter', () {
      final PlayerSave save = saveWith(chapter: 3, stage: 7);
      expect(
        RouteGuards.stage(save, const StageRef(chapter: 2, stage: 19),
            runs: runs),
        isNull,
      );
    });
  });

  group('run exclusivity', () {
    test('refuses starting a stage while a run is live', () {
      final PlayerSave save = saveWith();
      runs.tryBeginStart();
      runs.completeStart(
        RunSnapshot(
          runId: 'r1',
          seed: 1,
          stage: const StageRef(chapter: 1, stage: 1),
          heroId: 'wren',
          arrowId: 'ash_shaft',
          roomIndex: 0,
          currentHp: 100,
          startedAt: now,
        ),
      );

      expect(
        RouteGuards.stage(save, const StageRef(chapter: 1, stage: 1),
            runs: runs),
        GuardRejection.runAlreadyActive,
      );
    });

    test('/game refuses when no run is live', () {
      expect(RouteGuards.game(saveWith(), runs), GuardRejection.noActiveRun);
    });

    test('/game allows when a run is live', () {
      runs.tryBeginStart();
      runs.completeStart(
        RunSnapshot(
          runId: 'r1',
          seed: 1,
          stage: const StageRef(chapter: 1, stage: 1),
          heroId: 'wren',
          arrowId: 'ash_shaft',
          roomIndex: 0,
          currentHp: 100,
          startedAt: now,
        ),
      );
      expect(RouteGuards.game(saveWith(), runs), isNull);
    });
  });

  group('StageRef', () {
    test('computes the global index used by every balance curve', () {
      expect(const StageRef(chapter: 1, stage: 1).globalIndex, 1);
      expect(const StageRef(chapter: 1, stage: 20).globalIndex, 20);
      expect(const StageRef(chapter: 7, stage: 12).globalIndex, 132);
    });

    test('builds a stable record key', () {
      expect(const StageRef(chapter: 7, stage: 12).key, 'c7s12');
    });

    test('identifies boss stages', () {
      expect(const StageRef(chapter: 3, stage: 20).isBossStage, isTrue);
      expect(const StageRef(chapter: 3, stage: 19).isBossStage, isFalse);
    });
  });
}
