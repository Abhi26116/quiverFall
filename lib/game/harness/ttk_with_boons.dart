import 'package:quiverfall/features/gameplay/application/stage_runner.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/harness/expected_power.dart';
import 'package:quiverfall/game/harness/harness_bot.dart';
import 'package:quiverfall/game/harness/ttk_probe.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/heroes/hero_loadout_resolver.dart';
import 'package:quiverfall/game/level/level_generator.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';

/// The fourth and last term of docs/02 §2.6's "expected power" —
/// [TtkProbe] deliberately leaves out "an average Boon draw at room 5";
/// this is where it gets folded in. See ADR 0091 for what "average" and
/// "room 5" resolve to.
///
/// Plays a *real* generated stage with [HarnessBot] until it reaches room
/// [targetRoomIndex], then hands the same live world — hero, arrow, and
/// every Boon it drew along the way, still applied — to
/// [TtkProbe.measureAgainstFreshMote] for the identical clean-fight
/// measurement [TtkProbe.measure] itself takes.
abstract final class TtkWithBoonsProbe {
  /// docs/02 §2.6 names a room, not a stage — see ADR 0091 for why stage 10
  /// (an ordinary, ungated mid-chapter stage on every chapter) is the one
  /// this reads Boons from.
  static const int defaultStage = 10;

  /// "Room 5" — see `HarnessBot.playToRoom`'s own doc comment for why this
  /// is a room index, not a count of Boons actually picked along the way.
  static const int defaultTargetRoomIndex = 5;

  /// Generous on purpose — a loadout well short of viable at this chapter
  /// can be genuinely slow to clear five rooms. See `HarnessBot
  /// .playToRoom`'s own doc comment.
  static const double defaultMaxPlaySeconds = 900;

  /// `ttk` is `null` whenever a reading was not possible at all: either the
  /// bot never reached [targetRoomIndex] (`status` is not
  /// [StageStatus.fighting] — it died, or the whole stage completed first),
  /// or it did and the fresh mote still outlived [TtkProbe.timeoutSeconds].
  /// `status`/`roomIndex` are always populated, so a caller can tell those
  /// cases apart. `boonsTaken` is the run's own `pickOrder` at the moment of
  /// measurement — the Boon ids actually drawn, for a report to show its
  /// work or a test to confirm Boons were really applied rather than
  /// silently skipped.
  static ({
    double? ttk,
    StageStatus status,
    int roomIndex,
    List<int> boonsTaken,
  }) measure({
    required HeroDefinition hero,
    required ArrowDefinition arrow,
    required ExpectedPower power,
    required ContentLibrary content,
    required BoonCatalogue boons,
    required SynergyCatalogue synergies,
    required int chapter,
    required int seed,
    int stage = defaultStage,
    int targetRoomIndex = defaultTargetRoomIndex,
    double maxPlaySeconds = defaultMaxPlaySeconds,
  }) {
    final StageBlueprint blueprint =
        StageBlueprint.forStage(chapter: chapter, stage: stage, seed: seed);
    final StagePlan plan = generateStage(
      generator: LevelGenerator(content: content, arenas: content.arenas),
      blueprint: blueprint,
    );
    final world =
        buildStageWorld(blueprint: blueprint, content: content, plan: plan);
    final StageRunner runner = StageRunner(
      world: world,
      content: content,
      plan: plan,
      boonCatalogue: boons,
      synergies: synergies,
    )..start();

    // ADR 0090 is exactly what makes this measurement possible at all: the
    // hero+arrow build now survives every one of `HarnessBot`'s own picks
    // below, instead of the first one silently discarding it.
    final ({
      double baseAttack,
      double baseFireRateMultiplier,
      double baseMaxHealth,
      double baseMoveSpeed,
    }) base = HeroLoadoutResolver.apply(
      world,
      hero,
      power.heroState(hero.key),
      arrow,
      power.arrowInstance(arrow.key),
    );
    runner.setBaseLoadout(
      baseAttack: base.baseAttack,
      baseFireRateMultiplier: base.baseFireRateMultiplier,
      baseMaxHealth: base.baseMaxHealth,
      baseMoveSpeed: base.baseMoveSpeed,
    );

    HarnessBot.playToRoom(
      runner,
      world,
      targetRoomIndex: targetRoomIndex,
      maxSeconds: maxPlaySeconds,
    );

    if (runner.status != StageStatus.fighting) {
      return (
        ttk: null,
        status: runner.status,
        roomIndex: runner.roomIndex,
        boonsTaken: List<int>.of(runner.boons.pickOrder),
      );
    }

    final double? ttk = TtkProbe.measureAgainstFreshMote(
      world,
      globalStage: blueprint.globalStage,
    );
    return (
      ttk: ttk,
      status: runner.status,
      roomIndex: runner.roomIndex,
      boonsTaken: List<int>.of(runner.boons.pickOrder),
    );
  }
}
