/// Maps the numeric material tier [ArrowCraftCost.materialsByTier] and
/// [ArrowRefinement.materialTier] speak in onto the string keys
/// `Wallet.materials` (`lib/data/models/player_save.dart`) is keyed by.
///
/// docs/02 §2.1 names the four materials in tier order but never as
/// explicit lowercase ids — ADR 0013 §1 lowercases that listed order
/// verbatim rather than inventing a separate naming scheme.
abstract final class MaterialTier {
  static const List<String> _keysByTier = <String>[
    '', // index 0 unused — tiers are 1-indexed, matching the doc's own T1-T4.
    'ashwood',
    'ironhead',
    'skyfeather',
    'prismcore',
  ];

  static String keyFor(int tier) {
    assert(tier >= 1 && tier <= 4, 'material tier must be 1-4, got $tier');
    return _keysByTier[tier];
  }
}
