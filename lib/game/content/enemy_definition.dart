/// Enemy families, from docs/05-enemies.md.
///
/// The family is a real gameplay concept, not a taxonomy: it drives the shared
/// AI behaviour tree, the shared audio timbre, the silhouette colour, and the
/// room composition rules (e.g. "at least 40% of the threat budget must be
/// Drift or Rush", "max 2 Choir units per room").
enum EnemyFamily {
  /// Slow, dumb, numerous. The canvas the player paints Windlines on.
  drift,

  /// The armour puzzle. Only Draw tiers II/III break through.
  carapace,

  /// The movement tax. A timer on how long you may stand still.
  rush,

  /// The position tax. Forces you to move somewhere *specific*.
  salvo,

  /// Never dangerous alone. Makes everything else dangerous.
  choir,

  /// Elites.
  riftborn,
}

/// The 26 enemies of docs/05-enemies.md, one value each.
///
/// **This enum is the enemy's identity, not a label on it.** The content table's
/// `id` field is parsed straight into an archetype, so an enemy that is not
/// listed here cannot be authored, and an archetype with no behaviour branch
/// cannot be shipped — both failures are caught by
/// `test/game/enemy_content_test.dart` rather than by a player in chapter 7.
///
/// Behaviour *switches* live here (which branch of which family tree runs);
/// behaviour *numbers* live in `assets/data/enemies.json`. That split is what
/// keeps live-ops retuning safe: remote config may change how hard a Lancer
/// charges, never whether it charges at all.
enum EnemyArchetype {
  // ── Drift ─────────────────────────────────────────────────────────────────
  mote(EnemyFamily.drift),
  swarmling(EnemyFamily.drift),
  wisp(EnemyFamily.drift),
  cinderMote(EnemyFamily.drift),

  // ── Carapace ──────────────────────────────────────────────────────────────
  husk(EnemyFamily.carapace),
  bulwark(EnemyFamily.carapace),
  shellback(EnemyFamily.carapace),
  ironmaw(EnemyFamily.carapace),

  // ── Rush ──────────────────────────────────────────────────────────────────
  lancer(EnemyFamily.rush),
  stalker(EnemyFamily.rush),
  bounder(EnemyFamily.rush),
  ripper(EnemyFamily.rush),
  thresher(EnemyFamily.rush),

  // ── Salvo ─────────────────────────────────────────────────────────────────
  spitter(EnemyFamily.salvo),
  nettle(EnemyFamily.salvo),
  longeye(EnemyFamily.salvo),
  mortarite(EnemyFamily.salvo),
  screecher(EnemyFamily.salvo),

  // ── Choir ─────────────────────────────────────────────────────────────────
  weaver(EnemyFamily.choir),
  chanter(EnemyFamily.choir),
  knitter(EnemyFamily.choir),
  wardenFell(EnemyFamily.choir),

  // ── Riftborn ──────────────────────────────────────────────────────────────
  riftMaw(EnemyFamily.riftborn),
  echo(EnemyFamily.riftborn),
  gravebound(EnemyFamily.riftborn),

  /// Displayed as "Null"; spelled out here because `null` is a Dart keyword.
  nullborn(EnemyFamily.riftborn);

  const EnemyArchetype(this.family);

  final EnemyFamily family;
}

