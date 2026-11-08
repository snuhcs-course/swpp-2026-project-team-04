import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colors from the design prototype, light since the 2026-11-07 kickoff,
/// used as palette B ("형광펜", 2026-11-08):
/// - text is always ink: [textPrimary], or [textSecondary] / [textMuted]
///   for quieter lines, also on a color; the one exception is a dark fill
///   such as [ink], which takes white text ([onInk]) and may take a lime
///   icon;
/// - lime, pink, amber, cyan and red only fill: backgrounds, buttons, bars,
///   bands and chips, with ink text on them ([AppHighlight]);
/// - lines, icons and outlines that are not text are [line] or [ink]; a
///   mark told apart by its color is a colored fill with an ink edge.
/// Screens use these, never raw values.
abstract final class AppColors {
  /// The light gray ground of every screen.
  static const background = Color(0xFFE6E9F0);

  /// White cards, sheets and buttons on [background].
  static const card = Color(0xFFFFFFFF);

  /// A step off [card]: tiles and fields inside a white card or sheet.
  static const cardHigh = Color(0xFFF3F5F9);
  static const border = Color(0xFFD5DAE3);

  static const textPrimary = Color(0xFF141A26);
  static const textSecondary = Color(0xFF4A5366);

  /// Tags and hints; still readable on [background] and [card].
  static const textMuted = Color(0xFF586073);

  /// Lime fill: the main accent and the player. Never a text color.
  static const accent = Color(0xFFC6FF3D);

  /// Pink fill: the opponent and the AI. Never a text color.
  static const opponent = Color(0xFFFF4F81);

  /// Amber fill behind ink text, for warnings:
  /// - invalid reps: the "not counted" popup in the battle and the invalid
  ///   count on the result screen
  /// - the "needs improvement" posture label
  /// - the battle timer during its last 5 seconds
  static const warning = Color(0xFFFFB547);

  /// Cyan fill for fever time in the battle: behind the clock, the time bar
  /// until its last 5 seconds, and the fever chip.
  static const fever = Color(0xFF3DE8FF);

  /// Red fill, only for the battle's danger edge and its mark on the rules
  /// screen: the user is about to lose. Every other problem is [warning].
  static const danger = Color(0xFFFF3B30);

  /// Near-black of the game-style screens: edges and icons on a color fill,
  /// the 대결 시작 button, and drawings on a lime or pink band.
  static const ink = Color(0xFF141A26);

  /// A shade deeper than [accent] and [opponent], for the slanted half of
  /// a lime or pink band.
  static const accentDeep = Color(0xFFB4EC2C);
  static const opponentDeep = Color(0xFFF23E72);

  /// The lobby's backdrop: two large slanted facets over [background], one
  /// a step lighter and one a step darker. [facetDark] is also the color of
  /// a page's faint name behind it.
  static const facetLight = Color(0xFFEEF0F5);
  static const facetDark = Color(0xFFDCE0E8);

  /// Lines, icons, rings and outlines that are not text: the radar's
  /// circles, avatar rings, chevrons (3:1 or more on [background] and
  /// [card]).
  static const line = Color(0xFF586073);

  /// Behind a chosen option, with an [ink] edge.
  static const selectedFill = Color(0xFFF6FFE6);

  /// Text on an [ink] fill, such as the 대결 시작 button: the one exception
  /// to ink text, since a dark fill needs light text (palette B).
  static const onInk = Color(0xFFFFFFFF);
}

/// RepBot, the robot doing push-ups in the lobby, as designed: its own
/// greys, the same in any theme. Its visor and glow are [AppColors.opponent].
/// The limb names are the design's: L is the far side, R the near one.
abstract final class RepBotColors {
  static const footL = Color(0xFFABB2C0);
  static const footR = Color(0xFFB0B7C4);
  static const shinL = Color(0xFFB7BDC9);
  static const shinR = Color(0xFFBCC2CE);
  static const thighL = Color(0xFFC9CED8);
  static const thighR = Color(0xFFCFD4DD);
  static const pelvis = Color(0xFFD6DAE2);
  static const handL = Color(0xFFDDE1E8);
  static const forearmL = Color(0xFFDEE1E8);
  static const torso = Color(0xFFE1E4EA);
  static const upperArmL = Color(0xFFE3E6EC);

  /// The near hand, forearm and the shoulders.
  static const near = Color(0xFFEBEEF3);
  static const upperArmR = Color(0xFFEFF1F6);
  static const neck = Color(0xFFF3F5F9);

