import 'package:flutter/services.dart' show rootBundle;
import 'package:quiverfall/game/boons/boon_catalogue.dart';
import 'package:quiverfall/game/boons/synergy_catalogue.dart';
import 'package:quiverfall/game/content/content_library.dart';

/// Loads `boons.json` and `synergies.json` from the asset bundle.
///
/// The Boon counterpart to [ContentLoader] — same shape, same reasoning:
/// [BoonCatalogue] and [SynergyCatalogue] do no I/O themselves, which is what
/// lets the balance harness and every test in `test/game/` read the same files
/// with `dart:io`. This is the one place in the game layer that knows
/// `rootBundle` exists for Boon content specifically.
///
/// A separate loader rather than folding into [ContentLoader] because the two
/// are read by different systems on different schedules — enemies and arenas
/// are needed before the first room, Boons are not needed until the first room
/// clears — and a run that has not reached Phase 9 content yet should not pay
/// for parsing it.
abstract final class BoonContentLoader {
  static BoonCatalogue? _catalogue;
  static SynergyCatalogue? _synergies;

  static BoonCatalogue? get cachedCatalogue => _catalogue;
  static SynergyCatalogue? get cachedSynergies => _synergies;

  static Future<(BoonCatalogue, SynergyCatalogue)> load() async {
    final BoonCatalogue? existingCatalogue = _catalogue;
    final SynergyCatalogue? existingSynergies = _synergies;
    if (existingCatalogue != null && existingSynergies != null) {
      return (existingCatalogue, existingSynergies);
    }

    final String boonsJson =
        await rootBundle.loadString('assets/data/boons.json');
    final (BoonCatalogue?, List<ContentError>) parsedBoons =
        BoonCatalogue.parse(boonsJson);
    final BoonCatalogue? catalogue = parsedBoons.$1;
    if (catalogue == null) {
      throw StateError(
        'boons.json failed validation:\n${parsedBoons.$2.join('\n')}',
      );
    }

    final String synergiesJson =
        await rootBundle.loadString('assets/data/synergies.json');
    final (SynergyCatalogue?, List<ContentError>) parsedSynergies =
        SynergyCatalogue.parse(synergiesJson, boons: catalogue);
    final SynergyCatalogue? synergies = parsedSynergies.$1;
    if (synergies == null) {
      throw StateError(
        'synergies.json failed validation:\n${parsedSynergies.$2.join('\n')}',
      );
    }

    _catalogue = catalogue;
    _synergies = synergies;
    return (catalogue, synergies);
  }

  /// Test seam. Drops the cache so a test can load a different table.
  static void reset() {
    _catalogue = null;
    _synergies = null;
  }
}
