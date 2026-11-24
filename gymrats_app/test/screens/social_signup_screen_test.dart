import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/social_signup_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/social_signup_viewmodel.dart';
import 'package:gymrats_app/widgets/auth_cast.dart';
import 'package:gymrats_app/widgets/auth_form.dart';

import '../support/auth_fakes.dart';

/// Holds the account's creation until [gate] completes, when one is set.
class _HeldRepository extends ScriptedAuthRepository {
  Completer<void>? gate;

  @override
  Future<SocialSignIn> signInWith(
    SocialProvider provider,
    String token, {
    String? nickname,
  }) async {
    await gate?.future;
    return super.signInWith(provider, token, nickname: nickname);
  }
}

void main() {
  late _HeldRepository repository;
  late AuthViewModel auth;

  setUp(() async {
    repository = _HeldRepository();
    auth = AuthViewModel(repository: repository);
    await auth.restore();
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SocialSignupScreen(
          createViewModel: () => SocialSignupViewModel(
            auth: auth,
            request: (provider: SocialProvider.google, token: 'id-token'),
          ),
        ),
      ),
    );
  }

  Finder field() => find.descendant(
    of: find.byType(AuthInputField),
    matching: find.byType(TextField),
  );
  const help = '대결 화면에 보이는 이름, 12자 이하';

  testWidgets('back and 회원가입, the group photo, the nickname with its '
      'count and help, and the lime 시작하기 (SPEC 6)', (tester) async {
    await open(tester);
    expect(find.byTooltip('뒤로'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
    expect(find.byType(AuthCastStage), findsOneWidget);
    expect(
      tester.widget<AuthCastStage>(find.byType(AuthCastStage)).place,
      AuthCastPlace.signup,
    );
    expect(find.text('닉네임'), findsOneWidget);
    expect(field(), findsOneWidget);
    expect(find.text('0/12'), findsOneWidget);
    expect(find.text(help), findsOneWidget);
    expect(find.widgetWithText(AuthLimeButton, '시작하기'), findsOneWidget);
    // Only the design's words.
    expect(find.textContaining('계정으로 가입해요'), findsNothing);
    expect(find.text('가입하기'), findsNothing);
    final title = tester.getRect(find.text('회원가입'));
    final stage = tester.getRect(find.byType(AuthCastStage));
    final button = tester.getRect(find.byType(AuthLimeButton));
    expect(title.bottom, lessThanOrEqualTo(stage.top));
    expect(stage.bottom, lessThanOrEqualTo(tester.getRect(field()).top));
    expect(button.top, greaterThan(tester.getRect(find.text(help)).bottom));
  });

  testWidgets('back returns without creating anything', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SocialSignupScreen(
                  createViewModel: () => SocialSignupViewModel(
                    auth: auth,
                    request: (provider: SocialProvider.google, token: 't'),
                  ),
                ),
              ),
            ),
            child: const Text('login'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('login'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SocialSignupScreen), findsNothing);
    expect(repository.socialSignIns, isEmpty);
  });

  testWidgets('the count follows the text and stops at 12; a 13th letter is '
      'not taken', (tester) async {
    await open(tester);
    await tester.enterText(field(), '우현');
    await tester.pump();
    expect(find.text('2/12'), findsOneWidget);
    await tester.enterText(field(), '가나다라마바사아자차카타파');
    await tester.pump();
    final text = tester.widget<TextField>(field()).controller!.text;
    expect(text, '가나다라마바사아자차카타');
    expect(text.characters.length, 12);
    expect(find.text('12/12'), findsOneWidget);
  });

  testWidgets('the cut waits for a Korean letter being typed to finish', (
    tester,
  ) async {
    await open(tester);
    final formatter =
        tester.widget<TextField>(field()).inputFormatters!.single
            as LengthLimitingTextInputFormatter;
    expect(formatter.maxLength, 12);
    expect(
      formatter.maxLengthEnforcement,
      MaxLengthEnforcement.truncateAfterCompositionEnds,
    );
  });

  testWidgets('시작하기 creates the account with the nickname', (tester) async {
    await open(tester);
    await tester.enterText(field(), '우현');
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(repository.socialSignIns.single, (
      SocialProvider.google,
      'id-token',
      '우현',
    ));
    expect(auth.status, AuthStatus.signedIn);
  });

  testWidgets('an empty nickname: the error takes the help line\'s place, '
      'in ink with an amber mark', (tester) async {
    await open(tester);
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(
      find.widgetWithText(AuthFieldError, '닉네임을 입력해 주세요.'),
      findsOneWidget,
    );
    expect(find.text(help), findsNothing);
    expect(
      tester.widget<Text>(find.text('닉네임을 입력해 주세요.')).style!.color,
      AppColors.ink,
    );
    expect(repository.socialSignIns, isEmpty);
  });

  testWidgets('while it creates the account: pale lime, a spinner, '
      '"계정을 만드는 중…", and no second request', (tester) async {
    repository.gate = Completer<void>();
    await open(tester);
    await tester.enterText(field(), '우현');
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(find.text('계정을 만드는 중…'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AuthLimeButton),
        matching: find.byType(AuthSpinner),
      ),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byType(AuthLimeButton),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style!.backgroundColor!.resolve({WidgetState.disabled}),
      AuthColors.busyLime,
    );
    await tester.tap(find.text('계정을 만드는 중…'));
    repository.gate!.complete();
    await tester.pump();
    expect(repository.socialSignIns, hasLength(1));
  });

  testWidgets('a server failure shows the F1 box over the button', (
    tester,
  ) async {
    repository.socialError = const ApiException(ApiErrorKind.network);
    await open(tester);
    await tester.enterText(field(), '우현');
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(find.byType(AuthErrorBox), findsOneWidget);
    expect(
      tester.getRect(find.byType(AuthErrorBox)).bottom,
      lessThan(tester.getRect(find.byType(AuthLimeButton)).top),
    );
    expect(find.text(help), findsOneWidget);
  });

  testWidgets('an expired provider login says to go back and retry', (
    tester,
  ) async {
    repository.socialError = const SocialTokenRejectedException();
    await open(tester);
    await tester.enterText(field(), '우현');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Google 로그인이 만료됐어요.'), findsOneWidget);
    expect(find.text('뒤로 가서 다시 시도해 주세요.'), findsOneWidget);
    await tester.enterText(field(), '우현2');
    await tester.pump();
    expect(find.byType(AuthErrorBox), findsNothing);
  });

  group('small screens, large text and the keyboard (SPEC 6, 8)', () {
    for (final size in const [Size(360, 780), Size(320, 640)]) {
      testWidgets('${size.width.toInt()} x ${size.height.toInt()}, text 1.3: '
          'every state fits', (tester) async {
        repository.socialError = const ApiException(ApiErrorKind.network);
        await open(tester, size: size, textScale: 1.3);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('시작하기'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.enterText(field(), '우현');
        await tester.tap(find.text('시작하기'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final finder in [
          find.byTooltip('뒤로'),
          field(),
          find.byType(AuthErrorBox),
          find.byType(AuthLimeButton),
        ]) {
          final rect = tester.getRect(finder);
          expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder');
          expect(
            rect.bottom,
            lessThanOrEqualTo(size.height),
            reason: '$finder',
          );
        }
      });

      testWidgets('${size.width.toInt()} x ${size.height.toInt()}: with the '
          'keyboard up the field and the button stay above it', (tester) async {
        await open(tester, size: size);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final keyboardTop = size.height - 280;
        expect(tester.getRect(field()).bottom, lessThanOrEqualTo(keyboardTop));
        expect(
          tester.getRect(find.byType(AuthLimeButton)).bottom,
          lessThanOrEqualTo(keyboardTop),
        );
      });
    }
  });
}
