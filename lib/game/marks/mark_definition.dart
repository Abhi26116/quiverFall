import 'package:quiverfall/game/sim/effects/stat_channel.dart';

/// The 9 Marks docs/04-upgrades.md §4.5 names explicitly, out of "25 Marks
/// total... ...16 more" — the doc itself leaves the other sixteen
/// unspecified (no names, no earn conditions, no effects), an authorial
/// placeholder rather than an oversight this session can resolve by
/// interpretation. See ADR 0095.
enum MarkArchetype {
  markOfTheThread,
  markOfTheThreadII,
  markOfStillness,
  markOfTheGale,
  markOfTheUnbroken,
  markOfTheSwift,
  markOfTheChoir,
  markOfRuin,
  markOfTheNinefold,
}

/// One Mark.
///
/// Unlike every other content identity in this codebase, [MarkDefinition]
/// carries no earn-condition data at all — docs/04 §4.5's own "Earned by"
/// column is prose ("Trigger 500 Confluences", "Clear a chapter without
/// taking damage"), not a formula, and checking it needs its own event hook
/// into a different system per Mark (Confluence's own trigger count, a
/// hit's own Draw tier, a room's own damage-taken tally...). This Part
/// builds the catalogue, the equip mechanic, and the effect composition for
/// whichever Marks land on a channel that already exists; deliberately not
/// the unlock-condition checking itself — see ADR 0095.
class MarkDefinition {
  const MarkDefinition({
    required this.archetype,
    required this.id,
    required this.key,
    required this.name,
    required this.earnedBy,
    required this.description,
    this.channel,
    this.value = 0,
    this.secondaryChannel,
    this.secondaryValue = 0,
    this.implemented = true,
    this.balanceNote = '',
  });

  /// 1-9, in docs/04's own table order.
  final int id;

  final MarkArchetype archetype;
  final String key;
  final String name;

  /// docs/04's own "Earned by" text, verbatim — display only. Checking it
  /// for real is a separate, cross-cutting task this Part does not attempt.
  final String earnedBy;

  final String description;

  /// This Mark's own contribution once equipped and unlocked — a flat
  /// value in whatever unit [channel] expects, the same "additive within a
  /// source" shape a Spire node or a hero talent already composes with.
  /// Null for a Mark with no live effect yet.
  final StatChannel? channel;
  final double value;

  /// *Mark of the Thread II* alone grants two effects at once (Confluence
  /// damage and Windline duration) — the one Mark with a second channel.
  final StatChannel? secondaryChannel;
  final double secondaryValue;

  /// False for a Mark with no live effect yet — real, catalogued content,
  /// with its own specific, checked reason in [balanceNote]. See ADR 0095.
  final bool implemented;

  final String balanceNote;

  /// This Mark's own contribution, in the same `StatModifier` shape a
  /// Spire node or hero talent already composes with. Empty for a Mark
  /// with no live effect yet.
  List<StatModifier> contribution() {
    if (!implemented) return const <StatModifier>[];
    final List<StatModifier> out = <StatModifier>[];
    if (channel != null) out.add(StatModifier(channel!, value));
    if (secondaryChannel != null) {
      out.add(StatModifier(secondaryChannel!, secondaryValue));
    }
    return out;
  }

  @override
  String toString() => '#$id $name';
}
