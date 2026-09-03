import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/hero_runtime.dart';
import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';
import 'package:quiverfall/game/sim/status_store.dart';

/// Ticks elemental damage-over-time and expires statuses.
///
/// Ember and Toxin deal a fraction of the target's **max HP** per second, which
/// is what makes them boss-killers and deliberately poor against fodder — the
/// other half of the split that keeps element choice meaningful late
/// (docs/08-arrows.md §8.2).
///
/// Kestrel's own non-elemental *Bleed* (`EnemyStore.bleedStacks`) ticks here
/// too, alongside — not instead of — the four elements: it needs the exact
/// same "apply damage, check death, emit the event, despawn" routine this
/// class already is, and a second copy of that routine elsewhere would be
/// the real inconsistency, not one extra DoT source reusing it.
abstract final class ElementSystem {
  /// [deferDeath] hands corpses to [AiSystem]'s death pass instead of reaping
  /// them here.
  ///
  /// The world sets it; a unit test driving this system on its own does not.
  /// Deaths inside a live room have consequences — a Cinder Mote detonates, a
  /// Gravebound goes down instead of dying, a Twinned enemy splits — and those
  /// must not depend on *which* system happened to land the killing tick. One
  /// death routine, reached from every damage source, is the only arrangement
  /// where that is true.
  static void update({
    required EntityStore store,
    required StatusStore status,
    required SimEventBuffer events,
    required double dt,
    bool deferDeath = false,
    HeroRuntime? hero,
    EnemyStore? enemies,
  }) {
    final int high = store.highWater;

    // *Deep Burn* (Kade, T1b) — 6 %/s instead of the base 4 %/s. Read once
    // rather than per-entity below, since exactly one hero is ever equipped.
    final double burnPerSecond = hero != null && hero.has(HeroBehaviour.kadeDeepBurn)
        ? _kadeDeepBurnPerSecond
        : ElementTuning.burnPerSecond;

    // *Crush* (Rook, T3a) drives the exact same `bleedStacks`/
    // `bleedRemaining` storage Kestrel's own Bleed does (ADR 0015's own
    // update), but at its own stated 5 %/s per stack rather than Bleed's
    // borrowed 4 %/s — the same per-hero rate switch Deep Burn uses above.
    final double bleedPerSecond = hero != null && hero.has(HeroBehaviour.rookCrush)
        ? _rookCrushPerSecond
        : _bleedPerSecond;

    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      if (status.reactionCooldown[i] > 0) {
        status.reactionCooldown[i] -= dt;
      }

      // Freeze suppresses everything else while it lasts — including, notably,
      // the Cinder Mote's death fuse, which is the taught interaction that
      // makes Frost useful beyond damage (docs/05 §5.1).
      if (status.frozenRemaining[i] > 0) {
        status.frozenRemaining[i] -= dt;
        continue;
      }

      // Chill bleeds off when unreinforced. Without decay a single Rimeshaft
      // would eventually freeze everything regardless of sustained pressure.
      if (status.chill[i] > 0) {
        status.chill[i] -= ElementTuning.chillDecayPerSecond * dt;
        if (status.chill[i] < 0) status.chill[i] = 0;
      }

      double damage = 0;

      if (status.burnStacks[i] > 0) {
        status.burnRemaining[i] -= dt;
        if (status.burnRemaining[i] <= 0) {
          status.burnStacks[i] = 0;
          status.burnRemaining[i] = 0;
        } else {
          damage += store.maxHealth[i] * burnPerSecond * status.burnStacks[i] * dt;
        }
      }

      if (status.toxinStacks[i] > 0) {
        damage += store.maxHealth[i] *
            ElementTuning.toxinPerStackPerSecond *
            status.toxinStacks[i] *
            dt;
      }

      // *Bleed* — the shared storage Kestrel's own Bleed and Rook's own
      // Crush both drive; [bleedPerSecond] above already picked the right
      // rate for whichever of the two is actually equipped. ADR 0015: no
      // %/s is stated anywhere for Kestrel's own version, so that half
      // reuses Burn's own rate rather than inventing a fresh number, the
      // closest existing analog (a stacking, duration-based DoT).
      if (enemies != null && enemies.bleedStacks[i] > 0) {
        enemies.bleedRemaining[i] -= dt;
        if (enemies.bleedRemaining[i] <= 0) {
          enemies.bleedStacks[i] = 0;
          enemies.bleedRemaining[i] = 0;
        } else {
          damage +=
              store.maxHealth[i] * bleedPerSecond * enemies.bleedStacks[i] * dt;
        }
      }

      if (damage <= 0) continue;

      store.health[i] -= damage;

      if (store.health[i] <= 0 && !deferDeath) {
        events.emit(
          SimEventType.entityDied,
          entityA: i,
          x: store.posX[i],
          y: store.posY[i],
        );
        status.clearSlot(i);
        store.despawn(store.idAt(i));
      }
    }
  }

  /// Resolves a reaction produced by a Confluence hit.
  ///
  /// Reactions are triggered *only* here, from Confluence — never by passively
  /// stacking two elemental sources. That restriction is what turns
  /// build-crafting into an execution problem and is the deepest idea in the
  /// game (docs/08 §8.2).
  ///
  /// Returns the damage multiplier to apply to the triggering hit, or 1.0.
  static double resolveReaction({
    required StatusStore status,
    required SimEventBuffer events,
    required int target,
    required int elementMask,
    required SimElement? incoming,
    required double x,
    required double y,
  }) {
    if (!status.canReact(target)) return 1.0;

    final int distinct = _bitCount(elementMask) + (incoming != null ? 1 : 0);

    Reaction? reaction = Reactions.forElementCount(distinct);

    if (reaction == null && incoming != null) {
      // Pair the incoming element against whichever element the crossed lines
      // carried.
      for (final SimElement candidate in SimElement.values) {
        if (candidate == incoming) continue;
        if (elementMask & (1 << candidate.index) == 0) continue;
        reaction = Reactions.between(incoming, candidate);
        if (reaction != null) break;
      }
    }

    if (reaction == null) return 1.0;

    status.markReacted(target);
    events.emit(
      SimEventType.reactionTriggered,
      entityA: target,
      valueA: reaction.index.toDouble(),
      valueB: reaction.damageMultiplier,
      x: x,
      y: y,
    );

    return reaction.damageMultiplier;
  }

  static const double _kadeDeepBurnPerSecond = 0.06;

  /// ADR 0015 — Kestrel's own Bleed rate, anchored to Burn's own base
  /// (`ElementTuning.burnPerSecond`) since docs/07 states a duration (3 s)
  /// but no %/s for it at all.
  static const double _bleedPerSecond = ElementTuning.burnPerSecond;

  /// docs/07 §7.1: Rook's *Crush* states its own rate outright — "grouped
  /// enemies take stacking 5 %/s" — unlike Kestrel's own Bleed above, so
  /// this is not an invented or borrowed number.
  static const double _rookCrushPerSecond = 0.05;

  static int _bitCount(int mask) {
    int n = 0;
    int m = mask;
    while (m != 0) {
      n += m & 1;
      m >>= 1;
    }
    return n;
  }
}
