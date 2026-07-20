import 'package:flutter/material.dart';
import 'package:quiverfall/core/theme/tokens.dart';

/// Builds the app's [ThemeData] from [Tokens].
///
/// Quiverfall is dark-only by design — the art direction lights everything with
/// emissive VFX over near-black surfaces, and a light theme would break the
/// semantic palette's contrast guarantees. There is deliberately no light
/// variant to keep in sync.
abstract final class AppTheme {
  /// Display family: condensed geometric sans. Titles, numbers, currency.
  /// Bundled, never fetched at runtime — see docs/15-art-direction.md.
  static const String displayFamily = 'Display';

  /// Body family: humanist sans. Everything else.
  static const String bodyFamily = 'Body';

  static ThemeData build() {
    const ColorScheme scheme = ColorScheme.dark(
      primary: Tokens.accent,
      onPrimary: Tokens.bgDeep,
      secondary: Tokens.gem,
      onSecondary: Tokens.ink,
      error: Tokens.danger,
      onError: Tokens.ink,
      surface: Tokens.bgPanel,
      onSurface: Tokens.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Tokens.bgDeep,
      canvasColor: Tokens.bgDeep,
      splashFactory: InkRipple.splashFactory,
      textTheme: _textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Tokens.bgDeep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: Tokens.topBarHeight,
        titleTextStyle: TextStyle(
          fontFamily: displayFamily,
          fontSize: Tokens.textTitle,
          fontWeight: FontWeight.w800,
          color: Tokens.ink,
        ),
      ),
      cardTheme: CardTheme(
        color: Tokens.bgPanel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Tokens.accent,
          foregroundColor: Tokens.bgDeep,
          minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusChip),
          ),
          textStyle: const TextStyle(
            fontFamily: displayFamily,
            fontSize: Tokens.textHeading,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Tokens.ink,
          minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
          side: const BorderSide(color: Tokens.bgRaised),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusChip),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Tokens.inkDim,
          // Text buttons are frequently the "decline" option (e.g. "Not now" on
          // the login sheet). They get the same touch target as the affirmative
          // action so declining is never harder than accepting.
          minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Tokens.bgRaised,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Tokens.accent,
        inactiveTrackColor: Tokens.bgRaised,
        thumbColor: Tokens.accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? Tokens.accent
              : Tokens.inkFaint;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? Tokens.accent.withOpacity(0.35)
              : Tokens.bgRaised;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Tokens.accent,
        linearTrackColor: Tokens.bgRaised,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Tokens.bgPanel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Tokens.radiusSheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Tokens.bgRaised,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFamily,
          fontSize: Tokens.textBody,
          color: Tokens.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusChip),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Numbers use tabular figures throughout so counters do not jitter as they
  /// tick — currency count-ups on the Victory screen are a core feel moment.
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: displayFamily,
      fontSize: Tokens.textDisplay,
      fontWeight: FontWeight.w800,
      color: Tokens.ink,
      fontFeatures: _tabular,
    ),
    titleLarge: TextStyle(
      fontFamily: displayFamily,
      fontSize: Tokens.textTitle,
      fontWeight: FontWeight.w800,
      color: Tokens.ink,
      fontFeatures: _tabular,
    ),
    titleMedium: TextStyle(
      fontFamily: displayFamily,
      fontSize: Tokens.textHeading,
      fontWeight: FontWeight.w600,
      color: Tokens.ink,
      fontFeatures: _tabular,
    ),
    bodyLarge: TextStyle(
      fontFamily: bodyFamily,
      fontSize: Tokens.textBody,
      fontWeight: FontWeight.w400,
      color: Tokens.ink,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontFamily: bodyFamily,
      fontSize: Tokens.textLabel,
      fontWeight: FontWeight.w400,
      color: Tokens.inkDim,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontFamily: bodyFamily,
      fontSize: Tokens.textCaption,
      fontWeight: FontWeight.w600,
      color: Tokens.inkDim,
      letterSpacing: 0.4,
    ),
  );
}
