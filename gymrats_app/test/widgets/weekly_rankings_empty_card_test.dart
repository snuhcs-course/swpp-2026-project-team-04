import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:gymrats_app/widgets/weekly_rankings_empty_card.dart';

Future<void> pumpCard(
  WidgetTester tester,
  Widget card, {
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
          child: SizedBox(width: width, child: card),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('no friends: the podium, two lines and a button to add some', (
    tester,
  ) async {
    var added = 0;
    await pumpCard(
      tester,
      WeeklyRankingsEmptyCard.noFriends(onAddFriends: () => added++),
    );
    expect(find.text('아직 비교할 친구가 없어요'), findsOneWidget);
    expect(find.text('친구를 추가하면 이번 주 점수를 함께 겨뤄요.'), findsOneWidget);
    expect(
      tester.widget<RankingPodiumIcon>(find.byType(RankingPodiumIcon)).size,
      40,
    );
    expect(find.text('친구 추가하러 가기'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    final button = find.byType(OutlinedButton);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    await tester.tap(button);
    expect(added, 1);
  });

  testWidgets('an empty week: the same card without a button', (tester) async {
    await pumpCard(tester, const WeeklyRankingsEmptyCard.emptyWeek());
    expect(find.text('이번 주 온라인 대결 기록이 아직 없어요.'), findsOneWidget);
    expect(find.text('첫 승점을 올려 보세요!'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(RankingPodiumIcon), findsOneWidget);
  });

  testWidgets('a dashed gray edge on white at 70%', (tester) async {
    await pumpCard(tester, const WeeklyRankingsEmptyCard.emptyWeek());
    final box =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(WeeklyRankingsEmptyCard),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(box.color, AppColors.card.withValues(alpha: 0.7));
    // Many short gray strokes, not one solid edge.
    final edge = find
        .descendant(
          of: find.byType(WeeklyRankingsEmptyCard),
          matching: find.byType(CustomPaint),
        )
        .first;
    var dashes = 0;
    expect(
      edge,
      paints..everything((method, arguments) {
        if (method == #drawPath &&
            (arguments[1] as Paint).color.toARGB32() ==
                AppColors.inactive.toARGB32() &&
            (arguments[1] as Paint).style == PaintingStyle.stroke) {
          dashes++;
        }
        return true;
      }),
    );
    expect(dashes, greaterThan(20));
  });

  testWidgets('fits a narrow phone with a large text size', (tester) async {
    await pumpCard(
      tester,
      WeeklyRankingsEmptyCard.noFriends(onAddFriends: () {}),
      width: 280,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
