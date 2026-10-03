import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/screens/match_setup_screen.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/exit_game_button.dart';

import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

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
              matchup: _matchup,
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

  /// The 게임 나가기 button on top of SetupScreen.
  final exitButton = find.byType(ExitGameButton);

  /// The dialog's 게임 나가기, not the button on the screen.
  final dialogExit = find.descendant(
    of: find.byType(ExitDialog),
    matching: find.text('게임 나가기'),
  );

  /// The ways to open the dialog, each pumped until it is shown.
  final asks = <(String, Future<void> Function(WidgetTester))>[
    (
      'system back',
      (tester) async {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      },
    ),
    (
      'SetupScreen\'s back button',
      (tester) async {
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      },
    ),
    (
      'the 게임 나가기 button',
      (tester) async {
        await tester.tap(exitButton);
        await tester.pumpAndSettle();
      },
    ),
  ];

  /// SetupScreen's round button with [tooltip], tap area included.
  Finder setupButton(String tooltip) => find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(IconButton),
  );

  for (final size in const [Size(360, 640), Size(640, 360)]) {
    testWidgets('게임 나가기 sits at the top center, clear of Back and Switch '
        'camera (${size.width.toInt()}x${size.height.toInt()})', (
      tester,
    ) async {
      await open(tester, size: size);
      expect(find.byType(SetupScreen), findsOneWidget);
      final exit = tester.getRect(exitButton);
      expect(exit.center.dx, moreOrLessEquals(size.width / 2));
      for (final tooltip in ['Back', 'Switch camera']) {
        final button = tester.getRect(setupButton(tooltip));
        expect(exit.overlaps(button), isFalse, reason: tooltip);
        // On one line with SetupScreen's buttons.
        expect(exit.center.dy, moreOrLessEquals(button.center.dy));
      }

      // SetupScreen's buttons still get their taps.
      await tester.tap(find.byTooltip('Switch camera'));
      await tester.pump();
      expect(camera.switchCount, 1);

      // The dialog fits too.
      await tester.tap(exitButton);
      await tester.pumpAndSettle();
      expect(find.byType(ExitDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, ask) in asks) {
    testWidgets('$name keeps the screen and asks; 계속하기 stays', (
      tester,
    ) async {
      await open(tester);
      await ask(tester);
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);
      expect(find.text('RepBot과의 대결이 취소되고\n홈으로 돌아가요.'), findsOneWidget);
      expect(find.byType(MatchSetupScreen), findsOneWidget);
      // Setup goes on under the dialog.
      expect(camera.isStreaming, isTrue);

      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
      expect(find.byType(ExitDialog), findsNothing);
      expect(find.byType(MatchSetupScreen), findsOneWidget);
      expect(camera.isStreaming, isTrue);
      expect(popped, isNull);
    });
  }

  for (final (name, ask) in [asks.first, asks.last]) {
    testWidgets('$name, then 게임 나가기 in the dialog, goes home, closing '
        'versus too', (tester) async {
      await open(tester);
      await ask(tester);
      await tester.tap(dialogExit);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.text('versus'), findsNothing);
      expect(find.byType(MatchSetupScreen), findsNothing);
      expect(popped, isNull);
      expect(camera.isStreaming, isFalse);
      expect(estimator.closed, isTrue);
    });

    testWidgets('setup finishing under the dialog from $name closes it and '
        'passes the exercise on', (tester) async {
      await open(tester);
      await ask(tester);
      // The user ignores the dialog and holds Ready until the auto start.
      for (final ms in [0, 1500, 3000, 4500]) {
        await feed(tester, ms, standingFrame());
      }
      await tester.pumpAndSettle();
      expect(find.byType(ExitDialog), findsNothing);
      expect(popped, ExerciseType.pushUp);
      expect(find.text('versus'), findsOneWidget);
    });
  }

  testWidgets('Start pops with the exercise', (tester) async {
    await open(tester);
    await feed(tester, 0, standingFrame());
    await feed(tester, 1500, standingFrame());
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(popped, ExerciseType.pushUp);
    expect(find.text('versus'), findsOneWidget);
  });

  testWidgets('a frame arriving after 게임 나가기 cannot finish setup and pop '
      'home', (tester) async {
    await open(tester);
    for (final ms in [0, 1500, 3000]) {
      await feed(tester, ms, standingFrame());
    }
    expect(find.text('Ready! Starting in 2...'), findsOneWidget);
    await tester.tap(exitButton);
    await tester.pumpAndSettle();
    await tester.tap(dialogExit);
    await tester.pump();
    // The screen is sliding away; this frame would end the countdown.
    await feed(tester, 4500, standingFrame());
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(popped, isNull);
  });
}
