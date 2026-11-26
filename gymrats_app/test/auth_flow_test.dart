import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/screens/body_info_screen.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/widgets/auth_form.dart';
import 'package:gymrats_app/screens/login_screen.dart';
import 'package:gymrats_app/screens/settings_screen.dart';
import 'package:gymrats_app/screens/social_signup_screen.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/services/auth/token_store.dart';
import 'package:gymrats_app/services/user/in_memory_user_repository.dart';
import 'package:gymrats_app/services/user/rules_seen_store.dart';
import 'package:gymrats_app/widgets/help_rules.dart';

import 'support/auth_fakes.dart';
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
    SocialSignInService? google,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Reduced motion: home's RepBot holds still, so pumpAndSettle returns.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      GymRatsApp(
        authRepository: auth,
        userRepository: InMemoryUserRepository(),
        rulesSeenStore: rules,
        googleSignIn: google,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A field by its name: the id sign-up screen's labeled ones, or (P8)
  /// the id sheet's and the nickname step's, named on [AuthInputField].
  Finder field(String label) {
    final named = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is AuthInputField && w.label == label,
      ),
      matching: find.byType(TextField),
    );
    return named.evaluate().isEmpty
        ? find.widgetWithText(TextField, label)
        : named;
  }

  /// P8: id login and the sign-up link are in the sheet "아이디로 로그인".
  Future<void> openIdSheet(WidgetTester tester) async {
    await tester.tap(find.text('아이디로 로그인'));
    await tester.pumpAndSettle();
  }

  /// From login: creates the account [loginId], submits, and skips the
  /// body info step that follows (P7).
  Future<void> signUp(WidgetTester tester, {String loginId = 'woohyun'}) async {
    await openIdSheet(tester);
    await tester.tap(find.text('처음이신가요? 회원가입'));
    await tester.pumpAndSettle();
    await tester.enterText(field('닉네임'), '우현');
    await tester.enterText(field('아이디'), loginId);
    await tester.enterText(field('비밀번호'), 'password1');
    await tester.enterText(field('비밀번호 확인'), 'password1');
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(find.byType(BodyInfoScreen), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
  }

  Future<void> logIn(WidgetTester tester, String loginId) async {
    await openIdSheet(tester);
    await tester.enterText(field('아이디'), loginId);
    await tester.enterText(field('비밀번호'), 'password1');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
  }

  /// Logout is in 환경설정 now; the dialog's 로그아웃 is the last one.
  Future<void> logOut(WidgetTester tester) async {
    await tester.tap(find.text('환경설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃').last);
    await tester.pumpAndSettle();
  }

  /// Reads the rules to the last page and taps 시작하기.
  Future<void> tapStart(WidgetTester tester) async {
    for (var page = 1; page < HelpRules.pages.length; page++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('완료'));
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
    // The lobby's profile chip, where the greeting was.
    expect(find.text('우현'), findsOneWidget);
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
    await tester.tap(find.text('완료'));
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
    await openIdSheet(tester);
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
    // The body info step first (P7), then still the rules, not home.
    expect(find.byType(BodyInfoScreen), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
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
    await openIdSheet(tester);
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
    await openIdSheet(tester);
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

    // Logout is in 환경설정 now.
    await tester.tap(find.text('환경설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃').last);
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
    await tester.tap(find.text('운동일지'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);

    await auth.expireSession();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HistoryScreen), findsNothing);
    // P8: the box shows the first sentence in bold, the rest under it.
    expect(find.text('로그인이 만료됐어요.'), findsOneWidget);
    expect(find.text('다시 로그인해 주세요.'), findsOneWidget);
  });

  // Updated for the game lobby (W1): the 홈 | 기록 tabs are gone, and the
  // lobby's 기록보관소 opens the history as a page with a back button.
  testWidgets('"운동일지" opens the history as a page', (tester) async {
    await start(tester, signedInAuth());
    await tester.tap(find.text('운동일지'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('운동일지'), findsOneWidget);
    expect(find.byTooltip('뒤로'), findsOneWidget);
  });

  group('Google (P7)', () {
    testWidgets('a new Google account gives height and weight, reads the '
        'rules, then gets home', (tester) async {
      final auth = InMemoryAuthRepository();
      final google = FakeSocialSignIn(SocialProvider.google, token: 'g-1');
      await start(tester, auth, google: google);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pumpAndSettle();
      // A new provider account picks its nickname first.
      expect(find.byType(SocialSignupScreen), findsOneWidget);
      await tester.enterText(field('닉네임'), '우현');
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      expect(find.byType(BodyInfoScreen), findsOneWidget);
      expect(find.text('더 정확한 피드백 정보를 드리는 데 도움이 됩니다.'), findsOneWidget);

      await tester.enterText(field('키 (cm)'), '175');
      await tester.enterText(field('몸무게 (kg)'), '70.5');
      await tester.tap(find.text('개인정보(키·몸무게) 수집·이용 동의'));
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(auth.bodyInfo.values.single, (heightCm: 175.0, weightKg: 70.5));
      expect(find.byType(HelpScreen), findsOneWidget);
      await tapStart(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the same Google account later logs in straight to home', (
      tester,
    ) async {
      final auth = InMemoryAuthRepository();
      final google = FakeSocialSignIn(SocialProvider.google, token: 'g-2');
      await start(tester, auth, google: google);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pumpAndSettle();
      await tester.enterText(field('닉네임'), '현우');
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(auth.bodyInfo, isEmpty);
      await tapStart(tester);
      await logOut(tester);

      await tester.tap(find.text('Google로 시작하기'));
      await tester.pumpAndSettle();
      expect(find.byType(BodyInfoScreen), findsNothing);
      expect(find.byType(HelpScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('backing out of the nickname step creates no account', (
      tester,
    ) async {
      final auth = InMemoryAuthRepository();
      final google = FakeSocialSignIn(SocialProvider.google, token: 'g-1');
      await start(tester, auth, google: google);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await expectLater(
        auth.signInWith(SocialProvider.google, 'g-1'),
        throwsA(isA<SocialSignUpRequiredException>()),
      );
    });

    testWidgets('backing out of Google stays on login without an error', (
      tester,
    ) async {
      final google = FakeSocialSignIn(
        SocialProvider.google,
        error: const SocialSignInCancelledException(),
      );
      await start(tester, InMemoryAuthRepository(), google: google);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.textContaining('실패'), findsNothing);
      expect(google.calls, 1);
    });

    testWidgets('a Google session is restored after a restart', (tester) async {
      final tokens = MemoryTokenStore();
      final google = FakeSocialSignIn(SocialProvider.google, token: 'g-1');
      await start(
        tester,
        InMemoryAuthRepository(store: tokens),
        google: google,
      );
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pumpAndSettle();
      await tester.enterText(field('닉네임'), '우현');
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      await tapStart(tester);

      await tester.pumpWidget(const SizedBox());
      await start(
        tester,
        InMemoryAuthRepository(store: tokens),
        google: google,
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(BodyInfoScreen), findsNothing);
      expect(google.calls, 1);
    });
  });
}
