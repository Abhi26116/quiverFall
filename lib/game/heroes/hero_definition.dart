import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// The 20 heroes of docs/07-heroes.md, one value each.
///
/// The same split `EnemyArchetype` uses, and for the same reason: this enum is
/// the hero's *identity*, parsed straight from the content table's `id`
/// field, so a hero that is not listed here cannot be authored and an
/// archetype with no kit implemented cannot ship silently. Behaviour
/// *switches* live here and in `HeroBehaviour`; behaviour *numbers* — stat
/// baselines, unlock costs, talent values — live in `assets/data/heroes.json`,
/// which is what keeps live-ops retuning a hero's power safe without ever
/// letting it retune what the hero *does*.
enum HeroArchetype {
  wren,
  bram,
  kestrel,
  ovrin,
  kade,
  sela,
  torv,
  sable,
  lira,
  corvin,
  vane,
  thane,
  nyx,
  iris,
  zea,
  rook,
  halden,
  ashlin,
  mirelle,
  oriel,
}

/// docs/07 §7.0: "4 Common · 8 Rare · 6 Epic · 2 Legendary" — a classification
/// on unlock cost and kit complexity, not a draw weight. Heroes are never
/// randomly offered the way Boons are; a player unlocks a specific hero for a
/// specific, known cost. Deliberately not [BoonRarity] — reusing one enum
/// across two unrelated domains would mean a change meant for Boons (say, a
/// sixth tier) silently reshaping the hero roster too.
enum HeroRarity { common, rare, epic, legendary }

/// How a hero is unlocked. docs/07's per-hero unlock lines are all one of
/// three shapes: free from the start, granted on clearing a chapter, or
/// bought with shards from a named source.
enum HeroUnlockKind { free, chapterClear, shards }

class HeroUnlock {
  const HeroUnlock({
    required this.kind,
    this.chapter,
    this.shardCost,
    this.source,
    this.note,
  });

  final HeroUnlockKind kind;

  /// The chapter gate. Required for [HeroUnlockKind.chapterClear]; optional
  /// on [HeroUnlockKind.free] for a hero granted automatically on reaching a
  /// chapter rather than from the start — Kade's "free at chapter 5" is the
  /// one case docs/07 uses this for.
  final int? chapter;

  /// Set when [kind] is [HeroUnlockKind.shards].
  final int? shardCost;

  /// Where the shards come from, e.g. "Astral chests". Display text only.
  final String? source;

  /// Free-text detail docs/07 states but this model has no dedicated field
  /// for — Ovrin's "(shards from Gaunt)" describes where his *post-unlock*
  /// star-up shards come from, a different fact from how he is unlocked.
  /// Display text only.
  final String? note;
}

/// docs/07 §7.0's stat baseline: "All values are indices against a reference
/// Warden: ATK 100 · HP 100 · Move 3.20 u/s · Fire rate 2.20 /s."
///
/// These are level-1, star-0 values. `HeroLeveling` (docs/04 §4.3) scales them
/// up from here; this class only ever holds the authored baseline.
class HeroStatBlock {
  const HeroStatBlock({
    required this.atk,
    required this.hp,
    required this.moveSpeed,
    required this.fireRate,
  });

  final double atk;
  final double hp;
  final double moveSpeed;
  final double fireRate;
}

/// A hero's passive or ultimate.
class HeroAbility {
  const HeroAbility({
    required this.name,
    required this.description,
    this.modifiers = const <StatModifier>[],
    this.behaviour,
  });

  final String name;

  /// Card text, exactly as the Hero screen shows it.
  final String description;

  /// The plain-stat part of the ability, if any.
  final List<StatModifier> modifiers;

  /// The coded part, if any. Most abilities have one — an ability that is
  /// purely a [StatModifier] list barely needs to be an "ability" rather than
  /// a base-stat bonus, and docs/07 does not author any hero that way.
  final HeroBehaviour? behaviour;
}

/// One of a talent node's two mutually exclusive branches.
///
/// docs/04 §4.3: "Each node is a choice of two mutually exclusive branches."
/// [key] is what `HeroState.talentChoices` stores ('a' or 'b'), matching the
/// order docs/07 lists each pair in.
class HeroTalentBranch {
  const HeroTalentBranch({
    required this.key,
    required this.name,
    required this.description,
    this.modifiers = const <StatModifier>[],
    this.behaviour,
  });

  final String key;
  final String name;
  final String description;
  final List<StatModifier> modifiers;
  final HeroBehaviour? behaviour;
}

/// One of a hero's three talent nodes.
///
/// docs/04 §4.3: nodes unlock at ★1 / ★3 / ★5 — "★3 and ★5 unlock the hero's
/// second and third talent." [starRequired] is that gate; a node is choosable
/// once `HeroState.stars >= starRequired`, and inert (no branch active) below
/// it.
class HeroTalentNode {
  const HeroTalentNode({
    required this.starRequired,
    required this.branches,
  });

  /// 1, 3, or 5.
  final int starRequired;

  /// Always exactly two — docs/04 §4.3's "choice of two". Validated by
  /// [HeroCatalogue].
  final List<HeroTalentBranch> branches;

  HeroTalentBranch? branch(String key) {
    for (final HeroTalentBranch b in branches) {
      if (b.key == key) return b;
    }
    return null;
  }
}

/// One of the 20 heroes.
class HeroDefinition {
  const HeroDefinition({
    required this.archetype,
    required this.id,
    required this.key,
    required this.name,
    required this.epithet,
    required this.rarity,
    required this.role,
    required this.stats,
    required this.unlock,
    required this.passive,
    required this.ultimate,
    required this.talents,
    this.strengths = '',
    this.weaknesses = '',
  });

  final HeroArchetype archetype;

  /// 1–20, matching docs/07's numbering. Synonymous with [archetype] but
  /// kept as its own field for the same reason `BoonDefinition.id` is: it is
  /// the stable number the document and the player both use, independent of
  /// how the archetype happens to be spelled in code.
  final int id;

  final String key;
  final String name;
  final String epithet;
  final HeroRarity rarity;

  /// Flavour classification from docs/07.5's roster matrix — "Generalist",
  /// "Area damage", "Confluence specialist". Display only; the mechanical
  /// coverage-audit promise it stands for is enforced by content review, not
  /// by code.
  final String role;

  final HeroStatBlock stats;
  final HeroUnlock unlock;
  final HeroAbility passive;
  final HeroAbility ultimate;

  /// Always exactly three, at star 1 / 3 / 5. Validated by [HeroCatalogue].
  final List<HeroTalentNode> talents;

  final String strengths;
  final String weaknesses;

  HeroTalentNode? talentAt(int star) {
    for (final HeroTalentNode n in talents) {
      if (n.starRequired == star) return n;
    }
    return null;
  }

  @override
  String toString() => '#$id $name, $epithet (${rarity.name})';
}
