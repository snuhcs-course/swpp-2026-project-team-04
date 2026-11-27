import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/hold_reading.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/screens/hold_stage_art.dart';
import 'package:gymrats_app/screens/hold_stage_screen.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/services/audio/sound_effects.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/pose/chair_hold.dart';
import 'package:gymrats_app/services/pose/exercise_judge.dart';
import 'package:gymrats_app/services/pose/hold_judge.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/hold_stage_viewmodel.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';
import 'package:gymrats_app/widgets/pose_silhouette_squat.dart';
import 'package:gymrats_app/widgets/squat_height_overlay.dart';

import '../../support/audio_fakes.dart';
import '../../support/fakes.dart';
import '../../support/pose_fixtures.dart';

// The chair pose's stage on the hold screen, with the real chair bundle and
// reader: only the setup and the clock are scripted. A4's screen tests draw
// the chair pose with a stand-in bundle; these play STAGE 5 itself (arcade
// chair spec 7, "화면").

/// The battle's setup, scripted: the test says what it shows.
class _ScriptedSetup extends SetupViewModel {
  _ScriptedSetup(ExerciseType exercise, {this.camera})
    : super(
        exercise: exercise,
        camera: FakeCameraService(),
        estimator: FakePoseEstimator(),
        phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
      );

  /// A camera that is never opened: the camera box draws over it as over a
  /// picture.
  final CameraController? camera;

  SetupState _shown = const SetupState();

  @override
  SetupState get state => _shown;

  @override
  CameraController? get cameraController => camera;

  void show(SetupState state) {
    _shown = state;
    notifyListeners();
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> releaseCamera() async {}
}

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

/// A front view with the knees at y 700: standing, the hips 180 px above
/// them; seated at [depth], that much closer. The knees [kneeGap] px apart,
/// the ankles 100.
PoseFrame _legs({double depth = 0, double kneeGap = 100}) {
  final hipY = 700 - 180 * (1 - depth);
  return standingFrame(
    showHips: true,
    move: {
      BodyLandmark.leftHip: (530, hipY),
      BodyLandmark.rightHip: (470, hipY),
      BodyLandmark.leftKnee: (500 + kneeGap / 2, 700),
      BodyLandmark.rightKnee: (500 - kneeGap / 2, 700),
      BodyLandmark.leftAnkle: (550, 870),
      BodyLandmark.rightAnkle: (450, 870),
    },
  );
}

/// Drives STAGE 5 (1F, 10, 15 and 20 s) on a clock the test moves.
class _Driver {
  _Driver({this.withCamera = false});

  final bool withCamera;
  final effects = FakeSoundEffects();
  final store = MemoryArcadeProgressStore();
  final setups = <_ScriptedSetup>[];
  final guideJudges = <ExerciseType>[];
  final said = <String>[];
  Duration now = Duration.zero;
  late HoldStageViewModel viewModel;

  _ScriptedSetup get setup => setups.last;

  late final sounds = SoundServices(
    settings: SoundSettings(store: MemorySoundSettingsStore()),
    voice: const SilentVoiceGuidance(),
    music: const SilentBackgroundMusic(),
    effects: effects,
  );

  Widget screen() => HoldStageScreen(
    stage: 5,
    myCharacter: 'kangaroo',
    progressStore: store,
    accountId: 7,
    sounds: sounds,
    createViewModel: () => viewModel = HoldStageViewModel(
      stage: 5,
      store: store,
      accountId: 7,
      createSetup: (exercise, _) {
        final setup = _ScriptedSetup(
          exercise,
          camera: withCamera
              ? CameraController(
                  const CameraDescription(
                    name: 'front',
                    lensDirection: CameraLensDirection.front,
                    sensorOrientation: 270,
                  ),
                  ResolutionPreset.low,
                )
              : null,
        );
        setups.add(setup);
        return setup;
      },
      createGuideJudge: (exercise) {
        guideJudges.add(exercise);
        return judgeFor(exercise, clock: () => now);
      },
      clock: () => now,
    ),
  );

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen()));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// 자세 잡기, standing in the squat setup, a 3·2·1 of 3 s standing, GO.
  Future<void> go(WidgetTester tester) async {
    await tester.tap(find.text('자세 잡기'));
    await tester.pump();
    setup.show(_running(frame: _legs()));
    for (var ms = 3000; ms > 0; ms -= 100) {
      now += const Duration(milliseconds: 100);
      setup.show(
        _running(
          frame: _legs(),
          startIn: Duration(milliseconds: ms),
        ),
      );
    }
    setup.show(_running(frame: _legs(), started: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  /// A new frame every 100 ms for [ms].
  Future<void> frames(
    WidgetTester tester,
    int ms,
    PoseFrame Function() frame,
  ) async {
    for (var t = 0; t < ms; t += 100) {
      now += const Duration(milliseconds: 100);
      setup.show(_running(frame: frame()));
    }
    await tester.pump();
  }

  Future<void> sit(WidgetTester tester, int ms, {double kneeGap = 100}) =>
      frames(tester, ms, () => _legs(depth: .9, kneeGap: kneeGap));

  Future<void> stand(WidgetTester tester, int ms) => frames(tester, ms, _legs);
}

/// A widget test with the chair reader's debug print kept out of the test
/// output, and put back before the test's own checks of `debugPrint`.
void _testWidgets(String description, WidgetTesterCallback callback) =>
    testWidgets(description, (tester) async {
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      try {
        await callback(tester);
      } finally {
        debugPrint = print;
      }
    });

Color? _frameColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey('hold-frame')),
  );
  return ((box.decoration as BoxDecoration).border as Border).top.color;
}

