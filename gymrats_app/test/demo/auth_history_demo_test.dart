import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/auth_history_demo.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/login_screen.dart';

void main() {
  testWidgets('opens on login; the demo account reaches its history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(authHistoryDemoApp());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '아이디'), 'demo_user');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), 'password1');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('전체 기록 ›'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
  });

  test('the demo history is newest first', () {
    final matches = demoMatches(count: 5, now: DateTime(2026, 10, 15, 21));
    for (var i = 1; i < matches.length; i++) {
      expect(matches[i].playedAt!.isBefore(matches[i - 1].playedAt!), isTrue);
    }
  });
}
