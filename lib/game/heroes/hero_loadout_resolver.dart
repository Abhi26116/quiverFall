import 'package:quiverfall/data/models/inventory.dart';
import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/arrows/affix_catalogue.dart';
import 'package:quiverfall/game/arrows/affix_definition.dart';
import 'package:quiverfall/game/arrows/arrow_definition.dart';
import 'package:quiverfall/game/arrows/arrow_refinement.dart';
import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/boons/boon_inventory.dart';
import 'package:quiverfall/game/boons/loadout_resolver.dart';
import 'package:quiverfall/game/heroes/hero_definition.dart';
import 'package:quiverfall/game/marks/mark_catalogue.dart';
import 'package:quiverfall/game/sim/draw_state.dart';
import 'package:quiverfall/game/sim/effects/affix_behaviour.dart';
import 'package:quiverfall/game/sim/effects/boon_stats.dart';
import 'package:quiverfall/game/sim/effects/hero_behaviour.dart';
import 'package:quiverfall/game/sim/effects/hero_runtime.dart';
import 'package:quiverfall/game/sim/effects/stat_channel.dart';
import 'package:quiverfall/game/sim/entity.dart';
import 'package:quiverfall/game/sim/world.dart';
import 'package:quiverfall/game/spire/spire_catalogue.dart';
import 'package:quiverfall/game/spire/spire_definition.dart';

