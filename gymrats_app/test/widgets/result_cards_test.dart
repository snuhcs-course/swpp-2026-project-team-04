import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/result_cards.dart';

ResultRecent _recent({
  List<int> scores = const [80, 95, 110, 105, 130, 150, 185, 240],
  int average = 136,
  int difference = 104,
}) => ResultRecent(
  scores: scores,
  firstPlayedAt: DateTime(2026, 10, 28),
  average: average,
  averageCount: 5,
  difference: difference,
);

void main() {
  Future<void> show(WidgetTester tester, Widget card) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Align(alignment: Alignment.topCenter, child: card),
          ),
        ),
      ),
    );
  }

  group('the personal best card', () {
    const best = ResultNewBest(previous: 185, current: 240, gain: 55);

    testWidgets('the old best, the new one in bold, and the gain, in ink on '
        'lime with an ink edge', (tester) async {
      await show(tester, const ResultBestCard(best));
      expect(find.text('개인 최고 기록 갱신'), findsOneWidget);
      expect(find.text('185점 → 240점 · 55점 올랐어요'), findsOneWidget);
      final line = tester.widget<Text>(find.text('185점 → 240점 · 55점 올랐어요'));
      final spans = (line.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.first.text, '240점');
      expect(spans.first.style?.fontWeight, FontWeight.w700);
      expect(line.style?.color, AppColors.ink);

      final box =
          tester
                  .widget<Container>(
                    find.ancestor(
                      of: find.text('개인 최고 기록 갱신'),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(box.color, AppColors.accent);
      expect(box.border, Border.all(color: AppColors.ink, width: 1.5));
      // A lime trophy on an ink disc: lime on ink is allowed.
      expect(
        tester.widget<Icon>(find.byIcon(Icons.emoji_events_outlined)).color,
        AppColors.accent,
      );
    });
  });

  group('the latest battles card', () {
    /// The bars, left to right: their boxes.
    List<(Rect, Color)> bars(WidgetTester tester) => [
      for (final element
          in find
              .descendant(
                of: find.byType(ResultRecentCard),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration).borderRadius != null,
                ),
              )
              .evaluate())
        (
          tester.getRect(find.byElementPredicate((e) => e == element)),
          ((element.widget as Container).decoration! as BoxDecoration).color!,
        ),
    ];

    testWidgets('eight bars: the earlier ones gray, this one ink at the '
        'right; the highest is 88 points tall', (tester) async {
      await show(tester, ResultRecentCard(_recent()));
      final drawn = bars(tester);
      expect(drawn, hasLength(8));
      expect(drawn.map((bar) => bar.$2), [
        for (var i = 0; i < 7; i++) AppColors.inactive,
        AppColors.ink,
      ]);
      expect(drawn.last.$1.height, ResultRecentCard.barsHeight);
      // 80 of 240.
      expect(drawn.first.$1.height, (80 / 240 * 88).roundToDouble());
      // All stand on the same floor.
      expect(drawn.map((bar) => bar.$1.bottom).toSet(), hasLength(1));
    });

    testWidgets('the header, the chip, the dates and the average label', (
      tester,
    ) async {
      await show(tester, ResultRecentCard(_recent()));
      expect(find.text('최근 8판 중 이번 판'), findsOneWidget);
      expect(find.text('평균보다 +104점'), findsOneWidget);
      expect(find.text('최근 5판 평균 136'), findsOneWidget);
      expect(find.text('10/28'), findsOneWidget);
      expect(find.text('이번 판 240'), findsOneWidget);
      final chip =
          tester
                  .widget<DecoratedBox>(
                    find.ancestor(
                      of: find.text('평균보다 +104점'),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as ShapeDecoration;
      expect(chip.color, AppColors.accent.withValues(alpha: 0.6));
    });

    testWidgets('the dashed line sits at the average, the label just above', (
      tester,
    ) async {
      await show(tester, ResultRecentCard(_recent()));
      final chart = tester.getRect(
        find.descendant(
          of: find.byType(ResultRecentCard),
          matching: find.byType(Stack),
        ),
      );
      final line = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is ResultDashedLine,
        ),
      );
      final at = (136 / 240 * 88).roundToDouble();
      expect(chart.bottom - line.bottom, at);
      expect(
        tester.getRect(find.text('최근 5판 평균 136')).bottom,
        closeTo(chart.bottom - at - AppSpacing.s4, 1),
      );
    });

    testWidgets('a high average puts its label under the line, inside the '
        'chart', (tester) async {
      await show(
        tester,
        ResultRecentCard(_recent(scores: const [200, 210, 220], average: 210)),
      );
      final chart = tester.getRect(
        find.descendant(
          of: find.byType(ResultRecentCard),
          matching: find.byType(Stack),
        ),
      );
      final label = tester.getRect(find.text('최근 5판 평균 210'));
      expect(label.top, greaterThan(chart.top));
      expect(label.bottom, lessThanOrEqualTo(chart.bottom));
    });

    testWidgets('fewer battles fill the slots from the right', (tester) async {
      await show(
        tester,
        ResultRecentCard(_recent(scores: const [100, 120, 90])),
      );
      expect(find.text('최근 3판 중 이번 판'), findsOneWidget);
      expect(find.text('이번 판 90'), findsOneWidget);
      final drawn = bars(tester);
      expect(drawn, hasLength(3));
      final chart = tester.getRect(
        find.descendant(
          of: find.byType(ResultRecentCard),
          matching: find.byType(Stack),
        ),
      );
      expect(drawn.last.$1.right, closeTo(chart.right, 0.5));
      expect(drawn.first.$1.left, greaterThan(chart.center.dx));
    });

    test('more than eight keep the last eight', () {
      final card = ResultRecentCard(
        _recent(scores: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
      );
      expect(card.shown, [3, 4, 5, 6, 7, 8, 9, 10]);
    });

    for (final (difference, words) in const [
      (-20, '평균보다 -20점'),
      (0, '평균과 같아요'),
    ]) {
      testWidgets('a score $difference from the average: "$words" on a gray '
          'chip', (tester) async {
        await show(tester, ResultRecentCard(_recent(difference: difference)));
        expect(find.text(words), findsOneWidget);
        final chip =
            tester
                    .widget<DecoratedBox>(
                      find.ancestor(
                        of: find.text(words),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        expect(chip.color, AppColors.border);
      });
    }

    testWidgets('a screen reader hears the scores and the average', (
      tester,
    ) async {
      await show(tester, ResultRecentCard(_recent(scores: const [100, 120])));
      expect(
        find.bySemanticsLabel('최근 2판 점수 100, 120, 최근 5판 평균 136'),
        findsOneWidget,
      );
    });
  });

  group('the character card (A10 spec 2)', () {
    const entry = ResultCoachEntry(
      characterId: 'seal',
      name: '물렁범',
      ending: '범',
      lineCount: 4,
    );

    testWidgets('the name tag, the line with its count, and the buttons', (
      tester,
    ) async {
      final taps = <String>[];
      await show(
        tester,
        ResultCoachCard(
          entry: entry,
          onListen: () => taps.add('hear'),
          onSkip: () => taps.add('skip'),
        ),
      );
      expect(find.text('물렁범'), findsOneWidget);
      expect(
        find.bySemanticsLabel('물렁범, 이번 판 이야기해 줄게범! 할 말이 4개 있어.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('result-coach-character')), findsOne);
      await tester.tap(find.text('이야기 듣기'));
      await tester.tap(find.text('건너뛰기'));
      expect(taps, ['hear', 'skip']);
      final card = tester.getRect(find.byType(ResultCoachCard));
      expect(card.height, greaterThanOrEqualTo(ResultCoachCard.minHeight));
      // Every button is at least 44 high.
      for (final button in [
        find.byType(FilledButton),
        find.byType(TextButton),
      ]) {
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('the text starts right of the character\'s seat', (
      tester,
    ) async {
      await show(
        tester,
        ResultCoachCard(entry: entry, onListen: () {}, onSkip: () {}),
      );
      final card = tester.getRect(find.byType(ResultCoachCard));
      expect(
        tester.getRect(find.byType(FilledButton)).left,
        greaterThanOrEqualTo(card.left + ResultCoachCard.seatWidth),
      );
    });

    testWidgets('while the talk loads: no count, and the buttons wait', (
      tester,
    ) async {
      final taps = <String>[];
      await show(
        tester,
        ResultCoachCard(
          entry: const ResultCoachEntry(
            characterId: 'mouse',
            name: 'GYM마우스',
            ending: '찍',
          ),
          onListen: () => taps.add('hear'),
          onSkip: () => taps.add('skip'),
        ),
      );
      expect(find.bySemanticsLabel('GYM마우스, 이번 판 이야기해 줄게찍!'), findsOneWidget);
      await tester.tap(find.text('이야기 듣기'));
      await tester.tap(find.text('건너뛰기'));
      expect(taps, isEmpty);
    });

    test('its line marks the count', () {
      final pieces = ResultCoachCard.lineOf(entry);
      expect(pieces.where((p) => p.marked).single.text, '4개');
    });
  });

  group('the feedback link', () {
    testWidgets('"자세 기록 표로 보기", 44 high, opens the feedback', (tester) async {
      var opened = 0;
      await show(tester, ResultFeedbackLink(onPressed: () => opened++));
      expect(find.text('자세 기록 표로 보기'), findsOneWidget);
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.text('자세 기록 표로 보기'));
      expect(opened, 1);
    });
  });

  group('the placeholder while the earlier battles load', () {
    testWidgets('one muted line in a card: no number, no chart', (
      tester,
    ) async {
      await show(tester, const ResultComparisonPlaceholder());
      Finder inside(Finder matching) => find.descendant(
        of: find.byType(ResultComparisonPlaceholder),
        matching: matching,
      );
      final line = tester.widget<Text>(
        find.text(ResultComparisonPlaceholder.text),
      );
      expect(line.style?.color, AppColors.textMuted);
      expect(inside(find.byType(Card)), findsOneWidget);
      expect(inside(find.byType(Text)), findsOneWidget);
      expect(inside(find.textContaining(RegExp(r'\d'))), findsNothing);
      expect(inside(find.byType(ResultRecentCard)), findsNothing);
      expect(
        inside(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ResultDashedLine,
          ),
        ),
        findsNothing,
      );
    });
  });
}
