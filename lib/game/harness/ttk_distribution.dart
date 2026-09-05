import 'package:quiverfall/game/arrows/arrow_catalogue.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/harness/expected_power.dart';
import 'package:quiverfall/game/harness/ttk_probe.dart';
import 'package:quiverfall/game/heroes/hero_catalogue.dart';
import 'package:quiverfall/game/level/stage_blueprint.dart';

/// [TtkProbe.measure] run many times over seeded, varying draws of the same
/// fight — the "10,000 seeded runs per chapter" half of docs/02 §2.6.
///
/// Nothing about [ExpectedPower] varies run to run (no Boons are modelled
/// yet — see its own doc comment), but the fight itself is not
/// deterministic: `DamageResolver`'s crit roll, and any elemental
/// application chance the chapter's matching-tier arrow carries, both draw
/// from the world's own seeded RNG. Varying the seed is what turns "one
/// fight" into the distribution docs/02 asks the harness to report.
class TtkDistribution {
  const TtkDistribution({
    required this.chapter,
    required this.globalStage,
    required this.samples,
    required this.timeouts,
  });

  final int chapter;
  final int globalStage;

  /// Ascending-sorted TTK seconds. Excludes timed-out runs — see [timeouts].
  final List<double> samples;

  /// Runs where the mote outlived `TtkProbe.timeoutSeconds` — a harness
  /// failure in its own right, kept separate from the percentile math so one
  /// stuck run cannot silently vanish into a very high sample instead of
  /// being counted.
  final int timeouts;

  int get runCount => samples.length + timeouts;

  /// Linear-interpolated percentile, `p` in `[0, 1]`. `samples` must be
  /// non-empty — callers check [timeouts] first.
  double percentile(double p) {
    assert(samples.isNotEmpty, 'no completed runs to take a percentile of');
    if (samples.length == 1) return samples.single;
    final double rank = p * (samples.length - 1);
    final int lo = rank.floor();
    final int hi = rank.ceil();
    if (lo == hi) return samples[lo];
    final double frac = rank - lo;
    return samples[lo] + (samples[hi] - samples[lo]) * frac;
  }

  double get p10 => percentile(0.10);
  double get p50 => percentile(0.50);
  double get p90 => percentile(0.90);

  /// The CI gate itself — docs/02 §2.6: "Any build where the p10-p90 TTK
  /// band escapes [0.6, 2.2] fails CI." A timeout fails this on its own:
  /// there is no seconds value for it to be "within bounds".
  bool get withinHardBounds =>
      timeouts == 0 &&
      Curves.ttkWithinHardBounds(p10) &&
      Curves.ttkWithinHardBounds(p90);
}

/// Builds a [TtkDistribution] for one chapter by running [TtkProbe.measure]
/// [runs] times over consecutive seeds.
abstract final class TtkHarness {
  /// Global stage sampled for chapter [chapter]: the chapter's own boss
  /// stage (`stagesPerChapter`, i.e. stage 20) — the hardest common-enemy HP
  /// the chapter ever presents a player at this chapter's expected power,
  /// so a passing reading here is a passing reading for every earlier stage
  /// of the same chapter too.
  static int globalStageFor(int chapter) =>
      StageBlueprint.forStage(chapter: chapter, stage: 20, seed: 0)
          .globalStage;

  static TtkDistribution measureChapter({
    required int chapter,
    required ContentLibrary content,
    required HeroCatalogue heroes,
    required ArrowCatalogue arrows,
    int runs = 200,
    int baseSeed = 900000,
  }) {
    final ExpectedPower power = ExpectedPower.forChapter(chapter);
    final int globalStage = globalStageFor(chapter);

    final List<double> samples = <double>[];
    int timeouts = 0;

    for (int i = 0; i < runs; i++) {
      final double? ttk = TtkProbe.measure(
        hero: heroes.byArchetype(TtkProbe.referenceHero)!,
        arrow: arrows.byArchetype(power.arrow)!,
        power: power,
        content: content,
        globalStage: globalStage,
        seed: baseSeed + i,
      );
      if (ttk == null) {
        timeouts++;
      } else {
        samples.add(ttk);
      }
    }
    samples.sort();

    return TtkDistribution(
      chapter: chapter,
      globalStage: globalStage,
      samples: samples,
      timeouts: timeouts,
    );
  }
}