  /// The streak of light along each limb, drawn see-through.
  static const shine = Color(0xFFFFFFFF);

  /// The head's shading, from its lit spot to its edge.
  static const headLight = Color(0xFFFFFFFF);
  static const headMid = Color(0xFFDDE2EA);
  static const headDark = Color(0xFF99A1B2);

  /// The thin line around the whole body.
  static const outline = Color(0xFF8C95A7);

  /// The soft shadow on the floor under the body.
  static const shadow = Color(0xFF141A26);
}

/// Font families declared in pubspec.yaml.
abstract final class AppFonts {
  /// Korean headings. The headline text styles use it.
  static const headline = 'BlackHanSans';

  /// Numbers and English, in bold (700) and extra bold (800). It has no
  /// Korean glyphs.
  static const number = 'Oxanium';

  /// Home's big menu titles (Do Hyeon), as designed.
  static const display = 'DoHyeon';

  /// Body text, regular to bold (400, 500, 600, 700). Also fills in glyphs
  /// the other fonts lack.
  static const body = 'IBMPlexSansKR';
}

/// The text styles of the game-style screens (home lobby, 게임 시작, AI 1v1,
/// 환경설정), made from the theme's styles. Screens change only their color
/// or weight, so a font decision changes this one place.
extension LobbyText on TextTheme {
  /// "GYMRATS" on home.
  TextStyle get lobbyLogo => displayMedium!.copyWith(
    fontWeight: FontWeight.w800,
    letterSpacing: 1,
    height: 1,
  );

  /// "1V1" beside home's one-line pitch.
  TextStyle get lobbyBadge => bodyMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
  );

  /// "01 / PLAY": small spaced-out English capitals.
  TextStyle get lobbyTag => labelMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontWeight: FontWeight.w700,
    letterSpacing: 3,
  );

  /// The smaller tags on cards and sections, e.g. "ONLINE 1V1", "LEVEL".
  TextStyle get lobbyMiniTag => labelSmall!.copyWith(
    fontFamily: AppFonts.number,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
  );

  /// Home's menu titles, e.g. "게임 시작".
  TextStyle get lobbyMenuTitle => displayLarge!.copyWith(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  /// A page's name as a huge faint word behind it, e.g. "PLAY".
  TextStyle get lobbyWatermark =>
      displayLarge!.copyWith(fontWeight: FontWeight.w800, height: 1);

  /// A page's slanted title, e.g. "게임 시작" on its own page.
  TextStyle get lobbyPageTitle => displaySmall!.copyWith(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
    letterSpacing: -1,
  );

  /// A card's or an option's slanted name, e.g. "온라인 1v1", "푸쉬업".
  TextStyle get lobbyCardTitle => headlineSmall!.copyWith(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
  );

  /// A card's short line, which may take two lines.
  TextStyle get lobbyCardLine => bodySmall!.copyWith(height: 1.5);

  /// A row's bold label, e.g. "최근 설정으로 다시 하기".
  TextStyle get lobbyRowTitle =>
      titleSmall!.copyWith(fontWeight: FontWeight.w700);

  /// The label of a page's start button, e.g. "대결 시작".
  TextStyle get lobbyButton => titleLarge!.copyWith(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
  );

  /// A text link, e.g. "규칙 보기".
  TextStyle get lobbyLink => bodyMedium!.copyWith(
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
  );
}

/// Padding and gap steps (Design Documentation 2.5.5). Screens use only
/// these for padding and gaps.
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
}

/// Corner radii (Design Documentation 2.5.6). Pills use [StadiumBorder].
abstract final class AppRadius {
  /// Small boxes inside a card: tiles, tags, input fields.
  static const double small = 12;

  /// Cards, panels, and all buttons.
  static const double card = 18;

  /// Dialogs, bottom sheets, the top corners of a bottom panel.
  static const double sheet = 24;

  /// Tiny color marks: [AppHighlight.swatch].
  static const double mark = 3;
}

/// Palette B's highlighter: color never carries text. It sits behind ink
/// text like a marker, or marks ink text as a small swatch. Screens take
/// these as they are. WIN, for example:
///
/// ```dart
/// Transform(
///   transform: AppHighlight.slant,
///   alignment: Alignment.center,
///   child: DecoratedBox(
///     decoration: AppHighlight.band(AppColors.accent),
///     child: Padding(
///       padding: AppHighlight.bandPadding,
///       child: Text('WIN', style: style.copyWith(color: AppColors.ink)),
///     ),
///   ),
/// )
/// ```
abstract final class AppHighlight {
  /// A flat band of [color] behind ink text: WIN on lime, LOSE on pink, a
  /// number or a word to stand out.
  static BoxDecoration band(Color color) => BoxDecoration(color: color);

