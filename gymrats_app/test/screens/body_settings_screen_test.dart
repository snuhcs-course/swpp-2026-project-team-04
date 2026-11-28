import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/body_settings_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/body_settings_viewmodel.dart';

import '../support/auth_fakes.dart';
import '../support/fakes.dart';

void main() {
  late FakeUserRepository profiles;
  late ScriptedAuthRepository authRepository;
  late AuthViewModel auth;

  setUp(() {
    profiles = FakeUserRepository()
      ..profile = const UserProfile(name: '우현', heightCm: 175, weightKg: 72.5);
    authRepository = ScriptedAuthRepository();
    auth = AuthViewModel(repository: authRepository);
  });

  tearDown(() => auth.dispose());

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Text('settings')),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => BodySettingsScreen(
            createViewModel: () =>
                BodySettingsViewModel(profiles: profiles, auth: auth),
          ),
        ),
        initialRoute: '/body',
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  String fieldText(WidgetTester tester, String label) => tester
      .widget<TextField>(
        find.ancestor(of: find.text(label), matching: find.byType(TextField)),
      )
      .controller!
      .text;

  bool consented(WidgetTester tester) =>
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value!;

  testWidgets('the saved height and weight are filled in, the consent given '
      'with them ticked', (tester) async {
    await open(tester);
    expect(find.text('키·몸무게'), findsOneWidget);
    expect(fieldText(tester, '키 (cm)'), '175');
    expect(fieldText(tester, '몸무게 (kg)'), '72.5');
    expect(consented(tester), isTrue);
  });

  testWidgets('a user who gave none starts empty and unticked', (tester) async {
    profiles.profile = const UserProfile(name: '우현');
    await open(tester);
    expect(fieldText(tester, '키 (cm)'), isEmpty);
    expect(consented(tester), isFalse);
  });

  testWidgets('while the values load a spinner, no fields', (tester) async {
    profiles.gate = Completer<void>();
    await open(tester, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    profiles.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('저장 sends the new values and says so', (tester) async {
    await open(tester);
    await tester.enterText(
      find.ancestor(
        of: find.text('몸무게 (kg)'),
        matching: find.byType(TextField),
      ),
      '70',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(authRepository.bodyInfos, [(175.0, 70.0)]);
    expect(find.text('키·몸무게를 저장했어요'), findsOneWidget);
  });

  testWidgets('without consent: the error, nothing sent', (tester) async {
    profiles.profile = const UserProfile(name: '우현');
    await open(tester);
    await tester.enterText(
      find.ancestor(of: find.text('키 (cm)'), matching: find.byType(TextField)),
      '175',
    );
    await tester.enterText(
      find.ancestor(
        of: find.text('몸무게 (kg)'),
        matching: find.byType(TextField),
      ),
      '70',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(authRepository.bodyInfos, isEmpty);
    expect(find.textContaining('동의'), findsWidgets);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(consented(tester), isTrue);
  });

  testWidgets('a failed save shows its message', (tester) async {
    authRepository.bodyInfoError = Exception('boom');
    await open(tester);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('키·몸무게를 저장했어요'), findsNothing);
    expect(find.textContaining('문제가 생겼어요'), findsOneWidget);
  });

  testWidgets('back returns to settings', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets('fits a 360 x 640 phone', (tester) async {
    await open(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
  });
}
