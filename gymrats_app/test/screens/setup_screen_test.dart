import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';

import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

void main() {
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late Duration now;
  ExerciseType? popped;

  setUp(() {
    camera = FakeCameraService();
    estimator = FakePoseEstimator();
    now = Duration.zero;
    popped = null;
  });

  /// Opens SetupScreen on top of a host page so it can pop a result.
  Future<void> open(WidgetTester tester, {bool debug = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.push<ExerciseType>(
                context,
                MaterialPageRoute(
                  builder: (_) => SetupScreen(
                    exercise: ExerciseType.pushUp,
                    showDebugTools: debug,
                    createViewModel: () => SetupViewModel(
                      exercise: ExerciseType.pushUp,
                      camera: camera,
                      estimator: estimator,
                      clock: () => now,
                    ),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> feed(WidgetTester tester, int ms, PoseFrame frame) async {
    now = Duration(milliseconds: ms);
    estimator.frames.add(frame);
    camera.emit();
    // One pump runs the frame's async work, the next renders the result.
    await tester.pump();
    await tester.pump();
  }

  FilledButton startButton(WidgetTester tester) => tester.widget(
    find.ancestor(of: find.text('Start'), matching: find.byType(FilledButton)),
  );

  testWidgets('shows the placement guide', (tester) async {
    await open(tester);
    expect(
      find.text(
        'Place the phone on the floor, facing your side, about 2 m away.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('permission denied shows explanation and Open settings', (
    tester,
  ) async {
    camera.permission = CameraPermission.denied;
    await open(tester);
    expect(find.text('Camera access needed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    expect(camera.settingsCount, 1);
  });

  testWidgets('permanently denied shows Open settings without Try again', (
    tester,
  ) async {
    camera.permission = CameraPermission.permanentlyDenied;
    await open(tester);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.textContaining('Allow it in Settings.'), findsOneWidget);
  });

  testWidgets('camera failure shows an error with Retry', (tester) async {
    camera.startError = const CameraUnavailableException('No camera found.');
    await open(tester);
    expect(find.text('Could not start the camera.'), findsOneWidget);
    expect(find.text('No camera found.'), findsOneWidget);
    camera.startError = null;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('3 s of detector failures shows an error with Retry', (
    tester,
  ) async {
    await open(tester);
    for (final ms in [0, 1500, 3000]) {
      now = Duration(milliseconds: ms);
      estimator.frames.add(null);
      camera.emit();
      await tester.pump();
      await tester.pump();
    }
    expect(find.text('Pose detection stopped working.'), findsOneWidget);
    expect(find.text('Tap Retry to restart the camera.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('Ready turns the border green', (tester) async {
    await open(tester);
    Color borderColor() {
      final box = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      return (box.decoration! as BoxDecoration).border!.top.color;
    }

    await feed(tester, 0, standingFrame());
    expect(borderColor(), isNot(Colors.greenAccent));
    await feed(tester, 1500, standingFrame());
    expect(borderColor(), Colors.greenAccent);
  });

  testWidgets('no person message and Start disabled', (tester) async {
    await open(tester);
    await feed(tester, 0, standingFrame());
    expect(find.text('Hold still...'), findsOneWidget);
    await feed(tester, 100, emptyFrame());
    expect(
      find.text('No one detected. Step into the camera view.'),
      findsOneWidget,
    );
    expect(startButton(tester).onPressed, isNull);
  });

  testWidgets('feet missing keeps Start disabled', (tester) async {
    await open(tester);
    final frame = standingFrame(
      move: {for (final l in feetLandmarks) l: (500, 995)},
    );
    await feed(tester, 0, frame);
    expect(find.text('Feet not visible.'), findsOneWidget);
    await feed(tester, 2000, frame);
    expect(find.text('Feet not visible.'), findsOneWidget);
    expect(startButton(tester).onPressed, isNull);
  });

  testWidgets('Ready enables Start, which returns the exercise', (
    tester,
  ) async {
    await open(tester);
    await feed(tester, 0, standingFrame());
    expect(find.text('Hold still...'), findsOneWidget);
    await feed(tester, 1500, standingFrame());
    expect(find.text('Ready! Press Start.'), findsOneWidget);
    expect(startButton(tester).onPressed, isNotNull);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(popped, ExerciseType.pushUp);
    expect(camera.isStreaming, isFalse);
    expect(estimator.closed, isTrue);
  });

  testWidgets('back button releases camera and detector', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(camera.isStreaming, isFalse);
    expect(estimator.closed, isTrue);
  });

  testWidgets('background releases the camera, resume restarts it', (
    tester,
  ) async {
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(camera.isStreaming, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(camera.isStreaming, isTrue);
    expect(camera.startCount, 2);
  });

  testWidgets('debug overlay shows checker values and can be hidden', (
    tester,
  ) async {
    await open(tester, debug: true);
    await feed(tester, 0, emptyFrame());
    expect(find.textContaining('reason: noPerson'), findsOneWidget);
    expect(find.textContaining('minLikelihood: 0.6'), findsOneWidget);
    await tester.tap(find.byTooltip('Debug overlay'));
    await tester.pump();
    expect(find.textContaining('reason: noPerson'), findsNothing);
  });

  testWidgets('no debug toggle unless requested', (tester) async {
    await open(tester);
    expect(find.byTooltip('Debug overlay'), findsNothing);
  });
}
