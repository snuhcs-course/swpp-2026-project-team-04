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
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';
import 'package:gymrats_app/viewmodels/settings_viewmodel.dart';
import 'package:gymrats_app/widgets/lobby_menu_item.dart';
import 'package:gymrats_app/widgets/lobby_rep_bot.dart';

import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../widgets/battle_test_support.dart';

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

// An Android phone's status bar and three-button navigation bar.
const _systemBars = FakeViewPadding(top: 24, bottom: 48);

// The status bar and the gesture bar.
const _gestureBars = FakeViewPadding(top: 24, bottom: 24);

const _titles = ['게임 시작', '캐릭터', '기록보관소', '환경설정'];

final _least = LobbyRepBot.designSize * HomeScreen.repBotMinScale;
final _most = LobbyRepBot.designSize * HomeScreen.repBotMaxScale;

double _scrollRoom(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable))
    .position
    .maxScrollExtent;

Size _repBotSize(WidgetTester tester) =>
    tester.getSize(find.byType(LobbyRepBot));

Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(LobbyMenuItem));

/// RepBot's room: the box it is placed in.
Rect _slot(WidgetTester tester) => tester.getRect(
  find
      .ancestor(of: find.byType(LobbyRepBot), matching: find.byType(Align))
      .first,
);

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
  /// [still] is false. [bars] are the system bars' heights, [textScale] the
  /// system text size, and [tabBar] the height of a bar under home (none
  /// when 0).
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    FakeViewPadding bars = FakeViewPadding.zero,
    double textScale = 1,
    double tabBar = 0,
    bool still = true,
    Future<void> Function()? onLogOut,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = bars;
    tester.view.viewPadding = bars;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    if (still) _stillRepBot(tester);
    final settings = SettingsViewModel();
    addTearDown(settings.dispose);
    final characters = CharacterViewModel(store: MemoryCharacterStore());
    addTearDown(characters.dispose);
    final home = HomeScreen(
      createViewModel: () => HomeViewModel(repository: repository),
      onLogOut: onLogOut,
    );
    await tester.pumpWidget(
      // The app's settings and character sit above the navigator, as in
      // main.dart.
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsViewModel>.value(value: settings),
          ChangeNotifierProvider<CharacterViewModel>.value(value: characters),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          navigatorObservers: [GymRatsApp.routeObserver],
          home: tabBar == 0
              ? home
              : Scaffold(
                  body: home,
                  bottomNavigationBar: SizedBox(
                    key: const Key('tab bar'),
                    height: tabBar,
                  ),
                ),
          routes: {
            GymRatsApp.helpRoute: (_) => const HelpScreen(),
            GymRatsApp.characterRoute: (_) =>
                const Scaffold(body: Text('character page')),
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
    // The app is called GymMouse now (user, 2026-11-14).
    expect(find.text('GYMMOUSE'), findsOneWidget);
    expect(find.text('GYMRATS'), findsNothing);
    expect(find.text('1V1'), findsOneWidget);
    expect(find.text('30초 실시간 운동 대결'), findsOneWidget);
    expect(find.byType(LobbyRepBot), findsOneWidget);
    expect(find.byType(LobbyMenuItem), findsNWidgets(4));
    for (final tag in [
      '01 / PLAY',
      '02 / CHARACTER',
      '03 / ARCHIVE',
      '04 / SETTINGS',
    ]) {
      expect(find.text(tag), findsOneWidget);
    }
    // The old home's parts are gone.
    expect(find.textContaining('최근 경기'), findsNothing);
    expect(find.byTooltip('로그아웃'), findsNothing);
  });

  testWidgets('the menu: 게임 시작, 캐릭터, 기록보관소, 환경설정, all alike', (tester) async {
    await open(tester);
    final items = tester
        .widgetList<LobbyMenuItem>(find.byType(LobbyMenuItem))
        .toList();
    expect(items.map((item) => item.title), ['게임 시작', '캐릭터', '기록보관소', '환경설정']);
    expect(items.map((item) => item.tag), [
      '01 / PLAY',
      '02 / CHARACTER',
      '03 / ARCHIVE',
      '04 / SETTINGS',
    ]);
    // The same gray chevron on each; no lime or arrow chip (2026-11-08).
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
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
    expect(top(find.text('GYMMOUSE')), lessThan(repBot.top));
    expect(repBot.top, lessThan(top(find.text('게임 시작'))));
    expect(top(find.text('게임 시작')), lessThan(top(find.text('캐릭터'))));
    expect(top(find.text('캐릭터')), lessThan(top(find.text('기록보관소'))));
    expect(top(find.text('기록보관소')), lessThan(top(find.text('환경설정'))));
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

  testWidgets('캐릭터 opens 캐릭터 선택; back returns home', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('캐릭터'));
    expect(find.text('character page'), findsOneWidget);
    await back(tester);
    expect(find.text('캐릭터'), findsOneWidget);
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
      ('캐릭터 선택', '캐릭터'),
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
    // The 효과음 switch: the safety switch comes first on the page.
    final soundEffects = find.descendant(
      of: find.ancestor(of: find.text('효과음'), matching: find.byType(InkWell)),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(soundEffects).value, isFalse);
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

  group('fits the screen: RepBot takes the height left', () {
    testWidgets('a shorter screen shrinks RepBot, keeping its shape', (
      tester,
    ) async {
      await open(tester, size: const Size(360, 700), bars: _systemBars);
      final size = _repBotSize(tester);
      expect(size.height, lessThan(LobbyRepBot.designSize.height));
      expect(size.height, greaterThan(_least.height));
      expect(
        size.aspectRatio,
        closeTo(LobbyRepBot.designSize.aspectRatio, 0.01),
      );
      expect(_scrollRoom(tester), 0);
    });

    testWidgets('a taller screen grows RepBot, up to 1.2 times its design', (
      tester,
    ) async {
      await open(tester, size: const Size(412, 960), bars: _systemBars);
      expect(
        _repBotSize(tester).height,
        greaterThan(LobbyRepBot.designSize.height),
      );
      await open(tester, size: const Size(800, 1280));
      expect(_repBotSize(tester).width, closeTo(_most.width, 0.01));
      expect(_repBotSize(tester).height, closeTo(_most.height, 0.01));
    });

    testWidgets('only RepBot changes: the chip and the menu rows stay', (
      tester,
    ) async {
      final chip = find
          .ancestor(of: find.text('우현'), matching: find.byType(Material))
          .first;
      List<Size> parts() => [
        tester.getSize(chip),
        for (final title in _titles) tester.getSize(_row(title)),
      ];
      await open(tester, size: const Size(360, 640));
      final short = parts();
      final shortRepBot = _repBotSize(tester);
      await open(tester, size: const Size(360, 1000));
      expect(parts(), short);
      expect(short.first.height, 48);
      expect(_repBotSize(tester).height, greaterThan(shortRepBot.height));
    });

    testWidgets('a tab bar under home is left out of the room', (tester) async {
      await open(tester, size: const Size(412, 800), bars: _systemBars);
      final withoutBar = _repBotSize(tester);
      await open(
        tester,
        size: const Size(412, 800),
        bars: _systemBars,
        tabBar: 80,
      );
      expect(tester.takeException(), isNull);
      expect(_scrollRoom(tester), 0);
      final barTop = tester.getTopLeft(find.byKey(const Key('tab bar'))).dy;
      expect(tester.getRect(_row('환경설정')).bottom, lessThanOrEqualTo(barTop));
      expect(_repBotSize(tester).height, lessThan(withoutBar.height));
    });

    testWidgets('320×568 at 2× text scrolls, with RepBot at its least, and '
        'every menu row can be scrolled to and tapped', (tester) async {
      await open(
        tester,
        size: const Size(320, 568),
        bars: _systemBars,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(_scrollRoom(tester), greaterThan(0));
      expect(_repBotSize(tester).height, closeTo(_least.height, 0.01));
      for (final (title, opened) in [
        ('게임 시작', find.byType(PlayScreen)),
        ('캐릭터', find.text('character page')),
        ('기록보관소', find.text('history page')),
        ('환경설정', find.byType(SettingsScreen)),
      ]) {
        await tester.dragUntilVisible(
          find.text(title),
          find.byType(SingleChildScrollView),
          const Offset(0, -100),
        );
        await tapAndSettle(tester, find.text(title));
        expect(opened, findsOneWidget, reason: title);
        await back(tester);
      }
    });

    // Scrolling only ever starts once RepBot is as small as it goes.
    for (final size in const [
      Size(320, 568),
      Size(320, 640),
      Size(360, 640),
      Size(360, 780),
      Size(393, 852),
      Size(412, 915),
    ]) {
      for (final textScale in const [1.0, 1.3, 2.0]) {
        final label =
            '${size.width.toInt()}×${size.height.toInt()} at $textScale× text';
        testWidgets('$label: no overflow, no scroll while RepBot can shrink', (
          tester,
        ) async {
          await open(
            tester,
            size: size,
            bars: _systemBars,
            textScale: textScale,
          );
          expect(tester.takeException(), isNull);
          final height = _repBotSize(tester).height;
          expect(height, inInclusiveRange(_least.height - 0.01, _most.height));
          if (_scrollRoom(tester) > 0) {
            expect(height, closeTo(_least.height, 0.01));
          }
          await tester.dragUntilVisible(
            find.text('환경설정'),
            find.byType(SingleChildScrollView),
            const Offset(0, -200),
          );
          await tapAndSettle(tester, find.text('환경설정'));
          expect(find.byType(SettingsScreen), findsOneWidget);
        });
      }
    }
  });

  testWidgets('every button is big enough and has a name', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  // The design's numbers, measured with the app's fonts as on a phone (the
  // test font's wider letters shrink the logo). Placed last: it loads the
  // fonts, and the tests above keep the test font.
  group('the 76 px menu layout with the app\'s fonts (user, 2026-11-14)', () {
    setUpAll(loadBattleFonts);

    // Home's 76 px menu layout (user, 2026-11-14): at the default text size
    // these phones show it all without scrolling, also with the note of
    // battles not saved yet.
    for (final (label, size, bars) in [
      ('360×780 with a three-button bar', const Size(360, 780), _systemBars),
      ('360×780 with a gesture bar', const Size(360, 780), _gestureBars),
      ('360×780 without bars', const Size(360, 780), FakeViewPadding.zero),
      ('393×852 with a three-button bar', const Size(393, 852), _systemBars),
      ('412×915 with a three-button bar', const Size(412, 915), _systemBars),
    ]) {
      for (final unsent in const [0, 2]) {
        testWidgets('a $label phone shows it all without scrolling'
            '${unsent > 0 ? ', with the note of battles not saved' : ''}', (
          tester,
        ) async {
          repository.profile = UserProfile(
            name: '우현',
            lastMatch: _lastMatch,
            unsentMatches: unsent,
          );
          await open(tester, size: size, bars: bars);
          expect(tester.takeException(), isNull);
          expect(
            find.textContaining('저장하지 못한 경기'),
            unsent > 0 ? findsOneWidget : findsNothing,
          );
          expect(_scrollRoom(tester), 0);
          for (final title in _titles) {
            expect(
              tester.getRect(_row(title)).bottom,
              lessThanOrEqualTo(size.height - bars.bottom),
            );
            expect(find.text(title).hitTestable(), findsOneWidget);
          }
          expect(
            _repBotSize(tester).height,
            inInclusiveRange(_least.height, _most.height),
          );
        });
      }
    }

    testWidgets('the design\'s layout on a 360×780 phone with a three-button '
        'bar: RepBot gets the 272 left, less the app\'s own sizes', (
      tester,
    ) async {
      await open(tester, size: const Size(360, 780), bars: _systemBars);
      // 708 inside the bars. From the top: 8; the top bar 48 (the chip's
      // tap height, the design's 44); 8; the logo row 40; 8 (the design's 6
      // as a token step); the 18 high line. Under RepBot: four rows of 75
      // (the design's 76 in token steps) and 8.
      const inside = 780 - 24 - 48;
      final chip = tester.getRect(
        find
            .ancestor(of: find.text('우현'), matching: find.byType(Material))
            .first,
      );
      expect(chip.top, 24 + 8);
      expect(chip.height, 48);
      expect(tester.getSize(find.text('GYMMOUSE')).height, 40);
      // The logo's lime bar: 11 x 34 with a 1.5 ink edge (the profile mark
      // is lime too, but round).
      final bar = find.byWidgetPredicate((w) {
        final decoration = w is Container ? w.decoration : null;
        return decoration is BoxDecoration &&
            decoration.color == AppColors.accent &&
            decoration.shape == BoxShape.rectangle &&
            decoration.border == Border.all(color: AppColors.ink, width: 1.5);
      });
      expect(tester.getSize(bar), const Size(11, 34));
      expect(tester.getSize(find.text('30초 실시간 운동 대결')).height, 18);
      expect(tester.getSize(find.text('1V1')).height, 18);
      final firstRow = tester.getRect(_row('게임 시작'));
      expect(firstRow.top, 24 + inside - 8 - 4 * LobbyMenuItem.height);
      expect(tester.getRect(_row('환경설정')).bottom, 24 + inside - 8);
      // The design's 272, less the chip's 4 and the gap's 2, plus the rows'
      // 4 x 1.
      expect(_slot(tester).height, 272 - (48 - 44) - (8 - 6) + 4 * (76 - 75));
      expect(_slot(tester).bottom, firstRow.top);
      // RepBot fills it at its design size: the room is wider than tall.
      expect(_repBotSize(tester), LobbyRepBot.designSize);
    });

    for (final textScale in const [1.3, 1.5]) {
      testWidgets('at $textScale× text a 360×780 phone with a three-button '
          'bar still fits: the logo and the menu titles keep their size, '
          'the small text grows', (tester) async {
        await open(
          tester,
          size: const Size(360, 780),
          bars: _systemBars,
          textScale: textScale,
        );
        expect(tester.takeException(), isNull);
        expect(_scrollRoom(tester), 0);
        expect(tester.getSize(find.text('GYMMOUSE')).height, 40);
        for (final title in _titles) {
          expect(tester.getSize(find.text(title)).height, 44, reason: title);
        }
        expect(
          tester.getSize(find.text('30초 실시간 운동 대결')).height,
          closeTo(18 * textScale, 1),
        );
        expect(
          tester.getSize(_row('게임 시작')).height,
          greaterThan(LobbyMenuItem.height),
        );
      });
    }
  });
}
