import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/battle_demo.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/matching/bot_matchmaker.dart';
import 'package:gymrats_app/widgets/landmark_overlay.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';

void main() {
  testWidgets('opens the battle at once; a tap on the camera counts a rep, '
      'a long press rejects one', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const BattleDemoApp(roundLength: Duration(seconds: 20)),
    );
    // The first battle opens after the first frame.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BattleScreen), findsOneWidget);
    // The shorter round. The stand-in camera runs on real time.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data == '0:20' || widget.data == '0:19'),
      ),
      findsOneWidget,
    );
    // The stand-in pose shows as dots.
    expect(find.byType(LandmarkOverlay), findsOneWidget);

    final camera = tester.getCenter(find.byType(PoseCameraView));
    await tester.tapAt(camera);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('+1 GOOD'), findsOneWidget);

    // The reasons take turns.
    for (final reason in ['가슴을 더 내려요', '팔을 끝까지 펴요']) {
      await tester.longPressAt(camera);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('카운트 안 됨'), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
    }

    // Touches outside the camera count nothing.
    await tester.tapAt(tester.getCenter(find.text('남은 시간')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('팔을 끝까지 펴요'), findsOneWidget);
    expect(find.text('+1 GOOD'), findsNothing);
  });

  testWidgets('leaving the battle comes back to the demo home', (tester) async {
    await tester.pumpWidget(const BattleDemoApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(find.text('게임 나가기'));
    await tester.pumpAndSettle();
    expect(find.byType(BattleScreen), findsNothing);
    expect(find.text('배틀 데모'), findsOneWidget);
    expect(find.text('경기 시간 60초'), findsOneWidget);
    expect(find.text('배틀 시작'), findsOneWidget);
  });

  testWidgets('the result screen shows; 다시 매칭 opens the next battle', (
    tester,
  ) async {
    await tester.pumpWidget(const BattleDemoApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // What the battle does when time is up. A demo round runs on real
    // time, so the test does not wait for it.
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushReplacementNamed(
          GymRatsApp.resultRoute,
          arguments: BattleResult(
            matchup: const Matchup(
              exercise: ExerciseType.pushUp,
              playerName: '우현',
              opponent: BotMatchmaker.bot,
            ),
            myReps: 8,
            myInvalidReps: 1,
            opponentReps: 7,
            endedAt: DateTime(2026, 10, 4, 14, 32),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);

    await tester.tap(find.text('다시 매칭'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ResultScreen), findsNothing);
    expect(find.byType(BattleScreen), findsOneWidget);
  });
}
