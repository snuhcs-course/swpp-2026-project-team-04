import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/voice_cue.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/models/setup_hint_short.dart';
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
import 'package:gymrats_app/widgets/battle_fighter.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';
import 'package:gymrats_app/widgets/pose_silhouette_guide.dart';
import 'package:gymrats_app/widgets/pose_silhouette_squat.dart';
import 'package:gymrats_app/widgets/squat_height_overlay.dart';
import 'package:gymrats_app/models/feedback_goal.dart';
import 'package:gymrats_app/services/feedback/goal_progress.dart';
import 'package:gymrats_app/services/feedback/goal_store.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_stage_hud.dart';
import 'package:provider/provider.dart';

import '../support/auth_fakes.dart';
import '../support/fakes.dart';
import '../support/flow_snapshot.dart';
import '../support/placed_phone.dart';
import '../support/pose_fixtures.dart';
import '../services/pose/person_behind_test_support.dart';

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

/// A goal of [kind] and [target] for [exercise], set with the seal.
FeedbackGoal _goal(
  GoalKind kind,
  int target, {
  ExerciseType exercise = ExerciseType.pushUp,
}) => FeedbackGoal(
  exercise: exercise,
  kind: kind,
  target: target,
  baseline: target - 2,
  title: '목표 $target',
  setAt: DateTime(2026, 11, 17, 14),
  characterId: 'seal',
  fromMatch: 'report-1',
);

/// The app's auth with account 1 signed in, whose goals the tests save.
Future<AuthViewModel> _signedIn() async {
  final repository = ScriptedAuthRepository();
  await repository.logIn(loginId: 'woohyun', password: 'pw');
  return AuthViewModel(repository: repository);
}

/// [app] under the goal store [goals] and [auth], as the app provides
/// them; just [app] without a store.
Widget _withGoals(Widget app, GoalStore? goals, AuthViewModel? auth) {
  if (goals == null) return app;
  return MultiProvider(
    providers: [
      Provider<GoalStore>.value(value: goals),
      if (auth != null)
        ChangeNotifierProvider<AuthViewModel>.value(value: auth),
    ],
    child: app,
  );
}

/// A goal store that remembers what was read.
class _CountingGoalStore extends MemoryGoalStore {
  final reads = <(int, ExerciseType)>[];

  @override
  Future<FeedbackGoal?> read(int accountId, ExerciseType exercise) {
    reads.add((accountId, exercise));
    return super.read(accountId, exercise);
  }
}

