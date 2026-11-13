import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/help_pictures.dart';
import 'package:gymrats_app/widgets/help_rules.dart';

void main() {
  /// [picture] on a 360-wide card, as the rules screen shows it.
  Future<void> show(
    WidgetTester tester,
    Widget picture, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 740),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: picture,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The [ColoredBox] of [color] inside [picture], leaving out the bands
  /// behind the points (lime too). Call it after the picture is shown.
  Finder fill(Type picture, Color color) {
    final bands = find
        .descendant(
          of: find.byType(HelpMarkedPoints),
          matching: find.byType(ColoredBox),
        )
        .evaluate()
        .toSet();
    return find.descendant(
      of: find.byType(picture),
      matching: find.byElementPredicate(
        (element) =>
            element.widget is ColoredBox &&
            (element.widget as ColoredBox).color == color &&
            !bands.contains(element),
      ),
    );
  }

  /// Every color text is painted in, with what a span takes from the span
  /// around it; icons left out.
  Set<Color> textColors(WidgetTester tester) {
    final colors = <Color>{};
    void walk(InlineSpan span, Color? around) {
      if (span is! TextSpan) return;
      final color = span.style?.color ?? around;
      final isIcon = span.style?.fontFamily == Icons.home.fontFamily;
      if (!isIcon && (span.text ?? '').trim().isNotEmpty && color != null) {
        colors.add(color);
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child, color);
      }
    }

    for (final paragraph in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    )) {
      walk(paragraph.text, null);
    }
    return colors;
  }

  const fills = [
    AppColors.accent,
    AppColors.opponent,
    AppColors.warning,
    AppColors.fever,
    AppColors.danger,
  ];

  group('the health bar picture', () {
    testWidgets('both parts fill the bar inside its ink edge: lime 65, '
        'pink 35, a white gap between', (tester) async {
      await show(tester, const HelpBarPicture());
      final lime = tester.getRect(fill(HelpBarPicture, AppColors.accent));
      final pink = tester.getRect(fill(HelpBarPicture, AppColors.opponent));
      // The old bar drew its parts 0 high, so they did not show.
      const inner = AppSpacing.s24 - 2 * HelpBarPicture.barEdge;
      expect(lime.height, inner);
      expect(pink.height, inner);
      expect(lime.top, pink.top);
      expect(pink.left - lime.right, AppSpacing.s4);
      expect(lime.width / (lime.width + pink.width), closeTo(0.65, 0.01));

      final bar = tester.widget<Container>(
        find.ancestor(
          of: fill(HelpBarPicture, AppColors.accent),
          matching: find.byType(Container),
        ),
      );
      final box = bar.decoration! as BoxDecoration;
      expect(box.color, AppColors.card);
      expect(box.border, Border.all(color: AppColors.ink, width: 2));
    });

    testWidgets('the score is ink on a lime band over the end of the lime', (
      tester,
    ) async {
      await show(tester, const HelpBarPicture());
      final score = find.text(HelpRules.barScore);
      expect(tester.widget<Text>(score).style?.color, AppColors.ink);
      final band = find.descendant(
        of: find.byType(HelpMarkedPoints),
        matching: find.byType(ColoredBox),
      );
      expect(tester.widget<ColoredBox>(band).color, AppColors.accent);
      // The band leaves the top of the digits clear.
      expect(tester.getRect(band).top, greaterThan(tester.getRect(score).top));

      final limeEnd = tester
          .getRect(fill(HelpBarPicture, AppColors.accent))
          .right;
      expect(
        tester.getRect(find.byType(HelpMarkedPoints)).center.dx,
        closeTo(limeEnd, 30),
      );
    });

    testWidgets('나 and 상대 are ink with a lime and a pink swatch', (
      tester,
    ) async {
      await show(tester, const HelpBarPicture());
      for (final side in ['나', '상대']) {
        expect(
          tester.widget<Text>(find.text(side)).style?.color,
          AppColors.textPrimary,
        );
      }
      final swatches = tester
          .widgetList<HelpSwatch>(find.byType(HelpSwatch))
          .map((swatch) => swatch.color);
      expect(swatches, [AppColors.accent, AppColors.opponent]);
      // Lime before 나, pink after 상대.
      expect(
        tester.getRect(find.byType(HelpSwatch).first).right,
        lessThan(tester.getRect(find.text('나')).left),
      );
      expect(
        tester.getRect(find.byType(HelpSwatch).last).left,
        greaterThan(tester.getRect(find.text('상대')).right),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.arrow_forward_rounded)).color,
        AppColors.ink,
      );
    });
  });

  group('the score picture', () {
    testWidgets('four tiles, each the points in ink on a lime band', (
      tester,
    ) async {
      await show(tester, const HelpScorePicture());
      final marks = find.byType(HelpMarkedPoints);
      expect(marks, findsNWidgets(4));
      // In order: Average, Good, Excellent, the combo.
      expect(
        tester.widgetList<HelpMarkedPoints>(marks).map((mark) => mark.points),
        [for (final (points, _) in HelpRules.scores) points],
      );
      for (var tile = 0; tile < 4; tile++) {
        final mark = marks.at(tile);
        final digits = find.descendant(of: mark, matching: find.byType(Text));
        expect(tester.widget<Text>(digits).style?.color, AppColors.ink);
        final band = find.descendant(
          of: mark,
          matching: find.byType(ColoredBox),
        );
        expect(tester.widget<ColoredBox>(band).color, AppColors.accent);
      }
      for (final (_, label) in HelpRules.scores) {
        expect(find.text(label), findsOneWidget);
      }
      // +5 is on two tiles: Average and the combo.
      expect(find.text('+5'), findsNWidgets(2));
    });

    testWidgets('the timeline: the base part gray, fever lime, inside an ink '
        'edge, as long as their seconds', (tester) async {
      await show(tester, const HelpScorePicture());
      final base = tester.getRect(fill(HelpScorePicture, AppColors.cardHigh));
      final fever = tester.getRect(fill(HelpScorePicture, AppColors.accent));
      expect(base.height, AppSpacing.s32 - 2 * HelpScorePicture.timelineEdge);
      expect(fever.height, base.height);
      expect(
        base.width / fever.width,
        closeTo(HelpRules.baseSeconds / HelpRules.feverSeconds, 0.05),
      );
      expect(
        tester.widget<Text>(find.text(HelpRules.feverLabel)).style?.color,
        AppColors.ink,
      );
      expect(find.text('0초'), findsOneWidget);
      expect(find.text('${HelpRules.totalSeconds}초'), findsOneWidget);
    });
  });

  group('the reminder picture', () {
    testWidgets('ink icons; the danger one on red, the others on lime', (
      tester,
    ) async {
      await show(tester, const HelpReminderPicture());
      for (final rule in HelpRules.reminders) {
        expect(find.text(rule.title), findsOneWidget);
        expect(find.text(rule.body), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(rule.icon)).color,
          AppColors.ink,
        );
      }
      final boxes = tester
          .widgetList<HelpIconBox>(find.byType(HelpIconBox))
          .map((box) => box.fill);
      expect(boxes, [
        AppColors.danger.withValues(alpha: 0.30),
        AppColors.accent.withValues(alpha: 0.55),
        AppColors.accent.withValues(alpha: 0.55),
      ]);
      expect(
        tester.getSize(find.byType(HelpIconBox).first),
        const Size(48, 48),
      );
    });
  });

  for (final (name, picture) in const [
    ('health bar', HelpBarPicture()),
    ('score', HelpScorePicture()),
    ('reminder', HelpReminderPicture()),
  ]) {
    testWidgets('the $name picture paints no text in a fill color', (
      tester,
    ) async {
      await show(tester, picture);
      final colors = textColors(tester);
      expect(colors, isNotEmpty);
      for (final color in fills) {
        expect(colors, isNot(contains(color)));
      }
    });

    testWidgets('the $name picture fits at 2x text', (tester) async {
      await show(tester, picture, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
