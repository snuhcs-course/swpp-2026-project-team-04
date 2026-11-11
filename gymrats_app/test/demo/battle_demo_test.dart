import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/battle_demo.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/reject_reason_korean.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/matching/bot_matchmaker.dart';
import 'package:gymrats_app/widgets/battle_arena.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
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
    expect(find.text('+10 GOOD'), findsOneWidget);

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
    expect(find.text('+10 GOOD'), findsNothing);
  });

  testWidgets('long presses take turns over the push-up reasons only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BattleDemoApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final camera = tester.getCenter(find.byType(PoseCameraView));
    final reasons = RejectReason.forExercise(ExerciseType.pushUp);
    for (final reason in [...reasons, reasons.first]) {
      await tester.longPressAt(camera);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(reason.koreanMessage), findsOneWidget);
    }
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
    expect(find.text('경기 시간 30초'), findsOneWidget);
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

  group('the fighting stage by itself', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const BattleDemoApp(stageFirst: true));
      await tester.pump();
    }

    /// One of the demo's event buttons. ("KO" is also written on the stage.)
    Finder button(String label) => find.widgetWithText(OutlinedButton, label);

    Future<void> press(WidgetTester tester, String label) async {
      await tester.ensureVisible(button(label));
      await tester.tap(button(label));
      await tester.pump();
    }

    BattleStageState state(WidgetTester tester) =>
        tester.widget<BattleStage>(find.byType(BattleStage)).state;

    BattleFxFrame frame(WidgetTester tester) =>
        tester.widget<BattleStage>(find.byType(BattleStage)).frame;

    testWidgets('STAGE_DEMO opens the stage with a button for every effect', (
      tester,
    ) async {
      await open(tester);
      expect(find.byType(BattleArena), findsOneWidget);
      expect(find.byType(BattleScreen), findsNothing);
      for (final label in [
        '내 Good',
        'Excellent',
        '콤보',
        'Average',
        '0점 거절',
        '상대 공격',
        '상대 헛스윙',
        '피버',
        '위험',
        'KO',
        '시간 종료',
        '자세 세팅',
        '상대 대기',
        '카운트다운',
        '재연결 중',
        '상대 끊김',
        '상대 퇴장',
        '내 연결 끊김 패배',
        '처음으로',
      ]) {
        expect(button(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the demo home has a way to it', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const BattleDemoApp(roundLength: Duration(seconds: 20)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // Leave the battle that opens by itself.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(find.text('게임 나가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('무대 연출 보기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BattleArena), findsOneWidget);
    });

    testWidgets('reps score by the rules of the game: good 10, a combo 15, '
        'and double in fever', (tester) async {
      await open(tester);
      await press(tester, '내 Good');
      expect(state(tester).myScore, 10);
      expect(state(tester).myReps, 1);
      await press(tester, '콤보');
      expect(state(tester).myScore, 25);
      await press(tester, '피버');
      await press(tester, '상대 공격');
      expect(state(tester).opponentScore, 20);
      await tester.pump(const Duration(milliseconds: 100));
      expect(frame(tester).me.pose, BattlePose.hit);
    });

    testWidgets('a rejected rep raises the sign, with another reason each '
        'time; an average rep earns 5', (tester) async {
      await open(tester);
      await press(tester, '0점 거절');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('무릎 떼기'), findsOneWidget);
      expect(state(tester).myScore, 0);
      await press(tester, '0점 거절');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('더 깊게'), findsOneWidget);
      await press(tester, 'Average');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('더 깊게 +5'), findsOneWidget);
      expect(state(tester).myScore, 5);
      expect(state(tester).myReps, 0);
    });

    testWidgets('KO plays to 결과 보기, which starts over', (tester) async {
      await open(tester);
      await press(tester, 'KO');
      expect(state(tester).end!.kind, BattleEndKind.knockout);
      expect(state(tester).myScore, 100);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('K.O.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.tap(find.text('결과 보기'));
      await tester.pump();
      expect(state(tester).end, isNull);
      expect(state(tester).myScore, 0);
      expect(find.text('K.O.'), findsNothing);
    });

    testWidgets('danger, time-up and the leaving endings', (tester) async {
      await open(tester);
      await press(tester, '위험');
      expect(state(tester).danger, isTrue);
      expect(state(tester).lead, -65);
      await press(tester, '시간 종료');
      expect(state(tester).end!.kind, BattleEndKind.timeUp);
      expect(state(tester).end!.winner, BattleSide.opponent);
      await press(tester, '처음으로');
      await press(tester, '상대 퇴장');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('상대가 나가서 이겼어요'), findsOneWidget);
      await press(tester, '처음으로');
      await press(tester, '내 연결 끊김 패배');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('연결이 끊겨서 졌어요'), findsOneWidget);
    });

    testWidgets('before the start: setting up, waiting, then the countdown', (
      tester,
    ) async {
      await open(tester);
      await press(tester, '자세 세팅');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('자세 세팅 중'), findsOneWidget);
      expect(find.text('준비'), findsOneWidget);
      await press(tester, '상대 대기');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('상대를 기다리는 중'), findsOneWidget);
      expect(find.text('준비 취소'), findsOneWidget);
      await press(tester, '카운트다운');
      await tester.pump(const Duration(milliseconds: 50));
      expect(state(tester).phase, BattleStagePhase.countdown);
      expect(find.text('3'), findsOneWidget);
      // The start timer of the demo fires after three seconds.
      await tester.pump(const Duration(milliseconds: 3100));
      expect(state(tester).phase, BattleStagePhase.playing);
    });

    testWidgets('the online states toggle', (tester) async {
      await open(tester);
      await press(tester, '재연결 중');
      expect(state(tester).reconnecting, isTrue);
      await press(tester, '상대 끊김');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('연결 끊김'), findsOneWidget);
      await press(tester, '상대 끊김');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('연결 끊김'), findsNothing);
    });
  });
}
