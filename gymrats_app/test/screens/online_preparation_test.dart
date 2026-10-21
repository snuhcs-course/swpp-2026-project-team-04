import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/screens/online_battle_screen.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/screens/feedback_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/pose_avatar_toggle_view.dart';
import 'package:gymrats_app/widgets/battle_score_balance.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';

import '../support/fakes.dart';
import '../support/flow_snapshot.dart';
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
  @override
  void ready(bool value) {
    if (!canReady) return;
    readyRequests.add(value);
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

  Future<void> open(WidgetTester tester, {bool denied = false}) async {
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
      judge: FakeRepJudge(),
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
    expect(tester.takeException(), isNull);
    await captureFlowSnapshot('online-battle-live-indicators');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
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

  /// Plays a short online round and ends it with the server's [result].
  Future<void> finishRound(
    WidgetTester tester,
    Map<String, dynamic> result,
  ) async {
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
    session.result = result;
    session.notifyListeners();
    await tester.pumpAndSettle();
    session.notifyListeners();
    await tester.pumpAndSettle();
  }

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
