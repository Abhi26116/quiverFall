import 'dart:typed_data';

import 'package:quiverfall/game/sim/sim_config.dart';

/// Per-projectile data, indexed by entity slot.
///
/// Kept out of [EntityStore] because only a fraction of entities are
/// projectiles, and mixing rarely-used arrays into the hot component set hurts
/// the cache locality that struct-of-arrays exists to buy.
///
/// Sized to the entity capacity so it can be indexed directly by slot with no
/// mapping — a lookup table would cost an indirection on the hottest path in
/// the game.
class ProjectileStore {
  ProjectileStore({int capacity = SimConfig.maxEntities})
      : _capacity = capacity,
        damage = Float64List(capacity),
        pierceRemaining = Int32List(capacity),
        drawTier = Uint8List(capacity),
        elementalBonus = Float64List(capacity),
        confluenceBonus = Float64List(capacity),
        lifetime = Float64List(capacity),
        hitCount = Int32List(capacity),
        _hits = Int32List(capacity * maxTrackedHits);

  /// How many distinct targets one arrow remembers striking.
  ///
  /// An arrow that pierces more than this may re-hit an earlier target. That is
  /// a deliberate, documented ceiling rather than an unbounded set: tracking is
  /// fixed-size to stay allocation-free, and by the twelfth target pierce
  /// falloff has already reduced damage to ~14%, so a rare double-hit at that
  /// depth is beneath notice. Unbounded pierce (Boon 25, *The Long Arrow*) is
  /// the only build that reaches here.
  static const int maxTrackedHits = 12;

  final int _capacity;

  /// Pre-resolved attack value for this arrow, computed once at fire time.
  /// Resolving the full chain per *hit* would repeat work that cannot change
  /// mid-flight.
  final Float64List damage;

  final Int32List pierceRemaining;

  /// The Draw tier this arrow was fired at. Needed at impact to decide whether
  /// it breaks a Carapace plate — the arrow carries its tier, it is not read
  /// from the shooter's current state, because the shooter may have moved and
  /// dropped to Tier I while the arrow is still in flight.
  final Uint8List drawTier;

  final Float64List elementalBonus;
  final Float64List confluenceBonus;

  /// Seconds remaining before the arrow despawns.
  final Float64List lifetime;

  final Int32List hitCount;
  final Int32List _hits;

  // ── Confluence ────────────────────────────────────────────────────────────

  /// Serial of the Windline this arrow is itself laying. Every Confluence test
  /// requires strictly-older segments, and this is what "older" is measured
  /// against.
  final Int32List windlineSerial = Int32List(SimConfig.maxEntities);

  /// Stacks accumulated so far in flight.
  final Int32List confluenceStacks = Int32List(SimConfig.maxEntities);

  /// Distinct element indices picked up from crossed lines, packed as a bitmask.
  /// Three or more distinct elements collapse to Prismbreak.
  final Int32List confluenceElementMask = Int32List(SimConfig.maxEntities);

  /// The element this arrow itself carries, or -1.
  final Int8List element = Int8List(SimConfig.maxEntities);

  /// This arrow's own trail id. Every segment it lays carries this, so another
  /// arrow crossing the trail counts it once.
  final Int32List trailId = Int32List(SimConfig.maxEntities);

  /// Total distance this arrow has flown.
  ///
  /// Gates Confluence eligibility. See [ConfluenceTuning.minThreadDistance].
  final Float64List distanceFlown = Float64List(SimConfig.maxEntities);

  /// Every element this arrow carries, as a bitmask over [SimElement.index].
  ///
  /// Almost every arrow carries zero or one element, which [element] already
  /// says. The mask exists for the four Boons that carry several at once —
  /// *Frostfire* (#91), *Stormblight* (#92), *The Fourfold* (#93) and
  /// *Elemental Overload* (#90). A mask rather than a list because it costs one
  /// byte per arrow and nothing at all on the arrows that do not use it.
  final Uint8List elementMask = Uint8List(SimConfig.maxEntities);