/// Turns an equipped hero and arrow into the same [SimWorld] fields
/// [LoadoutResolver] already writes for Boons.
///
/// **The reuse is deliberate, not a resemblance.** docs/04 §4.1 rule 1 says a
/// source sums its own bonuses and sources multiply against each other, but
/// the only quantities the master formula (docs/04 §4.1) names as their own
/// multiplicative anchors are `heroBase(lvl)` and `arrowMult` — the two
/// numbers folded into [baseAttack] below. A hero passive's "+8 % crit
/// chance" or an arrow's "+2 pierce" is not a named anchor; it is the same
/// kind of fact as a Boon that grants the same channel, so it is merged into
/// the identical [StatChannel] bucket a Boon would use, via the same
/// `isMultiplicative ? multiplyBy : add` rule [BoonInventory] already applies
/// to every [BoonModifier]. One accumulation space for "the build", not two
/// parallel ones that would need their own composition rule — the Spire's
/// own thirteen non-attack nodes join it exactly this way (ADR 0092);
/// Research will too, the day it exists. Warden's Might, the Spire's own
/// attack node, is the one exception: docs/04 §4.1 names `spireMight` as
/// ATK's own separate multiplicative term, so it folds into `baseAttack`
/// directly instead.
///
/// Talent branches below the hero's current star, or at a star with no
/// choice made yet, contribute nothing — [HeroState.talentChoices] has no
/// default, and a node with no choice is inert rather than defaulted to
/// branch 'a'.
///
/// Call whenever the hero's level, stars, talent choices, equipped arrow or
/// its refine level changes — the same "on build change, not per tick"
/// contract [LoadoutResolver.apply] documents. Swapping to a *different*
/// hero or arrow entirely is a bigger change than this resolves: the caller
/// should call `world.hero.reset()` first, so a stale ultimate charge or
/// Rekindle flag never survives onto an unrelated kit.
abstract final class HeroLoadoutResolver {
  /// Returns the four `base*` values it just composed and handed to
  /// [LoadoutResolver.apply] — the hero+arrow baseline every *later*
  /// Boon-only recomposition (a pick, mid-run) needs to apply on top of
  /// instead of a hero-blind placeholder. `void` until ADR 0090: nothing
  /// downstream of the very first call ever saw these again, which is
  /// exactly the bug that ADR fixes. A caller driving a `StageRunner`
  /// should forward this straight to its own `setBaseLoadout(...)`.
  static ({
    double baseAttack,
    double baseFireRateMultiplier,
    double baseMaxHealth,
    double baseMoveSpeed,
  }) apply(
    SimWorld world,
    HeroDefinition hero,
    HeroState heroState,
    ArrowDefinition arrow,
    ArrowInstance arrowInstance, {
    BoonInventory? boons,
    AffixCatalogue? affixes,
    SpireCatalogue? spire,
    SpireState? spireState,
    MarkCatalogue? marks,
    List<String>? equippedMarkKeys,
  }) {
    final double heroAtk =
        Curves.heroStat(hero.stats.atk, heroState.level, heroState.stars);
    final double heroHp =
        Curves.heroStat(hero.stats.hp, heroState.level, heroState.stars);
    final double heroMoveSpeed = Curves.heroStat(
        hero.stats.moveSpeed, heroState.level, heroState.stars);
    final double heroFireRate = Curves.heroStat(
        hero.stats.fireRate, heroState.level, heroState.stars);

    final double arrowBaseMult = arrow.baseMult *
        ArrowRefinement.baseMultMultiplier(arrowInstance.refineLevel);

    final BoonStats combined = BoonStats();
    if (boons != null) combined.copyFrom(boons.stats);

    final List<bool> heroActive =
        List<bool>.filled(HeroBehaviour.values.length, false);

    void applyAbility(HeroAbility ability) {
      for (final StatModifier m in ability.modifiers) {
        _compose(combined, m);
      }
      final HeroBehaviour? b = ability.behaviour;
      if (b != null) heroActive[b.index] = true;
    }

    applyAbility(hero.passive);
    applyAbility(hero.ultimate);

    for (final HeroTalentNode node in hero.talents) {
      if (heroState.stars < node.starRequired) continue;
      final String? chosenKey = heroState.talentChoices['${node.starRequired}'];
      if (chosenKey == null) continue;
      final HeroTalentBranch? branch = node.branch(chosenKey);
      if (branch == null) continue;

      for (final StatModifier m in branch.modifiers) {
        _compose(combined, m);
      }
      final HeroBehaviour? b = branch.behaviour;
      if (b != null) heroActive[b.index] = true;
    }

    for (final StatModifier m in arrow.modifiers) {
      _compose(combined, m);
    }

    // Rolled affixes — sixteen of the seventeen are a value into an
    // existing channel, composed exactly like an arrow's own modifiers
    // just above; Echoing alone has no channel and is read directly onto
    // `HeroRuntime.echoChance` instead, the same "per-build number read
    // once at loadout time" shape `chargePerDamage` already uses.
    double echoChance = 0;
    if (affixes != null) {
      for (final Affix rolled in arrowInstance.affixes) {
        final AffixDefinition? def = affixes.byKey(rolled.affixId);
        if (def == null) continue;
        final StatChannel? channel = def.channel;
        if (channel != null) {
          _compose(combined, StatModifier(channel, rolled.value));
        } else if (def.behaviour == AffixBehaviour.echoing) {
          echoChance += rolled.value;
        }
      }
    }

    // The Spire — docs/04 §4.1's own ATK formula names `spireMight` as its
    // own multiplicative term, so it multiplies into `baseAttack` directly
    // rather than joining `combined`; every other node this build already
    // wires composes into `combined` exactly like a hero talent or an
    // arrow modifier does — see ADR 0092.
    double spireMight = 0;
    if (spire != null && spireState != null) {
      for (final SpireNodeDefinition node in spire.all) {
        final int level = spireState.levelOf(node.id);
        if (level <= 0) continue;
        spireMight += node.attackFractionAt(level);
        final StatModifier? contribution = node.contributionAt(level);
        if (contribution != null) _compose(combined, contribution);
      }
    }

    // Marks — every wired one composes into `combined` the same way a
    // Spire node or hero talent does; none of the nine named Marks is its
    // own separate multiplicative ATK term the way Warden's Might is, so
    // there is no equivalent of `spireMight` to fold into `baseAttack`
    // here. See ADR 0095.
    if (marks != null && equippedMarkKeys != null) {
      for (final String key in equippedMarkKeys) {
        final mark = marks.byKey(key);
        if (mark == null) continue;
        for (final StatModifier m in mark.contribution()) {
          _compose(combined, m);
        }
      }
    }

    LoadoutResolver.apply(
      world,
      combined,
      inventory: boons,
      baseAttack: heroAtk * arrowBaseMult * (1 + spireMight),
      // `DrawTier.one.fireRate` (2.2) is docs/07 §7.0's own reference fire
      // rate — the same 2.20 a level-1, star-0 hero's stat block is indexed
      // against. Dividing by it turns the hero's absolute fire-rate stat into
      // the multiplier `LoadoutResolver` expects on top of the Draw tier's
      // own base rate.
      baseFireRateMultiplier: heroFireRate / DrawTier.one.fireRate,
      baseMaxHealth: heroHp,
      baseMoveSpeed: heroMoveSpeed,
    );

    // The equipped arrow's element, if any — Prismshaft and Attunement-style
    // rotation aside, this is the one thing every arrow contributes that
    // isn't a StatModifier or a behaviour flag.
    world.arrowElement = arrow.element;

    world.hero
      ..setHeroActive(heroActive)
      ..setArrowActive(arrow.behaviour)
      ..echoChance = echoChance
      // ADR 0006: the hero's own base ATK and fire rate, not the composed
      // build — Boons and the arrow change how fast damage adds up, not how
      // fast that damage fills the bar. `ultimateChargeRate` is the one
      // exception ADR 0006 doesn't cover: a talent that names the charge
      // meter itself (Lira's Bloom Speed) is adjusting the bar, not the
      // damage, so it multiplies in here rather than being read from combat.
      ..chargePerDamage = combined.multiplierFor(StatChannel.ultimateChargeRate) /
          (HeroRuntime.ultimateChargeDivisor * heroAtk * heroFireRate);

    _syncZeaSkyhawk(world, heroActive);

    return (
      baseAttack: heroAtk * arrowBaseMult * (1 + spireMight),
      baseFireRateMultiplier: heroFireRate / DrawTier.one.fireRate,
      baseMaxHealth: heroHp,
      baseMoveSpeed: heroMoveSpeed,
    );
  }

