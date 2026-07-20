import 'package:flutter/widgets.dart';

/// The single source of truth for every colour, size, and duration in the game.
///
/// Nothing anywhere else in the codebase may declare a raw [Color] or a magic
/// spacing number. This is not style pedantry: the semantic palette below is a
/// *gameplay contract*. Amber always means "incoming threat", crimson always
/// means "lethal right now", cyan always means "yours". A player learns that in
/// thirty seconds and relies on it for the next forty hours, so a one-off colour
/// somewhere in the UI is a gameplay bug, not a design inconsistency.
///
/// See docs/10-ui-ux.md §10.0 and docs/15-art-direction.md §15.1.
abstract final class Tokens {
  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const Color bgDeep = Color(0xFF080B12);
  static const Color bgPanel = Color(0xFF111725);
  static const Color bgRaised = Color(0xFF1B2436);
  static const Color arenaFloor = Color(0xFF1B2436);
  static const Color arenaWall = Color(0xFF39435A);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFFE8EDF7);
  static const Color inkDim = Color(0xFF8E9AB4);
  static const Color inkFaint = Color(0xFF5A6478);

  // ── Semantic — DO NOT use these for decoration ────────────────────────────

  /// Player-positive: primary CTAs, pickups, shields, the base Windline.
  static const Color accent = Color(0xFF3FE0D0);

  /// Incoming threat. Every enemy telegraph in the game, without exception.
  static const Color warn = Color(0xFFFFB03A);

  /// Lethal right now. Every damaging zone, and destructive UI actions.
  static const Color danger = Color(0xFFFF4D5E);

  // ── Currency ──────────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFF5C542);
  static const Color gem = Color(0xFF8B6BFF);

  // ── Elements ──────────────────────────────────────────────────────────────
  static const Color ember = Color(0xFFFF6B2C);
  static const Color rime = Color(0xFF5CC8FF);
  static const Color storm = Color(0xFFB58BFF);
  static const Color blight = Color(0xFF8FE04A);

  /// Confluence, crits, and Mythic rarity. The brightest thing on screen.
  static const Color whiteHot = Color(0xFFFFFFFF);

  // ── Rarity ────────────────────────────────────────────────────────────────
  static const Color rarityCommon = Color(0xFF8E9AB4);
  static const Color rarityRare = Color(0xFF3FE0D0);
  static const Color rarityEpic = Color(0xFF8B6BFF);
  static const Color rarityLegendary = Color(0xFFF5C542);
  static const Color rarityMythic = Color(0xFFFFFFFF);

  // ── Enemy family tints (docs/15 §15.1) ────────────────────────────────────
  static const Color familyDrift = Color(0xFF6E5C8A);
  static const Color familyCarapace = Color(0xFF5A7291);
  static const Color familyRush = Color(0xFFA85440);
  static const Color familySalvo = Color(0xFF9A7B3F);
  static const Color familyChoir = Color(0xFF6E9A73);
  static const Color familyRiftborn = Color(0xFF1A1420);

  // ── Spacing — 4pt grid ────────────────────────────────────────────────────
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;

  // ── Radius ────────────────────────────────────────────────────────────────
  static const double radiusChip = 8;
  static const double radiusCard = 14;
  static const double radiusSheet = 22;

  // ── Touch targets ─────────────────────────────────────────────────────────

  /// Minimum interactive size. Anything smaller fails accessibility review.
  static const double minTouchTarget = 48;
  static const double primaryCtaHeight = 64;
  static const double navBarHeight = 64;
  static const double topBarHeight = 56;

  /// The bottom strip of the gameplay screen where the left thumb rests. No UI
  /// may be placed here. See docs/10-ui-ux.md §10.6.
  static const double gameplayNoUiZone = 96;

  // ── Motion ────────────────────────────────────────────────────────────────
  static const Duration motionTap = Duration(milliseconds: 90);
  static const Duration motionStandard = Duration(milliseconds: 180);
  static const Duration motionScreen = Duration(milliseconds: 320);
  static const Curve motionCurve = Curves.easeOutCubic;

  // ── Type scale ────────────────────────────────────────────────────────────
  static const double textDisplay = 32;
  static const double textTitle = 24;
  static const double textHeading = 18;
  static const double textBody = 15;
  static const double textLabel = 13;
  static const double textCaption = 11;
}

/// Rarity tiers, shared by Boons, arrows, heroes, and chests.
enum Rarity {
  common(Tokens.rarityCommon),
  rare(Tokens.rarityRare),
  epic(Tokens.rarityEpic),
  legendary(Tokens.rarityLegendary),
  mythic(Tokens.rarityMythic);

  const Rarity(this.color);

  final Color color;
}

/// The four elements. Ordering matters: it is the cycle order used by
/// Prismshaft and by Oriel's Spectrum passive (docs/08-arrows.md).
enum ElementType {
  ember(Tokens.ember),
  frost(Tokens.rime),
  storm(Tokens.storm),
  toxin(Tokens.blight);

  const ElementType(this.color);

  final Color color;
}
