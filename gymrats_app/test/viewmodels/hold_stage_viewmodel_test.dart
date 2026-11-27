import 'dart:async';
import 'dart:ui' show Size;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_progress.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/hold_progress.dart';
import 'package:gymrats_app/models/hold_reading.dart';
import 'package:gymrats_app/models/hold_record.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/feedback/hold_record_store.dart';
import 'package:gymrats_app/services/pose/chair_hold.dart';
import 'package:gymrats_app/services/pose/exercise_judge.dart';
import 'package:gymrats_app/services/pose/high_plank_hold.dart';
import 'package:gymrats_app/services/pose/hold_judge.dart';
import 'package:gymrats_app/services/pose/hold_pose_definition.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/viewmodels/hold_stage_viewmodel.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';

import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

/// The battle's setup, scripted: the test says what it shows, and every
/// call is counted. Nothing reaches a camera.
class _ScriptedSetup extends SetupViewModel {
  _ScriptedSetup(ExerciseType exercise, this.matcher)
    : super(
        exercise: exercise,
        camera: FakeCameraService(),
        estimator: FakePoseEstimator(),
        phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
      );

  final bool Function(PoseFrame, Size, bool) matcher;
  SetupState _shown = const SetupState();
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int releases = 0;
  Size? viewport;
  bool disposed = false;

  @override
  SetupState get state => _shown;

  void show(SetupState state) {
    _shown = state;
    notifyListeners();
  }

  @override
  Future<void> start() async => starts++;

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<void> releaseCamera() async => releases++;

  @override
  void setGuideViewport(Size size) => viewport = size;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// The guide lines' judge: counts its frames.
class _GuideJudge implements ExerciseRepJudge {
  int updates = 0;

  @override
  RepUpdate update(PoseFrame frame) {
    updates++;
    return const RepUpdate(snapshot: JudgeSnapshot(phase: RepPhase.up));
  }

  @override
  void reset() {}

  @override
  void abandon() {}

  @override
  double get minLikelihood => .6;

  @override
  double get passDepth => 1;
}

const _knee = HoldFault(id: 'knee', cue: ('무릎', '떼요'), icon: HoldIcon.knee);

/// A reader whose answer the test sets; it keeps the counting flags.
class _Reader implements HoldPoseReader {
  HoldReading answer = HoldReading.ok;
  final counting = <bool>[];

  @override
  HoldReading read(
    PoseFrame frame, {
    required Duration at,
    bool counting = false,
  }) {
    this.counting.add(counting);
    return answer;
  }
}

/// A reader that gives the guide lines itself, at the squat's bottom.
class _GuideReader extends _Reader implements HoldGuideReader {
  @override
  JudgeSnapshot get guide => JudgeSnapshot(
    phase: RepPhase.bottom,
    squatHipY: counting.length.toDouble(),
    squatKneeY: 500,
  );
}

HoldPoseDefinition _scripted(
  _Reader reader, {
  bool entry = false,
  HoldPose pose = HoldPose.plank,
  List<String> startWords = const [],
}) => HoldPoseDefinition(
  pose: pose,
  setupExercise: pose == HoldPose.plank
      ? ExerciseType.pushUp
      : ExerciseType.squat,
  createReader: () => reader,
  entry: entry,
  checks: const ['a'],
  faults: const [_knee],
  silhouette: HoldSilhouette.plank,
  guide: HoldGuide.chestHeight,
  startWords: startWords,
);

class _FailingStore implements ArcadeProgressStore {
  int records = 0;

  @override
  Future<ArcadeProgress> read(int accountId) async =>
      throw StateError('no storage');

  @override
  Future<void> write(int accountId, ArcadeProgress progress) async =>
      throw StateError('no storage');

  @override
  Future<ArcadeProgress> recordStage(int accountId, int number, int stars) {
    records++;
    throw StateError('no storage');
  }
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
);

/// A view model for [stage] on fake time, with its setups and cues.
class _Rig {
  _Rig(
    FakeAsync async, {
    int stage = 3,
    HoldPoseDefinition? definition,
    ArcadeProgressStore? store,
    int? accountId,
    HoldRecordStore? records,
    ExerciseRepJudge Function(ExerciseType exercise)? guideJudge,
  }) {
    viewModel = HoldStageViewModel(
      stage: stage,
      definition: definition,
      store: store,
      accountId: accountId,
      records: records,
      wallClock: () => DateTime(2026, 11, 26, 21, 10).add(async.elapsed),
      createSetup: (exercise, matcher) {
        final setup = _ScriptedSetup(exercise, matcher);
        setups.add(setup);
        return setup;
      },
      createGuideJudge: (exercise) {
        guideExercises.add(exercise);
        return guideJudge?.call(exercise) ?? guide;
      },
      clock: () => async.elapsed,
    );
    viewModel.cues.listen(cues.add);
  }