  /// Whether this arrow rolled a critical hit.
  ///
  /// Rolled once, at release, rather than per target. An arrow that crit its
  /// first victim and not its second would make crit unreadable on a piercing
  /// shot, and would put an RNG call in the hit loop.
  final Uint8List wasCrit = Uint8List(SimConfig.maxEntities);

  /// Torv's *Arc*: set at release for every 5th (or 3rd, with Frequent Arc)
  /// arrow, exactly like [wasCrit] — decided once at the bow, remembered
  /// until the arrow lands, since a chain has to trigger on whichever hit
  /// actually happens, not on whichever hit happens to be resolving first.
  final Uint8List willChain = Uint8List(SimConfig.maxEntities);

  /// Kestrel's *Bleed*: set at release for every 4th arrow, the exact same
  /// "decided once at the bow" shape [willChain] already uses for Torv's
  /// own Arc mark — a proc rolled/counted per shot must apply to whichever
  /// hit that specific shot eventually lands, not to whichever hit happens
  /// to resolve first.
  final Uint8List willBleed = Uint8List(SimConfig.maxEntities);

  /// Halden's *Sentence* (T3a): set at release only for the Judgment
  /// Spear's own arrow(s), the exact "decided once at the bow" shape
  /// [willChain]/[willBleed] already use — the boss actually struck gets
  /// marked, not whichever target happened to be selected at fire time.
  final Uint8List willMarkBoss = Uint8List(SimConfig.maxEntities);

  /// Bram's *Incendiary* (T3b): "splash applies Burn at 40%," rolled once
  /// at release — the same "decided once at the bow" shape [willChain]/
  /// [willBleed] already use, and for the identical reason: this arrow's
  /// splash either ignites every enemy it catches or none of them, decided
  /// before flight rather than re-rolled per enemy inside the splash's own
  /// hit loop.
  final Uint8List willIgniteSplash = Uint8List(SimConfig.maxEntities);

  /// Set at spawn only for an arrow fired by the hero's own Ultimate — so
  /// far only Wren's *Volley Fan*. Two talents read it: *Warden's Lattice*
  /// (T5a) via [windlineDurationOverride] below, and *Warden's Fury* (T5b,
  /// "refunds 30 % charge on kill") via `EnemyStore.lastHitWasUltimate`,
  /// written wherever this arrow's own hit resolves and read at
  /// `AiSystem`'s own death pass — a kill needs to know which arrow struck
  /// last, not merely that one of this shape existed somewhere in flight.
  final Uint8List isUltimateArrow = Uint8List(SimConfig.maxEntities);

  /// Above zero, replaces the ambient `windlineDuration` for every segment
  /// this specific arrow lays — *Warden's Lattice* (Wren, T5a, "Ultimate
  /// Windlines last 4 s"). Baked in once at spawn rather than read from
  /// [isUltimateArrow] plus a live hero check at each lay site: a segment
  /// can be laid many ticks after the arrow was fired, and this way
  /// neither lay site needs a `HeroRuntime` reference just to ask "was
  /// Lattice active when this arrow left the bow."
  final Float64List windlineDurationOverride = Float64List(SimConfig.maxEntities);

  /// Skimmer: bounces left off a wall or an enemy, shared between the two —
  /// docs/08 says "ricochets 2x", not "2x each". Set to 2 at spawn only for
  /// a Skimmer arrow; every other arrow leaves this at 0 and is retired on
  /// its first wall hit or when pierce runs out, same as before this arrow
  /// existed.
  final Int32List ricochetsLeft = Int32List(SimConfig.maxEntities);

