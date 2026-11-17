import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/feedback/feedback_stats.dart';
import 'package:gymrats_app/services/feedback/goal_store.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/viewmodels/coach_viewmodel.dart';
import 'package:gymrats_app/viewmodels/result_viewmodel.dart';
import 'package:gymrats_app/widgets/result_cards.dart';
import 'package:gymrats_app/widgets/result_report.dart';
import 'package:gymrats_app/widgets/victory_overlay.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';
import 'package:provider/provider.dart';

import '../support/auth_fakes.dart';
import '../support/fakes.dart';
import '../support/feedback_fakes.dart';
import '../support/form_report_fixtures.dart';
import '../widgets/battle_test_support.dart';

// The drawing of the report is tested in test/widgets/result_report_test.dart
// and result_cards_test.dart, the victory scene and its seat in
// test/widgets/victory_*_test.dart. This file checks only what the screen
// adds: the values it takes from J4's result view model, where its buttons
// lead, and the victory scene over it (W5 part 2).

final _endedAt = DateTime(2026, 11, 4, 14, 30);

final _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: const Opponent(
    name: 'RepBot',
    isBot: true,
  ).at(BotDifficulty.beginner),
);

final _squatBot = Matchup(
  exercise: ExerciseType.squat,
  playerName: '우현',
  opponent: const Opponent(
    name: 'RepBot',
    isBot: true,
  ).at(BotDifficulty.expert),
);

final _form = FormReport(
  endedAt: _endedAt,
  opponentName: 'AI 봇 · 초보',
  roundLength: const Duration(seconds: 30),
  reps: const [],
  samples: const [],
);

const _online = Matchup(
  exercise: ExerciseType.squat,
  playerName: '우현',
  opponent: Opponent(name: '진영', isBot: false),
);

BattleResult _result({
  Matchup? matchup,
  MatchOutcome? outcome = MatchOutcome.win,
  GameEnd end = GameEnd.timeUp,
  Duration roundLength = const Duration(seconds: 30),
  int myScore = 240,
  int opponentScore = 125,
  int opponentReps = 14,
  BattleDeparture departure = BattleDeparture.none,
  FormReport? form,
}) => BattleResult(
  matchup: matchup ?? _matchup,
  myReps: 12,
  myInvalidReps: 2,
  opponentReps: opponentReps,
  myScore: myScore,
  opponentScore: opponentScore,
  end: end,
  decidedOutcome: outcome,
  endedAt: _endedAt,
  roundLength: roundLength,
  form: form,
  departure: departure,
);

/// Push-up battles before the one under test, oldest first, one day apart
/// from 10월 28일 (the design's last-8 card: 185 the best, 136 the mean of
/// the last five).
FakeFeedbackStatsSource _earlier([
  List<int> scores = const [80, 95, 110, 105, 130, 150, 185],
]) => FakeFeedbackStatsSource([
  for (var i = 0; i < scores.length; i++)
    statsPoint(100 + i, DateTime(2026, 10, 28 + i, 20), score: scores[i]),
]);

/// A state as J4's view model gives it, for the mapping alone.
ResultState _state({
  MatchOutcome outcome = MatchOutcome.win,
  GameEnd? end = GameEnd.timeUp,
  Opponent? opponent = const Opponent(name: '진영', isBot: false),
  String opponentName = '진영',
  Duration? roundLength = const Duration(seconds: 30),
  int myScore = 240,
  int? myInvalidReps = 2,
  BattleDeparture departure = BattleDeparture.none,
  ResultHistoryPhase history = ResultHistoryPhase.ready,
  int? previousBest,
  bool isNewBest = false,
  List<int> recentScores = const [],
  DateTime? recentFrom,
  int? recentAverage,
  int recentAverageOf = 0,
  FormReport? form,
  NextTip? nextTip,
}) => ResultState(
  endedAt: _endedAt,
  outcome: outcome,
  end: end,
  exercise: ExerciseType.pushUp,
  opponent: opponent,
  opponentName: opponentName,
  roundLength: roundLength,
  myScore: myScore,
  opponentScore: 125,
  myReps: 12,
  opponentReps: 14,
  myInvalidReps: myInvalidReps,
  departure: departure,
  history: history,
  previousBest: previousBest,
  isNewBest: isNewBest,
  recentScores: recentScores,
  recentFrom: recentFrom,
  recentAverage: recentAverage,
  recentAverageOf: recentAverageOf,
  form: form,
  nextTip: nextTip,
);

/// The routes pushed or put in place, in order.
class _Routes extends NavigatorObserver {
  final settings = <RouteSettings>[];

  List<String?> get names => [for (final route in settings) route.name];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      settings.add(route.settings);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      settings.add(newRoute!.settings);
}

