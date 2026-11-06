import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';

import '../support/fakes.dart';

void main() {
  final theme = AppTheme.dark;

  test('is dark and uses the design colors', () {
    final scheme = theme.colorScheme;
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(scheme.primary, AppColors.accent);
    expect(scheme.onPrimary, AppColors.background);
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
      'the headline font, the rest in the body font, big to small', (
    tester,
  ) async {
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
    expect(text.lobbyMenuTitle.fontFamily, AppFonts.headline);
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

  testWidgets('GymRatsApp uses the dark theme', (tester) async {
    await tester.pumpWidget(testApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, same(AppTheme.dark));
  });
}
