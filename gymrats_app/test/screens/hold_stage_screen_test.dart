import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/hold_reading.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/screens/hold_stage_art.dart';
import 'package:gymrats_app/screens/hold_stage_brief.dart';
import 'package:gymrats_app/screens/hold_stage_play.dart';
import 'package:gymrats_app/screens/hold_stage_result.dart';
import 'package:gymrats_app/screens/hold_stage_screen.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/sound_effects.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/pose/exercise_judge.dart';
import 'package:gymrats_app/services/pose/high_plank_hold.dart';
import 'package:gymrats_app/services/pose/hold_judge.dart';
import 'package:gymrats_app/services/pose/hold_pose_definition.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/hold_stage_viewmodel.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_camera_area.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/gym_owner_figure.dart';

import '../support/audio_fakes.dart';
import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

/// The battle's setup, scripted: the test says what it shows.
class _ScriptedSetup extends SetupViewModel {
  _ScriptedSetup(ExerciseType exercise)
    : super(
        exercise: exercise,
        camera: FakeCameraService(),
        estimator: FakePoseEstimator(),
        phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
      );

  SetupState _shown = const SetupState();
  int releases = 0;
  int switches = 0;
  int retries = 0;

  @override
  SetupState get state => _shown;

  void show(SetupState state) {
    _shown = state;
    notifyListeners();
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> releaseCamera() async => releases++;

  @override
  Future<void> switchCamera() async => switches++;

  @override
  Future<void> retry() async => retries++;
}

class _GuideJudge implements ExerciseRepJudge {
  @override
  RepUpdate update(PoseFrame frame) =>
      const RepUpdate(snapshot: JudgeSnapshot.initial);

  @override
  void reset() {}

  @override
  void abandon() {}

  @override
  double get minLikelihood => .6;

  @override
  double get passDepth => 1;
}

class _Reader implements HoldPoseReader {
  HoldReading answer = HoldReading.ok;

  @override
  HoldReading read(
    PoseFrame frame, {
    required Duration at,
    bool counting = false,
  }) => answer;
}

/// The high plank with a reader the test answers for.
HoldPoseDefinition _plank(_Reader reader) => HoldPoseDefinition(
  pose: highPlankHold.pose,
  setupExercise: highPlankHold.setupExercise,
  createReader: () => reader,
  entry: highPlankHold.entry,
  checks: highPlankHold.checks,
  faults: highPlankHold.faults,
  silhouette: highPlankHold.silhouette,
  guide: highPlankHold.guide,
  startWords: highPlankHold.startWords,
);

const _low = HoldFault(id: 'chair.low', cue: ('더', '앉아요'), icon: HoldIcon.low);
const _spread = HoldFault(
  id: 'chair.spread',
  cue: ('무릎', '벌려요'),
  icon: HoldIcon.spread,
);

/// A stand-in for A5's chair pose: its icons, figure and squat guide.
HoldPoseDefinition _chair(_Reader reader) => HoldPoseDefinition(
  pose: HoldPose.chair,
  setupExercise: ExerciseType.squat,
  createReader: () => reader,
  entry: true,
  checks: const ['엉덩이 높이', '무릎 안 모으기'],
  faults: const [_low, _spread],
  silhouette: HoldSilhouette.sit,
  guide: HoldGuide.squatHeight,
);

SetupState _running({
  PoseFrame? frame,
  Duration? startIn,
  bool started = false,
}) => SetupState(
  phase: SetupPhase.running,
  lastFrame: frame,
  autoStartIn: startIn,
  autoStarted: started,
  guideAligned: true,
);

/// Drives one screen: its view model on a clock the test moves.
class _Driver {
  _Driver({this.stage = 3, HoldPoseDefinition Function(_Reader)? pose})
    : pose = pose ?? _plank;

  final int stage;
  final HoldPoseDefinition Function(_Reader) pose;
  final reader = _Reader();
  final effects = FakeSoundEffects();
  final music = FakeBackgroundMusic();
  final store = MemoryArcadeProgressStore();
  final setups = <_ScriptedSetup>[];
  Duration now = Duration.zero;
  late HoldStageViewModel viewModel;
  Object? exit;
  bool closed = false;

  _ScriptedSetup get setup => setups.last;

  late final sounds = SoundServices(
    settings: SoundSettings(store: MemorySoundSettingsStore()),
    voice: const SilentVoiceGuidance(),
    music: music,
    effects: effects,
  );

  Widget screen() => HoldStageScreen(
    stage: stage,
    myCharacter: 'kangaroo',
    progressStore: store,
    accountId: 7,
    sounds: sounds,
    createViewModel: () => viewModel = HoldStageViewModel(
      stage: stage,
      definition: pose(reader),
      store: store,
      accountId: 7,
      createSetup: (exercise, _) {
        final setup = _ScriptedSetup(exercise);
        setups.add(setup);
        return setup;
      },
      createGuideJudge: (_) => _GuideJudge(),
      clock: () => now,
    ),
  );

