import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';
import 'package:gymrats_app/viewmodels/battle_viewmodel.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';

import '../../support/fakes.dart';
import 'squat_report_depth_test.dart' show pose;

void main() {
  test('AI and online squats produce four valid and two shallow reps with depth samples', () async {
    Future<FormReport> run({required bool bot}) async {
      var now = Duration.zero;
      final camera = FakeCameraService();
      final estimator = FakePoseEstimator();
      final phone = PhoneTiltMonitor(samples: const Stream.empty());
      final counter = bot
          ? BattleViewModel.botCounter(
              ExerciseType.squat,
              camera: camera,
              estimator: estimator,
              phoneTilt: phone,
              clock: () => now,
            )
          : RepCounterViewModel(
              exercise: ExerciseType.squat,
              camera: camera,
              estimator: estimator,
              phoneTilt: phone,
              clock: () => now,
            );
      addTearDown(counter.dispose);
      await counter.start();
      Future<void> hold(double hip, int frames) async {
        for (var i = 0; i < frames; i++) {
          estimator.frames.add(pose(hip));
          camera.emit();
          await pumpEventQueue();
          now += const Duration(milliseconds: 100);
        }
      }

      await hold(200, 5);
      for (final hip in [280.0, 280.0, 280.0, 280.0, 255.0, 255.0]) {
        await hold(hip, 5);
        await hold(200, 7);
      }
      expect(counter.state.validReps, 4);
      expect(counter.state.invalidReps, 2);
      expect(counter.repRecords, hasLength(6));
      expect(
        counter.repRecords.where((r) => !r.valid).map((r) => r.reason),
        everyElement(RejectReason.shallowSquat),
      );
      final depths = counter.formSamples
          .map((s) => s.depth)
          .whereType<double>();
      expect(depths, isNotEmpty);
      expect(depths.any((d) => d >= .75), isTrue);
      expect(depths.any((d) => d.abs() < .05), isTrue);
      final report = FormReport(
        endedAt: DateTime.utc(2026, 11, 14),
        opponentName: bot ? 'RepBot' : 'Opponent',
        exercise: ExerciseType.squat,
        roundLength: now,
        reps: counter.repRecords,
        samples: counter.formSamples,
      );
      final restored = FormReport.fromJson(report.toJson());
      expect(
        restored.samples.map((s) => s.depth),
        report.samples.map((s) => s.depth),
      );
      final findings = const FormAnalyzer().analyze(restored);
      expect(
        findings.singleWhere((f) => f.code == 'reject.shallowSquat').count,
        2,
      );
      return restored;
    }

    final bot = await run(bot: true);
    final online = await run(bot: false);
    expect(bot.reps.map((r) => r.toJson()), online.reps.map((r) => r.toJson()));
    expect(bot.samples.map((s) => s.depth), online.samples.map((s) => s.depth));
  });

  test(
    'the AI squat counter applies the online phone-movement rejection',
    () async {
      var now = Duration.zero;
      final camera = FakeCameraService();
      final estimator = FakePoseEstimator();
      final phone = PhoneTiltMonitor(samples: const Stream.empty());
      final counter = BattleViewModel.botCounter(
        ExerciseType.squat,
        camera: camera,
        estimator: estimator,
        phoneTilt: phone,
        clock: () => now,
      );
      addTearDown(counter.dispose);
      await counter.start();
      phone.isDisturbed = true;
      for (final hip in [
        ...List.filled(5, 200.0),
        ...List.filled(5, 280.0),
        ...List.filled(7, 200.0),
      ]) {
        estimator.frames.add(pose(hip));
        camera.emit();
        await pumpEventQueue();
        now += const Duration(milliseconds: 100);
      }
      expect(counter.state.validReps, 0);
      expect(counter.state.invalidReps, 1);
      expect(counter.history.single.reason, RejectReason.phoneMoved);
    },
  );
}
