import 'dart:typed_data';

import 'package:quiverfall/game/sim/sim_config.dart';

/// Per-slot state for a `EntityKind.companion` — a friendly, independently
/// acting body fighting alongside the player. Zea's own Skyhawk/Falconry and
/// Mirelle's own Hall of Mirrors clone (docs/07 §7.3) are both companions;
/// nothing here is hero-specific, the same "the primitive is generic, the
/// hero-specific numbers are the caller's job" split every other per-entity
/// store in this codebase already draws. See `CompanionSystem` and ADR 0071.
///
/// Position, radius and health live on the shared `EntityStore` like any
/// other entity — this store only carries what makes a companion a
/// companion rather than an enemy or a projectile, the same "one struct-of-
/// arrays row per new fact, not per new entity" shape `ProjectileStore`/
/// `EnemyStore` already use.
class CompanionStore {
  CompanionStore({int capacity = SimConfig.maxEntities})
      : damageShare = Float64List(capacity),
        fireIntervalSeconds = Float64List(capacity),
        attackCooldown = Float64List(capacity),
        remaining = Float64List(capacity),
        alwaysCrit = Uint8List(capacity),
        followOffsetX = Float64List(capacity),
        followOffsetY = Float64List(capacity);

  /// Fraction of `SimWorld.playerAttack` this companion deals per landed
  /// hit — a flat share, not routed through the player's own Draw tier,
  /// Boon `boonSum`, or pierce falloff. docs/07's own cards state a bare
  /// percentage of ATK for every companion ("35 % of hero ATK", "60 %
  /// stats"), never a modified-by-the-player's-current-build number, so a
  /// companion's own hit is deliberately simple rather than routed through
  /// `ProjectileSystem`'s own hero-conditional pipeline built for the
  /// player's own arrow. See `CompanionSystem`'s own doc comment for why.
  final Float64List damageShare;

  /// Seconds between shots — `1 / fireRate`, docs/07's own stated rate.
  final Float64List fireIntervalSeconds;

  /// Counts down to the next shot; fires and resets to
  /// [fireIntervalSeconds] at zero.
  final Float64List attackCooldown;

  /// Seconds left before this companion despawns. `double.infinity` for a
  /// permanent companion (Zea's own passive Skyhawk); a real number for a
  /// timed summon (Falconry's own extra hawks, Mirelle's own clone).
  final Float64List remaining;

  /// Zea's own *Bonded* (T3a): this companion crits whenever the player is
  /// at Tier III, read live at fire time rather than stored as a rolled
  /// outcome — the same "read a live condition, not an RNG roll" shape
  /// Vane's own Marked bonus already uses for a boss-adjacent check.
  final Uint8List alwaysCrit;

  /// Where this companion tries to hover relative to the player's own
  /// position — authored, not docs-stated (docs/07 says nothing about hawk
  /// formation), so several companions spread out rather than stacking on
  /// one point.
  final Float64List followOffsetX;
  final Float64List followOffsetY;

  void reset(int slot) {
    damageShare[slot] = 0;
    fireIntervalSeconds[slot] = 1.0;
    attackCooldown[slot] = 0;
    remaining[slot] = 0;
    alwaysCrit[slot] = 0;
    followOffsetX[slot] = 0;
    followOffsetY[slot] = 0;
  }
}
