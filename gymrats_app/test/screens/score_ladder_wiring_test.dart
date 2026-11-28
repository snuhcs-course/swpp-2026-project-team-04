// How the A15 rank ladder is wired into the screens it does not own: the
// online battle screen reads the weekly ranking once when `match.start` sets
// the start (not for a friend battle) and hands it to the result without
// waiting for it; the result screen makes the ladder's view model only for a
// ranked battle with the app's RankingsRepository, and gives it to the
// victory scene and the seat. The battle harness follows
// online_preparation_test.dart's.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/ranking_ladder.dart';
import 'package:gymrats_app/screens/online_battle_screen.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_camera_view.dart';
import 'package:gymrats_app/widgets/victory_ladder.dart';
import 'package:gymrats_app/widgets/victory_overlay.dart';
import 'package:provider/provider.dart';

import '../services/pose/person_behind_test_support.dart';
import '../support/fakes.dart';
import '../support/placed_phone.dart';
import '../support/pose_fixtures.dart';

/// A session in preparation; the server's messages are set by hand.
class _Session extends OnlineBattleSession {
  _Session({required this.now})
    : super(
        endpoint: Uri.parse('wss://example.com/ws/v1/battle'),
        accessToken: 'test-only',
        character: 'bear',
      ) {
    playerId = 'me';
    connected = true;
    phase = OnlinePhase.preparing;
    opponent = const OnlinePlayer('opponent', '상대사용자', 'seal');
  }

  final int Function() now;

  @override
  int get serverNow => now();

  @override
  void ready(bool value) {}

  @override
  Future<void> leave() async {}

  /// `match.start`: the server sets the start [inMs] from now.
  void scheduleStart({int inMs = 3000}) {
    phase = OnlinePhase.scheduled;
    readyPlayers = {'me', 'opponent'};
    startAtMs = serverNow + inMs;
    endAtMs = startAtMs! + durationMs;
    notifyListeners();
  }
}

/// The weekly ranking: [answer] for every read (a ranking, an error to
/// throw, or null for an answer that never comes).
class _Rankings implements RankingsRepository {
  _Rankings(this.answer);

  final Object? answer;
  final reads = <RankingKey>[];

  @override
  Future<WeeklyRanking> fetchWeekly(RankingScope scope, ExerciseType exercise) {
    reads.add((scope, exercise));
    return switch (answer) {
      final WeeklyRanking ranking => Future.value(ranking),
      null => Completer<WeeklyRanking>().future,
      final error => Future.error(error),
    };
  }
}

final _ranking = WeeklyRanking(
  scope: RankingScope.global,
  weekStart: DateTime.utc(2026, 11, 22, 15),
  weekEnd: DateTime.utc(2026, 11, 29, 15),
  entries: const [
    RankingEntry(
      rank: 1,
      userId: 9,
      nickname: '우현',
      points: 19,
      battles: 4,
      wins: 2,
      koWins: 1,
      isMe: true,
    ),
  ],
  me: const RankingEntry(
    rank: 1,
    userId: 9,
    nickname: '우현',
    points: 19,
    battles: 4,
    wins: 2,
    koWins: 1,
    isMe: true,
  ),
);

Map<String, dynamic> _timeUpWin() => {
  'result_id': 'r' * 32,
  'reason': 'time_up',
  'players': [
    {'player_id': 'me', 'outcome': 'win'},
    {'player_id': 'opponent', 'outcome': 'loss'},
  ],
};

BattleResult _battle({required bool ranked, RankingSnapshot? before}) =>
    BattleResult(
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '나',
        opponent: Opponent(name: '상대', isBot: false),
      ),
      myReps: 10,
      myInvalidReps: 0,
      opponentReps: 6,
      myScore: 120,
      opponentScore: 80,
      end: GameEnd.ko,
      decidedOutcome: MatchOutcome.win,
      endedAt: DateTime.utc(2026, 11, 29),
      ranked: ranked,
      rankingBefore: before,
    );

