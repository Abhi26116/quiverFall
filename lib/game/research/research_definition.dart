/// The 12 Research Lab items of docs/04-upgrades.md §4.6 (Branches B and C
/// — Branch A, "Tier Gates", is the Spire's own per-node L20/L40/L60 gates,
/// already `SpireWorkshop.unlockTierBand`, not a discrete item here).
enum ResearchArchetype {
  // ── Branch B — Systemic unlocks (one-time, permanent, powerful) ───────────
  secondLoadout,
  boonBanking,
  shrineLedger,
  windlineMemory,
  doubleDraw,
  elementalCodex,
  deepDescent,

  // ── Branch C — Quality of life ─────────────────────────────────────────────
  autoClaimChests,
  skipRunIntro,
  damageNumberToggle,
  extraVigorNotification,
  combatLog,
}

enum ResearchBranch {
  /// "Consumes ~70% of lifetime Insight. Deliberately the boring-but-
  /// necessary sink." — the Spire's own tier gates, not a catalogue entry.
  tierGates,

  /// One-time, permanent, powerful.
  systemic,

  /// Cheap, unlocked early, deliberately not monetised.
  qualityOfLife,
}

/// One Research Lab item.
class ResearchDefinition {
  const ResearchDefinition({
    required this.archetype,
    required this.id,
    required this.key,
    required this.name,
    required this.branch,
    required this.insightCost,
    required this.description,
    this.implemented = true,
    this.balanceNote = '',
  });

  /// 1-12, in docs/04's own table order (Branch B first, then Branch C).
  final int id;

  final ResearchArchetype archetype;
  final String key;
  final String name;
  final ResearchBranch branch;

  /// One-time Insight cost. Zero for the one free item (damage-number
  /// toggle) — still tracked through `ResearchState.completedIds` like
  /// every other item, rather than treated as always-unlocked, so a single
  /// "has this research?" check works uniformly regardless of price.
  final int insightCost;

  final String description;

  /// False for an item with no live effect yet — real, purchasable content,
  /// with its own specific, checked reason in [balanceNote]. See ADR 0093.
  final bool implemented;

  final String balanceNote;

  @override
  String toString() => '#$id $name';
}
