import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/screens/match_feedback_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/history_viewmodel.dart';
import 'package:gymrats_app/widgets/archive_cards.dart';
import 'package:gymrats_app/widgets/archive_match_row.dart';
import 'package:gymrats_app/widgets/lobby_parts.dart';
import 'package:provider/provider.dart';

import '../support/feedback_fakes.dart';
import '../support/fakes.dart';
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

  group('the page', () {
    testWidgets('back button, 03 / ARCHIVE, the slanted title, LOG behind', (
      tester,
    ) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.byTooltip('뒤로'), findsOneWidget);
      expect(find.text('03 / ARCHIVE'), findsOneWidget);
      expect(find.text('기록보관소'), findsOneWidget);
      expect(
        tester.widget<LobbyWatermark>(find.byType(LobbyWatermark)).word,
        'LOG',
      );
      expect(find.text('경기 기록'), findsNothing);
    });

    testWidgets('back returns to the previous screen', (tester) async {
      await open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('with values', () {
    testWidgets('the last 7 days, the growth and the newest three battles', (
      tester,
    ) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      // The last 7 days: battles 2-5 (15 + 18 + 20 + 24 reps); today and
      // yesterday in a row.
      expect(find.byType(ArchiveWeekCard), findsOneWidget);
      expect(find.text('77회  · 4판'), findsOneWidget);
      expect(find.text('2일 연속'), findsOneWidget);
      // Push-ups first: 80 -> 240 over four battles since 10/28.
      expect(find.byType(ArchiveGrowthCard), findsOneWidget);
      expect(find.text('160점'), findsOneWidget);
      expect(find.text('첫 기록 80점 → 최고 240점'), findsOneWidget);
      expect(find.text('10/28'), findsOneWidget);
      // The newest three, then 전체 보기 for the other two.
      expect(find.text('최근 경기'), findsOneWidget);
      expect(shownIds(tester), [5, 4, 3]);
      expect(find.text('전체 보기'), findsOneWidget);
      expect(find.text('푸쉬업 · KO 승'), findsOneWidget);
      expect(find.text('스쿼트 · 승리'), findsOneWidget);
      expect(find.text('푸쉬업 · 패배'), findsOneWidget);
      expect(find.text('vs RepBot 고수'), findsOneWidget);
      expect(find.text('온라인 vs test111'), findsOneWidget);
      expect(find.text('어제 21:05'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
      expect(find.text('490'), findsOneWidget);
    });

    testWidgets('the gain chip only on the battles that raised the best', (
      tester,
    ) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      final rows = tester
          .widgetList<ArchiveMatchRow>(find.byType(ArchiveMatchRow))
          .toList();
      expect([for (final row in rows) row.bestGain], [55, null, 35]);
      final chips = find.byKey(const ValueKey('archive-gain-chip'));
      expect(chips, findsNWidgets(2));
      expect(
        find.descendant(
          of: find.widgetWithText(ArchiveMatchRow, '스쿼트 · 승리'),
          matching: chips,
        ),
        findsNothing,
      );
      expect(find.text('55'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
    });

    testWidgets('the 스쿼트 tab switches the graph to squats', (tester) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '스쿼트'));
      await tester.pumpAndSettle();
      // One squat: its score only, no rise.
      expect(find.text('첫 기록 490점'), findsOneWidget);
      expect(find.text('160점'), findsNothing);
      expect(find.text('11/14'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '푸쉬업'));
      await tester.pumpAndSettle();
      expect(find.text('160점'), findsOneWidget);
    });

    testWidgets('an exercise never scored shows the short empty line', (
      tester,
    ) async {
      withBattles([
        for (final b in _battles)
          if (b.exercise == ExerciseType.pushUp) b,
      ]);
      await open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '스쿼트'));
      await tester.pumpAndSettle();
      expect(find.text('아직 점수 기록이 없어요'), findsOneWidget);
    });

    testWidgets('a quiet streak hides the chip', (tester) async {
      // Only the battle of 10/28: nothing in the last 7 days.
      withBattles([_battles.last]);
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.text('0회  · 0판'), findsOneWidget);
      expect(find.textContaining('연속'), findsNothing);
      expect(find.text('전체 보기'), findsNothing);
      expect(shownIds(tester), [1]);
    });

    testWidgets('fits a 360 x 780 phone down to the second battle; the page '
        'scrolls to the rest', (tester) async {
      withBattles();
      await open(tester, size: const Size(360, 780));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // As BArchive: header, both cards, 최근 경기 and two rows on screen.
      expect(
        tester.getBottomLeft(find.byType(ArchiveMatchRow).at(1)).dy,
        lessThanOrEqualTo(780),
      );
      await tester.scrollUntilVisible(
        find.byType(ArchiveMatchRow).at(2),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(ArchiveMatchRow).at(2), findsOneWidget);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('no overflow at ${scale}x text on a 360 wide phone', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        withBattles();
        await open(tester, size: const Size(360, 780));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('전체 보기'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('전체 보기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('without the summary', () {
    testWidgets('no statistics source: the cards hide, the battles show', (
      tester,
    ) async {
      final plain = FakeUserRepository()..historyPages = [_battles];
      await open(tester, using: plain);
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveWeekCard), findsNothing);
      expect(find.byType(ArchiveGrowthCard), findsNothing);
      expect(find.byType(ArchiveStatsRetry), findsNothing);
      expect(shownIds(tester), [5, 4, 3]);
      // No summary, so no gains either.
      expect(find.byKey(const ValueKey('archive-gain-chip')), findsNothing);
    });

    testWidgets('while the summary loads the cards are hidden', (tester) async {
      withBattles();
      repository.stats.gate = Completer();
      await open(tester);
      await tester.pumpAndSettle();
      expect(shownIds(tester), [5, 4, 3]);
      expect(find.byType(ArchiveWeekCard), findsNothing);
      expect(find.byType(ArchiveStatsRetry), findsNothing);

      repository.stats.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveWeekCard), findsOneWidget);
    });

    testWidgets('a failed summary: 다시 시도 in the cards\' place, the list '
        'stays, and the retry brings the cards', (tester) async {
      withBattles();
      repository.stats.error = Exception('offline');
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveStatsRetry), findsOneWidget);
      expect(find.byType(ArchiveWeekCard), findsNothing);
      expect(shownIds(tester), [5, 4, 3]);
      // Above the list, where the cards go.
      expect(
        tester.getTopLeft(find.byType(ArchiveStatsRetry)).dy,
        lessThan(tester.getTopLeft(find.text('최근 경기')).dy),
      );

      repository.stats.error = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveStatsRetry), findsNothing);
      expect(find.byType(ArchiveWeekCard), findsOneWidget);
      expect(shownIds(tester), [5, 4, 3]);
    });
  });

  group('states', () {
    testWidgets('a new user sees the empty state, no cards', (tester) async {
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.text('아직 경기 기록이 없어요'), findsOneWidget);
      expect(find.text('첫 대결을 마치면 여기에 기록돼요.'), findsOneWidget);
      expect(find.byType(ArchiveMatchRow), findsNothing);
      expect(find.byType(ArchiveWeekCard), findsNothing);
      expect(find.text('최근 경기'), findsNothing);
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
      expect(find.byType(ArchiveStatsRetry), findsNothing);

      repository
        ..historyError = null
        ..historyPages = [
          [_record(30, 20)],
        ];
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveMatchRow), findsOneWidget);
    });
  });

  group('전체 보기', () {
    Future<void> openAll(WidgetTester tester) async {
      await tester.tap(find.text('전체 보기'));
      await tester.pumpAndSettle();
      expect(find.text('전체 경기'), findsOneWidget);
    }

    testWidgets('opens every battle on the same view model, with the gains', (
      tester,
    ) async {
      withBattles();
      await open(tester);
      await tester.pumpAndSettle();
      await openAll(tester);
      expect(shownIds(tester), [5, 4, 3, 2, 1]);
      expect(
        [
          for (final row in tester.widgetList<ArchiveMatchRow>(
            find.byType(ArchiveMatchRow),
          ))
            row.bestGain,
        ],
        [55, null, 35, 70, null],
      );
      // Not loaded again: one first page, one summary.
      expect(repository.historyCursors, [null]);
      expect(repository.stats.calls, hasLength(1));
      expect(find.text('03 / ARCHIVE'), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('기록보관소'), findsOneWidget);
      expect(shownIds(tester), [5, 4, 3]);
    });

    testWidgets('three battles or fewer and nothing older: no 전체 보기', (
      tester,
    ) async {
      withBattles(_battles.take(3).toList());
      await open(tester);
      await tester.pumpAndSettle();
      expect(shownIds(tester), [5, 4, 3]);
      expect(find.text('전체 보기'), findsNothing);
    });

    testWidgets('older pages left on the server: 전체 보기 even for one', (
      tester,
    ) async {
      repository.historyPages = [
        [_record(2, 1)],
        [_record(1, 1)],
      ];
      await open(tester);
      await tester.pumpAndSettle();
      // The archive itself never asks for the next page.
      expect(repository.historyCursors, [null]);
      expect(find.text('전체 보기'), findsOneWidget);
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
      await openAll(tester);
      // The first page fills the screen, so nothing more is asked yet.
      expect(repository.historyCursors, [null]);

      await tester.dragUntilVisible(
        find.byWidgetPredicate(
          (w) => w is ArchiveMatchRow && w.match.myReps == 1,
        ),
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(repository.historyCursors, [null, '1', '2']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a short first page asks for the next one right away', (
      tester,
    ) async {
      repository.historyPages = [
        [_record(2, 1)],
        [_record(1, 1)],
      ];
      await open(tester);
      await tester.pumpAndSettle();
      await openAll(tester);
      expect(repository.historyCursors, [null, '1']);
      expect(find.byType(ArchiveMatchRow), findsNWidgets(2));
    });

    testWidgets('a failed next page offers a retry under the list', (
      tester,
    ) async {
      repository
        ..historyPages = [
          [_record(2, 1)],
          [_record(1, 1)],
        ]
        ..nextPageError = Exception('offline');
      await open(tester);
      await tester.pumpAndSettle();
      await openAll(tester);
      expect(find.byType(ArchiveMatchRow), findsOneWidget);
      expect(find.text('더 불러오지 못했어요'), findsOneWidget);

      repository.nextPageError = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveMatchRow), findsNWidgets(2));
      expect(find.text('더 불러오지 못했어요'), findsNothing);
    });
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

    testWidgets('a row with feedback opens it; one without does nothing', (
      tester,
    ) async {
      repository
        ..historyPages = [
          [withFeedback(2), _record(9, 9, day: 14)],
        ]
        ..feedbackError = Exception('offline');
      await open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ArchiveMatchRow).last);
      await tester.pumpAndSettle();
      expect(find.byType(MatchFeedbackScreen), findsNothing);
      await tester.tap(find.byType(ArchiveMatchRow).first);
      await tester.pumpAndSettle();
      expect(find.byType(MatchFeedbackScreen), findsOneWidget);
      expect(repository.feedbackRequests, [2]);
    });

    testWidgets('the full list opens feedback the same way', (tester) async {
      repository.historyPages = [
        [for (var id = 4; id >= 1; id--) withFeedback(id)],
      ];
      await open(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ArchiveMatchRow).last);
      await tester.pumpAndSettle();
      expect(find.byType(MatchFeedbackScreen), findsOneWidget);
      expect(repository.feedbackRequests, [1]);
    });
  });
}