  /// Opens the screen over a home page, at a phone's size.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                exit = await Navigator.push<HoldStageExit>(
                  context,
                  MaterialPageRoute(builder: (_) => screen()),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> startPose(WidgetTester tester) async {
    await tester.tap(find.text('자세 잡기'));
    await tester.pump();
  }

  Future<void> countdown(WidgetTester tester, int ms) async {
    setup.show(
      _running(
        frame: pushUpFrame(),
        startIn: Duration(milliseconds: ms),
      ),
    );
    await tester.pump();
  }

  Future<void> go(WidgetTester tester) async {
    await startPose(tester);
    setup.show(_running(frame: pushUpFrame()));
    await countdown(tester, 1500);
    setup.show(_running(frame: pushUpFrame(), started: true));
    await tester.pump();
  }

  /// A frame every 100 ms for [ms], the reader answering [reading].
  Future<void> hold(WidgetTester tester, int ms, [HoldReading? reading]) async {
    if (reading != null) reader.answer = reading;
    for (var t = 0; t < ms; t += 100) {
      now += const Duration(milliseconds: 100);
      setup.show(_running(frame: pushUpFrame()));
    }
    await tester.pump();
  }

  /// What a screen reader is told from now on.
  List<String> listen(WidgetTester tester) {
    final said = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final event = message as Map<dynamic, dynamic>;
        if (event['type'] == 'announce') {
          said.add(
            (event['data'] as Map<dynamic, dynamic>)['message'] as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => messenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      ),
    );
    return said;
  }

  /// One warning for [fault], after a second held.
  Future<void> warn(WidgetTester tester, HoldFault fault) async {
    await hold(tester, 1000, HoldReading.ok);
    await hold(tester, 600, HoldReading.broken(fault));
  }
}

/// The leave button, on the screen and in the semantics tree alike.
void _expectLeaveButton(Matcher matcher) {
  expect(find.byIcon(Icons.logout_rounded), matcher);
  expect(find.bySemanticsLabel('게임 나가기'), matcher);
}

Color? _frameColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey('hold-frame')),
  );
  return ((box.decoration as BoxDecoration).border as Border).top.color;
}

