import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/systems/confluence_system.dart';
import 'package:quiverfall/game/sim/windline_store.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:test/test.dart';

void main() {
  group('segment intersection', () {
    bool hits(
      double ax0,
      double ay0,
      double ax1,
      double ay1,
      double bx0,
      double by0,
      double bx1,
      double by1, [
      double tol = 0.05,
    ]) =>
        ConfluenceSystem.segmentsIntersect(
            ax0, ay0, ax1, ay1, bx0, by0, bx1, by1, tol);

    test('detects a clean perpendicular crossing', () {
      expect(hits(0, 0, 10, 0, 5, -5, 5, 5), isTrue);
    });

    test('rejects segments that do not reach each other', () {
      expect(hits(0, 0, 4, 0, 5, -5, 5, 5), isFalse);
    });

    test('rejects a crossing that is beyond one segment', () {
      expect(hits(0, 0, 10, 0, 5, 2, 5, 8), isFalse);
    });

    test('handles parallel non-touching lines', () {
      // A pure cross-product test divides by zero here. Silently dropping this
      // case would look like "my arrow went through but nothing happened".
      expect(hits(0, 0, 10, 0, 0, 3, 10, 3), isFalse);
    });

    test('rejects collinear overlap — retracing is not threading', () {
      // Two segments along the same line are parallel, so the angle rule
      // rejects them however much they overlap. This is the rule that stops a
      // stationary player's repeated fire from self-Confluencing.
      expect(hits(0, 0, 10, 0, 5, 0, 15, 0), isFalse);
    });

    test('rejects a crossing shallower than the minimum angle', () {
      // ~15 degrees.
      expect(hits(0, 0, 10, 0, 0, -1, 10, 1.68), isFalse);
    });

    test('accepts a crossing at 30 degrees', () {
      expect(hits(0, 0, 10, 0, 2, -2, 8, 1.46), isTrue);
    });

    test('handles collinear disjoint lines', () {
      expect(hits(0, 0, 4, 0, 6, 0, 10, 0), isFalse);
    });

    test('handles a zero-length segment on the line', () {
      expect(hits(5, 0, 5, 0, 0, 0, 10, 0), isTrue);
    });

    test('handles two zero-length segments at the same point', () {
      expect(hits(5, 5, 5, 5, 5, 5, 5, 5), isTrue);
    });

    test('registers a near miss inside the tolerance', () {
      // The arrow has width. A shot passing within its own hit radius must
      // count, or the mechanic feels arbitrary.
      expect(hits(0, 0, 10, 0, 5, 0.03, 5, 4), isTrue);
      expect(hits(0, 0, 10, 0, 5, 0.30, 5, 4), isFalse);
    });

    test('detects a T-junction touching exactly at an endpoint', () {
      expect(hits(0, 0, 10, 0, 5, 0, 5, 5), isTrue);
    });
  });

  group('WindlineStore', () {
    test('rejects zero-length segments', () {
      // They can never be crossed, and admitting them would put a
      // divide-by-zero into the hottest loop in the game.
      final WindlineStore lines = WindlineStore(capacity: 8);
      expect(lines.add(
        fromX: 1, fromY: 1, toX: 1, toY: 1,
        expiresAt: 10, ownerIndex: 0, trailId: 1,
      ), -1);
      expect(lines.liveCount, 0);
    });

    test('serials increase monotonically', () {
      final WindlineStore lines = WindlineStore(capacity: 8);
      final int a = lines.add(
          fromX: 0, fromY: 0, toX: 1, toY: 0, expiresAt: 10, ownerIndex: 0, trailId: 1);
      final int b = lines.add(
          fromX: 0, fromY: 1, toX: 1, toY: 1, expiresAt: 10, ownerIndex: 0, trailId: 2);
      expect(lines.serialAt(b), greaterThan(lines.serialAt(a)));
    });

    test('evicts the oldest when full and reports it', () {
      final WindlineStore lines = WindlineStore(capacity: 4);
      for (int i = 0; i < 6; i++) {
        lines.add(
          fromX: 0, fromY: i.toDouble(), toX: 1, toY: i.toDouble(),
          expiresAt: 100, ownerIndex: 0, trailId: i,
        );
      }
      expect(lines.liveCount, 4);
      expect(lines.evictedWhileAlive, 2,
          reason: 'overflow must be visible, not silent');
    });

    test('serials stay meaningful after ring wrap-around', () {
      // A raw slot index would wrap and make "older than" wrong. This is what
      // the separate serial counter exists for.
      final WindlineStore lines = WindlineStore(capacity: 4);
      final List<int> serials = <int>[];
      for (int i = 0; i < 10; i++) {
        final int slot = lines.add(
          fromX: 0, fromY: i.toDouble(), toX: 1, toY: i.toDouble(),
          expiresAt: 100, ownerIndex: 0, trailId: i,
        );
        serials.add(lines.serialAt(slot));
      }
      for (int i = 1; i < serials.length; i++) {
        expect(serials[i], greaterThan(serials[i - 1]));
      }
    });

    test('expires by time', () {
      final WindlineStore lines = WindlineStore(capacity: 8);
      lines.add(
          fromX: 0, fromY: 0, toX: 1, toY: 0, expiresAt: 1.0, ownerIndex: 0, trailId: 1);
      expect(lines.liveCount, 1);
      lines.expire(0.9);
      expect(lines.liveCount, 1);
      lines.expire(1.0);
      expect(lines.liveCount, 0);
    });
  });

  group('Confluence stacking', () {
    test('bonus values match the design', () {
      expect(ConfluenceTuning.bonusFor(0), 0.00);
      expect(ConfluenceTuning.bonusFor(1), 0.40);
      expect(ConfluenceTuning.bonusFor(2), 0.90);
      expect(ConfluenceTuning.bonusFor(3), 1.60);
      expect(ConfluenceTuning.bonusFor(4), 2.30);
      expect(ConfluenceTuning.bonusFor(5), 3.20);
    });

    test('escalation is super-linear, so a third thread feels like a payoff',
        () {
      final double first = ConfluenceTuning.bonusFor(1);
      final double second = ConfluenceTuning.bonusFor(2) - first;
      final double third =
          ConfluenceTuning.bonusFor(3) - ConfluenceTuning.bonusFor(2);
      expect(second, greaterThan(first));
      expect(third, greaterThan(second));
    });

    test('an arrow cannot Confluence with a line newer than itself', () {
      // Without the age filter an arrow triggers on the trail it is laying,
      // handing every single shot a free stack.
      final WindlineStore lines = WindlineStore(capacity: 8);
      lines.add(
          fromX: 5, fromY: -5, toX: 5, toY: 5, expiresAt: 100, ownerIndex: 0, trailId: 1);

      final ConfluenceResult r = ConfluenceSystem.sweep(
        lines: lines,
        fromX: 0, fromY: 0, toX: 10, toY: 0,
        arrowSerial: 1, // same age as the line
        ownerIndex: 0,
        hitWidth: 0.14,
        maxStacks: 3,
        alreadyCrossed: <int>[],
        crossedBase: 0,
        crossedCount: 0,
      );

      expect(r.stacks, 0);
    });

    test('an enemy trail never grants the player a stack', () {
      final WindlineStore lines = WindlineStore(capacity: 8);
      lines.add(
          fromX: 5, fromY: -5, toX: 5, toY: 5, expiresAt: 100, ownerIndex: 7, trailId: 1);

      final ConfluenceResult r = ConfluenceSystem.sweep(
        lines: lines,
        fromX: 0, fromY: 0, toX: 10, toY: 0,
        arrowSerial: 99,
        ownerIndex: 0,
        hitWidth: 0.14,
        maxStacks: 3,
        alreadyCrossed: <int>[],
        crossedBase: 0,
        crossedCount: 0,
      );

      expect(r.stacks, 0);
    });

    test('accumulates one stack per distinct line crossed', () {
      final WindlineStore lines = WindlineStore(capacity: 16);
      for (int i = 0; i < 4; i++) {
        lines.add(
          fromX: 2.0 + i * 2, fromY: -5, toX: 2.0 + i * 2, toY: 5,
          expiresAt: 100, ownerIndex: 0, trailId: i,
        );
      }

      final ConfluenceResult r = ConfluenceSystem.sweep(
        lines: lines,
        fromX: 0, fromY: 0, toX: 10, toY: 0,
        arrowSerial: 999,
        ownerIndex: 0,
        hitWidth: 0.14,
        maxStacks: 3,
        alreadyCrossed: <int>[],
        crossedBase: 0,
        crossedCount: 0,
      );

      expect(r.stacks, 3, reason: 'capped at maxStacks');
    });

    test('a line already crossed cannot grant a second stack', () {
      // An arrow travelling nearly parallel to a line would otherwise farm
      // stacks from a single thread across consecutive ticks.
      final WindlineStore lines = WindlineStore(capacity: 8);
      final int slot = lines.add(
          fromX: 5, fromY: -5, toX: 5, toY: 5, expiresAt: 100, ownerIndex: 0, trailId: 1);
      final int serial = lines.serialAt(slot);

      final ConfluenceResult r = ConfluenceSystem.sweep(
        lines: lines,
        fromX: 0, fromY: 0, toX: 10, toY: 0,
        arrowSerial: 999,
        ownerIndex: 0,
        hitWidth: 0.14,
        maxStacks: 3,
        alreadyCrossed: <int>[serial],
        crossedBase: 0,
        crossedCount: 1,
      );

      expect(r.stacks, 0);
    });

    test('collects distinct elements from crossed lines', () {
      final WindlineStore lines = WindlineStore(capacity: 8);
      lines.add(
        fromX: 3, fromY: -5, toX: 3, toY: 5, expiresAt: 100, ownerIndex: 0, trailId: 1,
        elementIndex: SimElement.ember.index,
      );
      lines.add(
        fromX: 6, fromY: -5, toX: 6, toY: 5, expiresAt: 100, ownerIndex: 0, trailId: 2,
        elementIndex: SimElement.frost.index,
      );

      final ConfluenceResult r = ConfluenceSystem.sweep(
        lines: lines,
        fromX: 0, fromY: 0, toX: 10, toY: 0,
        arrowSerial: 999,
        ownerIndex: 0,
        hitWidth: 0.14,
        maxStacks: 3,
        alreadyCrossed: <int>[],
        crossedBase: 0,
        crossedCount: 0,
      );

      expect(r.stacks, 2);
      expect(r.elements.length, 2);
      expect(
        Reactions.between(SimElement.ember, SimElement.frost),
        Reaction.steamburst,
      );
    });
  });

  group('reaction matrix', () {
    test('every distinct pair produces a reaction', () {
      final Set<Reaction> seen = <Reaction>{};
      for (final SimElement a in SimElement.values) {
        for (final SimElement b in SimElement.values) {
          final Reaction? r = Reactions.between(a, b);
          if (a == b) {
            expect(r, isNull, reason: '$a with itself must not react');
          } else {
            expect(r, isNotNull, reason: '$a + $b has no reaction');
            seen.add(r!);
          }
        }
      }
      expect(seen.length, 6, reason: 'six pairwise reactions');
    });

    test('is symmetric', () {
      for (final SimElement a in SimElement.values) {
        for (final SimElement b in SimElement.values) {
          expect(Reactions.between(a, b), Reactions.between(b, a));
        }
      }
    });

    test('three or more elements collapse to Prismbreak', () {
      expect(Reactions.forElementCount(2), isNull);
      expect(Reactions.forElementCount(3), Reaction.prismbreak);
      expect(Reactions.forElementCount(4), Reaction.prismbreak);
    });

    test('Prismbreak is the strongest reaction', () {
      for (final Reaction r in Reaction.values) {
        if (r == Reaction.prismbreak) continue;
        expect(Reaction.prismbreak.damageMultiplier,
            greaterThan(r.damageMultiplier));
      }
    });

    test('elemental scaling is split two and two', () {
      // Two scale off target max HP (boss-killers, weak vs fodder) and two off
      // player attack. That split is what keeps element choice meaningful late.
      final int offHp = SimElement.values
          .where((SimElement e) => e.scalesOffTargetHp)
          .length;
      expect(offHp, 2);
    });
  });

  group('end to end in a live world', () {
    test('arrows lay Windlines as they fly', () {
      final SimWorld world = SimWorld(seed: 5);
      world.spawnPlayer(2.0, 4.5);
      world.spawnAt(EntityKind.enemy, 14.0, 4.5, radius: 0.3, health: 1e9);

      final InputSnapshot idle = InputSnapshot();
      for (int i = 0; i < 60; i++) {
        world.tick(idle);
      }

      expect(world.windlines.liveCount, greaterThan(0));
    });

    test('Windlines expire on schedule', () {
      final SimWorld world = SimWorld(seed: 5)..windlineDuration = 0.3;
      world.spawnPlayer(2.0, 4.5);
      world.spawnAt(EntityKind.enemy, 14.0, 4.5, radius: 0.3, health: 1e9);

      final InputSnapshot idle = InputSnapshot();
      for (int i = 0; i < 30; i++) {
        world.tick(idle);
      }
      final int peak = world.windlines.liveCount;
      expect(peak, greaterThan(0));

      // Stop producing, then let them age out.
      //
      // Turning off auto-fire stops new *arrows*, not the ones already in the
      // air — and an arrow keeps laying trail for as long as it flies. The wait
      // therefore has to cover the arrow lifetime as well as the Windline
      // duration, or the test is really asserting that arrows despawn quickly.
      world.autoFire = false;
      final int settle =
          ((world.arrowLifetime + world.windlineDuration) * 60).ceil() + 10;
      for (int i = 0; i < settle; i++) {
        world.tick(idle);
      }
      expect(world.windlines.liveCount, 0);
    });

    test('an arrow crossing an existing trail triggers Confluence', () {
      // End-to-end wiring check with geometry that genuinely crosses.
      //
      // Note what this does NOT claim: that ordinary play produces crossings.
      // A probe of the current base kit (single-target auto-aim, trails
      // radiating from one origin) found a 0% natural trigger rate — arrows
      // fan outward and rarely meet at the required angle. Making the mechanic
      // reachable is a Phase 6 problem, and Phase 6 is the gate that exists to
      // answer it. See the note in docs/decisions/0002-confluence-reachability.md.
      final SimWorld world = SimWorld(seed: 11)..playerAttack = 1;
      world.spawnPlayer(8.0, 4.5);
      world.spawnAt(EntityKind.enemy, 15.0, 4.5, radius: 0.3, health: 1e9);

      // Lay a trail perpendicular to the firing line, older than any arrow.
      world.windlines.add(
        fromX: 11.0,
        fromY: 1.0,
        toX: 11.0,
        toY: 8.0,
        expiresAt: 1e9,
        ownerIndex: 0,
        trailId: 99999,
      );

      final InputSnapshot idle = InputSnapshot();
      for (int i = 0; i < 120; i++) {
        world.tick(idle);
      }

      expect(
        world.events.countOf(SimEventType.confluenceTriggered),
        greaterThan(0),
        reason: 'an arrow crossing a live trail at 90 degrees must register',
      );
    });

    /// The same 90-degree crossing above, with an Ember arrow through a
    /// trail of [trailElementIndex] (or no element at all, when null).
    double firstDamageDealt(int? trailElementIndex) {
      final SimWorld world = SimWorld(seed: 11)
        ..playerAttack = 10
        ..arrowElement = SimElement.ember;
      world.spawnPlayer(8.0, 4.5);
      world.spawnAt(EntityKind.enemy, 15.0, 4.5, radius: 0.3, health: 1e9);

      world.windlines.add(
        fromX: 11.0,
        fromY: 1.0,
        toX: 11.0,
        toY: 8.0,
        expiresAt: 1e9,
        ownerIndex: 0,
        trailId: 99999,
        elementIndex: trailElementIndex ?? -1,
      );

      final InputSnapshot idle = InputSnapshot();
      for (int i = 0; i < 120; i++) {
        world.tick(idle);
        for (int e = 0; e < world.events.count; e++) {
          if (world.events.typeAt(e) == SimEventType.damageDealt) {
            return world.events.valueAAt(e);
          }
        }
      }
      throw StateError('no damage landed within the tick budget');
    }

    test(
        'an Ember arrow crossing a Frost trail resolves to Steamburst — the '
        'reaction the sim never actually produced before now', () {
      final SimWorld world = SimWorld(seed: 11)
        ..playerAttack = 10
        ..arrowElement = SimElement.ember;
      world.spawnPlayer(8.0, 4.5);
      world.spawnAt(EntityKind.enemy, 15.0, 4.5, radius: 0.3, health: 1e9);
      world.windlines.add(
        fromX: 11.0,
        fromY: 1.0,
        toX: 11.0,
        toY: 8.0,
        expiresAt: 1e9,
        ownerIndex: 0,
        trailId: 99999,
        elementIndex: SimElement.frost.index,
      );

      final InputSnapshot idle = InputSnapshot();
      for (int i = 0; i < 120; i++) {
        world.tick(idle);
      }

      expect(
        world.events.countOf(SimEventType.reactionTriggered),
        greaterThan(0),
        reason: 'Ember through a Frost trail must resolve to Steamburst',
      );
    });

    test("a triggered reaction multiplies that hit's own damage", () {
      // Same crossing, same Confluence stack either way (one line crossed) —
      // the only variable is whether the two elements actually react, which
      // isolates the reaction's own contribution from Confluence's.
      final double sameElement = firstDamageDealt(SimElement.ember.index);
      final double differentElement = firstDamageDealt(SimElement.frost.index);

      // Steamburst (Ember+Frost) is a flat 1.80x on the triggering hit.
      expect(differentElement / sameElement, closeTo(1.80, 0.05));
    });

    test('no trail element at all means no reaction, same as matching one',
        () {
      final double noElement = firstDamageDealt(null);
      final double sameElement = firstDamageDealt(SimElement.ember.index);
      expect(noElement / sameElement, closeTo(1.0, 0.02));
    });

    test('room clear wipes every line', () {
      final SimWorld world = SimWorld(seed: 5);
      world.spawnPlayer(2.0, 4.5);
      world.spawnAt(EntityKind.enemy, 14.0, 4.5, radius: 0.3, health: 1e9);

      final InputSnapshot idle = InputSnapshot();
      for (int i = 0; i < 60; i++) {
        world.tick(idle);
      }
      expect(world.windlines.liveCount, greaterThan(0));

      world.clearRoom();
      expect(world.windlines.liveCount, 0);
    });

    test('Windline Memory (docs/04 §4.6) keeps lines through a room clear',
        () {
      // Same effect as *Lingering* (#62, a Boon), from a different,
      // account-level source. See ADR 0093.
      final SimWorld world = SimWorld(seed: 5)
        ..windlinesSurviveRoomTransition = true;
      world.spawnPlayer(2.0, 4.5);
      world.spawnAt(EntityKind.enemy, 14.0, 4.5, radius: 0.3, health: 1e9);

      final InputSnapshot idle = InputSnapshot();
      for (int i = 0; i < 60; i++) {
        world.tick(idle);
      }
      expect(world.windlines.liveCount, greaterThan(0));

      world.clearRoom();
      expect(world.windlines.liveCount, greaterThan(0));
    });

    test('determinism holds with Confluence active', () {
      String run() {
        final SimWorld world = SimWorld(seed: 4242)
          ..playerAttack = 3
          ..projectileSpeed = 9.0;
        world.spawnPlayer(8.0, 4.5);
        for (int i = 0; i < 6; i++) {
          world.spawnAt(EntityKind.enemy, 2.0 + i * 2.2, 1.5 + (i % 3) * 2.5,
              radius: 0.3, health: 1e9);
        }
        final InputSnapshot input = InputSnapshot();
        for (int t = 0; t < 600; t++) {
          final bool moving = (t ~/ 30).isEven;
          input.set(moving ? 0.7 : 0, moving ? -0.4 : 0);
          world.tick(input);
        }
        return '${world.windlines.liveCount};'
            '${world.events.countOf(SimEventType.confluenceTriggered)};'
            '${world.entities.liveCount}';
      }

      expect(run(), run());
    });
  });

  group('reaction bespoke effects', () {
    // docs/08 §8.2's own "Effect" column — the part beyond the shared
    // damage multiplier the "end to end" group above already covers.

    /// A world where the player at (8, 4.5) fires east toward an enemy at
    /// (15, 4.5), crossing a perpendicular Windline at x = 11 carrying
    /// [trailElement] while the arrow itself carries [arrowElement] —
    /// resolving to whichever reaction that pair produces on the first
    /// hit that lands.
    ({SimWorld world, int target}) reactionArena({
      required SimElement arrowElement,
      required SimElement trailElement,
    }) {
      final SimWorld world = SimWorld(seed: 11)
        ..playerAttack = 10
        ..arrowElement = arrowElement;
      world.spawnPlayer(8.0, 4.5);
      final int target =
          world.spawnAt(EntityKind.enemy, 15.0, 4.5, radius: 0.3, health: 1e9)
              .index;
      world.entities.maxHealth[target] = 1e9;
      world.windlines.add(
        fromX: 11.0,
        fromY: 1.0,
        toX: 11.0,
        toY: 8.0,
        expiresAt: 1e9,
        ownerIndex: 0,
        trailId: 999,
        elementIndex: trailElement.index,
      );
      return (world: world, target: target);
    }

    void runUntilFirstHit(SimWorld world) {
      final InputSnapshot idle = InputSnapshot();
      for (int t = 0;
          t < 120 && world.events.countOf(SimEventType.damageDealt) == 0;
          t++) {
        world.tick(idle);
      }
    }

    test('Steamburst (Ember+Frost): -20 % armour for 5 s, plus its own '
        '2.5 u AoE', () {
      final ({SimWorld world, int target}) a = reactionArena(
        arrowElement: SimElement.ember,
        trailElement: SimElement.frost,
      );
      // 2 u from the target — inside the 2.5 u burst.
      final int bystander =
          a.world.spawnAt(EntityKind.enemy, 15.0, 6.5, radius: 0.3, health: 1e9)
              .index;
      a.world.entities.maxHealth[bystander] = 1e9;

      runUntilFirstHit(a.world);

      expect(a.world.enemies.steamburstArmourRemaining[a.target],
          closeTo(5.0, 0.02));
      expect(1e9 - a.world.entities.health[bystander], greaterThan(0),
          reason: "Steamburst's own AoE must reach a nearby enemy");
    });

    test('Blightfire (Ember+Toxin): Burn and Toxin both tick at 2x for 3 s',
        () {
      final ({SimWorld world, int target}) a = reactionArena(
        arrowElement: SimElement.ember,
        trailElement: SimElement.toxin,
      );
      runUntilFirstHit(a.world);
      expect(a.world.enemies.blightfireRemaining[a.target], closeTo(3.0, 0.02));

      // The arrow's own Ember element already applied a Burn stack — tick
      // once and confirm the rate is doubled relative to the plain
      // ElementTuning rate.
      final double before = a.world.entities.health[a.target];
      const double dt = 1 / 60;
      a.world.tick(InputSnapshot());
      final double doubled = before - a.world.entities.health[a.target];
      // 4 %/s base Burn, one stack, doubled, over one fixed tick.
      final double expected =
          a.world.entities.maxHealth[a.target] * 0.04 * 2 * dt;
      expect(doubled, closeTo(expected, expected * 0.5));
    });

    test('Rime Rot (Frost+Toxin): freeze duration +1 s', () {
      final ({SimWorld world, int target}) a = reactionArena(
        arrowElement: SimElement.frost,
        trailElement: SimElement.toxin,
      );
      runUntilFirstHit(a.world);
      // A single Frost hit alone cannot reach the 100-Chill freeze
      // threshold, so any frozen time here came from Rime Rot's own bonus.
      expect(a.world.status.frozenRemaining[a.target], closeTo(1.0, 0.05));
    });

    test('Prismbreak (3+ elements): applies all four elements at max '
        'stacks, plus its own 4 u AoE', () {
      final SimWorld world = SimWorld(seed: 11)
        ..playerAttack = 10
        ..arrowElement = SimElement.ember;
      world.spawnPlayer(8.0, 4.5);
      final int target =
          world.spawnAt(EntityKind.enemy, 15.0, 4.5, radius: 0.3, health: 1e9)
              .index;
      world.entities.maxHealth[target] = 1e9;
      // 3.5 u from the target — inside the 4 u burst.
      final int bystander =
          world.spawnAt(EntityKind.enemy, 15.0, 8.0, radius: 0.3, health: 1e9)
              .index;
      world.entities.maxHealth[bystander] = 1e9;

      for (final (double x, int elementIndex) in <(double, int)>[
        (10.0, SimElement.frost.index),
        (11.0, SimElement.storm.index),
        (12.0, SimElement.toxin.index),
      ]) {
        world.windlines.add(
          fromX: x,
          fromY: 1.0,
          toX: x,
          toY: 8.0,
          expiresAt: 1e9,
          ownerIndex: 0,
          trailId: x.toInt(),
          elementIndex: elementIndex,
        );
      }

      final InputSnapshot idle = InputSnapshot();
      for (int t = 0;
          t < 120 && world.events.countOf(SimEventType.damageDealt) == 0;
          t++) {
        world.tick(idle);
      }

      expect(world.status.burnStacks[target], ElementTuning.burnMaxStacks);
      expect(world.status.isFrozen(target), isTrue);
      expect(world.status.toxinStacks[target], ElementTuning.toxinMaxStacks);
      expect(1e9 - world.entities.health[bystander], greaterThan(0),
          reason: "Prismbreak's own AoE must reach a nearby enemy");
    });
  });
}
