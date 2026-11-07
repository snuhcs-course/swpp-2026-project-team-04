import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';

import '../support/fakes.dart';

void main() {
  final theme = AppTheme.dark;

  test('is light and uses the design colors (kickoff 2026-11-07)', () {
    final scheme = theme.colorScheme;
    expect(theme.brightness, Brightness.light);
    expect(AppColors.background, const Color(0xFFE6E9F0));
    expect(AppColors.card, const Color(0xFFFFFFFF));
    expect(AppColors.textPrimary, const Color(0xFF141A26));
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(scheme.primary, AppColors.accent);
    expect(scheme.onPrimary, AppColors.ink);
    expect(scheme.surface, AppColors.background);
    expect(scheme.onSurface, AppColors.textPrimary);
    expect(scheme.onSurfaceVariant, AppColors.textSecondary);
    expect(scheme.outline, AppColors.border);
  });

  test('fever has its own color, apart from the player, opponent, and '
      'warning', () {
    expect(AppColors.fever, const Color(0xFF3DE8FF));
    expect({
      AppColors.fever,
      AppColors.accent,
      AppColors.opponent,
      AppColors.warning,
    }, hasLength(4));
  });

  test('danger has its own color, apart from the warning, the opponent, and '
      'fever', () {
    expect(AppColors.danger, const Color(0xFFFF3B30));
    expect({
      AppColors.danger,
      AppColors.warning,
      AppColors.opponent,
      AppColors.fever,
    }, hasLength(4));
  });

  test('text uses the primary text color', () {
    expect(theme.textTheme.bodyMedium!.color, AppColors.textPrimary);
    expect(theme.textTheme.displayLarge!.color, AppColors.textPrimary);
  });

  test('Oxanium for numbers, Black Han Sans for titles, Plex for the rest', () {
    final text = theme.textTheme;
    expect(text.displayLarge!.fontFamily, AppFonts.number);
    expect(text.displayLarge!.fontWeight, FontWeight.w700);
    expect(text.headlineMedium!.fontFamily, AppFonts.headline);
    expect(text.titleMedium!.fontFamily, AppFonts.body);
    expect(text.bodyMedium!.fontFamily, AppFonts.body);
    expect(text.labelLarge!.fontFamily, AppFonts.body);
  });

  test('falls back to Plex for glyphs Oxanium and Black Han Sans lack', () {
    expect(theme.textTheme.displayLarge!.fontFamilyFallback, [AppFonts.body]);
    expect(theme.textTheme.headlineMedium!.fontFamilyFallback, [AppFonts.body]);
  });

  test('cards are flat, rounded and outlined', () {
    final card = theme.cardTheme;
    expect(card.color, AppColors.card);
    expect(card.elevation, 0);
    expect(
      card.shape,
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.cardRadius)),
        side: BorderSide(color: AppColors.border),
      ),
    );
  });

  test('the lobby facets sit one step either side of the background, and '
      'the band shades are deeper than their colors', () {
    double light(Color color) => color.computeLuminance();
    expect(
      light(AppColors.facetLight),
      greaterThan(light(AppColors.background)),
    );
    expect(light(AppColors.facetDark), lessThan(light(AppColors.background)));
    expect(light(AppColors.accentDeep), lessThan(light(AppColors.accent)));
    expect(light(AppColors.opponentDeep), lessThan(light(AppColors.opponent)));
    expect(light(AppColors.ink), lessThan(light(AppColors.textSecondary)));
  });

  test("RepBot's limbs go from the darkest far foot to the lightest neck", () {
    const farToNear = [
      RepBotColors.footL,
      RepBotColors.footR,
      RepBotColors.shinL,
      RepBotColors.shinR,
      RepBotColors.thighL,
      RepBotColors.thighR,
      RepBotColors.pelvis,
      RepBotColors.handL,
      RepBotColors.forearmL,
      RepBotColors.torso,
      RepBotColors.upperArmL,
      RepBotColors.near,
      RepBotColors.upperArmR,
      RepBotColors.neck,
    ];
    final light = farToNear.map((color) => color.computeLuminance()).toList();
    for (var i = 1; i < light.length; i++) {
      expect(light[i], greaterThan(light[i - 1]), reason: 'limb $i');
    }
    expect(
      RepBotColors.headLight.computeLuminance(),
      greaterThan(RepBotColors.headDark.computeLuminance()),
    );
  });

  testWidgets('the game-style text styles: tags in Oxanium, menu titles in '
      'Do Hyeon, the rest in the body font, big to small', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: theme, home: const Scaffold()));
    // The theme's sizes come in when a context reads it.
    final text = Theme.of(tester.element(find.byType(Scaffold))).textTheme;
    for (final tag in [text.lobbyTag, text.lobbyMiniTag, text.lobbyBadge]) {
      expect(tag.fontFamily, AppFonts.number);
      expect(tag.fontWeight, FontWeight.w700);
      expect(tag.letterSpacing, greaterThan(0));
    }
    expect(text.lobbyLogo.fontFamily, AppFonts.number);
    expect(text.lobbyWatermark.fontFamily, AppFonts.number);
    expect(text.lobbyMenuTitle.fontFamily, AppFonts.display);
    expect(AppFonts.display, 'DoHyeon');
    // The design's weights: Oxanium 800 for the logo and watermark, Plex
    // 600 for page and card titles.
    expect(text.lobbyLogo.fontWeight, FontWeight.w800);
    expect(text.lobbyWatermark.fontWeight, FontWeight.w800);
    expect(text.lobbyPageTitle.fontWeight, FontWeight.w600);
    expect(text.lobbyCardTitle.fontWeight, FontWeight.w600);
    expect(text.lobbyButton.fontFamily, AppFonts.body);
    for (final body in [
      text.lobbyPageTitle,
      text.lobbyCardTitle,
      text.lobbyCardLine,
      text.lobbyRowTitle,
      text.lobbyLink,
    ]) {
      expect(body.fontFamily, AppFonts.body);
    }
    expect(text.lobbyLink.decoration, TextDecoration.underline);
    expect(text.lobbyCardLine.height, 1.5);
    final sizes = [
      text.lobbyMenuTitle,
      text.lobbyLogo,
      text.lobbyPageTitle,
      text.lobbyCardTitle,
      text.lobbyRowTitle,
      text.lobbyTag,
      text.lobbyMiniTag,
    ].map((style) => style.fontSize!).toList();
    for (var i = 1; i < sizes.length; i++) {
      expect(sizes[i], lessThan(sizes[i - 1]), reason: 'style $i');
    }
  });

  test('every text color reads at 4.5:1 or more where it is meant to', () {
    double contrast(Color a, Color b) {
      final (light, dark) = a.computeLuminance() > b.computeLuminance()
          ? (a.computeLuminance(), b.computeLuminance())
          : (b.computeLuminance(), a.computeLuminance());
      return (light + 0.05) / (dark + 0.05);
    }

    // Text on the light screen, a white card and a tile in a card.
    for (final text in [
      AppColors.textPrimary,
      AppColors.textSecondary,
      AppColors.textMuted,
      AppColors.accentText,
      AppColors.opponentText,
      AppColors.warningText,
    ]) {
      for (final ground in [
        AppColors.background,
        AppColors.card,
        AppColors.cardHigh,
        AppColors.selectedFill,
      ]) {
        expect(contrast(text, ground), greaterThanOrEqualTo(4.5));
      }
    }
    // Ink on lime and pink fills, and white or lime on ink.
    expect(
      contrast(AppColors.ink, AppColors.accent),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppColors.ink, AppColors.opponent),
      greaterThanOrEqualTo(4.5),
    );
    expect(contrast(AppColors.onInk, AppColors.ink), greaterThanOrEqualTo(4.5));
    expect(
      contrast(AppColors.accent, AppColors.ink),
      greaterThanOrEqualTo(4.5),
    );
  });

  group('Material defaults stay visible on the light screens', () {
    double contrast(Color a, Color b) {
      final (light, dark) = a.computeLuminance() > b.computeLuminance()
          ? (a.computeLuminance(), b.computeLuminance())
          : (b.computeLuminance(), a.computeLuminance());
      return (light + 0.05) / (dark + 0.05);
    }

    /// At least [least] against the screen and a white card.
    void readable(Color? color, double least) {
      expect(color, isNotNull);
      expect(
        contrast(color!, AppColors.background),
        greaterThanOrEqualTo(least),
      );
      expect(contrast(color, AppColors.card), greaterThanOrEqualTo(least));
    }

    const none = <WidgetState>{};
    const chosen = {WidgetState.selected};

    test('spinners and progress bars are ink, not lime', () {
      expect(theme.progressIndicatorTheme.color, AppColors.ink);
      readable(theme.progressIndicatorTheme.color, 3);
    });

    test('text and outlined buttons without a color read in ink', () {
      final text = theme.textButtonTheme.style!.foregroundColor!.resolve(none);
      final outlined = theme.outlinedButtonTheme.style!.foregroundColor!
          .resolve(none);
      expect(text, AppColors.textPrimary);
      expect(outlined, AppColors.textPrimary);
      readable(text, 4.5);
    });

    test('the text cursor and handles are ink', () {
      expect(theme.textSelectionTheme.cursorColor, AppColors.ink);
      expect(theme.textSelectionTheme.selectionHandleColor, AppColors.ink);
      readable(theme.textSelectionTheme.cursorColor, 3);
    });

    test('a chosen radio is ink, an unchosen one muted', () {
      final fill = theme.radioTheme.fillColor!;
      expect(fill.resolve(chosen), AppColors.ink);
      expect(fill.resolve(none), AppColors.textMuted);
      readable(fill.resolve(none), 3);
    });

    test('a switch: ink and lime when on; edged gray and white when off', () {
      final s = theme.switchTheme;
      expect(s.trackColor!.resolve(chosen), AppColors.ink);
      expect(s.thumbColor!.resolve(chosen), AppColors.accent);
      expect(s.trackOutlineColor!.resolve(chosen), Colors.transparent);
      expect(s.trackColor!.resolve(none), AppColors.border);
      expect(s.thumbColor!.resolve(none), AppColors.card);
      expect(s.trackOutlineColor!.resolve(none), AppColors.textMuted);
      // The off edge and the on track stand out from a white card.
      readable(s.trackOutlineColor!.resolve(none), 3);
      readable(s.trackColor!.resolve(chosen), 3);
    });

    test('fields: an ink edge when focused, dark amber for errors', () {
      final field = theme.inputDecorationTheme;
      expect(
        (field.focusedBorder! as OutlineInputBorder).borderSide.color,
        AppColors.ink,
      );
      expect(
        (field.errorBorder! as OutlineInputBorder).borderSide.color,
        AppColors.warningText,
      );
      expect(field.errorStyle!.color, AppColors.warningText);
      expect(field.floatingLabelStyle!.color, AppColors.textPrimary);
      readable(field.errorStyle!.color, 4.5);
    });
  });

  test('AppTheme.dark is the light theme, under its old name', () {
    expect(AppTheme.dark, same(AppTheme.light));
  });

  testWidgets('GymRatsApp uses the light theme', (tester) async {
    await tester.pumpWidget(testApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, same(AppTheme.light));
  });
}