/// A goal store whose every read fails.
class _BrokenGoalStore extends MemoryGoalStore {
  @override
  Future<FeedbackGoal?> read(int accountId, ExerciseType exercise) =>
      Future.error(StateError('locked'));
}

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
  late CadencedRepJudge judge;
  late FakeOpponentSource opponent;
  late FakeUserRepository repository;
  late Duration now;
  late PhoneTiltMonitor phone;
  late BattleViewModel viewModel;
  late List<String> cues;
  PoseFrame? previousPose;

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
    String? myCharacter,
    GoalStore? goals,
    AuthViewModel? auth,
    bool personGuard = const bool.fromEnvironment('S2_PERSON_GUARD'),
  }) async {
    await prepareFlowSnapshotFonts(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Created here, inside the test's fake async zone.
    camera = FakeCameraService()..permission = permission;
    estimator = FakePoseEstimator();
    judge = CadencedRepJudge();
    opponent = FakeOpponentSource();
    repository = FakeUserRepository();
    now = Duration.zero;
    previousPose = null;
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
        enablePersonGuard: personGuard,
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
      _withGoals(
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
                      myCharacter: myCharacter ?? CharacterRig.defaultId,
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
        goals,
        auth,
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
    final target = Duration(milliseconds: (seconds * 1000).round());
    judge.holdVerdicts = true;
    while (previousPose != null &&
        target - now > const Duration(milliseconds: 500)) {
      now += const Duration(milliseconds: 500);
      estimator.frames.add(freshPose(previousPose!));
      camera.emit();
      await tester.pump();
    }
    judge.holdVerdicts = false;
    now = target;
    previousPose = pose ?? (found ? setupPose() : emptyFrame());
    estimator.frames.add(previousPose);
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

  /// The setup cue on screen (A9): its two short lines, and its whole
  /// [sentence] only for a screen reader.
  void showsCue(
    WidgetTester tester,
    String first,
    String second,
    String sentence,
  ) {
    expect(find.text(first), findsOneWidget, reason: sentence);
    expect(find.text(second), findsOneWidget, reason: sentence);
    expect(find.text(sentence), findsNothing, reason: sentence);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(sentence), findsOneWidget, reason: sentence);
    handle.dispose();
  }

  BattleFxFrame stageFrame(WidgetTester tester) =>
      tester.widget<BattleStage>(find.byType(BattleStage)).frame;

  /// The dialog's 게임 나가기.
  final dialogExit = find.descendant(
    of: find.byType(ExitDialog),
    matching: find.text('게임 나가기'),
  );

  /// Takes the screen down, so the stage's clock stops with the test.
  Future<void> close(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  for (final matchup in [_pushUp, _squat]) {
    testWidgets(
      'experimental guard pauses ${matchup.exercise} battle until confirmation',
      (tester) async {
        await open(tester, matchup: matchup, personGuard: true);
        for (var t = 1.0; t <= 4.0; t += .5) {
          await frame(tester, t);
        }
        expect(viewModel.state.started, isTrue);
        final original = setupPose();
        final shifted = PoseFrame(
          imageWidth: original.imageWidth,
          imageHeight: original.imageHeight,
          keypoints: {
            for (final entry in original.keypoints.entries)
              entry.key: Keypoint(
                landmark: entry.key,
                x: entry.value.x + 300,
                y: entry.value.y,
                likelihood: entry.value.likelihood,
              ),
          },
        );
        judge.closeRep();
        await frame(tester, 4.2, pose: shifted);
        expect(find.text('확인 후 계속'), findsOneWidget);
        expect(stage(tester).myReps, 0);
        await frame(tester, 4.4, pose: original);
        expect(stage(tester).myReps, 0);
        await tester.tap(find.text('확인 후 계속'));
        await tester.pump();
        expect(find.text('확인 후 계속'), findsNothing);
        await frame(tester, 4.6, pose: original);
        expect(stage(tester).myReps, 1);
        await close(tester);
      },
    );
  }

  // At 2.0x text the band (y 177-353 on a 360 x 780 phone) used to cover the
  // check's first line; at 1.0x it did not.
  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'while the person check asks for a tap in the setup, the setup band and '
      'its frame step aside, at ${textScale}x text; the check is clear of the '
      'camera switch, and once it is confirmed the countdown starts (A9 with S2)',
      (tester) async {
        await open(tester, personGuard: true, textScale: textScale);
        BattleCameraArea area() =>
            tester.widget<BattleCameraArea>(find.byType(BattleCameraArea));
        final band = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_SetupCueBand',
        );
        final statusFrame = find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).border is Border &&
              ((w.decoration as BoxDecoration).border! as Border).left.width ==
                  BattleCameraArea.frameWidth,
        );
        await frame(tester, 1);
        await frame(tester, 1.5);
        expect(band, findsOneWidget);
        final original = setupPose();
        await frame(
          tester,
          2,
          pose: PoseFrame(
            imageWidth: original.imageWidth,
            imageHeight: original.imageHeight,
            keypoints: {
              for (final entry in original.keypoints.entries)
                entry.key: Keypoint(
                  landmark: entry.key,
                  x: entry.value.x + 300,
                  y: entry.value.y,
                  likelihood: entry.value.likelihood,
                ),
            },
          ),
        );
        expect(viewModel.state.phase, BattlePhase.setup);
        expect(find.text('확인 후 계속'), findsOneWidget);
        expect(area().setupCue, isNull);
        await tester.pump(BattleCameraArea.cueHold);
        expect(band, findsNothing);
        expect(statusFrame, findsNothing);
        final notice = tester.getRect(
          find
              .descendant(
                of: find.byType(PersonTrackingPauseNotice),
                matching: find.byType(Material),
              )
              .first,
        );
        final camera = tester.getRect(find.byType(BattleCameraArea));
        expect(camera.contains(notice.topLeft), isTrue);
        expect(camera.contains(notice.bottomRight), isTrue);
        final cameraSwitch = tester.getRect(
          find.byIcon(Icons.cameraswitch_outlined),
        );
        expect(notice.overlaps(cameraSwitch), isFalse);
        expect(
          find.widgetWithText(FilledButton, '확인 후 계속').hitTestable(),
          findsOneWidget,
        );
        // Back in view, then confirmed, as in the S2 test above.
        await frame(tester, 2.5, pose: original);
        await tester.tap(find.text('확인 후 계속'));
        await tester.pump();
        await frame(tester, 3, pose: original);
        expect(find.text('확인 후 계속'), findsNothing);
        // The pose holds, so the countdown starts and its green frame shows.
        expect(stage(tester).phase, BattleStagePhase.countdown);
        expect(statusFrame, findsOneWidget);
        expect(tester.takeException(), isNull);
        await close(tester);
      },
    );
  }

  group('before the round', () {
    testWidgets('the stage shows my character against RepBot', (tester) async {
      await open(tester, myCharacter: 'seal');
      expect(
        tester.widget<BattleArena>(find.byType(BattleArena)).characters,
        const BattleCharacters(me: 'seal', opponent: 'bot'),
      );
      // While setting up no fighter stands on the stage (W2b 3-B); they pop
      // up once the countdown brings the line down.
      expect(find.byType(CharacterFigure), findsNothing);
      await frame(tester, 1);
      await wait(tester, 1000);
      expect(
        tester
            .widgetList<CharacterFigure>(find.byType(CharacterFigure))
            .map((figure) => (figure.characterId, figure.side)),
        containsAll([('seal', BattleSide.me), ('bot', BattleSide.opponent)]),
      );
      await close(tester);
    });

    testWidgets('without a character given, mine is the mouse', (tester) async {
      await open(tester);
      expect(
        tester.widget<BattleArena>(find.byType(BattleArena)).characters!.me,
        'mouse',
      );
    });

    testWidgets('opens on the setup: the band, my tag setting up and the '
        "bot's ready, the setup bar and the setup cue, and no 시작 button "
        '(team decision 2026-11-15)', (tester) async {
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
      expect(find.text('시작'), findsNothing);
      await frame(tester, 1, found: false);
      showsCue(tester, '카메라', '앞으로', '카메라 앞에 서 주세요.');
      expect(find.text('시작'), findsNothing);
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
      // Setting up (W2b 3-B): 360 x 621 below the line, the 3 : 4 picture
      // filling it, cut at the sides. The guide keeps the share a cropping
      // camera would show in the battle's 360 x 387 box (option 가).
      var picture = tester.getRect(find.byType(PoseCameraView));
      final area = BattleCameraView.coverShare(3 / 4, const Size(360, 387));
      expect(picture.top, closeTo(159, .01));
      expect(picture.height, closeTo(621, .01));
      expect(picture.width, closeTo(621 * 3 / 4, .01));
      void guideOn(Rect picture) {
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
      }

      guideOn(picture);
      // The chest lines are the round's, not the setup's.
      expect(find.byType(ChestHeightOverlay), findsNothing);
      await frame(tester, 1);
      expect(tester.widget<PoseSilhouetteGuide>(guide).ready, isTrue);
      // Still there while counting down, gone in the round; in the battle's
      // layout the picture is whole, 3 : 4 under the middle, as in W2.
      await wait(tester, 400);
      picture = tester.getRect(find.byType(PoseCameraView));
      expect(
        picture,
        rectMoreOrLessEquals(const Rect.fromLTWH(34.875, 393, 290.25, 387)),
      );
      guideOn(picture);
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
        'the spinner, no silhouette and no cue; the front camera mirrored', (
      tester,
    ) async {
      await open(tester);
      await frame(tester, 1, found: false);
      expect(find.byType(PoseSilhouetteGuide), findsOneWidget);
      expect(
        tester.widget<PoseCameraView>(find.byType(PoseCameraView)).mirror,
        isTrue,
      );
      // The cue's second line, "카메라 / 앞으로".
      const noOne = '앞으로';
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

    testWidgets('a squat setup has a silhouette; the round has the squat '
        'lines and no line of words (A9 spec 6)', (tester) async {
      await open(tester, matchup: _squat);
      await frame(tester, 0.5);
      expect(find.byType(PoseSilhouetteGuide), findsNothing);
      expect(find.byType(BattleCameraView), findsOneWidget);
      expect(find.byType(StandingSilhouetteGuide), findsOneWidget);
      expect(
        tester
            .widget<StandingSilhouetteGuide>(
              find.byType(StandingSilhouetteGuide),
            )
            .ready,
        isTrue,
      );
      expect(find.byType(SquatHeightOverlay), findsNothing);
      for (final time in [1.0, 1.5, 2.0, 2.5, 3.0, 3.5]) {
        await frame(tester, time);
      }
      await tester.pump();
      expect(viewModel.state.started, isTrue);
      expect(find.byType(StandingSilhouetteGuide), findsNothing);
      expect(find.byType(SquatHeightOverlay), findsOneWidget);
      const squatLines = [
        '정면에서 전신이 보이도록 서 주세요',
        '일어선 상태 · 무릎 가까이 앉아 주세요',
        '앉은 상태 · 이제 일어서세요',
      ];
      BattleCameraArea area() =>
          tester.widget<BattleCameraArea>(find.byType(BattleCameraArea));
      for (final phase in [RepPhase.idle, RepPhase.up, RepPhase.bottom]) {
        judge.snapshot = JudgeSnapshot(phase: phase);
        await frame(tester, 5);
        expect(area().hint, isNull, reason: phase.name);
        expect(area().setupCue, isNull, reason: phase.name);
        for (final line in squatLines) {
          expect(find.text(line), findsNothing, reason: '$phase: $line');
        }
      }
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
      // counts now. They fade out as the line comes down, read by no one.
      // No 시작 button comes in: the count runs to the start by itself.
      expect(find.bySemanticsLabel('자세 세팅 진행'), findsNothing);
      expect(find.bySemanticsLabel('카메라 전환'), findsNothing);
      expect(find.text('시작'), findsNothing);
      await wait(tester, 150);
      expect(find.text('시작'), findsNothing);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsNothing);
      await wait(tester, 1000 - 150);
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

    for (final (name, matchup) in const [
      ('push-up', _pushUp),
      ('squat', _squat),
    ]) {
      testWidgets('$name: no 시작 button in the setup or the countdown; the '
          'pose held, the round starts by itself, and the start is still '
          'told as 시작 to a screen reader', (tester) async {
        final said = <String>[];
        tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<
          dynamic
        >(SystemChannels.accessibility, (message) async {
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
        await open(tester, matchup: matchup);
        expect(find.text('시작'), findsNothing);
        // The pose held, a frame every half second.
        await frame(tester, 0.5);
        await wait(tester, 16);
        expect(stage(tester).phase, BattleStagePhase.countdown);
        for (final time in [1.0, 1.5, 2.0, 2.5, 3.0]) {
          await frame(tester, time);
          expect(find.text('시작'), findsNothing);
          expect(viewModel.state.started, isFalse);
          expect(opponent.startCount, 0);
        }
        // Three seconds after the pose was ready, with nothing pressed.
        await frame(tester, 3.5);
        expect(viewModel.state.started, isTrue);
        await wait(tester, 100);
        expect(find.text('GO!'), findsOneWidget);
        expect(stage(tester).phase, BattleStagePhase.playing);
        expect(opponent.startCount, 1);
        await wait(tester, 900);
        // The stage's start (the go cue) is no button: a screen reader
        // hears it as 시작, while no 시작 shows anywhere.
        expect(cues, contains('go'));
        expect(said, contains('시작'));
        expect(find.text('시작'), findsNothing);
        await close(tester);
      });
    }

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
      // W2b 3-B 4.6: the fighters fade out in 0.1 s and the line goes back
      // up in 0.35 s; the setup's band and chips come back with it.
      await wait(tester, 100);
      expect(find.byType(BattleFighter), findsNothing);
      await wait(tester, 250);
      expect(
        tester.getTopLeft(find.byType(BattleCameraArea)).dy,
        closeTo(156, 1e-9),
      );
      expect(find.text('자세 세팅 중'), findsOneWidget);
      expect(find.text('세팅 중'), findsOneWidget);
      expect(find.text('3'), findsNothing);
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

    /// Nothing counts down, nor has the round begun, and no 시작 button
    /// shows.
    void notCounting(WidgetTester tester) {
      expect(viewModel.state.startIn, isNull);
      expect(stage(tester).phase, BattleStagePhase.setup);
      expect(viewModel.state.started, isFalse);
      expect(find.text('시작'), findsNothing);
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
      showsCue(tester, '폰을 더', '세워요', '폰을 더 세워 주세요.');
      expect(
        setupWords(standingFrame(), ExerciseType.pushUp, propped: false),
        '폰을 더 세워 주세요.',
      );
      notCounting(tester);

      phone.isPropped = true;
      final noWrist = standingFrame(move: {BodyLandmark.leftWrist: (999, 700)});
      await hold(tester, noWrist, from: 7, seconds: 5);
      expect(setupWords(noWrist, ExerciseType.pushUp), '손이 화면에 안 보여요.');
      showsCue(tester, '손이', '안 보여요', '손이 화면에 안 보여요.');
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
      final cue = SetupHintShort.of(status);
      showsCue(tester, cue.first, cue.second, status.message);
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
        'starts with the standing silhouette', (tester) async {
      await open(tester, matchup: _squat, setupConfig: const SetupConfig());
      final noFeet = standingFrame(
        showHips: true,
        hide: {BodyLandmark.leftAnkle, BodyLandmark.rightAnkle},
      );
      await hold(tester, noFeet, from: 1, seconds: 3);
      expect(setupWords(noFeet, ExerciseType.squat), '발목이 화면에 안 보여요.');
      showsCue(tester, '발목이', '안 보여요', '발목이 화면에 안 보여요.');
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
      showsCue(tester, '한 걸음', '뒤로', '조금 뒤로 물러나 주세요.');
      notCounting(tester);
      expect(find.byType(StandingSilhouetteGuide), findsOneWidget);

      await hold(tester, standingFrame(showHips: true), from: 9, seconds: 4.5);
      expect(viewModel.state.started, isTrue);
      expect(cues, ['countdown 3', 'countdown 2', 'countdown 1', 'go']);
      await close(tester);
    });

    testWidgets('a squat whose pose is right but which is not in the '
        'silhouette says 실루엣에 / 맞춰요 in red, and nothing counts down '
        '(A9 spec 2)', (tester) async {
      await open(tester, matchup: _squat, setupConfig: const SetupConfig());
      final outside = aside(standingFrame(showHips: true), 200);
      await hold(tester, outside, from: 1, seconds: 3);
      expect(viewModel.state.setup.reason, SetupReason.ready);
      expect(viewModel.state.guideAligned, isFalse);
      showsCue(tester, '실루엣에', '맞춰요', '실루엣 안에 몸을 맞춰 주세요.');
      expect(
        tester
            .widget<BattleCameraArea>(find.byType(BattleCameraArea))
            .setupCue!
            .state,
        SetupCueState.mismatch,
      );
      notCounting(tester);
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
      if (viewModel.counter.enablePersonGuard) {
        expect(find.text('확인 후 계속'), findsOneWidget);
        await tester.tap(find.text('확인 후 계속'));
        await frame(tester, 12);
      }
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

  group('the goal (A11 spec 5)', () {
    void descend() => judge.snapshot = const JudgeSnapshot(
      phase: RepPhase.descending,
      shoulderDrop: .5,
      topShoulderY: 200,
    );

    Finder chip() => find.byType(BattleGoalChip);
    Color chipGround(WidgetTester tester) => tester
        .widget<ColoredBox>(
          find.descendant(of: chip(), matching: find.byType(ColoredBox)).first,
        )
        .color;

    testWidgets('read once for the account and the exercise: hidden while '
        'setting up, 미션 0/2 from the countdown, my counted reps fill it, '
        'and the rep that reaches it brings 미션 성공! once, after its '
        'bands', (tester) async {
      final store = _CountingGoalStore()
        ..goals[(1, ExerciseType.pushUp)] = _goal(GoalKind.reps, 2);
      final auth = await _signedIn();
      addTearDown(auth.dispose);
      await open(tester, goals: store, auth: auth);
      expect(store.reads, [(1, ExerciseType.pushUp)]);
      expect(
        stage(tester).goal,
        const GoalProgress(kind: GoalKind.reps, target: 2, value: 0),
      );
      // While setting up the ready chips are in its place (decision 7).
      expect(chip(), findsNothing);
      await frame(tester, 1);
      await wait(tester, 600);
      expect(stage(tester).phase, BattleStagePhase.countdown);
      expect(find.text('미션 0/2'), findsOneWidget);
      await frame(tester, 4);
      await wait(tester, 800);
      descend();
      judge.closeRep();
      await frame(tester, 6);
      await wait(tester, 100);
      expect(find.text('미션 1/2'), findsOneWidget);
      judge.closeRep();
      await frame(tester, 7);
      await wait(tester, 100);
      expect(find.text('미션 2/2'), findsOneWidget);
      expect(
        find.descendant(of: chip(), matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );
      // The rep's own bands first, then the goal's.
      expect(find.text('GOOD'), findsOneWidget);
      expect(find.text('미션 성공!'), findsNothing);
      await wait(tester, 1300);
      expect(find.text('미션 성공!'), findsOneWidget);
      await wait(tester, 1700);
      expect(find.text('미션 성공!'), findsNothing);
      // Once a battle; the chip goes on counting.
      judge.closeRep();
      await frame(tester, 11);
      await wait(tester, 2000);
      expect(find.text('미션 성공!'), findsNothing);
      expect(find.text('미션 3/2'), findsOneWidget);
      // The screen never writes the goal.
      expect(store.goals.values.single, _goal(GoalKind.reps, 2));
      expect(store.reads, hasLength(1));
      await close(tester);
    });

    testWidgets("only the battle's exercise: a squat goal shows nothing in a "
        'push-up battle', (tester) async {
      final store = MemoryGoalStore()
        ..goals[(1, ExerciseType.squat)] = _goal(
          GoalKind.reps,
          20,
          exercise: ExerciseType.squat,
        );
      final auth = await _signedIn();
      addTearDown(auth.dispose);
      await open(tester, goals: store, auth: auth);
      await begin(tester);
      expect(stage(tester).goal, isNull);
      expect(chip(), findsNothing);
      await close(tester);
    });

    testWidgets('without a signed-in account nothing is read', (tester) async {
      final store = _CountingGoalStore()
        ..goals[(1, ExerciseType.pushUp)] = _goal(GoalKind.reps, 2);
      await open(tester, goals: store);
      await begin(tester);
      expect(store.reads, isEmpty);
      expect(chip(), findsNothing);
      await close(tester);
    });

    testWidgets('a store that cannot be read is no goal', (tester) async {
      final auth = await _signedIn();
      addTearDown(auth.dispose);
      await open(tester, goals: _BrokenGoalStore(), auth: auth);
      await begin(tester);
      expect(stage(tester).goal, isNull);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('a maxRejects goal: white in the round, red once a rejection '
        'is past it; no band', (tester) async {
      final store = MemoryGoalStore()
        ..goals[(1, ExerciseType.pushUp)] = _goal(GoalKind.maxRejects, 0);
      final auth = await _signedIn();
      addTearDown(auth.dispose);
      await open(tester, goals: store, auth: auth);
      await begin(tester);
      expect(find.text('무효 0/0'), findsOneWidget);
      expect(chipGround(tester), AppColors.card);
      judge.closeRep(reason: RejectReason.tooFast);
      await frame(tester, 6);
      await wait(tester, 2000);
      expect(find.text('무효 1/0'), findsOneWidget);
      expect(chipGround(tester), AppColors.danger);
      expect(find.text('미션 성공!'), findsNothing);
      await close(tester);
    });

    testWidgets('a retry after a camera failure is a new battle: the goal '
        'starts over and its band can come again', (tester) async {
      final store = MemoryGoalStore()
        ..goals[(1, ExerciseType.pushUp)] = _goal(GoalKind.reps, 1);
      final auth = await _signedIn();
      addTearDown(auth.dispose);
      await open(tester, goals: store, auth: auth);
      await begin(tester);
      descend();
      judge.closeRep();
      await frame(tester, 6);
      await wait(tester, 1400);
      expect(find.text('미션 성공!'), findsOneWidget);
      // The camera fails in the round.
      now = const Duration(seconds: 7);
      estimator.frames.add(null);
      camera.emit();
      await tester.pump();
      now = const Duration(seconds: 11);
      estimator.frames.add(null);
      camera.emit();
      await wait(tester, 100);
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await wait(tester, 100);
      expect(stage(tester).goal!.value, 0);
      await frame(tester, 12);
      await frame(tester, 15);
      await wait(tester, 800);
      expect(find.text('미션 0/1'), findsOneWidget);
      descend();
      judge.closeRep();
      await frame(tester, 17);
      await wait(tester, 1400);
      expect(find.text('미션 1/1'), findsOneWidget);
      expect(find.text('미션 성공!'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a maxRejects goal kept to the end: the check and all lime '
        'once time is up', (tester) async {
      final store = MemoryGoalStore()
        ..goals[(1, ExerciseType.pushUp)] = _goal(GoalKind.maxRejects, 1);
      final auth = await _signedIn();
      addTearDown(auth.dispose);
      await open(tester, goals: store, auth: auth);
      await begin(tester);
      judge.closeRep(reason: RejectReason.tooFast);
      await frame(tester, 6);
      await wait(tester, 100);
      expect(
        find.descendant(of: chip(), matching: find.byIcon(Icons.check_rounded)),
        findsNothing,
      );
      await frame(tester, 34);
      await wait(tester, 100);
      expect(viewModel.state.phase, BattlePhase.timeUp);
      expect(stage(tester).goal!.reached, isTrue);
      expect(
        find.descendant(of: chip(), matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );
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
