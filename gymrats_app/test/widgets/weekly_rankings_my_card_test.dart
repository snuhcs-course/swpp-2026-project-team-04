import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/ranking_standing.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/weekly_rankings_my_card.dart';

StandingRow row(int rank, int points, {int battles = 3, bool me = false}) =>
    (rank: rank, points: points, battles: battles, isMe: me);

/// RankD1: 4th with 19, 22 above.
final behind = RankingStanding.of(
  me: row(4, 19, me: true),
  entries: [row(1, 31), row(2, 23), row(3, 22), row(4, 19, me: true)],
  friends: false,
);

/// RankG3: no global row of mine.
final unranked = RankingStanding.of(
  me: null,
  entries: [row(1, 31)],
  friends: false,
);

Future<void> pumpCard(
  WidgetTester tester,
  RankingStanding standing, {
  String record = '4전 2승 · KO 1',
  double width = 320,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: WeeklyRankingsMyCard(
              standing: standing,
              name: '쥐돌이',
              record: record,
              characterId: 'mouse',
            ),
          ),
        ),
      ),
    ),
  ),
);

BoxDecoration cardOf(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(WeeklyRankingsMyCard),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

void main() {
  testWidgets('my rank, name, record, points and the goal toward 3rd', (
    tester,
  ) async {
    await pumpCard(tester, behind);
    expect(tester.getSize(find.byType(WeeklyRankingsMyCard)).height, 92);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('위'), findsOneWidget);
    expect(find.text('쥐돌이'), findsOneWidget);
    expect(find.text('4전 2승 · KO 1'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('점'), findsOneWidget);
    expect(find.text('3위까지 3점'), findsOneWidget);
    // The goal's number in the number font.
    final goal = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == '3위까지 3점',
      ),
    );
    final spans = (goal.text as TextSpan).children!.first as TextSpan;
    expect(
      [for (final s in spans.children!) (s as TextSpan).style?.fontFamily],
      [null, AppFonts.number, null],
    );
    final bar = find.byType(WeeklyRankingsGoalBar);
    expect(tester.widget<WeeklyRankingsGoalBar>(bar).fill, 19 / 22);
    expect(tester.getSize(bar).height, WeeklyRankingsGoalBar.height);
    final lime = find.descendant(
      of: bar,
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AppColors.accent,
      ),
    );
    // Inside the 1.5 edge.
    expect(
      tester.getSize(lime).width,
      closeTo((tester.getSize(bar).width - 3) * 19 / 22, 0.01),
    );
    expect(cardOf(tester).color, AppColors.selectedFill);
    expect(tester.widget<Text>(find.text('4')).style?.fontSize, 40);
  });

  testWidgets('my character, idle in my team color', (tester) async {
    await pumpCard(tester, behind);
    final figure = tester.widget<CharacterFigure>(find.byType(CharacterFigure));
    expect(figure.characterId, 'mouse');
    expect(
      tester.getSize(find.byType(WeeklyRankingsMyFigure)),
      const Size.square(WeeklyRankingsMyFigure.size),
    );
  });

  testWidgets('first: ahead of 2nd, the bar full', (tester) async {
    final first = RankingStanding.of(
      me: null,
      entries: [row(1, 19, me: true), row(2, 15)],
      friends: true,
    );
    await pumpCard(tester, first);
    expect(find.text('친구'), findsOneWidget);
    expect(find.text('2위보다 4점 앞섬'), findsOneWidget);
    expect(
      tester
          .widget<WeeklyRankingsGoalBar>(find.byType(WeeklyRankingsGoalBar))
          .fill,
      1,
    );
  });

  testWidgets('two-digit ranks in the smaller number', (tester) async {
    await pumpCard(
      tester,
      RankingStanding.of(
        me: row(63, 4, me: true),
        entries: [row(50, 6)],
        friends: false,
      ),
    );
    expect(tester.widget<Text>(find.text('63')).style?.fontSize, 32);
    expect(find.text('50위까지 2점'), findsOneWidget);
  });

  testWidgets('before my first battle: white, a gray panel, – and 0 in gray, '
      'one line', (tester) async {
    await pumpCard(tester, unranked, record: '이번 주 기록 없음');
    expect(cardOf(tester).color, AppColors.card);
    expect(find.text('–'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('–')).style?.color,
      AppColors.inactive,
    );
    expect(
      tester.widget<Text>(find.text('위')).style?.color,
      AppColors.inactive,
    );
    expect(
      tester.widget<Text>(find.text('0')).style?.color,
      AppColors.inactive,
    );
    expect(find.text('이번 주 기록 없음'), findsOneWidget);
    expect(find.text('대결하면 순위에 올라요'), findsOneWidget);
    expect(find.byType(WeeklyRankingsGoalBar), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter != null &&
            w.painter.runtimeType.toString() == '_PanelPainter',
      ),
      paints..path(color: AppColors.cardHigh),
    );
  });

  testWidgets('no friends: no goal line', (tester) async {
    await pumpCard(
      tester,
      RankingStanding.of(
        me: null,
        entries: [row(1, 19, me: true)],
        friends: true,
      ),
    );
    expect(find.byType(WeeklyRankingsGoalBar), findsNothing);
    expect(find.textContaining('대결하면'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('reads as one sentence', (tester) async {
    await pumpCard(tester, behind);
    expect(
      tester.getSemantics(find.byType(WeeklyRankingsMyCard)).label,
      '전체 4위, 쥐돌이, 19점, 4전 2승 · KO 1, 3위까지 3점',
    );
    await pumpCard(tester, unranked, record: '이번 주 기록 없음');
    expect(
      tester.getSemantics(find.byType(WeeklyRankingsMyCard)).label,
      '전체 순위 없음, 쥐돌이, 0점, 이번 주 기록 없음, 대결하면 순위에 올라요',
    );
  });

  testWidgets('fits a narrow phone with a large text size', (tester) async {
    for (final (width, scale) in [(280.0, 1.0), (320.0, 1.3)]) {
      await pumpCard(tester, behind, width: width, textScale: scale);
      expect(tester.takeException(), isNull, reason: '$width x$scale');
    }
  });

  testWidgets('a very large text size: words up to 1.3x, the rank and '
      'points shrunk to their share before my name runs out', (tester) async {
    final far = RankingStanding.of(
      me: row(77, 1, me: true),
      entries: [row(50, 6)],
      friends: false,
    );
    await pumpCard(tester, far, width: 280, textScale: 1.6);
    expect(tester.takeException(), isNull);
    expect(WeeklyRankingsMyCard.maxTextScale, 1.3);
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('쥐돌이'))).scale(10),
      moreOrLessEquals(13),
    );
    final card = tester.getSize(find.byType(WeeklyRankingsMyCard)).width;
    for (final text in ['77', '1']) {
      final cell = find
          .ancestor(of: find.text(text), matching: find.byType(FittedBox))
          .first;
      expect(
        tester.getSize(cell).width,
        lessThanOrEqualTo(card * WeeklyRankingsMyCard.cellShare),
        reason: text,
      );
    }
    expect(tester.getSize(find.text('쥐돌이')).width, greaterThan(0));
  });
}