  /// The room around the text on a [band].
  static const bandPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s8,
    vertical: AppSpacing.s4,
  );

  /// The marker's slant, as the design draws WIN and LOSE. A new matrix each
  /// time, so no one changes another's.
  static Matrix4 get slant => Matrix4.skewX(-10 * math.pi / 180);

  /// A soft pill of [color] behind ink text, for chips: points (lime),
  /// fever (cyan), warnings (amber), danger (red). [strength] is how much of
  /// the color shows; the design uses 0.75 for lime, 0.6 for amber, 0.45 for
  /// cyan and 0.35 for red. Ink text reads on any of them.
  static ShapeDecoration chip(Color color, {double strength = 0.6}) =>
      ShapeDecoration(
        color: color.withValues(alpha: strength),
        shape: const StadiumBorder(),
      );

  /// The room around the text on a [chip].
  static const chipPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s8,
    vertical: AppSpacing.s4,
  );

  /// A small square of [color] with an ink edge, beside the ink text it
  /// marks, e.g. "나" with lime and "상대" with pink. Make it [swatchSize]
  /// square.
  static BoxDecoration swatch(Color color) => BoxDecoration(
    color: color,
    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.mark)),
    border: Border.all(color: AppColors.ink, width: _swatchEdge),
  );

  static const double swatchSize = 10;
  static const _swatchEdge = 1.5;

  /// [style] in ink with a band of [color] right behind the letters, for a
  /// marked word inside a line of text.
  static TextStyle marked(TextStyle style, Color color) =>
      style.copyWith(color: AppColors.ink, backgroundColor: color);
}

/// Builds the app's [ThemeData] from [AppColors] and [AppFonts].
abstract final class AppTheme {
  static const double cardRadius = AppRadius.card;

  /// The app's only theme: always light, whatever the system setting
  /// (team kickoff 2026-11-07).
  static final ThemeData light = _build();

  /// The name from before the app turned light; the same theme as [light],
  /// kept so screens and tests that still say `dark` keep working.
  static final ThemeData dark = light;

  static ThemeData _build() {
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
      inputDecorationTheme: _inputTheme(base.textTheme),
      switchTheme: _switchTheme,
      // Material paints these in the primary lime by default, which all but
      // disappears on the light screens.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.border,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionHandleColor: AppColors.ink,
        selectionColor: AppColors.accent.withValues(alpha: 0.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.textMuted,
        ),
      ),
    );
  }

  /// fromSeed fills the roles the design leaves open (secondary, error, ...)
  /// with tones of the accent, and the design colors replace the rest.
  /// Pink and amber stay out so default widgets never paint with them.
  static ColorScheme _colorScheme() => ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.light,
    primary: AppColors.accent,
    onPrimary: AppColors.ink,
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
      // Small numbers, e.g. match history scores (Design Documentation 2.5.3).
      titleLarge: asNumber(text.titleLarge),
      headlineLarge: asHeadline(text.headlineLarge),
      headlineMedium: asHeadline(text.headlineMedium),
      headlineSmall: asHeadline(text.headlineSmall),
    );
  }

  /// Text fields: a card-colored box with radius [AppRadius.small], an ink
  /// outline while focused or wrong (as the design's fields), and an error
  /// line in ink on an amber band (2.5.2: every problem is amber; palette B:
  /// the amber sits behind the text).
  static InputDecorationTheme _inputTheme(TextTheme text) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.small),
          ),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.all(AppSpacing.s16),
      hintStyle: text.bodyLarge?.copyWith(color: AppColors.textMuted),
      labelStyle: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
      floatingLabelStyle: text.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
      ),
      errorStyle: text.bodyMedium == null
          ? null
          : AppHighlight.marked(text.bodyMedium!, AppColors.warning),
      errorMaxLines: 2,
      border: outline(AppColors.border),
      enabledBorder: outline(AppColors.border),
      focusedBorder: outline(AppColors.ink, 2),
      errorBorder: outline(AppColors.ink),
      focusedErrorBorder: outline(AppColors.ink, 2),
    );
  }

  /// The design's switch: an ink track with a lime knob when on, a gray
  /// track with a white knob when off. The off track keeps a muted edge so
  /// it stands out from a white card.
  static final _switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.accent
          : AppColors.card,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.ink
          : AppColors.border,
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? Colors.transparent
          : AppColors.textMuted,
    ),
  );

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
