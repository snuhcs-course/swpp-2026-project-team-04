import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:gymrats_app/widgets/help_rules.dart';

void main() {
  /// [home] on a phone of [size]; 412×915 unless given.
  Future<void> show(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: home));
    await tester.pumpAndSettle();
  }

  /// A page with a button that opens the rules, as '?' on home does.
  Widget homeBelow() => Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
        ),
        child: const Text('home'),
      ),
    ),
  );

  Future<void> openFromHome(WidgetTester tester) async {
    await show(tester, homeBelow());
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
  }

  final [bar, score, safety] = HelpRules.pages;

  testWidgets('다음 turns through the three pages with their pictures', (
    tester,
  ) async {
    await show(tester, HelpScreen(onStart: () {}));
    expect(find.text('게임 규칙'), findsOneWidget);
    expect(find.text(bar.title), findsOneWidget);
    expect(find.text(bar.body), findsOneWidget);
    expect(find.text('KO 100점 차'), findsOneWidget);
    expect(find.text(HelpRules.barScore), findsOneWidget);
    expect(find.text('나'), findsOneWidget);
    expect(find.text('상대'), findsOneWidget);
    expect(find.bySemanticsLabel('3장 중 1장'), findsOneWidget);

    await tapNext(tester);
    expect(find.text(score.title), findsOneWidget);
    expect(find.text(score.body), findsOneWidget);
    for (final (points, label) in HelpRules.scores) {
      expect(find.text(points), findsOneWidget);
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(HelpRules.baseLabel), findsOneWidget);
    expect(find.text(HelpRules.feverLabel), findsOneWidget);
    expect(find.text('20초부터 ×2'), findsOneWidget);
    expect(find.bySemanticsLabel('3장 중 2장'), findsOneWidget);

    await tapNext(tester);
    expect(find.text(safety.title), findsOneWidget);
    expect(find.text(safety.body), findsOneWidget);
    for (final rule in HelpRules.reminders) {
      expect(find.text(rule.title), findsOneWidget);
      expect(find.text(rule.body), findsOneWidget);
    }
    // The danger row is red like the danger edge; the others are lime.
    Color? iconColor(IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon)).color;
    final [danger, ...others] = HelpRules.reminders;
    expect(iconColor(danger.icon), AppColors.danger);
    for (final rule in others) {
      expect(iconColor(rule.icon), AppColors.accent);
    }
    expect(find.bySemanticsLabel('3장 중 3장'), findsOneWidget);
    expect(find.text('다음'), findsNothing);
  });

  testWidgets('swiping turns the pages too', (tester) async {
    await show(tester, HelpScreen(onStart: () {}));
    await tester.fling(find.text(bar.title), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(score.title), findsOneWidget);

    await tester.fling(find.text(score.title), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(bar.title), findsOneWidget);
  });

  testWidgets('after sign-up: no back arrow; 건너뛰기 calls onStart', (
    tester,
  ) async {
    var started = 0;
    await show(tester, HelpScreen(onStart: () => started++));
    expect(find.byTooltip('뒤로'), findsNothing);
    await tester.tap(find.text('건너뛰기'));
    expect(started, 1);
  });

  testWidgets('after sign-up: the last page has 시작하기 and its hint instead '
      'of 건너뛰기; it calls onStart', (tester) async {
    var started = 0;
    await show(tester, HelpScreen(onStart: () => started++));
    await tapNext(tester);
    expect(find.text('건너뛰기'), findsOneWidget);
    expect(started, 0);
    await tapNext(tester);
    expect(find.text('건너뛰기'), findsNothing);
    expect(find.text('확인'), findsNothing);
    expect(find.text('규칙은 홈의 ? 버튼으로 다시 볼 수 있어요'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    expect(started, 1);
  });

  testWidgets('from home: no 건너뛰기, and back returns home', (tester) async {
    await openFromHome(tester);
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.text('건너뛰기'), findsNothing);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('from home: the last page\'s 확인 returns home', (tester) async {
    await openFromHome(tester);
    await tapNext(tester);
    await tapNext(tester);
    expect(find.text('시작하기'), findsNothing);
    expect(find.text('규칙은 홈의 ? 버튼으로 다시 볼 수 있어요'), findsNothing);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  for (final size in const [Size(412, 915), Size(360, 740)]) {
    testWidgets('every page fits ${size.width.toInt()}×${size.height.toInt()}: '
        'no overflow, the one button on screen', (tester) async {
      await show(tester, HelpScreen(onStart: () {}), size: size);
      for (var page = 0; page < HelpRules.pages.length; page++) {
        if (page > 0) await tapNext(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(AccentButton), findsOneWidget);
        expect(
          tester.getBottomLeft(find.byType(AccentButton)).dy,
          lessThanOrEqualTo(size.height),
        );
      }
    });
  }
}
