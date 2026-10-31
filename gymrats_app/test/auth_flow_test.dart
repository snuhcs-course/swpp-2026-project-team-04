import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/login_screen.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/services/auth/token_store.dart';
import 'package:gymrats_app/services/user/in_memory_user_repository.dart';
import 'package:gymrats_app/services/user/rules_seen_store.dart';
import 'package:gymrats_app/widgets/help_rules.dart';

import 'support/fakes.dart';
import 'support/help_fakes.dart';

/// The whole app from start to home and back, on in-memory repositories.
void main() {
  /// [rules] stands for the phone's storage across restarts; a new one
  /// when null.
  Future<void> start(
    WidgetTester tester,
    InMemoryAuthRepository auth, {
    RulesSeenStore? rules,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GymRatsApp(
        authRepository: auth,
        userRepository: InMemoryUserRepository(),
        rulesSeenStore: rules,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  /// From login: creates the account [loginId] and submits.
  Future<void> signUp(WidgetTester tester, {String loginId = 'woohyun'}) async {
    await tester.tap(find.text('처음이신가요? 회원가입'));
    await tester.pumpAndSettle();
    await tester.enterText(field('닉네임'), '우현');
    await tester.enterText(field('아이디'), loginId);
    await tester.enterText(field('비밀번호'), 'password1');
    await tester.enterText(field('비밀번호 확인'), 'password1');
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
  }

  Future<void> logIn(WidgetTester tester, String loginId) async {
    await tester.enterText(field('아이디'), loginId);
    await tester.enterText(field('비밀번호'), 'password1');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
  }

  Future<void> logOut(WidgetTester tester) async {
    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
  }

  /// Reads the rules to the last page and taps 시작하기.
  Future<void> tapStart(WidgetTester tester) async {
    for (var page = 1; page < HelpRules.pages.length; page++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
  }

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

  // Updated for the rules screen (task: help screen): a new account now
  // reads the battle rules before home, so 시작하기 is one more tap.
  testWidgets('sign-up shows the rules before home; 시작하기 opens home', (
    tester,
  ) async {
    await start(tester, InMemoryAuthRepository());
    await signUp(tester);
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    // The sign-up screen closed: back has nothing to return to.
    expect(find.byTooltip('뒤로'), findsNothing);

    await tapStart(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(HelpScreen), findsNothing);
  });

  testWidgets('the rules show once: again after a restart before 시작하기, '
      'never after it', (tester) async {
    final tokens = MemoryTokenStore();
    final rules = MemoryRulesSeenStore();
    await start(tester, InMemoryAuthRepository(store: tokens), rules: rules);
    await signUp(tester);
    expect(find.byType(HelpScreen), findsOneWidget);

    // Closed before 시작하기: the rules come back.
    await tester.pumpWidget(const SizedBox());
    await start(tester, InMemoryAuthRepository(store: tokens), rules: rules);
    expect(find.byType(HelpScreen), findsOneWidget);
    await tapStart(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await start(tester, InMemoryAuthRepository(store: tokens), rules: rules);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(HelpScreen), findsNothing);
  });

  testWidgets('a returning user logs in straight to home', (tester) async {
    final auth = InMemoryAuthRepository()
      ..addAccount(loginId: 'woohyun', nickname: '우현', password: 'password1');
    await start(tester, auth);
    await logIn(tester, 'woohyun');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(HelpScreen), findsNothing);
  });

  testWidgets('each new account on the phone sees the rules once', (
    tester,
  ) async {
    await start(tester, InMemoryAuthRepository());
    await signUp(tester, loginId: 'woohyun');
    await tapStart(tester);
    await logOut(tester);

    await signUp(tester, loginId: 'songwoo');
    expect(find.byType(HelpScreen), findsOneWidget);
    await tapStart(tester);
    await logOut(tester);

    await logIn(tester, 'woohyun');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(HelpScreen), findsNothing);
  });

  testWidgets("'?' after sign-up saves nothing, and a restart stays on home", (
    tester,
  ) async {
    final tokens = MemoryTokenStore();
    final rules = ScriptedRulesSeenStore();
    await start(tester, InMemoryAuthRepository(store: tokens), rules: rules);
    await signUp(tester);
    await tapStart(tester);
    final writes = [...rules.writes];

    await tester.tap(find.byTooltip('게임 규칙'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(rules.writes, writes);

    await tester.pumpWidget(const SizedBox());
    await start(tester, InMemoryAuthRepository(store: tokens), rules: rules);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(HelpScreen), findsNothing);
  });

  testWidgets("'?' after a login saves nothing when 확인 returns home", (
    tester,
  ) async {
    final rules = ScriptedRulesSeenStore();
    final auth = InMemoryAuthRepository()
      ..addAccount(loginId: 'woohyun', nickname: '우현', password: 'password1');
    await start(tester, auth, rules: rules);
    await logIn(tester, 'woohyun');

    await tester.tap(find.byTooltip('게임 규칙'));
    await tester.pumpAndSettle();
    for (var page = 1; page < HelpRules.pages.length; page++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(rules.writes, isEmpty);
  });

  testWidgets('with slow phone storage, sign-up never shows home before '
      'the rules', (tester) async {
    final rules = ScriptedRulesSeenStore();
    await start(tester, InMemoryAuthRepository(), rules: rules);
    final read = rules.holdRead();
    final write = rules.holdWrite();
    await tester.tap(find.text('처음이신가요? 회원가입'));
    await tester.pumpAndSettle();
    await tester.enterText(field('닉네임'), '우현');
    await tester.enterText(field('아이디'), 'woohyun');
    await tester.enterText(field('비밀번호'), 'password1');
    await tester.enterText(field('비밀번호 확인'), 'password1');
    await tester.tap(find.text('가입하기'));
    // Every frame of the sign-up screen closing, with nothing saved yet.
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(HomeScreen), findsNothing);
    }
    expect(find.byType(HelpScreen), findsOneWidget);

    read.complete();
    write.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(rules.values, {1: false});
  });

  testWidgets('with slow phone storage, a login waits, then opens home', (
    tester,
  ) async {
    final rules = ScriptedRulesSeenStore();
    final auth = InMemoryAuthRepository()
      ..addAccount(loginId: 'woohyun', nickname: '우현', password: 'password1');
    await start(tester, auth, rules: rules);
    final read = rules.holdRead();
    await tester.enterText(field('아이디'), 'woohyun');
    await tester.enterText(field('비밀번호'), 'password1');
    await tester.tap(find.text('로그인'));
    // The spinner keeps turning, so pumpAndSettle would not return.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(HelpScreen), findsNothing);

    read.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(HelpScreen), findsNothing);
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
