import 'dart:io';

import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/content/enemy_definition.dart';
import 'package:quiverfall/game/sim/input.dart';
import 'package:quiverfall/game/sim/world.dart';

/// Loads the **shipping** enemy table from disk.
///
/// Deliberately not a fixture. The content in `assets/data/enemies.json` is the
/// thing under test as much as the code is — a Husk with no plate or a Longeye
/// that outranges the arena is a shipping bug, and a hand-written fixture would
/// hide exactly that class of problem.
ContentLibrary loadEnemies() {
  final String json = File('assets/data/enemies.json').readAsStringSync();
  final (ContentLibrary?, List<ContentError>) result =
      ContentLibrary.parse(enemiesJson: json);

  final ContentLibrary? library = result.$1;
  if (library == null) {
    throw StateError('enemies.json failed to load:\n${result.$2.join('\n')}');
  }
  return library;
}

/// A world with real content, a player, and no auto-fire.
///
/// Auto-fire off by default because most enemy tests want to observe an enemy
/// doing its own thing, not race it against the player's damage.
SimWorld enemyWorld({
  required ContentLibrary content,
  int seed = 20260720,
  double playerX = 8.0,
  double playerY = 4.5,
  double playerHealth = 100,
  bool autoFire = false,
  double enemyHpBase = 44.0,
}) {
  final SimWorld world = SimWorld(seed: seed, content: content)
    ..autoFire = autoFire
    ..enemyHpBase = enemyHpBase;

  final int player = world.spawnPlayer(playerX, playerY).index;
  world.entities.health[player] = playerHealth;
  world.entities.maxHealth[player] = playerHealth;
  return world;
}

/// Runs [seconds] of simulation at the fixed step.
void run(SimWorld world, double seconds, {InputSnapshot? input}) {
  final InputSnapshot snapshot = input ?? InputSnapshot();
  final int ticks = (seconds * 60).round();
  for (int i = 0; i < ticks; i++) {
    world.tick(snapshot);
  }
}

/// The chapter each enemy is introduced in, from docs/05 §5.8.
///
/// Transcribed here so the schedule is asserted against the *document* rather
/// than against whatever the data happens to say. The schedule is load-bearing:
/// it is what makes all 26 base types visible by chapter 8, so the second half
/// of the campaign can be about combinations rather than new sprites.
const Map<EnemyArchetype, int> introductionSchedule = <EnemyArchetype, int>{
  EnemyArchetype.mote: 1,
  EnemyArchetype.husk: 1,
  EnemyArchetype.lancer: 1,
  EnemyArchetype.spitter: 1,
  EnemyArchetype.swarmling: 2,
  EnemyArchetype.stalker: 2,
  EnemyArchetype.nettle: 2,
  EnemyArchetype.weaver: 2,
  EnemyArchetype.wisp: 3,
  EnemyArchetype.ripper: 3,
  EnemyArchetype.bulwark: 3,
  EnemyArchetype.riftMaw: 3,
  EnemyArchetype.cinderMote: 4,
  EnemyArchetype.bounder: 4,
  EnemyArchetype.longeye: 4,
  EnemyArchetype.chanter: 4,
  EnemyArchetype.shellback: 5,
  EnemyArchetype.thresher: 5,
  EnemyArchetype.mortarite: 5,
  EnemyArchetype.echo: 5,
  EnemyArchetype.ironmaw: 6,
  EnemyArchetype.screecher: 6,
  EnemyArchetype.knitter: 6,
  EnemyArchetype.wardenFell: 6,
  EnemyArchetype.gravebound: 7,
  EnemyArchetype.nullborn: 8,
};
