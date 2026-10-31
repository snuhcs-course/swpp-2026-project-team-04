import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/screens/online_battle_screen.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/screens/feedback_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/pose_avatar_toggle_view.dart';
import 'package:gymrats_app/widgets/battle_score_balance.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/game_danger_edge.dart';
import 'package:gymrats_app/widgets/game_fever_chip.dart';
import 'package:gymrats_app/widgets/game_health_bar.dart';

import '../support/fakes.dart';
import '../support/flow_snapshot.dart';
import '../support/game_fakes.dart';
import '../support/pose_fixtures.dart';
import '../support/placed_phone.dart';

class _Session extends OnlineBattleSession {
  _Session()
    : super(
        endpoint: Uri.parse('wss://example.com/ws/v1/battle'),
        accessToken: 'test-only',
        avatar: AvatarModel.humanoid,
      ) {
    playerId = 'me';
    connected = true;
    phase = OnlinePhase.preparing;
    opponent = const OnlinePlayer('opponent', '상대사용자', AvatarModel.robot);
  }
  final readyRequests = <bool>[];

  /// False: the server has not answered ready yet (a slow confirmation).
  bool confirmReady = true;
  @override
  void ready(bool value) {
    if (!canReady) return;
    readyRequests.add(value);
    if (!confirmReady) return;
    if (value) {
      readyPlayers.add(playerId!);
    } else {
      readyPlayers.remove(playerId);
    }
    notifyListeners();
  }

  void scheduleStart() {
    phase = OnlinePhase.scheduled;
    startAtMs = serverNow + 3000;
    endAtMs = startAtMs! + durationMs;
    notifyListeners();
  }
}

