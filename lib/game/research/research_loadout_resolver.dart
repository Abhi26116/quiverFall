import 'package:quiverfall/data/models/progression.dart';
import 'package:quiverfall/game/sim/world.dart';

/// Turns a completed Research Lab item into the matching [SimWorld] field —
/// the same "content becomes a game rule in one place" seam
/// [LoadoutResolver]/`HeroLoadoutResolver` already keep for Boon and hero
/// sources.
///
/// Only one item has a live sim effect so far — *Windline Memory*
/// (docs/04 §4.6) — see ADR 0093 for why the other eleven Research Lab
/// items are content-only for now. Call once per real run, the same "on
/// build change" contract those other resolvers document; unlike a hero or
/// arrow, a Research unlock is permanent and account-wide, so in practice
/// this only ever needs calling once per app session.
abstract final class ResearchLoadoutResolver {
  static void apply(SimWorld world, ResearchState research) {
    world.windlinesSurviveRoomTransition =
        research.completedIds.contains('windline_memory');
  }
}
