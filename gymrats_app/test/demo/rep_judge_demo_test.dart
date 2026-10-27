import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraImageData, CameraImageFormat, CameraImagePlane;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gymrats_app/demo/rep_judge_demo.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';

import '../support/fakes.dart';
import '../support/placed_phone.dart';
import '../support/pose_fixtures.dart';
import '../support/pushup_case_loader.dart';

/// The judge the demo is given in these tests: no smoothing.
const _fast = RepJudgeConfig(smoothingTau: Duration.zero);

void main() {
  testWidgets('the recorder form offers push-up sets only', (tester) async {
    await tester.pumpWidget(const RepJudgeDemoApp());
    expect(find.text('Push-up recorder'), findsOneWidget);
    expect(find.text('Normal push-ups'), findsOneWidget);
    expect(find.byKey(repsFieldKey), findsOneWidget);
    expect(find.text('Sit-up'), findsNothing);
    expect(find.text('Squat'), findsNothing);
  });

  testWidgets('setup then a valid rep shows +1 and the count', (tester) async {
    final harness = _Harness();
    await harness.openCounter(tester);

    await harness.feed(1500, pushUpFrame());
    await harness.feed(1800, pushUpFrame());
    expect(find.byKey(repPhaseKey), findsOneWidget);
    expect(find.textContaining('UP'), findsOneWidget);

    await harness.feed(1900, pushUpFrame(depth: 0.6));
    await harness.feed(2300, pushUpFrame(depth: 1.5));
    expect(find.textContaining('DOWN'), findsOneWidget);
    await harness.feed(2700, pushUpFrame());

    expect(find.byKey(validRepsKey), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(validRepsKey)).data, '1');
    expect(find.text('+1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('+1'), findsNothing);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(validRepsKey)).data, '0');
  });

  testWidgets('a shallow rep shows the reject reason', (tester) async {
    final harness = _Harness();
    await harness.openCounter(tester);
    await harness.feed(1500, pushUpFrame());
    await harness.feed(1800, pushUpFrame());
    await harness.feed(1900, pushUpFrame(depth: 0.9));
    await harness.feed(2300, pushUpFrame());

    expect(find.text('Go lower'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(validRepsKey)).data, '0');
    expect(tester.widget<Text>(find.byKey(invalidRepsKey)).data, 'Invalid 1');
  });

  testWidgets('stop ends the round and lists reject reasons', (tester) async {
    final harness = _Harness();
    await harness.openCounter(tester);
    await harness.feed(1500, pushUpFrame());
    await harness.feed(1800, pushUpFrame());
    await harness.feed(1900, pushUpFrame(depth: 0.9));
    await harness.feed(2300, pushUpFrame());

    await harness.stop();

    expect(find.byKey(roundResultKey), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(validRepsKey)).data, '0');
    expect(tester.widget<Text>(find.byKey(invalidRepsKey)).data, 'Invalid 1');
    expect(find.text('Go lower × 1'), findsOneWidget);
    expect(find.byKey(repPhaseKey), findsNothing);
  });

  testWidgets('the round ends with the same result after 30 seconds', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.openCounter(tester);
    await harness.feed(1500, pushUpFrame());
    await harness.feed(1800, pushUpFrame());
    await harness.feed(2200, pushUpFrame(depth: 0.6));
    await harness.feed(2600, pushUpFrame(depth: 1.5));
    await harness.feed(3000, pushUpFrame());
    expect(tester.widget<Text>(find.byKey(remainingTimeKey)).data, '0:28');

    await harness.feed(33000, pushUpFrame());
    await tester.pump();
    expect(find.text("Time's up"), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(validRepsKey)).data, '1');
    expect(find.text('No rejected reps'), findsOneWidget);
  });

  group('recording', () {
    testWidgets('stop saves every judged frame with the label and the result', (
      tester,
    ) async {
      final harness = _Harness();
      await harness.openCounter(
        tester,
        form: () async {
          await _enter(tester, find.byKey(repsFieldKey), '1');
          await _enter(tester, find.byKey(personFieldKey), 'HS');
          await _enter(tester, find.byKey(heightFieldKey), '175');
          await _enter(tester, find.byKey(armFieldKey), '62');
          await _enter(tester, find.byKey(shoulderFieldKey), '41');
          await _enter(tester, find.byKey(deviceFieldKey), 'S22');
          await _enter(tester, find.byKey(placementFieldKey), 'floor 1.5 m');
          await _enter(tester, find.byKey(noteFieldKey), 'first try');
        },
      );
      await harness.oneRep();
      await harness.stop();

      final (name, recording) = harness.saved.single;
      expect(name, '20261025-140312_S22_normal.json');
      expect(recording.id, '20261025-140312_S22_normal');
      expect(recording.recordedAt, _recordedAt);
      expect(recording.label.kind, CaseKind.normal);
      expect(recording.label.reps, 1);
      expect(recording.label.note, 'first try');
      expect(recording.label.expected!.valid, 1);
      expect(recording.setup.person, 'HS');
      expect(recording.setup.heightCm, 175);
      expect(recording.setup.armCm, 62);
      expect(recording.setup.shoulderCm, 41);
      // The phone's raw gravity and the (blank) fake image's brightness.
      expect(recording.frames.first.gravity, [1.5, 9.6, 0.4]);
      expect(recording.frames.first.luma, 0);
      expect(recording.setup.device, 'S22');
      expect(recording.setup.placement, 'floor 1.5 m');
      expect(recording.setup.model, PoseDetectionModel.base);
      expect(recording.frontCamera, isTrue);
      expect(recording.frameRotation, 270);
      expect(
        [for (final f in recording.frames) f.at.inMilliseconds],
        [1500, 1800, 1900, 2300, 2700],
      );
      expect(recording.liveEvents.single.valid, isTrue);

      final replayed = replay(recording, config: _fast);
      expect(replayed.valid, liveResult(recording).valid);
      expect(replayed.matches(recording.label), isTrue);
      expect(recording.frames.first.fps, 1);
      final config = recording.judge['config']! as Map<String, Object?>;
      expect(config['smoothingTauMs'], 0);
      expect(config['bottomDepth'], 1.1);

      expect(find.text('Expected: 1 valid'), findsOneWidget);
      expect(
        find.text('Saved /fake/20261025-140312_S22_normal.json'),
        findsOneWidget,
      );
    });

    testWidgets('the chosen set, model, and round reach the recording', (
      tester,
    ) async {
      final harness = _Harness();
      await harness.openCounter(
        tester,
        form: () async {
          await tester.tap(find.byKey(caseKindKey));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Knees on the floor').last);
          await tester.pumpAndSettle();
          await _enter(tester, find.byKey(repsFieldKey), '3');
          await _tapVisible(tester, find.text('dim'));
          await _tapVisible(tester, find.text('accurate'));
          await _tapVisible(tester, find.text('60 s'));
          await tester.pump();
        },
      );
      expect(harness.counterArgs!.setup.model, PoseDetectionModel.accurate);
      expect(tester.widget<Text>(find.byKey(remainingTimeKey)).data, '1:00');
      expect(find.text('Knees on the floor'), findsOneWidget);

      await harness.oneRep();
      await harness.stop();
      final (name, recording) = harness.saved.single;
      expect(name, '20261025-140312_knees.json');
      expect(recording.label.kind, CaseKind.knees);
      expect(recording.label.expected!.rejected, {RejectReason.kneesDown: 3});
      expect(recording.setup.lighting, 'dim');
      expect(recording.setup.roundLength, const Duration(seconds: 60));
      expect(find.text('Expected: 3 × Knees up'), findsOneWidget);
    });

    testWidgets('reset starts the recording over', (tester) async {
      final harness = _Harness();
      await harness.openCounter(tester);
      await harness.feed(1500, pushUpFrame());
      await harness.feed(1800, pushUpFrame());
      await tester.tap(find.text('Reset'));
      await tester.pump();
      await harness.oneRep(start: 2000);
      await harness.stop();

      final recording = harness.saved.single.$2;
      expect(recording.frames.first.at, const Duration(milliseconds: 2000));
      expect(recording.frames, hasLength(5));
      expect(replay(recording, config: _fast).valid, 1);
      expect(liveResult(recording).valid, 1);
    });

    testWidgets('pose detection failing is recorded as an abandon', (
      tester,
    ) async {
      final harness = _Harness();
      await harness.openCounter(tester);
      await harness.feed(1500, pushUpFrame());
      await harness.feed(1800, pushUpFrame());
      await harness.feed(1900, pushUpFrame(depth: 0.6));
      await harness.feed(2000, null);
      await harness.feed(2600, null);
      await harness.feed(2700, null);
      await harness.feed(2800, pushUpFrame(depth: 1.5));
      await harness.feed(3200, pushUpFrame());
      await harness.stop();

      final recording = harness.saved.single.$2;
      final marks = recording.frames.where((f) => f.mark != null).toList();
      expect(marks.single.mark, FrameMark.abandon);
      expect(liveResult(recording).events, isEmpty);
      expect(replay(recording, config: _fast).events, isEmpty);
    });

    testWidgets('switching the camera is recorded as an abandon', (
      tester,
    ) async {
      final harness = _Harness();
      await harness.openCounter(tester);
      await harness.feed(1500, pushUpFrame());
      await harness.feed(1800, pushUpFrame());
      await harness.feed(1900, pushUpFrame(depth: 0.6));
      await tester.tap(find.byTooltip('Switch camera'));
      await tester.pump();
      await tester.pump();
      await harness.feed(2300, pushUpFrame(depth: 1.5));
      await harness.feed(2700, pushUpFrame());
      await harness.stop();

      final recording = harness.saved.single.$2;
      expect(recording.frames[3].mark, FrameMark.abandon);
      expect(
        replay(recording, config: _fast).valid,
        liveResult(recording).valid,
      );
    });

    testWidgets('retry after a detector error starts the recording over', (
      tester,
    ) async {
      final harness = _Harness();
      await harness.openCounter(tester);
      await harness.feed(1500, pushUpFrame());
      await harness.feed(1800, pushUpFrame());
      await harness.feed(2000, null);
      await harness.feed(5100, null);
      expect(find.text('Pose detection stopped working.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      await harness.oneRep(start: 6000);
      await harness.stop();

      final recording = harness.saved.single.$2;
      expect(recording.frames.first.at, const Duration(milliseconds: 6000));
      expect(recording.frames.where((f) => f.mark != null), isEmpty);
      expect(liveResult(recording).valid, 1);
      expect(replay(recording, config: _fast).valid, 1);
    });

    testWidgets('with saving off nothing is written', (tester) async {
      final harness = _Harness();
      await harness.openCounter(
        tester,
        form: () async {
          await _tapVisible(tester, find.byKey(recordSwitchKey));
          await tester.pump();
        },
      );
      await harness.oneRep();
      await harness.stop();
      expect(harness.saved, isEmpty);
      expect(find.byKey(saveStatusKey), findsNothing);
    });

    testWidgets('a round without frames saves nothing and says so', (
      tester,
    ) async {
      final harness = _Harness();
      await harness.openCounter(tester);
      await harness.stop();
      expect(harness.saved, isEmpty);
      expect(find.text('Nothing recorded'), findsOneWidget);
    });

    testWidgets('a failed save shows why', (tester) async {
      final harness = _Harness()..saveError = Exception('disk full');
      await harness.openCounter(tester);
      await harness.oneRep();
      await harness.stop();
      expect(find.text('Not saved: Exception: disk full'), findsOneWidget);
    });
  });

  group('brightness', () {
    CameraImage image(
      List<int> bytes, {
      int width = 4,
      int height = 2,
      int? bytesPerRow,
    }) => CameraImage.fromPlatformInterface(
      CameraImageData(
        format: const CameraImageFormat(ImageFormatGroup.nv21, raw: 17),
        width: width,
        height: height,
        planes: [
          CameraImagePlane(
            bytes: Uint8List.fromList(bytes),
            bytesPerRow: bytesPerRow ?? width,
            bytesPerPixel: 1,
          ),
        ],
      ),
    );

    test('the mean counts the luma bytes, not the colour bytes after them', () {
      // 4 x 2 luma bytes, then colour bytes that must not count.
      final frame = image([10, 20, 30, 40, 50, 60, 70, 80, 200, 200, 200, 200]);
      expect(meanLuma(frame, step: 1), 45);
      expect(meanLuma(frame, step: 4), 30);
      expect(meanLuma(image(const [], width: 0, height: 0)), isNull);
      // Rows padded to 4 bytes: the padding does not count.
      final padded = image(
        [10, 20, 99, 99, 30, 40, 99, 99],
        width: 2,
        bytesPerRow: 4,
      );
      expect(meanLuma(padded, step: 1), 25);
    });

    test('the meter keeps the last brightness over an empty frame', () {
      final meter = LumaMeter()..measure(image(List.filled(8, 120)));
      expect(meter.latest, 120);
      meter.measure(image(const [], width: 0, height: 0));
      expect(meter.latest, 120);
    });

    test('the metered camera measures each frame and passes it on', () async {
      final camera = FakeCameraService();
      final meter = LumaMeter();
      final metered = MeteredCamera(camera, meter);
      final seen = <CameraImage>[];
      await metered.start(seen.add);
      camera.onImage!(image(List.filled(8, 90)));
      expect(seen, hasLength(1));
      expect(meter.latest, 90);
      expect(metered.isFrontCamera, isTrue);
      expect(metered.canSwitchCamera, isTrue);
      expect(metered.rotationDegrees, 270);
      expect(metered.controller, isNull);
      expect(metered.preferredLens, CameraLensDirection.front);
      expect(await metered.requestPermission(), CameraPermission.granted);
      expect(await metered.openSettings(), isTrue);
      metered.selectNextCamera();
      expect(camera.switchCount, 1);
      await metered.stop();
      expect(camera.isStreaming, isFalse);
    });
  });

  test('a recording id is safe as a file name', () {
    expect(
      recordingId(
        DateTime(2026, 1, 2, 3, 4, 5),
        ' Galaxy S23 / PM ',
        CaseKind.halfRepHeadNod,
      ),
      '20260102-030405_Galaxy-S23-PM_halfRepHeadNod',
    );
    expect(
      recordingId(DateTime(2026, 1, 2, 3, 4, 5), '', CaseKind.normal),
      '20260102-030405_normal',
    );
  });
}

final _recordedAt = DateTime(2026, 10, 25, 14, 3, 12);

/// The form is a list taller than the test screen.
Future<void> _enter(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  // A focused field scrolls itself into view, and a scroll in progress
  // ignores taps.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

class _Harness {
  final setupCamera = FakeCameraService();
  final setupEstimator = FakePoseEstimator();
  final counterCamera = FakeCameraService();
  final counterEstimator = FakePoseEstimator();
  final saved = <(String, PushUpRecording)>[];

  /// A placed phone whose sensor the test drives.
  final gravity = StreamController<GravitySample>(sync: true);
  late final phoneTilt = PhoneTiltMonitor(samples: gravity.stream)
    ..isPropped = true
    ..isStill = true;
  Exception? saveError;
  CounterArgs? counterArgs;
  late WidgetTester tester;
  var now = Duration.zero;

  /// Fills the form with [form], then runs setup until the counter shows.
  Future<void> openCounter(
    WidgetTester tester, {
    Future<void> Function()? form,
  }) async {
    this.tester = tester;
    await tester.pumpWidget(
      RepJudgeDemoApp(
        createSetup: (exercise) => SetupViewModel(
          exercise: exercise,
          camera: setupCamera,
          estimator: setupEstimator,
          clock: () => now,
          phoneTilt: placedPhone(),
        ),
        createCounter: (args) {
          counterArgs = args;
          return RepCounterViewModel(
            camera: MeteredCamera(counterCamera, args.meter),
            estimator: counterEstimator,
            clock: args.clock,
            phoneTilt: args.phoneTilt,
            judge: args.judge,
            roundLength: args.setup.roundLength,
          );
        },
        phoneTilt: phoneTilt,
        clock: () => now,
        judgeConfig: _fast,
        now: () => _recordedAt,
        save: (name, contents) async {
          final error = saveError;
          if (error != null) throw error;
          saved.add((name, PushUpRecording.decode(contents)));
          return '/fake/$name';
        },
      ),
    );
    await form?.call();
    await _tapVisible(tester, find.byKey(startRecordingKey));
    await tester.pumpAndSettle();

    Future<void> feedSetup(int ms, PoseFrame frame) async {
      now = Duration(milliseconds: ms);
      setupEstimator.frames.add(frame);
      setupCamera.emit();
      await tester.pump();
      await tester.pump();
    }

    await feedSetup(0, standingFrame());
    await feedSetup(1500, standingFrame());
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.byKey(validRepsKey), findsOneWidget);
    // The counter listens now; one upright reading with no gyro.
    gravity.add(const GravitySample(1.5, 9.6, 0.4));
  }

  /// A null [frame] makes pose detection fail.
  Future<void> feed(int ms, PoseFrame? frame) async {
    now = Duration(milliseconds: ms);
    counterEstimator.frames.add(frame);
    counterCamera.emit();
    await tester.pump();
    await tester.pump();
  }

  /// Arms the judge and does one full rep, five frames from [start].
  Future<void> oneRep({int start = 1500}) async {
    await feed(start, pushUpFrame());
    await feed(start + 300, pushUpFrame());
    await feed(start + 400, pushUpFrame(depth: 0.6));
    await feed(start + 800, pushUpFrame(depth: 1.5));
    await feed(start + 1200, pushUpFrame());
  }

  /// Taps Stop and lets the save finish.
  Future<void> stop() async {
    await tester.tap(find.byKey(stopRoundKey));
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }
}
