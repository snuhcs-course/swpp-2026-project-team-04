import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/hold_reading.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/screens/arcade_flow.dart';
import 'package:gymrats_app/screens/hold_stage_screen.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
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
import 'package:gymrats_app/widgets/arcade_hold_music.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';

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

  @override
  SetupState get state => _shown;

  void show(SetupState state) {
    _shown = state;
    notifyListeners();
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> releaseCamera() async {}
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

/// The leave button, on the screen and in the semantics tree alike.
void _expectLeaveButton(Matcher matcher) {
  expect(find.byIcon(Icons.logout_rounded), matcher);
  expect(find.bySemanticsLabel('게임 나가기'), matcher);
}

/// A hold stage opened from the arcade: the screen [ArcadeFlow.holdScreen]
/// builds (A4's, with the app's sounds and its music in an
/// [ArcadeHoldMusic]), run on a scripted setup and pose reader and a clock
/// the test moves.
class _ArcadeHold {
  final reader = _Reader();
  final music = FakeBackgroundMusic();
  final store = MemoryArcadeProgressStore();
  final setups = <_ScriptedSetup>[];
  Duration now = Duration.zero;
  late HoldStageViewModel viewModel;
  HoldStageExit? exit;
  bool closed = false;

  _ScriptedSetup get setup => setups.last;

  late final HoldStageScreen fromArcade = ArcadeFlow.holdScreen(
    ArcadeCatalog.stage(3) as ArcadeHoldStage,
    myCharacter: 'kangaroo',
    store: store,
    accountId: 7,
    sounds: SoundServices(
      settings: SoundSettings(store: MemorySoundSettingsStore()),
      voice: const SilentVoiceGuidance(),
      music: music,
      effects: FakeSoundEffects(),
    ),
  );

  /// [fromArcade] as it is, its view model on the scripted setup.
  Widget screen() => HoldStageScreen(
    stage: fromArcade.stage,
    myCharacter: fromArcade.myCharacter,
    progressStore: fromArcade.progressStore,
    accountId: fromArcade.accountId,
    sounds: fromArcade.sounds,
    createViewModel: () => viewModel = HoldStageViewModel(
      stage: fromArcade.stage,
      definition: _plank(reader),
      store: fromArcade.progressStore,
      accountId: fromArcade.accountId,
      createSetup: (exercise, _) {
        final setup = _ScriptedSetup(exercise);
        setups.add(setup);
        return setup;
      },
      createGuideJudge: (_) => _GuideJudge(),
      clock: () => now,
    ),
  );

  /// Opens the screen over the map's place, at a phone's size.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
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
              child: const Text('map'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('map'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// 자세 잡기, the 3·2·1 and GO.
  Future<void> go(WidgetTester tester) async {
    await tester.tap(find.text('자세 잡기'));
    await tester.pump();
    setup.show(_running(frame: pushUpFrame()));
    setup.show(
      _running(
        frame: pushUpFrame(),
        startIn: const Duration(milliseconds: 1500),
      ),
    );
    await tester.pump();
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

  Future<void> tapAndClose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  test("the arcade's hold screen is A4's, its music in an ArcadeHoldMusic", () {
    final stage = _ArcadeHold().fromArcade;
    expect(stage.stage, 3);
    expect(stage.sounds!.music, isA<ArcadeHoldMusic>());
  });

  group("a second warning from the arcade: A4's hidden leave button with the "
      "arcade's music", () {
    for (final star in [false, true]) {
      testWidgets('${star ? 'after a star' : 'with no star'}: no leave button '
          'for the whole moment, the ${star ? 'win' : 'lose'} jingle from its '
          'start, and no menu track at the map after '
          '${star ? '다음 스테이지' : '아케이드로'}', (tester) async {
        final stage = _ArcadeHold();
        await stage.open(tester);
        await stage.go(tester);
        expect(stage.music.played.last, MusicCue.battle);
        if (star) {
          await stage.hold(tester, 16000);
        } else {
          await stage.hold(tester, 1000, HoldReading.ok);
        }
        await stage.hold(
          tester,
          600,
          const HoldReading.broken(HighPlankFaults.kneeDown),
        );
        await stage.hold(tester, 700, HoldReading.ok);
        _expectLeaveButton(findsOneWidget);
        await stage.hold(
          tester,
          600,
          const HoldReading.broken(HighPlankFaults.armBent),
        );
        expect(stage.viewModel.state.ending, isTrue);
        _expectLeaveButton(findsNothing);
        final jingle = star ? MusicCue.win : MusicCue.lose;
        expect(stage.music.played.last, jingle);
        await tester.pump(HoldTiming.endShow ~/ 2);
        _expectLeaveButton(findsNothing);
        expect(stage.music.played.last, jingle);
        await tester.pump(HoldTiming.endShow ~/ 2);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(star ? '클리어!' : '다시 도전'), findsOneWidget);
        _expectLeaveButton(findsNothing);
        await stage.tapAndClose(tester, star ? '다음 스테이지' : '아케이드로');
        expect(
          stage.exit,
          star ? HoldStageExit.nextStage : HoldStageExit.arcade,
        );
        // The jingle goes on at the map, as after a fight's result.
        expect(stage.music.played.last, jingle);
        expect(stage.music.played, isNot(contains(MusicCue.menu)));
      });
    }
  });

  testWidgets('before the end the leave button is there, and leaving from '
      'the arcade brings the menu track back', (tester) async {
    final stage = _ArcadeHold();
    await stage.open(tester);
    await stage.go(tester);
    await stage.hold(tester, 1000);
    _expectLeaveButton(findsOneWidget);
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
    expect(stage.exit, HoldStageExit.left);
    expect(stage.music.played.last, MusicCue.menu);
  });
}
