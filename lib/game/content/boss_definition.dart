/// The 20 bosses of docs/06-bosses.md, one value each.
///
/// The same split every other content type in this directory uses: this enum
/// is the boss's *identity*, parsed straight from the content table's `id`
/// field, so a boss that is not listed here cannot be authored. Bosses are
/// bespoke rather than data-driven — each fight's actual mechanics are coded,
/// boss by boss, the same way a hero's kit is — so unlike [EnemyArchetype]
/// there is no matching `BossBehaviour` enum yet; one gets added the moment a
/// second boss needs to share a branch with a first, not before.
enum BossArchetype {
  // ── Campaign (chapters 1–12) ────────────────────────────────────────────
  cinderChoir,
  gauntIronTide,
  silversong,
  hollowWarden,
  vermillion,
  rimefather,
  arclight,
  greenMother,
  thrallOfNine,
  weepingGate,
  skarnUnmade,
  quiverfall,

  // ── Elite & event (13–16) ────────────────────────────────────────────────
  ashenChoir,
  umbralTwin,
  bellweather,
  paleJudge,

  // ── Endless Descent (17–20) ──────────────────────────────────────────────
  theLoom,
  coilspine,
  motherOfMotes,
  lastWarden,
}

/// Where a boss is met, from docs/06's own three sections. Not a difficulty
/// label — a Pale Judge (event) is harder than a Cinder Choir (campaign) —
/// but a real gameplay fact: it decides which unlock/appearance rule applies,
/// campaign chapter clear vs. a floor-depth interval vs. a calendar event.
enum BossTier {
  campaign,
  elite,
  event,
  endless,
}

/// A single boss, loaded from `assets/data/bosses.json`.
///
/// Deliberately leaner than [EnemyDefinition]: an enemy's whole behaviour is
/// numbers plugged into a shared family tree, so [EnemyDefinition] carries
/// dozens of optional combat fields. A boss's behaviour is *code* — its own
/// attack pattern, own multi-body rules, own per-phase logic — so this class
/// carries only what's true of every boss regardless of what its fight does:
/// identity, where it's fought, how tough it is, and where its phases break.
class BossDefinition {
  const BossDefinition({
    required this.archetype,
    required this.name,
    required this.tier,
    required this.hpMultiplier,
    required this.phaseThresholds,
    this.targetDurationSeconds,
    this.chapter,
  });

  factory BossDefinition.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawThresholds =
        json['phaseThresholds'] as List<dynamic>;
    return BossDefinition(
      // The id *is* the archetype, the same rule EnemyDefinition uses and for
      // the same reason: a boss's data and its coded fight cannot drift apart
      // if there is only one field naming it.
      archetype: BossArchetype.values.byName(json['id'] as String),
      name: json['name'] as String,
      tier: BossTier.values.byName(json['tier'] as String),
      hpMultiplier: (json['hpMultiplier'] as num).toDouble(),
      targetDurationSeconds:
          (json['targetDurationSeconds'] as num?)?.toDouble(),
      phaseThresholds: List<double>.unmodifiable(
        rawThresholds.map((Object? v) => (v as num).toDouble()),
      ),
      chapter: (json['chapter'] as num?)?.toInt(),
    );
  }

  final BossArchetype archetype;
  final String name;
  final BossTier tier;

  String get id => archetype.name;

  /// Campaign chapter this boss closes (1–12). Null for elite, event and
  /// Endless bosses — docs/06 §6.2/§6.3 gate those on a mini-boss interval,
  /// a live event window and a floor depth respectively, none of which this
  /// pass models yet; see ADR 0017.
  final int? chapter;

  /// Multiplier on `Curves.bossHp`'s own `HP(G)` term — docs/06 §6.0's
  /// `bossHP = HP(G) · bossMult · (1 + 0.06 · encounterCount)`. `Curves.bossHp`
  /// already implements the whole formula; this is just its `multiplier` arg.
  final double hpMultiplier;

  /// docs/06 §6.0 rule 5: "Longer than 90 s in a mobile session is a phone in
  /// a pocket." Not read by any system yet — a future balance-harness check,
  /// the same role `Curves.ttkWithinTarget` plays for common enemies.
  ///
  /// Null for three of the four Endless bosses (docs/06 §6.3's own text gives
  /// every campaign, elite and event boss — and Endless boss #20, The Last
  /// Warden — an exact number, but #17-19 only ever get the tier's aggregate
  /// "90-150 s" range in the §6.4 summary table, never their own figure) —
  /// see ADR 0017 rather than inventing one.
  final double? targetDurationSeconds;

  /// HP-fraction thresholds a boss transitions on, highest first.
  ///
  /// `[0.66, 0.33]` is docs/06 §6.0 rule 1's own stated default — "hard visual
  /// and musical transition at 66% and 33% HP" — and every boss in this file
  /// except [BossArchetype.lastWarden] uses exactly that, unmodified, because
  /// none of their own per-boss text overrides it. `phaseCount` is derived
  /// (`phaseThresholds.length + 1`) rather than stored separately, so the two
  /// can never disagree.
  ///
  /// [BossArchetype.lastWarden]'s own four thresholds (`[0.8, 0.6, 0.4, 0.2]`)
  /// are an inferred even split, not a number docs/06 §6.3 states — see ADR
  /// 0017. Its own P5 ("one HP each... sudden death") is not a fractional
  /// threshold at all and needs its own end-of-fight rule when that boss is
  /// actually built, not a fifth entry here.
  final List<double> phaseThresholds;

  int get phaseCount => phaseThresholds.length + 1;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'tier': tier.name,
        if (chapter != null) 'chapter': chapter,
        'hpMultiplier': hpMultiplier,
        if (targetDurationSeconds != null)
          'targetDurationSeconds': targetDurationSeconds,
        'phaseThresholds': phaseThresholds,
      };
}
