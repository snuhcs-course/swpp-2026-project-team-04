import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/pose_setup_demo.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';

import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

void main() {
  testWidgets('demo picker lists every exercise', (tester) async {
    await tester.pumpWidget(const PoseSetupDemoApp());
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Sit-up'), findsOneWidget);
    expect(find.text('Pull-up'), findsOneWidget);
  });

  testWidgets('picker -> Ready -> Start -> complete page -> picker', (
    tester,
  ) async {
    final camera = FakeCameraService();
    final estimator = FakePoseEstimator();
    var now = Duration.zero;
    await tester.pumpWidget(
      PoseSetupDemoApp(
        createViewModel: (exercise) => SetupViewModel(
          exercise: exercise,
          camera: camera,
          estimator: estimator,
          clock: () => now,
        ),
      ),
    );

    await tester.tap(find.text('Sit-up'));
    await tester.pumpAndSettle();
    expect(find.textContaining('about 1.5 m away'), findsOneWidget);

    Future<void> feed(int ms, PoseFrame frame) async {
      now = Duration(milliseconds: ms);
      estimator.frames.add(frame);
      camera.emit();
      await tester.pump();
      await tester.pump();
    }

    await feed(0, standingFrame());
    expect(find.textContaining('reason: ready'), findsOneWidget);
    await feed(1500, standingFrame());
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Setup complete: Sit-up'), findsOneWidget);
    expect(camera.isStreaming, isFalse);

    await tester.tap(find.text('Back to exercise picker'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an exercise'), findsOneWidget);
  });
}