  late final HoldStageViewModel viewModel;
  final setups = <_ScriptedSetup>[];
  final guideExercises = <ExerciseType>[];
  final guide = _GuideJudge();
  final cues = <HoldStageCue>[];

  _ScriptedSetup get setup => setups.last;

  /// 자세 잡기, the 3·2·1 on one frame, and GO.
  void goAt(FakeAsync async) {
    viewModel.startPose();
    async.flushMicrotasks();
    setup.show(_running(frame: pushUpFrame()));
    setup.show(
      _running(frame: pushUpFrame(), startIn: const Duration(seconds: 2)),
    );
    setup.show(_running(frame: pushUpFrame(), started: true));
  }

  /// A new frame every 100 ms for [ms].
  void frames(FakeAsync async, int ms) {
    for (var t = 0; t < ms; t += 100) {
      async.elapse(const Duration(milliseconds: 100));
      setup.show(_running(frame: pushUpFrame()));
    }
    // The cues reach their listeners on the next microtask.
    async.flushMicrotasks();
  }
}

void main() {
  group('opening', () {
    test('opens on the briefing of its stage: pose, floor and owner', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        final viewModel = rig.viewModel;
        expect(viewModel.state.phase, HoldStagePhase.brief);
        expect(viewModel.stage.number, 3);
        expect(viewModel.stage.pose, HoldPose.plank);
        expect(viewModel.floor.number, 1);
        expect(viewModel.floor.owner, 'seal');
        expect(viewModel.definition, same(highPlankHold));
        expect(viewModel.setup, isNull);
        expect(viewModel.lastFrame, isNull);
        viewModel.dispose();
      });
    });

    test('a stage that is not a hold stage is stopped', () {
      expect(
        () => HoldStageViewModel(stage: 1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a chair stage opens on A5\'s chair pose', () {
      final viewModel = HoldStageViewModel(stage: 5);
      expect(viewModel.stage.pose, HoldPose.chair);
      expect(viewModel.definition, same(chairHold));
      viewModel.dispose();
    });
  });

  group('the owner\'s bubbles and the second warning (effects spec)', () {
    test('GO shows the pose\'s start words for 2 s, read out', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.goAt(async);
        async.flushMicrotasks();
        final callout = rig.viewModel.state.callout!;
        expect(callout.kind, HoldCalloutKind.start);
        expect(callout.lines, highPlankHold.startWords);
        expect(rig.cues.single.kind, HoldStageCueKind.callout);
        expect(rig.cues.single.words, '그대로 버텨!');
        rig.frames(async, 1900);
        expect(rig.viewModel.state.callout, isNotNull);
        rig.frames(async, 200);
        expect(rig.viewModel.state.callout, isNull);
        rig.viewModel.dispose();
      });
    });

    test('with an entry the start words stay until the time starts', () {
      fakeAsync((async) {
        final reader = _Reader()..answer = const HoldReading.broken(_knee);
        final rig = _Rig(
          async,
          stage: 5,
          definition: _scripted(
            reader,
            entry: true,
            pose: HoldPose.chair,
            startWords: const ['스쿼트 자세로', '버텨!'],
          ),
        );
        rig.goAt(async);
        rig.frames(async, 4000);
        expect(rig.viewModel.state.callout!.kind, HoldCalloutKind.start);
        expect(rig.viewModel.state.callout!.words, '스쿼트 자세로 버텨!');
        reader.answer = HoldReading.ok;
        rig.frames(async, 700);
        expect(rig.viewModel.state.progress.state, HoldState.holding);
        expect(rig.viewModel.state.callout, isNull);
        rig.viewModel.dispose();
      });
    });

    test('a warning takes the start bubble', () {
      fakeAsync((async) {
        final reader = _Reader()..answer = const HoldReading.broken(_knee);
        final rig = _Rig(
          async,
          definition: _scripted(reader, startWords: const ['그대로 버텨!']),
        );
        rig.goAt(async);
        rig.frames(async, 600);
        expect(rig.viewModel.state.progress.paused, isTrue);
        expect(rig.viewModel.state.callout, isNull);
        rig.viewModel.dispose();
      });
    });