void main() {
  group('the values it takes from J4\'s result state', () {
    test('the outcome, the scores, the reps, the length, the opponent', () {
      final data = ResultScreen.reportOf(_state());
      expect(data.outcome, MatchOutcome.win);
      expect(data.byKo, isFalse);
      expect(data.exercise, ExerciseType.pushUp);
      expect(data.opponent.name, '진영');
      expect(data.played, const Duration(seconds: 30));
      expect((data.myScore, data.opponentScore), (240, 125));
      expect((data.myValidReps, data.myInvalidReps), (12, 2));
      expect(data.opponentValidReps, 14);
      expect(data.endedAt, _endedAt);
      expect(data.departure, BattleDeparture.none);
      expect(data.hasFeedback, isFalse);
      expect(data.comparisonLoading, isFalse);
    });

    test('a KO is said by the end; a battle a player left has no length (the '
        'result carries the whole round, not when they left)', () {
      expect(ResultScreen.reportOf(_state(end: GameEnd.ko)).byKo, isTrue);
      for (final departure in [
        BattleDeparture.opponentLeft,
        BattleDeparture.myConnectionLost,
      ]) {
        final data = ResultScreen.reportOf(
          _state(end: null, departure: departure),
        );
        expect(data.departure, departure);
        expect(data.byKo, isFalse);
        expect(data.played, isNull);
      }
    });

    test('a past battle keeps only the name; its rejected reps may be '
        'unknown', () {
      final data = ResultScreen.reportOf(
        _state(opponent: null, opponentName: 'AI 봇 · 초보', myInvalidReps: null),
      );
      expect(data.opponent.name, 'AI 봇 · 초보');
      expect(data.opponent.isBot, isFalse);
      expect(data.myInvalidReps, isNull);
    });

    test('a new best: the best before, this score, and the gain', () {
      final best = ResultScreen.reportOf(
        _state(previousBest: 185, isNewBest: true),
      ).best!;
      expect((best.previous, best.current, best.gain), (185, 240, 55));
    });

    test('no best card when the best was not beaten, or there was none (the '
        'first battle)', () {
      expect(ResultScreen.reportOf(_state(previousBest: 250)).best, isNull);
      expect(ResultScreen.reportOf(_state(previousBest: 240)).best, isNull);
      expect(ResultScreen.reportOf(_state()).best, isNull);
    });

    test('the latest battles: the scores, the first date, the average and '
        'this score against it', () {
      final recent = ResultScreen.reportOf(
        _state(
          recentScores: const [80, 95, 110, 105, 130, 150, 185, 240],
          recentFrom: DateTime(2026, 10, 28),
          recentAverage: 136,
          recentAverageOf: 5,
        ),
      ).recent!;
      expect(recent.scores, [80, 95, 110, 105, 130, 150, 185, 240]);
      expect(recent.firstPlayedAt, DateTime(2026, 10, 28));
      expect((recent.average, recent.averageCount), (136, 5));
      expect(recent.difference, 104);
      final below = ResultScreen.reportOf(
        _state(
          myScore: 200,
          recentScores: const [250, 200],
          recentFrom: DateTime(2026, 11, 3),
          recentAverage: 250,
          recentAverageOf: 1,
        ),
      ).recent!;
      expect(below.difference, -50);
    });

    test('the first battle has no average: no latest-battles card', () {
      final data = ResultScreen.reportOf(
        _state(recentScores: const [240], recentFrom: _endedAt),
      );
      expect(data.recent, isNull);
    });

    test('a battle without a game score leaves the latest battles out: '
        'their last bar would be an earlier battle', () {
      final state = _state(
        recentScores: const [100, 120],
        recentFrom: DateTime(2026, 11, 2),
        recentAverage: 110,
        recentAverageOf: 2,
      );
      expect(ResultScreen.reportOf(state).recent, isNotNull);
      expect(ResultScreen.reportOf(state, scored: false).recent, isNull);
      final loading = _state(history: ResultHistoryPhase.loading);
      expect(ResultScreen.reportOf(loading).comparisonLoading, isTrue);
      expect(
        ResultScreen.reportOf(loading, scored: false).comparisonLoading,
        isFalse,
      );
    });

    test('while loading: the placeholder, and no comparison card even with '
        'values', () {
      final data = ResultScreen.reportOf(
        _state(
          history: ResultHistoryPhase.loading,
          previousBest: 185,
          isNewBest: true,
          recentScores: const [185, 240],
          recentFrom: DateTime(2026, 11, 3),
          recentAverage: 185,
          recentAverageOf: 1,
        ),
      );
      expect(data.comparisonLoading, isTrue);
      expect(data.best, isNull);
      expect(data.recent, isNull);
    });

    test('a failed load: no placeholder and no comparison card', () {
      final data = ResultScreen.reportOf(
        _state(
          history: ResultHistoryPhase.failed,
          previousBest: 185,
          isNewBest: true,
        ),
      );
      expect(data.comparisonLoading, isFalse);
      expect(data.best, isNull);
      expect(data.recent, isNull);
    });

    test('the tip leaves the report (task.md W10 decision 4); the character '
        'card shows only with a form report', () {
      const entry = ResultCoachEntry(
        characterId: 'seal',
        name: '물렁범',
        ending: '범',
        lineCount: 3,
      );
      final withForm = ResultScreen.reportOf(
        _state(
          form: _form,
          nextTip: const NextTip(
            headline: '가슴이 바닥에 가까워질 때까지 내려간 뒤 올라와요.',
            detail: '깊이 부족 2회',
          ),
        ),
        coach: entry,
      );
      expect(withForm.coach, same(entry));
      expect(ResultScreen.reportOf(_state(), coach: entry).coach, isNull);
      expect(ResultScreen.reportOf(_state(form: _form)).coach, isNull);
    });

    test('the talk\'s pill: exercise, opponent and result in the '
        'headline\'s words (task.md W10 decision 5)', () {
      expect(ResultScreen.summaryOf(_state()), '푸쉬업 · 진영 · 승리');
      expect(
        ResultScreen.summaryOf(
          _state(
            outcome: MatchOutcome.lose,
            end: GameEnd.ko,
            opponent: const Opponent(
              name: 'AI 봇 · 중수',
              isBot: true,
              difficulty: BotDifficulty.intermediate,
            ),
          ),
        ),
        '푸쉬업 · RepBot 중수 · KO 패배',
      );
      // A past battle keeps only the opponent's name.
      expect(
        ResultScreen.summaryOf(
          _state(outcome: MatchOutcome.draw, opponent: null),
        ),
        '푸쉬업 · 진영 · 무승부',
      );
    });

    test('feedback only with a form report', () {
      expect(ResultScreen.reportOf(_state(form: _form)).hasFeedback, isTrue);
    });
  });

  group('where the earlier battles come from', () {
    Future<FeedbackStatsSource> sourceUnder(
      WidgetTester tester,
      UserRepository? repository,
    ) async {
      late FeedbackStatsSource source;
      final reader = Builder(
        builder: (context) {
          source = ResultScreen.historyOf(context);
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(
        repository == null
            ? reader
            : Provider<UserRepository>.value(value: repository, child: reader),
      );
      return source;
    }

    testWidgets('the app\'s repository, when it keeps the battle list', (
      tester,
    ) async {
      final repository = FakeStatsUserRepository();
      expect(await sourceUnder(tester, repository), same(repository));
    });

    testWidgets('otherwise, or without a repository, every fetch fails', (
      tester,
    ) async {
      for (final repository in [FakeUserRepository(), null]) {
        final source = await sourceUnder(tester, repository);
        await expectLater(source.fetchStatsPoints(), throwsException);
      }
    });
  });

  group('on the screen', () {
    late _Routes routes;

    /// Opens ResultScreen above a home page, where the battle leaves it. With
    /// [history] its view model compares with those battles; without, no
    /// repository is given, so the comparison fails and stays out. The
    /// matching and feedback routes are stubs that show their argument.
    Future<void> open(
      WidgetTester tester,
      BattleResult result, {
      FeedbackStatsSource? history,
      UserRepository? repository,
      CoachViewModel Function(FormReport form)? coach,
      Widget Function(Widget app)? around,
    }) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      routes = _Routes();
      final app = MaterialApp(
        theme: AppTheme.light,
        navigatorObservers: [routes],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ResultScreen(
                    result: result,
                    createViewModel: history == null
                        ? null
                        : () =>
                              ResultViewModel.battle(result, history: history),
                    createCoachViewModel: coach,
                  ),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              Scaffold(body: Text('${settings.name} ${settings.arguments}')),
        ),
      );
      final provided = repository == null
          ? app
          : Provider<UserRepository>.value(value: repository, child: app);
      await tester.pumpWidget(around?.call(provided) ?? provided);
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      routes.settings.clear();
    }

    group('how it ended', () {
      for (final squat in [false, true]) {
        for (final (outcome, opponentScore, opponentReps, headline) in const [
          (MatchOutcome.win, 125, 14, '승리'),
          (MatchOutcome.lose, 260, 14, '패배'),
          (MatchOutcome.draw, 240, 12, '무승부'),
        ]) {
          testWidgets('a time-up ${squat ? 'squat' : 'push-up'} '
              '${outcome.name}: "$headline", both scores, the seconds', (
            tester,
          ) async {
            await open(
              tester,
              _result(
                matchup: squat ? _squatBot : _matchup,
                outcome: outcome,
                opponentScore: opponentScore,
                opponentReps: opponentReps,
              ),
              history: _earlier(),
            );
            expect(find.byType(ResultReport), findsOneWidget);
            expect(find.text(headline), findsOneWidget);
            expect(
              find.text(squat ? '스쿼트 · vs ' : '푸쉬업 · vs '),
              findsOneWidget,
            );
            expect(
              find.text(squat ? 'RepBot 고수' : 'RepBot 초보'),
              findsOneWidget,
            );
            if (opponentScore == 240) {
              expect(find.text('240'), findsNWidgets(2));
            } else {
              expect(find.text('240'), findsOneWidget);
              expect(find.text('$opponentScore'), findsOneWidget);
            }
            expect(find.text(' · 30초'), findsOneWidget);
            expect(find.text('인정 12회 · 무효 2회'), findsOneWidget);
          });
        }
      }

      for (final (outcome, headline) in const [
        (MatchOutcome.win, 'KO 승리'),
        (MatchOutcome.lose, 'KO 패배'),
      ]) {
        testWidgets('a KO ${outcome.name}: "$headline" and the time it took', (
          tester,
        ) async {
          await open(
            tester,
            _result(
              outcome: outcome,
              end: GameEnd.ko,
              roundLength: const Duration(seconds: 24),
            ),
            history: _earlier(),
          );
          expect(find.text(headline), findsOneWidget);
          expect(find.text(' · 24초'), findsOneWidget);
        });
      }

      testWidgets('equal scores at time-up: the reps that decided it, under '
          'the sub line', (tester) async {
        await open(tester, _result(opponentScore: 240, opponentReps: 11));
        expect(find.text('승리'), findsOneWidget);
        expect(find.text('점수 같음 · 횟수로 승리'), findsOneWidget);
        expect(find.text(' · 30초'), findsOneWidget);
      });

      for (final (outcome, departure, headline, reason) in const [
        (MatchOutcome.win, BattleDeparture.opponentLeft, '승리', '상대가 나갔어요'),
        (MatchOutcome.lose, BattleDeparture.myConnectionLost, '패배', '연결이 끊겼어요'),
      ]) {
        testWidgets('an online battle that ended by ${departure.name}: '
            '$headline, and why, without the seconds', (tester) async {
          await open(
            tester,
            _result(
              matchup: _online,
              outcome: outcome,
              end: GameEnd.ko,
              departure: departure,
            ),
            history: _earlier(),
          );
          expect(find.text(headline), findsOneWidget);
          expect(find.text(reason), findsOneWidget);
          expect(find.text('진영'), findsOneWidget);
          expect(find.textContaining('초'), findsNothing);
        });
      }
    });

    group('the comparison with earlier battles', () {
      testWidgets('a new best: the best card and the latest battles, as in '
          'the design', (tester) async {
        await open(tester, _result(), history: _earlier());
        expect(find.text('개인 최고 기록 갱신'), findsOneWidget);
        expect(
          find.text('185점 → 240점 · 55점 올랐어요', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('최근 8판 중 이번 판'), findsOneWidget);
        expect(find.text('평균보다 +104점'), findsOneWidget);
        expect(find.text('최근 5판 평균 136'), findsOneWidget);
        expect(find.text('10/28'), findsOneWidget);
        expect(find.text('이번 판 240'), findsOneWidget);
        expect(find.byType(ResultComparisonPlaceholder), findsNothing);
      });

      for (final (earlier, chip) in const [
        ([250, 200], '평균보다 +15점'),
        ([240], '평균과 같아요'),
      ]) {
        testWidgets('earlier best ${earlier.first}: not beaten, so no best '
            'card; the latest battles still show', (tester) async {
          await open(tester, _result(), history: _earlier(earlier));
          expect(find.byType(ResultBestCard), findsNothing);
          expect(find.byType(ResultRecentCard), findsOneWidget);
          expect(find.text('최근 ${earlier.length + 1}판 중 이번 판'), findsOneWidget);
          expect(find.text(chip), findsOneWidget);
        });
      }

      testWidgets('the first battle: no new best and no comparison, the rest '
          'of the report as usual', (tester) async {
        final history = FakeFeedbackStatsSource();
        await open(tester, _result(form: _form), history: history);
        expect(history.calls.single.exercise, ExerciseType.pushUp);
        expect(find.byType(ResultBestCard), findsNothing);
        expect(find.textContaining('최고'), findsNothing);
        expect(find.byType(ResultRecentCard), findsNothing);
        expect(find.byType(ResultComparisonPlaceholder), findsNothing);
        expect(find.text('승리'), findsOneWidget);
        expect(find.text('자세 기록 표로 보기'), findsOneWidget);
      });

      testWidgets('while they load: the placeholder, no 0 and no chart; then '
          'the cards in its place', (tester) async {
        final history = _earlier()..gate = Completer<void>();
        await open(tester, _result(form: _form), history: history);
        final placeholder = find.byType(ResultComparisonPlaceholder);
        expect(placeholder, findsOneWidget);
        expect(find.text(ResultComparisonPlaceholder.text), findsOneWidget);
        expect(find.byType(ResultBestCard), findsNothing);
        expect(find.byType(ResultRecentCard), findsNothing);
        expect(find.text('0'), findsNothing);
        final top = tester.getRect(placeholder).top;
        // The feedback link does not wait for them.
        expect(find.text('자세 기록 표로 보기'), findsOneWidget);

        history.gate!.complete();
        await tester.pumpAndSettle();
        expect(placeholder, findsNothing);
        expect(
          tester.getRect(find.byType(ResultBestCard)).top,
          moreOrLessEquals(top, epsilon: 0.5),
        );
        expect(find.byType(ResultRecentCard), findsOneWidget);
      });

      testWidgets('a failed load: the comparison is left out, the rest of the '
          'report stays', (tester) async {
        final history = _earlier()..error = Exception('offline');
        await open(
          tester,
          _result(form: sampleReport(valid: 12, rejected: 2)),
          history: history,
        );
        expect(find.byType(ResultComparisonPlaceholder), findsNothing);
        expect(find.byType(ResultBestCard), findsNothing);
        expect(find.byType(ResultRecentCard), findsNothing);
        expect(find.text('승리'), findsOneWidget);
        expect(find.text('240'), findsOneWidget);
        expect(find.byType(ResultCoachCard), findsOneWidget);
        expect(find.text('자세 기록 표로 보기'), findsOneWidget);
      });

      testWidgets('from the app\'s repository, of this battle\'s exercise', (
        tester,
      ) async {
        final repository = FakeStatsUserRepository();
        repository.stats.points = _earlier().points;
        await open(tester, _result(), repository: repository);
        expect(repository.stats.calls.single.exercise, ExerciseType.pushUp);
        expect(find.byType(ResultBestCard), findsOneWidget);
        expect(find.byType(ResultRecentCard), findsOneWidget);
      });

      testWidgets('a repository without the battle list: no comparison, and '
          'nothing breaks', (tester) async {
        await open(tester, _result(), repository: FakeUserRepository());
        expect(tester.takeException(), isNull);
        expect(find.byType(ResultComparisonPlaceholder), findsNothing);
        expect(find.byType(ResultBestCard), findsNothing);
        expect(find.byType(ResultRecentCard), findsNothing);
        expect(find.text('승리'), findsOneWidget);
      });

      testWidgets('a battle without a game shows its reps as the scores, and '
          'no comparison: not even the placeholder while they load', (
        tester,
      ) async {
        final history = _earlier()..gate = Completer<void>();
        await open(tester, _result(outcome: null), history: history);
        expect(find.byType(ResultComparisonPlaceholder), findsNothing);
        history.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('패배'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('14'), findsOneWidget);
        expect(find.byType(ResultBestCard), findsNothing);
        expect(find.byType(ResultRecentCard), findsNothing);
      });
    });

    group('the character card (A10)', () {
      /// The label the card's sentence reads.
      final cardLine = RegExp(r'^GYM마우스, 이번 판 이야기해 줄게찍! 할 말이 \d+개 있어\.$');

      testWidgets('a battle with a form report: the card in place of the '
          'tip, with the talk\'s line count (task.md W10 decision 4)', (
        tester,
      ) async {
        late CoachViewModel made;
        await open(
          tester,
          _result(form: sampleReport(valid: 12, rejected: 2)),
          history: _earlier(),
          coach: (form) => made = CoachViewModel(
            report: form,
            characterId: 'seal',
            summary: '푸쉬업 · RepBot 고수 · 승리',
          ),
        );
        expect(find.byType(ResultCoachCard), findsOneWidget);
        expect(find.text('다음 판 한 가지'), findsNothing);
        expect(find.text('가슴이 바닥에 가까워질 때까지 내려간 뒤 올라와요.'), findsNothing);
        expect(made.lineCount, greaterThanOrEqualTo(3));
        expect(
          find.bySemanticsLabel(
            '물렁범, 이번 판 이야기해 줄게범! 할 말이 ${made.lineCount}개 있어.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('nothing to fix: the card all the same, and its link', (
        tester,
      ) async {
        await open(tester, _result(form: sampleReport()), history: _earlier());
        expect(find.bySemanticsLabel(cardLine), findsOneWidget);
        expect(find.text('자세 기록 표로 보기'), findsOneWidget);
      });

      testWidgets('without a form report there is no card', (tester) async {
        await open(tester, _result(), history: _earlier());
        expect(find.byType(ResultCoachCard), findsNothing);
      });

      testWidgets('이야기 듣기 opens the talk from its first line; back comes '
          'here again', (tester) async {
        await open(tester, _result(form: _form), history: _earlier());
        await tester.tap(find.text('이야기 듣기'));
        await tester.pumpAndSettle();
        expect(routes.names, [GymRatsApp.coachRoute]);
        final talk = routes.settings.single.arguments! as CoachViewModel;
        expect(talk.state.index, 0);
        expect(talk.state.ended, isFalse);
        expect(talk.summary, '푸쉬업 · RepBot 초보 · 승리');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ResultScreen), findsOneWidget);
      });

      testWidgets('건너뛰기 opens it at the goal question', (tester) async {
        await open(tester, _result(form: _form), history: _earlier());
        await tester.tap(find.text('건너뛰기'));
        await tester.pumpAndSettle();
        final talk = routes.settings.single.arguments! as CoachViewModel;
        expect(talk.state.onQuestion, isTrue);
      });

      testWidgets('with reduced motion the talk shows each line whole', (
        tester,
      ) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await open(tester, _result(form: _form), history: _earlier());
        await tester.tap(find.text('이야기 듣기'));
        await tester.pumpAndSettle();
        final talk = routes.settings.single.arguments! as CoachViewModel;
        expect(talk.state.fullyShown, isTrue);
      });

      testWidgets('the talk takes the app\'s goal store, account and '
          'character: a picked goal is saved for this account with it', (
        tester,
      ) async {
        final store = MemoryGoalStore();
        final auth = ScriptedAuthRepository();
        await auth.logIn(loginId: 'woohyun', password: 'pw');
        final characters = CharacterViewModel(store: MemoryCharacterStore());
        await characters.load(1);
        await characters.choose('penguin');
        await open(
          tester,
          _result(form: _form),
          history: _earlier(),
          around: (app) => MultiProvider(
            providers: [
              Provider<GoalStore>.value(value: store),
              ChangeNotifierProvider<AuthViewModel>.value(
                value: AuthViewModel(repository: auth),
              ),
              ChangeNotifierProvider<CharacterViewModel>.value(
                value: characters,
              ),
            ],
            child: app,
          ),
        );
        expect(
          find.bySemanticsLabel(RegExp('^펭뚱이, 이번 판 이야기해 줄게펭!')),
          findsOneWidget,
        );
        await tester.tap(find.text('건너뛰기'));
        await tester.pumpAndSettle();
        final talk = routes.settings.single.arguments! as CoachViewModel;
        talk.setInstant(true);
        final goal = talk.state.script!.suggestions.first;
        await talk.choose(goal);
        final saved = store.goals[(1, ExerciseType.pushUp)]!;
        expect(saved.title, goal.title);
        expect(saved.characterId, 'penguin');
        expect(saved.fromMatch, _form.id);
      });
    });

    group('the buttons', () {
      for (final (name, press) in [
        ('홈으로', (WidgetTester t) => t.tap(find.text('홈으로'))),
        ('the back button', (WidgetTester t) => t.tap(find.byTooltip('홈으로'))),
        ('system back', (WidgetTester t) => t.binding.handlePopRoute()),
      ]) {
        testWidgets('$name goes home', (tester) async {
          await open(tester, _result());
          await press(tester);
          await tester.pumpAndSettle();
          expect(find.text('home'), findsOneWidget);
          expect(find.byType(ResultScreen), findsNothing);
        });
      }

      testWidgets('다시 대결 replaces the result with a search for the same '
          'battle; back from it goes home', (tester) async {
        await open(tester, _result());
        await tester.tap(find.text('다시 대결'));
        await tester.pumpAndSettle();
        expect(routes.names, [GymRatsApp.matchingRoute]);
        final request = routes.settings.single.arguments! as BotMatchRequest;
        expect(request.exercise, ExerciseType.pushUp);
        expect(request.difficulty, BotDifficulty.beginner);
        expect(find.byType(ResultScreen), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
      });

      testWidgets('after an online battle 다시 대결 opens the online lobby with '
          'the same exercise, in the place of the result', (tester) async {
        await open(tester, _result(matchup: _online));
        await tester.tap(find.text('다시 대결'));
        await tester.pumpAndSettle();
        expect(routes.names, [GymRatsApp.onlineBattleRoute]);
        expect(routes.settings.single.arguments, ExerciseType.squat);
        expect(find.byType(ResultScreen), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
      });

      testWidgets('only the first leaving button acts', (tester) async {
        await open(tester, _result());
        final rematch = tester
            .widget<FilledButton>(find.byType(FilledButton))
            .onPressed!;
        final home = tester
            .widget<OutlinedButton>(find.byType(OutlinedButton))
            .onPressed!;
        rematch();
        rematch();
        home();
        await tester.pumpAndSettle();
        expect(routes.names, [GymRatsApp.matchingRoute]);
      });

      testWidgets('자세 기록 표로 보기 opens this battle\'s feedback on top; '
          'back comes here again', (tester) async {
        await open(tester, _result(form: _form));
        await tester.tap(find.text('자세 기록 표로 보기'));
        await tester.pumpAndSettle();
        expect(routes.names, [GymRatsApp.feedbackRoute]);
        expect(routes.settings.single.arguments, same(_form));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ResultScreen), findsOneWidget);
      });

      testWidgets('without a form report there is no feedback link', (
        tester,
      ) async {
        await open(tester, _result());
        expect(find.text('자세 기록 표로 보기'), findsNothing);
      });

      testWidgets('leaving while the earlier battles load: the late answer '
          'changes nothing', (tester) async {
        final history = _earlier()..gate = Completer<void>();
        await open(tester, _result(), history: history);
        await tester.tap(find.text('홈으로'));
        await tester.pumpAndSettle();
        history.gate!.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('home'), findsOneWidget);
      });
    });
  });

  group('the victory scene (W5 part 2)', () {
    // The app's fonts, so the seat is where it is on the phone. The group
    // runs last, so the tests above keep the test font.
    setUpAll(loadBattleFonts);

    test('the scene of J4\'s state: a win because the opponent left, by KO '
        'or by time; a loss; a draw', () {
      for (final (outcome, end, departure, scene) in const [
        (
          MatchOutcome.win,
          GameEnd.ko,
          BattleDeparture.none,
          VictoryResult.koWin,
        ),
        (
          MatchOutcome.win,
          GameEnd.timeUp,
          BattleDeparture.none,
          VictoryResult.timeWin,
        ),
        (
          MatchOutcome.win,
          null,
          BattleDeparture.opponentLeft,
          VictoryResult.leftWin,
        ),
        (
          MatchOutcome.lose,
          GameEnd.ko,
          BattleDeparture.none,
          VictoryResult.lose,
        ),
        (
          MatchOutcome.lose,
          null,
          BattleDeparture.myConnectionLost,
          VictoryResult.lose,
        ),
        (
          MatchOutcome.draw,
          GameEnd.timeUp,
          BattleDeparture.none,
          VictoryResult.draw,
        ),
      ]) {
        expect(
          ResultScreen.sceneOf(
            _state(outcome: outcome, end: end, departure: departure),
          ),
          scene,
          reason: '$outcome $end $departure',
        );
      }
    });

    /// The scene's overlay over the whole screen; the seat's own (its end
    /// look) does not play.
    final sceneOverlay = find.byWidgetPredicate(
      (widget) => widget is VictoryOverlay && widget.play,
    );

    VictoryFrame frameNow(WidgetTester tester) {
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: sceneOverlay,
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as VictoryPainter;
      return painter.frameIn(tester.getSize(sceneOverlay));
    }

    /// Where the seat is: right of the headline, on the score row.
    Offset seatPlace(WidgetTester tester) => Offset(
      200,
      tester.getRect(find.byType(ResultScoreRow)).top -
          VictoryOverlay.seatSize.height,
    );

    /// ResultScreen as the app's first page on a 360 x 780 phone with a
    /// status bar, after a battle; my character [character] when given.
    /// Returns when the scene's clock is at 0 ms (unless reduced motion
    /// keeps it from playing).
    Future<void> openScene(
      WidgetTester tester,
      BattleResult result, {
      String? character,
      FeedbackStatsSource? history,
      bool reduceMotion = false,
    }) async {
      tester.view
        ..physicalSize = const Size(360, 780)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
      if (reduceMotion) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      final app = MaterialApp(
        theme: AppTheme.light,
        home: ResultScreen(
          result: result,
          createViewModel: () =>
              ResultViewModel.battle(result, history: history ?? _earlier()),
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('${settings.name}')),
        ),
      );
      if (character == null) {
        await tester.pumpWidget(app);
      } else {
        final characters = CharacterViewModel(store: MemoryCharacterStore());
        addTearDown(characters.dispose);
        await characters.choose(character);
        await tester.pumpWidget(
          ChangeNotifierProvider<CharacterViewModel>.value(
            value: characters,
            child: app,
          ),
        );
      }
      // The seat is found after the first layout, then the clock ticks.
      await tester.pump();
      await tester.pump();
    }

    /// Fails unless the seat holds the end look of [scene] with [character].
    void expectSeat(
      WidgetTester tester,
      VictoryResult scene,
      String character,
    ) {
      expect(sceneOverlay, findsNothing);
      final seat = tester.widget<VictorySeat>(find.byType(VictorySeat));
      expect(seat.result, scene);
      expect(seat.characterId, character);
      expect(tester.getTopLeft(find.byType(VictorySeat)), seatPlace(tester));
    }

    for (final (name, result, scene, band) in [
      ('a KO win', _result(end: GameEnd.ko), VictoryResult.koWin, 'KO 승리'),
      ('a time-up win', _result(), VictoryResult.timeWin, '판정승'),
      (
        'an online win because the opponent left',
        _result(
          matchup: _online,
          end: GameEnd.ko,
          departure: BattleDeparture.opponentLeft,
        ),
        VictoryResult.leftWin,
        '기권승',
      ),
    ]) {
      testWidgets('$name: the cut-in with "$band" over the report, then my '
          'character on its seat right of the headline; then the report\'s '
          'buttons work', (tester) async {
        final semantics = tester.ensureSemantics();
        await openScene(tester, result, character: 'kangaroo');
        final overlay = tester.widget<VictoryOverlay>(sceneOverlay);
        expect(overlay.result, scene);
        expect(overlay.characterId, 'kangaroo');
        // It ends on the seat: x 200-344, its bottom on the score row: the
        // design's (200, 36), a status bar lower; the reason line of a
        // departure puts it one line lower still.
        expect(overlay.seat, seatPlace(tester));
        if (result.departure == BattleDeparture.none) {
          expect(overlay.seat.dy, closeTo(36, 4));
        }
        expect(tester.getSize(sceneOverlay), const Size(360, 780));
        expect(
          find.bySemanticsLabel(VictoryOverlay.skipWinLabel),
          findsOneWidget,
        );
        // Nothing in the seat while the scene draws it.
        expect(find.byType(VictorySeat), findsNothing);

        await tester.pump(const Duration(milliseconds: 1000));
        final frame = frameNow(tester);
        expect(frame.band!.text, band);
        expect(frame.panel, isNotNull);
        expect(frame.figure!.scale, greaterThan(1));

        await tester.pump(const Duration(milliseconds: 1099));
        expect(sceneOverlay, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        expectSeat(tester, scene, 'kangaroo');
        expect(
          find.bySemanticsLabel(VictoryOverlay.skipWinLabel),
          findsNothing,
        );

        await tester.tap(find.text('다시 대결'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            result.matchup.opponent.isBot
                ? GymRatsApp.matchingRoute
                : GymRatsApp.onlineBattleRoute,
          ),
          findsOneWidget,
        );
        semantics.dispose();
      });
    }

    for (final (outcome, character, endMs) in const [
      (MatchOutcome.lose, 'bear', 760),
      (MatchOutcome.draw, 'seal', 820),
    ]) {
      testWidgets('a ${outcome.name}: no cut-in and no band; $character '
          'frustrates once on the seat on a white stand, then the end look '
          'stays ($endMs ms)', (tester) async {
        final semantics = tester.ensureSemantics();
        final scene = outcome == MatchOutcome.lose
            ? VictoryResult.lose
            : VictoryResult.draw;
        await openScene(
          tester,
          _result(
            outcome: outcome,
            opponentScore: outcome == MatchOutcome.lose ? 260 : 240,
            opponentReps: 12,
          ),
          character: character,
        );
        expect(tester.widget<VictoryOverlay>(sceneOverlay).result, scene);
        expect(find.bySemanticsLabel(VictoryOverlay.skipLabel), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 300));
        final frame = frameNow(tester);
        expect(frame.panel, isNull);
        expect(frame.band, isNull);
        expect(frame.confetti, isEmpty);
        expect(frame.stand!.color, AppColors.card);
        expect(frame.figure!.foot, seatPlace(tester) + const Offset(86, 132));
        expect(frame.figure!.scale, closeTo(0.66, 0.001));

        await tester.pump(Duration(milliseconds: endMs - 301));
        expect(sceneOverlay, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        expectSeat(tester, scene, character);
        semantics.dispose();
      });
    }

    testWidgets('a tap anywhere skips to the end look on the seat; that tap '
        'does not reach the report\'s button, the next one does', (
      tester,
    ) async {
      await openScene(tester, _result(end: GameEnd.ko));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('다시 대결'), warnIfMissed: false);
      await tester.pump();
      expect(find.text(GymRatsApp.matchingRoute), findsNothing);
      expectSeat(tester, VictoryResult.koWin, 'mouse');
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(find.text('다시 대결'));
      await tester.pumpAndSettle();
      expect(find.text(GymRatsApp.matchingRoute), findsOneWidget);
    });

    for (final (outcome, scene) in const [
      (MatchOutcome.win, VictoryResult.timeWin),
      (MatchOutcome.lose, VictoryResult.lose),
    ]) {
      testWidgets('with reduced motion a ${outcome.name} does not play: the '
          'seat shows the end look from the first frame', (tester) async {
        await openScene(
          tester,
          _result(outcome: outcome),
          character: 'penguin',
          reduceMotion: true,
        );
        expectSeat(tester, scene, 'penguin');
        await tester.pump(const Duration(seconds: 3));
        expectSeat(tester, scene, 'penguin');
        // The report takes taps at once.
        await tester.tap(find.text('다시 대결'));
        await tester.pumpAndSettle();
        expect(find.text(GymRatsApp.matchingRoute), findsOneWidget);
      });
    }

    testWidgets('reduced motion turned on while it plays: the end look at '
        'once; turned off again, it does not play again', (tester) async {
      await openScene(tester, _result(end: GameEnd.ko));
      await tester.pump(const Duration(milliseconds: 700));
      expect(sceneOverlay, findsOneWidget);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      expectSeat(tester, VictoryResult.koWin, 'mouse');
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expectSeat(tester, VictoryResult.koWin, 'mouse');
    });

    testWidgets('it plays once: the earlier battles arriving after the end '
        'change the cards, not the seat', (tester) async {
      final history = _earlier()..gate = Completer<void>();
      await openScene(tester, _result(end: GameEnd.ko), history: history);
      await tester.pump(const Duration(milliseconds: 2100));
      expectSeat(tester, VictoryResult.koWin, 'mouse');
      history.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ResultRecentCard), findsOneWidget);
      expectSeat(tester, VictoryResult.koWin, 'mouse');
    });

    testWidgets('the earlier battles arriving while it plays change the cards '
        'under it, not the scene: it ends on the seat at 2100 ms', (
      tester,
    ) async {
      final history = _earlier()..gate = Completer<void>();
      await openScene(tester, _result(end: GameEnd.ko), history: history);
      final seat = tester.widget<VictoryOverlay>(sceneOverlay).seat;
      await tester.pump(const Duration(milliseconds: 700));
      history.gate!.complete();
      await tester.pump();
      expect(find.byType(ResultRecentCard), findsOneWidget);
      expect(tester.widget<VictoryOverlay>(sceneOverlay).seat, seat);
      await tester.pump(const Duration(milliseconds: 1399));
      expect(sceneOverlay, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expectSeat(tester, VictoryResult.koWin, 'mouse');
    });

    testWidgets('the scene follows the seat when the page moves while it '
        'plays: new insets, or a scroll (a screen reader can scroll it)', (
      tester,
    ) async {
      await openScene(tester, _result(end: GameEnd.ko));
      await tester.pump(const Duration(milliseconds: 500));
      Offset cell() => tester.getTopLeft(
        find.descendant(
          of: find.byType(ResultSeatRows),
          matching: find.byType(KeyedSubtree),
        ),
      );
      expect(tester.widget<VictoryOverlay>(sceneOverlay).seat, cell());

      tester.view.padding = const FakeViewPadding(top: 48);
      await tester.pump();
      await tester.pump();
      expect(cell().dy, seatPlace(tester).dy);
      expect(tester.widget<VictoryOverlay>(sceneOverlay).seat, cell());

      final atOne = cell();
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      await tester.pump();
      expect(cell(), isNot(atOne));
      expect(tester.widget<VictoryOverlay>(sceneOverlay).seat, cell());

      // A wider and shorter screen: the seat moves right, and the page
      // scrolls.
      tester.view.physicalSize = const Size(412, 560);
      await tester.pump();
      await tester.pump();
      final before = cell();
      expect(before.dx, 412 - 20 + ResultSeatRows.overhang - 144);
      expect(tester.widget<VictoryOverlay>(sceneOverlay).seat, before);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, greaterThan(40));
      position.jumpTo(40);
      await tester.pump();
      await tester.pump();
      expect(cell(), before - const Offset(0, 40));
      expect(tester.widget<VictoryOverlay>(sceneOverlay).seat, cell());
    });

    testWidgets('leaving while it plays (system back) goes home with nothing '
        'left running', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 780)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final result = _result(end: GameEnd.ko);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ResultScreen(
                      result: result,
                      createViewModel: () =>
                          ResultViewModel.battle(result, history: _earlier()),
                    ),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(sceneOverlay, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ResultScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without the app\'s character the default character plays', (
      tester,
    ) async {
      await openScene(tester, _result());
      expect(
        tester.widget<VictoryOverlay>(sceneOverlay).characterId,
        CharacterRig.defaultId,
      );
    });
  });

  group('a past battle from 기록보관소 (W5, team decision 2026-11-08)', () {
    setUpAll(loadBattleFonts);

    /// A past battle as J4's record view model gives it.
    ResultState past({
      required String name,
      bool? isOnline,
      ExerciseType exercise = ExerciseType.squat,
    }) => ResultState(
      endedAt: _endedAt,
      outcome: MatchOutcome.win,
      exercise: exercise,
      opponentName: name,
      isOnline: isOnline,
      myScore: 240,
      opponentScore: 125,
      myReps: 12,
      opponentReps: 6,
    );

    test('다시 대결: a battle just played keeps J4\'s rematch; a past bot '
        'battle reads the level from the bot\'s name, else 고수; a past '
        'online battle opens the lobby', () {
      const rematch = BotMatchRequest(
        exercise: ExerciseType.pushUp,
        difficulty: BotDifficulty.intermediate,
      );
      final played = ResultState(
        endedAt: _endedAt,
        outcome: MatchOutcome.win,
        exercise: ExerciseType.pushUp,
        opponent: const Opponent(name: 'RepBot', isBot: true),
        opponentName: 'RepBot',
        myScore: 1,
        opponentScore: 0,
        myReps: 1,
        opponentReps: 0,
        rematch: rematch,
      );
      expect(ResultScreen.rematchOf(played), same(rematch));
      expect(ResultScreen.rematchOf(_state()), isNull);

      for (final level in BotDifficulty.values) {
        final again = ResultScreen.rematchOf(
          past(name: level.opponentName, isOnline: false),
        )!;
        expect(again.difficulty, level);
        expect(again.exercise, ExerciseType.squat);
      }
      expect(
        ResultScreen.rematchOf(past(name: 'RepBot', isOnline: false))!
            .difficulty,
        BotDifficulty.expert,
      );
      expect(ResultScreen.rematchOf(past(name: '진영', isOnline: true)), isNull);
      // Not known as online or not: a bot's name says it was a bot.
      expect(
        ResultScreen.rematchOf(past(name: BotDifficulty.beginner.opponentName))!
            .difficulty,
        BotDifficulty.beginner,
      );
      expect(ResultScreen.rematchOf(past(name: '진영')), isNull);
    });

    late _Routes routes;

    /// Home, then 기록보관소's stand-in on top of it: a page whose button
    /// opens [record]'s report as a row does ([reportTap]), with the app's
    /// [repository].
    Future<void> openPast(
      WidgetTester tester,
      MatchRecord record, {
      UserRepository? repository,
      String character = 'penguin',
    }) async {
      tester.view
        ..physicalSize = const Size(360, 780)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
      routes = _Routes();
      final characters = CharacterViewModel(store: MemoryCharacterStore());
      addTearDown(characters.dispose);
      await characters.choose(character);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserRepository>.value(
              value: repository ?? FakeUserRepository(),
            ),
            ChangeNotifierProvider<CharacterViewModel>.value(value: characters),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            navigatorObservers: [routes],
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        body: TextButton(
                          onPressed: reportTap(context, record),
                          child: const Text('archive'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('home'),
                ),
              ),
            ),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(body: Text('${settings.name}')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('archive'));
      await tester.pump();
    }

    final sceneOverlay = find.byWidgetPredicate(
      (widget) => widget is VictoryOverlay && widget.play,
    );

    for (final (name, record, scene) in [
      (
        'a KO win',
        MatchRecord(
          id: 7,
          exercise: ExerciseType.pushUp,
          opponentName: BotDifficulty.beginner.opponentName,
          myReps: 12,
          opponentReps: 6,
          myScore: 240,
          opponentScore: 125,
          playedAt: _endedAt,
          gameEnd: GameEnd.ko,
          isOnline: false,
        ),
        VictoryResult.koWin,
      ),
      (
        'an online win because the opponent left',
        MatchRecord(
          exercise: ExerciseType.squat,
          opponentName: '진영',
          myReps: 5,
          opponentReps: 3,
          playedAt: _endedAt,
          isOnline: true,
          opponentLeft: true,
        ),
        VictoryResult.leftWin,
      ),
      (
        'a loss',
        MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: 'RepBot',
          myReps: 4,
          opponentReps: 9,
          playedAt: _endedAt,
        ),
        VictoryResult.lose,
      ),
    ]) {
      testWidgets('$name: the report opens on top with the end look only, '
          'from its first frame; system back returns to 기록보관소', (tester) async {
        await openPast(tester, record);
        // The page's first frame, and every one after it.
        for (var i = 0; i < 4; i++) {
          expect(sceneOverlay, findsNothing);
          await tester.pump(const Duration(milliseconds: 150));
        }
        await tester.pumpAndSettle();
        final screen = tester.widget<ResultScreen>(find.byType(ResultScreen));
        expect(screen.record, same(record));
        expect(screen.result, isNull);
        final seat = tester.widget<VictorySeat>(find.byType(VictorySeat));
        expect(seat.result, scene);
        expect(seat.characterId, 'penguin');
        // On the seat, as after a battle.
        expect(
          tester.getTopLeft(find.byType(VictorySeat)),
          Offset(
            200,
            tester.getRect(find.byType(ResultScoreRow)).top -
                VictoryOverlay.seatSize.height,
          ),
        );
        expect(find.bySemanticsLabel(RegExp('연출 건너뛰기')), findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('archive'), findsOneWidget);
      });
    }

    testWidgets('its values come from J4\'s record view model: the form '
        'report from the app\'s repository, so the feedback link shows', (
      tester,
    ) async {
      final report = sampleReport();
      final repository = FakeUserRepository()..reports = {7: report};
      await openPast(
        tester,
        MatchRecord(
          id: 7,
          exercise: ExerciseType.pushUp,
          opponentName: BotDifficulty.beginner.opponentName,
          myReps: 3,
          opponentReps: 1,
          playedAt: _endedAt,
          isOnline: false,
          feedbackSummary: const FeedbackSummary(
            validReps: 3,
            invalidReps: 0,
            issueCount: 0,
          ),
        ),
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(repository.feedbackRequests, [7]);
      expect(find.text('AI 봇 · 초보'), findsOneWidget);
      // The character card comes with the form report (A10).
      expect(find.byType(ResultCoachCard), findsOneWidget);
      routes.settings.clear();
      await tester.tap(find.text('자세 기록 표로 보기'));
      await tester.pumpAndSettle();
      expect(routes.names, [GymRatsApp.feedbackRoute]);
      expect(routes.settings.single.arguments, same(report));
    });

    for (final myScore in [240, null]) {
      testWidgets(
        'a past battle ${myScore == null ? 'without a score '
                  'leaves the latest battles out' : 'with a score is compared '
                  'with the battles before it'}',
        (tester) async {
          final repository = FakeStatsUserRepository();
          repository.stats.points = [
            for (final (i, score) in const [80, 95, 110].indexed)
              statsPoint(100 + i, DateTime(2026, 10, 28 + i, 20), score: score),
          ];
          await openPast(
            tester,
            MatchRecord(
              id: 9,
              exercise: ExerciseType.pushUp,
              opponentName: 'RepBot',
              myReps: 12,
              opponentReps: 6,
              myScore: myScore,
              opponentScore: myScore == null ? null : 125,
              playedAt: _endedAt,
              isOnline: false,
            ),
            repository: repository,
          );
          await tester.pumpAndSettle();
          expect(
            find.byType(ResultRecentCard),
            myScore == null ? findsNothing : findsOneWidget,
          );
        },
      );
    }

    testWidgets('a battle just played: 다시 대결 takes only the report\'s '
        'place; the page under it stays', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 780)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final result = _result();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultScreen(
                              result: result,
                              createViewModel: () => ResultViewModel.battle(
                                result,
                                history: _earlier(),
                              ),
                            ),
                          ),
                        ),
                        child: const Text('under'),
                      ),
                    ),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text('${settings.name}')),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('under'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 대결'));
      await tester.pumpAndSettle();
      expect(find.text(GymRatsApp.matchingRoute), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('under'), findsOneWidget);
    });

    for (final (name, isOnline, route) in const [
      ('a past bot battle', false, GymRatsApp.matchingRoute),
      ('a past online battle', true, GymRatsApp.onlineBattleRoute),
    ]) {
      testWidgets('다시 대결 after $name opens $route from home', (tester) async {
        await openPast(
          tester,
          MatchRecord(
            exercise: ExerciseType.squat,
            opponentName: isOnline ? '진영' : BotDifficulty.beginner.opponentName,
            myReps: 5,
            opponentReps: 3,
            playedAt: _endedAt,
            isOnline: isOnline,
          ),
        );
        await tester.pumpAndSettle();
        routes.settings.clear();
        await tester.tap(find.text('다시 대결'));
        await tester.pumpAndSettle();
        expect(routes.names, [route]);
        final argument = routes.settings.single.arguments;
        if (isOnline) {
          expect(argument, ExerciseType.squat);
        } else {
          final request = argument! as BotMatchRequest;
          expect(request.exercise, ExerciseType.squat);
          expect(request.difficulty, BotDifficulty.beginner);
        }
        // It starts from home, as any battle: 기록보관소 is not left under it.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
        expect(find.text('archive'), findsNothing);
      });
    }
  });
}
