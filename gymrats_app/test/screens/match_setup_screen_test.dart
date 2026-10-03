import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/screens/match_setup_screen.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
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

  /// Stacks the screens as the app does when setup opens: home, a page
  /// standing in for the versus screen, then MatchSetupScreen, whose result
  /// lands in [popped].
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Text('home')),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('versus')),
      ),
    );
    navigator
        .push(
          MaterialPageRoute<ExerciseType>(
            builder: (_) => MatchSetupScreen(
              exercise: ExerciseType.pushUp,
              createViewModel: () => SetupViewModel(
                exercise: ExerciseType.pushUp,
                camera: camera,
                estimator: estimator,
                clock: () => now,
              ),
            ),
          ),
        )
        .then((exercise) => popped = exercise);
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

  /// Opens the dialog with system back.
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  /// The 매칭 취소 button on top of SetupScreen; the dialog has its own.
  final cancelButton = find.ancestor(
    of: find.descendant(
      of: find.byType(MatchSetupScreen),
      matching: find.text('매칭 취소'),
    ),
    matching: find.bySubtype<FilledButton>(),
  );

  final dialogCancel = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('매칭 취소'),
  );

  /// SetupScreen's round button with [tooltip], tap area included.
  Finder setupButton(String tooltip) => find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(IconButton),
  );

  for (final size in const [Size(360, 640), Size(640, 360)]) {
    testWidgets('매칭 취소 sits at the top center, clear of Back and Switch camera '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      await open(tester, size: size);
      expect(find.byType(SetupScreen), findsOneWidget);
      final cancel = tester.getRect(cancelButton);
      expect(cancel.center.dx, moreOrLessEquals(size.width / 2));
      for (final tooltip in ['Back', 'Switch camera']) {
        final button = tester.getRect(setupButton(tooltip));
        expect(cancel.overlaps(button), isFalse, reason: tooltip);
        // On one line with SetupScreen's buttons.
        expect(cancel.center.dy, moreOrLessEquals(button.center.dy));
      }

      // SetupScreen's buttons still get their taps.
      await tester.tap(find.byTooltip('Switch camera'));
      await tester.pump();
      expect(camera.switchCount, 1);
    });
  }

  testWidgets('system back keeps the screen and asks; 계속하기 stays', (
    tester,
  ) async {
    await open(tester);
    await back(tester);
    expect(find.text('매칭을 취소할까요?'), findsOneWidget);
    expect(find.byType(MatchSetupScreen), findsOneWidget);

    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(MatchSetupScreen), findsOneWidget);
    expect(camera.isStreaming, isTrue);
    expect(popped, isNull);
  });

  testWidgets('SetupScreen\'s back button asks the same', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('매칭을 취소할까요?'), findsOneWidget);
    expect(find.byType(MatchSetupScreen), findsOneWidget);
  });

  testWidgets('매칭 취소 in the back dialog goes home, closing versus too', (
    tester,
  ) async {
    await open(tester);
    await back(tester);
    await tester.tap(dialogCancel);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('versus'), findsNothing);
    expect(find.byType(MatchSetupScreen), findsNothing);
    expect(popped, isNull);
    expect(camera.isStreaming, isFalse);
    expect(estimator.closed, isTrue);
  });

  testWidgets('the 매칭 취소 button goes home without asking', (tester) async {
    await open(tester);
    await tester.tap(cancelButton);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('versus'), findsNothing);
    expect(popped, isNull);
    expect(camera.isStreaming, isFalse);
  });

  testWidgets('Start pops with the exercise', (tester) async {
    await open(tester);
    await feed(tester, 0, standingFrame());
    await feed(tester, 1500, standingFrame());
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(popped, ExerciseType.pushUp);
    expect(find.text('versus'), findsOneWidget);
  });

  testWidgets('setup finishing under the dialog closes it and passes the '
      'exercise on', (tester) async {
    await open(tester);
    await back(tester);
    // The user ignores the dialog and holds Ready until the auto start.
    for (final ms in [0, 1500, 3000, 4500]) {
      await feed(tester, ms, standingFrame());
    }
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(popped, ExerciseType.pushUp);
    expect(find.text('versus'), findsOneWidget);
  });

  testWidgets('a frame arriving after 매칭 취소 cannot finish setup and pop '
      'home', (tester) async {
    await open(tester);
    for (final ms in [0, 1500, 3000]) {
      await feed(tester, ms, standingFrame());
    }
    expect(find.text('Ready! Starting in 2...'), findsOneWidget);
    await tester.tap(cancelButton);
    await tester.pump();
    // The screen is sliding away; this frame would end the countdown.
    await feed(tester, 4500, standingFrame());
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(popped, isNull);
  });
}
