import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';

import '../../support/fakes.dart';

/// These are recorded Android ML Kit outputs from real video, not generated
/// pose motion. The fake replaces only camera/inference IO during replay.
PoseFrame _decode(Map<String, dynamic> source, List<dynamic> frame) {
  final joints = frame[2] as List<dynamic>?;
  return PoseFrame(
    imageWidth: (source['width'] as num).toDouble(),
    imageHeight: (source['height'] as num).toDouble(),
    keypoints: {
      if (joints != null)
        for (var i = 0; i < joints.length; i++)
          if (joints[i] != null)
            BodyLandmark.values[i]: Keypoint(
              landmark: BodyLandmark.values[i],
              x: (joints[i][0] as num).toDouble(),
              y: (joints[i][1] as num).toDouble(),
              likelihood: (joints[i][2] as num).toDouble(),
            ),
    },
  );
}

class _Replay {
  final baselineEvents = <(int, bool, String?)>[];
  final guardedEvents = <(int, bool, String?)>[];
  final frames = <({int ms, bool paused, bool published})>[];
}

Future<_Replay> _replay(
  WidgetTester tester,
  Map<String, dynamic> source, {
  int? confirmAt,
}) async {
  var now = Duration.zero;
  final result = _Replay();
  final exercise = source['exercise'] == 'squat'
      ? ExerciseType.squat
      : ExerciseType.pushUp;
  final cameras = [FakeCameraService(), FakeCameraService()];
  final estimators = [FakePoseEstimator(), FakePoseEstimator()];
  final counters = [
    for (var i = 0; i < 2; i++)
      RepCounterViewModel(
        camera: cameras[i],
        estimator: estimators[i],
        phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
        clock: () => now,
        // Exercise only the replay interval, independent of match timeout.
        roundLength: const Duration(hours: 1),
        enablePersonGuard: i == 1,
        exercise: exercise,
      ),
  ];
  for (var i = 0; i < 2; i++) {
    final events = i == 0 ? result.baselineEvents : result.guardedEvents;
    counters[i].reps.listen((event) {
      events.add((now.inMilliseconds, event.valid, event.reason?.name));
    });
    await counters[i].start();
  }
  try {
    var locked = false;
    var previous = 0;
    for (final raw in source['frames'] as List<dynamic>) {
      final frame = raw as List<dynamic>;
      final ms = frame[1] as int;
      if (ms < (source['anchor_ms'] as int)) continue;
      now = Duration(milliseconds: ms);
      await tester.pump(Duration(milliseconds: ms - previous));
      previous = ms;
      final pose = _decode(source, frame);
      for (var i = 0; i < 2; i++) {
        estimators[i].frames.add(pose);
        cameras[i].emit();
      }
      await tester.pump();
      if (!locked) {
        // The selected first pose was visually confirmed as the exerciser.
        // Source videos do not contain the app's preparation screen.
        for (final counter in counters) {
          counter.reset(restartClock: true);
        }
        locked = true;
      }
      if (ms == confirmAt) counters[1].confirmTrackedPerson();
      final state = counters[1].state;
      result.frames.add((
        ms: ms,
        paused: state.trackingPaused,
        published: state.lastFrame?.hasPerson ?? false,
      ));
      if (state.trackingPaused) {
        expect(state.lastFrame?.hasPerson ?? false, isFalse);
      }
    }
  } finally {
    for (final counter in counters) {
      counter.dispose();
    }
    await tester.pump();
  }
  return result;
}

void main() {
  final fixture = jsonDecode(
    utf8.decode(
      gzip.decode(
        File('test/fixtures/person_behind/reviewed_native.json.gz')
            .readAsBytesSync(),
      ),
    ),
  ) as Map<String, dynamic>;
  final sources = {
    for (final source in fixture['sources'] as List<dynamic>)
      source['source_id'] as String: source as Map<String, dynamic>,
  };

  testWidgets('real wrong-person stream is withheld until confirmation', (
    tester,
  ) async {
    final result = await _replay(tester, sources['OLD-O027']!);
    bool wrongPerson(int ms) =>
        (ms >= 800 && ms <= 16067) || (ms >= 16600 && ms <= 18267);
    final wrong = result.frames.where((frame) => wrongPerson(frame.ms));
    // All 256 frames in these intervals were independently reviewed from
    // the guard results, with native shoulders drawn on the original video.
    expect(wrong, hasLength(256));
    expect(wrong.every((frame) => frame.paused && !frame.published), isTrue);
    expect(result.baselineEvents.where((e) => wrongPerson(e.$1)), hasLength(7));
    expect(result.guardedEvents, isEmpty);
    expect(result.frames.firstWhere((frame) => frame.paused).ms, 267);
    // The real user returning alone must not silently dismiss the warning.
    expect(result.frames.last.paused, isTrue);
  });

  testWidgets('explicit confirmation resumes a returned real-video user', (
    tester,
  ) async {
    final result = await _replay(
      tester,
      sources['OLD-O027']!,
      confirmAt: 19067,
    );
    expect(
      result.frames
          .where((f) => f.ms < 19067 && f.ms >= 267)
          .every((f) => f.paused),
      isTrue,
    );
    expect(result.frames.firstWhere((f) => f.ms == 19133).published, isTrue);
    // Later source blur/gaps can interrupt attempts again. This clip proves
    // pose recovery, not successful rep completion after confirmation.
    expect(
      result.frames
          .where((f) => f.ms > 19067 && !f.paused && f.published)
          .length,
      greaterThan(30),
    );
    expect(result.guardedEvents.every((event) => event.$1 > 19067), isTrue);
  });

  for (final id in [
    'S2-D015-G',
    'S2-D015-B',
    'S2-SQUAT-MULTI',
    'S2-SQUAT-CONTROL',
  ]) {
    testWidgets('$id retains the original user and judge events', (
      tester,
    ) async {
      final result = await _replay(tester, sources[id]!);
      expect(result.frames, isNotEmpty);
      expect(result.frames.every((frame) => !frame.paused), isTrue);
      expect(result.guardedEvents, result.baselineEvents);
      if (id == 'S2-SQUAT-MULTI') {
        expect(result.guardedEvents.where((event) => event.$2), hasLength(3));
      }
      if (id == 'S2-D015-G') expect(result.guardedEvents, hasLength(13));
    });
  }

  for (final id in ['OLD-O025', 'OLD-O048', 'S2-D009-G']) {
    testWidgets('$id resumes after brief uncertain native frames', (
      tester,
    ) async {
      final result = await _replay(tester, sources[id]!);
      final paused = result.frames.where((frame) => frame.paused).length;
      expect(paused, greaterThan(0));
      expect(paused, lessThanOrEqualTo(5));
      expect(result.frames.last.paused, isFalse);
      expect(result.frames.last.published, isTrue);
    });
  }

  testWidgets('blurred unstable control remains visibly paused', (
    tester,
  ) async {
    final result = await _replay(tester, sources['OLD-O033']!);
    expect(result.frames.where((frame) => frame.paused), isNotEmpty);
    expect(result.frames.last.paused, isTrue);
    expect(result.frames.last.published, isFalse);
    expect(result.guardedEvents, isEmpty);
  });
}
