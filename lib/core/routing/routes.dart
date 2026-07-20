/// Every route path in the game, in one place.
///
/// String literals for routes scattered through a codebase are a reliable
/// source of typo bugs that only appear at runtime on a screen nobody tested.
/// See docs/11-screen-flow.md §11.5.
abstract final class Routes {
  static const String splash = '/';
  static const String loading = '/loading';
  static const String menu = '/menu';
  static const String levels = '/levels/:chapter';
  static const String loadout = '/loadout';
  static const String game = '/game';
  static const String spire = '/spire';
  static const String research = '/spire/research';
  static const String heroes = '/heroes';
  static const String gear = '/gear';
  static const String shop = '/shop';
  static const String compete = '/compete';
  static const String events = '/events/:eventId';
  static const String pass = '/pass';
  static const String achievements = '/achievements';
  static const String settings = '/settings';
  static const String daily = '/daily';
  static const String login = '/login';

  /// Developer tools. Not reachable from normal navigation — deep-link only.
  static const String devBench = '/dev/bench';

  static String levelsFor(int chapter) => '/levels/$chapter';

  static String eventFor(String eventId) => '/events/$eventId';
}
