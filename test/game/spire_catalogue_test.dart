import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/spire/spire_catalogue.dart';
import 'package:quiverfall/game/spire/spire_definition.dart';
import 'package:test/test.dart';

import 'spire_test_support.dart';

/// docs/04-upgrades.md §4.2: 24 nodes, 4 wings. See ADR 0092.
void main() {
  late SpireCatalogue spire;

  setUpAll(() {
    spire = loadSpire();
  });

  test('has exactly 24 nodes, ids 1-24 with no gaps', () {
    expect(spire.length, 24);
    final List<int> ids = spire.all.map((n) => n.id).toList()..sort();
    expect(ids, List<int>.generate(24, (i) => i + 1));
  });

  test('every node is reachable by id, key, and archetype', () {
    for (final node in spire.all) {
      expect(spire.byId(node.id), same(node));
      expect(spire.byKey(node.key), same(node));
      expect(spire.byArchetype(node.archetype), same(node));
    }
  });

  test('wings unlock at docs/04\'s own account levels', () {
    expect(SpireWing.armory.unlockAccountLevel, 1);
    expect(SpireWing.bulwark.unlockAccountLevel, 5);
    expect(SpireWing.fletchery.unlockAccountLevel, 9);
    expect(SpireWing.sanctum.unlockAccountLevel, 14);
  });

  test('each wing has exactly 6 nodes', () {
    for (final wing in SpireWing.values) {
      final count = spire.all.where((n) => n.wing == wing).length;
      expect(count, 6, reason: '${wing.name} should have 6 nodes');
    }
  });

  test('exactly one node is the attack multiplier (Warden\'s Might)', () {
    final attackNodes =
        spire.all.where((n) => n.isAttackMultiplier).toList();
    expect(attackNodes, hasLength(1));
    expect(attackNodes.single.archetype, SpireNodeArchetype.wardensMight);
  });

  test('every implemented node\'s own L80 cap matches docs/04\'s table', () {
    // Independently recomputed per node, the same check ADR 0092's own
    // table performed — pinned here so a future data-entry typo fails the
    // suite, not just the document.
    const Map<SpireNodeArchetype, double> expectedCapAt80 = {
      SpireNodeArchetype.wardensMight: 1.60,
      SpireNodeArchetype.keenEdge: 0.28,
      SpireNodeArchetype.executioner: 1.20,
      SpireNodeArchetype.quickdraw: -0.48,
      SpireNodeArchetype.piercingStudy: 5,
      SpireNodeArchetype.elementalFocus: 1.60,
      SpireNodeArchetype.vitality: 2.00,
      SpireNodeArchetype.wardedHide: 0.36,
      SpireNodeArchetype.secondWind: 0.28,
      SpireNodeArchetype.swiftshot: 0.40,
      SpireNodeArchetype.windlineWeaving: 1.44,
      SpireNodeArchetype.confluenceStudy: 0.96,
      SpireNodeArchetype.arrowVelocity: 0.64,
      SpireNodeArchetype.wideNock: 0.24,
    };

    for (final entry in expectedCapAt80.entries) {
      final node = spire.byArchetype(entry.key)!;
      final int levels = 80 ~/ node.stepEvery;
      final double cap = node.isAttackMultiplier
          ? node.attackFractionAt(80)
          : levels * node.valuePerLevel;
      expect(cap, closeTo(entry.value, 1e-9),
          reason: '${node.name}\'s own L80 cap');
    }
  });

  test('every implemented, non-attack-multiplier node has a channel', () {
    for (final node in spire.all) {
      if (node.implemented && !node.isAttackMultiplier) {
        expect(node.channel, isNotNull, reason: node.name);
      }
    }
  });

  test('ten nodes are deferred, each with a balance note (ADR 0092)', () {
    final deferred = spire.all.where((n) => !n.implemented).toList();
    expect(deferred, hasLength(10));
    for (final node in deferred) {
      expect(node.balanceNote, isNotEmpty, reason: node.name);
    }
  });

  test('contributionAt is null below the first step threshold', () {
    final piercingStudy =
        spire.byArchetype(SpireNodeArchetype.piercingStudy)!;
    expect(piercingStudy.contributionAt(0), isNull);
    expect(piercingStudy.contributionAt(15), isNull);
    expect(piercingStudy.contributionAt(16)!.value, 1.0);
    expect(piercingStudy.contributionAt(32)!.value, 2.0);
  });

  test('contributionAt sums the whole node before composing once', () {
    // Quickdraw is multiplicative (StatChannel.drawSpeed) - the one wired
    // node where getting this wrong (compounding per level instead of
    // summing once) would silently land on the wrong number. See ADR 0092.
    final quickdraw = spire.byArchetype(SpireNodeArchetype.quickdraw)!;
    final contribution = quickdraw.contributionAt(80)!;
    expect(contribution.channel, StatChannel.drawSpeed);
    expect(contribution.value, closeTo(0.52, 1e-9),
        reason: '1 - 0.006*80, not (1-0.006)^80');
  });

  test('a deferred node\'s contributionAt is always null, at any level', () {
    final ironResolve = spire.byArchetype(SpireNodeArchetype.ironResolve)!;
    expect(ironResolve.contributionAt(1), isNull);
    expect(ironResolve.contributionAt(80), isNull);
  });
}
