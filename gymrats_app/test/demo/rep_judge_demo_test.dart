import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/rep_judge_demo.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';

import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

void main() {
  testWidgets('demo picker lists only push-up', (tester) async {
    await tester.pumpWidget(const RepJudgeDemoApp());
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Sit-up'), findsNothing);
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
}

class _Harness {
  _Harness() {
    setupCamera = FakeCameraService();
    setupEstimator = FakePoseEstimator();
    counterCamera = FakeCameraService();
    counterEstimator = FakePoseEstimator();
  }

  late final FakeCameraService setupCamera;
  late final FakePoseEstimator setupEstimator;
  late final FakeCameraService counterCamera;
  late final FakePoseEstimator counterEstimator;
  late WidgetTester tester;
  var now = Duration.zero;

  Future<void> openCounter(WidgetTester tester) async {
    this.tester = tester;
    await tester.pumpWidget(
      RepJudgeDemoApp(
        createSetup: (exercise) => SetupViewModel(
          exercise: exercise,
          camera: setupCamera,
          estimator: setupEstimator,
          clock: () => now,
        ),
        createCounter: () => RepCounterViewModel(
          camera: counterCamera,
          estimator: counterEstimator,
          clock: () => now,
          judge: RepJudge(
            config: const RepJudgeConfig(smoothingTau: Duration.zero),
            clock: () => now,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Push-up'));
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
  }

  Future<void> feed(int ms, PoseFrame frame) async {
    now = Duration(milliseconds: ms);
    counterEstimator.frames.add(frame);
    counterCamera.emit();
    await tester.pump();
    await tester.pump();
  }
}
