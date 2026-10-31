import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/game_health_bar.dart';

GameRepScore _score(int points) =>
    GameRepScore(grade: GameGrade.good, combo: 1, fever: false, points: points);

Widget _bar(double share, {GameRepScore? mine, GameRepScore? theirs}) =>
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: GameHealthBar(
          myShare: share,
          myLastScore: mine,
          opponentLastScore: theirs,
        ),
      ),
    );

void main() {
  for (final (share, mine, theirs) in const [
    (0.5, '나 50%', '상대 50%'),
    (0.625, '나 63%', '상대 37%'),
    (1.0, '나 100%', '상대 0%'),
    (0.0, '나 0%', '상대 100%'),
  ]) {
    testWidgets('a share of $share fills the bar and reads $mine', (
      tester,
    ) async {
      await tester.pumpWidget(_bar(share));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FractionallySizedBox>(find.byKey(const Key('myBarShare')))
            .widthFactor,
        share,
      );
      expect(find.text(mine), findsOneWidget);
      expect(find.text(theirs), findsOneWidget);
      expect(find.bySemanticsLabel('체력 바, $mine, $theirs'), findsOneWidget);
    });
  }

  testWidgets('no popup before anyone scores', (tester) async {
    await tester.pumpWidget(_bar(0.5));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('each +N is in its side\'s color', (tester) async {
    await tester.pumpWidget(_bar(0.5, mine: _score(15), theirs: _score(30)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<Text>(find.text('+15')).style!.color,
      AppColors.accent,
    );
    expect(
      tester.widget<Text>(find.text('+30')).style!.color,
      AppColors.opponent,
    );
  });

  testWidgets('a +N fades in, stays, and fades away', (tester) async {
    await tester.pumpWidget(_bar(0.55, mine: _score(10)));
    double opacity() => tester
        .widget<Opacity>(
          find.ancestor(of: find.text('+10'), matching: find.byType(Opacity)),
        )
        .opacity;
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacity(), 1);
    await tester.pumpAndSettle();
    expect(opacity(), 0);
  });

  testWidgets('a new rep pops again, even with the same points', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(0.55, mine: _score(10)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_bar(0.6, mine: _score(10)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: find.text('+10'), matching: find.byType(Opacity)),
          )
          .opacity,
      1,
    );
  });

  testWidgets('both popups fit a narrow phone on the largest system font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_bar(0.5, mine: _score(40), theirs: _score(40)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('+40'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bar keeps its place when a popup appears', (tester) async {
    await tester.pumpWidget(_bar(0.5));
    final before = tester.getTopLeft(find.byKey(const Key('myBarShare')));
    await tester.pumpWidget(_bar(0.5, mine: _score(40)));
    expect(tester.getTopLeft(find.byKey(const Key('myBarShare'))), before);
    expect(tester.takeException(), isNull);
  });
}
