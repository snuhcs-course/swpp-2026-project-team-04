import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/body_info_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
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
    await auth.signInWith(SocialProvider.google, 't', nickname: '우현');
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.light, home: const BodyInfoScreen()),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> fill(WidgetTester tester, {bool consent = true}) async {
    await tester.enterText(field('키 (cm)'), '175');
    await tester.enterText(field('몸무게 (kg)'), '70');
    if (consent) await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  testWidgets('has the fields, the consent box, 건너뛰기 and one lime 다음', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('키와 몸무게를\n알려주세요'), findsOneWidget);
    expect(find.text('더 정확한 피드백 정보를 드리는 데 도움이 됩니다.'), findsOneWidget);
    expect(field('키 (cm)'), findsOneWidget);
    expect(field('몸무게 (kg)'), findsOneWidget);
    expect(find.text('개인정보(키·몸무게) 수집·이용 동의'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(find.text('건너뛰기'), findsOneWidget);
    expect(find.byType(AccentButton), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    final height = tester.widget<TextField>(field('키 (cm)'));
    expect(
      height.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
  });

  testWidgets('다음 with values and consent saves and moves on', (tester) async {
    await open(tester);
    await fill(tester);
    await tester.tap(find.text('다음'));
    await tester.pump();
    expect(repository.bodyInfos.single, (175.0, 70.0));
    expect(auth.needsBodyInfo, isFalse);
  });

  testWidgets('다음 without consent asks for it and sends nothing', (
    tester,
  ) async {
    await open(tester);
    await fill(tester, consent: false);
    await tester.tap(find.text('다음'));
    await tester.pump();
    expect(find.textContaining('동의해 주세요'), findsOneWidget);
    expect(repository.bodyInfos, isEmpty);
    expect(auth.needsBodyInfo, isTrue);
  });

  testWidgets('empty fields show their errors', (tester) async {
    await open(tester);
    await tester.tap(find.text('다음'));
    await tester.pump();
    expect(find.text('키를 입력해 주세요.'), findsOneWidget);
    expect(find.text('몸무게를 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('건너뛰기 sends nothing and moves on', (tester) async {
    await open(tester);
    await fill(tester);
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    expect(repository.bodyInfos, isEmpty);
    expect(auth.needsBodyInfo, isFalse);
  });

  testWidgets('while saving, the buttons wait; a failure shows its message', (
    tester,
  ) async {
    final gate = repository.holdBodyInfo();
    repository.bodyInfoError = const ApiException(ApiErrorKind.network);
    await open(tester);
    await fill(tester);
    await tester.tap(find.text('다음'));
    await tester.pump();
    expect(find.text('저장하는 중…'), findsOneWidget);
    final skip = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '건너뛰기'),
    );
    expect(skip.onPressed, isNull);
    gate.complete();
    await tester.pump();
    expect(
      find.text(const ApiException(ApiErrorKind.network).message),
      findsOneWidget,
    );
    // Toggling the box clears the message again.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(
      find.text(const ApiException(ApiErrorKind.network).message),
      findsNothing,
    );
  });

  testWidgets('fits a small phone with the keyboard closed', (tester) async {
    await open(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(find.text('다음'), findsOneWidget);
  });
}
