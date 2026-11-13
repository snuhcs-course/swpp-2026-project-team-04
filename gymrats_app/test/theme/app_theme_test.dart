import 'dart:math' as math;

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

  group('palette B (형광펜, 2026-11-08)', () {
    double contrast(Color a, Color b) {
      final (light, dark) = a.computeLuminance() > b.computeLuminance()
          ? (a.computeLuminance(), b.computeLuminance())
          : (b.computeLuminance(), a.computeLuminance());
      return (light + 0.05) / (dark + 0.05);
    }

    const fills = [
      AppColors.accent,
      AppColors.opponent,
      AppColors.warning,
      AppColors.fever,
      AppColors.danger,
    ];

    test('the colors keep their values and only fill', () {
      expect(fills, const [
        Color(0xFFC6FF3D),
        Color(0xFFFF4F81),
        Color(0xFFFFB547),
        Color(0xFF3DE8FF),
        Color(0xFFFF3B30),
      ]);
    });

    test('ink text reads at 4.5:1 on every surface and every color fill', () {
      for (final text in [
        AppColors.textPrimary,
        AppColors.textSecondary,
        AppColors.textMuted,
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
      expect(AppColors.ink, AppColors.textPrimary);
      for (final fill in fills) {
        expect(contrast(AppColors.ink, fill), greaterThanOrEqualTo(4.5));
      }
    });

    test('a dark ink fill takes white text and a lime icon', () {
      expect(AppColors.onInk, const Color(0xFFFFFFFF));
      expect(
        contrast(AppColors.onInk, AppColors.ink),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppColors.accent, AppColors.ink),
        greaterThanOrEqualTo(3),
      );
    });

    test('lines and icons in gray read at 3:1 on the screen and a card', () {
      expect(AppColors.line, const Color(0xFF586073));
      expect(
        contrast(AppColors.line, AppColors.background),
        greaterThanOrEqualTo(3),
      );
      expect(contrast(AppColors.line, AppColors.card), greaterThanOrEqualTo(3));
    });

    test('AppHighlight: a band, a chip and a swatch of a color, ink text', () {
      expect(
        AppHighlight.band(AppColors.accent),
        const BoxDecoration(color: AppColors.accent),
      );
      final chip = AppHighlight.chip(AppColors.warning);
      expect(chip.color, AppColors.warning.withValues(alpha: 0.6));
      expect(chip.shape, isA<StadiumBorder>());
      expect(
        AppHighlight.chip(AppColors.fever, strength: 0.45).color,
        AppColors.fever.withValues(alpha: 0.45),
      );
      final swatch = AppHighlight.swatch(AppColors.opponent);
      expect(swatch.color, AppColors.opponent);
      expect((swatch.border! as Border).top.color, AppColors.ink);
      expect(AppHighlight.swatchSize, 10);
      expect(
        swatch.borderRadius,
        const BorderRadius.all(Radius.circular(AppRadius.mark)),
      );
      expect(AppHighlight.bandPadding.vertical, 2 * AppSpacing.s4);
      // The design's tight band (BMatchFound "MATCH FOUND") and the room
      // beside a swatch.
      expect(
        AppHighlight.tightBandPadding,
        const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      );
      // The "AI" tag's pill on the match-found board (W2b 2-A3, 2 x 12).
      expect(
        AppHighlight.tagPadding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      );
      expect(AppHighlight.swatchGap, 6);
      final marked = AppHighlight.marked(
        const TextStyle(color: AppColors.accent),
        AppColors.accent,
      );
      expect(marked.color, AppColors.ink);
      expect(marked.backgroundColor, AppColors.accent);
    });

    test('the marker slants like the design, and each call is its own', () {
      final slant = AppHighlight.slant;
      expect(slant.entry(0, 1), closeTo(math.tan(-10 * math.pi / 180), 1e-12));
      expect(identical(slant, AppHighlight.slant), isFalse);
    });
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

    test('fields: an ink edge when focused or wrong, the error in ink on an '
        'amber band', () {
      final field = theme.inputDecorationTheme;
      expect(
        (field.focusedBorder! as OutlineInputBorder).borderSide.color,
        AppColors.ink,
      );
      expect(
        (field.errorBorder! as OutlineInputBorder).borderSide.color,
        AppColors.ink,
      );
      expect(field.errorStyle!.color, AppColors.ink);
      expect(field.errorStyle!.backgroundColor, AppColors.warning);
      expect(field.floatingLabelStyle!.color, AppColors.textPrimary);
      readable(field.errorStyle!.color, 4.5);
    });
  });

  group('the battle stage', () {
    final text = theme.textTheme;

    test('every stage style is ink, spaced like the design\'s CSS, and in '
        'the design\'s font, size and weight', () {
      final styles = {
        'name': (text.stageName, AppFonts.body, 14.0, FontWeight.w700),
        'clock': (text.stageClock, AppFonts.number, 26.0, FontWeight.w700),
        'chip': (text.stageChip, AppFonts.number, 12.0, FontWeight.w700),
        'score': (text.stageScore, AppFonts.number, 80.0, FontWeight.w800),
        'count': (text.stageCount, AppFonts.number, 18.0, FontWeight.w700),
        'bar end': (text.stageBarEnd, AppFonts.number, 12.0, FontWeight.w700),
        'tag': (text.stageTag, AppFonts.body, 13.0, FontWeight.w700),
        'band': (text.stageBand, AppFonts.number, 100.0, FontWeight.w800),
        'korean band': (
          text.stageBandKorean,
          AppFonts.display,
          100.0,
          FontWeight.w400,
        ),
        'sign label': (
          text.stageSignLabel,
          AppFonts.display,
          40.0,
          FontWeight.w400,
        ),
      };
      for (final MapEntry(key: name, value: (style, family, size, weight))
          in styles.entries) {
        expect(style.fontFamily, family, reason: name);
        expect(style.fontSize, size, reason: name);
        expect(style.fontWeight, weight, reason: name);
        expect(style.color, AppColors.ink, reason: name);
        expect(
          style.leadingDistribution,
          TextLeadingDistribution.even,
          reason: name,
        );
      }
      expect(StageText.stageBandSize, text.stageBand.fontSize);
    });

    test('the label over the valid counts is the quieter secondary text', () {
      expect(text.stageCountLabel.color, AppColors.textSecondary);
      expect(text.stageCountLabel.fontSize, 11);
      expect(text.stageCountLabel.fontWeight, FontWeight.w700);
    });

    test('line heights are the design\'s: the score sits tight, Korean '
        'bands get room', () {
      expect(text.stageScore.height, 0.92);
      expect(text.stageScore.letterSpacing, -3);
      expect(text.stageClock.height, 1);
      expect(text.stageBand.height, 1);
      expect(text.stageBand.letterSpacing, -1);
      expect(text.stageBandKorean.height, 1.25);
      expect(text.stageSignLabel.height, 1.2);
      // Given in the design as a line height in points.
      expect(text.stageCount.fontSize! * text.stageCount.height!, 20);
      expect(
        text.stageCountLabel.fontSize! * text.stageCountLabel.height!,
        closeTo(14, 1e-9),
      );
      expect(
        text.stageTag.fontSize! * text.stageTag.height!,
        closeTo(16, 1e-9),
      );
    });

    test('a band takes its own size from the base size', () {
      final small = text.stageBand.apply(
        fontSizeFactor: 44 / StageText.stageBandSize,
      );
      expect(small.fontSize, 44);
      // The letters stay 1 closer whatever the size.
      expect(small.letterSpacing, -1);
    });

    test('the pictograms\' floor is lighter than their gray figure', () {
      expect(AppColors.pictogramFloor, const Color(0xFFB9C0CC));
      expect(
        AppColors.pictogramFloor.computeLuminance(),
        greaterThan(AppColors.line.computeLuminance()),
      );
    });

    test('the dimming around the setup guide is black at 45%, as the '
        'push-up silhouette dims outside its outline', () {
      expect(AppColors.setupGuideScrim, const Color(0x73000000));
    });

    test('the stage\'s bands slant 12 degrees, and each call is its own', () {
      final slant = AppHighlight.battleSlant;
      expect(slant.entry(0, 1), closeTo(math.tan(-12 * math.pi / 180), 1e-12));
      expect(identical(slant, AppHighlight.battleSlant), isFalse);
    });
  });

  test("the match-found board's texts (W2b 2-A3): ink, as the design's "
      'CSS sets them', () {
    final text = AppTheme.light.textTheme;
    List<Object?> look(TextStyle style) => [
      style.fontFamily,
      style.fontSize,
      style.fontWeight,
      style.height,
      style.letterSpacing,
      style.color,
    ];
    // "나" / "상대": 13 bold on a 20 line.
    expect(look(text.versusSide), [
      AppFonts.body,
      13,
      FontWeight.w700,
      20 / 13,
      0,
      AppColors.ink,
    ]);
    // The name: Do Hyeon 28 on a 34 line.
    expect(look(text.versusName), [
      AppFonts.display,
      28,
      FontWeight.w400,
      34 / 28,
      0,
      AppColors.ink,
    ]);
    // "AI": Oxanium 700 14 on a 20 line.
    expect(look(text.versusAiTag), [
      AppFonts.number,
      14,
      FontWeight.w700,
      20 / 14,
      0,
      AppColors.ink,
    ]);
    // "VS": Oxanium 800 34, letters 1 closer.
    expect(look(text.versusMark), [
      AppFonts.number,
      34,
      FontWeight.w800,
      1,
      -1,
      AppColors.ink,
    ]);
    // Lines spaced like CSS: the extra height split above and below.
    for (final style in [text.versusSide, text.versusName, text.versusAiTag]) {
      expect(style.leadingDistribution, TextLeadingDistribution.even);
    }
  });

  test('AppTheme.dark is the light theme, under its old name', () {
    expect(AppTheme.dark, same(AppTheme.light));
  });

  testWidgets('GymRatsApp uses the light theme', (tester) async {
    await tester.pumpWidget(testApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, same(AppTheme.light));
  });

  group('the battle\'s camera area', () {
    final text = AppTheme.light.textTheme;

    test('its texts are ink in the body font, the result button in the '
        'display font', () {
      expect(text.cameraHint.fontSize, 14);
      expect(text.cameraHint.fontWeight, FontWeight.w500);
      expect(text.cameraHint.height, 1.35);
      expect(text.cameraButton.fontSize, 14);
      expect(text.cameraButton.fontWeight, FontWeight.w700);
      expect(text.cameraNotice.fontSize, 13);
      expect(text.cameraNotice.fontWeight, FontWeight.w700);
      expect(text.cameraResult.fontFamily, AppFonts.display);
      expect(text.cameraResult.fontSize, 24);
      expect(text.cameraResult.fontSize! * text.cameraResult.height!, 32);
      for (final style in [
        text.cameraHint,
        text.cameraButton,
        text.cameraNotice,
        text.cameraResult,
      ]) {
        expect(style.color, AppColors.ink);
      }
      expect(text.cameraHint.fontFamily, AppFonts.body);
    });

    test('the setup\'s large hint and ready button (W2b 3-B): Do Hyeon 26 on '
        'a 1.2 line and Do Hyeon 22, ink, with no extra letter spacing', () {
      final hint = text.cameraSetupHint;
      expect(hint.fontFamily, AppFonts.display);
      expect(hint.fontSize, 26);
      expect(hint.fontWeight, FontWeight.w400);
      expect(hint.height, 1.2);
      expect(hint.leadingDistribution, TextLeadingDistribution.even);
      final button = text.cameraSetupButton;
      expect(button.fontFamily, AppFonts.display);
      expect(button.fontSize, 22);
      expect(button.fontWeight, FontWeight.w400);
      for (final style in [hint, button]) {
        expect(style.letterSpacing, 0);
        expect(style.color, AppColors.ink);
      }
    });

    test('the leave dialog\'s title is Do Hyeon at the headline\'s size', () {
      expect(text.leaveDialogTitle.fontFamily, AppFonts.display);
      expect(text.leaveDialogTitle.fontSize, text.headlineSmall!.fontSize);
      expect(text.leaveDialogTitle.color, text.headlineSmall!.color);
    });

    test('a dialog covers the screen with ink at 54%, not black', () {
      expect(
        theme.dialogTheme.barrierColor,
        AppColors.ink.withValues(alpha: 0.54),
      );
    });
  });
}
