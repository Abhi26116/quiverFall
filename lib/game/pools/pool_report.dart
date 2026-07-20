/// A pool that can report on itself.
///
/// Pure Dart and in the game layer, because the pools that matter most live in
/// the simulation and the simulation may not depend on the view.
///
/// The stores in this project are already pools — fixed-capacity typed arrays
/// with free lists — so nothing wraps them. This is the reporting surface
/// docs/12 §12.11 requires: pools are "pre-warmed during the loading screen,
/// never grown mid-room (a miss returns a no-op object and logs)", and a rule
/// nothing can observe is not a rule.
abstract interface class PoolReport {
  String get poolName;

  /// Slots allocated at construction. Pools never grow past this.
  int get poolCapacity;

  /// Slots currently in use.
  int get poolLive;

  /// Allocations refused, or live entries evicted, since the last reset.
  ///
  /// **This is the number that matters.** A miss is a dropped arrow, a dropped
  /// telegraph, or an enemy that never spawned — each of which the player
  /// experiences as the game being broken rather than as the game being
  /// careful.
  int get poolMisses;
}
