import 'package:quiverfall/game/balance/curves.dart';
import 'package:quiverfall/game/content/boss_definition.dart';
import 'package:quiverfall/game/content/content_library.dart';
import 'package:quiverfall/game/sim/sim_config.dart';
import 'package:quiverfall/game/sim/world.dart';

/// Which Endless Descent boss (docs/06 §6.3, #17-20) appears on a given
/// floor, and how to place one — the Endless tier's own equivalent of
/// [BossRoomComposer]/[EliteRoomComposer], following the identical "one
/// function decides who, one function places them, everything else generic"
/// shape (ADR 0021/0055/0067) now a fourth time.
///
/// **This is deliberately the whole of what Phase 11 owes the Endless
/// tier.** The Endless Descent *mode* itself — infinite floor generation, a
/// weekly global seed, Descent Modifiers every 5 floors, the Ascension gate
/// that unlocks it at all (docs/14 §14.7) — is explicitly Phase 13
/// ("Ascension: gate, projection screen, reset, Emberdust tree") and Phase
/// 17 ("Endless Descent with weekly seeds") work, both several phases past
/// where this session sits (`docs/20-roadmap.md`). Phase 11's own exit
/// criteria is narrower: "All 20 bosses beatable... each boss has a test."
/// [bossFor] and [spawn] are the one piece of that mode a boss-focused pass
/// can honestly build ahead of time — pure, deterministic resolution logic
/// with no floor-generation loop, save data, or UI behind it yet, ready for
/// Phase 17's own driver to call the exact way `LevelGenerator._assemble`
/// already calls [BossRoomComposer.bossFor]/[EliteRoomComposer.eliteFor].
/// No new game-mode infrastructure is attempted here.
///
/// **[bossFor]'s own floor pattern is read directly off each boss's own
/// card, not invented.** docs/14 §14.7: "Boss every 10 floors." Each of the
/// four cards then gives its own repeating floor list: The Loom "Floor 10,
/// 30, 50…" (every 20, starting at 10); Coilspine "Floor 20, 60…" (every 40,
/// starting at 20); Mother of Motes "Floor 40, 80…" (every 40, starting at
/// 40 — the complementary half of Coilspine's own every-40 cadence, so
/// together they cover every floor that is a multiple of 20 but not of 10
/// mod 20); The Last Warden "Floor 100, then every 50." The four patterns
/// partition every multiple of 10 with one deliberate overlap: floor 100
/// (and every 150/200/250… after it) would also satisfy Coilspine's own
/// "every 40 from 20" rule, so The Last Warden's own check runs first and
/// wins — "the true final boss" superseding the ordinary rotation as the
/// descent gets deep enough, not a bug in either pattern.
///
/// **Health reuses `Curves.endlessHp`, already built and unused until
/// now** (`lib/game/balance/curves.dart`, docs/14's own `HP × 1.09^floor`)
/// — the Endless tier's own enemy-HP baseline, scaled by the boss's own
/// `hpMultiplier` from `bosses.json`, the identical composition
/// `Curves.bossHp` already uses for a campaign boss's own `enemyHp(g) *
/// multiplier`. `encounterCount` (repeat-kill scaling) is left at 0 — the
/// same deliberate gap `BossRoomComposer.spawn`'s own doc comment already
/// carries for campaign bosses, since neither reads `PlayerSave`.
abstract final class EndlessBossComposer {
  /// The `BossArchetype` that should appear on [floor], or null if [floor]
  /// is not a multiple of 10 at all (docs/14 §14.7: "boss every 10
  /// floors").
  static BossArchetype? bossFor(int floor) {
    if (floor <= 0 || floor % 10 != 0) return null;

    // "Floor 100, then every 50" — checked first, since it also satisfies
    // Coilspine's own pattern below from floor 100 onward.
    if (floor >= 100 && (floor - 100) % 50 == 0) {
      return BossArchetype.lastWarden;
    }

    // "Floor 10, 30, 50…" — every 20, starting at 10.
    if (floor % 20 == 10) return BossArchetype.theLoom;

    // "Floor 20, 60…" — every 40, starting at 20.
    if (floor % 40 == 20) return BossArchetype.coilspine;

    // "Floor 40, 80…" — every 40, starting at 40 — the only case left.
    return BossArchetype.motherOfMotes;
  }

  /// The health an Endless-tier boss should spawn with on [floor], or 0 if
  /// [archetype] has no catalogue entry.
  static double healthFor({
    required int floor,
    required BossArchetype archetype,
    required ContentLibrary content,
  }) {
    final def = content.bosses.byArchetype(archetype);
    if (def == null) return 0;
    return Curves.endlessHp(floor) * def.hpMultiplier;
  }

  /// Places [archetype]'s boss and returns its primary slot, or -1 if
  /// nothing here knows how to spawn it — which [bossFor] should never
  /// actually let happen, since it only ever returns an archetype this
  /// function also handles.
  ///
  /// Spawns at the arena's own geometric centre, the same stand-in
  /// `BossRoomComposer.spawn`'s own doc comment already uses for every
  /// campaign and Elite/Event boss — no bespoke Endless arena exists
  /// either.
  static int spawn(SimWorld world, BossArchetype archetype, double health) {
    return switch (archetype) {
      BossArchetype.theLoom => world.spawnTheLoom(
          SimConfig.arenaWidth / 2,
          SimConfig.arenaHeight / 2,
          health: health,
        ),
      BossArchetype.coilspine => world.spawnCoilspine(
          SimConfig.arenaWidth / 2,
          SimConfig.arenaHeight / 2,
          health: health,
        ),
      BossArchetype.motherOfMotes => world.spawnMotherOfMotes(
          SimConfig.arenaWidth / 2,
          SimConfig.arenaHeight / 2,
          health: health,
        ),
      // `echoArchetypes` is left at its default (none) — resolving "the
      // three bosses beaten most often" from `Progression.bossKillCounts`
      // is a separate, still-open piece (ADR 0061), not attempted here.
      BossArchetype.lastWarden => world.spawnLastWarden(
          SimConfig.arenaWidth / 2,
          SimConfig.arenaHeight / 2,
          health: health,
        ),
      _ => -1,
    };
  }
}
