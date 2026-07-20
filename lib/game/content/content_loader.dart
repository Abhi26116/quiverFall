import 'package:flutter/services.dart' show rootBundle;
import 'package:quiverfall/game/content/content_library.dart';

/// Loads the content tables from the asset bundle.
///
/// [ContentLibrary] itself does no I/O — it takes strings — which is what lets
/// the headless balance harness read the same files with `dart:io` and lets
/// tests pass literals. This is the Flutter-side adapter, and it is the only
/// place in the game layer that knows `rootBundle` exists.
///
/// Loaded **once**, at run start. Content is read-only at runtime and the
/// tables are small; re-parsing them per room would be pointless work on the
/// one thread that cannot afford it.
abstract final class ContentLoader {
  static ContentLibrary? _cached;

  /// The library, or null before [load] has completed.
  static ContentLibrary? get cached => _cached;

  static Future<ContentLibrary> load() async {
    final ContentLibrary? existing = _cached;
    if (existing != null) return existing;

    final String enemies =
        await rootBundle.loadString('assets/data/enemies.json');

    final (ContentLibrary?, List<ContentError>) parsed =
        ContentLibrary.parse(enemiesJson: enemies);

    final ContentLibrary? library = parsed.$1;
    if (library == null) {
      // A malformed table must fail loudly at load, not silently produce a room
      // with no enemies in it. The build-time validator (`tool/validate_content
      // .dart`) exists so this can never be reached in a shipped build — which
      // is exactly why it is safe to throw here.
      throw StateError(
        'enemies.json failed validation:\n${parsed.$2.join('\n')}',
      );
    }

    _cached = library;
    return library;
  }

  /// Test seam. Drops the cache so a test can load a different table.
  static void reset() => _cached = null;
}
