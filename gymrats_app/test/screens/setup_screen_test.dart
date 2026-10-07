import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';

import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

/// Counts routes popped from the navigator.
class _PopCounter extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

void main() {
  late _PopCounter popCounter;
  setUp(() => popCounter = _PopCounter());

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
        navigatorObservers: [popCounter],
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

  testWidgets('no guide text bar, only floating back and switch buttons', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('Place the phone'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('allows landscape while open and restores portrait on leave', (
    tester,
  ) async {
    final calls = <List<dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments as List<dynamic>);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(tester);
    expect(calls, [
      [
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ],
    ]);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(calls.last, ['DeviceOrientation.portraitUp']);
  });

  testWidgets('rotating the screen reopens the camera', (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);
    expect(camera.startCount, 1);
    tester.view.physicalSize = const Size(2316, 1080);
    await tester.pumpAndSettle();
    expect(camera.startCount, 2);
    expect(camera.isStreaming, isTrue);
    // Same orientation again: no restart.
    tester.view.physicalSize = const Size(2300, 1080);
    await tester.pumpAndSettle();
    expect(camera.startCount, 2);
  });

  testWidgets('works in a landscape window', (tester) async {
    tester.view.physicalSize = const Size(2316, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);
    await feed(tester, 0, pushUpFrontFrame());
    await feed(tester, 1500, pushUpFrontFrame());
    expect(find.text('Ready! Starting in 3...'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('hands missing keeps Start disabled', (tester) async {
    await open(tester);
    final frame = standingFrame(
      move: {for (final l in handLandmarks) l: (500, 995)},
    );
    await feed(tester, 0, frame);
    expect(find.text('Hands not visible.'), findsOneWidget);
    await feed(tester, 2000, frame);
    expect(find.text('Hands not visible.'), findsOneWidget);
    expect(startButton(tester).onPressed, isNull);
  });

  testWidgets('not facing the camera keeps Start disabled', (tester) async {
    await open(tester);
    final frame = standingFrame(hide: faceLandmarks);
    await feed(tester, 0, frame);
    await feed(tester, 2000, frame);
    expect(find.text('Face the camera.'), findsOneWidget);
    expect(startButton(tester).onPressed, isNull);
  });

  testWidgets('staying Ready for 3 s finishes setup without a tap', (
    tester,
  ) async {
    await open(tester);
    await feed(tester, 0, standingFrame());
    await feed(tester, 1500, standingFrame());
    await feed(tester, 3000, standingFrame());
    expect(find.text('Ready! Starting in 2...'), findsOneWidget);
    expect(popped, isNull);
    await feed(tester, 4500, standingFrame());
    await tester.pumpAndSettle();
    expect(popped, ExerciseType.pushUp);
    expect(camera.isStreaming, isFalse);
  });

  testWidgets('auto start and a Start tap together pop only once', (
    tester,
  ) async {
    await open(tester);
    await feed(tester, 0, standingFrame());
    await feed(tester, 1500, standingFrame());
    await feed(tester, 4500, standingFrame());
    // The pop has started; more frames arrive and the user taps Start
    // while the route is still animating out.
    await feed(tester, 4600, standingFrame());
    // Call the handler directly: a real tap would hit-test through the
    // closing route and could press the button behind it.
    startButton(tester).onPressed?.call();
    await feed(tester, 4700, standingFrame());
    await tester.pumpAndSettle();
    expect(popCounter.pops, 1);
    expect(popped, ExerciseType.pushUp);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('leaving Ready cancels the auto start countdown', (tester) async {
    await open(tester);
    await feed(tester, 0, standingFrame());
    await feed(tester, 1500, standingFrame());
    await feed(tester, 2000, emptyFrame());
    await feed(tester, 2600, emptyFrame());
    expect(
      find.text('No one detected. Step into the camera view.'),
      findsOneWidget,
    );
    await feed(tester, 5000, emptyFrame());
    await tester.pumpAndSettle();
    expect(popped, isNull);
  });

  testWidgets('Ready enables Start, which returns the exercise', (
    tester,
  ) async {
    await open(tester);
    await feed(tester, 0, standingFrame());
    expect(find.text('Hold still...'), findsOneWidget);
    await feed(tester, 1500, standingFrame());
    expect(find.text('Ready! Starting in 3...'), findsOneWidget);
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

  /// Captures debugPrint output while [body] runs.
  Future<List<String>> captureLogs(Future<void> Function() body) async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    try {
      await body();
    } finally {
      debugPrint = original;
    }
    return logs;
  }

  testWidgets('debug tools log checker values and draw no text overlay', (
    tester,
  ) async {
    final logs = await captureLogs(() async {
      await open(tester, debug: true);
      await feed(tester, 0, emptyFrame());
      // Logs are throttled on real time (at most every 250 ms).
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await feed(tester, 1000, standingFrame());
    });
    expect(
      logs.where((l) => l.startsWith('pose_setup config |')),
      hasLength(1),
    );
    expect(logs.first, contains('minLikelihood=0.6'));
    expect(logs, contains(contains('reason=noPerson fps=')));
    expect(logs, contains(contains('reason=ready')));
    // No debug text or toggle on screen.
    expect(find.textContaining('reason'), findsNothing);
    expect(find.byTooltip('Debug overlay'), findsNothing);
    expect(find.byIcon(Icons.bug_report), findsNothing);
  });

  testWidgets('no debug logs unless requested', (tester) async {
    final logs = await captureLogs(() async {
      await open(tester);
      await feed(tester, 0, emptyFrame());
    });
    expect(logs.where((l) => l.startsWith('pose_setup')), isEmpty);
  });
}
