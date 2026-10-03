import 'package:flutter/material.dart';

/// Colors from the design prototype. Screens use these, never raw values.
abstract final class AppColors {
  static const background = Color(0xFF0A0C11);
  static const card = Color(0xFF141821);

  /// A step lighter than [card].
  static const cardHigh = Color(0xFF1C212D);
  static const border = Color(0xFF262D3C);

  static const textPrimary = Color(0xFFEEF1F6);
  static const textSecondary = Color(0xFFA0A9BA);
  static const textMuted = Color(0xFF5B6478);

  /// Lime. The main accent, also used for the player.
  static const accent = Color(0xFFC6FF3D);

  /// Pink, for the opponent.
  static const opponent = Color(0xFFFF4F81);

  /// Amber, for warnings:
  /// - invalid reps: the "not counted" popup in the battle and the invalid
  ///   count on the result screen
  /// - the "needs improvement" posture label
  /// - the battle timer during its last 10 seconds
  static const warning = Color(0xFFFFB547);
}

/// Font families declared in pubspec.yaml.
abstract final class AppFonts {
  /// Korean headings. The headline text styles use it.
  static const headline = 'BlackHanSans';

  /// Numbers and English. Bold only, and it has no Korean glyphs.
  static const number = 'Oxanium';

  /// Body text. Also fills in glyphs the other two fonts lack.
  static const body = 'IBMPlexSansKR';
}

/// Builds the app's [ThemeData] from [AppColors] and [AppFonts].
abstract final class AppTheme {
  static const double cardRadius = 18;

  /// The app's only theme: always dark, whatever the system setting.
  static final ThemeData dark = _buildDark();

  static ThemeData _buildDark() {
    final base = ThemeData(
      colorScheme: _colorScheme(),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppFonts.body,
      // Oxanium has no Korean and Black Han Sans has no "·".
      fontFamilyFallback: const [AppFonts.body],
    );
    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      cardTheme: _cardTheme,
    );
  }

  /// fromSeed fills the roles the design leaves open (secondary, error, ...)
  /// with tones of the accent, and the design colors replace the rest.
  /// Pink and amber stay out so default widgets never paint with them.
  static ColorScheme _colorScheme() => ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
    primary: AppColors.accent,
    onPrimary: AppColors.background,
    surface: AppColors.background,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLow: AppColors.card,
    surfaceContainer: AppColors.card,
    surfaceContainerHigh: AppColors.cardHigh,
    surfaceContainerHighest: AppColors.cardHigh,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
  );

  /// Colors [base], which already uses the body font, and gives the display
  /// and headline styles their fonts.
  static TextTheme _textTheme(TextTheme base) {
    final text = base.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    TextStyle? asNumber(TextStyle? style) => style?.copyWith(
      fontFamily: AppFonts.number,
      fontWeight: FontWeight.w700,
    );
    TextStyle? asHeadline(TextStyle? style) =>
        style?.copyWith(fontFamily: AppFonts.headline);
    return text.copyWith(
      displayLarge: asNumber(text.displayLarge),
      displayMedium: asNumber(text.displayMedium),
      displaySmall: asNumber(text.displaySmall),
      headlineLarge: asHeadline(text.headlineLarge),
      headlineMedium: asHeadline(text.headlineMedium),
      headlineSmall: asHeadline(text.headlineSmall),
    );
  }

  static const _cardTheme = CardThemeData(
    color: AppColors.card,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
      side: BorderSide(color: AppColors.border),
    ),
  );
}