/// Behavioural numbers for one enemy.
///
/// Every value is optional and defaults to zero-meaning-absent, so an enemy
/// authors only the fields its archetype actually reads. A Mote's combat block
/// is empty; a Longeye's is not.
///
/// Damage values are **fractions of the player's max HP**, never flat numbers —
/// docs/05 §5.0. That is the only way to keep threat constant across a 300x
/// power curve, and it means one number per enemy covers the whole game.
class EnemyCombat {
  const EnemyCombat({
    this.attackDamage = 0,
    this.attackCooldown = 0,
    this.attackRange = 0,
    this.contactCooldown = defaultContactCooldown,
    this.windUpSeconds = 0,
    this.heavyWindUpSeconds = 0,
    this.trackingCutoffSeconds = 0,
    this.recoverySeconds = 0,
    this.flightSeconds = 0,
    this.projectileSpeed = 0,
    this.projectileCount = 0,
    this.spreadDegrees = 0,
    this.areaRadius = 0,
    this.lingerSeconds = 0,
    this.lingerDamage = 0,
    this.chargeSpeed = 0,
    this.chargeDistance = 0,
    this.keepDistance = 0,
    this.turnRateDegrees = 0,
    this.auraRadius = 0,
    this.auraStrength = 0,
    this.drawLockSeconds = 0,
    this.immunitySeconds = 0,
    this.deathBlastDamage = 0,
    this.deathBlastRadius = 0,
    this.reviveCount = 0,
    this.reviveHealthFraction = 0,
    this.reviveSpeedBonus = 0,
    this.spawnsId,
    this.spawnCount = 0,
    this.spawnCap = 0,
  });

  factory EnemyCombat.fromJson(Map<String, dynamic> json) {
    double num_(String key, [double fallback = 0]) =>
        (json[key] as num?)?.toDouble() ?? fallback;

    return EnemyCombat(
      attackDamage: num_('attackDamage'),
      attackCooldown: num_('attackCooldown'),
      attackRange: num_('attackRange'),
      contactCooldown: num_('contactCooldown', defaultContactCooldown),
      windUpSeconds: num_('windUpSeconds'),
      heavyWindUpSeconds: num_('heavyWindUpSeconds'),
      trackingCutoffSeconds: num_('trackingCutoffSeconds'),
      recoverySeconds: num_('recoverySeconds'),
      flightSeconds: num_('flightSeconds'),
      projectileSpeed: num_('projectileSpeed'),
      projectileCount: (json['projectileCount'] as num?)?.toInt() ?? 0,
      spreadDegrees: num_('spreadDegrees'),
      areaRadius: num_('areaRadius'),
      lingerSeconds: num_('lingerSeconds'),
      lingerDamage: num_('lingerDamage'),
      chargeSpeed: num_('chargeSpeed'),
      chargeDistance: num_('chargeDistance'),
      keepDistance: num_('keepDistance'),
      turnRateDegrees: num_('turnRateDegrees'),
      auraRadius: num_('auraRadius'),
      auraStrength: num_('auraStrength'),
      drawLockSeconds: num_('drawLockSeconds'),
      immunitySeconds: num_('immunitySeconds'),
      deathBlastDamage: num_('deathBlastDamage'),
      deathBlastRadius: num_('deathBlastRadius'),
      reviveCount: (json['reviveCount'] as num?)?.toInt() ?? 0,
      reviveHealthFraction: num_('reviveHealthFraction'),
      reviveSpeedBonus: num_('reviveSpeedBonus'),
      spawnsId: json['spawnsId'] as String?,
      spawnCount: (json['spawnCount'] as num?)?.toInt() ?? 0,
      spawnCap: (json['spawnCap'] as num?)?.toInt() ?? 0,
    );
  }

  /// Mote's 0.8 s. Fast fodder (Swarmling) overrides it downward.
  static const double defaultContactCooldown = 0.8;

  static const EnemyCombat none = EnemyCombat();

  /// The special attack's damage, as a fraction of player max HP.
  final double attackDamage;

  /// Seconds between special attacks, measured from the end of recovery.
  final double attackCooldown;

  /// How close the enemy must be before it will begin an attack. Zero means the
  /// enemy has no ranged option at all.
  final double attackRange;

  /// Minimum seconds between two contact hits on the same player.
  final double contactCooldown;

  /// Telegraph lead. **Every damaging attack in the game has one** — the
  /// telegraph precedes the threat, always (docs/05 §5.2, Ironmaw).
  final double windUpSeconds;

  /// Wind-up of a combo's *final* beat, which is always longer and always the
  /// one the player is meant to read. The Ripper's overhead third swing is the
  /// game's parry window (docs/05 §5.3); bosses reuse the same shape.
  final double heavyWindUpSeconds;

