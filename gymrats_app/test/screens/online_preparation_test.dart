import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/screens/battle_screen.dart'
    show BattleSetupListener;
import 'package:gymrats_app/screens/online_battle_screen.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_arena.dart';
import 'package:gymrats_app/widgets/battle_camera_view.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';
import 'package:gymrats_app/widgets/pose_silhouette_guide.dart';
import 'package:gymrats_app/widgets/squat_height_overlay.dart';

import '../support/fakes.dart';
import '../support/flow_snapshot.dart';
import '../support/game_fakes.dart';
import '../support/pose_fixtures.dart';
import '../support/placed_phone.dart';

class _Session extends OnlineBattleSession {
  _Session({super.exercise})
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
  final readyRequests = <bool>[];
  var leaves = 0;

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

  @override
  Future<void> leave() async {
    leaves++;
  }

  /// The server sets the start [inMs] from now.
  void scheduleStart({int inMs = 3000}) {
    phase = OnlinePhase.scheduled;
    readyPlayers = {'me', 'opponent'};
    startAtMs = serverNow + inMs;
    endAtMs = startAtMs! + durationMs;
    notifyListeners();
  }
}

/// Counts the routes put in another's place, by name.
class _Replacements extends NavigatorObserver {
  final names = <String?>[];
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    names.add(newRoute?.settings.name);
  }
}

/// The server's result of a battle the user won or lost by [reason].
Map<String, dynamic> _result(String reason, {String outcome = 'win'}) => {
  'result_id': 'r' * 32,
  'reason': reason,
  'players': [
    {'player_id': 'me', 'outcome': outcome},
    {
      'player_id': 'opponent',
      'outcome': switch (outcome) {
        'win' => 'loss',
        'loss' => 'win',
        _ => outcome,
      },
    },
  ],
};