void main() {
  group('the briefing', () {
    testWidgets('shows the stage, the owner, the pose and its stars', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      expect(find.text('STAGE 3 · 1F'), findsOneWidget);
      expect(find.text('버티기'), findsOneWidget);
      expect(find.text('COACH'), findsOneWidget);
      expect(find.text('물렁범'), findsOneWidget);
      expect(find.text('1F 체육관 관장'), findsOneWidget);
      expect(find.text('하이 플랭크'), findsOneWidget);
      expect(find.text('최대 30초'), findsOneWidget);
      for (final seconds in ['15초', '20초', '30초']) {
        expect(find.text(seconds), findsOneWidget);
      }
      expect(find.text('판정'), findsOneWidget);
      for (final check in ['팔 펴기', '무릎 떼기', '머리 들기']) {
        expect(find.text(check), findsOneWidget);
      }
      expect(find.text('경고 2번이면 실패'), findsOneWidget);
      expect(find.text('자세 잡기'), findsOneWidget);
      final owner = tester.widget<GymOwnerFigure>(
        find.byType(GymOwnerFigure).last,
      );
      expect(owner.ownerId, 'seal');
      expect(owner.face, GymOwnerFace.watch);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter is HoldPoseIconPainter &&
              (w.painter! as HoldPoseIconPainter).pose == HoldSilhouette.plank,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a small phone without overflow', (tester) async {
      final driver = _Driver();
      await driver.open(tester, size: const Size(360, 780));
      expect(tester.takeException(), isNull);
      expect(find.text('자세 잡기'), findsOneWidget);
    });

    testWidgets('its back button returns to the arcade', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      await tester.tap(find.bySemanticsLabel('지도로'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(driver.closed, isTrue);
      expect(driver.exit, HoldStageExit.arcade);
    });

    testWidgets('back returns to the arcade as well', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(driver.exit, HoldStageExit.arcade);
    });
  });

  group('setting up and the 3·2·1', () {
    testWidgets('자세 잡기 shows the battle\'s camera area and setup', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.startPose(tester);
      driver.setup.show(_running(frame: pushUpFrame()));
      await tester.pump();
      final area = tester.widget<BattleCameraArea>(
        find.byType(BattleCameraArea),
      );
      expect(area.settingUp, isTrue);
      expect(area.setupCue, isNotNull);
      expect(area.onLeave, isNotNull);
      expect(area.setupProgress, isNotNull);
      // No clock while setting up.
      expect(find.text('버틴 시간'), findsNothing);
      area.onSwitchCamera!();
      expect(driver.setup.switches, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the 3·2·1 shows its number and the clock at zero', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.startPose(tester);
      await driver.countdown(tester, 2500);
      expect(find.text('3'), findsOneWidget);
      await driver.countdown(tester, 1500);
      expect(find.text('2'), findsOneWidget);
      await driver.countdown(tester, 400);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('버틴 시간'), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(
        tester
            .widget<BattleCameraArea>(find.byType(BattleCameraArea))
            .settingUp,
        isFalse,
      );
    });

    testWidgets('a camera that fails shows why, with a way back', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.startPose(tester);
      driver.setup.show(const SetupState(phase: SetupPhase.cameraError));
      await tester.pump();
      expect(find.text('카메라를 켜지 못했어요'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      expect(driver.setup.retries, 1);
      driver.setup.show(
        const SetupState(
          phase: SetupPhase.permissionDenied,
          permanentlyDenied: true,
        ),
      );
      await tester.pump();
      expect(find.text('카메라 권한이 꺼져 있어요'), findsOneWidget);
      expect(find.text('설정 열기'), findsOneWidget);
      driver.setup.show(const SetupState(phase: SetupPhase.permissionDenied));
      await tester.pump();
      expect(find.text('카메라 권한이 필요해요'), findsOneWidget);
      driver.setup.show(const SetupState(phase: SetupPhase.detectorError));
      await tester.pump();
      expect(find.text('자세 인식이 멈췄어요'), findsOneWidget);
    });
  });

  group('holding', () {
    testWidgets('GO! shows, then the clock runs in a green frame', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      expect(find.text('GO!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('GO!'), findsNothing);
      await driver.hold(tester, 2200);
      expect(find.text('버틴 시간'), findsOneWidget);
      expect(find.text('0:02'), findsOneWidget);
      expect(_frameColor(tester), AppColors.statusGood);
      expect(find.byKey(const ValueKey('hold-cue')), findsNothing);
      expect(find.text('삐익!'), findsNothing);
      // No camera picture: the pose's figure stands in.
      final silhouette = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('hold-silhouette')),
      );
      expect(
        (silhouette.painter! as HoldSilhouettePainter).pose,
        HoldSilhouette.plank,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bar fills toward the third star, its marks light', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 15100);
      final fill = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('hold-fill')),
      );
      expect(fill.widthFactor, closeTo(15 / 30, .01));
      expect(
        (tester
                    .widget<FractionallySizedBox>(
                      find.byKey(const ValueKey('hold-fill')),
                    )
                    .child!
                as ColoredBox)
            .color,
        AppColors.accent,
      );
      HoldStar star(int i) =>
          tester.widget<HoldStar>(find.byKey(ValueKey('hold-mark-star-$i')));
      expect([star(0).lit, star(1).lit, star(2).lit], [true, false, false]);
      for (final seconds in ['15초', '20초', '30초']) {
        expect(find.text(seconds), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('hold-face')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (fault, words) in [
      (HighPlankFaults.armBent, '팔\n펴요'),
      (HighPlankFaults.kneeDown, '무릎\n떼요'),
      (HighPlankFaults.headDown, '머리\n들어요'),
      (HoldFault.offScreen, '화면\n안으로'),
    ]) {
      testWidgets('a warning for ${fault.id} stops the clock and says '
          '${words.replaceAll('\n', ' ')}', (tester) async {
        final driver = _Driver();
        await driver.open(tester);
        await driver.go(tester);
        await driver.warn(tester, fault);
        expect(find.text('멈춤'), findsOneWidget);
        expect(find.text(words), findsOneWidget);
        expect(find.text('삐익!'), findsOneWidget);
        expect(_frameColor(tester), AppColors.danger);
        final icon = tester.widget<HoldWarningIcon>(
          find.byType(HoldWarningIcon),
        );
        expect(icon.icon, fault.icon);
        final owner = tester.widget<GymOwnerFigure>(
          find.byType(GymOwnerFigure).last,
        );
        expect(owner.face, GymOwnerFace.blow);
        final strike = tester.widget<HoldStrike>(
          find.byKey(const ValueKey('hold-strike-1')),
        );
        expect(strike.fill, AppColors.danger);
        expect(
          tester
              .widget<HoldStrike>(find.byKey(const ValueKey('hold-strike-2')))
              .fill,
          AppColors.card,
        );
        final fill = tester.widget<FractionallySizedBox>(
          find.byKey(const ValueKey('hold-fill')),
        );
        expect((fill.child! as ColoredBox).color, AppColors.warning);
        expect(driver.effects.played, [SoundEffect.reject]);
        expect(tester.takeException(), isNull);
        // Held again, the words go and the clock runs.
        await driver.hold(tester, 700, HoldReading.ok);
        expect(find.text('멈춤'), findsNothing);
        expect(find.text(words), findsNothing);
        expect(_frameColor(tester), AppColors.statusGood);
      });
    }

    testWidgets('the leave button asks with the battle\'s dialog', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 1000);
      await tester.tap(find.bySemanticsLabel('게임 나가기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExitDialog), findsOneWidget);
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);
      // 계속하기 stays.
      await tester.tap(find.text('계속하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(driver.closed, isFalse);
      await tester.tap(find.bySemanticsLabel('게임 나가기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.descendant(
          of: find.byType(ExitDialog),
          matching: find.text('게임 나가기'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(driver.exit, HoldStageExit.left);
      expect(driver.setups.single.releases, 1);
      final saved = await driver.store.read(7);
      expect(saved.bestOf(3), 0);
    });

    testWidgets('back asks too while holding', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExitDialog), findsOneWidget);
      expect(driver.closed, isFalse);
    });

    testWidgets('the hold ending while asking closes the question', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 1000);
      await tester.tap(find.bySemanticsLabel('게임 나가기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await driver.hold(tester, 30000);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExitDialog), findsNothing);
      expect(find.text('클리어!'), findsOneWidget);
      expect(driver.closed, isFalse);
    });

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('게임 나가기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExitDialog), findsOneWidget);
    }

    testWidgets('a second warning while asking closes the question at once, '
        'then the fail screen', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.warn(tester, HighPlankFaults.kneeDown);
      await driver.hold(tester, 700, HoldReading.ok);
      await openDialog(tester);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      await tester.pump(const Duration(milliseconds: 300));
      // The stage is over: the question goes, as when a battle ends.
      expect(find.byType(ExitDialog), findsNothing);
      expect(find.text('실패!'), findsOneWidget);
      await tester.pump(HoldTiming.endShow);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('다시 도전'), findsOneWidget);
      expect(driver.closed, isFalse);
    });

    testWidgets('in a second warning\'s moment there is no leave button '
        'and back opens no dialog', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.warn(tester, HighPlankFaults.kneeDown);
      await driver.hold(tester, 700, HoldReading.ok);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      expect(driver.viewModel.state.ending, isTrue);
      _expectLeaveButton(findsNothing);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExitDialog), findsNothing);
      expect(driver.closed, isFalse);
      await tester.pump(HoldTiming.endShow);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('다시 도전'), findsOneWidget);
      expect(driver.closed, isFalse);
    });

    for (final star in [false, true]) {
      testWidgets('a second warning ${star ? 'after a star' : 'with no star'}: '
          'the leave button is gone for the whole moment, on the screen and '
          'to a screen reader', (tester) async {
        final driver = _Driver();
        await driver.open(tester);
        await driver.go(tester);
        if (star) {
          await driver.hold(tester, 16000);
          await driver.hold(tester, 600, const HoldReading.broken(_low));
        } else {
          await driver.warn(tester, HighPlankFaults.kneeDown);
        }
        await driver.hold(tester, 700, HoldReading.ok);
        _expectLeaveButton(findsOneWidget);
        await driver.hold(tester, 600, const HoldReading.broken(_low));
        expect(driver.viewModel.state.ending, isTrue);
        _expectLeaveButton(findsNothing);
        await tester.pump(HoldTiming.endShow ~/ 2);
        _expectLeaveButton(findsNothing);
        await tester.pump(
          HoldTiming.endShow ~/ 2 - const Duration(milliseconds: 100),
        );
        // Still the moment, 0.1 s before its end.
        expect(driver.viewModel.state.ending, isTrue);
        _expectLeaveButton(findsNothing);
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text(star ? '클리어!' : '다시 도전'), findsOneWidget);
        expect(driver.closed, isFalse);
      });
    }

    testWidgets('a star, then a second warning while asking: the clear '
        'shows and its star is kept', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 16000);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      await driver.hold(tester, 700, HoldReading.ok);
      await openDialog(tester);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExitDialog), findsNothing);
      expect(find.byKey(const ValueKey('hold-whistle')), findsOneWidget);
      // Back in the moment does not ask either.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExitDialog), findsNothing);
      await tester.pump(HoldTiming.endShow);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('클리어!'), findsOneWidget);
      expect(driver.closed, isFalse);
      expect((await driver.store.read(7)).bestOf(3), 1);
    });
  });

  group('the result', () {
    testWidgets('a clear: time, stars, the next stage, and its buttons', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 31000);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('STAGE 3 · 1F'), findsOneWidget);
      expect(find.text('클리어!'), findsOneWidget);
      expect(find.text('버틴 시간'), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<HoldStar>(find.byKey(ValueKey('result-star-$i'))).lit,
          isTrue,
        );
      }
      expect(find.text('STAGE 4'), findsOneWidget);
      expect(
        find.text('${CharacterRig.standard.art('mouse').name} · 푸쉬업'),
        findsOneWidget,
      );
      final owner = tester.widget<GymOwnerFigure>(
        find.byType(GymOwnerFigure).last,
      );
      expect(owner.face, GymOwnerFace.ok);
      expect(find.byKey(const ValueKey('result-strikes')), findsNothing);
      expect(find.text('다시 하기'), findsOneWidget);
      expect(find.text('다음 스테이지'), findsOneWidget);
      expect(driver.setup.releases, 1);
      expect((await driver.store.read(7)).bestOf(3), 3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('다음 스테이지'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(driver.exit, HoldStageExit.nextStage);
    });

    testWidgets('a clear by two warnings lights the stars held', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 16000);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      await driver.hold(tester, 700, HoldReading.ok);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      await tester.pump(HoldTiming.endShow);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('클리어!'), findsOneWidget);
      HoldStar star(int i) =>
          tester.widget<HoldStar>(find.byKey(ValueKey('result-star-$i')));
      expect([star(0).lit, star(1).lit, star(2).lit], [true, false, false]);
      await tester.tap(find.text('다시 하기'));
      await tester.pump();
      expect(find.text('자세 잡기'), findsOneWidget);
    });

    testWidgets('a fail: no star, the two warnings, and its buttons', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.warn(tester, HighPlankFaults.kneeDown);
      await driver.hold(tester, 700, HoldReading.ok);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      await tester.pump(HoldTiming.endShow);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('실패'), findsOneWidget);
      expect(find.text('0:01'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<HoldStar>(find.byKey(ValueKey('result-star-$i'))).lit,
          isFalse,
        );
      }
      // The two reasons, in order, where "경고 2번" was (effects spec 5).
      expect(find.text('경고 2번'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-reason-0')),
          matching: find.text('무릎 떼요'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-reason-1')),
          matching: find.text('더 앉아요'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('result-next')), findsNothing);
      final owner = tester.widget<GymOwnerFigure>(
        find.byType(GymOwnerFigure).last,
      );
      expect(owner.face, GymOwnerFace.blow);
      expect(find.text('아케이드로'), findsOneWidget);
      expect(find.text('다시 도전'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('다시 도전'));
      await tester.pump();
      expect(find.text('자세 잡기'), findsOneWidget);
      await driver.go(tester);
      await driver.warn(tester, HighPlankFaults.kneeDown);
      await driver.hold(tester, 700, HoldReading.ok);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      await tester.pump(HoldTiming.endShow);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('아케이드로'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(driver.exit, HoldStageExit.arcade);
    });

    testWidgets('the results fit a small phone', (tester) async {
      final driver = _Driver();
      await driver.open(tester, size: const Size(360, 780));
      await driver.go(tester);
      await driver.hold(tester, 31000);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('다음 스테이지'), findsOneWidget);
    });

    // A narrow phone or large text (found by P16, 2026-11-23): the frame's
    // stars and the ink button's words shrink only where they do not fit.
    for (final (size, scale) in [
      (const Size(360, 780), 1.3),
      (const Size(320, 640), 1.3),
      (const Size(320, 640), 1.0),
    ]) {
      testWidgets('a clear and a fail fit ${size.width.toInt()} × '
          '${size.height.toInt()} at ${scale}x text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final driver = _Driver();
        await driver.open(tester, size: size);
        // A short phone scrolls the briefing and the result to their
        // buttons.
        Future<void> reach(String words) async {
          await tester.ensureVisible(find.text(words));
          await tester.pump();
        }

        await reach('자세 잡기');
        await driver.go(tester);
        await driver.hold(tester, 31000);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('다음 스테이지'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await reach('다시 하기');
        await tester.tap(find.text('다시 하기'));
        await tester.pump();
        await reach('자세 잡기');
        await driver.go(tester);
        await driver.warn(tester, HighPlankFaults.kneeDown);
        await driver.hold(tester, 700, HoldReading.ok);
        await driver.hold(tester, 600, const HoldReading.broken(_low));
        expect(find.text('실패!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(HoldTiming.endShow);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('다시 도전'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the frame keeps the design sizes where they fit', (
      tester,
    ) async {
      Future<void> frame(Size size, double scale) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: ArcadeResultFrame(
                tag: 'STAGE 6 · 1F',
                title: '실패',
                cleared: false,
                stars: const [
                  ArcadeResultStar(lit: false, label: '승리'),
                  ArcadeResultStar(lit: false, label: '콤보 5 이상'),
                  ArcadeResultStar(lit: false, label: '20초'),
                ],
                figures: const SizedBox(),
                secondaryLabel: '아케이드로',
                onSecondary: () {},
                primaryLabel: 'R1부터 다시',
                onPrimary: () {},
              ),
            ),
          ),
        );
      }

      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // The painted width, after any shrinking.
      double drawn(Finder finder) => tester.getRect(finder).width;
      final star = find.byKey(const ValueKey('result-star-1'));
      final words = find.text('R1부터 다시');

      await frame(const Size(412, 915), 1);
      expect(tester.takeException(), isNull);
      expect(drawn(star), 72);
      final full = drawn(words);
      // A roomier phone draws them no bigger: at 412 they are not shrunk.
      await frame(const Size(600, 1000), 1);
      expect(drawn(words), closeTo(full, .01));
      expect(drawn(star), 72);
      // Nor at the design's own 360 × 780.
      await frame(const Size(360, 780), 1);
      expect(drawn(words), closeTo(full, .01));
      expect(drawn(star), 72);

      for (final (size, scale) in [
        (const Size(360, 780), 1.3),
        (const Size(320, 640), 1.3),
        (const Size(320, 640), 1.0),
      ]) {
        await frame(size, scale);
        expect(tester.takeException(), isNull, reason: '$size ${scale}x');
      }
      // 320 wide: the stars' row is 20 points too wide, so it shrinks.
      expect(drawn(star), lessThan(72));
      // 1.3x text on a 360 phone: the words shrink to their button, under
      // the 1.3x they would be.
      await frame(const Size(360, 780), 1.3);
      expect(drawn(words), lessThan(full * 1.3 - 1));
    });

    test('the next stage card names a fight, a hold and a boss match', () {
      final mouse = CharacterRig.standard.art('mouse').name;
      expect(
        ArcadeNextStageCard.nameOf(ArcadeCatalog.stage(4)),
        '$mouse · 푸쉬업',
      );
      expect(ArcadeNextStageCard.nameOf(ArcadeCatalog.stage(5)), '물렁범 · 의자 자세');
      expect(ArcadeNextStageCard.nameOf(ArcadeCatalog.stage(6)), '보스 매치 · 물렁범');
    });
  });

  group('the owner\'s bubbles, the sounds and the music (effects spec)', () {
    HoldOwner owner(WidgetTester tester) =>
        tester.widget<HoldOwner>(find.byKey(const ValueKey('hold-owner')));

    testWidgets('GO: "그대로 버텨!" in the white bubble for 2 s, read out', (
      tester,
    ) async {
      final driver = _Driver();
      final said = driver.listen(tester);
      await driver.open(tester);
      await driver.go(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('hold-start')),
          matching: find.text('그대로 버텨!'),
        ),
        findsOneWidget,
      );
      expect(said, contains('그대로 버텨!'));
      await driver.hold(tester, 1000);
      expect(find.byKey(const ValueKey('hold-start')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('hold-start')), findsNothing);
    });

    testWidgets('a warning takes the start bubble\'s place', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      expect(find.byKey(const ValueKey('hold-start')), findsNothing);
      expect(find.byKey(const ValueKey('hold-whistle')), findsOneWidget);
    });

    testWidgets('the first and second stars: a lime cheer, a smile, a pop '
        'and the good sound, once each', (tester) async {
      final driver = _Driver(); // Stage 3: 15, 20 and 30 s.
      final said = driver.listen(tester);
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 15200);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('hold-cheer')),
          matching: find.text('좋아!'),
        ),
        findsOneWidget,
      );
      expect(owner(tester).face, GymOwnerFace.ok);
      expect(find.byKey(const ValueKey('hold-star-pop-0')), findsOneWidget);
      expect(
        driver.effects.played.where((e) => e == SoundEffect.good),
        hasLength(1),
      );
      expect(said, contains('15초, 별 하나, 좋아!'));
      await tester.pump(HoldTiming.cheer);
      expect(find.byKey(const ValueKey('hold-cheer')), findsNothing);
      expect(owner(tester).face, GymOwnerFace.watch);
      expect(find.byKey(const ValueKey('hold-star-pop-0')), findsNothing);
      await driver.hold(tester, 5000);
      await tester.pump();
      expect(find.text('잘한다!'), findsOneWidget);
      expect(find.byKey(const ValueKey('hold-star-pop-1')), findsOneWidget);
      expect(
        driver.effects.played.where((e) => e == SoundEffect.good),
        hasLength(2),
      );
      // The third star is the clear: no cheer and no sound for it.
      await driver.hold(tester, 10000);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('클리어!'), findsOneWidget);
      expect(
        driver.effects.played.where((e) => e == SoundEffect.good),
        hasLength(2),
      );
    });

    testWidgets('the cheer ends at the owner on every floor', (tester) async {
      for (final (stage, owner) in [
        (9, 'penguin'),
        (15, 'kangaroo'),
        (21, 'bear'),
      ]) {
        final driver = _Driver(stage: stage);
        await driver.open(tester);
        await driver.go(tester);
        final first = ArcadeCatalog.stage(stage) as ArcadeHoldStage;
        await driver.hold(tester, first.starSeconds.first * 1000 + 200);
        await tester.pump();
        final positioned = tester.widget<Positioned>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('hold-cheer')),
                matching: find.byType(Positioned),
              )
              .first,
        );
        expect(positioned.right, holdBigBubbleRight[owner], reason: owner);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });

    for (final (size, scale) in [
      (const Size(360, 780), 1.3),
      (const Size(320, 640), 1.3),
      (const Size(320, 640), 1.0),
    ]) {
      testWidgets('"잘한다!" fits ${size.width.toInt()} × '
          '${size.height.toInt()} at ${scale}x text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final driver = _Driver();
        await driver.open(tester, size: size);
        await tester.ensureVisible(find.text('자세 잡기'));
        await tester.pump();
        await driver.go(tester);
        expect(find.byKey(const ValueKey('hold-start')), findsOneWidget);
        await driver.hold(tester, 20200);
        await tester.pump(HoldTiming.failPop);
        expect(find.text('잘한다!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('with reduced motion the stars do not pop', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 15200);
      await tester.pump();
      expect(find.text('좋아!'), findsOneWidget);
      expect(find.byKey(const ValueKey('hold-star-pop-0')), findsNothing);
    });

    testWidgets('a warning takes the cheer\'s place', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 15200);
      await tester.pump();
      expect(find.text('좋아!'), findsOneWidget);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      expect(find.text('좋아!'), findsNothing);
      expect(find.byKey(const ValueKey('hold-whistle')), findsOneWidget);
      expect(owner(tester).face, GymOwnerFace.blow);
    });

    testWidgets('a second warning with no star: "실패!" over the stage, the '
        'warning kept below for 1.5 s, then the reasons in order', (
      tester,
    ) async {
      final driver = _Driver();
      final said = driver.listen(tester);
      await driver.open(tester);
      await driver.go(tester);
      await driver.warn(tester, HighPlankFaults.kneeDown);
      await driver.hold(tester, 700, HoldReading.ok);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      await tester.pump(HoldTiming.failPop);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('hold-fail')),
          matching: find.text('실패!'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('hold-whistle')), findsNothing);
      expect(find.text('더\n앉아요'), findsOneWidget);
      expect(find.text('멈춤'), findsOneWidget);
      expect(_frameColor(tester), AppColors.danger);
      expect(owner(tester).face, GymOwnerFace.blow);
      expect(said.sublist(said.length - 2), ['경고 2번, 더 앉아요', '실패!']);
      // The lose jingle starts now, as a battle's does when it ends.
      expect(driver.music.played.last, MusicCue.lose);
      // Nothing is judged in the moment: the frames are not even read.
      final seen = driver.viewModel.lastFrame;
      await driver.hold(tester, 1000, const HoldReading.broken(_low));
      expect(identical(driver.viewModel.lastFrame, seen), isTrue);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('실패!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('다시 도전'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-reason-0')),
          matching: find.text('무릎 떼요'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-reason-1')),
          matching: find.text('더 앉아요'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the battle\'s music at the battle\'s moments', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      expect(driver.music.played, isEmpty);
      await driver.startPose(tester);
      expect(driver.music.played.last, MusicCue.setup);
      driver.setup.show(_running(frame: pushUpFrame()));
      await driver.countdown(tester, 1500);
      expect(driver.music.played.last, MusicCue.setup);
      driver.setup.show(_running(frame: pushUpFrame(), started: true));
      await tester.pump();
      expect(driver.music.played.last, MusicCue.battle);
      await driver.hold(tester, 31000);
      await tester.pump(const Duration(milliseconds: 100));
      expect(driver.music.played.last, MusicCue.win);
      // Closing on a result keeps its jingle.
      await tester.tap(find.text('다음 스테이지'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(driver.music.played.last, MusicCue.win);
    });

    testWidgets('a clear ended by warnings plays the win jingle at once', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.hold(tester, 16000);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      await driver.hold(tester, 700, HoldReading.ok);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      expect(find.byKey(const ValueKey('hold-whistle')), findsOneWidget);
      expect(find.text('실패!'), findsNothing);
      expect(driver.music.played.last, MusicCue.win);
      await tester.pump(HoldTiming.endShow);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('클리어!'), findsOneWidget);
    });

    testWidgets('a second warning with no star plays the lose jingle at once', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.warn(tester, HighPlankFaults.kneeDown);
      await driver.hold(tester, 700, HoldReading.ok);
      await driver.hold(tester, 600, const HoldReading.broken(_low));
      expect(driver.music.played.last, MusicCue.lose);
      await tester.pump(HoldTiming.endShow);
      await tester.pump(const Duration(milliseconds: 100));
      expect(driver.music.played.last, MusicCue.lose);
    });

    testWidgets('leaving before a result brings the menu music back', (
      tester,
    ) async {
      final left = _Driver();
      await left.open(tester);
      await left.go(tester);
      await left.hold(tester, 1000);
      await tester.tap(find.bySemanticsLabel('게임 나가기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.descendant(
          of: find.byType(ExitDialog),
          matching: find.text('게임 나가기'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(left.exit, HoldStageExit.left);
      expect(left.music.played.last, MusicCue.menu);
    });
  });

  group('the chair pose\'s drawings, with a stand-in bundle', () {
    testWidgets('its briefing icon, words and checks', (tester) async {
      final driver = _Driver(stage: 5, pose: _chair);
      await driver.open(tester);
      expect(find.text('의자 자세'), findsOneWidget);
      expect(find.text('최대 20초'), findsOneWidget);
      expect(find.text('엉덩이 높이'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter is HoldPoseIconPainter &&
              (w.painter! as HoldPoseIconPainter).pose == HoldSilhouette.sit,
        ),
        findsOneWidget,
      );
    });

    for (final (fault, words) in [(_low, '더\n앉아요'), (_spread, '무릎\n벌려요')]) {
      testWidgets('its warning ${fault.id}: words, icon and figure', (
        tester,
      ) async {
        final driver = _Driver(stage: 5, pose: _chair);
        await driver.open(tester);
        await driver.go(tester);
        // Entered: held for a while starts the time.
        await driver.hold(tester, 700, HoldReading.ok);
        await driver.warn(tester, fault);
        expect(find.text(words), findsOneWidget);
        expect(
          tester.widget<HoldWarningIcon>(find.byType(HoldWarningIcon)).icon,
          fault.icon,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter is HoldWarningIconPainter &&
                (w.painter! as HoldWarningIconPainter).icon == fault.icon,
          ),
          findsOneWidget,
        );
        final silhouette = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('hold-silhouette')),
        );
        expect(
          (silhouette.painter! as HoldSilhouettePainter).pose,
          HoldSilhouette.sit,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('announcements', () {
    test('a screen reader hears short lines, never the clock', () {
      expect(
        holdAnnouncement(
          const HoldStageCue(
            HoldStageCueKind.warning,
            count: 1,
            fault: HighPlankFaults.kneeDown,
          ),
        ),
        '경고 1번, 무릎 떼요',
      );
      // The first two stars with the owner's cheer (effects spec 6).
      expect(
        holdAnnouncement(
          const HoldStageCue(HoldStageCueKind.star, count: 1, seconds: 20),
        ),
        '20초, 별 하나, 좋아!',
      );
      expect(
        holdAnnouncement(
          const HoldStageCue(HoldStageCueKind.star, count: 2, seconds: 30),
        ),
        '30초, 별 둘, 잘한다!',
      );
      expect(
        holdAnnouncement(
          const HoldStageCue(HoldStageCueKind.star, count: 3, seconds: 45),
        ),
        '45초, 별 셋',
      );
      expect(
        holdAnnouncement(
          const HoldStageCue(HoldStageCueKind.callout, words: '실패!'),
        ),
        '실패!',
      );
      expect(
        holdAnnouncement(const HoldStageCue(HoldStageCueKind.ended, count: 3)),
        '클리어, 별 셋',
      );
      expect(
        holdAnnouncement(const HoldStageCue(HoldStageCueKind.ended)),
        '실패',
      );
      expect(
        holdAnnouncement(const HoldStageCue(HoldStageCueKind.resumed)),
        '시간이 다시 흘러요',
      );
      expect(
        holdAnnouncement(const HoldStageCue(HoldStageCueKind.started)),
        '시작',
      );
      expect(holdClock(const Duration(seconds: 75)), '1:15');
    });
  });

  testWidgets('a stage that is not a hold stage does not open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HoldStageScreen(
          stage: 1,
          sounds: SoundServices.silent(),
          createViewModel: () => throw StateError('not reached'),
        ),
      ),
    );
    expect(tester.takeException(), isA<AssertionError>());
  });
}
