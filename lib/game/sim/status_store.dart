import 'dart:typed_data';

import 'package:quiverfall/game/sim/elements.dart';
import 'package:quiverfall/game/sim/sim_config.dart';

/// Elemental status on every entity, indexed by slot.
///
/// Four elements, four different shapes of state — deliberately, because each
/// element's *feel* comes from how its state behaves, not from its numbers:
///
///  - **Ember** stacks and expires. Pressure that fades.
///  - **Frost** accumulates toward a threshold, then discharges. Tension, then
///    release.
///  - **Storm** has no state at all; it resolves instantly on hit.
///  - **Toxin** stacks and persists. Investment that compounds.
class StatusStore {
  StatusStore({int capacity = SimConfig.maxEntities})
      : burnStacks = Uint8List(capacity),
        burnRemaining = Float64List(capacity),
        chill = Float64List(capacity),
        frozenRemaining = Float64List(capacity),
        toxinStacks = Uint8List(capacity),
        reactionCooldown = Float64List(capacity),
        _capacity = capacity;

  final int _capacity;

  final Uint8List burnStacks;
  final Float64List burnRemaining;

  /// Accumulates toward [ElementTuning.chillToFreeze]; decays when unreinforced.
  final Float64List chill;
  final Float64List frozenRemaining;

  final Uint8List toxinStacks;

  /// Time until this entity may host another reaction.
  final Float64List reactionCooldown;

  bool isFrozen(int slot) => frozenRemaining[slot] > 0;

  /// Extra damage a frozen target takes.
  double damageTakenBonus(int slot) =>
      isFrozen(slot) ? ElementTuning.frozenDamageBonus : 0;

  /// Healing multiplier, reduced by Toxin. Floors at zero rather than going
  /// negative, which would turn healing into damage.
  double healingMultiplier(int slot) {
    final double reduction =
        toxinStacks[slot] * ElementTuning.toxinHealingReductionPerStack;
    final double m = 1.0 - reduction;
    return m < 0 ? 0 : m;
  }

  void clearSlot(int slot) {
    burnStacks[slot] = 0;
    burnRemaining[slot] = 0;
    chill[slot] = 0;
    frozenRemaining[slot] = 0;
    toxinStacks[slot] = 0;
    reactionCooldown[slot] = 0;
  }

  void clear() {
    for (int i = 0; i < _capacity; i++) {
      clearSlot(i);
    }
  }

  /// Applies an element to a target. Returns the element that was already
  /// present and would react, or null.
  ///
  /// Application is separate from reaction resolution because reactions are
  /// produced only by Confluence (docs/08 §8.2) — a plain hit applies its
  /// element and nothing more.
  ///
  /// [chillPerHitOverride] lets a hero-specific rate (Sela's Deeper Chill:
  /// 16 instead of the base 12) feed the same accumulator every other Frost
  /// source uses, rather than forking the threshold logic per caller.
  ///
  /// [toxinStacksPerHitOverride]/[toxinMaxStacksOverride] do the same for
  /// Sable's Fast Acting (2 stacks/hit, capped at 8) and Virulence (capped
  /// at 12) — both read the same [toxinStacks] every other Toxin source
  /// (an arrow's own element, a Boon) stacks at the base rate of 1/10.
  ///
  /// [burnMaxStacksOverride]/[burnDurationOverride] do the same for Kade's
  /// Slow Burn (3 stacks, 8 s instead of the base 2/4 s).
  ///
  /// [durationMultiplier] is Oriel's own Saturation (T3b) — "elements
  /// persist 2x longer on enemies" — scaling whatever duration this call
  /// would otherwise have landed on (an override included), rather than a
  /// second override slot of its own. It touches Burn's own duration and
  /// Frost's own freeze once discharged; Toxin has no duration to extend
  /// (stacks persist until cleared, not on a timer) and Storm resolves
  /// instantly, so neither reads it at all.
  SimElement? apply(
    int slot,
    SimElement element, {
    double? chillPerHitOverride,
    int? toxinStacksPerHitOverride,
    int? toxinMaxStacksOverride,
    int? burnMaxStacksOverride,
    double? burnDurationOverride,
    double durationMultiplier = 1.0,
  }) {
    final SimElement? existing = dominantElement(slot);

    switch (element) {
      case SimElement.ember:
        final int maxBurnStacks =
            burnMaxStacksOverride ?? ElementTuning.burnMaxStacks;
        if (burnStacks[slot] < maxBurnStacks) {
          burnStacks[slot]++;
        }
        burnRemaining[slot] =
            (burnDurationOverride ?? ElementTuning.burnDuration) *
                durationMultiplier;

      case SimElement.frost:
        chill[slot] += chillPerHitOverride ?? ElementTuning.chillPerHit;
        if (chill[slot] >= ElementTuning.chillToFreeze) {
          chill[slot] = 0;
          frozenRemaining[slot] = ElementTuning.freezeDuration * durationMultiplier;
        }

      case SimElement.storm:
        // Resolves instantly at the hit site; no lingering state.
        break;

      case SimElement.toxin:
        final int maxStacks =
            toxinMaxStacksOverride ?? ElementTuning.toxinMaxStacks;
        final int next = toxinStacks[slot] + (toxinStacksPerHitOverride ?? 1);
        toxinStacks[slot] = next > maxStacks ? maxStacks : next;
    }

    return existing != element ? existing : null;
  }

  /// The element currently most present on a target, for reaction pairing.
  SimElement? dominantElement(int slot) {
    if (frozenRemaining[slot] > 0 || chill[slot] > 0) return SimElement.frost;
    if (burnStacks[slot] > 0) return SimElement.ember;
    if (toxinStacks[slot] > 0) return SimElement.toxin;
    return null;
  }

  bool canReact(int slot) => reactionCooldown[slot] <= 0;

  void markReacted(int slot) {
    reactionCooldown[slot] = Reactions.perEnemyCooldown;
  }
}