void main() {
  group('the briefing', () {
    for (final size in [const Size(412, 915), const Size(360, 780)]) {
      _testWidgets('names the chair pose, its stars and its two checks at '
          '${size.width.toInt()} x ${size.height.toInt()}', (tester) async {
        final driver = _Driver();
        await driver.open(tester, size: size);
        expect(driver.viewModel.definition, same(chairHold));
        expect(find.text('STAGE 5 · 1F'), findsOneWidget);
        expect(find.text('의자 자세'), findsOneWidget);
        expect(find.text('최대 20초'), findsOneWidget);
        for (final seconds in ['10초', '15초', '20초']) {
          expect(find.text(seconds), findsOneWidget);
        }
        expect(find.text('엉덩이 높이'), findsOneWidget);
        expect(find.text('무릎 안 모으기'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter is HoldPoseIconPainter &&
                (w.painter! as HoldPoseIconPainter).pose == HoldSilhouette.sit,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  _testWidgets('자세 잡기 opens the squat battle\'s setup and its figure', (
    tester,
  ) async {
    final driver = _Driver();
    await driver.open(tester);
    await tester.tap(find.text('자세 잡기'));
    await tester.pump();
    driver.setup.show(_running(frame: _legs()));
    await tester.pump();
    expect(driver.setups.single.exercise, ExerciseType.squat);
    expect(find.byType(StandingSilhouetteGuide), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('entering and holding', () {
    _testWidgets('standing after GO: 0:00, 버틴 시간, a green frame, no warning', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.stand(tester, 5000);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('버틴 시간'), findsOneWidget);
      expect(find.text('멈춤'), findsNothing);
      expect(_frameColor(tester), AppColors.statusGood);
      expect(driver.viewModel.state.progress.warnings, isEmpty);
      // The entry has no time limit, so the leave button stays: it is the
      // way out (decision 9.3), on the screen and to a screen reader.
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('게임 나가기'), findsOneWidget);
      // The owner's two lines stay while entering (the effects spec 3).
      final bubble = find.byKey(const ValueKey('hold-start'));
      expect(
        find.descendant(of: bubble, matching: find.text('스쿼트 자세로')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bubble, matching: find.text('버텨!')),
        findsOneWidget,
      );
      expect(driver.said, ['스쿼트 자세로 버텨!']);
    });

    _testWidgets('seated, the time starts with "시작" and runs', (tester) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.stand(tester, 1000);
      // The first seated frame is still 0.71 deep; held from the second,
      // the time starts 0.6 s later.
      await driver.sit(tester, 700);
      await tester.pump();
      expect(driver.said, ['스쿼트 자세로 버텨!']);
      expect(find.byKey(const ValueKey('hold-start')), findsOneWidget);
      await driver.sit(tester, 100);
      await tester.pump();
      // The time starts: "시작", and the start bubble goes.
      expect(driver.said, ['스쿼트 자세로 버텨!', '시작']);
      expect(find.byKey(const ValueKey('hold-start')), findsNothing);
      await driver.sit(tester, 3000);
      expect(find.text('0:03'), findsOneWidget);
      expect(driver.said, ['스쿼트 자세로 버텨!', '시작']);
    });

    _testWidgets('the squat height lines stay over the camera past 12 s', (
      tester,
    ) async {
      final driver = _Driver(withCamera: true);
      await driver.open(tester);
      await driver.go(tester);
      await driver.sit(tester, 15000);
      expect(
        driver.viewModel.state.progress.held,
        greaterThan(const Duration(seconds: 14)),
      );
      final overlay = tester.widget<SquatHeightOverlay>(
        find.byType(SquatHeightOverlay),
      );
      expect(overlay.snapshot.phase, RepPhase.bottom);
      expect(overlay.snapshot.squatHipY, closeTo(700 - 18, 1e-9));
      expect(overlay.snapshot.squatKneeY, 700);
      // The reader draws them: no squat judge of their own.
      expect(driver.guideJudges, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  for (final (size, scale) in [
    (const Size(360, 780), 1.3),
    (const Size(320, 640), 1.3),
    (const Size(320, 640), 1.0),
  ]) {
    _testWidgets('the two-line start bubble and "좋아!" fit '
        '${size.width.toInt()} × ${size.height.toInt()} at ${scale}x text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final driver = _Driver();
      await driver.open(tester, size: size);
      await tester.ensureVisible(find.text('자세 잡기'));
      await tester.pump();
      await driver.go(tester);
      final bubble = find.byKey(const ValueKey('hold-start'));
      for (final line in ['스쿼트 자세로', '버텨!']) {
        expect(
          find.descendant(of: bubble, matching: find.text(line)),
          findsOneWidget,
        );
      }
      // The whole bubble on screen, its two lines inside it.
      final box = tester.getRect(bubble);
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(size.width));
      for (final line in ['스쿼트 자세로', '버텨!']) {
        final words = tester.getRect(
          find.descendant(of: bubble, matching: find.text(line)),
        );
        expect(box.left <= words.left && words.right <= box.right, isTrue);
      }
      expect(tester.takeException(), isNull);
      // Seated to the first star (10 s): the cheer.
      await driver.sit(tester, 10900);
      // The cheer comes 0.8 s after the star (A8 spec 6).
      await tester.pump(HoldTiming.cheerBubble);
      await tester.pump(HoldTiming.failPop);
      expect(find.text('좋아!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('warnings', () {
    for (final (name, words, icon, act) in [
      (
        'hips up',
        '더\n앉아요',
        HoldIcon.low,
        (_Driver d, WidgetTester t) => d.stand(t, 600),
      ),
      (
        'knees in',
        '무릎\n벌려요',
        HoldIcon.spread,
        (_Driver d, WidgetTester t) => d.sit(t, 600, kneeGap: 50),
      ),
      (
        'out of the picture',
        '화면\n안으로',
        HoldIcon.offScreen,
        // A frame without anyone in it, a new one each time.
        (_Driver d, WidgetTester t) => d.frames(
          t,
          1600,
          () => PoseFrame(
            imageWidth: imageSize,
            imageHeight: imageSize,
            keypoints: const {},
          ),
        ),
      ),
    ]) {
      _testWidgets('$name: the clock stops and the box says $words', (
        tester,
      ) async {
        final driver = _Driver();
        await driver.open(tester);
        await driver.go(tester);
        await driver.sit(tester, 2000);
        await act(driver, tester);
        await tester.pump();
        expect(find.text(words), findsOneWidget);
        expect(find.text('멈춤'), findsOneWidget);
        expect(
          tester.widget<HoldWarningIcon>(find.byType(HoldWarningIcon)).icon,
          icon,
        );
        expect(_frameColor(tester), AppColors.danger);
        expect(driver.effects.played, contains(SoundEffect.reject));
        expect(driver.said.last, '경고 1번, ${words.replaceAll('\n', ' ')}');
        // Seated again: the time runs again.
        await driver.sit(tester, 800);
        await tester.pump();
        expect(find.text(words), findsNothing);
        expect(driver.viewModel.state.progress.paused, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    _testWidgets('a second warning: no leave button until the result', (
      tester,
    ) async {
      final driver = _Driver();
      await driver.open(tester);
      await driver.go(tester);
      await driver.sit(tester, 2000);
      await driver.stand(tester, 600);
      await driver.sit(tester, 800);
      expect(find.bySemanticsLabel('게임 나가기'), findsOneWidget);
      await driver.stand(tester, 600);
      expect(driver.viewModel.state.ending, isTrue);
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
      expect(find.bySemanticsLabel('게임 나가기'), findsNothing);
      await tester.pump(HoldTiming.endShow - const Duration(milliseconds: 100));
      expect(driver.viewModel.state.ending, isTrue);
      expect(find.bySemanticsLabel('게임 나가기'), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('다시 도전'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  _testWidgets('held to the third star: a clear with three stars, kept', (
    tester,
  ) async {
    final driver = _Driver();
    await driver.open(tester);
    await driver.go(tester);
    await driver.sit(tester, 21000);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('클리어!'), findsOneWidget);
    expect((await driver.store.read(7)).bestOf(5), 3);
    expect(tester.takeException(), isNull);
  });
}