void main() {
  late _Session session;
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late RepCounterViewModel counter;
  late PhoneTiltMonitor phone;
  late InMemoryFormReportStore reports;
  late FakeUserRepository repository;

  Future<void> open(
    WidgetTester tester, {
    bool denied = false,
    RepJudge? judge,
  }) async {
    await prepareFlowSnapshotFonts(tester);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    session = _Session();
    addTearDown(session.dispose);
    camera = FakeCameraService();
    if (denied) camera.permission = CameraPermission.denied;
    estimator = FakePoseEstimator();
    phone = placedPhone();
    reports = InMemoryFormReportStore();
    repository = FakeUserRepository();
    counter = RepCounterViewModel(
      camera: camera,
      estimator: estimator,
      judge: judge ?? FakeRepJudge(),
      phoneTilt: phone,
      roundLength: const Duration(days: 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnlineBattleScreen(
          session: session,
          formReports: reports,
          userRepository: repository,
          createCounter: () => counter,
          setupConfig: const SetupConfig(
            readyDelay: Duration.zero,
            dropDelay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Plays a short online round and ends it with the server's [result],
  /// [endedAfterMs] into the round if given.
  Future<void> finishRound(
    WidgetTester tester,
    Map<String, dynamic> result, {
    int? endedAfterMs,
  }) async {
    session.durationMs = 30000;
    session.startAtMs = session.serverNow - 100;
    session.endAtMs = session.serverNow + 29900;
    session.phase = OnlinePhase.playing;
    session.notifyListeners();
    await tester.pump();
    estimator.frames.add(standingFrame());
    camera.emit();
    await tester.pump();
    session.phase = OnlinePhase.finished;
    session.result = {
      ...result,
      if (endedAfterMs != null)
        'ended_at_ms': session.startAtMs! + endedAfterMs,
    };
    session.notifyListeners();
    await tester.pumpAndSettle();
    session.notifyListeners();
    await tester.pumpAndSettle();
  }

  testWidgets('online battle uses server score ratio and chest HUD', (
    tester,
  ) async {
    await open(tester);
    session.startAtMs = session.serverNow - 100;
    session.endAtMs = session.serverNow + 29900;
    session.phase = OnlinePhase.playing;
    session.myReps = 3;
    session.opponentReps = 2;
    session.notifyListeners();
    estimator.frames.add(standingFrame());
    camera.emit();
    await tester.pumpAndSettle();
    expect(find.byType(ChestHeightOverlay), findsOneWidget);
    final balance = tester.widget<BattleScoreBalance>(
      find.byType(BattleScoreBalance),
    );
    expect(balance.mine, 3);
    expect(balance.theirs, 2);
    expect(find.text('나 60%'), findsOneWidget);
    // An older server has no game: the reps are the score.
    expect(find.text('나  3'), findsOneWidget);
    expect(find.byType(GameHealthBar), findsNothing);
    expect(find.byType(GameFeverChip), findsNothing);
    expect(tester.takeException(), isNull);
    await captureFlowSnapshot('online-battle-live-indicators');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  group('with the game', () {
    Color? clockColor(WidgetTester tester, int seconds) =>
        tester.widget<Text>(find.text('$seconds초')).style?.color;

    bool edgeActive(WidgetTester tester) =>
        tester.widget<GameDangerEdge>(find.byType(GameDangerEdge)).active;

    /// A round running for [elapsedMs], with [leftMs] left.
    Future<void> play(
      WidgetTester tester, {
      int elapsedMs = 100,
      int leftMs = 15000,
    }) async {
      session.rules = battleRules;
      session.startAtMs = session.serverNow - elapsedMs;
      session.endAtMs = session.serverNow + leftMs;
      session.phase = OnlinePhase.playing;
      session.notifyListeners();
      await tester.pump();
    }

    testWidgets('scores, valid reps, the bar, and +N come from the session', (
      tester,
    ) async {
      await open(tester);
      await play(tester);
      session.myReps = 3;
      session.opponentReps = 2;
      session.myScore = 45;
      session.opponentScore = 20;
      session.myLastScore = const GameRepScore(
        grade: GameGrade.excellent,
        combo: 1,
        fever: false,
        points: 15,
      );
      session.notifyListeners();
      estimator.frames.add(standingFrame());
      camera.emit();
      await tester.pumpAndSettle();
      expect(find.text('나  45'), findsOneWidget);
      expect(find.text('20  상대'), findsOneWidget);
      expect(find.text('유효 3회'), findsOneWidget);
      expect(find.text('유효 2회'), findsOneWidget);
      expect(find.byType(BattleScoreBalance), findsNothing);
      final bar = tester.widget<GameHealthBar>(find.byType(GameHealthBar));
      expect(bar.myShare, closeTo(.625, 1e-9));
      expect(bar.myLastScore, same(session.myLastScore));
      expect(find.text('나 63%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the clock is lime, cyan with the chip in fever, then amber', (
      tester,
    ) async {
      await open(tester);
      await play(tester, elapsedMs: 15000, leftMs: 14500);
      expect(clockColor(tester, 15), AppColors.accent);
      expect(find.byType(GameFeverChip), findsNothing);
      await play(tester, elapsedMs: 21000, leftMs: 8500);
      expect(clockColor(tester, 9), AppColors.fever);
      expect(find.text('FEVER ×2'), findsOneWidget);
      await play(tester, elapsedMs: 26000, leftMs: 3500);
      expect(clockColor(tester, 4), AppColors.warning);
      expect(find.byType(GameFeverChip), findsOneWidget);
      // Over in fever time: the chip goes with the round.
      session.phase = OnlinePhase.finished;
      session.result = {'reason': 'ko', 'ended_at_ms': session.serverNow};
      session.notifyListeners();
      await tester.pump();
      expect(find.byType(GameFeverChip), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    /// Lets the judge's queued rep close on the next frame.
    Future<void> closeRep(WidgetTester tester) async {
      estimator.frames.add(standingFrame());
      camera.emit();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('each rep says its words at once, without the server: the '
        'grade and +N, or the reason in Korean', (tester) async {
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester);
      judge.closeRep(maxDepth: 1.9);
      await closeRep(tester);
      expect(find.text('+15 EXCELLENT'), findsOneWidget);
      judge.closeRep(reason: RejectReason.insufficientDepth);
      await closeRep(tester);
      expect(find.text('가슴을 더 내려요'), findsOneWidget);
      expect(find.text('+15 EXCELLENT'), findsNothing);
      judge.closeRep(maxDepth: 1.4);
      await closeRep(tester);
      expect(find.text('+10 GOOD'), findsOneWidget);
      // Nothing was answered: the score still waits for the server.
      expect(session.myScore, 0);
      expect(find.text('나  0'), findsOneWidget);
      session.myLastScore = const GameRepScore(
        grade: GameGrade.excellent,
        combo: 3,
        fever: true,
        points: 40,
      );
      session.notifyListeners();
      await tester.pump();
      expect(find.text('+40 EXCELLENT · 콤보 3 · 점수 2배'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('an average rep says its reason and its points, and only that '
        'rep does', (tester) async {
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester);
      judge.closeRep(
        reason: RejectReason.insufficientDepth,
        minElbowAngle: 120,
      );
      await closeRep(tester);
      expect(find.text('가슴을 더 내려요 · +5 AVERAGE'), findsOneWidget);

      // The latest score is still the average one.
      judge.closeRep(
        reason: RejectReason.insufficientDepth,
        minElbowAngle: 121,
      );
      await closeRep(tester);
      expect(find.text('가슴을 더 내려요'), findsOneWidget);
      judge.closeRep(reason: RejectReason.kneesDown, minElbowAngle: 90);
      await closeRep(tester);
      expect(find.text('무릎을 바닥에서 떼요'), findsOneWidget);
      expect(find.textContaining('AVERAGE'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a server without Average has no points for that rep', (
      tester,
    ) async {
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester);
      session.rules = const BattleRules(averagePoints: 0);
      judge.closeRep(reason: RejectReason.insufficientDepth, minElbowAngle: 90);
      await closeRep(tester);
      expect(find.text('가슴을 더 내려요'), findsOneWidget);
      expect(session.myLastScore, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets("the result counts the user's grades", (tester) async {
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester);
      judge.closeRep(maxDepth: 1.9);
      await closeRep(tester);
      judge.closeRep(maxDepth: 1.4);
      await closeRep(tester);
      judge.closeRep(reason: RejectReason.insufficientDepth, minElbowAngle: 90);
      await closeRep(tester);
      judge.closeRep(reason: RejectReason.kneesDown, minElbowAngle: 90);
      await closeRep(tester);
      await finishRound(tester, {
        'result_id': 'r' * 32,
        'reason': 'time_up',
        'players': [
          {'player_id': 'me', 'outcome': 'win'},
          {'player_id': 'opponent', 'outcome': 'loss'},
        ],
      });
      expect(find.text('Excellent 1 · Good 1 · Average 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets("the result's grades go by the server's rules and the "
        "counter's pass depth", (tester) async {
      final judge = DepthRepJudge(
        config: const RepJudgeConfig(bottomDepth: .75),
      );
      await open(tester, judge: judge);
      await play(tester);
      // A server without Average: this rep earned nothing.
      session.rules = const BattleRules(averagePoints: 0);
      judge.closeRep(reason: RejectReason.insufficientDepth, minElbowAngle: 90);
      await closeRep(tester);
      // 1.6 x 0.75: a push-up at this depth would only be good.
      judge.closeRep(maxDepth: 1.2);
      await closeRep(tester);
      await finishRound(tester, {
        'result_id': 'r' * 32,
        'reason': 'time_up',
        'players': [
          {'player_id': 'me', 'outcome': 'win'},
          {'player_id': 'opponent', 'outcome': 'loss'},
        ],
      });
      expect(find.text('Excellent 1 · Good 0 · Average 0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets("a rep's grade goes by the counter's pass depth", (
      tester,
    ) async {
      final judge = DepthRepJudge(
        config: const RepJudgeConfig(bottomDepth: .75),
      );
      await open(tester, judge: judge);
      await play(tester);
      // 1.6 x 0.75: a push-up at this depth would only be good.
      judge.closeRep(maxDepth: 1.2);
      await closeRep(tester);
      expect(find.text('+15 EXCELLENT'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('an older server has no words but +1', (tester) async {
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester);
      session.rules = null;
      judge.closeRep(maxDepth: 1.9);
      await closeRep(tester);
      expect(find.text('+1'), findsOneWidget);
      expect(session.myLastScore, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('on the largest system font the fever row does not overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester);
      await play(tester, elapsedMs: 21000, leftMs: 8500);
      session.myReps = 12;
      session.opponentReps = 14;
      session.notifyListeners();
      await tester.pump();
      expect(find.text('FEVER ×2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the danger edge is on 60 points behind, off once it ends', (
      tester,
    ) async {
      await open(tester);
      await play(tester);
      session.opponentScore = 59;
      session.notifyListeners();
      await tester.pump();
      expect(edgeActive(tester), isFalse);
      session.opponentScore = 60;
      session.notifyListeners();
      await tester.pump();
      expect(edgeActive(tester), isTrue);
      session.phase = OnlinePhase.finished;
      session.result = {'reason': 'time_up', 'ended_at_ms': session.serverNow};
      session.notifyListeners();
      await tester.pump();
      expect(edgeActive(tester), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the danger edge is off while the camera has failed', (
      tester,
    ) async {
      await open(tester, denied: true);
      await play(tester);
      session.opponentScore = 60;
      session.notifyListeners();
      await tester.pump();
      expect(edgeActive(tester), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a KO says so, shows the scores, and keeps the report with '
        'the time played rounded up', (tester) async {
      await open(tester);
      session.rules = battleRules;
      session.myScore = 120;
      session.opponentScore = 20;
      session.myReps = 6;
      session.opponentReps = 2;
      await finishRound(tester, {
        'result_id': 'r' * 32,
        'reason': 'ko',
        'players': [
          {'player_id': 'me', 'outcome': 'win'},
          {'player_id': 'opponent', 'outcome': 'loss'},
        ],
      }, endedAfterMs: 23400);
      expect(find.text('승리'), findsOneWidget);
      expect(find.text('K.O.로 끝났어요.'), findsOneWidget);
      expect(find.text('점수 120 : 20 · 유효 6 : 2'), findsOneWidget);
      final report = (await reports.list()).single;
      expect(report.roundLength, const Duration(seconds: 24));
      expect(repository.savedFeedback.single.$1, 'r' * 32);
      expect(find.text('자세 피드백 보기'), findsOneWidget);
      // 6.6 s were left at the KO. The clock stays there, in a plain color.
      Text clock() => tester.widget<Text>(find.text('7초'));
      expect(
        clock().style?.color,
        isNot(anyOf(AppColors.accent, AppColors.fever, AppColors.warning)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      session.notifyListeners();
      await tester.pump();
      expect(find.text('7초'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  testWidgets('online setup requires a propped and still phone', (
    tester,
  ) async {
    await open(tester);
    phone.isPropped = false;
    estimator.frames.add(standingFrame());
    camera.emit();
    await tester.pumpAndSettle();
    expect(find.text('폰을 더 세워 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
          .onPressed,
      isNull,
    );
    phone.isPropped = true;
    phone.isStill = false;
    estimator.frames.add(standingFrame());
    camera.emit();
    await tester.pumpAndSettle();
    expect(find.text('폰이 흔들리지 않게 두세요.'), findsOneWidget);
    phone.isStill = true;
    estimator.frames.add(standingFrame());
    camera.emit();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(session.readyRequests, [true]);
    phone.isStill = false;
    estimator.frames.add(standingFrame());
    camera.emit();
    await tester.pumpAndSettle();
    expect(session.readyRequests, [true, false]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  testWidgets('a failed feedback upload still shows the result and feedback', (
    tester,
  ) async {
    await open(tester);
    repository.feedbackSaveError = Exception('offline');
    await finishRound(tester, {
      'result_id': 'r' * 32,
      'reason': 'time_up',
      'ended_at_ms': 1792400000000,
    });
    expect(await reports.list(), hasLength(1));
    expect(find.text('자세 피드백 보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a result without a result id uploads nothing', (tester) async {
    await open(tester);
    await finishRound(tester, {
      'reason': 'time_up',
      'ended_at_ms': 1792400000000,
    });
    expect(await reports.list(), hasLength(1));
    expect(repository.savedFeedback, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('completed online round saves feedback once and opens it', (
    tester,
  ) async {
    await open(tester);
    await finishRound(tester, {
      'result_id': 'r' * 32,
      'reason': 'time_up',
      'ended_at_ms': 1792400000000,
    });
    expect(await reports.list(), hasLength(1));
    final report = (await reports.list()).single;
    // Uploaded once, under the battle server's result id.
    expect(repository.savedFeedback, hasLength(1));
    expect(repository.savedFeedback.single.$1, 'r' * 32);
    expect(repository.savedFeedback.single.$2, same(report));
    expect(repository.saved, isEmpty);
    expect(report.roundLength, const Duration(seconds: 30));
    expect(report.opponentName, '상대사용자');
    expect(report.samples, isNotEmpty);
    await tester.tap(find.text('자세 피드백 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'same full-screen setup blocks Start until valid pose; ready waits for server',
    (tester) async {
      await open(tester);
      expect(find.byType(PoseSetupTopButtons), findsOneWidget);
      expect(find.byType(PoseSetupPanel), findsOneWidget);
      expect(find.byType(PoseReadyBorder), findsOneWidget);
      expect(find.byType(PoseAvatarToggleView), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
            .onPressed,
        isNull,
      );
      estimator.frames.add(standingFrame());
      camera.emit();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(session.readyRequests, [true]);
      expect(find.text('상대 준비를 기다리는 중…'), findsOneWidget);
      expect(session.startAtMs, isNull);
      expect(counter.history, isEmpty);
      expect(counter.roundLength, const Duration(days: 1));
      await captureFlowSnapshot('online-ready-waiting');
      session.scheduleStart();
      await tester.pump();
      expect(find.textContaining('초 후 함께 시작'), findsOneWidget);
      await captureFlowSnapshot('online-countdown');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '경기 시작 대기'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  group('auto ready', () {
    Future<void> pose(WidgetTester tester, bool ready) async {
      estimator.frames.add(ready ? standingFrame() : emptyFrame());
      camera.emit();
      // Not pumpAndSettle: it moves the clock past the 3 seconds.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('a ready pose sends ready by itself after 3 seconds', (
      tester,
    ) async {
      await open(tester);
      await pose(tester, true);
      expect(find.textContaining('초 후 자동으로 준비해요'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2900));
      expect(session.readyRequests, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(session.readyRequests, [true]);
      await tester.pump();
      expect(find.text('상대 준비를 기다리는 중…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('losing the pose within 3 seconds cancels; it starts over', (
      tester,
    ) async {
      await open(tester);
      await pose(tester, true);
      await tester.pump(const Duration(seconds: 2));
      await pose(tester, false);
      expect(find.textContaining('초 후 자동으로 준비해요'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(session.readyRequests, isEmpty);
      // Ready again: a full new 3 seconds.
      await pose(tester, true);
      await tester.pump(const Duration(seconds: 2));
      expect(session.readyRequests, isEmpty);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(session.readyRequests, [true]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('after 준비 취소 it waits until the pose is found again', (
      tester,
    ) async {
      await open(tester);
      await pose(tester, true);
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(session.readyRequests, [true]);
      await tester.tap(find.text('준비 취소'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(session.readyRequests, [true, false]);
      await pose(tester, false);
      await pose(tester, true);
      await tester.pump(const Duration(milliseconds: 3100));
      expect(session.readyRequests, [true, false, true]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a slow confirmation does not send ready again', (
      tester,
    ) async {
      await open(tester);
      session.confirmReady = false;
      await pose(tester, true);
      await tester.pump(const Duration(milliseconds: 3100));
      expect(session.readyRequests, [true]);
      // More frames while the confirmation is on its way.
      for (var i = 0; i < 5; i++) {
        await pose(tester, true);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(session.readyRequests, [true]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Start during the countdown sends ready once', (tester) async {
      await open(tester);
      await pose(tester, true);
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(seconds: 4));
      expect(session.readyRequests, [true]);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets(
    'losing the valid pose revokes ready instead of starting the round',
    (tester) async {
      await open(tester);
      estimator.frames.add(standingFrame());
      camera.emit();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pump();
      estimator.frames.add(emptyFrame());
      camera.emit();
      await tester.pumpAndSettle();
      expect(session.readyRequests, [true, false]);
      expect(session.phase, OnlinePhase.preparing);
      expect(session.startAtMs, isNull);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'camera permission failure keeps setup and recovery controls visible',
    (tester) async {
      await open(tester, denied: true);
      expect(find.text('카메라 권한 또는 자세 인식을 확인해주세요.'), findsOneWidget);
      expect(find.text('카메라 다시 준비'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
            .onPressed,
        isNull,
      );
      expect(session.readyRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
