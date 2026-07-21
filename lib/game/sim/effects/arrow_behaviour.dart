/// The arrows whose mechanic cannot be expressed as a [StatModifier].
///
/// Most of the 12 are plain numbers — Broadhead is a `fireRate` penalty and a
/// higher `baseMult`, Lancehead is `pierce` and `projectileSpeed`. Splitshaft
/// reuses the same `extraArrows` channel a Boon-driven volley already does.
/// This enum exists only for the four that genuinely change how a shot
/// behaves rather than how big it is.
enum ArrowBehaviour {
  /// Skimmer: ricochets twice off walls or enemies; each ricochet lays its
  /// own Windline. The highest lattice-generation arrow in the game.
  skimmerRicochet,

  /// Twinfang: fires two arrows on converging paths that cross at 6 u — a
  /// guaranteed Confluence every shot, rather than one found by threading a
  /// trail. docs/08 §8.5 rule 4: this must never reach the ceiling a skilled
  /// manual player can reach, only ever a reliable floor.
  twinfangConverging,

  /// Ghostshaft: passes through walls and shields, ignores plating entirely.
  /// No pierce falloff to converge — the trade is an 8 u range cap instead.
  ghostshaftPhase,

  /// Prismshaft: cycles all four elements, one per shot, in a fixed rotation.
  /// The same idea as Oriel's *Spectrum* passive, kept as its own entry
  /// because an arrow and a hero passive are different sources composing
  /// into the same loadout, not the same fact told twice.
  prismshaftCycle,
}
