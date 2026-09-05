import 'package:quiverfall/game/marks/mark_catalogue.dart';
import 'package:quiverfall/game/marks/mark_definition.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:test/test.dart';

import 'mark_test_support.dart';

/// docs/04-upgrades.md §4.5: the 9 Marks the doc names explicitly out of
/// "25 Marks total... ...16 more". See ADR 0095.
void main() {
  late MarkCatalogue marks;

  setUpAll(() {
    marks = loadMarks();
  });

  test('has exactly the 9 named Marks, ids 1-9 with no gaps', () {
    expect(marks.length, 9);
    final List<int> ids = marks.all.map((d) => d.id).toList()..sort();
    expect(ids, List<int>.generate(9, (i) => i + 1));
  });

  test('every Mark is reachable by id, key, and archetype', () {
    for (final d in marks.all) {
      expect(marks.byId(d.id), same(d));
      expect(marks.byKey(d.key), same(d));
      expect(marks.byArchetype(d.archetype), same(d));
    }
  });

  test('6 Marks are implemented, 3 are deferred with a balance note', () {
    final implemented = marks.all.where((d) => d.implemented).toList();
    final deferred = marks.all.where((d) => !d.implemented).toList();
    expect(implemented, hasLength(6));
    expect(deferred, hasLength(3));
    for (final d in deferred) {
      expect(d.balanceNote, isNotEmpty, reason: d.name);
    }
  });

  test('Mark of the Thread II is the one Mark with two effects', () {
    final threadII = marks.byArchetype(MarkArchetype.markOfTheThreadII)!;
    expect(threadII.contribution(), hasLength(2));
    expect(threadII.contribution()[0].channel, StatChannel.confluenceDamage);
    expect(threadII.contribution()[1].channel, StatChannel.windlineDuration);
  });

  test('a deferred Mark has no contribution', () {
    final unbroken = marks.byArchetype(MarkArchetype.markOfTheUnbroken)!;
    expect(unbroken.contribution(), isEmpty);
  });

  test('Mark of Ruin\'s own value matches docs/04', () {
    final ruin = marks.byArchetype(MarkArchetype.markOfRuin)!;
    expect(ruin.channel, StatChannel.damage);
    expect(ruin.value, closeTo(0.10, 1e-9));
  });
}
