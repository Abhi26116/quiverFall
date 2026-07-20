import 'package:quiverfall/data/models/run_snapshot.dart';
import 'package:quiverfall/features/gameplay/application/run_coordinator.dart';
import 'package:test/test.dart';

/// Regression tests for the single-run invariant.
///
/// docs/11-screen-flow.md §11.5 requires this to be backed by a single-flight
/// lock *with a regression test*, because two live sessions means two
/// simulations ticking and two sets of rewards banked.
void main() {
  final DateTime now = DateTime.utc(2026, 7, 19);

  RunSnapshot snapshot({String id = 'r1', int room = 0}) => RunSnapshot(
        runId: id,
        seed: 42,
        stage: const StageRef(chapter: 1, stage: 1),
        heroId: 'wren',
        arrowId: 'ash_shaft',
        roomIndex: room,
        currentHp: 100,
        startedAt: now,
      );

  late RunCoordinator runs;

  setUp(() => runs = RunCoordinator());
  tearDown(() => runs.dispose());

  test('starts idle', () {
    expect(runs.isRunActive, isFalse);
    expect(runs.activeRun.value, isNull);
  });

  test('a double-tap on DESCEND cannot claim the slot twice', () {
    expect(runs.tryBeginStart(), isTrue);
    expect(
      runs.tryBeginStart(),
      isFalse,
      reason: 'second tap must be refused before the route transition finishes',
    );
  });

  test('the slot is held during the start window, before a run exists', () {
    runs.tryBeginStart();
    // This is the race the lock exists for: between claiming and populating,
    // activeRun is still null but the coordinator must already report busy.
    expect(runs.activeRun.value, isNull);
    expect(runs.isRunActive, isTrue);
  });

  test('abandonStart releases the slot', () {
    runs.tryBeginStart();
    runs.abandonStart();
    expect(runs.isRunActive, isFalse);
    expect(runs.tryBeginStart(), isTrue);
  });

  test('completeStart publishes the run', () {
    runs.tryBeginStart();
    runs.completeStart(snapshot());
    expect(runs.isRunActive, isTrue);
    expect(runs.activeRun.value!.runId, 'r1');
  });

  test('a deep link cannot start a second run mid-descent', () {
    runs.tryBeginStart();
    runs.completeStart(snapshot());
    expect(runs.tryBeginStart(), isFalse);
  });

  test('endRun frees the slot for the next descent', () {
    runs.tryBeginStart();
    runs.completeStart(snapshot());
    runs.endRun();

    expect(runs.isRunActive, isFalse);
    expect(runs.activeRun.value, isNull);
    expect(runs.tryBeginStart(), isTrue);
  });

  test('updateSnapshot advances the resume point', () {
    runs.tryBeginStart();
    runs.completeStart(snapshot());
    runs.updateSnapshot(snapshot(room: 4));
    expect(runs.activeRun.value!.roomIndex, 4);
  });

  test('crash recovery resumes into an empty slot', () {
    expect(runs.tryResume(snapshot(room: 3)), isTrue);
    expect(runs.activeRun.value!.roomIndex, 3);
  });

  test('crash recovery loses the race rather than clobbering a live run', () {
    // The resume prompt racing a fresh launch. Recovery must yield, not
    // overwrite — overwriting would discard a run the player is inside.
    runs.tryBeginStart();
    runs.completeStart(snapshot(id: 'live'));

    expect(runs.tryResume(snapshot(id: 'recovered', room: 9)), isFalse);
    expect(runs.activeRun.value!.runId, 'live');
  });

  test('notifies listeners on start and end', () {
    int notifications = 0;
    runs.activeRun.addListener(() => notifications++);

    runs.tryBeginStart();
    runs.completeStart(snapshot());
    runs.endRun();

    expect(notifications, 2);
  });
}
