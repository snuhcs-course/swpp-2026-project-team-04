import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/screens/login_screen.dart';
import 'package:gymrats_app/screens/signup_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';
import 'package:gymrats_app/viewmodels/signup_viewmodel.dart';
import 'package:gymrats_app/widgets/auth_form.dart';
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

  /// Lets a route move in or out; the group photo never settles.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('아이디로 로그인'));
    await settle(tester);
  }

  Finder input(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is AuthInputField && w.label == label),
    matching: find.byType(TextField),
  );

  group('LoginScreen id sheet (P8 SPEC 5)', () {
    testWidgets('the link opens it: title, close, both fields, the lime '
        'button, the sign-up link', (tester) async {
      await open(tester, const LoginScreen());
      expect(find.byType(TextField), findsNothing);
      await openSheet(tester);
      expect(find.text('아이디로 로그인'), findsNWidgets(2));
      expect(find.byTooltip('닫기'), findsOneWidget);
      expect(input('아이디'), findsOneWidget);
      expect(input('비밀번호'), findsOneWidget);
      expect(tester.widget<TextField>(input('비밀번호')).obscureText, isTrue);
      expect(find.widgetWithText(AuthLimeButton, '로그인'), findsOneWidget);
      expect(find.text('처음이신가요? 회원가입'), findsOneWidget);
    });

    testWidgets('X, back and a tap outside each close it, keeping the text', (
      tester,
    ) async {
      await open(tester, const LoginScreen());
      await openSheet(tester);
      await tester.enterText(input('아이디'), 'woohyun');
      await tester.tap(find.byTooltip('닫기'));
      await settle(tester);
      expect(find.byType(TextField), findsNothing);

      await openSheet(tester);
      expect(find.text('woohyun'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(TextField), findsNothing);

      await openSheet(tester);
      await tester.tapAt(const Offset(20, 20));
      await settle(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('아이디로 로그인'), findsOneWidget);
    });

    testWidgets('empty fields show their errors under them', (tester) async {
      await open(tester, const LoginScreen());
      await openSheet(tester);
      await tester.tap(find.text('로그인'));
      await tester.pump();
      expect(
        find.widgetWithText(AuthFieldError, '아이디를 입력해 주세요.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AuthFieldError, '비밀번호를 입력해 주세요.'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('아이디를 입력해 주세요.')).dy,
        greaterThan(tester.getBottomLeft(input('아이디')).dy),
      );
      expect(repository.logIns, isEmpty);
    });

    testWidgets('a wrong id or password shows one line over the button, in '
        'ink with an amber mark', (tester) async {
      repository.logInError = const InvalidCredentialsException();
      await open(tester, const LoginScreen());
      await openSheet(tester);
      await tester.enterText(input('아이디'), 'woohyun');
      await tester.enterText(input('비밀번호'), 'wrongpass');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.pump();
      final line = find.widgetWithText(
        AuthFieldError,
        LoginViewModel.wrongCredentialsMessage,
      );
      expect(line, findsOneWidget);
      final words = tester.widget<Text>(
        find.text(LoginViewModel.wrongCredentialsMessage),
      );
      expect(words.style!.color, AppColors.ink);
      expect(
        tester.getBottomLeft(line).dy,
        lessThan(tester.getTopLeft(find.byType(AuthLimeButton)).dy),
      );
      expect(repository.logIns.single, ('woohyun', 'wrongpass'));
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('a network failure shows its message', (tester) async {
      repository.logInError = const ApiException(ApiErrorKind.network);
      await open(tester, const LoginScreen());
      await openSheet(tester);
      await tester.enterText(input('아이디'), 'woohyun');
      await tester.enterText(input('비밀번호'), 'password1');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text(const ApiException(ApiErrorKind.network).message),
        findsOneWidget,
      );
    });

    testWidgets('while it logs in, the button turns pale with a spinner and '
        '"로그인하는 중…"', (tester) async {
      final gate = repository.holdLogIn();
      await open(tester, const LoginScreen());
      await openSheet(tester);
      await tester.enterText(input('아이디'), 'woohyun');
      await tester.enterText(input('비밀번호'), 'password1');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      expect(find.text('로그인하는 중…'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AuthLimeButton),
          matching: find.byType(AuthSpinner),
        ),
        findsOneWidget,
      );
      final link = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '처음이신가요? 회원가입'),
      );
      expect(link.onPressed, isNull);
      gate.complete();
      await tester.pump();
      expect(auth.status, AuthStatus.signedIn);
    });

    testWidgets('closed while it logs in, a wrong password shows nowhere', (
      tester,
    ) async {
      repository.logInError = const InvalidCredentialsException();
      final gate = repository.holdLogIn();
      await open(tester, const LoginScreen());
      await openSheet(tester);
      await tester.enterText(input('아이디'), 'woohyun');
      await tester.enterText(input('비밀번호'), 'wrongpass');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.tap(find.byTooltip('닫기'));
      await settle(tester);
      expect(find.byType(TextField), findsNothing);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(repository.logIns.single, ('woohyun', 'wrongpass'));
      expect(find.byType(AuthErrorBox), findsNothing);
      expect(find.text(LoginViewModel.wrongCredentialsMessage), findsNothing);
      // The sheet opens clean again.
      await openSheet(tester);
      expect(find.byType(AuthFieldError), findsNothing);
    });

    testWidgets('the password manager is asked to save only after a login '
        'that worked, never when the sheet closes', (tester) async {
      List<bool> saves() => [
        for (final call in tester.testTextInput.log)
          if (call.method == 'TextInput.finishAutofillContext')
            call.arguments as bool,
      ];
      repository.logInError = const InvalidCredentialsException();
      await open(tester, const LoginScreen());
      await openSheet(tester);
      await tester.enterText(input('아이디'), 'woohyun');
      await tester.enterText(input('비밀번호'), 'wrongpass');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.pump();
      expect(find.text(LoginViewModel.wrongCredentialsMessage), findsOneWidget);
      tester.testTextInput.log.clear();
      await tester.tap(find.byTooltip('닫기'));
      await settle(tester);
      // Closing ends the autofill context without saving.
      expect(saves(), [false]);

      repository.logInError = null;
      await openSheet(tester);
      tester.testTextInput.log.clear();
      await tester.enterText(input('비밀번호'), 'password1');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.pump();
      expect(auth.status, AuthStatus.signedIn);
      expect(saves(), [true]);
    });

    testWidgets('the sign-up link opens the id sign-up screen', (tester) async {
      await open(tester, const LoginScreen());
      await openSheet(tester);
      await tester.tap(find.text('처음이신가요? 회원가입'));
      await settle(tester);
      expect(find.text('signup'), findsOneWidget);
    });

    testWidgets('a login closes the sheet with the screen, as the app does', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      // GymRatsApp closes everything over its first screen on a login.
      void onAuth() => navigator.currentState?.popUntil((r) => r.isFirst);
      auth.addListener(onAuth);
      addTearDown(() => auth.removeListener(onAuth));
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: auth,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: AppTheme.light,
            home: const LoginScreen(),
          ),
        ),
      );
      await openSheet(tester);
      await tester.enterText(input('아이디'), 'woohyun');
      await tester.enterText(input('비밀번호'), 'password1');
      await tester.tap(find.text('로그인'));
      await settle(tester);
      expect(auth.status, AuthStatus.signedIn);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('with the keyboard up, the fields and the button stay above '
        'it', (tester) async {
      await open(tester, const LoginScreen());
      tester.view.viewInsets = const FakeViewPadding(bottom: 330);
      addTearDown(tester.view.resetViewInsets);
      await openSheet(tester);
      const keyboardTop = 915 - 330;
      for (final finder in [
        input('아이디'),
        input('비밀번호'),
        find.byType(AuthLimeButton),
      ]) {
        expect(tester.getRect(finder).bottom, lessThanOrEqualTo(keyboardTop));
      }
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

  group('LoginScreen with Google (P7, P8)', () {
    late FakeSocialSignIn google;

    setUp(() {
      google = FakeSocialSignIn(SocialProvider.google);
      // An existing provider account unless a test says otherwise.
      repository.socialIsNew = false;
    });

    LoginScreen screen([AuthViewModel? withAuth]) => LoginScreen(
      createViewModel: () =>
          LoginViewModel(auth: withAuth ?? auth, google: google),
    );

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
      await tester.tap(find.text('Google로 시작하기'));
      await settle(tester);
      expect(find.text('nickname'), findsOneWidget);
      expect(arguments, (
        provider: SocialProvider.google,
        token: 'provider-token',
      ));
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('(a) after a Google failure the sheet opens with no error', (
      tester,
    ) async {
      google.error = const SocialSignInFailedException('x');
      await open(tester, screen());
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      expect(find.byType(AuthErrorBox), findsOneWidget);
      await openSheet(tester);
      expect(find.byType(AuthFieldError), findsNothing);
      expect(
        find.textContaining(
          LoginViewModel.socialFailedMessage(SocialProvider.google),
        ),
        findsNothing,
      );
      expect(find.byType(AuthErrorBox), findsNothing);
    });

    testWidgets('(b) a wrong password in the sheet, then closing it, leaves '
        'nothing on the first screen', (tester) async {
      repository.logInError = const InvalidCredentialsException();
      await open(tester, screen());
      await openSheet(tester);
      await tester.enterText(input('아이디'), 'woohyun');
      await tester.enterText(input('비밀번호'), 'wrongpass');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.pump();
      expect(find.text(LoginViewModel.wrongCredentialsMessage), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await settle(tester);
      expect(find.byType(AuthErrorBox), findsNothing);
      expect(find.byType(AuthNotice), findsNothing);
      expect(find.text(LoginViewModel.wrongCredentialsMessage), findsNothing);
      expect(find.text('Google로 시작하기'), findsOneWidget);
    });

    testWidgets('(c) the expired-session box goes when the sheet opens and '
        'stays gone when it closes', (tester) async {
      final memory = InMemoryAuthRepository();
      final expired = AuthViewModel(repository: memory);
      await memory.signUp(
        nickname: '우현',
        loginId: 'woohyun',
        password: 'password1',
      );
      await expired.restore();
      await memory.expireSession();
      await tester.runAsync(pumpEventQueue);
      await open(tester, screen(expired));
      expect(find.byType(AuthErrorBox), findsOneWidget);
      expect(find.text('로그인이 만료됐어요.'), findsOneWidget);
      await openSheet(tester);
      expect(find.byType(AuthFieldError), findsNothing);
      await tester.tap(find.byTooltip('닫기'));
      await settle(tester);
      expect(find.byType(AuthErrorBox), findsNothing);
    });
  });
}
