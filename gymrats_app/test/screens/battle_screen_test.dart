import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/voice_cue.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/services/audio/voice_cue_table.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/push_up_judge_adapter.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/battle_viewmodel.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_arena.dart';
import 'package:gymrats_app/widgets/battle_camera_area.dart';
import 'package:gymrats_app/widgets/battle_camera_view.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';
import 'package:gymrats_app/widgets/pose_silhouette_guide.dart';
import 'package:gymrats_app/widgets/squat_height_overlay.dart';

import '../support/fakes.dart';
import '../support/flow_snapshot.dart';
import '../support/placed_phone.dart';
import '../support/pose_fixtures.dart';

const _pushUp = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

const _squat = Matchup(
  exercise: ExerciseType.squat,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

/// A setup that takes a pose as ready on its first frame and drops it on
/// the first frame without it, so a test need not hold a pose. The UAT-1
/// tests use the real one.
const _quickSetup = SetupConfig(
  readyDelay: Duration.zero,
  dropDelay: Duration.zero,
);

void main() {
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late FakeRepJudge judge;
  late FakeOpponentSource opponent;
  late FakeUserRepository repository;
  late Duration now;
  late PhoneTiltMonitor phone;
  late BattleViewModel viewModel;
  late List<String> cues;

  /// Opens BattleScreen from a home page, as the app does after the versus
  /// screen. The result route is a stub that shows the reps it received.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    CameraPermission permission = CameraPermission.granted,
    Matchup matchup = _pushUp,
    double textScale = 1,
    SetupConfig setupConfig = _quickSetup,
    BattleSetupListener? onSetup,
  }) async {
    await prepareFlowSnapshotFonts(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Created here, inside the test's fake async zone.
    camera = FakeCameraService()..permission = permission;
    estimator = FakePoseEstimator();
    judge = FakeRepJudge();
    opponent = FakeOpponentSource();
    repository = FakeUserRepository();
    now = Duration.zero;
    cues = [];
    phone = placedPhone();
    viewModel = BattleViewModel(
      matchup: matchup,
      counter: RepCounterViewModel(
        camera: camera,
        estimator: estimator,
        judge: matchup.exercise == ExerciseType.pushUp ? judge : null,
        exerciseJudge: matchup.exercise == ExerciseType.squat
            ? PushUpJudgeAdapter(judge)
            : null,
        exercise: matchup.exercise,
        phoneTilt: phone,
        clock: () => now,
        roundLength: const Duration(days: 1),
      ),
      opponent: opponent,
      repository: repository,
      sound: FakeRepSound(),
      setup: SetupChecker(
        exercise: matchup.exercise,
        config: setupConfig,
        clock: () => now,
      ),
      clock: () => now,
      now: () => DateTime(2026, 11, 12, 14, 32),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BattleScreen(
                    matchup: matchup,
                    createViewModel: () => viewModel,
                    onCue: (cue) => cues.add('$cue'),
                    onSetup: onSetup,
                  ),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
        onGenerateRoute: (settings) => switch (settings.name) {
          GymRatsApp.resultRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) {
              final result = settings.arguments! as BattleResult;
              return Scaffold(
                body: Text('result ${result.myReps}:${result.opponentReps}'),
              );
            },
          ),
          _ => null,
        },
      ),
    );
    await tester.tap(find.text('home'));
    await wait(tester, 400);
  }

  /// The pose the setup looks for: a push-up's straight arms, or for a
  /// squat the whole body standing.
  PoseFrame setupPose() => viewModel.matchup.exercise == ExerciseType.squat
      ? standingFrame(showHips: true)
      : standingFrame();

  /// A camera frame at [seconds] on the battle's clock, with the setup pose
  /// found or not. It closes the rep queued on the judge, if any.
  Future<void> frame(
    WidgetTester tester,
    double seconds, {
    bool found = true,
    PoseFrame? pose,
  }) async {
    now = Duration(milliseconds: (seconds * 1000).round());
    estimator.frames.add(pose ?? (found ? setupPose() : emptyFrame()));
    camera.emit();
    // One pump runs the frame's async work, the next renders the result.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Sets up at 1 s: the round begins at 4 s on the battle's clock. Returns
  /// once GO! has gone from the stage.
  Future<void> begin(WidgetTester tester) async {
    await frame(tester, 1);
    await frame(tester, 4);
    expect(viewModel.state.started, isTrue);
    await wait(tester, 800);
  }

  BattleStageState stage(WidgetTester tester) =>
      tester.widget<BattleArena>(find.byType(BattleArena)).state;

  BattleFxFrame stageFrame(WidgetTester tester) =>
      tester.widget<BattleStage>(find.byType(BattleStage)).frame;

  /// Whether the ready button with [label] can be pressed.
  bool canPress(WidgetTester tester, String label) =>
      tester
          .widget<InkWell>(
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
          )
          .onTap !=
      null;

  /// The dialog's 게임 나가기.
  final dialogExit = find.descendant(
    of: find.byType(ExitDialog),
    matching: find.text('게임 나가기'),
  );

  /// Takes the screen down, so the stage's clock stops with the test.
  Future<void> close(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  group('before the round', () {
    testWidgets('opens on the setup: the band, my tag setting up and the '
        "bot's ready, the setup bar, the hint, and 시작, which waits for a "
        'ready pose', (tester) async {
      await open(tester);
      expect(stage(tester).phase, BattleStagePhase.setup);
      expect(stage(tester).myName, '우현');
      expect(stage(tester).opponentName, 'RepBot');
      expect(find.text('자세 세팅 중'), findsOneWidget);
      expect(find.text('세팅 중'), findsOneWidget);
      expect(find.text('준비 완료'), findsOneWidget);
      // The bot never keeps anyone waiting.
      expect(find.text('상대를 기다리는 중'), findsNothing);
      expect(find.text('0:30'), findsOneWidget);
      expect(find.bySemanticsLabel('자세 세팅 진행'), findsOneWidget);
      expect(find.bySemanticsLabel('카메라 전환'), findsOneWidget);
      expect(canPress(tester, '시작'), isFalse);
      await frame(tester, 1, found: false);
      expect(find.text('카메라 앞에 서 주세요.'), findsOneWidget);
      expect(canPress(tester, '시작'), isFalse);
      expect(opponent.startCount, 0);
      await captureFlowSnapshot('ai-battle-setup');
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('the push-up silhouette lies over the part of the camera a '
        'cropping view would show, and turns ready with the pose', (
      tester,
    ) async {
      await open(tester);
      await frame(tester, 0.5, found: false);
      final guide = find.byType(PoseSilhouetteGuide);
      expect(guide, findsOneWidget);
      expect(tester.widget<PoseSilhouetteGuide>(guide).ready, isFalse);
      // 360 x 387 below the line, the picture 3 : 4 in it, whole.
      final picture = tester.getRect(find.byType(PoseCameraView));
      final area = BattleCameraView.coverShare(3 / 4, const Size(360, 387));
      expect(picture.height, closeTo(387, .01));
      expect(tester.getSize(guide).width, closeTo(picture.width, .01));
      expect(
        tester.getSize(guide).height,
        closeTo(picture.height * area.height, .01),
      );
      expect(tester.getCenter(guide), offsetMoreOrLessEquals(picture.center));
      // The strips above and below it are dimmed as its own outside is.
      final overlay = find.byType(BattleGuideOverlay);
      expect(tester.widget<BattleGuideOverlay>(overlay).share, area);
      expect(tester.getRect(overlay), picture);
      // The chest lines are the round's, not the setup's.
      expect(find.byType(ChestHeightOverlay), findsNothing);
      await frame(tester, 1);
      expect(tester.widget<PoseSilhouetteGuide>(guide).ready, isTrue);
      // Still there while counting down, gone in the round.
      await frame(tester, 2);
      expect(guide, findsOneWidget);
      expect(find.byType(ChestHeightOverlay), findsNothing);
      await frame(tester, 4);
      await tester.pump();
      expect(guide, findsNothing);
      expect(find.byType(ChestHeightOverlay), findsOneWidget);
      await close(tester);
    });

    testWidgets('while the app is away or the camera reopens in the setup: '
        'the spinner, no silhouette and no hint; the front camera mirrored', (
      tester,
    ) async {
      await open(tester);
      await frame(tester, 1, found: false);
      expect(find.byType(PoseSilhouetteGuide), findsOneWidget);
      expect(
        tester.widget<PoseCameraView>(find.byType(PoseCameraView)).mirror,
        isTrue,
      );
      const noOne = '카메라 앞에 서 주세요.';
      expect(find.text(noOne), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(viewModel.state.phase, BattlePhase.paused);
      expect(stage(tester).phase, BattleStagePhase.setup);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PoseSilhouetteGuide), findsNothing);
      expect(find.text(noOne), findsNothing);
      expect(find.bySemanticsLabel('카메라 전환'), findsNothing);

      // Back, with a camera slow to open.
      camera.startGate = Completer();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(viewModel.state.phase, BattlePhase.starting);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PoseSilhouetteGuide), findsNothing);
      expect(find.text(noOne), findsNothing);
      expect(find.bySemanticsLabel('카메라 전환'), findsNothing);

      camera.startGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(viewModel.state.phase, BattlePhase.setup);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(PoseSilhouetteGuide), findsOneWidget);
      await close(tester);
    });

    testWidgets('the camera switch in the setup turns to the other camera and '
        'sets up again', (tester) async {
      await open(tester);
      await frame(tester, 1, found: false);
      final starts = camera.startCount;
      await tester.tap(find.bySemanticsLabel('카메라 전환'));
      await tester.pump();
      await tester.pump();
      expect(camera.switchCount, 1);
      expect(camera.startCount, starts + 1);
      // The other camera runs, and the setup checks its picture.
      expect(viewModel.state.phase, BattlePhase.setup);
      expect(viewModel.state.started, isFalse);
      await frame(tester, 2);
      expect(viewModel.state.startIn, const Duration(seconds: 3));
      await close(tester);
    });

    testWidgets('a squat setup has no silhouette yet; the round has the squat '
        'lines and its hint', (tester) async {
      await open(tester, matchup: _squat);
      await frame(tester, 0.5);
      expect(find.byType(PoseSilhouetteGuide), findsNothing);
      expect(find.byType(BattleCameraView), findsOneWidget);
      expect(find.byType(SquatHeightOverlay), findsNothing);
      await frame(tester, 4);
      await tester.pump();
      expect(viewModel.state.started, isTrue);
      expect(find.byType(PoseSilhouetteGuide), findsNothing);
      expect(find.byType(SquatHeightOverlay), findsOneWidget);
      expect(find.text('정면에서 전신이 보이도록 서 주세요'), findsOneWidget);
      judge.snapshot = const JudgeSnapshot(phase: RepPhase.bottom);
      await frame(tester, 5);
      expect(find.text('앉은 상태 · 이제 일어서세요'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a ready pose counts 3, 2, 1 on the stage, then GO! and the '
        'round with the bot', (tester) async {
      await open(tester);
      // Frames a second apart, on the stage's time as on the battle's.
      await frame(tester, 1);
      await wait(tester, 16);
      expect(stage(tester).phase, BattleStagePhase.countdown);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('세팅 중'), findsNothing);
      // The setup bar and the camera switch are for setting up; the stage
      // counts now. 시작 may still begin the round at once.
      expect(find.bySemanticsLabel('자세 세팅 진행'), findsNothing);
      expect(find.bySemanticsLabel('카메라 전환'), findsNothing);
      expect(canPress(tester, '시작'), isTrue);
      await wait(tester, 1000);
      await frame(tester, 2);
      expect(find.text('2'), findsOneWidget);
      await wait(tester, 1000);
      await frame(tester, 3);
      expect(find.text('1'), findsOneWidget);
      expect(opponent.startCount, 0);
      await wait(tester, 1000);
      // A rep closed on the frame that ends the count is the setup's.
      judge.closeRep();
      await frame(tester, 4);
      await wait(tester, 100);
      expect(find.text('GO!'), findsOneWidget);
      expect(find.text('GOOD'), findsNothing);
      expect(stage(tester).myScore, 0);
      expect(stage(tester).phase, BattleStagePhase.playing);
      expect(opponent.startCount, 1);
      expect(find.text('시작'), findsNothing);
      expect(find.bySemanticsLabel('카메라 전환'), findsNothing);
      await wait(tester, 900);
      expect(cues, ['countdown 3', 'countdown 2', 'countdown 1', 'go']);
      await close(tester);
    });

    testWidgets('시작 in the countdown begins the round at once, with GO!', (
      tester,
    ) async {
      await open(tester);
      await frame(tester, 1);
      await wait(tester, 300);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('시작'));
      await wait(tester, 50);
      expect(viewModel.state.started, isTrue);
      expect(find.text('GO!'), findsOneWidget);
      expect(find.text('3'), findsNothing);
      await wait(tester, 3000);
      expect(cues, ['countdown 3', 'go']);
      await close(tester);
    });

    testWidgets('losing the pose in the countdown goes back to setting up', (
      tester,
    ) async {
      await open(tester);
      await frame(tester, 1);
      await wait(tester, 300);
      expect(find.text('3'), findsOneWidget);
      await frame(tester, 2, found: false);
      await wait(tester, 16);
      expect(stage(tester).phase, BattleStagePhase.setup);
      expect(find.text('자세 세팅 중'), findsOneWidget);
      expect(find.text('세팅 중'), findsOneWidget);
      await wait(tester, 3000);
      expect(find.text('GO!'), findsNothing);
      expect(viewModel.state.started, isFalse);
      await close(tester);
    });

    testWidgets('the setup waits for portrait', (tester) async {
      await open(tester, size: const Size(780, 360));
      expect(camera.startCount, 0);
      expect(viewModel.state.phase, BattlePhase.starting);
      tester.view.physicalSize = const Size(360, 780);
      await tester.pump();
      await tester.pump();
      expect(camera.startCount, 1);
      expect(viewModel.state.phase, BattlePhase.setup);
      await close(tester);
    });

    testWidgets('keeps the screen on and upright from the setup on', (
      tester,
    ) async {
      final device = <(String, Object?)>[];
      final orientations = <Object?>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      const deviceChannel = MethodChannel('gymrats/device');
      messenger.setMockMethodCallHandler(deviceChannel, (call) async {
        device.add((call.method, call.arguments));
        return null;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(call.arguments);
        }
        return null;
      });
      addTearDown(() {
        messenger
          ..setMockMethodCallHandler(deviceChannel, null)
          ..setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await open(tester);
      expect(device, [('keepScreenOn', true)]);
      expect(orientations, [
        ['DeviceOrientation.portraitUp'],
      ]);
      await begin(tester);
      expect(orientations, hasLength(1));

      await tester.binding.handlePopRoute();
      await wait(tester, 400);
      await tester.tap(dialogExit);
      await wait(tester, 1000);
      expect(device, [('keepScreenOn', true), ('keepScreenOn', false)]);
    });

    for (final scale in const [1.3, 2.0]) {
      testWidgets('at $scale x text size nothing overflows in the setup or the '
          'round', (tester) async {
        await open(tester, textScale: scale);
        await frame(tester, 0.5, found: false);
        expect(tester.takeException(), isNull);
        await begin(tester);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }
  });

  group("UAT-1 through the battle screen's setup (real setup times)", () {
    /// The words the setup screen shows for [frame]: the setup check's own
    /// message, which the battle screen's hint shows too.
    String setupWords(
      PoseFrame frame,
      ExerciseType exercise, {
      bool propped = true,
    }) =>
        SetupChecker(exercise: exercise)
            .update(frame, phonePropped: propped)
            .message;

    /// Nothing counts down, nor has the round begun, and 시작 waits.
    void notCounting(WidgetTester tester) {
      expect(viewModel.state.startIn, isNull);
      expect(stage(tester).phase, BattleStagePhase.setup);
      expect(viewModel.state.started, isFalse);
      expect(canPress(tester, '시작'), isFalse);
      expect(opponent.startCount, 0);
    }

    /// [frame] with the whole body [dx] pixels to one side in the picture.
    PoseFrame aside(PoseFrame frame, double dx) => PoseFrame(
      imageWidth: frame.imageWidth,
      imageHeight: frame.imageHeight,
      keypoints: {
        for (final MapEntry(:key, :value) in frame.keypoints.entries)
          key: Keypoint(
            landmark: key,
            x: value.x + dx,
            y: value.y,
            likelihood: value.likelihood,
          ),
      },
    );

    /// Holds [pose] from [from] for [seconds], a frame every half second,
    /// the stage's time going on with the battle's. Each frame is a new
    /// object with [pose]'s joints, as the camera's are: the setup checks
    /// each frame once.
    Future<void> hold(
      WidgetTester tester,
      PoseFrame pose, {
      required double from,
      required double seconds,
    }) async {
      for (var t = from; t <= from + seconds + 1e-9; t += .5) {
        final copy = PoseFrame(
          imageWidth: pose.imageWidth,
          imageHeight: pose.imageHeight,
          keypoints: Map.of(pose.keypoints),
        );
        await frame(tester, t, pose: copy);
        await wait(tester, 490);
      }
    }

    testWidgets('AC1, step 2 (push-up): a phone lying almost flat, then the '
        'left wrist out of the picture: the hint says what to fix, and '
        'nothing counts down', (tester) async {
      await open(tester, setupConfig: const SetupConfig());
      phone.isPropped = false;
      await hold(tester, standingFrame(), from: 1, seconds: 5);
      expect(find.text('폰을 더 세워 주세요.'), findsOneWidget);
      expect(
        setupWords(standingFrame(), ExerciseType.pushUp, propped: false),
        '폰을 더 세워 주세요.',
      );
      notCounting(tester);

      phone.isPropped = true;
      final noWrist = standingFrame(move: {BodyLandmark.leftWrist: (999, 700)});
      await hold(tester, noWrist, from: 7, seconds: 5);
      expect(setupWords(noWrist, ExerciseType.pushUp), '손이 화면에 안 보여요.');
      expect(find.text('손이 화면에 안 보여요.'), findsOneWidget);
      notCounting(tester);
      await close(tester);
    });

    testWidgets('AC2, step 3 (push-up): placed well, the silhouette is on the '
        'camera; moved to one side, the hint says how to get back in, and '
        'nothing counts down', (tester) async {
      await open(tester, setupConfig: const SetupConfig());
      await frame(tester, 1, found: false);
      final silhouette = find.byType(PoseSilhouetteGuide);
      expect(silhouette, findsOneWidget);
      final picture = tester.getRect(find.byType(PoseCameraView));
      final guide = tester.getRect(silhouette);
      expect(picture.intersect(guide), guide);
      expect(guide.width, closeTo(picture.width, .01));

      final moved = aside(standingFrame(), 420);
      final status = SetupChecker(exercise: ExerciseType.pushUp).update(moved);
      expect(status.isReady, isFalse);
      expect(status.reason, isNot(SetupReason.noPerson));
      await hold(tester, moved, from: 2, seconds: 5);
      expect(find.text(status.message), findsOneWidget);
      notCounting(tester);
      await close(tester);
    });

    testWidgets('AC3, step 4 (push-up): matching the silhouette with straight '
        'arms and holding still counts 3, 2, 1 by itself and starts the '
        'battle, with no tap', (tester) async {
      await open(tester, setupConfig: const SetupConfig());
      await hold(tester, standingFrame(), from: 1, seconds: 1.5);
      expect(viewModel.state.setup.isReady, isTrue);
      expect(
        tester
            .widget<PoseSilhouetteGuide>(find.byType(PoseSilhouetteGuide))
            .ready,
        isTrue,
      );
      await hold(tester, standingFrame(), from: 3, seconds: 2);
      expect(viewModel.state.started, isFalse);
      await frame(tester, 5.5);
      await wait(tester, 100);
      expect(viewModel.state.started, isTrue);
      expect(stage(tester).phase, BattleStagePhase.playing);
      expect(opponent.startCount, 1);
      expect(cues, ['countdown 3', 'countdown 2', 'countdown 1', 'go']);
      await close(tester);
    });

    testWidgets('step 5 (squat): missing feet and standing too close are '
        'named, and nothing counts down; standing still then counts down and '
        'starts. The standing silhouette is not there yet', (tester) async {
      await open(tester, matchup: _squat, setupConfig: const SetupConfig());
      final noFeet = standingFrame(
        showHips: true,
        hide: {BodyLandmark.leftAnkle, BodyLandmark.rightAnkle},
      );
      await hold(tester, noFeet, from: 1, seconds: 3);
      expect(setupWords(noFeet, ExerciseType.squat), '발목이 화면에 안 보여요.');
      expect(find.text('발목이 화면에 안 보여요.'), findsOneWidget);
      notCounting(tester);

      final tooClose = standingFrame(
        showHips: true,
        move: {
          BodyLandmark.nose: (500, 40),
          BodyLandmark.leftAnkle: (530, 960),
          BodyLandmark.rightAnkle: (470, 960),
        },
      );
      await hold(tester, tooClose, from: 5, seconds: 3);
      expect(setupWords(tooClose, ExerciseType.squat), '조금 뒤로 물러나 주세요.');
      expect(find.text('조금 뒤로 물러나 주세요.'), findsOneWidget);
      notCounting(tester);
      // #49 has only the push-up silhouette; the squat slot waits for
      // the standing one.
      expect(find.byType(PoseSilhouetteGuide), findsNothing);

      await hold(tester, standingFrame(showHips: true), from: 9, seconds: 4.5);
      expect(viewModel.state.started, isTrue);
      expect(cues, ['countdown 3', 'countdown 2', 'countdown 1', 'go']);
      await close(tester);
    });
  });

  testWidgets("onSetup hears the setup's status and count on every change, "
      "ready for J1's voice table, and nothing after GO!", (tester) async {
    final heard = <(SetupStatus, Duration?)>[];
    await open(
      tester,
      onSetup: (status, startIn) => heard.add((status, startIn)),
    );
    // From the moment the camera runs: nobody seen yet.
    expect(VoiceCueTable.forSetup(heard.single.$1), VoiceCue.noPerson);
    await frame(tester, 0.5, found: false);
    expect(VoiceCueTable.forSetup(heard.last.$1), VoiceCue.noPerson);
    expect(VoiceCueTable.forCountdown(heard.last.$2), isNull);
    phone.isPropped = false;
    await frame(tester, 0.7);
    expect(VoiceCueTable.forSetup(heard.last.$1), VoiceCue.phoneTooFlat);
    phone.isPropped = true;
    await frame(tester, 1);
    expect(VoiceCueTable.forSetup(heard.last.$1), VoiceCue.ready);
    expect(heard.last.$2, const Duration(seconds: 3));
    expect(VoiceCueTable.forCountdown(heard.last.$2), VoiceCue.countdownThree);
    await frame(tester, 2.5);
    expect(VoiceCueTable.forCountdown(heard.last.$2), VoiceCue.countdownTwo);
    await frame(tester, 4);
    final count = heard.length;
    await frame(tester, 6);
    await frame(tester, 7);
    expect(heard, hasLength(count));
    await close(tester);
  });

  group('in the round', () {
    testWidgets('my counted rep: GOOD, then +10, the score and my valid rep '
        'on the stage, the chest lines on the camera', (tester) async {
      await open(tester);
      await begin(tester);
      judge.snapshot = const JudgeSnapshot(
        phase: RepPhase.descending,
        shoulderDrop: .5,
        topShoulderY: 200,
      );
      judge.closeRep();
      await frame(tester, 6);
      await wait(tester, 100);
      expect(find.text('GOOD'), findsOneWidget);
      await wait(tester, 400);
      expect(find.text('+10'), findsOneWidget);
      expect((stage(tester).myScore, stage(tester).myReps), (10, 1));
      expect(stage(tester).barShare, closeTo(.55, 1e-9));
      // The front camera's picture and its lines are mirrored.
      expect(
        tester
            .widget<ChestHeightOverlay>(find.byType(ChestHeightOverlay))
            .mirror,
        isTrue,
      );
      expect(cues, contains('hit me good'));
      expect(tester.takeException(), isNull);
      await captureFlowSnapshot('ai-battle-live-indicators');
      await close(tester);
    });

    testWidgets('two counted reps within the combo window: the second earns '
        'the bonus and "2 HIT" shows over the camera (UAT-5 combo)', (
      tester,
    ) async {
      await open(tester);
      await begin(tester);
      judge.snapshot = const JudgeSnapshot(
        phase: RepPhase.descending,
        shoulderDrop: .5,
        topShoulderY: 200,
      );
      judge.closeRep();
      await frame(tester, 6);
      await wait(tester, 600);
      expect(find.text('2 HIT'), findsNothing);
      // One second later, inside the 1.5 s combo window.
      judge.closeRep();
      await frame(tester, 7);
      await wait(tester, 100);
      expect(find.text('GOOD'), findsOneWidget);
      await wait(tester, 400);
      expect(
        find.descendant(
          of: find.byType(BattleCameraArea),
          matching: find.text('2 HIT'),
        ),
        findsOneWidget,
      );
      // 10, then 10 and the 5 combo bonus.
      expect(find.text('+15'), findsOneWidget);
      expect((stage(tester).myScore, stage(tester).myReps), (25, 2));
      expect(cues.where((cue) => cue == 'hit me good'), hasLength(2));
      await close(tester);
    });

    testWidgets('a rejected rep: MISS and the sign with its reason', (
      tester,
    ) async {
      await open(tester);
      await begin(tester);
      judge.closeRep(reason: RejectReason.tooFast);
      await frame(tester, 6);
      await wait(tester, 200);
      expect(find.text('MISS'), findsOneWidget);
      expect(find.text('천천히'), findsOneWidget);
      expect(stageFrame(tester).sign!.average, isFalse);
      expect(stage(tester).myScore, 0);
      expect(cues, contains('miss me'));
      await close(tester);
    });

    testWidgets("the bot's rep lands on me, in pink", (tester) async {
      await open(tester);
      await begin(tester);
      opponent.emit();
      await wait(tester, 100);
      expect(stageFrame(tester).me.pose, BattlePose.hit);
      final word = stageFrame(tester).banners.single;
      expect((word.text, word.tone), ('GOOD', BattleFxTone.opponent));
      expect(stage(tester).opponentScore, 10);
      await close(tester);
    });

    testWidgets('fever turns the stage cyan 20 s into the round, counted '
        'from GO!, not from the camera', (tester) async {
      await open(tester);
      await begin(tester);
      // Begun at 4: 19.9 s into the round, though the camera ran 23.9 s.
      await frame(tester, 23.9);
      expect(stage(tester).fever, isFalse);
      await frame(tester, 24);
      await wait(tester, 300);
      expect(stage(tester).fever, isTrue);
      expect(find.text('FEVER ×2'), findsWidgets);
      await close(tester);
    });

    testWidgets('the danger edge from 60 behind; off while the camera has '
        'failed', (tester) async {
      await open(tester);
      await begin(tester);
      for (var i = 0; i < 5; i++) {
        opponent.emit();
      }
      await wait(tester, 300);
      expect(viewModel.state.danger, isTrue);
      expect(stage(tester).danger, isTrue);
      expect(stageFrame(tester).dangerOpacity, greaterThan(0));
      now = const Duration(seconds: 6);
      estimator.frames.add(null);
      camera.emit();
      await tester.pump();
      now = const Duration(seconds: 10);
      estimator.frames.add(null);
      camera.emit();
      await wait(tester, 300);
      expect(viewModel.state.phase, BattlePhase.failed);
      expect(stage(tester).danger, isFalse);
      expect(stageFrame(tester).dangerOpacity, 0);
      expect(find.text('자세 인식이 멈췄어요'), findsOneWidget);
      await close(tester);
    });

    testWidgets('the app in the background holds the round', (tester) async {
      await open(tester);
      await begin(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(viewModel.state.phase, BattlePhase.paused);
      expect(opponent.running, isFalse);
      expect(camera.isStreaming, isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(viewModel.state.phase, BattlePhase.playing);
      expect(opponent.running, isTrue);
      expect(camera.isStreaming, isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await close(tester);
    });
  });

  group('the end', () {
    for (final (mine, theirs, verdict, side) in const [
      (2, 1, 'WIN!', 'me'),
      (1, 2, 'LOSE', 'opponent'),
      (1, 1, 'DRAW', null),
    ]) {
      testWidgets('time up at $mine:$theirs: TIME!, then $verdict and '
          '결과 보기', (tester) async {
        await open(tester);
        await begin(tester);
        for (var i = 0; i < mine; i++) {
          judge.closeRep();
          await frame(tester, 6.0 + i);
        }
        for (var i = 0; i < theirs; i++) {
          opponent.emit();
        }
        await tester.pump();
        await frame(tester, 34);
        await wait(tester, 100);
        expect(viewModel.state.phase, BattlePhase.timeUp);
        expect(find.text('TIME!'), findsOneWidget);
        expect(find.text('결과 보기'), findsNothing);
        await wait(tester, 1000);
        expect(find.text(verdict), findsOneWidget);
        await wait(tester, 1000);
        expect(find.text('결과 보기'), findsOneWidget);
        expect(
          cues.where((c) => c.startsWith('timeUp') || c.startsWith('verdict')),
          [
            'timeUp',
            ['verdict', ?side].join(' '),
          ],
        );
        // The battle has ended: no leaving any more.
        expect(find.bySemanticsLabel('게임 나가기'), findsNothing);
        await close(tester);
      });
    }

    testWidgets('a KO plays the ring-out to 결과 보기, which opens the result '
        'in place', (tester) async {
      await open(tester);
      await begin(tester);
      judge.closeRep();
      await frame(tester, 6);
      // 10, 25, 40, 55, 70, 85, 100, 115: a 105-point lead.
      for (var i = 0; i < 8; i++) {
        opponent.emit();
      }
      await wait(tester, 100);
      expect(viewModel.state.result!.end, GameEnd.ko);
      expect(cues, contains('knockout opponent good'));
      await wait(tester, 1300);
      expect(find.text('K.O.'), findsOneWidget);
      await wait(tester, 1500);
      expect(find.text('결과 보기'), findsOneWidget);
      await tester.tap(find.text('결과 보기'));
      await wait(tester, 1000);
      expect(find.text('result 1:8'), findsOneWidget);
      expect(find.byType(BattleScreen), findsNothing);

      // Replaced, not pushed: back from the result goes home.
      await tester.binding.handlePopRoute();
      await wait(tester, 1000);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('back does nothing while the ending plays, then opens the '
        'result like 결과 보기', (tester) async {
      await open(tester);
      await begin(tester);
      await frame(tester, 34);
      await tester.binding.handlePopRoute();
      await wait(tester, 300);
      expect(find.byType(BattleScreen), findsOneWidget);
      expect(find.byType(ExitDialog), findsNothing);
      await wait(tester, 2000);
      await tester.binding.handlePopRoute();
      await wait(tester, 1000);
      expect(find.text('result 0:0'), findsOneWidget);
    });

    testWidgets('the result opens once, however often it is asked for', (
      tester,
    ) async {
      await open(tester);
      await begin(tester);
      await frame(tester, 34);
      await wait(tester, 2400);
      final show = tester
          .widget<BattleArena>(find.byType(BattleArena))
          .onShowResult!;
      show();
      show();
      await wait(tester, 1000);
      expect(find.text('result 0:0'), findsOneWidget);
      // One result screen: the battle's place was taken once.
      expect(find.byType(BattleScreen), findsNothing);
      // One battle, saved once.
      expect(repository.saved, hasLength(1));
    });
  });

  group('leaving', () {
    testWidgets('back asks; 게임 나가기 goes home and keeps nothing', (
      tester,
    ) async {
      await open(tester);
      await begin(tester);
      await tester.binding.handlePopRoute();
      await wait(tester, 400);
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);
      expect(find.text('RepBot 님과의 대결이 취소되고\n홈으로 돌아가요.'), findsOneWidget);
      expect(find.byType(BattleScreen), findsOneWidget);

      await tester.tap(dialogExit);
      await wait(tester, 1000);
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(BattleScreen), findsNothing);
      expect(opponent.stopped, isTrue);
      expect(opponent.disposed, isTrue);
      expect(camera.isStreaming, isFalse);
      expect(repository.saved, isEmpty);
    });

    testWidgets('the leave button asks too, also in the setup; 계속하기 keeps '
        'the battle going', (tester) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel('게임 나가기'));
      await wait(tester, 400);
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('계속하기'));
      await wait(tester, 400);
      expect(find.byType(ExitDialog), findsNothing);
      expect(viewModel.state.phase, BattlePhase.setup);
      await begin(tester);
      await tester.tap(find.bySemanticsLabel('게임 나가기'));
      await wait(tester, 400);
      await tester.tap(find.text('계속하기'));
      await wait(tester, 400);
      expect(viewModel.state.phase, BattlePhase.playing);
      expect(opponent.running, isTrue);
      await close(tester);
    });

    testWidgets('leaving in the setup never starts the bot', (tester) async {
      await open(tester);
      await frame(tester, 1);
      await tester.binding.handlePopRoute();
      await wait(tester, 400);
      await tester.tap(dialogExit);
      await wait(tester, 1000);
      expect(find.text('home'), findsOneWidget);
      expect(opponent.startCount, 0);
    });

    testWidgets('time running out while asking closes the question', (
      tester,
    ) async {
      await open(tester);
      await begin(tester);
      await tester.binding.handlePopRoute();
      await wait(tester, 400);
      expect(find.byType(ExitDialog), findsOneWidget);
      await frame(tester, 34);
      await wait(tester, 400);
      expect(find.byType(ExitDialog), findsNothing);
      expect(find.text('TIME!'), findsOneWidget);
      expect(find.byType(BattleScreen), findsOneWidget);
      await close(tester);
    });
  });

  group('camera trouble', () {
    testWidgets('no permission: the camera area says so, and a retry sets up '
        'again', (tester) async {
      await open(tester, permission: CameraPermission.denied);
      expect(find.text('카메라 권한이 필요해요'), findsOneWidget);
      expect(stage(tester).phase, BattleStagePhase.setup);
      expect(opponent.startCount, 0);

      camera.permission = CameraPermission.granted;
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await tester.pump();
      expect(find.text('카메라 권한이 필요해요'), findsNothing);
      expect(viewModel.state.phase, BattlePhase.setup);
      await begin(tester);
      expect(opponent.startCount, 1);
      await close(tester);
    });

    testWidgets('a failure in the round: retry sets up again on a stage that '
        'starts over, then plays from zero', (tester) async {
      await open(tester);
      await begin(tester);
      judge.closeRep();
      await frame(tester, 6);
      await wait(tester, 1000);
      // My +10 moved the meeting point to 80 + 200 x 0.55.
      expect(stageFrame(tester).meetX, closeTo(190, .5));
      now = const Duration(seconds: 7);
      estimator.frames.add(null);
      camera.emit();
      await tester.pump();
      now = const Duration(seconds: 11);
      estimator.frames.add(null);
      camera.emit();
      await wait(tester, 100);
      expect(find.text('다시 시도하면 경기가 처음부터 시작돼요.'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // A new stage stands at the middle at once; the old one would glide
      // back from 190.
      expect(stageFrame(tester).meetX, closeTo(180, .01));
      await wait(tester, 100);
      expect(viewModel.state.started, isFalse);
      expect(stage(tester).phase, BattleStagePhase.setup);
      expect((stage(tester).myScore, stage(tester).myReps), (0, 0));
      expect(find.text('자세 세팅 중'), findsOneWidget);
      cues.clear();
      await frame(tester, 12);
      await frame(tester, 15);
      await wait(tester, 100);
      expect(find.text('GO!'), findsOneWidget);
      expect(cues.last, 'go');
      await close(tester);
    });

    testWidgets('a camera turned off in settings offers the settings', (
      tester,
    ) async {
      await open(tester, permission: CameraPermission.permanentlyDenied);
      expect(find.text('카메라 권한이 꺼져 있어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
      await tester.tap(find.text('설정 열기'));
      await tester.pump();
      expect(camera.settingsCount, 1);
      await close(tester);
    });
  });
}

/// Lets [ms] pass on the stage, a frame at a time. The stage never settles:
/// its fighters breathe.
Future<void> wait(WidgetTester tester, int ms) async {
  for (var left = ms; left > 0; left -= 50) {
    await tester.pump(Duration(milliseconds: left < 50 ? left : 50));
  }
}
