import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/login_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';
import 'package:gymrats_app/widgets/auth_cast.dart';
import 'package:gymrats_app/widgets/auth_form.dart';
import 'package:provider/provider.dart';

import '../support/auth_fakes.dart';

void main() {
  late ScriptedAuthRepository repository;
  late AuthViewModel auth;
  late FakeSocialSignIn google;

  setUp(() async {
    repository = ScriptedAuthRepository()..socialIsNew = false;
    auth = AuthViewModel(repository: repository);
    await auth.restore();
    google = FakeSocialSignIn(SocialProvider.google);
  });

  Future<void> open(
    WidgetTester tester, {
    AuthViewModel? withAuth,
    bool withGoogle = true,
    Size size = const Size(412, 915),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final a = withAuth ?? auth;
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: a,
        child: MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: Text('${settings.name}')),
          ),
          home: LoginScreen(
            createViewModel: () =>
                LoginViewModel(auth: a, google: withGoogle ? google : null),
          ),
        ),
      ),
    );
  }

  Finder googleButton() => find.byType(AuthGoogleButton);
  OutlinedButton googleWidget(WidgetTester tester) => tester.widget(
    find.descendant(of: googleButton(), matching: find.byType(OutlinedButton)),
  );
  TextButton linkWidget(WidgetTester tester) =>
      tester.widget(find.widgetWithText(TextButton, '아이디로 로그인'));

  Future<AuthViewModel> expiredAuth() async {
    final memory = InMemoryAuthRepository();
    final expired = AuthViewModel(repository: memory);
    await memory.signUp(
      nickname: '우현',
      loginId: 'woohyun',
      password: 'password1',
    );
    await expired.restore();
    await memory.expireSession();
    await pumpEventQueue();
    return expired;
  }

  group('the first screen (SPEC 3, 9-1)', () {
    testWidgets('the logo and its line, the group photo, Google and the id '
        'link; no fields and no sign-up link', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      expect(find.text('GYMMOUSE'), findsOneWidget);
      expect(find.text('1V1'), findsOneWidget);
      expect(find.text('30초 실시간 운동 대결'), findsOneWidget);
      expect(find.byType(AuthCastStage), findsOneWidget);
      expect(find.bySemanticsLabel(AuthCast.standard.label), findsOneWidget);
      expect(find.text('Google로 시작하기'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.text('아이디로 로그인'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('처음이신가요? 회원가입'), findsNothing);
      expect(find.textContaining('카카오'), findsNothing);
      // The logo, then the photo, then the button, then the link.
      final logo = tester.getRect(find.text('GYMMOUSE'));
      final stage = tester.getRect(find.byType(AuthCastStage));
      final button = tester.getRect(googleButton());
      final link = tester.getRect(find.text('아이디로 로그인'));
      expect(logo.bottom, lessThanOrEqualTo(stage.top));
      expect(stage.bottom, lessThanOrEqualTo(button.top));
      expect(button.bottom, lessThan(link.top));
      semantics.dispose();
    });

    testWidgets('Google로 시작하기 signs in with Google', (tester) async {
      await open(tester);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      expect(google.calls, 1);
      expect(repository.socialSignIns.single.$1, SocialProvider.google);
      expect(auth.status, AuthStatus.signedIn);
    });

    testWidgets('without the Google service, only the id link', (tester) async {
      await open(tester, withGoogle: false);
      expect(googleButton(), findsNothing);
      expect(find.text('아이디로 로그인'), findsOneWidget);
    });

    testWidgets('buttons keep the app\'s tap size', (tester) async {
      await open(tester);
      expect(tester.getSize(googleButton()).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(find.widgetWithText(TextButton, '아이디로 로그인')).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('the states (SPEC 7, 9-2)', () {
    testWidgets('L1: a spinner in the Google button, its words, and the '
        'button and the link ignore taps', (tester) async {
      final gate = google.gate = Completer<void>();
      await open(tester);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      expect(find.text('Google로 로그인하는 중…'), findsOneWidget);
      expect(
        find.descendant(of: googleButton(), matching: find.byType(AuthSpinner)),
        findsOneWidget,
      );
      expect(find.text('G'), findsNothing);
      expect(googleWidget(tester).onPressed, isNull);
      expect(linkWidget(tester).onPressed, isNull);
      final words = tester.widget<Text>(find.text('Google로 로그인하는 중…'));
      expect(words.style!.color, AuthColors.busyText);
      await tester.tap(find.text('아이디로 로그인'));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      gate.complete();
      await tester.pump();
      expect(google.calls, 1);
    });

    testWidgets('C2: backing out shows the grey line, told to a screen '
        'reader; a new tap clears it', (tester) async {
      google.error = const SocialSignInCancelledException();
      await open(tester);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      expect(find.text('로그인을 취소했어요'), findsOneWidget);
      expect(find.byType(AuthErrorBox), findsNothing);
      expect(
        tester.getRect(find.byType(AuthNotice)).bottom,
        lessThan(tester.getRect(googleButton()).top),
      );
      final live = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('로그인을 취소했어요'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(live.properties.liveRegion, isTrue);
      expect(find.text('Google로 시작하기'), findsOneWidget);
      google
        ..error = null
        ..gate = Completer<void>();
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      expect(find.text('로그인을 취소했어요'), findsNothing);
      google.gate!.complete();
      await tester.pump();
    });

    testWidgets('C2: opening the id sheet clears it', (tester) async {
      google.error = const SocialSignInCancelledException();
      await open(tester);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      await tester.tap(find.text('아이디로 로그인'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('로그인을 취소했어요'), findsNothing);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('로그인을 취소했어요'), findsNothing);
    });

    testWidgets('F1: the box over the button, its first sentence bold and '
        'the rest grey, and "Google로 다시 시도"; a new tap clears it', (
      tester,
    ) async {
      google.error = const SocialSignInFailedException('x');
      await open(tester);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      expect(find.byType(AuthErrorBox), findsOneWidget);
      final title = tester.widget<Text>(find.text('Google 로그인에 실패했어요.'));
      final rest = tester.widget<Text>(find.text('다시 시도해 주세요.'));
      expect(title.style!.fontWeight, FontWeight.w700);
      expect(title.style!.color, AppColors.ink);
      expect(rest.style!.color, AppColors.textSecondary);
      expect(rest.style!.fontSize, lessThan(title.style!.fontSize!));
      expect(find.text('Google로 다시 시도'), findsOneWidget);
      expect(
        tester.getRect(find.byType(AuthErrorBox)).bottom,
        lessThan(tester.getRect(googleButton()).top),
      );
      google
        ..error = null
        ..gate = Completer<void>();
      await tester.tap(find.text('Google로 다시 시도'));
      await tester.pump();
      expect(find.byType(AuthErrorBox), findsNothing);
      expect(find.text('Google로 로그인하는 중…'), findsOneWidget);
      google.gate!.complete();
      await tester.pump();
      expect(auth.status, AuthStatus.signedIn);
    });

    testWidgets('F1 tells each failure in its own words', (tester) async {
      repository.socialError = const SocialLoginUnavailableException();
      await open(tester);
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      expect(find.text('지금은 Google 로그인을 쓸 수 없어요.'), findsOneWidget);
      expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
      repository.socialError = const ApiException(ApiErrorKind.network);
      await tester.tap(find.text('Google로 다시 시도'));
      await tester.pump();
      final (first, _) = splitFirstSentence(
        const ApiException(ApiErrorKind.network).message,
      );
      expect(find.text(first), findsOneWidget);
    });

    testWidgets('an expired session shows in the box, with the button still '
        '"Google로 시작하기"; a tap clears it', (tester) async {
      final expired = await tester.runAsync(expiredAuth);
      await open(tester, withAuth: expired);
      expect(find.byType(AuthErrorBox), findsOneWidget);
      expect(find.text('로그인이 만료됐어요.'), findsOneWidget);
      expect(find.text('다시 로그인해 주세요.'), findsOneWidget);
      expect(find.text('Google로 시작하기'), findsOneWidget);
      expect(find.text('Google로 다시 시도'), findsNothing);
      google.gate = Completer<void>();
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      expect(find.byType(AuthErrorBox), findsNothing);
      google.gate!.complete();
      await tester.pump();
    });
  });

  group('small screens and large text (SPEC 8, 9-6)', () {
    /// Checks [finder] lies on the screen whole.
    void onScreen(WidgetTester tester, Finder finder, Size size) {
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder');
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
      expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$finder');
      expect(rect.right, lessThanOrEqualTo(size.width), reason: '$finder');
    }

    /// The lowest row's feet: a note may cover the podium, not them.
    double feetOf(WidgetTester tester) {
      final stage = tester.getRect(find.byType(AuthCastStage));
      const place = AuthCastPlace.login;
      final scale = stage.height / place.height;
      return stage.bottom - (place.bottom - place.feet) * scale;
    }

    for (final size in const [Size(360, 780), Size(320, 640)]) {
      testWidgets('${size.width.toInt()} x ${size.height.toInt()}, text 1.3: '
          'every state fits', (tester) async {
        google.gate = Completer<void>();
        await open(tester, size: size, textScale: 1.3);
        expect(tester.takeException(), isNull);
        onScreen(tester, googleButton(), size);
        onScreen(tester, find.text('아이디로 로그인'), size);
        expect(tester.getSize(find.text('GYMMOUSE')).height, greaterThan(0));

        await tester.tap(find.text('Google로 시작하기'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        onScreen(tester, googleButton(), size);
        google.error = const SocialSignInCancelledException();
        google.gate!.complete();
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        onScreen(tester, find.byType(AuthNotice), size);
        expect(
          tester.getRect(find.byType(AuthNotice)).top,
          greaterThanOrEqualTo(feetOf(tester) - 0.5),
        );

        google
          ..gate = null
          ..error = const SocialSignInFailedException('x');
        await tester.tap(find.text('Google로 시작하기'));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        onScreen(tester, find.byType(AuthErrorBox), size);
        onScreen(tester, googleButton(), size);
        expect(
          tester.getRect(find.byType(AuthErrorBox)).top,
          greaterThanOrEqualTo(feetOf(tester) - 0.5),
        );
      });

      testWidgets('${size.width.toInt()} x ${size.height.toInt()}, text 1.3: '
          'the sheet with its errors fits', (tester) async {
        await open(tester, size: size, textScale: 1.3);
        await tester.tap(find.text('아이디로 로그인'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('로그인'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('처음이신가요? 회원가입'));
        await tester.pump();
        onScreen(tester, find.text('처음이신가요? 회원가입'), size);
        await tester.ensureVisible(find.byType(AuthLimeButton));
        await tester.pump();
        onScreen(tester, find.byType(AuthLimeButton), size);
        expect(find.byType(AuthFieldError), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('at the design\'s size a note covers the lowest step, and '
        'the photo keeps its size', (tester) async {
      google.error = const SocialSignInFailedException('x');
      await open(tester, size: const Size(360, 780));
      final before = tester.getRect(find.byType(AuthCastStage));
      await tester.tap(find.text('Google로 시작하기'));
      await tester.pump();
      expect(tester.getRect(find.byType(AuthCastStage)), before);
      // The box reaches over the photo's band (onto the podium's step).
      expect(
        tester.getRect(find.byType(AuthErrorBox)).top,
        lessThan(before.bottom),
      );
    });
  });
}