void main() {
  late _Session session;
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late RepCounterViewModel counter;
  late PhoneTiltMonitor phone;
  late InMemoryFormReportStore reports;
  late FakeUserRepository repository;
  late List<BattleResult> results;
  late _Replacements replacements;

  Future<void> open(
    WidgetTester tester, {
    bool denied = false,
    RepJudge? judge,
    ExerciseType exercise = ExerciseType.pushUp,
    double textScale = 1,
    ValueChanged<BattleStageCue>? onCue,
    BattleSetupListener? onSetup,
  }) async {
    await prepareFlowSnapshotFonts(tester);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    session = _Session(exercise: exercise);
    addTearDown(session.dispose);
    camera = FakeCameraService();
    if (denied) camera.permission = CameraPermission.denied;
    estimator = FakePoseEstimator();
    phone = placedPhone();
    reports = InMemoryFormReportStore();
    repository = FakeUserRepository();
    results = [];
    replacements = _Replacements();
    counter = RepCounterViewModel(
      camera: camera,
      estimator: estimator,
      judge: judge ?? FakeRepJudge(),
      phoneTilt: phone,
      roundLength: const Duration(days: 1),
    );
    // As in the app, the battle opens over the lobby.
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [replacements],
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: Text('로비')),
        onGenerateRoute: (settings) => settings.name == GymRatsApp.resultRoute
            ? MaterialPageRoute<void>(
                settings: settings,
                builder: (_) {
                  results.add(settings.arguments! as BattleResult);
                  return const Scaffold(body: Text('결과 화면'));
                },
              )
            : null,
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => OnlineBattleScreen(
            session: session,
            formReports: reports,
            userRepository: repository,
            createCounter: () => counter,
            playerName: '우현',
            setupConfig: const SetupConfig(
              readyDelay: Duration.zero,
              dropDelay: Duration.zero,
            ),
            onCue: onCue,
            onSetup: onSetup,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Lets [ms] pass on the stage, a frame at a time. The stage never
  /// settles: its fighters breathe.
  Future<void> wait(WidgetTester tester, int ms) async {
    for (var left = ms; left > 0; left -= 50) {
      await tester.pump(Duration(milliseconds: left < 50 ? left : 50));
    }
  }

  BattleStageState stage(WidgetTester tester) =>
      tester.widget<BattleArena>(find.byType(BattleArena)).state;

  BattleFxFrame frame(WidgetTester tester) =>
      tester.widget<BattleStage>(find.byType(BattleStage)).frame;

  /// Whether the ready button with [label] can be pressed.
  bool canPress(WidgetTester tester, String label) =>
      tester
          .widget<InkWell>(
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
          )
          .onTap !=
      null;

  /// Lets a camera frame through, with the setup pose found or not.
  Future<void> pose(WidgetTester tester, {bool found = true}) async {
    estimator.frames.add(found ? standingFrame() : emptyFrame());
    camera.emit();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// A round running for [elapsedMs], with [leftMs] left, with the game.
  Future<void> play(
    WidgetTester tester, {
    int elapsedMs = 100,
    int leftMs = 15000,
    BattleRules? rules = battleRules,
  }) async {
    session.rules = rules;
    session.startAtMs = session.serverNow - elapsedMs;
    session.endAtMs = session.serverNow + leftMs;
    session.phase = OnlinePhase.playing;
    session.notifyListeners();
    await tester.pump();
    await pose(tester);
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
    await pose(tester);
    session.phase = OnlinePhase.finished;
    session.result = {
      ...result,
      if (endedAfterMs != null)
        'ended_at_ms': session.startAtMs! + endedAfterMs,
    };
    session.notifyListeners();
    await tester.pump();
    // Let the report be written and sent.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  /// Plays the ending to 결과 보기 and presses it.
  Future<BattleResult> showResult(WidgetTester tester) async {
    await wait(tester, 2400);
    expect(find.text('결과 보기'), findsOneWidget);
    await tester.tap(find.text('결과 보기'));
    await wait(tester, 400);
    expect(find.text('결과 화면'), findsOneWidget);
    return results.single;
  }

  group('before the start', () {
    testWidgets('the stage draws my character and the one the opponent sent', (
      tester,
    ) async {
      await open(tester);
      expect(
        tester.widget<BattleArena>(find.byType(BattleArena)).characters,
        const BattleCharacters(me: 'bear', opponent: 'seal'),
      );
      expect(
        tester
            .widgetList<CharacterFigure>(find.byType(CharacterFigure))
            .map((figure) => (figure.characterId, figure.side)),
        containsAll([('bear', BattleSide.me), ('seal', BattleSide.opponent)]),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('both players set up on the stage; the camera area has the '
        'setup bar, the hint and 준비, which waits for a valid pose', (
      tester,
    ) async {
      await open(tester);
      expect(stage(tester).phase, BattleStagePhase.setup);
      expect(stage(tester).myName, '우현');
      expect(stage(tester).opponentName, '상대사용자');
      expect(find.text('자세 세팅 중'), findsOneWidget);
      expect(find.text('세팅 중'), findsNWidgets(2));
      expect(canPress(tester, '준비'), isFalse);
      expect(find.bySemanticsLabel('자세 세팅 진행'), findsOneWidget);
      await pose(tester);
      expect(canPress(tester, '준비'), isTrue);
      await tester.tap(find.text('준비'));
      await tester.pump();
      expect(session.readyRequests, [true]);
      expect(find.text('상대 준비를 기다리는 중…'), findsOneWidget);
      await wait(tester, 100);
      expect(find.text('상대를 기다리는 중'), findsOneWidget);
      expect(find.text('준비 완료'), findsOneWidget);
      expect(canPress(tester, '준비 취소'), isTrue);
      expect(session.startAtMs, isNull);
      expect(counter.history, isEmpty);
      expect(counter.roundLength, const Duration(days: 1));
      await captureFlowSnapshot('online-ready-waiting');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('online setup requires a propped and still phone', (
      tester,
    ) async {
      await open(tester);
      phone.isPropped = false;
      await pose(tester);
      expect(find.text('폰을 더 세워 주세요.'), findsOneWidget);
      expect(canPress(tester, '준비'), isFalse);
      phone.isPropped = true;
      phone.isStill = false;
      await pose(tester);
      expect(find.text('폰이 흔들리지 않게 두세요.'), findsOneWidget);
      phone.isStill = true;
      await pose(tester);
      await tester.tap(find.text('준비'));
      await tester.pump();
      expect(session.readyRequests, [true]);
      phone.isStill = false;
      await pose(tester);
      expect(session.readyRequests, [true, false]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('losing the valid pose revokes ready instead of starting the '
        'round', (tester) async {
      await open(tester);
      await pose(tester);
      await tester.tap(find.text('준비'));
      await tester.pump();
      await pose(tester, found: false);
      expect(session.readyRequests, [true, false]);
      expect(session.phase, OnlinePhase.preparing);
      expect(session.startAtMs, isNull);
      expect(canPress(tester, '준비'), isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the camera switch is there while setting up', (tester) async {
      await open(tester);
      await pose(tester);
      expect(find.bySemanticsLabel('카메라 전환'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the push-up silhouette lies over the camera as in the bot '
        'battle, turns ready with the pose and stays through the countdown; '
        'the chest lines come with the round', (tester) async {
      await open(tester);
      await pose(tester, found: false);
      final guide = find.byType(PoseSilhouetteGuide);
      expect(guide, findsOneWidget);
      expect(tester.widget<PoseSilhouetteGuide>(guide).ready, isFalse);
      // Laid where a cropping camera would show it, the strips around it
      // dimmed (the S22's 360 x 387 below the line).
      final overlay = tester.widget<BattleGuideOverlay>(
        find.byType(BattleGuideOverlay),
      );
      expect(
        overlay.share,
        BattleCameraView.coverShare(3 / 4, const Size(360, 387)),
      );
      final picture = tester.getRect(find.byType(PoseCameraView));
      expect(tester.getSize(guide).width, closeTo(picture.width, .01));
      expect(
        tester.getSize(guide).height,
        closeTo(picture.height * overlay.share.height, .01),
      );
      expect(tester.getCenter(guide), offsetMoreOrLessEquals(picture.center));
      expect(find.byType(ChestHeightOverlay), findsNothing);

      await pose(tester);
      expect(tester.widget<PoseSilhouetteGuide>(guide).ready, isTrue);
      session.scheduleStart(inMs: 5000);
      await wait(tester, 100);
      expect(stage(tester).phase, BattleStagePhase.countdown);
      expect(guide, findsOneWidget);
      expect(find.byType(ChestHeightOverlay), findsNothing);

      await play(tester);
      expect(guide, findsNothing);
      expect(find.byType(ChestHeightOverlay), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a squat setup has no silhouette yet; the squat lines come '
        'with the round', (tester) async {
      await open(tester, exercise: ExerciseType.squat);
      await pose(tester);
      expect(find.byType(PoseSilhouetteGuide), findsNothing);
      expect(find.byType(BattleGuideOverlay), findsNothing);
      expect(find.byType(SquatHeightOverlay), findsNothing);
      session.scheduleStart(inMs: 5000);
      await wait(tester, 100);
      expect(find.byType(SquatHeightOverlay), findsNothing);
      await play(tester);
      expect(find.byType(PoseSilhouetteGuide), findsNothing);
      expect(find.byType(SquatHeightOverlay), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no silhouette while the app is away, the camera reopens or '
        'it has failed', (tester) async {
      await open(tester);
      await pose(tester);
      final guide = find.byType(PoseSilhouetteGuide);
      expect(guide, findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(counter.state.phase, isNot(CounterPhase.running));
      expect(find.byType(BattleCameraView), findsOneWidget);
      expect(guide, findsNothing);

      // Back, with a camera slow to open.
      camera.startGate = Completer();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(counter.state.phase, CounterPhase.starting);
      expect(guide, findsNothing);
      camera.startGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(counter.state.phase, CounterPhase.running);
      expect(guide, findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await open(tester, denied: true);
      expect(find.byType(PoseSilhouetteGuide), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a lost connection is said in the hint, and 준비 waits', (
      tester,
    ) async {
      await open(tester);
      await pose(tester);
      session.connected = false;
      session.notifyListeners();
      await tester.pump();
      expect(find.text('재연결 중 · 준비 상태 확인 중…'), findsOneWidget);
      expect(canPress(tester, '준비'), isFalse);
      // The round's band is for the round only.
      expect(find.text('재연결 중 · 경기 시간은 계속 진행됩니다.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the countdown: the time to the start in the hint, then 3, '
        '2, 1 and GO! on the stage', (tester) async {
      await open(tester);
      await pose(tester);
      session.scheduleStart(inMs: 5000);
      await wait(tester, 100);
      expect(stage(tester).phase, BattleStagePhase.countdown);
      expect(find.text('5초 후 함께 시작'), findsOneWidget);
      expect(find.text('준비'), findsNothing);
      expect(find.text('준비 완료'), findsNWidgets(2));
      await captureFlowSnapshot('online-countdown');
      await wait(tester, 2200);
      expect(find.text('3'), findsOneWidget);
      // From 3 seconds on the stage counts; the hint has nothing to add.
      session.startAtMs = session.serverNow + 2500;
      session.notifyListeners();
      await tester.pump();
      expect(find.textContaining('초 후 함께 시작'), findsNothing);
      await wait(tester, 2900);
      expect(find.text('GO!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a lost connection during the countdown is said in the hint, '
        'not in the round\'s band', (tester) async {
      await open(tester);
      await pose(tester);
      session.scheduleStart(inMs: 5000);
      session.connected = false;
      session.notifyListeners();
      await wait(tester, 100);
      expect(find.text('재연결 중 · 준비 상태 확인 중…'), findsOneWidget);
      expect(find.text('재연결 중 · 경기 시간은 계속 진행됩니다.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('camera permission failure keeps setup and recovery controls '
        'visible', (tester) async {
      await open(tester, denied: true);
      expect(find.text('카메라 권한 또는 자세 인식을 확인해주세요.'), findsOneWidget);
      expect(find.text('카메라 다시 준비'), findsOneWidget);
      expect(canPress(tester, '준비'), isFalse);
      expect(session.readyRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('at $scale x text size nothing overflows, before the start '
          'and in the round', (tester) async {
        await open(tester, textScale: scale);
        await pose(tester);
        expect(tester.takeException(), isNull);
        await play(tester);
        session.connected = false;
        session.notifyListeners();
        await wait(tester, 100);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('back before the start names the opponent in the leave dialog', () {
    for (final (name, words) in const [
      ('상대사용자', '상대사용자와의 대결이 취소되고\n홈으로 돌아가요.'),
      ('진영', '진영과의 대결이 취소되고\n홈으로 돌아가요.'),
      ('Mike', 'Mike 님과의 대결이 취소되고\n홈으로 돌아가요.'),
      ('NightRunner7', 'NightRunner7 님과의\n대결이 취소되고\n홈으로 돌아가요.'),
    ]) {
      testWidgets(name, (tester) async {
        await open(tester);
        session.opponent = OnlinePlayer('opponent', name, 'seal');
        await tester.binding.handlePopRoute();
        await wait(tester, 400);
        expect(find.text('게임에서 나갈까요?'), findsOneWidget);
        expect(find.text(words), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  testWidgets('the leave button asks first; leaving after the start tells '
      'the server and closes the battle', (tester) async {
    await open(tester);
    await play(tester);
    await tester.tap(find.bySemanticsLabel('게임 나가기'));
    await wait(tester, 400);
    expect(find.text('시작 후 나가면 서버 규칙에 따라\n기권 처리됩니다.'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await wait(tester, 400);
    expect(session.leaves, 0);
    await tester.tap(find.bySemanticsLabel('게임 나가기'));
    await wait(tester, 400);
    await tester.tap(find.widgetWithText(TextButton, '게임 나가기'));
    await wait(tester, 1000);
    expect(session.leaves, 1);
    expect(find.byType(OnlineBattleScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  group('in the round', () {
    testWidgets('the stage shows the server\'s scores, valid reps and bar, '
        'and the camera its chest lines', (tester) async {
      await open(tester);
      await play(tester);
      session.myReps = 3;
      session.opponentReps = 2;
      session.myScore = 45;
      session.opponentScore = 20;
      session.notifyListeners();
      await wait(tester, 100);
      final now = stage(tester);
      expect(now.phase, BattleStagePhase.playing);
      expect((now.myScore, now.opponentScore), (45, 20));
      expect((now.myReps, now.opponentReps), (3, 2));
      expect(now.barShare, closeTo(.625, 1e-9));
      expect(find.text('45'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.byType(BattleCameraView), findsOneWidget);
      expect(find.byType(ChestHeightOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureFlowSnapshot('online-battle-live-indicators');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an older server has no game: the reps are the score, and a '
        'counted rep lands for +1', (tester) async {
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester, rules: null);
      session.myReps = 3;
      session.notifyListeners();
      await tester.pump();
      expect(stage(tester).myScore, 3);
      judge.closeRep(maxDepth: 1.9);
      await pose(tester);
      await wait(tester, 100);
      expect(find.text('GOOD'), findsOneWidget);
      await wait(tester, 400);
      expect(find.text('+1'), findsOneWidget);
      expect(session.myLastScore, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('my rep plays at once, without the server: the grade and its '
        'points from the preview; the score waits for the server', (
      tester,
    ) async {
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester);
      judge.closeRep(maxDepth: 1.9);
      await pose(tester);
      await wait(tester, 100);
      expect(find.text('EXCELLENT'), findsOneWidget);
      await wait(tester, 500);
      expect(find.text('+15'), findsOneWidget);
      expect(session.myScore, 0);
      expect(stage(tester).myScore, 0);
      judge.closeRep(reason: RejectReason.insufficientDepth);
      await pose(tester);
      await wait(tester, 200);
      expect(find.text('MISS'), findsOneWidget);
      expect(find.text('더 깊게'), findsOneWidget);
      expect(find.text('+15'), findsNothing);
      await tester.pumpWidget(const SizedBox());
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
      await pose(tester);
      await wait(tester, 100);
      expect(find.text('EXCELLENT'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an average rep: amber AVERAGE, its points and the reason on '
        'the sign; a server without Average makes it a miss', (tester) async {
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester);
      judge.closeRep(
        reason: RejectReason.insufficientDepth,
        minElbowAngle: 120,
      );
      await pose(tester);
      await wait(tester, 100);
      expect(find.text('AVERAGE'), findsOneWidget);
      expect(find.text('더 깊게'), findsOneWidget);
      expect(frame(tester).sign!.average, isTrue);
      await wait(tester, 400);
      expect(find.text('+5'), findsOneWidget);
      session.rules = const BattleRules(averagePoints: 0);
      judge.closeRep(reason: RejectReason.insufficientDepth, minElbowAngle: 90);
      await pose(tester);
      await wait(tester, 200);
      expect(find.text('MISS'), findsOneWidget);
      expect(frame(tester).sign!.average, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the opponent\'s scoring rep lands on me, in pink, once; '
        'a reconnect snapshot does not play it again', (tester) async {
      await open(tester);
      await play(tester);
      session.opponentScore = 10;
      session.opponentReps = 1;
      session.opponentLastScore = const GameRepScore(
        grade: GameGrade.good,
        combo: 1,
        fever: false,
        points: 10,
      );
      session.notifyListeners();
      await wait(tester, 100);
      expect(frame(tester).me.pose, BattlePose.hit);
      final word = frame(tester).banners.single;
      expect((word.text, word.tone), ('GOOD', BattleFxTone.opponent));
      await wait(tester, 2000);
      // The same score again, as after a snapshot: nothing plays.
      session.opponentScore = 10;
      session.notifyListeners();
      await wait(tester, 100);
      expect(frame(tester).banners, isEmpty);
      expect(frame(tester).me.pose, BattlePose.idle);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets("the opponent's rep that earned nothing: their swing misses "
        'with MISS, nothing lands on me, and no sign (the sign is mine); a '
        'reconnect snapshot plays it not again', (tester) async {
      await open(tester);
      await play(tester);
      session.opponentMisses = 1;
      session.notifyListeners();
      await wait(tester, 200);
      expect(frame(tester).opponent.pose, BattlePose.attack);
      expect(frame(tester).me.pose, BattlePose.idle);
      final miss = frame(tester).banners.single;
      expect((miss.text, miss.tone), ('MISS', BattleFxTone.plain));
      expect(frame(tester).sign, isNull);
      expect(stage(tester).opponentScore, 0);
      await wait(tester, 2000);
      // The same count again, as after a snapshot: nothing plays.
      session.notifyListeners();
      await wait(tester, 100);
      expect(frame(tester).banners, isEmpty);
      expect(frame(tester).opponent.pose, BattlePose.idle);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('fever turns the stage cyan with its chip; the danger edge is '
        'on from 60 behind', (tester) async {
      await open(tester);
      await play(tester, elapsedMs: 21000, leftMs: 8500);
      await wait(tester, 300);
      expect(stage(tester).fever, isTrue);
      expect(find.text('FEVER ×2'), findsWidgets);
      expect(stage(tester).danger, isFalse);
      session.opponentScore = 60;
      session.notifyListeners();
      await wait(tester, 300);
      expect(stage(tester).danger, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the danger edge is off while the camera has failed', (
      tester,
    ) async {
      await open(tester, denied: true);
      await play(tester);
      session.opponentScore = 60;
      session.notifyListeners();
      await wait(tester, 300);
      expect(find.text('카메라 권한 또는 자세 인식을 확인해주세요.'), findsOneWidget);
      expect(stage(tester).danger, isFalse);
      expect(frame(tester).dangerOpacity, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a session error in the round is said in the hint', (
      tester,
    ) async {
      await open(tester);
      await play(tester);
      session.error = '잘못된 서버 데이터를 무시했어요.';
      session.notifyListeners();
      await tester.pump();
      expect(find.text('잘못된 서버 데이터를 무시했어요.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a screen reader hears my score when the server\'s answer '
        'brings it, not before', (tester) async {
      final said = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final event = message as Map<dynamic, dynamic>;
            if (event['type'] == 'announce') {
              said.add(
                (event['data'] as Map<dynamic, dynamic>)['message'] as String,
              );
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester);
      judge.closeRep(maxDepth: 1.4);
      await pose(tester);
      await wait(tester, 300);
      // The blow is seen; the server has not answered yet.
      expect(find.text('GOOD'), findsOneWidget);
      expect(said.where((s) => s.startsWith('내 점수')), isEmpty);
      session.myScore = 10;
      session.myReps = 1;
      session.notifyListeners();
      await tester.pump();
      expect(said.where((s) => s.startsWith('내 점수')), ['내 점수 10점, 유효 1회']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('my lost connection shows the reconnect band; the opponent\'s '
        'fades them with a tag', (tester) async {
      await open(tester);
      await play(tester);
      session.connected = false;
      session.opponentConnected = false;
      session.notifyListeners();
      await wait(tester, 100);
      expect(find.text('재연결 중 · 경기 시간은 계속 진행됩니다.'), findsOneWidget);
      expect(find.text('연결 끊김'), findsOneWidget);
      expect(frame(tester).opponent.opacity, closeTo(.45, 1e-9));
      session.connected = true;
      session.opponentConnected = true;
      session.notifyListeners();
      await wait(tester, 100);
      expect(find.text('재연결 중 · 경기 시간은 계속 진행됩니다.'), findsNothing);
      expect(find.text('연결 끊김'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the end', () {
    testWidgets('time up waits for the server: TIME!, then its verdict and '
        '결과 보기, which opens the result with the server\'s numbers', (
      tester,
    ) async {
      final judge = DepthRepJudge();
      await open(tester, judge: judge);
      await play(tester);
      judge.closeRep(maxDepth: 1.9);
      await pose(tester);
      judge.closeRep(maxDepth: 1.4);
      await pose(tester);
      session.endAtMs = session.serverNow;
      session.phase = OnlinePhase.awaitingResult;
      session.notifyListeners();
      await wait(tester, 300);
      expect(find.text('TIME!'), findsOneWidget);
      expect(find.text('서버의 최종 결과를 기다리는 중…'), findsOneWidget);
      await wait(tester, 2000);
      expect(find.text('WIN!'), findsNothing);
      expect(find.text('결과 보기'), findsNothing);
      // The leave button stays while there is no result.
      expect(find.bySemanticsLabel('게임 나가기'), findsOneWidget);
      session.myScore = 30;
      session.opponentScore = 20;
      session.myReps = 2;
      session.myInvalidReps = 1;
      session.opponentReps = 2;
      session.phase = OnlinePhase.finished;
      session.result = {
        ..._result('time_up'),
        'ended_at_ms': session.serverNow,
      };
      session.notifyListeners();
      await wait(tester, 100);
      expect(find.text('WIN!'), findsOneWidget);
      final result = await showResult(tester);
      expect(result.matchup.playerName, '우현');
      expect(result.matchup.opponent.name, '상대사용자');
      expect(result.matchup.opponent.isBot, isFalse);
      expect((result.myScore, result.opponentScore), (30, 20));
      expect(
        (result.myReps, result.myInvalidReps, result.opponentReps),
        (2, 1, 2),
      );
      expect(result.outcome, MatchOutcome.win);
      expect(result.end, GameEnd.timeUp);
      expect(result.departure, BattleDeparture.none);
      // The form report goes with it, holding the user's two reps.
      expect(result.form, same((await reports.list()).single));
      expect(result.form!.reps, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a KO from the server plays the ring-out; the result keeps '
        'the time played, rounded up, and the report is sent', (tester) async {
      await open(tester);
      session.rules = battleRules;
      session.myScore = 120;
      session.opponentScore = 20;
      session.myReps = 6;
      session.opponentReps = 2;
      await finishRound(tester, _result('ko'), endedAfterMs: 23400);
      expect(stage(tester).end?.kind, BattleEndKind.knockout);
      expect(stage(tester).end?.winner, BattleSide.me);
      await wait(tester, 1400);
      expect(find.text('K.O.'), findsOneWidget);
      expect(find.bySemanticsLabel('게임 나가기'), findsNothing);
      final result = await showResult(tester);
      expect(result.end, GameEnd.ko);
      expect(result.roundLength, const Duration(seconds: 24));
      expect(result.form!.roundLength, const Duration(seconds: 24));
      expect(repository.savedFeedback.single.$1, 'r' * 32);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the opponent\'s KO blow plays as the ending blow; the '
        'server\'s report after it does not start it over', (tester) async {
      await open(tester);
      await play(tester);
      session.opponentScore = 100;
      session.opponentReps = 6;
      session.opponentLastScore = const GameRepScore(
        grade: GameGrade.good,
        combo: 1,
        fever: false,
        points: 10,
      );
      session.notifyListeners();
      await wait(tester, 200);
      expect(frame(tester).me.pose, BattlePose.hit);
      expect(frame(tester).zoom, greaterThan(1));
      await wait(tester, 500);
      final flying = frame(tester).me.footY;
      session.phase = OnlinePhase.finished;
      session.result = _result('ko', outcome: 'loss');
      session.notifyListeners();
      await wait(tester, 50);
      // Still flying from where it was, not back on the bar.
      expect(frame(tester).me.footY, lessThan(flying));
      await wait(tester, 800);
      expect(find.text('K.O.'), findsOneWidget);
      final result = await showResult(tester);
      expect(result.outcome, MatchOutcome.lose);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the opponent leaving: they vanish, the band says so, and so '
        'does the result', (tester) async {
      await open(tester);
      session.rules = battleRules;
      await finishRound(tester, _result('forfeit'));
      await wait(tester, 600);
      expect(find.text('상대가 나가서 이겼어요'), findsOneWidget);
      expect(frame(tester).opponent.opacity, 0);
      final result = await showResult(tester);
      expect(result.departure, BattleDeparture.opponentLeft);
      expect(result.outcome, MatchOutcome.win);
      // No form report: the round did not end by time or KO.
      expect(result.form, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('my connection lost too long: I vanish and lose', (
      tester,
    ) async {
      await open(tester);
      session.rules = battleRules;
      await finishRound(tester, _result('disconnect_timeout', outcome: 'loss'));
      await wait(tester, 600);
      expect(find.text('연결이 끊겨서 졌어요'), findsOneWidget);
      final result = await showResult(tester);
      expect(result.departure, BattleDeparture.myConnectionLost);
      expect(result.outcome, MatchOutcome.lose);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('back does nothing while the ending plays, then opens the '
        'result like 결과 보기', (tester) async {
      await open(tester);
      session.rules = battleRules;
      await finishRound(tester, _result('time_up'));
      await tester.binding.handlePopRoute();
      await wait(tester, 300);
      expect(find.byType(OnlineBattleScreen), findsOneWidget);
      expect(find.text('게임에서 나갈까요?'), findsNothing);
      expect(results, isEmpty);
      await wait(tester, 2000);
      await tester.binding.handlePopRoute();
      await wait(tester, 400);
      expect(results, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the result opens once, however often it is asked for', (
      tester,
    ) async {
      await open(tester);
      session.rules = battleRules;
      await finishRound(tester, _result('time_up'));
      await wait(tester, 2400);
      // Asked twice at once, as a double tap or a tap and back would.
      final show = tester
          .widget<BattleArena>(find.byType(BattleArena))
          .onShowResult!;
      show();
      show();
      await wait(tester, 1000);
      expect(results, hasLength(1));
      expect(replacements.names, [GymRatsApp.resultRoute]);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (what, phase, extra, title, message) in [
      (
        'cancelled',
        OnlinePhase.cancelled,
        <String, dynamic>{'reason': 'player_left_before_start'},
        '경기 취소',
        '종료 사유: player_left_before_start',
      ),
      (
        'void by a server restart',
        OnlinePhase.voided,
        <String, dynamic>{'reason': 'server_restarted'},
        '경기를 확인할 수 없어요',
        '서버가 다시 시작되어 이 경기는 기록되지 않았어요.',
      ),
      (
        'void',
        OnlinePhase.voided,
        <String, dynamic>{'reason': 'both_disconnected'},
        '경기 무효',
        '종료 사유: both_disconnected',
      ),
    ]) {
      testWidgets('a battle that ended without a result ($what) says so and '
          'goes home', (tester) async {
        await open(tester);
        await play(tester);
        session.phase = phase;
        session.result = extra;
        session.notifyListeners();
        await tester.pump();
        expect(find.byType(BattleArena), findsNothing);
        expect(find.text(title), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(results, isEmpty);
        await tester.tap(find.text('홈으로 돌아가기'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('로비'), findsOneWidget);
        expect(find.byType(OnlineBattleScreen), findsNothing);
      });
    }

    testWidgets('a connection error says the session\'s words', (tester) async {
      await open(tester);
      session.phase = OnlinePhase.failed;
      session.error = '연결을 복구하지 못했어요. 임의의 승패는 기록하지 않습니다.';
      session.notifyListeners();
      await tester.pump();
      expect(find.text('연결 오류'), findsOneWidget);
      expect(find.text(session.error!), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the form report', () {
    // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
    testWidgets('a failed feedback upload still gives the result its report', (
      tester,
    ) async {
      await open(tester);
      repository.feedbackSaveError = Exception('offline');
      await finishRound(tester, {
        ..._result('time_up'),
        'ended_at_ms': 1792400000000,
      });
      expect(await reports.list(), hasLength(1));
      final result = await showResult(tester);
      expect(result.form, isNotNull);
      await tester.pumpWidget(const SizedBox());
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
    });

    testWidgets('squat result does not save or carry push-up form feedback', (
      tester,
    ) async {
      await open(tester, exercise: ExerciseType.squat);
      await finishRound(tester, {
        ..._result('time_up'),
        'ended_at_ms': 1792400000000,
      });
      expect(await reports.list(), isEmpty);
      expect(repository.savedFeedback, isEmpty);
      final result = await showResult(tester);
      expect(result.form, isNull);
      expect(result.matchup.exercise, ExerciseType.squat);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a completed online round saves its report once and sends it '
        'under the server\'s result id', (tester) async {
      await open(tester);
      await finishRound(tester, {
        ..._result('time_up'),
        'ended_at_ms': 1792400000000,
      });
      session.notifyListeners();
      await tester.pump();
      expect(await reports.list(), hasLength(1));
      final report = (await reports.list()).single;
      expect(repository.savedFeedback, hasLength(1));
      expect(repository.savedFeedback.single.$1, 'r' * 32);
      expect(repository.savedFeedback.single.$2, same(report));
      expect(repository.saved, isEmpty);
      expect(report.roundLength, const Duration(seconds: 30));
      expect(report.opponentName, '상대사용자');
      expect(report.samples, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  group('auto ready', () {
    testWidgets('a ready pose sends ready by itself after 3 seconds', (
      tester,
    ) async {
      await open(tester);
      await pose(tester);
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
      await pose(tester);
      await tester.pump(const Duration(seconds: 2));
      await pose(tester, found: false);
      expect(find.textContaining('초 후 자동으로 준비해요'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(session.readyRequests, isEmpty);
      // Ready again: a full new 3 seconds.
      await pose(tester);
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
      await pose(tester);
      await tester.tap(find.text('준비'));
      await tester.pump();
      expect(session.readyRequests, [true]);
      await tester.tap(find.text('준비 취소'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(session.readyRequests, [true, false]);
      await pose(tester, found: false);
      await pose(tester);
      await tester.pump(const Duration(milliseconds: 3100));
      expect(session.readyRequests, [true, false, true]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a slow confirmation does not send ready again', (
      tester,
    ) async {
      await open(tester);
      session.confirmReady = false;
      await pose(tester);
      await tester.pump(const Duration(milliseconds: 3100));
      expect(session.readyRequests, [true]);
      // More frames while the confirmation is on its way.
      for (var i = 0; i < 5; i++) {
        await pose(tester);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(session.readyRequests, [true]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('준비 during the countdown sends ready once', (tester) async {
      await open(tester);
      await pose(tester);
      await tester.tap(find.text('준비'));
      await tester.pump(const Duration(seconds: 4));
      expect(session.readyRequests, [true]);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('sound hooks, as on the bot screen', () {
    testWidgets("onCue hears the stage's moments: 3, 2, 1 and GO!", (
      tester,
    ) async {
      final cues = <BattleStageCue>[];
      void hear(BattleStageCue cue) => cues.add(cue);
      await open(tester, onCue: hear);
      expect(tester.widget<BattleArena>(find.byType(BattleArena)).onCue, hear);
      await pose(tester);
      session.scheduleStart(inMs: 3000);
      await wait(tester, 3400);
      expect(
        cues.map((cue) => (cue.kind, cue.number)).toList(),
        containsAllInOrder([
          (BattleCueKind.countdown, 3),
          (BattleCueKind.countdown, 2),
          (BattleCueKind.countdown, 1),
          (BattleCueKind.go, null),
        ]),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('onSetup hears the setup while the pose is checked, with the '
        "time to the server's start once it is set, and nothing after it", (
      tester,
    ) async {
      final heard = <(SetupReason, bool, Duration?)>[];
      await open(
        tester,
        onSetup: (status, startIn) =>
            heard.add((status.reason, status.isReady, startIn)),
      );
      await pose(tester, found: false);
      expect(heard.last, (SetupReason.noPerson, false, null));
      await pose(tester);
      expect(heard.last, (SetupReason.ready, true, null));

      // Both ready: the server sets the start 5 s ahead.
      session.scheduleStart(inMs: 5000);
      await tester.pump();
      final (reason, ready, startIn) = heard.last;
      expect((reason, ready), (SetupReason.ready, true));
      expect(startIn!.inMilliseconds, inInclusiveRange(4900, 5000));
      // It follows the server's start, as the stage's countdown does.
      session.startAtMs = session.serverNow + 2500;
      session.notifyListeners();
      await pose(tester);
      expect(heard.last.$3!.inMilliseconds, inInclusiveRange(2400, 2500));

      // The start passes on the phone's clock while the server still says
      // scheduled: the round is on, and the setup is over.
      final before = heard.length;
      session.startAtMs = session.serverNow - 1;
      session.endAtMs = session.startAtMs! + session.durationMs;
      session.notifyListeners();
      await tester.pump();
      await pose(tester);
      expect(session.phase, OnlinePhase.scheduled);
      expect(heard.length, before);

      await play(tester);
      final count = heard.length;
      await pose(tester);
      await pose(tester, found: false);
      expect(heard.length, count);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('onSetup keeps counting to the start when the pose is lost '
        'once the server has set it, and is quiet once the battle ended', (
      tester,
    ) async {
      final heard = <(SetupReason, Duration?)>[];
      await open(
        tester,
        onSetup: (status, startIn) => heard.add((status.reason, startIn)),
      );
      await pose(tester);
      session.scheduleStart(inMs: 5000);
      await tester.pump();
      await pose(tester, found: false);
      final (reason, startIn) = heard.last;
      expect(reason, SetupReason.noPerson);
      expect(startIn, isNotNull);

      session.phase = OnlinePhase.cancelled;
      session.notifyListeners();
      await tester.pump();
      final count = heard.length;
      await pose(tester);
      session.notifyListeners();
      await tester.pump();
      expect(heard.length, count);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('onSetup is quiet while the camera is not running', (
      tester,
    ) async {
      final heard = <SetupStatus>[];
      await open(tester, onSetup: (status, _) => heard.add(status));
      await pose(tester);
      expect(heard, isNotEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final count = heard.length;
      session.notifyListeners();
      await tester.pump();
      expect(heard.length, count);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
