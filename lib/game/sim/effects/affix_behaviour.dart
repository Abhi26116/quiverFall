/// The affixes whose mechanic cannot be expressed as a plain
/// [StatModifier]-shaped roll into an existing [StatChannel].
///
/// Sixteen of the seventeen affixes (docs/08-arrows.md §8.4; ADR 0012 on why
/// seventeen, not the doc's own stated eighteen) are a rolled value into one
/// existing channel — Sharpened is `damage`, Keen is `critChance`, Piercing
/// is a flat `pierce`, and so on. `AffixCatalogue` reads a numeric range
/// straight off those. Echoing alone needs code: "8-15 % chance to fire a
/// second arrow" is a proc rolled per shot, not a number `LoadoutResolver`
/// can add into a composed total.
enum AffixBehaviour {
  echoing,
}
