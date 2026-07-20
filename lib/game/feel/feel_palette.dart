/// The semantic palette as packed ARGB integers.
///
/// `Tokens` is the single source of truth for colour and imports Flutter, which
/// `game/feel` may not — the feedback stack has to stay pure Dart so it can be
/// unit-tested without a widget tree, and so the eventual replay renderer can
/// reuse it.
///
/// **These values are checked against `Tokens` by a guard test.** Duplicating a
/// colour is normally how a palette rots; duplicating it with a test that fails
/// the build on divergence is how you get purity without the rot.
///
/// See docs/15-art-direction.md §15.1.
abstract final class FeelPalette {
  /// Player-positive. Base Windline, shields, pickups.
  static const int accent = 0xFF3FE0D0;

  /// Incoming threat. Every telegraph, without exception.
  static const int warn = 0xFFFFB03A;

  /// Lethal right now.
  static const int danger = 0xFFFF4D5E;

  /// Confluence, crits, Mythic. The brightest thing on screen.
  static const int whiteHot = 0xFFFFFFFF;

  static const int ink = 0xFFE8EDF7;
  static const int inkDim = 0xFF8E9AB4;

  static const int arenaFloor = 0xFF1B2436;
  static const int arenaWall = 0xFF39435A;
  static const int bgDeep = 0xFF080B12;

  // ── Elements ──────────────────────────────────────────────────────────────
  static const int ember = 0xFFFF6B2C;
  static const int rime = 0xFF5CC8FF;
  static const int storm = 0xFFB58BFF;
  static const int blight = 0xFF8FE04A;

  // ── Enemy families ────────────────────────────────────────────────────────
  static const int familyDrift = 0xFF6E5C8A;
  static const int familyCarapace = 0xFF5A7291;
  static const int familyRush = 0xFFA85440;
  static const int familySalvo = 0xFF9A7B3F;
  static const int familyChoir = 0xFF6E9A73;
  static const int familyRiftborn = 0xFF1A1420;

  /// [SimElement] index to colour. Index order matches the enum, which is
  /// load-bearing: it is the cycle order used by Prismshaft and Oriel.
  static const List<int> byElement = <int>[ember, rime, storm, blight];

  /// [EnemyFamily] index to colour, in enum order.
  static const List<int> byFamily = <int>[
    familyDrift,
    familyCarapace,
    familyRush,
    familySalvo,
    familyChoir,
    familyRiftborn,
  ];

  /// Replaces the alpha channel of a packed colour.
  static int withAlpha(int argb, double alpha) {
    final int a = (alpha.clamp(0.0, 1.0) * 255).round();
    return (a << 24) | (argb & 0x00FFFFFF);
  }
}
