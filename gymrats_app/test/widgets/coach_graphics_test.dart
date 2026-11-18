import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_goal.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/coach_script.dart';
import 'package:gymrats_app/services/feedback/goal_progress.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_reject_sign.dart';
import 'package:gymrats_app/widgets/coach_graphics.dart';
import 'package:gymrats_app/widgets/coach_parts.dart';

const _pace = CoachPaceGraphic(
  buckets: [5, 5, 2, 2, 2, 2],
  sliceSeconds: 5,
  usual: [3, 3, 2.7, 2.7, 2.3, 2.3],
  mark: CoachPaceMark.early,
);

const _form = CoachFormGraphic(
  reason: RejectReason.shallowSquat,
  word: '더 앉기',
  sentence: '엉덩이를 무릎 높이까지 내려요',
  count: 3,
  roundLength: Duration(seconds: 30),
  validTimes: [Duration(seconds: 1), Duration(seconds: 2)],
  rejectTimes: [
    Duration(milliseconds: 19400),
    Duration(milliseconds: 24200),
    Duration(milliseconds: 28800),
  ],
);

void main() {
  Future<void> show(
    WidgetTester tester,
    CoachGraphic graphic, {
    double textScale = 1,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Align(
              alignment: Alignment.topCenter,
              child: CoachGraphicCard(graphic: graphic),
            ),
          ),
        ),
      ),
    );
  }

  group('the score card', () {
    testWidgets('the count, the chip against the average and the bars, this '
        'battle in ink at the right', (tester) async {
      await show(
        tester,
        const CoachScoreGraphic(
          reps: 18,
          earlier: [14, 17, 15, 18, 16],
          average: 16,
        ),
      );
      expect(find.text('이번 판 인정 횟수'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('+2회'), findsOneWidget);
      expect(find.text('최근 5판 평균 16회'), findsOneWidget);
      expect(find.text('5판 전'), findsOneWidget);
      final last = tester.widget<Container>(
        find.byKey(const ValueKey('coach-score-bar-5')),
      );
      expect((last.decoration! as BoxDecoration).color, AppColors.ink);
      expect(
        tester.getSize(find.byKey(const ValueKey('coach-score-bar-5'))).height,
        CoachScoreCard.barsHeight,
      );
      expect(
        find.bySemanticsLabel('이번 판 인정 횟수 18회, 최근 5판 평균 16회'),
        findsOneWidget,
      );
    });

    testWidgets('without earlier battles: the count alone', (tester) async {
      await show(tester, const CoachScoreGraphic(reps: 9));
      expect(find.text('9'), findsOneWidget);
      expect(find.textContaining('평균'), findsNothing);
      expect(find.byKey(const ValueKey('coach-score-bar-0')), findsNothing);
    });

    test('the chip\'s words', () {
      expect(CoachScoreCard.differenceText(2), '+2회');
      expect(CoachScoreCard.differenceText(0), '±0회');
      expect(CoachScoreCard.differenceText(-3), '-3회');
    });
  });

  group('the pace card', () {
    testWidgets('six bars with their counts, the start lime with its chip, '
        'the times under them', (tester) async {
      await show(tester, _pace);
      expect(find.text('5초마다 인정 횟수'), findsOneWidget);
      expect(find.text('평소보다 빨라요'), findsOneWidget);
      expect(find.text('평소'), findsOneWidget);
      expect(find.text('0~5초'), findsOneWidget);
      expect(find.text('~30'), findsOneWidget);
      Color colorOf(int i) =>
          (tester
                      .widget<Container>(
                        find.byKey(ValueKey('coach-pace-bar-$i')),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(colorOf(0), AppColors.accent);
      expect(colorOf(2), AppColors.chartBar);
      // Five reps are 20 high each: the design's 100.
      expect(
        tester.getSize(find.byKey(const ValueKey('coach-pace-bar-0'))).height,
        100,
      );
    });

    testWidgets('the later part amber; many reps shrink to fit', (
      tester,
    ) async {
      await show(
        tester,
        const CoachPaceGraphic(
          buckets: [12, 11, 6, 5, 5, 4],
          sliceSeconds: 5,
          usual: [8, 8, 8, 8, 8, 8],
          mark: CoachPaceMark.late,
        ),
      );
      expect(find.text('평소보다 느려졌어요'), findsOneWidget);
      // Ink on the amber chip (palette B: text on a colored fill is ink).
      expect(
        tester.widget<Text>(find.text('평소보다 느려졌어요')).style!.color,
        AppColors.ink,
      );
      final bar = tester.widget<Container>(
        find.byKey(const ValueKey('coach-pace-bar-3')),
      );
      expect((bar.decoration! as BoxDecoration).color, AppColors.warning);
      expect(
        tester.getSize(find.byKey(const ValueKey('coach-pace-bar-0'))).height,
        lessThanOrEqualTo(CoachPaceCard.barsHeight - 16),
      );
      expect(tester.takeException(), isNull);
    });

    test('without earlier battles: the start\'s own pace, and the chip '
        'compares with it', () {
      const own = CoachPaceGraphic(
        buckets: [4, 2, 1, 1, 1, 1],
        sliceSeconds: 5,
        mark: CoachPaceMark.late,
      );
      expect(CoachPaceCard.levelsOf(own), everyElement(3));
      expect(CoachPaceCard.chipOf(own), '초반보다 느려졌어요');
      expect(CoachPaceCard.chipOf(_pace), '평소보다 빨라요');
      expect(
        CoachPaceCard.chipOf(
          const CoachPaceGraphic(buckets: [1, 1, 1, 1, 1, 1], sliceSeconds: 5),
        ),
        isNull,
      );
    });

    test('a KO round\'s times have one decimal', () {
      const ko = CoachPaceGraphic(
        buckets: [2, 2, 1, 1, 1, 1],
        sliceSeconds: 17 / 6,
      );
      expect(CoachPaceCard.timesOf(ko).first, '0~2.8초');
      expect(CoachPaceCard.timesOf(ko).last, '~17');
    });

    test('read as one sentence: each slice and its usual count (spec 7)', () {
      expect(
        CoachGraphicCard.sentenceOf(_pace),
        startsWith('5초마다 인정 횟수, 0~5초 5회, 평소 3회, 5~10초 5회, 평소 3회'),
      );
      expect(CoachGraphicCard.sentenceOf(_pace), endsWith('평소보다 빨라요'));
    });
  });

  group('the form card', () {
    testWidgets('the pictogram, the short words on red, × 3, the sentence and '
        'the time line', (tester) async {
      await show(tester, _form);
      expect(find.text('더 앉기'), findsOneWidget);
      expect(find.text('× 3'), findsOneWidget);
      expect(find.text('엉덩이를 무릎 높이까지 내려요'), findsOneWidget);
      expect(find.text('후반에 3번'), findsOneWidget);
      expect(find.text('15초'), findsOneWidget);
      expect(find.text('30초'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is BattleRejectIconPainter,
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('더 앉기 3회, 엉덩이를 무릎 높이까지 내려요'),
        findsOneWidget,
      );
    });

    testWidgets('another issue: no pictogram and no count', (tester) async {
      await show(
        tester,
        const CoachFormGraphic(
          word: '후반 깊이 감소',
          sentence: '전반 평균 1.20 → 후반 0.80',
          roundLength: Duration(seconds: 30),
          validTimes: [],
        ),
      );
      expect(find.text('후반 깊이 감소'), findsOneWidget);
      expect(find.textContaining('×'), findsNothing);
      expect(find.textContaining('후반에'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is BattleRejectIconPainter,
        ),
        findsNothing,
      );
    });

    test('the time line: 0 at the left, the end at the right, clamped', () {
      const painter = CoachTimeLinePainter(_form);
      expect(painter.xOf(Duration.zero, 300), 0);
      expect(painter.xOf(const Duration(seconds: 15), 300), 150);
      expect(painter.xOf(const Duration(seconds: 31), 300), 300);
      const none = CoachTimeLinePainter(
        CoachFormGraphic(
          word: '',
          sentence: '',
          roundLength: Duration.zero,
          validTimes: [],
        ),
      );
      expect(none.xOf(const Duration(seconds: 1), 300), 0);
      expect(painter.shouldRepaint(none), isTrue);
    });
  });

  group('the combo and goal cards', () {
    testWidgets('"11 HIT", the chip and the old best', (tester) async {
      await show(tester, const CoachComboGraphic(combo: 11, previousBest: 6));
      expect(find.text('가장 긴 콤보'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('가장 긴 콤보')).style!.color,
        AppColors.ink,
      );
      expect(find.text('11 HIT'), findsNWidgets(2));
      expect(find.text('지난 최고 6 HIT'), findsOneWidget);
      expect(
        find.bySemanticsLabel('가장 긴 콤보 11 HIT, 지난 최고 6 HIT'),
        findsOneWidget,
      );
    });

    testWidgets('the goal: its tag, title, line and where it will show', (
      tester,
    ) async {
      await show(
        tester,
        const CoachGoalGraphic(
          title: '스쿼트 20회 인정받기',
          subtitle: '이번 판 18회보다 2회 더',
          exercise: ExerciseType.squat,
        ),
      );
      expect(find.text('다음 판 미션'), findsOneWidget);
      expect(find.text('스쿼트 20회 인정받기'), findsOneWidget);
      expect(find.text('이번 판 18회보다 2회 더'), findsOneWidget);
      expect(find.text('스쿼트를 고르면 운동 선택과 대결 시작 화면에 떠요'), findsOneWidget);
      expect(
        CoachGoalCard.whereText(
          const CoachGoalGraphic(
            title: '',
            subtitle: '',
            exercise: ExerciseType.pushUp,
          ),
        ),
        startsWith('푸쉬업을 고르면'),
      );
    });
  });

  testWidgets('every card fits a 320 phone at 1.3x text', (tester) async {
    for (final graphic in <CoachGraphic>[
      const CoachScoreGraphic(reps: 18, earlier: [14, 17], average: 16),
      _pace,
      _form,
      const CoachComboGraphic(combo: 11, previousBest: 6),
      const CoachGoalGraphic(
        title: '후반 15초에 8회 이상',
        subtitle: '이번 판 후반은 6회',
        exercise: ExerciseType.squat,
      ),
    ]) {
      await show(tester, graphic, width: 320, textScale: 1.3);
      expect(tester.takeException(), isNull, reason: '$graphic');
    }
  });

  group('the last goal (A11 spec 6)', () {
    CoachGoalResultGraphic result(GoalKind kind, int target, int value) =>
        CoachGoalResultGraphic(
          title: '스쿼트 20회 인정받기',
          result: GoalProgress(
            kind: kind,
            target: target,
            value: value,
            ended: true,
          ),
        );

    Color barFill(WidgetTester tester) => tester
        .widget<ColoredBox>(
          find.descendant(
            of: find.byKey(const ValueKey('goal-result-bar')),
            matching: find.byType(ColoredBox),
          ),
        )
        .color;
    double barShare(WidgetTester tester) => tester
        .widget<FractionallySizedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('goal-result-bar')),
            matching: find.byType(FractionallySizedBox),
          ),
        )
        .widthFactor!;
    Color stamp(WidgetTester tester) =>
        (tester
                    .widget<Container>(
                      find.byKey(const ValueKey('goal-result-stamp')),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;

    testWidgets('recalled: "지난번 미션" and no word on where it shows', (
      tester,
    ) async {
      await show(
        tester,
        const CoachGoalGraphic(
          title: '스쿼트 20회 인정받기',
          subtitle: '지난 판에 그루가 준 미션',
          exercise: ExerciseType.squat,
          tag: CoachGoalGraphic.lastTag,
          showsWhere: false,
        ),
      );
      expect(find.text('지난번 미션'), findsOneWidget);
      expect(find.text('다음 판 미션'), findsNothing);
      // The mission's tag: orange, with the flag (MsGfx goal).
      final tag =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('지난번 미션'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(tag.color, AppColors.warning);
      expect(find.byType(CoachFlagIcon), findsOneWidget);
      expect(find.byType(CoachTargetIcon), findsNothing);
      expect(find.text('지난 판에 그루가 준 미션'), findsOneWidget);
      expect(find.textContaining('고르면'), findsNothing);
      expect(find.byType(CoachDashedLine), findsNothing);
    });

    testWidgets('reached: the two numbers, a full green bar, "성공!" on lime', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await show(tester, result(GoalKind.reps, 20, 21));
      expect(find.text('지난번 미션 · 스쿼트 20회 인정받기'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('미션보다 1회 더 해냈어요'), findsOneWidget);
      expect(find.text('성공!'), findsOneWidget);
      expect(barShare(tester), 1);
      expect(barFill(tester), AppColors.statusGood);
      expect(stamp(tester), AppColors.accent);
      expect(
        find.bySemanticsLabel(
          '지난번 미션 스쿼트 20회 인정받기, 미션 20, 이번 판 21, 미션보다 1회 더 해냈어요, 성공',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('missed: an amber bar as far as it came, what was left on a '
        'white stamp', (tester) async {
      await show(tester, result(GoalKind.reps, 20, 19));
      expect(find.text('미션까지 1회 남았어요'), findsOneWidget);
      expect(find.text('1회\n남음'), findsOneWidget);
      expect(barShare(tester), closeTo(0.95, 1e-9));
      expect(barFill(tester), AppColors.warning);
      expect(stamp(tester), AppColors.card);
    });

    test('the words of each kind', () {
      expect(
        CoachGoalResultCard.lineOf(result(GoalKind.reps, 20, 20)),
        '미션을 딱 채웠어요',
      );
      expect(
        CoachGoalResultCard.lineOf(result(GoalKind.combo, 5, 3)),
        '미션까지 2번 남았어요',
      );
      expect(
        CoachGoalResultCard.stampOf(result(GoalKind.combo, 5, 3)),
        '2번\n남음',
      );
      expect(
        CoachGoalResultCard.lineOf(result(GoalKind.maxRejects, 2, 0)),
        '미션보다 2회 적었어요',
      );
      expect(
        CoachGoalResultCard.lineOf(result(GoalKind.maxRejects, 2, 2)),
        '미션만큼 지켰어요',
      );
      final over = result(GoalKind.maxRejects, 1, 4);
      expect(CoachGoalResultCard.lineOf(over), '미션보다 3회 많았어요');
      expect(CoachGoalResultCard.stampOf(over), '3회\n초과');
      expect(CoachGoalResultCard.fillOf(over), closeTo(0.25, 1e-9));
      expect(CoachGoalResultCard.fillOf(result(GoalKind.maxRejects, 0, 2)), 0);
    });

    testWidgets('fits a 320 phone at 1.3x text', (tester) async {
      await show(
        tester,
        result(GoalKind.lateReps, 18, 7),
        width: 320,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
