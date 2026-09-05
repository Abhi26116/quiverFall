import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// The 24 Spire nodes of docs/04-upgrades.md §4.2, one enum entry each, in
/// the doc's own numbering (1-24) and grouping (6 per wing).
enum SpireNodeArchetype {
  // ── Wing I — The Armory (offence) ─────────────────────────────────────────
  wardensMight,
  keenEdge,
  executioner,
  quickdraw,
  piercingStudy,
  elementalFocus,

  // ── Wing II — The Bulwark (survival) ──────────────────────────────────────
  vitality,
  wardedHide,
  momentumMastery,
  secondWind,
  ironResolve,
  lastLight,

  // ── Wing III — The Fletchery (mechanics) ──────────────────────────────────
  swiftshot,
  windlineWeaving,
  confluenceStudy,
  arrowVelocity,
  deflection,
  wideNock,

  // ── Wing IV — The Sanctum (economy) ───────────────────────────────────────
  fortune,
  prospector,
  boonInsight,
  shrineFavour,
  vigorWell,
  shardseeker,
}

/// The 4 wings, in docs/04's own unlock order.
enum SpireWing {
  /// Offence. Unlocks at account level 1 — every account can invest here
  /// from the start.
  armory(unlockAccountLevel: 1),

  /// Survival.
  bulwark(unlockAccountLevel: 5),

  /// Mechanics — "the mastery wing... intentionally the most expensive
  /// wing, and intentionally the one that rewards players who already
  /// understand [Confluence]" (docs/04 §4.2).
  fletchery(unlockAccountLevel: 9),

  /// Economy.
  sanctum(unlockAccountLevel: 14);

  const SpireWing({required this.unlockAccountLevel});

  final int unlockAccountLevel;
}

/// One Spire node.
///
/// Same split every content identity in this codebase uses: [archetype] is
/// identity, parsed straight from `assets/data/spire.json`'s own `id`;
/// numbers live in that file. Unlike [ArrowDefinition]/[HeroDefinition],
/// most nodes here need no code at all — see [contributionAt].
class SpireNodeDefinition {
  const SpireNodeDefinition({
    required this.archetype,
    required this.id,
    required this.key,
    required this.name,
    required this.wing,
    required this.description,
    required this.baseCost,
    this.channel,
    this.valuePerLevel = 0,
    this.stepEvery = 1,
    this.isAttackMultiplier = false,
    this.implemented = true,
    this.balanceNote = '',
  });

  /// 1-24, matching docs/04's own numbering.
  final int id;

  final SpireNodeArchetype archetype;
  final String key;
  final String name;
  final SpireWing wing;
  final String description;

  /// docs/02 §2.6: `Curves.spireNodeCost(base, n)` for level `n` (1-based).
  final double baseCost;

  /// The channel this node's own levels compose into, via [contributionAt]
  /// — null for [isAttackMultiplier] (composed separately, see its own doc)
  /// and for a node with no live effect yet ([implemented] false).
  final StatChannel? channel;

  /// This node's own contribution per level, in whatever unit [channel]
  /// expects raw (a fraction for a percentage channel, seconds for
  /// [StatChannel.windlineDuration], a count for [StatChannel.pierce]) —
  /// see [contributionAt] for how a multiplicative channel's factor is
  /// derived from this.
  final double valuePerLevel;

  /// [valuePerLevel] applies once every [stepEvery] levels, not every
  /// level — Piercing Study's own "+1 pierce / 16 levels" is the one node
  /// this is not 1 for.
  final int stepEvery;

  /// True only for Warden's Might. docs/04 §4.1's own master formula names
  /// `spireMight` as ATK's own parenthesised multiplicative term, standing
  /// alongside `arrowMult` and `(1 + Σ boonAtk)` — not one more line folded
  /// into the shared `combined` block every other node in this table
  /// composes into. A caller reads this node's own total via
  /// [attackFractionAt] and multiplies it into `baseAttack` directly,
  /// before `combined` is composed at all. See ADR 0092.
  final bool isAttackMultiplier;

  /// False for a node with no live combat effect yet — real, purchasable
  /// content (`SpireWorkshop` charges for it, `SpireState` tracks its own
  /// level like any other node), but [contributionAt] returns null for it
  /// until whatever integration point it actually needs exists. Every one
  /// has a *specific*, checked reason in [balanceNote] and ADR 0092 — never
  /// "not gotten to yet".
  final bool implemented;

  final String balanceNote;

  static const int maxLevel = 80;

  /// This node's own contribution at [level], in the same `StatModifier`
  /// shape a hero passive or arrow modifier already composes with — a
  /// caller feeds it straight into the same `_compose` rule
  /// `HeroLoadoutResolver` already applies to every other source. `null`
  /// for [isAttackMultiplier] (use [attackFractionAt] instead), a node with
  /// [implemented] false, or a level below its first [stepEvery] threshold.
  ///
  /// The Spire's own 80 levels of *one* node are one source, not eighty —
  /// docs/04 §4.1 rule 1 ("additive within a source") applies here: the
  /// total across every level is summed first, then composed *once*, the
  /// same way a hero's single "+8% crit chance" passive line is one
  /// `_compose` call rather than eight 1% ones. For a multiplicative
  /// channel (`StatChannel.drawSpeed` is the only one among the fourteen
  /// wired nodes), the summed total becomes `1 + total` — the single
  /// factor `BoonStats.multiplyBy` expects — rather than compounding the
  /// per-level value once per level, which would land on the wrong number
  /// entirely (checked directly against Quickdraw's own stated cap in
  /// ADR 0092).
  StatModifier? contributionAt(int level) {
    if (!implemented || isAttackMultiplier || channel == null) return null;
    final int steps = level ~/ stepEvery;
    if (steps <= 0) return null;
    final double total = steps * valuePerLevel;
    final double value = channel!.isMultiplicative ? 1.0 + total : total;
    return StatModifier(channel!, value);
  }

  /// Warden's Might's own total at [level] — a plain fraction (e.g. `0.40`
  /// for level 20), for a caller to fold into `1 + spireMight` before
  /// `baseAttack` is computed. `0` for every other node.
  double attackFractionAt(int level) =>
      isAttackMultiplier ? level * valuePerLevel : 0.0;

  @override
  String toString() => '#$id $name';
}
