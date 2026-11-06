import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/settings_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/settings_viewmodel.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:provider/provider.dart';

void main() {
  // A tap that misses its target must fail here, not pass with nothing done.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  late SettingsViewModel vm;
  late int loggedOut;

  /// Opens settings over a stub page, as home opens it, under the app's
  /// settings view model [vm].
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('below'));
    await tester.pumpAndSettle();
  }

  /// The app with the settings view model above its navigator, as main.dart
  /// has it, then settings opened.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    bool canLogOut = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    loggedOut = 0;
    vm = SettingsViewModel();
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsViewModel>.value(
        value: vm,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(
                      nickname: '우현',
                      onLogOut: canLogOut ? () async => loggedOut++ : null,
                    ),
                  ),
                ),
                child: const Text('below'),
              ),
            ),
          ),
          routes: {
            GymRatsApp.helpRoute: (_) => const HelpScreen(),
            GymRatsApp.profileRoute: (_) =>
                const Scaffold(body: Text('avatar page')),
          },
        ),
      ),
    );
    await openSettings(tester);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  bool switchOf(WidgetTester tester, String title) => tester
      .widget<Switch>(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(InkWell),
          ),
          matching: find.byType(Switch),
        ),
      )
      .value;

  testWidgets('shows the nickname, the rules, the sound switches and logout', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('03 / SETTINGS'), findsOneWidget);
    expect(find.text('환경설정'), findsOneWidget);
    for (final text in [
      '프로필',
      '닉네임',
      '우현',
      '아바타',
      '게임',
      '게임 규칙 다시 보기',
      '소리',
      '효과음',
      '음성 안내',
      '카운트다운 · 매칭 · 판정을 소리로',
      '로그아웃',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byType(Switch), findsNWidgets(2));
  });

  testWidgets('only what works in this step: no editing, no safety switch', (
    tester,
  ) async {
    await open(tester);
    // The nickname is shown only: changing it needs a server API.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('저장'), findsNothing);
    // The safety switch comes with the battle screen's safety notice.
    expect(find.text('매 경기 안전 안내'), findsNothing);
  });

  testWidgets('아바타 opens the avatar page until the characters come', (
    tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, find.text('아바타'));
    expect(find.text('avatar page'), findsOneWidget);
  });

  testWidgets('the switches show the view model, as designed at first', (
    tester,
  ) async {
    await open(tester);
    expect(switchOf(tester, '효과음'), isTrue);
    expect(switchOf(tester, '음성 안내'), isFalse);
  });

  testWidgets('tapping a switch or its row turns it, and only it', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(vm.state.soundEffectsOn, isFalse);
    expect(switchOf(tester, '효과음'), isFalse);
    expect(vm.state.voiceGuidanceOn, isFalse);

    await tester.tap(find.text('음성 안내'));
    await tester.pump();
    expect(vm.state.voiceGuidanceOn, isTrue);
    expect(switchOf(tester, '음성 안내'), isTrue);
    expect(vm.state.soundEffectsOn, isFalse);
  });

  testWidgets('a switch keeps its value when settings opens again', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('효과음'));
    await tester.tap(find.text('음성 안내'));
    await tester.pump();
    await tapAndSettle(tester, find.byTooltip('뒤로'));
    expect(find.byType(SettingsScreen), findsNothing);

    await openSettings(tester);
    expect(switchOf(tester, '효과음'), isFalse);
    expect(switchOf(tester, '음성 안내'), isTrue);
    expect(vm.state.soundEffectsOn, isFalse);
  });

  testWidgets('another screen sees the change while settings is open', (
    tester,
  ) async {
    await open(tester);
    final heard = <bool>[];
    vm.addListener(() => heard.add(vm.state.voiceGuidanceOn));
    await tester.tap(find.text('음성 안내'));
    await tester.pump();
    expect(heard, [true]);
  });

  testWidgets('게임 규칙 다시 보기 opens the rules', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('게임 규칙 다시 보기'));
    expect(find.byType(HelpScreen), findsOneWidget);
  });

  testWidgets('logout asks first; 계속하기 keeps the user in', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('로그아웃'));
    expect(find.byType(ExitDialog), findsOneWidget);
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    await tapAndSettle(tester, find.text('계속하기'));
    expect(find.byType(ExitDialog), findsNothing);
    expect(loggedOut, 0);
  });

  testWidgets('confirming logs out', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('로그아웃'));
    await tapAndSettle(
      tester,
      find.descendant(of: find.byType(ExitDialog), matching: find.text('로그아웃')),
    );
    expect(loggedOut, 1);
  });

  testWidgets('no logout without a logout action', (tester) async {
    await open(tester, canLogOut: false);
    expect(find.text('로그아웃'), findsNothing);
  });

  testWidgets('back returns to the page below', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.byTooltip('뒤로'));
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('below'), findsOneWidget);
  });

  testWidgets('a screen reader hears each sound row as one switch', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^효과음'))),
      matchesSemantics(
        label: '효과음',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  for (final (label, size, scale) in [
    ('a short phone', const Size(360, 640), 1.0),
    ('a large text size', const Size(360, 780), 2.0),
  ]) {
    testWidgets('fits $label without overflow, scrolling if it must', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.text('로그아웃'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(find.text('로그아웃').hitTestable(), findsOneWidget);
    });
  }
}
