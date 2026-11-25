import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/hold_record.dart';
import 'package:gymrats_app/screens/hold_report_screen.dart';
import 'package:gymrats_app/services/feedback/hold_record_store.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/screens/feedback_stats_screen.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/history_viewmodel.dart';
import 'package:gymrats_app/widgets/archive_cards.dart';
import 'package:gymrats_app/widgets/archive_match_row.dart';
import 'package:gymrats_app/widgets/victory_overlay.dart';
import 'package:provider/provider.dart';

import '../support/feedback_fakes.dart';
import '../models/hold_record_test.dart' show holdRecord;
import '../support/fakes.dart';
import '../support/form_report_fixtures.dart';
import '../widgets/battle_test_support.dart';

/// Saturday 2026-11-14, 15:00.
final _now = DateTime(2026, 11, 14, 15);

MatchRecord _record(int mine, int theirs, {int day = 15}) => MatchRecord(
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: mine,
  opponentReps: theirs,
  playedAt: DateTime(2026, 10, day, 21, 5),
);

/// The five stored battles of the archive tests, newest first, and their
/// statistics points: three push-ups raising the best (by 70, 35, 55), one
/// squat (its first, so no gain) and the first push-up (no gain).
final _battles = [
  MatchRecord(
    id: 5,
    exercise: ExerciseType.pushUp,
    opponentName: 'RepBot 고수',
    myReps: 24,
    opponentReps: 12,
    myScore: 240,
    opponentScore: 125,
    playedAt: DateTime(2026, 11, 14, 14, 30),
    gameEnd: GameEnd.ko,
    isOnline: false,
  ),
  MatchRecord(
    id: 4,
    exercise: ExerciseType.squat,
    opponentName: 'test111',
    myReps: 20,
    opponentReps: 18,
    myScore: 490,
    opponentScore: 420,
    playedAt: DateTime(2026, 11, 14, 13, 42),
    gameEnd: GameEnd.timeUp,
    isOnline: true,
  ),
  MatchRecord(
    id: 3,
    exercise: ExerciseType.pushUp,
    opponentName: 'RepBot 보통',
    myReps: 18,
    opponentReps: 21,
    myScore: 185,
    opponentScore: 210,
    playedAt: DateTime(2026, 11, 13, 21, 5),
    gameEnd: GameEnd.timeUp,
    isOnline: false,
  ),
  MatchRecord(
    id: 2,
    exercise: ExerciseType.pushUp,
    opponentName: 'RepBot',
    myReps: 15,
    opponentReps: 9,
    myScore: 150,
    opponentScore: 90,
    playedAt: DateTime(2026, 11, 10, 20),
  ),
  MatchRecord(
    id: 1,
    exercise: ExerciseType.pushUp,
    opponentName: 'RepBot',
    myReps: 8,
    opponentReps: 6,
    myScore: 80,
    opponentScore: 60,
    playedAt: DateTime(2026, 10, 28, 20),
  ),
];

List<StatsPoint> _pointsOf(List<MatchRecord> battles) => [
  for (final b in battles)
    statsPoint(
      b.id!,
      b.playedAt!,
      reps: b.myReps,
      score: b.myScore,
      exercise: b.exercise,
    ),
];