void main() {
  group('the online battle screen', () {
    late _Session session;
    late FakeCameraService camera;
    late FakePoseEstimator estimator;
    late List<BattleResult> results;
    PoseFrame? streamPose;

    PoseFrame setupPose() {
      final overlays = find.byType(BattleGuideOverlay).evaluate();
      final share = overlays.isEmpty
          ? null
          : (overlays.single.widget as BattleGuideOverlay).share;
      return alignedPushUpSetupFrame(
        crop: share == null
            ? const Size(1, 1)
            : Size(share.width, share.height),
      );
    }

    Future<void> open(
      WidgetTester tester,
      RankingsRepository? rankings, {
      String? friendId,
    }) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      session = _Session(
        now: () => tester.binding.clock.now().millisecondsSinceEpoch,
      )..friendId = friendId;
      addTearDown(session.dispose);
      camera = FakeCameraService();
      estimator = FakePoseEstimator();
      streamPose = null;
      results = [];
      final clockStart = tester.binding.clock.now();
      final counter = RepCounterViewModel(
        camera: camera,
        estimator: estimator,
        judge: FakeRepJudge(),
        phoneTilt: placedPhone(),
        enablePersonGuard: false,
        clock: () => tester.binding.clock.now().difference(clockStart),
        roundLength: const Duration(days: 1),
      );
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        Provider<RankingsRepository?>.value(
          value: rankings,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: AppTheme.light,
            home: const Scaffold(body: Text('로비')),
            onGenerateRoute: (settings) =>
                settings.name == GymRatsApp.resultRoute
                ? MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) {
                      results.add(settings.arguments! as BattleResult);
                      return const Scaffold(body: Text('결과 화면'));
                    },
                  )
                : null,
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => OnlineBattleScreen(
              session: session,
              formReports: InMemoryFormReportStore(),
              createCounter: () => counter,
              playerName: '우현',
              setupClock: () =>
                  tester.binding.clock.now().difference(clockStart),
              setupConfig: const SetupConfig(
                readyDelay: Duration.zero,
                dropDelay: Duration.zero,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> wait(WidgetTester tester, int ms) async {
      for (var left = ms; left > 0; left -= 50) {
        if (streamPose case final current? when camera.isStreaming) {
          estimator.frames.add(freshPose(current));
          camera.emit();
          await tester.pump();
        }
        await tester.pump(Duration(milliseconds: left < 50 ? left : 50));
      }
    }

    Future<void> pose(WidgetTester tester) async {
      streamPose = setupPose();
      estimator.frames.add(streamPose);
      camera.emit();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    }

    /// Plays a round to its time-up win and opens the result with 결과 보기.
    Future<BattleResult> playToResult(WidgetTester tester) async {
      session.rules = battleRules;
      await pose(tester);
      session
        ..durationMs = 30000
        ..startAtMs = session.serverNow - 100
        ..endAtMs = session.serverNow + 29900
        ..phase = OnlinePhase.playing
        ..notifyListeners();
      await tester.pump();
      await pose(tester);
      session
        ..phase = OnlinePhase.finished
        ..result = _timeUpWin()
        ..notifyListeners();
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await wait(tester, 2400);
      await tester.tap(find.text('결과 보기'));
      await wait(tester, 400);
      expect(find.text('결과 화면'), findsOneWidget);
      return results.single;
    }

    testWidgets('reads the global ranking once, when match.start sets the '
        'start', (tester) async {
      final rankings = _Rankings(_ranking);
      await open(tester, rankings);
      session.notifyListeners();
      await tester.pump();
      expect(rankings.reads, isEmpty);
      session.scheduleStart();
      await tester.pump();
      expect(rankings.reads, [(RankingScope.global, ExerciseType.pushUp)]);
      // Later messages do not read it again.
      session.notifyListeners();
      await tester.pump();
      session
        ..phase = OnlinePhase.playing
        ..notifyListeners();
      await tester.pump();
      expect(rankings.reads, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a friend battle reads no ranking and is not ranked', (
      tester,
    ) async {
      final rankings = _Rankings(_ranking);
      await open(tester, rankings, friendId: '7');
      session.scheduleStart();
      await tester.pump();
      expect(rankings.reads, isEmpty);
      final result = await playToResult(tester);
      expect(result.ranked, isFalse);
      expect(result.rankingBefore, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the ranking read before goes with the result', (tester) async {
      final rankings = _Rankings(_ranking);
      await open(tester, rankings);
      session.scheduleStart();
      await tester.pump();
      final result = await playToResult(tester);
      expect(result.ranked, isTrue);
      expect(result.rankingBefore!.me!.points, 19);
      expect(result.rankingBefore!.me!.battles, 4);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (name, answer) in [
      ('fails', Exception('offline')),
      ('never comes', null),
    ]) {
      testWidgets('the result opens at once when the ranking $name', (
        tester,
      ) async {
        final rankings = _Rankings(answer);
        await open(tester, rankings);
        session.scheduleStart();
        await tester.pump();
        expect(rankings.reads, hasLength(1));
        final result = await playToResult(tester);
        expect(result.ranked, isTrue);
        expect(result.rankingBefore, isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('without the app\'s rankings nothing is read', (tester) async {
      await open(tester, null);
      session.scheduleStart();
      await tester.pump();
      final result = await playToResult(tester);
      expect(result.ranked, isTrue);
      expect(result.rankingBefore, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the result screen', () {
    Future<void> open(
      WidgetTester tester,
      BattleResult result, {
      RankingsRepository? rankings,
      bool provide = true,
    }) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = MaterialApp(
        theme: AppTheme.light,
        home: ResultScreen(result: result),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(),
        ),
      );
      await tester.pumpWidget(
        provide
            ? Provider<RankingsRepository?>.value(value: rankings, child: app)
            : app,
      );
      await tester.pump();
      await tester.pump();
    }

    final before = RankingSnapshot(
      entries: const [],
      me: (userId: 9, nickname: '우현', points: 19, rank: 1, battles: 4),
    );

    testWidgets('a ranked battle gets the ladder in its scene and its seat', (
      tester,
    ) async {
      final rankings = _Rankings(_ranking);
      await open(
        tester,
        _battle(ranked: true, before: before),
        rankings: rankings,
      );
      final overlay = tester.widget<VictoryOverlay>(
        find.byType(VictoryOverlay),
      );
      expect(overlay.ladder, isNotNull);
      expect(overlay.ladder!.ranked, isTrue);
      expect(overlay.ladder!.before, same(before));
      expect(overlay.ladder!.points, RankingPoints.koWin);
      expect(rankings.reads, [(RankingScope.global, ExerciseType.pushUp)]);
      await tester.pumpAndSettle();
      final seat = tester.widget<VictorySeat>(find.byType(VictorySeat));
      expect(seat.ladder, same(overlay.ladder));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a battle that is not ranked gets no ladder and reads '
        'nothing', (tester) async {
      final rankings = _Rankings(_ranking);
      await open(tester, _battle(ranked: false), rankings: rankings);
      expect(
        tester.widget<VictoryOverlay>(find.byType(VictoryOverlay)).ladder,
        isNull,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<VictorySeat>(find.byType(VictorySeat)).ladder,
        isNull,
      );
      expect(rankings.reads, isEmpty);
    });

    testWidgets('a ranked battle without the ranking before plays as before: '
        'no read, the old end, no chip', (tester) async {
      final rankings = _Rankings(_ranking);
      await open(tester, _battle(ranked: true), rankings: rankings);
      final playing = find.byWidgetPredicate(
        (widget) => widget is VictoryOverlay && widget.play,
      );
      final overlay = tester.widget<VictoryOverlay>(playing);
      expect(overlay.ladder, isNotNull);
      for (var t = 0; t < 1900; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(overlay.ladder!.path, LadderPath.none);
      expect(playing, findsOneWidget);
      // The KO win's scene ends at 2.1 s, without the hold.
      for (var t = 0; t < 300; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(playing, findsNothing);
      expect(rankings.reads, isEmpty);
      expect(find.byType(VictoryRankChip), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (name, provide) in [
      ('no RankingsRepository Provider', false),
      ('a null RankingsRepository', true),
    ]) {
      testWidgets('with $name a ranked battle plays as before', (tester) async {
        await open(
          tester,
          _battle(ranked: true, before: before),
          provide: provide,
        );
        expect(
          tester.widget<VictoryOverlay>(find.byType(VictoryOverlay)).ladder,
          isNull,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<VictorySeat>(find.byType(VictorySeat)).ladder,
          isNull,
        );
      });
    }
  });
}
