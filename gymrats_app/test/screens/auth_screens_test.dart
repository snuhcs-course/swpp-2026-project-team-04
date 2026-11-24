import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/screens/login_screen.dart';
import 'package:gymrats_app/screens/signup_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';
import 'package:gymrats_app/viewmodels/signup_viewmodel.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:provider/provider.dart';

import '../support/auth_fakes.dart';

void main() {
  late ScriptedAuthRepository repository;
  late AuthViewModel auth;

  setUp(() async {
    repository = ScriptedAuthRepository();
    auth = AuthViewModel(repository: repository);
    await auth.restore();
  });

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: screen,
          routes: {
            GymRatsApp.signupRoute: (_) => const Scaffold(body: Text('signup')),
          },
        ),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  group('LoginScreen', () {
    testWidgets('has the fields, one lime button, and a sign-up link', (
      tester,
    ) async {
      await open(tester, const LoginScreen());
      // The app is called GymMouse now (user, 2026-11-14).
      expect(find.text('GYMMOUSE'), findsOneWidget);
      expect(find.text('GYMRATS'), findsNothing);
      expect(find.text('로그인하고\n한 판 붙어볼까요?'), findsOneWidget);
      expect(field('아이디'), findsOneWidget);
      expect(field('비밀번호'), findsOneWidget);
      expect(find.byType(AccentButton), findsOneWidget);
      final password = tester.widget<TextField>(field('비밀번호'));
      expect(password.obscureText, isTrue);

      await tester.tap(find.text('처음이신가요? 회원가입'));
      await tester.pumpAndSettle();
      expect(find.text('signup'), findsOneWidget);
    });

    testWidgets('empty fields show their errors', (tester) async {
      await open(tester, const LoginScreen());
      await tester.tap(find.text('로그인'));
      await tester.pump();
      expect(find.text('아이디를 입력해 주세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
      expect(repository.logIns, isEmpty);
    });

    testWidgets('wrong credentials show the generic error in amber', (
      tester,
    ) async {
      repository.logInError = const InvalidCredentialsException();
      await open(tester, const LoginScreen());
      await tester.enterText(field('아이디'), 'woohyun');
      await tester.enterText(field('비밀번호'), 'wrongpass');
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
      final message = find.text(LoginViewModel.wrongCredentialsMessage);
      expect(message, findsOneWidget);
      expect(tester.widget<Text>(message).style!.color, AppColors.warning);
      expect(repository.logIns.single, ('woohyun', 'wrongpass'));
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('a network failure shows its message', (tester) async {
      repository.logInError = const ApiException(ApiErrorKind.network);
      await open(tester, const LoginScreen());
      await tester.enterText(field('아이디'), 'woohyun');
      await tester.enterText(field('비밀번호'), 'password1');
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
      expect(
        find.text(const ApiException(ApiErrorKind.network).message),
        findsOneWidget,
      );
    });

    testWidgets('shows progress while logging in, then signs in', (
      tester,
    ) async {
      final gate = repository.holdLogIn();
      await open(tester, const LoginScreen());
      await tester.enterText(field('아이디'), 'woohyun');
      await tester.enterText(field('비밀번호'), 'password1');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      expect(find.text('로그인하는 중…'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(auth.status, AuthStatus.signedIn);
    });
  });

  group('SignupScreen', () {
    testWidgets('has four fields, a back arrow, and one lime button', (
      tester,
    ) async {
      await open(tester, const SignupScreen());
      expect(find.text('회원가입'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      for (final label in ['닉네임', '아이디', '비밀번호', '비밀번호 확인']) {
        expect(field(label), findsOneWidget, reason: label);
      }
      expect(find.byType(AccentButton), findsOneWidget);
    });

    testWidgets('shows every field error', (tester) async {
      await open(tester, const SignupScreen());
      await tester.enterText(field('아이디'), 'AB');
      await tester.enterText(field('비밀번호'), 'short');
      await tester.enterText(field('비밀번호 확인'), 'other');
      await tester.ensureVisible(find.text('가입하기'));
      await tester.tap(find.text('가입하기'));
      await tester.pump();
      expect(find.text('닉네임을 입력해 주세요.'), findsOneWidget);
      expect(find.text('아이디는 영문 소문자, 숫자, _ 로 4~20자여야 해요.'), findsOneWidget);
      expect(find.text('비밀번호는 8자 이상이어야 해요.'), findsOneWidget);
      expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
      expect(repository.signUps, isEmpty);
    });

    testWidgets('a taken id shows under the id field', (tester) async {
      repository.signUpError = const LoginIdTakenException();
      await open(tester, const SignupScreen());
      await tester.enterText(field('닉네임'), '우현');
      await tester.enterText(field('아이디'), 'woohyun');
      await tester.enterText(field('비밀번호'), 'password1');
      await tester.enterText(field('비밀번호 확인'), 'password1');
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();
      expect(find.text(SignupViewModel.takenMessage), findsOneWidget);
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('valid fields sign up and log in', (tester) async {
      await open(tester, const SignupScreen());
      await tester.enterText(field('닉네임'), '우현');
      await tester.enterText(field('아이디'), 'woohyun');
      await tester.enterText(field('비밀번호'), 'password1');
      await tester.enterText(field('비밀번호 확인'), 'password1');
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();
      expect(repository.signUps.single, ('우현', 'woohyun', 'password1'));
      expect(auth.status, AuthStatus.signedIn);
    });
  });

  group('LoginScreen with Google (P7)', () {
    late FakeSocialSignIn google;

    setUp(() {
      google = FakeSocialSignIn(SocialProvider.google);
      // An existing provider account unless a test says otherwise.
      repository.socialIsNew = false;
    });

    LoginScreen screen() => LoginScreen(
      createViewModel: () => LoginViewModel(auth: auth, google: google),
    );

    testWidgets('no Google button without the service', (tester) async {
      await open(tester, const LoginScreen());
      expect(find.text('Google로 계속하기'), findsNothing);
      expect(find.textContaining('카카오'), findsNothing);
    });

    testWidgets('shows Google, still with one lime button', (tester) async {
      await open(tester, screen());
      expect(find.text('Google로 계속하기'), findsOneWidget);
      expect(find.textContaining('카카오'), findsNothing);
      expect(find.byType(AccentButton), findsOneWidget);
    });

    testWidgets('a new provider account opens the nickname step', (
      tester,
    ) async {
      repository.socialIsNew = true;
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Object? arguments;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.light,
            home: screen(),
            onGenerateRoute: (settings) {
              if (settings.name != GymRatsApp.socialSignupRoute) return null;
              arguments = settings.arguments;
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('nickname')),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Google로 계속하기'));
      await tester.pumpAndSettle();
      expect(find.text('nickname'), findsOneWidget);
      expect(arguments, (
        provider: SocialProvider.google,
        token: 'provider-token',
      ));
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('tapping it signs in with Google', (tester) async {
      await open(tester, screen());
      await tester.tap(find.text('Google로 계속하기'));
      await tester.pump();
      expect(google.calls, 1);
      expect(repository.socialSignIns.single.$1, SocialProvider.google);
      expect(auth.status, AuthStatus.signedIn);
    });

    testWidgets('while one runs, it says so and the others wait', (
      tester,
    ) async {
      final gate = google.gate = Completer<void>();
      await open(tester, screen());
      await tester.tap(find.text('Google로 계속하기'));
      await tester.pump();
      expect(find.text('Google로 로그인하는 중…'), findsOneWidget);
      final googleButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Google로 로그인하는 중…'),
      );
      expect(googleButton.onPressed, isNull);
      final signup = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '처음이신가요? 회원가입'),
      );
      expect(signup.onPressed, isNull);
      gate.complete();
      await tester.pump();
    });

    testWidgets('a failure shows its message and can be retried', (
      tester,
    ) async {
      google.error = const SocialSignInFailedException('x');
      await open(tester, screen());
      await tester.tap(find.text('Google로 계속하기'));
      await tester.pump();
      expect(
        find.text(LoginViewModel.socialFailedMessage(SocialProvider.google)),
        findsOneWidget,
      );
      google.error = null;
      await tester.tap(find.text('Google로 계속하기'));
      await tester.pump();
      expect(auth.status, AuthStatus.signedIn);
    });
  });
}