  /// Zea's own *Skyhawk* passive (docs/07 §7.3) — a permanent companion,
  /// re-synced every time a build change calls [apply], the same "on
  /// build change, not per tick" contract this whole function already
  /// documents. Idempotent by construction: any permanent companion
  /// (`CompanionStore.remaining == double.infinity`) a previous call
  /// granted is despawned first, so a level-up or a star-up mid-run
  /// replaces the hawk(s) with fresh numbers rather than accumulating
  /// duplicates — a temporary Falconry/Hall of Mirrors summon, whose own
  /// `remaining` is always finite, is never touched by this sweep.
  ///
  /// *Falconry* (the Ultimate) and its own ★5 pair (Skydarken, Great
  /// Hawk) are not built here — those summon *temporary* companions on
  /// demand, the same "fire the Ultimate" dispatch every other hero's own
  /// Ultimate already uses, a separate piece of work. *Sharper Talons*
  /// (★1a), *Swift Hawk* (★1b) and *Bonded* (★3a) all read as blanket
  /// "your hawks are better" rules rather than Falconry-specific ones, so
  /// they apply here too; *Flock* (★3b) explicitly names "2 *permanent*
  /// hawks," so it belongs here and only here. See ADR 0072.
  static void _syncZeaSkyhawk(SimWorld world, List<bool> heroActive) {
    final EntityStore store = world.entities;

    for (int i = 0; i < store.highWater; i++) {
      if (store.alive[i] == 0) continue;
      if (store.kind[i] != EntityKind.companion.index) continue;
      if (world.companions.remaining[i] == double.infinity) {
        store.despawn(store.idAt(i));
      }
    }

    if (!heroActive[HeroBehaviour.zeaSkyhawk.index]) return;
    if (world.player.isNone || !store.isAlive(world.player)) return;

    final double x = store.posX[world.player.index];
    final double y = store.posY[world.player.index];
    final double fireRate = heroActive[HeroBehaviour.zeaSwiftHawk.index]
        ? _zeaSwiftHawkFireRate
        : _zeaBaseFireRate;
    final bool bonded = heroActive[HeroBehaviour.zeaBonded.index];

    if (heroActive[HeroBehaviour.zeaFlock.index]) {
      world.spawnCompanion(x, y,
          damageShare: _zeaFlockShare,
          fireRate: fireRate,
          alwaysCrit: bonded,
          followOffsetX: -0.8,
          followOffsetY: -0.6);
      world.spawnCompanion(x, y,
          damageShare: _zeaFlockShare,
          fireRate: fireRate,
          alwaysCrit: bonded,
          followOffsetX: 0.8,
          followOffsetY: -0.6);
      return;
    }

    final double damageShare = heroActive[HeroBehaviour.zeaSharperTalons.index]
        ? _zeaSharperTalonsShare
        : _zeaBaseDamageShare;
    world.spawnCompanion(x, y,
        damageShare: damageShare,
        fireRate: fireRate,
        alwaysCrit: bonded,
        followOffsetX: 0.7,
        followOffsetY: -0.6);
  }

  /// docs/07's own stated numbers.
  static const double _zeaBaseDamageShare = 0.35;
  static const double _zeaSharperTalonsShare = 0.50;
  static const double _zeaFlockShare = 0.25;
  static const double _zeaBaseFireRate = 1.5;
  static const double _zeaSwiftHawkFireRate = 2.4;

  /// The same add-or-multiply rule [BoonInventory] applies to every
  /// [BoonModifier], reused verbatim so a hero's "+12 % crit damage" and a
  /// Boon's "+15 % crit damage" compose identically.
  static void _compose(BoonStats stats, StatModifier m) {
    if (m.channel.isMultiplicative) {
      stats.multiplyBy(m.channel, m.value);
    } else {
      stats.add(m.channel, m.value);
    }
  }
}
