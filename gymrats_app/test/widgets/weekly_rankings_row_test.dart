import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/weekly_rankings_row.dart';

Future<void> pumpRow(
  WidgetTester tester,
  Widget row, {
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
          child: SizedBox(width: width, child: row),
        ),
      ),
    ),
  ),
);

WeeklyRankingsRow entry({
  int rank = 2,
  String nickname = '헬스쿼카',
  int points = 23,
  int battles = 4,
  bool isMe = false,
}) => WeeklyRankingsRow(
  rank: rank,
  nickname: nickname,
  points: points,
  battles: battles,
  wins: battles == 0 ? 0 : 3,
  koWins: battles == 0 ? 0 : 1,
  isMe: isMe,
);

BoxDecoration rowBox(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(WeeklyRankingsRow),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

/// The row's edge, drawn over its content.
Color edgeOf(WidgetTester tester) =>
    ((tester
                        .widget<Container>(
                          find
                              .descendant(
                                of: find.byType(WeeklyRankingsRow),
                                matching: find.byType(Container),
                              )
                              .first,
                        )
                        .foregroundDecoration!
                    as BoxDecoration)
                .border!
            as Border)
        .top
        .color;

Color? colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  testWidgets('a row: the rank in its cell, name, record and points', (
    tester,
  ) async {
    await pumpRow(tester, entry());
    expect(tester.getSize(find.byType(WeeklyRankingsRow)).height, 46);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('헬스쿼카'), findsOneWidget);
    expect(find.text('4전 3승 · KO 1'), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(find.text('점'), findsOneWidget);
    final row = entry();
    expect(row.rankFill, AppColors.card);
    expect(rowBox(tester).color, AppColors.card);
    expect(edgeOf(tester), AppColors.ink);
    expect(colorOf(tester, '2'), AppColors.ink);
    expect(tester.widget<Text>(find.text('2')).style?.fontSize, 20);
    // The rank cell is 40 wide.
    final cell = find
        .ancestor(of: find.text('2'), matching: find.byType(Container))
        .first;
    expect(tester.getSize(cell).width, WeeklyRankingsRow.rankWidth);
    // The points sit in the row's middle.
    expect(
      tester.getCenter(find.text('23')).dy,
      closeTo(tester.getCenter(find.byType(WeeklyRankingsRow)).dy, 6),
    );
  });

  test('the rank cell: ink for me, orange first, gray without a battle', () {
    expect(entry(rank: 1).rankFill, AppColors.warning);
    expect(entry(rank: 1, isMe: true).rankFill, AppColors.ink);
    expect(entry(rank: 4, isMe: true).rankFill, AppColors.ink);
    expect(entry(rank: 1, battles: 0).rankFill, AppColors.cardHigh);
    expect(entry(rank: 1, battles: 0, isMe: true).rankFill, AppColors.ink);
    expect(entry(rank: 3).rankFill, AppColors.card);
  });

  testWidgets('my row is lime with a 나 mark, its rank lime on ink', (
    tester,
  ) async {
    await pumpRow(tester, entry(rank: 4, nickname: '쥐돌이', isMe: true));
    expect(rowBox(tester).color, AppColors.accent);
    expect(find.byType(WeeklyRankingsMeMark), findsOneWidget);
    expect(find.text('나'), findsOneWidget);
    expect(colorOf(tester, '4'), AppColors.accent);
    expect(colorOf(tester, '4전 3승 · KO 1'), AppColors.ink);
    // 16 high, taller only when its letter needs it.
    expect(
      tester.getSize(find.byType(WeeklyRankingsMeMark)).height,
      greaterThanOrEqualTo(WeeklyRankingsMeMark.height),
    );
  });

  testWidgets('a friend without a battle: – and 이번 주 기록 없음 in gray', (
    tester,
  ) async {
    await pumpRow(
      tester,
      entry(rank: 1, nickname: '근육곰', points: 0, battles: 0),
    );
    expect(find.text('1'), findsNothing);
    expect(find.text('–'), findsOneWidget);
    expect(colorOf(tester, '–'), AppColors.inactive);
    expect(find.text('이번 주 기록 없음'), findsOneWidget);
    expect(colorOf(tester, '근육곰'), AppColors.textSecondary);
    expect(colorOf(tester, '0'), AppColors.inactive);
    expect(edgeOf(tester), AppColors.inactive);
  });

  testWidgets('my row without a battle stays lime, – on ink', (tester) async {
    await pumpRow(
      tester,
      entry(rank: 1, nickname: '쥐돌이', points: 0, battles: 0, isMe: true),
    );
    expect(rowBox(tester).color, AppColors.accent);
    expect(colorOf(tester, '–'), AppColors.accent);
    expect(colorOf(tester, '쥐돌이'), AppColors.ink);
    expect(colorOf(tester, '0'), AppColors.ink);
    expect(edgeOf(tester), AppColors.ink);
  });

  testWidgets('two-digit ranks in the smaller number', (tester) async {
    await pumpRow(tester, entry(rank: 12, points: 3));
    expect(tester.widget<Text>(find.text('12')).style?.fontSize, 17);
  });

  testWidgets('a row reads as one sentence', (tester) async {
    await pumpRow(
      tester,
      entry(rank: 4, nickname: '쥐돌이', points: 19, isMe: true),
    );
    expect(
      tester.getSemantics(find.byType(WeeklyRankingsRow)).label,
      '4위, 쥐돌이 (나), 19점, 4전 3승 · KO 1',
    );
    await pumpRow(tester, entry(nickname: '근육곰', points: 0, battles: 0));
    expect(
      tester.getSemantics(find.byType(WeeklyRankingsRow)).label,
      '순위 없음, 근육곰, 0점, 이번 주 기록 없음',
    );
  });

  testWidgets('a long name fits a narrow row with a large text size', (
    tester,
  ) async {
    await pumpRow(
      tester,
      entry(nickname: '아주아주긴닉네임입니다', points: 120, isMe: true),
      width: 280,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the list heading: its name slanted and a note on the right', (
    tester,
  ) async {
    await pumpRow(
      tester,
      const WeeklyRankingsListHeading(title: 'TOP 50', note: '같은 점수는 같은 등수'),
    );
    final title = tester.widget<Text>(find.text('TOP 50'));
    expect(title.style?.fontFamily, AppFonts.display);
    expect(title.style?.fontSize, 18);
    expect(colorOf(tester, '같은 점수는 같은 등수'), AppColors.textSecondary);
    expect(tester.getTopRight(find.text('같은 점수는 같은 등수')).dx, closeTo(320, 0.5));
    // An empty note leaves the name alone.
    await pumpRow(tester, const WeeklyRankingsListHeading(title: 'TOP 50'));
    expect(find.text('TOP 50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the edge is drawn over the fills, which are clipped inside '
      'it (the corners stay ink)', (tester) async {
    await pumpRow(tester, entry(rank: 1));
    final outline = tester.widget<WeeklyRankingsOutline>(
      find.byType(WeeklyRankingsOutline),
    );
    expect((outline.edge, outline.corner), (1.5, 9.0));
    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(WeeklyRankingsOutline),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clip.borderRadius, const BorderRadius.all(Radius.circular(9 - 1.5)));
    // The orange rank cell is painted under the clip, the ink edge last.
    final box = tester.getRect(find.byType(WeeklyRankingsOutline));
    expect(
      find.byType(WeeklyRankingsOutline),
      paints
        ..clipRRect(
          rrect: RRect.fromRectAndRadius(
            Rect.fromLTWH(1.5, 1.5, box.width - 3, box.height - 3),
            const Radius.circular(7.5),
          ),
        )
        ..rect(color: AppColors.warning)
        ..drrect(),
    );
  });
}
