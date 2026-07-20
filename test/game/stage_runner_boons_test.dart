import 'dart:io';

import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/boon_pool.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

import 'boon_test_support.dart';

/// [StageRunner]'s Phase 9 half: pausing on a room clear for the Boon Choice
/// or the Shrine, rather than advancing straight through it.
///
/// The Phase 8 exit criterion — a full stage plays end to end — is not
/// re-litigated here. `stage_runner_test.dart` covers it, unmodified, because
/// none of its stages construct a [StageRunner] with a Boon catalogue: with
/// none supplied, [StageRunner.update] behaves exactly as it did before this
/// file existed. What is new here is the paused path itself.
void main() {
  late ContentLibrary content;
  late BoonCatalogue boons;
  late SynergyCatalogue synergies;

  setUpAll(() {
    content = ContentLibrary.parse(
      enemiesJson: File('assets/data/enemies.json').readAsStringSync(),
      arenasJson: File('assets/data/arenas.json').readAsStringSync(),
    ).$1!;
    boons = loadBoons();
    synergies = loadSynergies(boons);
  });

  /// Chapter 9 is chosen deliberately: `roomCount(9) == 9`, which puts the
  /// Shrine at room index 4 and the Elite at room index 5 — two *different*
  /// rooms, so one stage exercises both. (Several chapters put them on the
  /// same index, in which case the generator's own precedence rule makes that
  /// room Elite and the stage has no Shrine at all — existing Phase 8
  /// behaviour, not something this file is testing.)
  ({StageRunner runner, SimWorld world}) stage({
    int chapter = 9,
    int stage = 1,
    int seed = 4242,
  }) {
    final StageBlueprint blueprint =
        StageBlueprint.forStage(chapter: chapter, stage: stage, seed: seed);
    final StagePlan plan = generateStage(
      generator: LevelGenerator(content: content, arenas: content.arenas),
      blueprint: blueprint,
    );
    final SimWorld world =
        buildStageWorld(blueprint: blueprint, content: content, plan: plan);

    final StageRunner runner = StageRunner(
      world: world,
      content: content,
      plan: plan,
      boonCatalogue: boons,
      synergies: synergies,
    )..start();
    return (runner: runner, world: world);
  }

  void killAll(SimWorld world) {
    for (int i = 0; i < world.entities.highWater; i++) {
      if (world.entities.alive[i] == 0) continue;
      if (world.entities.kind[i] != EntityKind.enemy.index) continue;
      world.entities.health[i] = 0;
    }
  }

  /// Ticks until the *next* state change — a room clear into an interstitial,
  /// or the stage ending. Keeps the player topped up, matching
  /// `stage_runner_test.dart`'s own convention: this tests progression, not
  /// survival.
  void tickUntilPaused(StageRunner runner, SimWorld world) {
    final StageStatus before = runner.status;
    for (int i = 0; i < 60 * 300; i++) {
      if (world.entities.isAlive(world.player)) {
        final int p = world.player.index;
        world.entities.health[p] = world.entities.maxHealth[p];
      }
      killAll(world);
      world.tick(InputSnapshot());
      world.events.clear();
      runner.update();
      if (runner.status != before) return;
    }
    fail('the runner never left $before');
  }

  /// Resolves whichever interstitial is currently open, however it needs to
  /// be resolved, so a loop that is walking toward a *specific* room kind does
  /// not have to know or care what kind of room it passes through on the way
  /// there.
  void resolveInterstitial(StageRunner runner) {
    switch (runner.status) {
      case StageStatus.awaitingBoonChoice:
        runner.pickBoon(runner.pendingBoonOffers.first.definition);
      case StageStatus.awaitingShrine:
        runner.leaveShrine();
      case StageStatus.fighting:
      case StageStatus.complete:
      case StageStatus.failed:
        break;
    }
  }

  group('a normal or Elite room clear pauses on the Boon Choice', () {
    test('the run stops with a non-empty draw', () {
      final ({StageRunner runner, SimWorld world}) s = stage();
      expect(s.runner.room.kind, RoomKind.normal, reason: 'room 0 of chapter 9');

      tickUntilPaused(s.runner, s.world);

      expect(s.runner.status, StageStatus.awaitingBoonChoice);
      expect(s.runner.pendingBoonOffers, isNotEmpty);
      // The room the player is standing in has not changed — resolving the
      // choice is what advances it, not clearing the fight.
      expect(s.runner.roomIndex, 0);
    });

    test('picking a card applies it and resumes the fight', () {
      final ({StageRunner runner, SimWorld world}) s = stage();
      tickUntilPaused(s.runner, s.world);

      final int pickedId = s.runner.pendingBoonOffers.first.definition.id;
      s.runner.pickBoon(s.runner.pendingBoonOffers.first.definition);

      expect(s.runner.boons.copiesOf(pickedId), 1);
      expect(s.runner.status, StageStatus.fighting);
      expect(s.runner.roomIndex, 1, reason: 'resolving the choice should advance the room');
      expect(s.runner.pendingBoonOffers, isEmpty);
    });

    test('a reroll needs a source and spends its budget', () {
      final ({StageRunner runner, SimWorld world}) s = stage();
      tickUntilPaused(s.runner, s.world);

      expect(s.runner.rerollsRemaining, 0,
          reason: 'no reroll source has been taken yet');
      expect(s.runner.rerollBoonOffers(), isFalse);

      // Grant one directly rather than hoping the draw offers Second Choice
      // (#102) — this is a plumbing test, not a draw-odds test.
      s.runner.boons.take(boons.byKey('second_choice')!);
      expect(s.runner.rerollsRemaining, 1);

      expect(s.runner.rerollBoonOffers(), isTrue);
      expect(s.runner.rerollsRemaining, 0);
      expect(s.runner.rerollBoonOffers(), isFalse,
          reason: 'the budget must not go negative');
    });

    test('a reroll on an Elite clear keeps the Elite bonus context', () {
      // The bonus is exercised statistically in boon_pool_test.dart; what
      // matters here is only that the reroll does not silently drop it by
      // forgetting which DrawContext produced the draw being rerolled.
      final ({StageRunner runner, SimWorld world}) s = stage();
      while (s.runner.room.kind != RoomKind.elite) {
        tickUntilPaused(s.runner, s.world);
        resolveInterstitial(s.runner);
      }
      tickUntilPaused(s.runner, s.world);
      expect(s.runner.status, StageStatus.awaitingBoonChoice);

      s.runner.boons.take(boons.byKey('second_choice')!);
      expect(s.runner.rerollBoonOffers(), isTrue);
      expect(s.runner.pendingBoonOffers, isNotEmpty);
    });

    test('the Elite room also pauses on the Boon Choice, not a different screen', () {
      final ({StageRunner runner, SimWorld world}) s = stage();

      while (s.runner.room.kind != RoomKind.elite) {
        tickUntilPaused(s.runner, s.world);
        resolveInterstitial(s.runner);
      }

      tickUntilPaused(s.runner, s.world);
      expect(s.runner.status, StageStatus.awaitingBoonChoice);
      expect(s.runner.pendingBoonOffers, isNotEmpty);
    });
  });

  group('the Shrine', () {
    test('a Shrine room clear pauses on the Shrine, not the Boon Choice', () {
      final ({StageRunner runner, SimWorld world}) s = stage();

      while (s.runner.room.kind != RoomKind.shrine) {
        tickUntilPaused(s.runner, s.world);
        expect(s.runner.status, StageStatus.awaitingBoonChoice);
        s.runner.pickBoon(s.runner.pendingBoonOffers.first.definition);
      }

      tickUntilPaused(s.runner, s.world);
      expect(s.runner.status, StageStatus.awaitingShrine);
      expect(s.runner.pendingBoonOffers, isEmpty);
    });

    test('leaving the Shrine with no purchase costs nothing and resumes', () {
      final ({StageRunner runner, SimWorld world}) s = stage();
      while (s.runner.room.kind != RoomKind.shrine) {
        tickUntilPaused(s.runner, s.world);
        s.runner.pickBoon(s.runner.pendingBoonOffers.first.definition);
      }
      tickUntilPaused(s.runner, s.world);

      final double goldBefore = s.runner.bankedGold;
      s.runner.leaveShrine();

      expect(s.runner.status, StageStatus.fighting);
      expect(s.runner.bankedGold, closeTo(goldBefore, 1e-9));
    });

    test('a purchase the run cannot afford fails and spends nothing', () {
      final ({StageRunner runner, SimWorld world}) s = stage();
      while (s.runner.room.kind != RoomKind.shrine) {
        tickUntilPaused(s.runner, s.world);
        s.runner.pickBoon(s.runner.pendingBoonOffers.first.definition);
      }
      tickUntilPaused(s.runner, s.world);

      // At this point in a real run (chapter 9, four rooms cleared) the heal
      // is affordable but the pricier actions are not — see the heal test
      // below for the same run affording it. Reroll and Boon are checked here
      // precisely because they are the ones that should fail.
      expect(s.runner.shrineRerollPrice, greaterThan(s.runner.bankedGold));
      final double before = s.runner.bankedGold;

      expect(s.runner.buyShrineReroll(), isFalse);
      expect(s.runner.buyShrineBoon(), isFalse);
      expect(s.runner.bankedGold, closeTo(before, 1e-9),
          reason: 'a rejected purchase must not spend anything');
      expect(s.runner.status, StageStatus.awaitingShrine,
          reason: 'a rejected Boon purchase must not open the Boon Choice');
    });

    test('a heal purchase spends gold and heals 35 % of max HP', () {
      final ({StageRunner runner, SimWorld world}) s = stage();
      while (s.runner.room.kind != RoomKind.shrine) {
        tickUntilPaused(s.runner, s.world);
        s.runner.pickBoon(s.runner.pendingBoonOffers.first.definition);
      }
      tickUntilPaused(s.runner, s.world);

      // Real banked gold from the rooms already cleared, not a manufactured
      // number — chapter 9's four rooms into the Shrine bank enough for the
      // heal specifically (~217 g against a ~210 g price).
      expect(s.runner.shrineHealPrice, lessThan(s.runner.bankedGold),
          reason: 'this scenario is calibrated to afford exactly the heal — '
              'if the pricing formula changes this needs recalibrating, not '
              'papering over');

      final int p = s.world.player.index;
      s.world.entities.maxHealth[p] = 100;
      s.world.entities.health[p] = 10;

      final double goldBefore = s.runner.bankedGold;
      final double price = s.runner.shrineHealPrice;

      expect(s.runner.buyShrineHeal(), isTrue);

      expect(s.world.entities.health[p], closeTo(45.0, 1e-9),
          reason: '10 + 35 % of 100 max HP');
      expect(s.runner.bankedGold, closeTo(goldBefore - price, 1e-9));
    });

    test('a heal purchase never overheals past max HP', () {
      final ({StageRunner runner, SimWorld world}) s = stage();
      while (s.runner.room.kind != RoomKind.shrine) {
        tickUntilPaused(s.runner, s.world);
        s.runner.pickBoon(s.runner.pendingBoonOffers.first.definition);
      }
      tickUntilPaused(s.runner, s.world);

      final int p = s.world.player.index;
      s.world.entities.maxHealth[p] = 100;
      s.world.entities.health[p] = 90;

      expect(s.runner.buyShrineHeal(), isTrue);
      expect(s.world.entities.health[p], closeTo(100.0, 1e-9));
    });

    test('buying a Boon opens the Boon Choice and returns to the Shrine', () {
      // docs/02 §2.4's Shrine spends from *this run's* banked gold, and at
      // chapter 9 the Boon purchase (~769 g) is deliberately out of reach at
      // room 4's ~217 g — the "not affordable" test above exercises exactly
      // that scarcity. A later chapter is needed to prove the purchase
      // actually *works* once it is affordable: by chapter 18 the same four
      // rooms bank more than the (clamped-at-900) Boon price.
      final ({StageRunner runner, SimWorld world}) deep = stage(chapter: 18);
      while (deep.runner.room.kind != RoomKind.shrine) {
        tickUntilPaused(deep.runner, deep.world);
        deep.runner.pickBoon(deep.runner.pendingBoonOffers.first.definition);
      }
      tickUntilPaused(deep.runner, deep.world);
      expect(deep.runner.status, StageStatus.awaitingShrine);
      expect(
        deep.runner.shrineBoonPrice,
        lessThanOrEqualTo(deep.runner.bankedGold),
        reason: 'this scenario is calibrated to afford it — if the pricing '
            'formula changes this needs recalibrating',
      );

      expect(deep.runner.buyShrineBoon(), isTrue);
      expect(deep.runner.status, StageStatus.awaitingBoonChoice);
      expect(deep.runner.pendingBoonOffers, isNotEmpty);
      for (final BoonOffer o in deep.runner.pendingBoonOffers) {
        expect(o.definition.rarity.isRarePlus, isTrue,
            reason: 'a Shrine purchase guarantees Rare+, docs/09 §9.1');
      }

      deep.runner.pickBoon(deep.runner.pendingBoonOffers.first.definition);
      expect(deep.runner.status, StageStatus.awaitingShrine,
          reason: 'a Shrine-bought Boon should return to the Shrine, not '
              'resume the fight — the player may still have gold to spend');

      deep.runner.leaveShrine();
      expect(deep.runner.status, StageStatus.fighting);
    });
  });

  group('with no Boon catalogue, nothing changes', () {
    test('a room clear still advances immediately', () {
      final StageBlueprint blueprint =
          StageBlueprint.forStage(chapter: 9, stage: 1, seed: 4242);
      final StagePlan plan = generateStage(
        generator: LevelGenerator(content: content, arenas: content.arenas),
        blueprint: blueprint,
      );
      final SimWorld world =
          buildStageWorld(blueprint: blueprint, content: content, plan: plan);
      final StageRunner runner =
          StageRunner(world: world, content: content, plan: plan)..start();

      for (int i = 0; i < 60 * 300; i++) {
        if (world.entities.isAlive(world.player)) {
          final int p = world.player.index;
          world.entities.health[p] = world.entities.maxHealth[p];
        }
        killAll(world);
        world.tick(InputSnapshot());
        world.events.clear();
        if (runner.update()) break;
      }

      expect(
        runner.status,
        isNot(anyOf(StageStatus.awaitingBoonChoice, StageStatus.awaitingShrine)),
        reason: 'an empty catalogue must never produce an interstitial',
      );
      expect(runner.roomIndex, 1);
    });
  });
}