  /// Set the moment this arrow's first ricochet happens (wall or enemy),
  /// and never cleared again for the rest of its flight — Corvin's own
  /// *Hard Bounce* ("a ricochet deals 120 %") and *Perfect Carom* ("during
  /// Caroms, ricochets never lose damage") both key off this rather than
  /// off [ricochetsLeft] being below its starting grant, since a Skimmer
  /// arrow with no Corvin bonuses equipped still ricochets and this stays
  /// meaningless for it either way.
  final Uint8List hasRicocheted = Uint8List(SimConfig.maxEntities);

  /// Distance flown since the last Windline segment was emitted.
  ///
  /// Segments are emitted per distance travelled rather than per tick. Per-tick
  /// emission produced ~120 segments for a two-second flight, which filled the
  /// 1024-segment ring in a handful of shots and pushed the Confluence sweep to
  /// 1.82 ms on device against a 0.8 ms budget.
  final Float64List sinceLastSegment = Float64List(SimConfig.maxEntities);

  final Int32List crossedCount = Int32List(SimConfig.maxEntities);
  final Int32List _crossed =
      Int32List(SimConfig.maxEntities * maxTrackedCrossings);

  /// How many distinct Windline serials an arrow remembers crossing.
  ///
  /// Sized just above the highest reachable stack count (5, for Iris) so an
  /// arrow cannot farm repeat stacks from one line while travelling nearly
  /// parallel to it.
  static const int maxTrackedCrossings = 8;

  void reset(int slot) {
    elementMask[slot] = 0;
    wasCrit[slot] = 0;
    willChain[slot] = 0;
    willBleed[slot] = 0;
    damage[slot] = 0;
    pierceRemaining[slot] = 0;
    drawTier[slot] = 0;
    elementalBonus[slot] = 0;
    confluenceBonus[slot] = 0;
    lifetime[slot] = 0;
    hitCount[slot] = 0;
    windlineSerial[slot] = 0;
    confluenceStacks[slot] = 0;
    confluenceElementMask[slot] = 0;
    element[slot] = -1;
    trailId[slot] = 0;
    sinceLastSegment[slot] = 0;
    distanceFlown[slot] = 0;
    crossedCount[slot] = 0;
    ricochetsLeft[slot] = 0;
    hasRicocheted[slot] = 0;
    willMarkBoss[slot] = 0;
    willIgniteSplash[slot] = 0;
    isUltimateArrow[slot] = 0;
    windlineDurationOverride[slot] = 0;
  }

  bool hasCrossed(int slot, int serial) {
    final int n = crossedCount[slot];
    final int base = slot * maxTrackedCrossings;
    for (int i = 0; i < n; i++) {
      if (_crossed[base + i] == serial) return true;
    }
    return false;
  }

  void recordCrossing(int slot, int serial) {
    final int n = crossedCount[slot];
    if (n >= maxTrackedCrossings) return;
    _crossed[slot * maxTrackedCrossings + n] = serial;
    crossedCount[slot] = n + 1;
  }

  /// The raw crossed-serial array, for the sweep's dedupe pass.
  ///
  /// Exposed directly, with [crossedBase] as the offset, rather than as a
  /// sublist or an Iterable view: `getRange`, `sublist`, and `where` all
  /// allocate, and this is read once per arrow per tick.
  Int32List get crossedRaw => _crossed;

  int crossedBase(int slot) => slot * maxTrackedCrossings;

  /// True if this arrow has already struck [targetId].
  ///
  /// Stores the full generation-tagged handle, not the slot index, so an arrow
  /// cannot be fooled into skipping a *new* enemy that happens to have recycled
  /// a dead one's slot.
  bool hasHit(int slot, int targetId) {
    final int n = hitCount[slot];
    final int base = slot * maxTrackedHits;
    for (int i = 0; i < n; i++) {
      if (_hits[base + i] == targetId) return true;
    }
    return false;
  }

  void recordHit(int slot, int targetId) {
    final int n = hitCount[slot];
    if (n >= maxTrackedHits) return;
    _hits[slot * maxTrackedHits + n] = targetId;
    hitCount[slot] = n + 1;
  }

  int get capacity => _capacity;
}