    test('the first two stars are cheered for 2.4 s (HoldTiming.cheer, A8 '
        'spec 6), the third is not', () {
      fakeAsync((async) {
        final rig = _Rig(async); // Stage 3: 15, 20 and 30 s.
        rig.goAt(async);
        // The time runs from the first frame: the star on the last one.
        rig.frames(async, 15100);
        var callout = rig.viewModel.state.callout!;
        expect(callout.kind, HoldCalloutKind.cheer);
        expect(callout.star, 1);
        expect(callout.words, '좋아!');
        rig.frames(async, 2300);
        async.elapse(HoldTiming.cheer - const Duration(milliseconds: 2301));
        expect(rig.viewModel.state.callout, same(callout));
        async.elapse(const Duration(milliseconds: 1));
        expect(rig.viewModel.state.callout, isNull);
        rig.frames(async, 2600);
        callout = rig.viewModel.state.callout!;
        expect(callout.star, 2);
        expect(callout.words, '잘한다!');
        rig.frames(async, 11000);
        expect(rig.viewModel.state.phase, HoldStagePhase.result);
        expect(rig.viewModel.state.callout, isNull);
        // Each star once: no callout for the third.
        expect(
          rig.cues
              .where((c) => c.kind == HoldStageCueKind.star)
              .map((c) => c.count),
          [1, 2, 3],
        );
        rig.viewModel.dispose();
      });
    });

    test('a warning takes the cheer', () {
      fakeAsync((async) {
        final reader = _Reader();
        final rig = _Rig(async, definition: _scripted(reader));
        rig.goAt(async);
        rig.frames(async, 15200);
        expect(rig.viewModel.state.callout!.kind, HoldCalloutKind.cheer);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        expect(rig.viewModel.state.progress.paused, isTrue);
        expect(rig.viewModel.state.callout, isNull);
        rig.viewModel.dispose();
      });
    });

    test('a second warning with no star: 실패! for 1.5 s, nothing judged', () {
      fakeAsync((async) {
        final reader = _Reader();
        final rig = _Rig(async, definition: _scripted(reader));
        rig.goAt(async);
        rig.frames(async, 1000);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        reader.answer = HoldReading.ok;
        rig.frames(async, 700);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        async.flushMicrotasks();
        var state = rig.viewModel.state;
        expect(state.phase, HoldStagePhase.hold);
        expect(state.ending, isTrue);
        expect(state.stopped, isTrue);
        expect(state.callout!.kind, HoldCalloutKind.fail);
        expect(state.shownFault, _knee);
        expect(
          rig.cues.map((c) => c.kind).toList().sublist(rig.cues.length - 2),
          [HoldStageCueKind.warning, HoldStageCueKind.callout],
        );
        expect(rig.cues.last.words, '실패!');
        // Frames in the moment are not judged.
        final readings = reader.counting.length;
        reader.answer = HoldReading.ok;
        rig.frames(async, 1300);
        state = rig.viewModel.state;
        expect(reader.counting, hasLength(readings));
        expect(state.phase, HoldStagePhase.hold);
        expect(state.progress.warningCount, 2);
        rig.frames(async, 300);
        async.flushMicrotasks();
        state = rig.viewModel.state;
        expect(state.phase, HoldStagePhase.result);
        expect(state.ending, isFalse);
        expect(state.callout, isNull);
        expect(state.progress.warnings, [_knee, _knee]);
        expect(rig.cues.last.kind, HoldStageCueKind.ended);
        rig.viewModel.dispose();
      });
    });

    test('a second warning after a star: the whistle stays, then a clear', () {
      fakeAsync((async) {
        final reader = _Reader();
        final rig = _Rig(async, definition: _scripted(reader));
        rig.goAt(async);
        rig.frames(async, 16500);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        reader.answer = HoldReading.ok;
        rig.frames(async, 700);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        var state = rig.viewModel.state;
        expect(state.ending, isTrue);
        expect(state.stars.count, 1);
        expect(state.callout, isNull);
        async.elapse(HoldTiming.endShow);
        async.flushMicrotasks();
        state = rig.viewModel.state;
        expect(state.phase, HoldStagePhase.result);
        expect(state.stars.cleared, isTrue);
        rig.viewModel.dispose();
      });
    });

