import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/play_screen.dart';
import 'package:gymrats_app/screens/settings_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';
import 'package:gymrats_app/viewmodels/settings_viewmodel.dart';
import 'package:gymrats_app/widgets/lobby_menu_item.dart';
import 'package:gymrats_app/widgets/lobby_rep_bot.dart';

import 'package:provider/provider.dart';

import '../support/fakes.dart';

const _lastMatch = MatchRecord(
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: 24,
  opponentReps: 19,
);

/// Turns on the system's reduced motion, so RepBot holds still and
/// pumpAndSettle can settle.
void _stillRepBot(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

RepBotPainter _repBot(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(LobbyRepBot),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as RepBotPainter;

void main() {
  late FakeUserRepository repository;

  // A tap that misses its button must fail here, not pass with nothing
  // opened.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  setUp(() {
    repository = FakeUserRepository()
      ..profile = const UserProfile(
        name: '우현',
        bestReps: 32,
        lastMatch: _lastMatch,
      );
  });

  /// Opens HomeScreen on a phone-sized screen with the app's route observer
  /// and stub pages for the routes it opens. RepBot holds still unless
  /// [still] is false.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    bool still = true,
    Future<void> Function()? onLogOut,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (still) _stillRepBot(tester);
    final settings = SettingsViewModel();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      // The app's settings sit above the navigator, as in main.dart.
      ChangeNotifierProvider<SettingsViewModel>.value(
        value: settings,
        child: MaterialApp(
          theme: AppTheme.dark,
          navigatorObservers: [GymRatsApp.routeObserver],
          home: HomeScreen(
            createViewModel: () => HomeViewModel(repository: repository),
            onLogOut: onLogOut,
          ),
          routes: {
            GymRatsApp.helpRoute: (_) => const HelpScreen(),
            GymRatsApp.historyRoute: (_) =>
                const Scaffold(body: Text('history page')),
          },
        ),
      ),
    );
    // The first frame shows loading; this one shows what the load returned.
    await tester.pump();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('shows rules, the nickname, the title, RepBot and the menu', (
    tester,
  ) async {
    await open(tester);
    expect(find.byTooltip('게임 규칙'), findsOneWidget);
    expect(find.text('우현'), findsOneWidget);
    expect(find.text('GYMRATS'), findsOneWidget);
    expect(find.text('1V1'), findsOneWidget);
    expect(find.text('30초 실시간 운동 대결'), findsOneWidget);
    expect(find.byType(LobbyRepBot), findsOneWidget);
    expect(find.byType(LobbyMenuItem), findsNWidgets(3));
    for (final tag in ['01 / PLAY', '02 / ARCHIVE', '03 / SETTINGS']) {
      expect(find.text(tag), findsOneWidget);
    }
    // The old home's parts are gone.
    expect(find.textContaining('최근 경기'), findsNothing);
    expect(find.byTooltip('로그아웃'), findsNothing);
  });

  testWidgets('only 게임 시작 is the main entry', (tester) async {
    await open(tester);
    final items = tester
        .widgetList<LobbyMenuItem>(find.byType(LobbyMenuItem))
        .toList();
    expect(items.map((item) => item.title), ['게임 시작', '기록보관소', '환경설정']);
    expect(items.map((item) => item.main), [true, false, false]);
    expect(items.map((item) => item.last), [false, false, true]);
  });

  testWidgets('the profile mark is lime with an ink edge and an ink icon', (
    tester,
  ) async {
    await open(tester);
    final icon = tester.widget<Icon>(find.byIcon(Icons.person_outline_rounded));
    expect(icon.color, AppColors.ink);
    final mark = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.person_outline_rounded),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = mark.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.accent);
    expect((decoration.border! as Border).top.color, AppColors.ink);
  });

  testWidgets('RepBot stands between the title and the menu, top to bottom', (
    tester,
  ) async {
    await open(tester);
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final repBot = tester.getRect(find.byType(LobbyRepBot));
    expect(top(find.text('GYMRATS')), lessThan(repBot.top));
    expect(repBot.top, lessThan(top(find.text('게임 시작'))));
    expect(top(find.text('게임 시작')), lessThan(top(find.text('기록보관소'))));
    expect(top(find.text('기록보관소')), lessThan(top(find.text('환경설정'))));
    expect(repBot.size, LobbyRepBot.designSize);
  });

  testWidgets('RepBot keeps doing push-ups on home', (tester) async {
    await open(tester, still: false);
    final first = _repBot(tester).depth;
    await tester.pump(const Duration(milliseconds: 400));
    expect(_repBot(tester).depth, isNot(first));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('RepBot holds the top pose with reduced motion', (tester) async {
    await open(tester);
    expect(_repBot(tester).depth, 0);
    await tester.pumpAndSettle();
    expect(_repBot(tester).depth, 0);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    repository.gate = Completer();
    await open(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LobbyRepBot), findsNothing);
    repository.gate!.complete();
    await tester.pump();
    expect(find.byType(LobbyRepBot), findsOneWidget);
  });

  testWidgets('a failed load shows a retry button that loads again', (
    tester,
  ) async {
    repository.error = Exception('offline');
    await open(tester);
    expect(find.text('정보를 불러오지 못했어요'), findsOneWidget);
    repository.error = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump();
    expect(find.text('게임 시작'), findsOneWidget);
  });

  testWidgets('a network failure says why under the title', (tester) async {
    repository.error = const ApiException(ApiErrorKind.network);
    await open(tester);
    expect(
      find.text(const ApiException(ApiErrorKind.network).message),
      findsOneWidget,
    );
  });

  testWidgets("'?' opens the rules; back returns home (UAT-6)", (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.byTooltip('게임 규칙'));
    expect(find.byType(HelpScreen), findsOneWidget);
    await back(tester);
    expect(find.text('게임 시작'), findsOneWidget);
  });

  testWidgets('게임 시작 opens the play page on home\'s profile', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('게임 시작'));
    expect(find.byType(PlayScreen), findsOneWidget);
    // The play page reads home's latest battle: the bot from before levels.
    expect(find.text('푸쉬업 · AI 1v1 · 고수'), findsOneWidget);
  });

  testWidgets('기록보관소 opens the history page', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('기록보관소'));
    expect(find.text('history page'), findsOneWidget);
    await back(tester);
    expect(find.text('기록보관소'), findsOneWidget);
  });

  for (final (name, finder) in [
    ('환경설정', find.text('환경설정')),
    ('the profile chip', find.text('우현')),
  ]) {
    testWidgets('$name opens settings with the nickname', (tester) async {
      await open(tester);
      await tapAndSettle(tester, finder);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text('우현'),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('logout moved to settings: it asks, then logs out', (
    tester,
  ) async {
    var loggedOut = 0;
    await open(tester, onLogOut: () async => loggedOut++);
    await tapAndSettle(tester, find.text('환경설정'));
    await tapAndSettle(tester, find.text('로그아웃'));
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    expect(loggedOut, 0);
    await tapAndSettle(tester, find.text('로그아웃').last);
    expect(loggedOut, 1);
  });

  testWidgets('settings has no logout without a logout action', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('환경설정'));
    expect(find.text('로그아웃'), findsNothing);
  });

  group('coming back to home loads it again', () {
    for (final (name, entry) in [
      ('the play page', '게임 시작'),
      ('the history page', '기록보관소'),
      ('settings', '환경설정'),
    ]) {
      testWidgets('after $name', (tester) async {
        await open(tester);
        expect(repository.fetchCount, 1);
        await tapAndSettle(tester, find.text(entry));
        expect(repository.fetchCount, 1);
        await back(tester);
        expect(repository.fetchCount, 2);
      });
    }

    testWidgets('and the play page shows the battle saved meanwhile', (
      tester,
    ) async {
      await open(tester);
      repository.profile = const UserProfile(
        name: '우현',
        lastMatch: MatchRecord(
          exercise: ExerciseType.squat,
          opponentName: '민지',
          myReps: 10,
          opponentReps: 9,
        ),
      );
      await tapAndSettle(tester, find.text('기록보관소'));
      await back(tester);
      await tapAndSettle(tester, find.text('게임 시작'));
      expect(find.text('스쿼트 · 온라인 1v1'), findsOneWidget);
    });
  });

  testWidgets('battles not saved yet show an amber chip with ink text', (
    tester,
  ) async {
    repository.profile = const UserProfile(
      name: '우현',
      lastMatch: _lastMatch,
      unsentMatches: 2,
    );
    await open(tester);
    final note = find.text('저장하지 못한 경기 2개 · 연결되면 다시 저장해요');
    expect(note, findsOneWidget);
    expect(tester.widget<Text>(note).style!.color, AppColors.ink);
    final chip = tester.widget<DecoratedBox>(
      find.ancestor(of: note, matching: find.byType(DecoratedBox)).first,
    );
    expect(chip.decoration, AppHighlight.chip(AppColors.warning));
  });

  testWidgets('no note when every battle is saved', (tester) async {
    await open(tester);
    expect(find.textContaining('저장하지 못한 경기'), findsNothing);
  });

  testWidgets('the profile chip ends at the right margin, as designed', (
    tester,
  ) async {
    await open(tester, size: const Size(360, 780));
    final chip = find
        .ancestor(of: find.text('우현'), matching: find.byType(Material))
        .first;
    expect(tester.getRect(chip).right, 360 - AppSpacing.s20);
  });

  testWidgets('a 12-letter nickname shows whole at 360 wide', (tester) async {
    repository.profile = const UserProfile(name: '아주아주아주긴닉네임열둘');
    await open(tester, size: const Size(360, 780));
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('아주아주아주긴닉네임열둘'))
          .didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('a sound switch keeps its value when 환경설정 opens again', (
    tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, find.text('환경설정'));
    await tester.tap(find.text('효과음'));
    await tester.pump();
    await back(tester);
    await tapAndSettle(tester, find.text('환경설정'));
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
  });

  testWidgets('a long nickname ends in an ellipsis beside the rules', (
    tester,
  ) async {
    repository.profile = const UserProfile(name: '아주아주아주긴닉네임열둘');
    await open(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    final name = tester.widget<Text>(find.text('아주아주아주긴닉네임열둘'));
    expect(name.overflow, TextOverflow.ellipsis);
  });

  for (final (label, size, scale) in [
    ('the design phone', const Size(360, 780), 1.0),
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
        find.text('환경설정'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tapAndSettle(tester, find.text('환경설정'));
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  }

  testWidgets('every button is big enough and has a name', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
