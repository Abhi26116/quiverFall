import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/enemy_store.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/events.dart';

/// Advances every live boss's phase as its own HP crosses its own
/// thresholds.
///
/// This is the one piece of docs/06 §6.0's design rules that is true of
/// *every* boss regardless of what its fight actually does — "three phases
/// minimum, with a hard visual and musical transition at 66% and 33% HP" —
/// so it is the one piece built generic, ahead of any single boss's bespoke
/// attack pattern. What a phase *means* (which attacks unlock, whether the
/// boss splits, whether a mechanic inverts) is each boss's own code, reading
/// [EnemyStore.bossPhase] the same way `ai_system.dart`'s family trees
/// already read `EnemyStore.state`.
abstract final class BossPhaseSystem {
  static void update({
    required EntityStore store,
    required EnemyStore enemies,
    required ContentLibrary content,
    required SimEventBuffer events,
  }) {
    final int high = store.highWater;
    for (int i = 0; i < high; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.enemy.index) continue;

      final int bossIndex = enemies.bossIndex[i];
      if (bossIndex < 0) continue;

      final BossDefinition def = content.bosses.all[bossIndex];
      final List<double> thresholds = def.phaseThresholds;

      final double maxHealth = store.maxHealth[i];
      if (maxHealth <= 0) continue;
      final double fraction = store.health[i] / maxHealth;

      int phase = enemies.bossPhase[i];
      // A `while`, not an `if`: a single burst hit (or a big DoT tick) can
      // cross more than one threshold in the same simulation step, and every
      // boundary crossed is a real transition the presentation layer needs
      // to know happened — docs/06's "hard transition" is a step function,
      // so jumping straight to the final phase would silently drop the one
      // in between, the same reasoning `ElementSystem` already applies to a
      // DoT tick that would overshoot a death threshold.
      while (phase < thresholds.length && fraction <= thresholds[phase]) {
        phase++;
        enemies.bossPhase[i] = phase;
        events.emit(
          SimEventType.bossPhaseChanged,
          entityA: i,
          valueA: phase.toDouble(),
          valueB: fraction,
        );
      }
    }
  }
}