void main() {
  // The app's fonts, so the archive measures as it does on a phone.
  setUpAll(loadBattleFonts);

  late FakeStatsUserRepository repository;

  setUp(() => repository = FakeStatsUserRepository());

  /// The archive over a home page, on a phone of [size], with the
  /// statistics repository or [using] (e.g. one without statistics).
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    UserRepository? using,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = using ?? repository;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserRepository>.value(value: repo),
          Provider<FormReportStore>.value(value: InMemoryFormReportStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('home')),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => HistoryScreen(
              createViewModel: () =>
                  HistoryViewModel(repository: repo, now: () => _now),
              now: () => _now,
            ),
          ),
          initialRoute: '/history',
        ),
      ),
    );
  }

  void withBattles([List<MatchRecord>? battles]) {
    final all = battles ?? _battles;
    repository
      ..historyPages = [all]
      ..stats.points = _pointsOf(all);
  }

  Iterable<int?> shownIds(WidgetTester tester) => tester
      .widgetList<ArchiveMatchRow>(find.byType(ArchiveMatchRow))
      .map((row) => row.match.id);

  Future<void> toMatches(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, '경기'));
    await tester.pumpAndSettle();
  }

  /// The tab's list, not the chips' row or the tab pages.
  final vertical = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );

  String? chartLabel(WidgetTester tester) {
    // The chart's label, not its title's: "경기별 점수: 150점, …".
    final label = find.bySemanticsLabel(RegExp(r'^경기별 [^:]*: '));
    if (label.evaluate().isEmpty) return null;
    return tester.getSemantics(label).label;
  }

  group('the page (P13, draft C)', () {
    testWidgets('back, the title 기록보관소 and the 전체 · 경기 tabs, 전체 '
        'first', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.byTooltip('뒤로'), findsOneWidget);
      expect(find.text('기록보관소'), findsOneWidget);
      expect(find.widgetWithText(Tab, '전체'), findsOneWidget);
      expect(find.widgetWithText(Tab, '경기'), findsOneWidget);
      expect(find.byType(ArchivePeriodPicker), findsOneWidget);
      expect(find.byType(ArchiveMatchRow), findsNothing);
    });

    testWidgets('back returns to the previous screen', (tester) async {
      await open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('전체 tab', () {
    testWidgets("this week's push-ups: battles, reps per battle, best "
        'score', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      // Saturday 11-14: the week from Monday 11-09 has three push-ups.
      expect(find.bySemanticsLabel('경기 3판'), findsOneWidget);
      expect(find.bySemanticsLabel('경기당 인정 19회'), findsOneWidget);
      expect(find.bySemanticsLabel('최고 점수 240점'), findsOneWidget);
      expect(chartLabel(tester), '경기별 점수: 150점, 185점, 240점');
    });

    testWidgets('전체 기간 and 스쿼트 change what is summed', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체 기간'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('경기 4판'), findsOneWidget);
      expect(find.bySemanticsLabel('경기당 인정 16.3회'), findsOneWidget);
      await tester.tap(find.text('스쿼트').first);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('경기 1판'), findsOneWidget);
      expect(find.bySemanticsLabel('최고 점수 490점'), findsOneWidget);
    });

    testWidgets('인정 횟수 turns the chart to the counted reps', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('인정 횟수'));
      await tester.pumpAndSettle();
      expect(chartLabel(tester), '경기별 인정 횟수: 15회, 18회, 24회');
      expect(find.text('경기별 인정 횟수'), findsOneWidget);
    });

    testWidgets('a period without battles says so, with no best', (
      tester,
    ) async {
      withBattles([_battles.last]);
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('경기 0판'), findsOneWidget);
      expect(find.bySemanticsLabel('최고 점수 –'), findsOneWidget);
      expect(find.text('이 기간에 기록된 경기가 없어요.'), findsOneWidget);
      expect(chartLabel(tester), isNull);
    });

    testWidgets('개인 최고 of both exercises, from every battle', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('개인 최고'),
        200,
        scrollable: vertical.first,
      );
      expect(
        find.bySemanticsLabel('푸쉬업 최고 240점, 인정 24회, 11.14'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('스쿼트 최고 490점, 인정 20회, 11.14'),
        findsOneWidget,
      );
    });

    testWidgets('자주 나온 자세 문제: the reject reasons of the period, most '
        'first; none says so', (tester) async {
      repository
        ..historyPages = [_battles]
        ..stats.points = [
          statsPoint(
            5,
            DateTime(2026, 11, 14, 9),
            score: 100,
            issues: {'reject.insufficientDepth': 4, 'reject.kneesDown': 1},
          ),
        ];
      await open(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('자주 나온 자세 문제'),
        200,
        scrollable: vertical.first,
      );
      expect(find.text('이번 주 무효 5회'), findsOneWidget);
      expect(find.text('4회'), findsOneWidget);
      expect(find.text('1회'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('스쿼트').first,
        -200,
        scrollable: vertical.first,
      );
      await tester.tap(find.text('스쿼트').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('자주 나온 자세 문제'),
        200,
        scrollable: vertical.first,
      );
      expect(find.text('이 기간에 무효 처리된 횟수가 없어요.'), findsOneWidget);
    });

    testWidgets('기간별 통계 자세히 보기 opens the statistics on the same '
        'clock', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('기간별 통계 자세히 보기'),
        200,
        scrollable: vertical.first,
      );
      await tester.ensureVisible(find.text('기간별 통계 자세히 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기간별 통계 자세히 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackStatsScreen), findsOneWidget);
      expect(find.text('이번 주 · 11/9 월 ~ 11/15 일'), findsOneWidget);
    });

    testWidgets('no statistics source: a note, no way into the statistics', (
      tester,
    ) async {
      final plain = FakeUserRepository()..historyPages = [_battles];
      await open(tester, using: plain);
      await tester.pumpAndSettle();
      expect(find.text('기간별 기록은 서버에 연결되어 있을 때 볼 수 있어요.'), findsOneWidget);
      expect(find.text('기간별 통계 자세히 보기'), findsNothing);
    });

    testWidgets('while the period loads a spinner; a failure offers 다시 '
        '시도', (tester) async {
      withBattles();
      repository.stats.gate = Completer<void>();
      await open(tester);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repository.stats
        ..error = const ApiException(ApiErrorKind.network)
        ..gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveStatsRetry), findsOneWidget);
      repository.stats
        ..gate = null
        ..error = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveStatsRetry), findsNothing);
      expect(find.bySemanticsLabel('경기 3판'), findsOneWidget);
    });
  });

  group('경기 tab', () {
    testWidgets('the battles by day: 오늘, 어제 and the date, each with its '
        'count', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await toMatches(tester);
      expect(find.text('오늘 · 11.14 (토)'), findsOneWidget);
      expect(find.text('어제 · 11.13 (금)'), findsOneWidget);
      expect(find.text('2경기'), findsOneWidget);
      expect(shownIds(tester).take(3), [5, 4, 3]);
    });

    testWidgets('a row: the result chip, the title, the time and kind, the '
        'score and reps', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await toMatches(tester);
      expect(find.text('KO승'), findsOneWidget);
      expect(find.text('푸쉬업 · vs RepBot 고수'), findsOneWidget);
      expect(find.text('14:30 · 아케이드'), findsOneWidget);
      expect(find.text('13:42 · 온라인'), findsOneWidget);
      expect(find.text('240 점', findRichText: true), findsOneWidget);
      expect(find.text('인정 24회'), findsOneWidget);
    });

    testWidgets('the chips: an exercise, 온라인 or 아케이드; 전체 shows all '
        'again', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await toMatches(tester);
      await tester.tap(find.text('스쿼트'));
      await tester.pumpAndSettle();
      expect(shownIds(tester), [4]);
      await tester.tap(find.text('온라인'));
      await tester.pumpAndSettle();
      expect(shownIds(tester), [4]);
      await tester.tap(find.text('아케이드'));
      await tester.pumpAndSettle();
      expect(shownIds(tester), [5, 3]);
      await tester.tap(find.text('전체').last);
      await tester.pumpAndSettle();
      expect(shownIds(tester).take(3), [5, 4, 3]);
    });

    testWidgets('a chip that leaves no battle says so', (tester) async {
      withBattles([_battles.first]);
      await open(tester);
      await tester.pumpAndSettle();
      await toMatches(tester);
      await tester.tap(find.text('온라인'));
      await tester.pumpAndSettle();
      expect(find.text('이 조건에 맞는 기록이 없어요.'), findsOneWidget);
    });

    testWidgets('the gain chip only on the battles that raised the best', (
      tester,
    ) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await toMatches(tester);
      await tester.scrollUntilVisible(
        find.byWidgetPredicate((w) => w is ArchiveMatchRow && w.match.id == 1),
        200,
        scrollable: vertical.last,
      );
      final gained = [
        for (final row in tester.widgetList<ArchiveMatchRow>(
          find.byType(ArchiveMatchRow),
        ))
          if (row.bestGain != null) row.match.id,
      ];
      expect(gained, [5, 3, 2]);
    });

    testWidgets('older battles load as the end of the list comes near', (
      tester,
    ) async {
      repository.historyPages = [
        for (var page = 0; page < 3; page++)
          [for (var i = 0; i < 20; i++) _record(60 - page * 20 - i, 5)],
      ];
      await open(tester);
      await tester.pumpAndSettle();
      await toMatches(tester);
      expect(repository.historyCursors, [null]);
      await tester.dragUntilVisible(
        find.byWidgetPredicate(
          (w) => w is ArchiveMatchRow && w.match.myReps == 1,
        ),
        find.byType(ListView).last,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(repository.historyCursors, [null, '1', '2']);
    });

    testWidgets('a short first page asks for the next one right away', (
      tester,
    ) async {
      repository.historyPages = [
        [_record(2, 1)],
        [_record(1, 1, day: 14)],
      ];
      await open(tester);
      await tester.pumpAndSettle();
      await toMatches(tester);
      expect(repository.historyCursors, [null, '1']);
      expect(find.byType(ArchiveMatchRow), findsNWidgets(2));
    });

    testWidgets('a failed next page offers a retry under the list', (
      tester,
    ) async {
      repository
        ..historyPages = [
          [_record(2, 1)],
          [_record(1, 1, day: 14)],
        ]
        ..nextPageError = Exception('offline');
      await open(tester);
      await tester.pumpAndSettle();
      await toMatches(tester);
      expect(find.byType(ArchiveMatchRow), findsOneWidget);
      expect(find.text('더 불러오지 못했어요'), findsOneWidget);
      repository.nextPageError = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveMatchRow), findsNWidgets(2));
    });
  });

  group('states', () {
    testWidgets('a new user sees the empty state, no tabs\' content', (
      tester,
    ) async {
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.text('아직 경기 기록이 없어요'), findsOneWidget);
      expect(find.text('첫 대결을 마치면 여기에 기록돼요.'), findsOneWidget);
      expect(find.byType(ArchiveMatchRow), findsNothing);
      expect(find.byType(ArchivePeriodPicker), findsNothing);
    });

    testWidgets('a spinner shows while loading', (tester) async {
      repository.historyGate = Completer();
      await open(tester);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('기록보관소'), findsOneWidget);
      repository.historyGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failure shows the reason and 다시 시도 works', (tester) async {
      repository.historyError = const ApiException(ApiErrorKind.network);
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);
      expect(
        find.text(const ApiException(ApiErrorKind.network).message),
        findsOneWidget,
      );
      repository
        ..historyError = null
        ..historyPages = [
          [_record(30, 20)],
        ];
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      await toMatches(tester);
      expect(find.byType(ArchiveMatchRow), findsOneWidget);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('no overflow at ${scale}x text on a 360 x 780 phone, on '
          'both tabs', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        withBattles();
        await open(tester, size: const Size(360, 780));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await toMatches(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  group('feedback', () {
    MatchRecord withFeedback(int id) => MatchRecord(
      id: id,
      exercise: ExerciseType.pushUp,
      opponentName: 'RepBot',
      myReps: 10,
      opponentReps: 5,
      playedAt: DateTime(2026, 10, 15, 21, id),
      feedbackSummary: const FeedbackSummary(
        validReps: 10,
        invalidReps: 1,
        issueCount: 0,
      ),
    );

    // Since W5 (team decision 2026-11-08): a row opens its battle's report,
    // with the victory scene's end look only; the report links to the
    // feedback when the battle has one.
    MatchRecord? shownRecord(WidgetTester tester) =>
        tester.widget<ResultScreen>(find.byType(ResultScreen)).record;

    void expectEndLookOnly(WidgetTester tester) {
      expect(find.byType(VictorySeat), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is VictoryOverlay && w.play),
        findsNothing,
      );
    }

    testWidgets('a row opens its battle\'s report, with the end look only: '
        'with feedback the report links to it; without, the report opens '
        'too', (tester) async {
      final without = _record(9, 9, day: 14);
      repository
        ..historyPages = [
          [withFeedback(2), without],
        ]
        ..reports = {2: sampleReport()};
      await open(tester);
      await tester.pumpAndSettle();
      await toMatches(tester);
      await tester.tap(find.byType(ArchiveMatchRow).last);
      await tester.pumpAndSettle();
      expect(shownRecord(tester), same(without));
      expectEndLookOnly(tester);
      expect(find.text('자세 기록 표로 보기'), findsNothing);
      expect(repository.feedbackRequests, isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ArchiveMatchRow).first);
      await tester.pumpAndSettle();
      expect(shownRecord(tester)!.id, 2);
      expectEndLookOnly(tester);
      expect(find.text('자세 기록 표로 보기'), findsOneWidget);
      expect(repository.feedbackRequests, [2]);
    });
  });
  group('holds (P13)', () {
    Future<void> openWithHolds(
      WidgetTester tester,
      List<HoldRecord> holds,
    ) async {
      final store = InMemoryHoldRecordStore();
      for (final h in holds) {
        await store.save(h);
      }
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserRepository>.value(value: repository),
            Provider<FormReportStore>.value(value: InMemoryFormReportStore()),
            Provider<HoldRecordStore>.value(value: store),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: HistoryScreen(now: () => _now),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a hold is a row of its day; it opens its report', (
      tester,
    ) async {
      withBattles();
      await openWithHolds(tester, [
        holdRecord(endedAt: DateTime(2026, 11, 14, 14, 50)),
      ]);
      await toMatches(tester);
      expect(find.text('3기록'), findsOneWidget);
      expect(find.byType(ArchiveHoldRow), findsOneWidget);
      await tester.tap(find.byType(ArchiveHoldRow));
      await tester.pumpAndSettle();
      expect(find.byType(HoldReportScreen), findsOneWidget);
    });

    testWidgets('버티기 lists only the holds', (tester) async {
      withBattles();
      await openWithHolds(tester, [
        holdRecord(endedAt: DateTime(2026, 11, 14, 14, 50)),
      ]);
      await toMatches(tester);
      // The last chip: it may need the row scrolled to it first.
      final chip = find.descendant(
        of: find.byType(ArchiveChips<ArchiveFilter>),
        matching: find.text('버티기'),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveMatchRow), findsNothing);
      expect(find.byType(ArchiveHoldRow), findsOneWidget);
    });

    testWidgets('the 전체 tab sums the holds of the period', (tester) async {
      withBattles();
      await openWithHolds(tester, [
        holdRecord(endedAt: DateTime(2026, 11, 14, 14, 50)),
      ]);
      await tester.scrollUntilVisible(
        find.byType(ArchiveHoldSummary),
        200,
        scrollable: vertical.first,
      );
      expect(find.bySemanticsLabel('횟수 1회'), findsOneWidget);
    });

    testWidgets('no hold: no 버티기 section', (tester) async {
      withBattles();
      await openWithHolds(tester, const []);
      expect(find.byType(ArchiveHoldSummary), findsNothing);
    });
  });
}
