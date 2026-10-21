import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/login_screen.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/services/auth/token_store.dart';
import 'package:gymrats_app/services/user/in_memory_user_repository.dart';

import 'support/fakes.dart';

/// The whole app from start to home and back, on in-memory repositories.
void main() {
  Future<void> start(WidgetTester tester, InMemoryAuthRepository auth) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(auth: auth, users: InMemoryUserRepository()),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('without a saved session the app opens on login', (tester) async {
    await start(tester, InMemoryAuthRepository());
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('a saved session opens home without logging in', (tester) async {
    await start(tester, signedInAuth());
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
  });

  testWidgets('sign up from login lands on home', (tester) async {
    await start(tester, InMemoryAuthRepository());
    await tester.tap(find.text('처음이신가요? 회원가입'));
    await tester.pumpAndSettle();
    await tester.enterText(field('닉네임'), '우현');
    await tester.enterText(field('아이디'), 'woohyun');
    await tester.enterText(field('비밀번호'), 'password1');
    await tester.enterText(field('비밀번호 확인'), 'password1');
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    // The sign-up screen closed: back has nothing to return to.
    expect(find.byTooltip('뒤로'), findsNothing);
  });

  testWidgets('wrong password stays on login', (tester) async {
    final auth = InMemoryAuthRepository()
      ..addAccount(loginId: 'woohyun', nickname: '우현', password: 'password1');
    await start(tester, auth);
    await tester.enterText(field('아이디'), 'woohyun');
    await tester.enterText(field('비밀번호'), 'password2');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('아이디 또는 비밀번호가 맞지 않아요.'), findsOneWidget);
  });

  testWidgets('logout asks first, then shows login; a restart stays there', (
    tester,
  ) async {
    final store = MemoryTokenStore();
    final auth = InMemoryAuthRepository(store: store)
      ..addAccount(loginId: 'woohyun', nickname: '우현', password: 'password1');
    await auth.logIn(loginId: 'woohyun', password: 'password1');
    await start(tester, auth);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(store.session, isNull);

    // Restart: a new app on the same device storage.
    await tester.pumpWidget(const SizedBox());
    await start(tester, InMemoryAuthRepository(store: store));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('an expired session closes every screen and shows login', (
    tester,
  ) async {
    final auth = signedInAuth();
    await start(tester, auth);
    await tester.tap(find.text('전체 기록 ›'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);

    await auth.expireSession();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
  });

  // Updated for the 홈 | 기록 tabs: "전체 기록" switches to the 기록 tab
  // (task: match history with feedback); a battle card opens its feedback.
  testWidgets('"전체 기록" switches to the 기록 tab', (tester) async {
    await start(tester, signedInAuth());
    await tester.tap(find.text('전체 기록 ›'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('경기 기록'), findsOneWidget);
    expect(find.byTooltip('뒤로'), findsNothing);
  });
}