  /// How long before an attack lands that it stops tracking the player.
  ///
  /// The Longeye's beam follows for 0.8 s and commits for the last 0.4 s. An
  /// attack that tracks all the way to impact cannot be dodged, only outranged,
  /// which is a much poorer thing to ask of a player.
  final double trackingCutoffSeconds;

  /// Fully-vulnerable window after the attack. The player's punish.
  final double recoverySeconds;

  /// Travel time for a lobbed shell or a leap arc, which fly for a fixed
  /// duration to a fixed point rather than at a fixed speed.
  final double flightSeconds;

  /// Straight-line bolt speed, u/s.
  final double projectileSpeed;

  final int projectileCount;

  /// Total arc of a spread or a cone, in degrees.
  final double spreadDegrees;

  /// Blast, puddle or aura radius, u.
  final double areaRadius;

  /// How long a ground hazard persists.
  final double lingerSeconds;

  /// Ground-hazard damage per second, as a fraction of player max HP.
  final double lingerDamage;

  final double chargeSpeed;
  final double chargeDistance;

  /// Preferred stand-off distance for kiters and orbiters.
  final double keepDistance;

  /// Maximum turn rate, degrees per second. Zero means "turns instantly" —
  /// a real weakness where it is set, because it is what makes flanking work.
  final double turnRateDegrees;

  /// Support aura radius (Chanter, Knitter, Warden-Fell).
  final double auraRadius;

  /// What the aura is worth: +30% attack, 4%/s healing, 40% shield.
  final double auraStrength;

  /// Screecher only. Suppresses Draw tier gain; Momentum still works.
  final double drawLockSeconds;

  /// How long an adapted elemental immunity lasts (Null, docs/05 §5.6). The
  /// counter is element rotation — or Confluence, which applies two elements in
  /// one hit and beats the adaptation outright.
  final double immunitySeconds;

  final double deathBlastDamage;
  final double deathBlastRadius;

  final int reviveCount;
  final double reviveHealthFraction;
  final double reviveSpeedBonus;

  /// Content id of the adds this enemy summons.
  final String? spawnsId;
  final int spawnCount;

  /// Ceiling on this enemy's live adds. Uncapped summoning is how a procedural
  /// room turns into an unwinnable one.
  final int spawnCap;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    void put(String key, num value, [num skipIf = 0]) {
      if (value != skipIf) out[key] = value;
    }

    put('attackDamage', attackDamage);
    put('attackCooldown', attackCooldown);
    put('attackRange', attackRange);
    put('contactCooldown', contactCooldown, defaultContactCooldown);
    put('windUpSeconds', windUpSeconds);
    put('heavyWindUpSeconds', heavyWindUpSeconds);
    put('trackingCutoffSeconds', trackingCutoffSeconds);
    put('recoverySeconds', recoverySeconds);
    put('flightSeconds', flightSeconds);
    put('projectileSpeed', projectileSpeed);
    put('projectileCount', projectileCount);
    put('spreadDegrees', spreadDegrees);
    put('areaRadius', areaRadius);
    put('lingerSeconds', lingerSeconds);
    put('lingerDamage', lingerDamage);
    put('chargeSpeed', chargeSpeed);
    put('chargeDistance', chargeDistance);
    put('keepDistance', keepDistance);
    put('turnRateDegrees', turnRateDegrees);
    put('auraRadius', auraRadius);
    put('auraStrength', auraStrength);
    put('drawLockSeconds', drawLockSeconds);
    put('immunitySeconds', immunitySeconds);
    put('deathBlastDamage', deathBlastDamage);
    put('deathBlastRadius', deathBlastRadius);
    put('reviveCount', reviveCount);
    put('reviveHealthFraction', reviveHealthFraction);
    put('reviveSpeedBonus', reviveSpeedBonus);
    if (spawnsId != null) out['spawnsId'] = spawnsId;
    put('spawnCount', spawnCount);
    put('spawnCap', spawnCap);
    return out;
  }
}