    test('leaving in the moment shows no result and keeps nothing', () {
      fakeAsync((async) {
        final reader = _Reader();
        final store = MemoryArcadeProgressStore();
        final rig = _Rig(
          async,
          definition: _scripted(reader),
          store: store,
          accountId: 7,
        );
        rig.goAt(async);
        // A star first, so a result would keep one.
        rig.frames(async, 16500);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        reader.answer = HoldReading.ok;
        rig.frames(async, 700);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        expect(rig.viewModel.state.ending, isTrue);
        rig.viewModel.leave();
        async.elapse(HoldTiming.endShow * 2);
        async.flushMicrotasks();
        expect(rig.viewModel.state.phase, HoldStagePhase.hold);
        late ArcadeProgress saved;
        store.read(7).then((p) => saved = p);
        async.flushMicrotasks();
        expect(saved.bestOf(3), 0);
        rig.viewModel.dispose();
      });
    });
  });

  group('setup and the 3·2·1', () {
    test('자세 잡기 opens the camera on the push-up setup, once', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.viewModel.startPose();
        rig.viewModel.startPose();
        async.flushMicrotasks();
        expect(rig.setups, hasLength(1));
        expect(rig.setup.exercise, ExerciseType.pushUp);
        expect(rig.setup.starts, 1);
        expect(rig.viewModel.state.phase, HoldStagePhase.setup);
        expect(rig.viewModel.setup, same(rig.setup));
        rig.viewModel.dispose();
      });
    });

    test('the setup counting down is the 3·2·1; a broken pose goes back', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.viewModel.startPose();
        async.flushMicrotasks();
        rig.setup.show(
          _running(frame: pushUpFrame(), startIn: const Duration(seconds: 2)),
        );
        expect(rig.viewModel.state.phase, HoldStagePhase.countdown);
        expect(rig.viewModel.state.startIn, const Duration(seconds: 2));
        rig.setup.show(_running(frame: pushUpFrame()));
        expect(rig.viewModel.state.phase, HoldStagePhase.setup);
        expect(rig.viewModel.state.startIn, isNull);
        rig.viewModel.dispose();
      });
    });

    test('frames of the 3·2·1 reach the reader only, counting', () {
      fakeAsync((async) {
        final reader = _Reader()..answer = const HoldReading.broken(_knee);
        final rig = _Rig(async, definition: _scripted(reader));
        rig.viewModel.startPose();
        async.flushMicrotasks();
        final frame = pushUpFrame();
        for (var i = 0; i < 3; i++) {
          async.elapse(const Duration(seconds: 1));
          rig.setup.show(
            _running(
              frame: frame,
              startIn: Duration(seconds: 3 - i),
            ),
          );
        }
        // The same frame shown again is read once.
        expect(reader.counting, [true]);
        async.elapse(const Duration(seconds: 1));
        rig.setup.show(_running(frame: pushUpFrame(), startIn: Duration.zero));
        expect(reader.counting, [true, true]);
        expect(rig.viewModel.state.progress.warnings, isEmpty);
        expect(rig.viewModel.state.progress.held, Duration.zero);
        expect(rig.guide.updates, 0);
        rig.viewModel.dispose();
      });
    });

    test('the guide viewport and crop reach the setup check', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.viewModel.setGuideViewport(const Size(400, 400));
        rig.viewModel.startPose();
        async.flushMicrotasks();
        rig.viewModel.setGuideViewport(const Size(412, 450));
        expect(rig.setup.viewport, const Size(412, 450));
        final frame = alignedPushUpSetupFrame();
        // The push-up guide matches only on the crop the camera box drew.
        expect(rig.setup.matcher(frame, const Size(412, 450), false), isFalse);
        rig.viewModel.setGuideCrop((
          guide: const Size(1, 1),
          visible: const Size(1, 1),
        ));
        expect(rig.setup.matcher(frame, const Size(412, 450), false), isTrue);
        rig.viewModel.dispose();
      });
    });

    test('a squat setup matches the standing guide on the whole picture', () {
      fakeAsync((async) {
        final rig = _Rig(
          async,
          stage: 5,
          definition: _scripted(_Reader(), pose: HoldPose.chair),
        );
        rig.viewModel.startPose();
        async.flushMicrotasks();
        expect(rig.setup.exercise, ExerciseType.squat);
        expect(
          rig.setup.matcher(emptyFrame(), const Size(1, 1), true),
          isFalse,
        );
        rig.viewModel.dispose();
      });
    });
  });

  group('the hold', () {
    test('GO starts the hold: frames are read and timed', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.goAt(async);
        expect(rig.viewModel.state.phase, HoldStagePhase.hold);
        expect(rig.viewModel.state.startIn, isNull);
        expect(rig.guideExercises, [ExerciseType.pushUp]);
        rig.frames(async, 2000);
        expect(
          rig.viewModel.state.progress.held,
          const Duration(milliseconds: 1900),
        );
        expect(rig.viewModel.lastFrame, isNotNull);
        expect(rig.guide.updates, 20);
        expect(rig.viewModel.state.guide.phase, RepPhase.up);
        rig.viewModel.dispose();
      });
    });

    test('held to the third star: three star cues, the end, stars kept', () {
      fakeAsync((async) {
        final store = MemoryArcadeProgressStore();
        final rig = _Rig(async, store: store, accountId: 7);
        rig.goAt(async);
        rig.frames(async, 31000);
        async.flushMicrotasks();
        final state = rig.viewModel.state;
        expect(state.phase, HoldStagePhase.result);
        expect(state.progress.end, HoldEnd.held);
        expect(state.progress.held, const Duration(seconds: 30));
        expect(state.stars.count, 3);
        expect(rig.cues.map((c) => (c.kind, c.count, c.seconds)), [
          (HoldStageCueKind.callout, 0, null), // The start words.
          (HoldStageCueKind.star, 1, 15),
          (HoldStageCueKind.star, 2, 20),
          (HoldStageCueKind.star, 3, 30),
          (HoldStageCueKind.ended, 3, null),
        ]);
        expect(rig.setup.releases, 1);
        late ArcadeProgress saved;
        store.read(7).then((p) => saved = p);
        async.flushMicrotasks();
        expect(saved.bestOf(3), 3);
        rig.viewModel.dispose();
      });
    });

    test('a reader that gives the guide lines draws them: no guide judge', () {
      fakeAsync((async) {
        final reader = _GuideReader();
        final rig = _Rig(async, definition: _scripted(reader));
        rig.goAt(async);
        rig.frames(async, 500);
        expect(rig.guideExercises, isEmpty);
        expect(rig.guide.updates, 0);
        final guide = rig.viewModel.state.guide;
        expect(guide.phase, RepPhase.bottom);
        expect(guide.squatHipY, reader.counting.length.toDouble());
        expect(guide.squatKneeY, 500);
        rig.viewModel.dispose();
      });
    });

    test('the push-up judge keeps the chest guide through a 60 s plank', () {
      fakeAsync((async) {
        // The real push-up judge, fed on the test's fake time. (The app's
        // judge keeps its own stopwatch.)
        final rig = _Rig(
          async,
          stage: 21, // 30, 45 and 60 s.
          guideJudge: (exercise) =>
              judgeFor(exercise, clock: () => async.elapsed),
        );
        rig.goAt(async);
        expect(rig.guideExercises, [ExerciseType.pushUp]);
        for (final seconds in [5, 15, 30, 45]) {
          rig.frames(async, seconds * 1000 - async.elapsed.inMilliseconds);
          final guide = rig.viewModel.state.guide;
          expect(guide.phase, RepPhase.up, reason: 'at $seconds s');
          expect(guide.topShoulderY, isNotNull, reason: 'at $seconds s');
        }
        rig.frames(async, 59900 - async.elapsed.inMilliseconds);
        expect(rig.viewModel.state.phase, HoldStagePhase.hold);
        expect(rig.viewModel.state.guide.phase, RepPhase.up);
        expect(rig.viewModel.state.guide.topShoulderY, isNotNull);
        rig.viewModel.dispose();
      });
    });

    test('an entry: the time starting is one started cue', () {
      fakeAsync((async) {
        final reader = _Reader()..answer = const HoldReading.broken(_knee);
        final rig = _Rig(
          async,
          stage: 5,
          definition: _scripted(reader, entry: true, pose: HoldPose.chair),
        );
        rig.goAt(async);
        rig.frames(async, 2000);
        expect(rig.viewModel.state.progress.state, HoldState.entering);
        expect(rig.cues, isEmpty);
        reader.answer = HoldReading.ok;
        rig.frames(async, 700);
        expect(rig.viewModel.state.progress.state, HoldState.holding);
        expect(rig.cues.map((c) => c.kind), [HoldStageCueKind.started]);
        // A warning and the time running again later: resumed, not started.
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        reader.answer = HoldReading.ok;
        rig.frames(async, 700);
        expect(rig.cues.map((c) => c.kind), [
          HoldStageCueKind.started,
          HoldStageCueKind.warning,
          HoldStageCueKind.resumed,
        ]);
        rig.viewModel.dispose();
      });
    });

    test('without an entry the time runs from GO, with no started cue', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.goAt(async);
        rig.frames(async, 2000);
        expect(rig.viewModel.state.progress.held, greaterThan(Duration.zero));
        // Only the start words: no started cue.
        expect(rig.cues.map((c) => c.kind), [HoldStageCueKind.callout]);
        rig.viewModel.dispose();
      });
    });

    test('a warning is a cue with its fault; held again, a resumed cue', () {
      fakeAsync((async) {
        final reader = _Reader();
        final rig = _Rig(async, definition: _scripted(reader));
        rig.goAt(async);
        rig.frames(async, 1000);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        expect(rig.viewModel.state.progress.paused, isTrue);
        expect(rig.cues.single.kind, HoldStageCueKind.warning);
        expect(rig.cues.single.count, 1);
        expect(rig.cues.single.fault, _knee);
        reader.answer = HoldReading.ok;
        rig.frames(async, 700);
        expect(rig.viewModel.state.progress.state, HoldState.holding);
        expect(rig.cues.last.kind, HoldStageCueKind.resumed);
        rig.viewModel.dispose();
      });
    });

    test('two warnings before a star: a fail, kept as no star', () {
      fakeAsync((async) {
        final reader = _Reader();
        final store = MemoryArcadeProgressStore();
        final rig = _Rig(
          async,
          definition: _scripted(reader),
          store: store,
          accountId: 7,
        );
        rig.goAt(async);
        rig.frames(async, 1000);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        reader.answer = HoldReading.ok;
        rig.frames(async, 700);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        // The second warning stays for its moment, then the result.
        expect(rig.viewModel.state.ending, isTrue);
        async.elapse(HoldTiming.endShow);
        async.flushMicrotasks();
        final state = rig.viewModel.state;
        expect(state.phase, HoldStagePhase.result);
        expect(state.progress.end, HoldEnd.warnings);
        expect(state.stars.count, 0);
        expect(state.stars.cleared, isFalse);
        expect(rig.cues.last.kind, HoldStageCueKind.ended);
        expect(rig.cues.last.count, 0);
        late ArcadeProgress saved;
        store.read(7).then((p) => saved = p);
        async.flushMicrotasks();
        expect(saved.bestOf(3), 0);
        rig.viewModel.dispose();
      });
    });

    test('ended by warnings, the stars count the time really held', () {
      fakeAsync((async) {
        final reader = _Reader();
        final rig = _Rig(async, definition: _scripted(reader));
        rig.goAt(async);
        rig.frames(async, 16000);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        reader.answer = HoldReading.ok;
        rig.frames(async, 700);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        final state = rig.viewModel.state;
        expect(state.progress.end, HoldEnd.warnings);
        expect(state.progress.held, greaterThan(const Duration(seconds: 15)));
        expect(state.progress.held, lessThan(const Duration(seconds: 20)));
        expect(state.stars.lit, [true, false, false]);
        expect(state.stars.cleared, isTrue);
        rig.viewModel.dispose();
      });
    });

    test('no frame for a while is an unknown pose: off screen, warned', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.goAt(async);
        rig.frames(async, 1000);
        final held = rig.viewModel.state.progress.held;
        async.elapse(const Duration(milliseconds: 1400));
        expect(rig.viewModel.state.progress.warnings, isEmpty);
        async.elapse(const Duration(milliseconds: 500));
        final progress = rig.viewModel.state.progress;
        expect(progress.warnings, [HoldFault.offScreen]);
        // Within the grace the held reading stood.
        expect(progress.held, greaterThan(held));
        rig.viewModel.dispose();
      });
    });

    test('while the camera is not running the hold\'s clock stands', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.goAt(async);
        rig.frames(async, 1000);
        final held = rig.viewModel.state.progress.held;
        rig.viewModel.pause();
        expect(rig.setup.pauses, 1);
        rig.setup.show(const SetupState(phase: SetupPhase.paused));
        async.elapse(const Duration(seconds: 10));
        expect(rig.viewModel.state.progress.warnings, isEmpty);
        expect(rig.viewModel.state.progress.held, held);
        rig.viewModel.resume();
        expect(rig.setup.resumes, 1);
        rig.setup.show(const SetupState(phase: SetupPhase.starting));
        rig.setup.show(_running());
        rig.frames(async, 1000);
        final after = rig.viewModel.state.progress;
        expect(after.warnings, isEmpty);
        expect(after.held, lessThan(held + const Duration(seconds: 2)));
        expect(after.held, greaterThan(held));
        rig.viewModel.dispose();
      });
    });

    test('a store that fails keeps the result on screen', () {
      fakeAsync((async) {
        final store = _FailingStore();
        final rig = _Rig(async, store: store, accountId: 7);
        rig.goAt(async);
        rig.frames(async, 31000);
        async.flushMicrotasks();
        expect(store.records, 1);
        expect(rig.viewModel.state.phase, HoldStagePhase.result);
        rig.viewModel.dispose();
      });
    });

    test('without an account nothing is kept', () {
      fakeAsync((async) {
        final store = MemoryArcadeProgressStore();
        final rig = _Rig(async, store: store);
        rig.goAt(async);
        rig.frames(async, 31000);
        async.flushMicrotasks();
        late ArcadeProgress saved;
        store.read(7).then((p) => saved = p);
        async.flushMicrotasks();
        expect(saved.totalStars, 0);
        rig.viewModel.dispose();
      });
    });
  });

  group('after the hold', () {
    test('다시 하기 goes back to the briefing with a new camera next time', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.goAt(async);
        rig.frames(async, 31000);
        final first = rig.setup;
        rig.viewModel.playAgain();
        expect(rig.viewModel.state.phase, HoldStagePhase.brief);
        expect(rig.viewModel.state.progress.held, Duration.zero);
        expect(rig.viewModel.setup, isNull);
        expect(first.disposed, isTrue);
        rig.viewModel.startPose();
        async.flushMicrotasks();
        expect(rig.setups, hasLength(2));
        expect(rig.viewModel.state.phase, HoldStagePhase.setup);
        rig.viewModel.dispose();
      });
    });

    test('playing again is only after a result', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.goAt(async);
        rig.viewModel.playAgain();
        expect(rig.viewModel.state.phase, HoldStagePhase.hold);
        rig.viewModel.dispose();
      });
    });

    test('leaving lets the camera go and stops looking for frames', () {
      fakeAsync((async) {
        final rig = _Rig(async);
        rig.goAt(async);
        rig.frames(async, 500);
        rig.viewModel.leave();
        expect(rig.setup.releases, 1);
        async.elapse(const Duration(seconds: 5));
        expect(rig.viewModel.state.progress.warnings, isEmpty);
        rig.viewModel.dispose();
        expect(rig.setup.disposed, isTrue);
        // Nothing happens after dispose.
        rig.viewModel.leave();
        rig.viewModel.startPose();
      });
    });
  });

  group('cues', () {
    test('a cue reads its kind and numbers', () {
      const cue = HoldStageCue(
        HoldStageCueKind.warning,
        count: 1,
        fault: _knee,
      );
      expect(cue.toString(), 'HoldStageCue(warning, 1, knee)');
      const state = HoldStageState();
      expect(state.copyWith(startIn: Duration.zero).startIn, Duration.zero);
      expect(
        state
            .copyWith(startIn: Duration.zero)
            .copyWith(clearStartIn: true)
            .startIn,
        isNull,
      );
    });

    test('the setup config the guide check uses is the setup\'s', () {
      expect(const SetupConfig().minLikelihood, .6);
    });
  });
  group('the play kept for its report (P13)', () {
    /// Holds [ms], then breaks the pose for 600 ms and holds again for 700.
    void warnOnce(_Rig rig, _Reader reader, FakeAsync async, int ms) {
      rig.frames(async, ms);
      reader.answer = const HoldReading.broken(_knee);
      rig.frames(async, 600);
      reader.answer = HoldReading.ok;
      rig.frames(async, 700);
    }

    test('two warnings after a star: the time held and from GO, both '
        'warnings with their moments, the pause between, saved with the '
        'result', () {
      fakeAsync((async) {
        final reader = _Reader();
        final records = InMemoryHoldRecordStore();
        final rig = _Rig(
          async,
          definition: _scripted(reader),
          records: records,
          accountId: 7,
        );
        rig.goAt(async);
        warnOnce(rig, reader, async, 16500);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        final record = rig.viewModel.state.record!;
        // Kept for the signed-in account: the phone's store is shared.
        expect(record.accountId, 7);
        expect(record.pose, HoldPose.plank);
        expect(record.stage, 3);
        expect(record.stars, 1);
        expect(record.starSeconds, rig.viewModel.stage.starSeconds);
        expect(record.endedByWarnings, isTrue);
        expect(record.warnings.map((w) => w.words), ['무릎 떼요', '무릎 떼요']);
        expect(record.warnings.map((w) => w.faultId), ['knee', 'knee']);
        expect(record.pauses, hasLength(1));
        final pause = record.pauses.single;
        expect(pause.start, record.warnings.first.at);
        expect(pause.length, greaterThan(Duration.zero));
        expect(record.held, rig.viewModel.state.progress.held);
        expect(record.elapsed, greaterThan(record.held));
        expect(record.endedAt.isAfter(DateTime(2026, 11, 26, 21, 10)), isTrue);
        // Not kept until the result.
        late List<HoldRecord> kept;
        records.list().then((r) => kept = r);
        async.flushMicrotasks();
        expect(kept, isEmpty);
        async.elapse(HoldTiming.endShow);
        async.flushMicrotasks();
        records.list().then((r) => kept = r);
        async.flushMicrotasks();
        expect(kept.single, same(record));
        rig.viewModel.dispose();
      });
    });

    test('every star without a warning: no warning, no pause, all stars', () {
      fakeAsync((async) {
        final reader = _Reader();
        final records = InMemoryHoldRecordStore();
        final rig = _Rig(
          async,
          definition: _scripted(reader),
          records: records,
        );
        rig.goAt(async);
        final last = rig.viewModel.stage.starSeconds.last;
        rig.frames(async, last * 1000 + 500);
        async.flushMicrotasks();
        final state = rig.viewModel.state;
        expect(state.phase, HoldStagePhase.result);
        final record = state.record!;
        expect(record.stars, rig.viewModel.stage.starSeconds.length);
        expect(record.warnings, isEmpty);
        expect(record.pauses, isEmpty);
        expect(record.endedByWarnings, isFalse);
        late List<HoldRecord> kept;
        records.list().then((r) => kept = r);
        async.flushMicrotasks();
        expect(kept, hasLength(1));
        rig.viewModel.dispose();
      });
    });

    test('a GO again starts a new log; 다시 하기 clears the record', () {
      fakeAsync((async) {
        final reader = _Reader();
        final rig = _Rig(async, definition: _scripted(reader));
        rig.goAt(async);
        warnOnce(rig, reader, async, 1000);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        async.elapse(HoldTiming.endShow);
        async.flushMicrotasks();
        expect(rig.viewModel.state.record!.warnings, hasLength(2));
        rig.viewModel.playAgain();
        expect(rig.viewModel.state.record, isNull);
        reader.answer = HoldReading.ok;
        rig.goAt(async);
        rig.frames(async, rig.viewModel.stage.starSeconds.last * 1000 + 500);
        async.flushMicrotasks();
        expect(rig.viewModel.state.record!.warnings, isEmpty);
        expect(rig.viewModel.state.record!.pauses, isEmpty);
        rig.viewModel.dispose();
      });
    });

    test('leaving keeps no record', () {
      fakeAsync((async) {
        final reader = _Reader();
        final records = InMemoryHoldRecordStore();
        final rig = _Rig(
          async,
          definition: _scripted(reader),
          records: records,
        );
        rig.goAt(async);
        warnOnce(rig, reader, async, 16500);
        reader.answer = const HoldReading.broken(_knee);
        rig.frames(async, 600);
        rig.viewModel.leave();
        async.elapse(HoldTiming.endShow * 2);
        async.flushMicrotasks();
        late List<HoldRecord> kept;
        records.list().then((r) => kept = r);
        async.flushMicrotasks();
        expect(kept, isEmpty);
        rig.viewModel.dispose();
      });
    });

    test('a record that cannot be saved still keeps the stars', () {
      fakeAsync((async) {
        final reader = _Reader();
        final store = MemoryArcadeProgressStore();
        final rig = _Rig(
          async,
          definition: _scripted(reader),
          store: store,
          accountId: 7,
          records: _FailingRecords(),
        );
        rig.goAt(async);
        rig.frames(async, rig.viewModel.stage.starSeconds.last * 1000 + 500);
        async.flushMicrotasks();
        late ArcadeProgress saved;
        store.read(7).then((p) => saved = p);
        async.flushMicrotasks();
        expect(saved.bestOf(3), 3);
        rig.viewModel.dispose();
      });
    });

    test('a record save that never finishes does not hold back the stars: '
        'they are saved first (송우현, 2026-11-26)', () {
      fakeAsync((async) {
        final reader = _Reader();
        final store = MemoryArcadeProgressStore();
        final rig = _Rig(
          async,
          definition: _scripted(reader),
          store: store,
          accountId: 7,
          records: _StuckRecords(),
        );
        rig.goAt(async);
        rig.frames(async, rig.viewModel.stage.starSeconds.last * 1000 + 500);
        async.flushMicrotasks();
        late ArcadeProgress saved;
        store.read(7).then((p) => saved = p);
        async.flushMicrotasks();
        expect(saved.bestOf(3), 3);
        rig.viewModel.dispose();
      });
    });
  });
}

/// A record store whose saves never finish.
class _StuckRecords implements HoldRecordStore {
  @override
  Future<void> save(HoldRecord record) => Completer<void>().future;

  @override
  Future<List<HoldRecord>> list() async => const [];
}

class _FailingRecords implements HoldRecordStore {
  @override
  Future<void> save(HoldRecord record) async => throw StateError('no files');

  @override
  Future<List<HoldRecord>> list() async => const [];
}
