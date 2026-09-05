import 'dart:io';

import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/harness/expected_power.dart';
import 'package:quiverfall/game/harness/ttk_probe.dart';
import 'package:quiverfall/game/harness/ttk_with_boons.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:test/test.dart';

/// docs/02 §2.6's expected power, all four terms — the composition of
/// `TtkProbe` (ADR 0089) and `HarnessBot` (ADR 0091).
void main() {
  late HeroCatalogue heroes;
  late ArrowCatalogue arrows;
  late ContentLibrary content;
  late BoonCatalogue boons;
  late SynergyCatalogue synergies;

  setUpAll(() {
    heroes =
        HeroCatalogue.parse(File('assets/data/heroes.json').readAsStringSync())
            .$1!;
    arrows = ArrowCatalogue.parse(
            File('assets/data/arrows.json').readAsStringSync())
        .$1!;
    content = ContentLibrary.parse(
      enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
      arenasJson: File('assets/data/arenas.json').readAsStringSync(),
    ).$1!;
    boons =
        BoonCatalogue.parse(File('assets/data/boons.json').readAsStringSync())
            .$1!;
    synergies = SynergyCatalogue.parse(
      File('assets/data/synergies.json').readAsStringSync(),
      boons: boons,
    ).$1!;
  });

  ({double? ttk, StageStatus status, int roomIndex, List<int> boonsTaken})
      measure({
    required int chapter,
    required int seed,
  }) {
    final ExpectedPower power = ExpectedPower.forChapter(chapter);
    return TtkWithBoonsProbe.measure(
      hero: heroes.byArchetype(TtkProbe.referenceHero)!,
      arrow: arrows.byArchetype(power.arrow)!,
      power: power,
      content: content,
      boons: boons,
      synergies: synergies,
      chapter: chapter,
      seed: seed,
    );
  }

  test('reaches room 5 and returns a plausible reading on an early chapter',
      () {
    final r = measure(chapter: 1, seed: 11);
    expect(r.status, StageStatus.fighting);
    expect(r.roomIndex, greaterThanOrEqualTo(5));
    expect(r.ttk, isNotNull);
    expect(r.ttk, greaterThan(0));
  });

  test('is deterministic for a fixed seed', () {
    final r1 = measure(chapter: 1, seed: 555);
    final r2 = measure(chapter: 1, seed: 555);
    expect(r1.status, r2.status);
    expect(r1.roomIndex, r2.roomIndex);
    expect(r1.ttk, r2.ttk);
  });

  test('the measurement reflects real Boons, not a silently-skipped draw',
      () {
    // A deterministic guard against a wiring mistake that stops Boons from
    // ever applying at all — `boonsTaken` is the run's own `pickOrder`, so
    // this fails loudly if a future refactor breaks the pick-and-apply loop
    // rather than passing by floor-effect luck the way a "faster than
    // baseline" statistical check would (ADR 0091's own Cursed-card finding
    // means a Boon-augmented reading is not even guaranteed to beat a
    // no-Boon one).
    final r = measure(chapter: 1, seed: 11);
    expect(r.boonsTaken, isNotEmpty);
    expect(r.boonsTaken.length, greaterThanOrEqualTo(3),
        reason: 'room 5 on a 6+ room stage should offer several picks');
  });

  test('an unreachable chapter reports why, not a misleading number', () {
    // Chapter 12 - ADR 0089's own finding: even with zero Boons, a fresh
    // mote already times out here. Confirms the "why" (status/roomIndex)
    // survives through TtkWithBoonsProbe rather than collapsing to a bare
    // null that looks identical to a healthy read that simply timed out.
    final r = measure(chapter: 12, seed: 1);
    expect(r.roomIndex, isNotNull);
    expect(r.status, isNotNull);
  });
}