/// A single enemy type, loaded from `assets/data/enemies.json`.
///
/// Values are multipliers and fractions, not absolutes — see docs/05 §5.0:
///
///  - [hpMultiplier] scales the base HP curve, so one number covers all 240
///    stages.
///  - [contactDamage] is a fraction of the player's *max* HP, which is the only
///    way to keep threat constant across a 300x power curve.
class EnemyDefinition {
  const EnemyDefinition({
    required this.archetype,
    required this.name,
    required this.hpMultiplier,
    required this.speed,
    required this.contactDamage,
    required this.radius,
    required this.threatCost,
    required this.goldWeight,
    required this.materialChance,
    this.combat = EnemyCombat.none,
    this.hasFrontalPlate = false,
    this.plateArcDegrees = defaultPlateArcDegrees,
    this.plateRegenSeconds = 0,
    this.introducedInChapter = 1,
  });

  factory EnemyDefinition.fromJson(Map<String, dynamic> json) {
    final Object? rawCombat = json['combat'];
    return EnemyDefinition(
      // The id *is* the archetype. One field, so an enemy's data and its
      // behaviour branch cannot drift apart.
      archetype: EnemyArchetype.values.byName(json['id'] as String),
      name: json['name'] as String,
      hpMultiplier: (json['hpMultiplier'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      contactDamage: (json['contactDamage'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      threatCost: (json['threatCost'] as num).toDouble(),
      goldWeight: (json['goldWeight'] as num).toDouble(),
      materialChance: (json['materialChance'] as num).toDouble(),
      combat: rawCombat is Map<String, dynamic>
          ? EnemyCombat.fromJson(rawCombat)
          : EnemyCombat.none,
      hasFrontalPlate: json['hasFrontalPlate'] as bool? ?? false,
      plateArcDegrees:
          (json['plateArcDegrees'] as num?)?.toDouble() ??
              defaultPlateArcDegrees,
      plateRegenSeconds: (json['plateRegenSeconds'] as num?)?.toDouble() ?? 0,
      introducedInChapter: (json['introducedInChapter'] as num?)?.toInt() ?? 1,
    );
  }

  /// Total arc the plate covers, centred on the enemy's facing. 150 degrees
  /// leaves a generous rear window, which is what makes "flank it" a move a
  /// player can actually execute on a phone.
  static const double defaultPlateArcDegrees = 150.0;

  final EnemyArchetype archetype;
  final String name;

  String get id => archetype.name;

  EnemyFamily get family => archetype.family;

  /// Multiplier on `Curves.enemyHp(globalStageIndex)`.
  final double hpMultiplier;

  /// World units per second. The player's base is 3.20, so anything above that
  /// can catch a fleeing player — a deliberate and rare property.
  final double speed;

  /// Fraction of player max HP per contact hit.
  final double contactDamage;

  final double radius;

  /// Cost against the room's threat budget.
  final double threatCost;

  /// Share of the room's gold payout.
  final double goldWeight;

  /// Probability of dropping a material on death.
  final double materialChance;

  final EnemyCombat combat;

  /// Front arc takes reduced damage below Draw tier III. The Carapace family's
  /// defining property and the reason the Draw mechanic exists.
  final bool hasFrontalPlate;

  final double plateArcDegrees;

  /// Seconds until a broken plate returns. Zero means it stays broken.
  final double plateRegenSeconds;

  final int introducedInChapter;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> combatJson = combat.toJson();
    return <String, dynamic>{
      'id': id,
      'name': name,
      'family': family.name,
      'hpMultiplier': hpMultiplier,
      'speed': speed,
      'contactDamage': contactDamage,
      'radius': radius,
      'threatCost': threatCost,
      'goldWeight': goldWeight,
      'materialChance': materialChance,
      if (hasFrontalPlate) 'hasFrontalPlate': hasFrontalPlate,
      if (hasFrontalPlate && plateArcDegrees != defaultPlateArcDegrees)
        'plateArcDegrees': plateArcDegrees,
      if (plateRegenSeconds != 0) 'plateRegenSeconds': plateRegenSeconds,
      if (combatJson.isNotEmpty) 'combat': combatJson,
      'introducedInChapter': introducedInChapter,
    };
  }
}
