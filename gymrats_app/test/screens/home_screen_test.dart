import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:gymrats_app/widgets/battle_mode_card.dart';
import 'package:gymrats_app/widgets/bot_difficulty_sheet.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:gymrats_app/widgets/grid_background.dart';
import 'package:gymrats_app/widgets/match_record_card.dart';

import '../support/fakes.dart';

const _lastMatch = MatchRecord(
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: 24,
  opponentReps: 19,
);

void main() {
  late FakeUserRepository repository;

  // Home grows with each feature: a tap that misses its button must fail
  // here, not pass with nothing opened.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  setUp(() {
    repository = FakeUserRepository()
      ..profile = const UserProfile(
        name: '우현',
        bestReps: 32,
        lastMatch: _lastMatch,
      )
      // Home lists the recent battles (task: match history with feedback).
      ..recent = [_lastMatch];
  });

  /// Opens HomeScreen on a phone-sized screen, with a stub matching route
  /// that shows its argument.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          createViewModel: () => HomeViewModel(repository: repository),
        ),
        routes: {
          GymRatsApp.onlineBattleRoute: (_) =>
              const Scaffold(body: Text('online matching')),
          GymRatsApp.profileRoute: (_) =>
              const Scaffold(body: Text('my profile')),
          GymRatsApp.helpRoute: (_) => const HelpScreen(),
          GymRatsApp.matchingRoute: (context) {
            final request =
                ModalRoute.of(context)!.settings.arguments! as BotMatchRequest;
            return Scaffold(
              body: Text('matching ${request.exercise} ${request.difficulty}'),
            );
          },
        },
      ),
    );
    // The first frame shows loading; this one shows what the load returned.
    await tester.pump();
  }

  /// Taps the card called [mode] and checks that the exercise sheet opened.
  Future<void> openExerciseSheet(WidgetTester tester, String mode) async {
    await tester.tap(find.text(mode));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSheet), findsOneWidget);
  }

  /// Taps [exercise] on the exercise sheet.
  Future<void> choose(WidgetTester tester, String exercise) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ExerciseSheet),
        matching: find.text(exercise),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Takes the AI card as far as the difficulty sheet, and checks it opened.
  Future<void> openDifficultySheet(
    WidgetTester tester, {
    String exercise = '푸쉬업',
  }) async {
    await openExerciseSheet(tester, 'AI 1v1');
    await choose(tester, exercise);
    expect(find.byType(ExerciseSheet), findsNothing);
    expect(find.byType(BotDifficultySheet), findsOneWidget);
  }

  testWidgets('shows the greeting, the two modes and the recent battles', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(GridBackground), findsOneWidget);
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
    expect(find.text('오늘도 한 판,\n붙어볼까요?'), findsOneWidget);
    expect(find.text('대결 모드'), findsOneWidget);
    expect(find.text('30초 · 점수 높은 쪽 승리'), findsOneWidget);
    expect(find.byType(BattleModeCard), findsNWidgets(2));
    expect(find.text('온라인 1v1'), findsOneWidget);
    expect(find.text('사람과 실시간 대결'), findsOneWidget);
    expect(find.text('AI 1v1'), findsOneWidget);
    expect(find.text('봇과 난이도별 대결'), findsOneWidget);
    expect(find.text('최근 경기'), findsOneWidget);
    expect(find.text('24회'), findsOneWidget);
  });

  testWidgets('has no second main button, and no exercise or best of its own', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(AccentButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('종목 선택'), findsNothing);
    expect(find.textContaining('개인 최고'), findsNothing);
    final online = tester.widget<BattleModeCard>(
      find.widgetWithText(BattleModeCard, '온라인 1v1'),
    );
    final bot = tester.widget<BattleModeCard>(
      find.widgetWithText(BattleModeCard, 'AI 1v1'),
    );
    expect(online.main, isTrue);
    expect(bot.main, isFalse);
    // Each card has its own picture: the bot's has only the user's figure.
    Finder figuresOn(String title) => find.descendant(
      of: find.widgetWithText(BattleModeCard, title),
      matching: find.byType(ExercisePictogram),
    );
    expect(figuresOn('온라인 1v1'), findsNWidgets(2));
    expect(figuresOn('AI 1v1'), findsOneWidget);
  });

  testWidgets('the two modes stand side by side above the recent battles', (
    tester,
  ) async {
    await open(tester);
    final online = tester.getRect(
      find.widgetWithText(BattleModeCard, '온라인 1v1'),
    );
    final bot = tester.getRect(find.widgetWithText(BattleModeCard, 'AI 1v1'));
    expect(online.right, lessThan(bot.left));
    expect(online.top, bot.top);
    expect(online.size, bot.size);
    expect(
      tester.getTopLeft(find.text('최근 경기')).dy,
      greaterThan(online.bottom),
    );
  });

  testWidgets('shows the latest match in one card row', (tester) async {
    repository.recent = [
      const MatchRecord(
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot',
        myReps: 2,
        opponentReps: 1,
        myScore: 24,
        opponentScore: 19,
      ),
    ];
    await open(tester);
    expect(find.text('최근 경기'), findsOneWidget);
    final card = find.ancestor(
      of: find.text('vs RepBot'),
      matching: find.byType(Card),
    );
    for (final text in ['승', '푸쉬업', '24', ':', '19', '나', '상대']) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
      );
    }
    // One row: 16 padding (2.5.7) around the tallest item, the text.
    expect(tester.getSize(card).height, lessThan(100));

    // Badge, names, my score, ':' and their score from left to right.
    final badge = tester.getRect(find.text('승'));
    final names = tester.getRect(find.text('vs RepBot'));
    final mine = tester.getRect(find.text('24'));
    final colon = tester.getRect(find.text(':'));
    final theirs = tester.getRect(find.text('19'));
    expect(badge.right, lessThan(names.left));
    expect(names.right, lessThan(mine.left));
    expect(mine.right, lessThan(colon.left));
    expect(colon.right, lessThan(theirs.left));

    // Each label sits centered under its number.
    final me = tester.getRect(find.text('나'));
    final them = tester.getRect(find.text('상대'));
    expect(me.top, greaterThanOrEqualTo(mine.bottom));
    expect(me.center.dx, moreOrLessEquals(mine.center.dx, epsilon: 0.5));
    expect(them.top, greaterThanOrEqualTo(theirs.bottom));
    expect(them.center.dx, moreOrLessEquals(theirs.center.dx, epsilon: 0.5));
  });

  testWidgets(
    'recent match: my score is white, theirs gray, both in the number font',
    (tester) async {
      await open(tester);
      final mine = tester.widget<Text>(find.text('24회')).style!;
      expect(mine.fontFamily, AppFonts.number);
      expect(mine.fontWeight, FontWeight.w700);
      final theme = Theme.of(tester.element(find.text('24회'))).textTheme;
      final titleLarge = theme.titleLarge!;
      expect(mine.fontSize, titleLarge.fontSize);
      expect(mine.color, AppColors.textPrimary);
      final theirs = tester.widget<Text>(find.text('19회')).style!;
      expect(theirs.fontFamily, AppFonts.number);
      expect(theirs.fontWeight, FontWeight.w700);
      expect(theirs.fontSize, titleLarge.fontSize);
      expect(theirs.color, AppColors.textSecondary);
      final colon = tester.widget<Text>(find.text(':')).style!;
      expect(colon.color, AppColors.textMuted);

      // 나 is dark text on a lime pill; 상대 is small gray text.
      final pill = tester.widget<DecoratedBox>(
        find
            .ancestor(of: find.text('나'), matching: find.byType(DecoratedBox))
            .first,
      );
      expect((pill.decoration as ShapeDecoration).color, AppColors.accent);
      final me = tester.widget<Text>(find.text('나')).style!;
      final bodySmall = theme.bodySmall!;
      expect(me.fontSize, bodySmall.fontSize);
      expect(me.color, AppColors.background);
      final them = tester.widget<Text>(find.text('상대')).style!;
      expect(them.fontSize, bodySmall.fontSize);
      expect(them.color, AppColors.textSecondary);
    },
  );

  testWidgets('my score stays highlighted when I lose', (tester) async {
    repository.profile = const UserProfile(
      name: '우현',
      lastMatch: MatchRecord(
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot',
        myReps: 19,
        opponentReps: 24,
      ),
    );
    repository.recent = [repository.profile.lastMatch!];
    await open(tester);
    expect(find.text('패'), findsOneWidget);
    final mine = tester.widget<Text>(find.text('19회')).style!;
    expect(mine.color, AppColors.textPrimary);
    final theirs = tester.widget<Text>(find.text('24회')).style!;
    expect(theirs.color, AppColors.textSecondary);
    // 나 stays under my score.
    expect(
      tester.getRect(find.text('나')).center.dx,
      moreOrLessEquals(
        tester.getRect(find.text('19회')).center.dx,
        epsilon: 0.5,
      ),
    );
  });

  testWidgets('says there is no match yet before the first battle', (
    tester,
  ) async {
    repository.profile = const UserProfile(name: '우현');
    repository.recent = [];
    await open(tester);
    expect(find.text('최근 경기'), findsOneWidget);
    expect(find.text('아직 경기 기록이 없어요. 첫 대결을 시작해 보세요!'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    repository.gate = Completer();
    await open(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('온라인 1v1'), findsNothing);
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('온라인 1v1'), findsOneWidget);
  });

  testWidgets('a failed load shows a retry button that loads again', (
    tester,
  ) async {
    repository.error = Exception('offline');
    await open(tester);
    expect(find.text('정보를 불러오지 못했어요'), findsOneWidget);
    repository.error = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
    expect(repository.fetchCount, 2);
  });

  for (final (name, exercise) in const [
    ('푸쉬업', ExerciseType.pushUp),
    ('스쿼트', ExerciseType.squat),
  ]) {
    testWidgets('the online card asks for the exercise, then opens the lobby '
        'for $name', (tester) async {
      await open(tester);
      await openExerciseSheet(tester, '온라인 1v1');
      expect(find.text('온라인 1v1 · 30초'), findsOneWidget);
      expect(find.text('online matching'), findsNothing);

      await choose(tester, name);
      expect(find.byType(ExerciseSheet), findsNothing);
      final context = tester.element(find.text('online matching'));
      expect(ModalRoute.of(context)!.settings.arguments, exercise);
    });
  }

  testWidgets('the online card never asks how hard', (tester) async {
    await open(tester);
    await openExerciseSheet(tester, '온라인 1v1');
    await choose(tester, '푸쉬업');
    expect(find.byType(BotDifficultySheet), findsNothing);
  });

  testWidgets('closing the online sheet stays on home with no lobby', (
    tester,
  ) async {
    await open(tester);
    await openExerciseSheet(tester, '온라인 1v1');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSheet), findsNothing);
    expect(find.text('online matching'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets("the exercise sheet shows each exercise's own best", (
    tester,
  ) async {
    repository.profile = const UserProfile(
      name: '우현',
      bests: {
        ExerciseType.pushUp: PersonalBest(reps: 14, score: 150),
        ExerciseType.squat: PersonalBest(reps: 9),
      },
    );
    await open(tester);
    await openExerciseSheet(tester, 'AI 1v1');
    expect(find.text('개인 최고 150점'), findsOneWidget);
    expect(find.text('개인 최고 9회'), findsOneWidget);
  });

  testWidgets('a new user reads a dash on the sheet, not 0점 or 0회', (
    tester,
  ) async {
    repository.profile = const UserProfile(name: '우현');
    repository.recent = [];
    await open(tester);
    await openExerciseSheet(tester, '온라인 1v1');
    expect(find.text('개인 최고 —'), findsNWidgets(2));
    expect(find.textContaining('0점'), findsNothing);
    expect(find.textContaining('0회'), findsNothing);
  });

  testWidgets('profile button opens profile', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('my profile'), findsOneWidget);
  });

  testWidgets("'?' opens the rules from the greeting; back returns home", (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byTooltip('게임 규칙'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.text('건너뛰기'), findsNothing);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
  });

  testWidgets("'?' has a 48×48 tap target and sits left of the profile", (
    tester,
  ) async {
    await open(tester);
    final help = find.widgetWithIcon(IconButton, Icons.help_outline_rounded);
    expect(tester.getSize(help), const Size(48, 48));
    expect(
      tester.getRect(help).right,
      lessThanOrEqualTo(tester.getRect(find.byTooltip('프로필')).left),
    );
    expect(tester.widget<IconButton>(help).color, AppColors.textSecondary);
  });

  testWidgets('a long name wraps beside all three greeting buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository.profile = const UserProfile(name: '아주아주아주아주아주아주아주긴이름의사용자');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          createViewModel: () => HomeViewModel(repository: repository),
          onLogOut: () async {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('프로필'), findsOneWidget);
    expect(find.byTooltip('로그아웃'), findsOneWidget);
    final name = find.textContaining('안녕하세요');
    final greeting = tester.getRect(name);
    final help = tester.getRect(find.byTooltip('게임 규칙'));
    expect(greeting.right, lessThanOrEqualTo(help.left));
    // Two lines at least: one line stays under twice the font size.
    final fontSize = tester.widget<Text>(name).style!.fontSize!;
    expect(greeting.height, greaterThanOrEqualTo(fontSize * 2));
    expect(tester.takeException(), isNull);
  });

  for (final (name, exercise, word) in const [
    ('푸쉬업', ExerciseType.pushUp, '푸쉬업 · 30초 · 1v1'),
    ('스쿼트', ExerciseType.squat, '스쿼트 · 30초 · 1v1'),
  ]) {
    testWidgets('the AI card asks for the exercise and how hard, then opens '
        'matching for $name', (tester) async {
      await open(tester);
      await openDifficultySheet(tester, exercise: name);
      expect(find.text(word), findsOneWidget);
      expect(find.textContaining('matching'), findsNothing);

      await tester.tap(find.text('중수'));
      await tester.pumpAndSettle();
      expect(find.byType(BotDifficultySheet), findsNothing);
      expect(
        find.text('matching $exercise ${BotDifficulty.intermediate}'),
        findsOneWidget,
      );
    });
  }

  testWidgets('closing the AI exercise sheet stays on home with no search', (
    tester,
  ) async {
    await open(tester);
    await openExerciseSheet(tester, 'AI 1v1');
    expect(find.text('AI 1v1 · 30초'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSheet), findsNothing);
    expect(find.byType(BotDifficultySheet), findsNothing);
    expect(find.textContaining('matching'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('closing the difficulty sheet stays on home with no search', (
    tester,
  ) async {
    await open(tester);
    await openDifficultySheet(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BotDifficultySheet), findsNothing);
    expect(find.textContaining('matching'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a level chosen after home has gone starts no search', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => HomeScreen(
                    createViewModel: () =>
                        HomeViewModel(repository: repository),
                  ),
                ),
              ),
              child: const Text('below home'),
            ),
          ),
        ),
        routes: {GymRatsApp.matchingRoute: (_) => const Text('matching')},
      ),
    );
    await tester.tap(find.text('below home'));
    await tester.pumpAndSettle();
    await openDifficultySheet(tester);

    final home = ModalRoute.of(tester.element(find.byType(HomeScreen)))!;
    home.navigator!.removeRoute(home);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(BotDifficultySheet), findsOneWidget);

    await tester.tap(find.text('중수'));
    await tester.pumpAndSettle();
    expect(find.text('matching'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an exercise chosen online after home has gone opens no lobby', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => HomeScreen(
                    createViewModel: () =>
                        HomeViewModel(repository: repository),
                  ),
                ),
              ),
              child: const Text('below home'),
            ),
          ),
        ),
        routes: {
          GymRatsApp.onlineBattleRoute: (_) => const Text('online matching'),
        },
      ),
    );
    await tester.tap(find.text('below home'));
    await tester.pumpAndSettle();
    await openExerciseSheet(tester, '온라인 1v1');

    final home = ModalRoute.of(tester.element(find.byType(HomeScreen)))!;
    home.navigator!.removeRoute(home);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);

    await choose(tester, '푸쉬업');
    expect(find.text('online matching'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an exercise chosen after home has gone asks nothing more', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => HomeScreen(
                    createViewModel: () =>
                        HomeViewModel(repository: repository),
                  ),
                ),
              ),
              child: const Text('below home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('below home'));
    await tester.pumpAndSettle();
    await openExerciseSheet(tester, 'AI 1v1');

    final home = ModalRoute.of(tester.element(find.byType(HomeScreen)))!;
    home.navigator!.removeRoute(home);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);

    await choose(tester, '푸쉬업');
    expect(find.byType(BotDifficultySheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coming back home loads the latest battle and best record', (
    tester,
  ) async {
    // The app's observer tells HomeScreen when it shows again.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        navigatorObservers: [GymRatsApp.routeObserver],
        home: HomeScreen(
          createViewModel: () => HomeViewModel(repository: repository),
        ),
        routes: {
          GymRatsApp.matchingRoute: (_) =>
              const Scaffold(body: Text('a battle')),
        },
      ),
    );
    await tester.pump();
    expect(find.text('24회'), findsOneWidget);

    await openDifficultySheet(tester);
    await tester.tap(find.text('고수'));
    await tester.pumpAndSettle();
    // The battle was saved meanwhile.
    repository.profile = const UserProfile(
      name: '우현',
      bestReps: 40,
      lastMatch: MatchRecord(
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot',
        myReps: 40,
        opponentReps: 30,
      ),
    );
    repository.recent = [repository.profile.lastMatch!];
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(repository.fetchCount, 2);
    expect(find.text('40회'), findsOneWidget);
    expect(find.text('30회'), findsOneWidget);
    expect(find.text('24회'), findsNothing);
    // The next sheet reads the new best.
    await openExerciseSheet(tester, 'AI 1v1');
    expect(find.text('개인 최고 40회'), findsOneWidget);
  });

  testWidgets('closing any sheet does not load home again', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        navigatorObservers: [GymRatsApp.routeObserver],
        home: HomeScreen(
          createViewModel: () => HomeViewModel(repository: repository),
        ),
      ),
    );
    await tester.pump();
    expect(repository.fetchCount, 1);

    Future<void> close() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    for (var turn = 0; turn < 2; turn++) {
      await openExerciseSheet(tester, '온라인 1v1');
      await close();
      await openExerciseSheet(tester, 'AI 1v1');
      await close();
      await openDifficultySheet(tester);
      await close();
    }
    expect(repository.fetchCount, 1);
  });

  group('coming back to home loads it again', () {
    /// Home with the app's observer, which tells it when it shows again.
    Future<void> openObserved(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          navigatorObservers: [GymRatsApp.routeObserver],
          home: HomeScreen(
            createViewModel: () => HomeViewModel(repository: repository),
          ),
          routes: {
            GymRatsApp.onlineBattleRoute: (_) =>
                const Scaffold(body: Text('a lobby')),
          },
        ),
      );
      await tester.pump();
      expect(repository.fetchCount, 1);
    }

    testWidgets('after the online lobby', (tester) async {
      await openObserved(tester);
      await openExerciseSheet(tester, '온라인 1v1');
      await choose(tester, '푸쉬업');
      expect(find.text('a lobby'), findsOneWidget);
      expect(repository.fetchCount, 1);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(repository.fetchCount, 2);
    });

    for (final (name, openSheet) in [
      (
        'the online sheet',
        (WidgetTester tester) => openExerciseSheet(tester, '온라인 1v1'),
      ),
      (
        'the AI exercise sheet',
        (WidgetTester tester) => openExerciseSheet(tester, 'AI 1v1'),
      ),
      (
        'the difficulty sheet',
        (WidgetTester tester) => openDifficultySheet(tester),
      ),
    ]) {
      testWidgets('after a page, once $name was closed', (tester) async {
        await openObserved(tester);
        await openSheet(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(repository.fetchCount, 1);

        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed(GymRatsApp.onlineBattleRoute);
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(repository.fetchCount, 2);
      });
    }
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    repository.profile = const UserProfile(
      name: '우현',
      bestReps: 999,
      lastMatch: MatchRecord(
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot with a very long name',
        myReps: 100,
        opponentReps: 99,
      ),
    );
    repository.recent = [repository.profile.lastMatch!];
    await open(tester, size: const Size(360, 640));
    // The row was laid out, so an overflow in it would have been reported.
    expect(find.text('99회', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a network failure says why under the title', (tester) async {
    repository.error = const ApiException(ApiErrorKind.network);
    await open(tester);
    expect(find.text('정보를 불러오지 못했어요'), findsOneWidget);
    expect(
      find.text(const ApiException(ApiErrorKind.network).message),
      findsOneWidget,
    );
  });

  testWidgets('battles not saved yet show an amber note', (tester) async {
    repository.profile = const UserProfile(
      name: '우현',
      lastMatch: _lastMatch,
      unsentMatches: 2,
    );
    repository.recent = [repository.profile.lastMatch!];
    await open(tester);
    final note = find.text('저장하지 못한 경기 2개 · 연결되면 다시 저장해요');
    expect(note, findsOneWidget);
    expect(tester.widget<Text>(note).style!.color, AppColors.warning);
  });

  testWidgets('no note when every battle is saved', (tester) async {
    await open(tester);
    expect(find.textContaining('저장하지 못한 경기'), findsNothing);
  });

  testWidgets('no logout button without a logout action', (tester) async {
    await open(tester);
    expect(find.byTooltip('로그아웃'), findsNothing);
  });

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  group('recent battles', () {
    MatchRecord battle(int id, {String? issue, bool feedback = true}) =>
        MatchRecord(
          id: id,
          exercise: ExerciseType.pushUp,
          opponentName: 'Rival$id',
          myReps: 10 + id,
          opponentReps: 5,
          playedAt: DateTime(2026, 10, 21, 9, id),
          feedbackSummary: feedback
              ? FeedbackSummary(
                  validReps: 10,
                  invalidReps: 0,
                  issueCount: issue == null ? 0 : 1,
                  topIssue: issue,
                )
              : null,
        );

    testWidgets('home shows the newest three with result, date, feedback', (
      tester,
    ) async {
      repository.recent = [
        battle(5, issue: '깊이 부족 1회'),
        battle(4),
        battle(3, feedback: false),
        battle(2),
        battle(1),
      ];
      await open(tester);
      await tester.scrollUntilVisible(find.text('피드백 없음'), 180);
      expect(find.byType(MatchRecordCard), findsNWidgets(3));
      expect(find.text('vs Rival5'), findsOneWidget);
      expect(find.text('vs Rival3'), findsOneWidget);
      expect(find.text('vs Rival2'), findsNothing);
      expect(find.text('깊이 부족 1회'), findsOneWidget);
      expect(find.text('푸쉬업 · 10월 21일 09:05'), findsOneWidget);
    });

    testWidgets('"전체 기록" calls the tab switch when given', (tester) async {
      var opened = 0;
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(
            createViewModel: () => HomeViewModel(repository: repository),
            onOpenHistory: () => opened++,
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('전체 기록 ›'), 180);
      await tester.tap(find.text('전체 기록 ›'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('the fallback latest battle shows no feedback line', (
      tester,
    ) async {
      repository.recentError = Exception('offline');
      await open(tester);
      await tester.scrollUntilVisible(find.text('vs RepBot'), 180);
      expect(find.text('피드백 없음'), findsNothing);
    });

    testWidgets('a row without feedback is not tappable', (tester) async {
      repository.recent = [battle(3, feedback: false)];
      await open(tester);
      await tester.scrollUntilVisible(find.text('피드백 없음'), 180);
      final ink = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('vs Rival3'),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.onTap, isNull);
    });
  });
}
