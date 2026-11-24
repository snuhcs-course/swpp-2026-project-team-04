import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/social_signup_screen.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/social_signup_viewmodel.dart';
import 'package:gymrats_app/widgets/accent_button.dart';

import '../support/auth_fakes.dart';

void main() {
  late ScriptedAuthRepository repository;
  late AuthViewModel auth;

  setUp(() async {
    repository = ScriptedAuthRepository();
    auth = AuthViewModel(repository: repository);
    await auth.restore();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  Finder field() => find.widgetWithText(TextField, '닉네임');

  testWidgets('asks for the nickname, with one lime 가입하기', (tester) async {
    await open(tester);
    expect(find.text('닉네임을\n정해 주세요'), findsOneWidget);
    expect(find.text('Google 계정으로 가입해요.'), findsOneWidget);
    expect(field(), findsOneWidget);
    expect(find.text('대결 화면에 보이는 이름, 12자 이하'), findsOneWidget);
    expect(find.byType(AccentButton), findsOneWidget);
    expect(find.byTooltip('뒤로'), findsOneWidget);
  });

  testWidgets('가입하기 creates the account with the nickname', (tester) async {
    await open(tester);
    await tester.enterText(field(), '우현');
    await tester.tap(find.text('가입하기'));
    await tester.pump();
    expect(repository.socialSignIns.single, (
      SocialProvider.google,
      'id-token',
      '우현',
    ));
    expect(auth.status, AuthStatus.signedIn);
  });

  testWidgets('an empty nickname shows its error', (tester) async {
    await open(tester);
    await tester.tap(find.text('가입하기'));
    await tester.pump();
    expect(find.text('닉네임을 입력해 주세요.'), findsOneWidget);
    expect(repository.socialSignIns, isEmpty);
  });

  testWidgets('an expired provider login says to go back and retry', (
    tester,
  ) async {
    repository.socialError = const SocialTokenRejectedException();
    await open(tester);
    await tester.enterText(field(), '우현');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('뒤로 가서 다시 시도해 주세요'), findsOneWidget);
    await tester.enterText(field(), '우현2');
    await tester.pump();
    expect(find.textContaining('뒤로 가서 다시 시도해 주세요'), findsNothing);
  });
}
