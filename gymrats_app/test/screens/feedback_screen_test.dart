import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/reject_reason_korean.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/screens/feedback_screen.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/feedback/form_summary.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/feedback_viewmodel.dart';
import 'package:gymrats_app/widgets/feedback_parts.dart';

import '../support/fakes.dart';
import '../widgets/feedback_test_reports.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

final _report = FormReport(
  endedAt: DateTime(2026, 10, 11, 9, 5),
  opponentName: 'RepBot',
  roundLength: const Duration(seconds: 30),
  reps: const [
    RepRecord(
      index: 1,
      valid: true,
      at: Duration(seconds: 4),
      maxDepth: 1.6,
      minElbowAngle: 147,
    ),
    RepRecord(
      index: 2,
      valid: false,
      at: Duration(seconds: 8),
      reason: RejectReason.kneesDown,
      maxDepth: 1.3,
    ),
  ],
  samples: [
    for (var i = 0; i < 30; i++)
      FormSample(
        at: Duration(milliseconds: i * 300),
        depth: (i % 10) / 6,
        leftElbow: 140,
        rightElbow: 168,
      ),
  ],
);

/// Routes the feedback screen like the app does, under [home].
Widget app(Widget home) => MaterialApp(
  theme: AppTheme.dark,
  home: home,
  onGenerateRoute: (settings) => switch (settings.name) {
    GymRatsApp.feedbackRoute => MaterialPageRoute<void>(
      builder: (_) => FeedbackScreen(report: settings.arguments! as FormReport),
    ),
    _ => null,
  },
);

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a flared-elbow finding shows the side-view figure', (
    tester,
  ) async {
    phone(tester);
    const pose = FormPose(
      at: Duration(seconds: 3),
      points: {
        'leftShoulder': FormPoint(-0.5, 0),
        'rightShoulder': FormPoint(0.5, 0),
        'leftElbow': FormPoint(-1.5, 0.3),
        'nose': FormPoint(0, -0.4),
      },
    );
    await tester.pumpWidget(
      app(
        FeedbackScreen(
          report: FormReport(
            endedAt: DateTime(2026, 10, 11, 9, 5),
            opponentName: 'RepBot',
            roundLength: const Duration(seconds: 60),
            reps: const [],
            samples: [
              for (var i = 0; i < 12; i++)
                FormSample(
                  at: Duration(milliseconds: i * 100),
                  depth: 1.2,
                  leftSpread: 1.2,
                ),
            ],
            leftFlarePose: pose,
          ),
        ),
      ),
    );
    expect(find.text('팔꿈치 벌어짐'), findsOneWidget);
    expect(find.text('예시 동작 · 누르면 멈춤'), findsOneWidget);
    expect(find.byTooltip('예시 멈춤'), findsOneWidget);

    await tester.tap(find.byTooltip('예시 멈춤'));
    await tester.pump();
    expect(find.text('예시 동작 · 누르면 재생'), findsOneWidget);
    expect(find.byTooltip('예시 재생'), findsOneWidget);

    await tester.tap(find.byTooltip('예시 재생'));
    await tester.pump();
    expect(find.text('예시 동작 · 누르면 멈춤'), findsOneWidget);
  });

  testWidgets('feedback shows findings, both charts, and every rep', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(FeedbackScreen(report: _report)));

    expect(find.text('FORM'), findsOneWidget);
    expect(find.text('vs RepBot · 10/11 09:05'), findsOneWidget);
    expect(find.text('무릎 대고 함 1회'), findsOneWidget);
    expect(find.text('좌우 불균형'), findsOneWidget);
    expect(find.text('예시 동작 · 누르면 멈춤'), findsWidgets);

    await tester.scrollUntilVisible(find.text('머리 하강 깊이'), 300);
    expect(find.byType(LineChart), findsWidgets);

    await tester.scrollUntilVisible(find.text('오른팔'), 300);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('왼팔'), findsOneWidget);
    expect(find.byType(LineChart), findsWidgets);

    await tester.scrollUntilVisible(find.text('무효 · 무릎을 바닥에서 떼요'), 300);
    expect(find.text('무효 · 무릎을 바닥에서 떼요'), findsOneWidget);
    expect(find.text('147°'), findsOneWidget);
    expect(find.text('1.60'), findsOneWidget);
    expect(find.textContaining('초반 5초 1회'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('without samples, the charts say nothing was seen', (
    tester,
  ) async {
    phone(tester);
    final empty = FormReport(
      endedAt: _report.endedAt,
      opponentName: 'RepBot',
      roundLength: const Duration(seconds: 60),
      reps: const [],
      samples: const [],
    );
    await tester.pumpWidget(app(FeedbackScreen(report: empty)));
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('이 구간은 카메라에 잡히지 않았어요.'), findsWidgets);
  });

  testWidgets('the result screen opens the feedback and comes back', (
    tester,
  ) async {
    phone(tester);
    final result = BattleResult(
      matchup: _matchup,
      myReps: 1,
      myInvalidReps: 1,
      opponentReps: 0,
      endedAt: _report.endedAt,
      form: _report,
    );
    await tester.pumpWidget(app(ResultScreen(result: result)));
    await tester.tap(find.text('자세 피드백 전체 보기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FeedbackScreen), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('승리'), findsOneWidget);
  });

  testWidgets('a result without a form report has no feedback button', (
    tester,
  ) async {
    phone(tester);
    final result = BattleResult(
      matchup: _matchup,
      myReps: 1,
      myInvalidReps: 0,
      opponentReps: 0,
      endedAt: _report.endedAt,
    );
    await tester.pumpWidget(app(ResultScreen(result: result)));
    expect(find.text('자세 피드백 보기'), findsNothing);
  });

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  // Home no longer lists the phone's latest report on its own: each of its
  // recent battles carries its feedback (task: match history with feedback).
  // Updated for the game lobby (W1): home lists no battles now; they are in
  // 기록보관소, the /history page.
  testWidgets('a battle in 기록보관소 opens the same feedback screen', (
    tester,
  ) async {
    phone(tester);
    final repository = FakeUserRepository()
      ..historyPages = [
        [
          MatchRecord(
            id: 5,
            exercise: ExerciseType.pushUp,
            opponentName: 'RepBot',
            myReps: 1,
            opponentReps: 0,
            playedAt: _report.endedAt,
            feedbackSummary: summarizeForm(_report),
          ),
        ],
      ]
      ..reports = {5: _report};
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserRepository>.value(value: repository),
          Provider<FormReportStore>.value(value: InMemoryFormReportStore()),
        ],
        // What the /history route opens.
        child: app(const HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs RepBot'));
    await tester.pumpAndSettle();
    // Since W5 (team decision 2026-11-08) the row opens the battle's report;
    // its 자세 피드백 전체 보기 opens the feedback.
    expect(find.byType(ResultScreen), findsOneWidget);
    await tester.ensureVisible(find.text('자세 피드백 전체 보기'));
    await tester.tap(find.text('자세 피드백 전체 보기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(
      tester.widget<FeedbackScreen>(find.byType(FeedbackScreen)).report,
      same(_report),
    );
  });

  // W8 (BFeedback in palette B, issues #58 and #59): the screen words the
  // view model's values; push-ups and squats.
  group('palette B, from the view model', () {
    /// Shows [report] (and [form], if given) on a screen [height] tall, so
    /// the whole page is built.
    Future<void> show(
      WidgetTester tester,
      FormReport report, {
      FormFeedback? form,
      double height = 3600,
    }) async {
      tester.view.physicalSize = Size(412, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(FeedbackScreen(report: report, form: form)));
      await tester.pump(const Duration(milliseconds: 500));
    }

    for (final (exercise, reason, title) in [
      (ExerciseType.pushUp, RejectReason.kneesDown, '무릎 대고 함 2회'),
      (ExerciseType.squat, RejectReason.shallowSquat, '얕은 스쿼트 2회'),
    ]) {
      testWidgets('UAT-4 AC2 (${exercise.name}): 4 counted and 2 rejected '
          'reps, the issue with its tip, and one row per rep', (tester) async {
        await show(
          tester,
          feedbackReport(exercise: exercise, rejected: [reason, reason]),
        );
        expect(find.text('4회'), findsOneWidget);
        expect(find.text('2회'), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.textContaining('→ '), findsWidgets);
        expect(find.text('6회 판정'), findsOneWidget);
        // Four 인정 rows and the 인정 count's label.
        expect(find.text('인정'), findsNWidgets(5));
        expect(find.text('무효 · ${reason.koreanMessage}'), findsNWidgets(2));
      });
    }

    testWidgets('#58: a squat that lost 0.15 says so on the card and under '
        'the chart', (tester) async {
      final report = issue58Squat();
      expect(
        FeedbackViewModel.fromReport(report).state.form!.depthTrend,
        DepthTrend.dropped,
      );
      await show(tester, report);
      expect(find.text('후반 깊이 감소'), findsOneWidget);
      expect(find.textContaining('후반으로 갈수록 깊이가 줄었어요.'), findsOneWidget);
      expect(find.textContaining('깊이는 끝까지 유지됐어요'), findsNothing);
    });

    testWidgets('#58: the same depths in a push-up stay within its 0.25 '
        'line, on the card and under the chart', (tester) async {
      await show(tester, issue58Squat(exercise: ExerciseType.pushUp));
      expect(find.text('후반 깊이 감소'), findsNothing);
      expect(find.textContaining('깊이는 끝까지 유지됐어요.'), findsOneWidget);
      expect(find.textContaining('후반으로 갈수록'), findsNothing);
    });

    testWidgets('a push-up that lost 0.3 says so on the card and under the '
        'chart, as before', (tester) async {
      await show(tester, feedbackReport(depths: const [1.6, 1.6, 1.3, 1.3]));
      expect(find.text('후반 깊이 감소'), findsOneWidget);
      expect(find.textContaining('후반으로 갈수록 깊이가 줄었어요.'), findsOneWidget);
    });

    testWidgets('with too few counted reps the depth sentence only reads the '
        'chart', (tester) async {
      await show(tester, feedbackReport(depths: const [1.2, 1.2, 1.2]));
      expect(
        find.text('회색 점선은 판정된 횟수, 위에 주황 칸이 붙은 점선은 거절된 횟수예요.'),
        findsOneWidget,
      );
    });

    testWidgets('a squat is titled 앉은 깊이 and has no elbow chart, arm '
        'sentence or elbow column', (tester) async {
      final semantics = tester.ensureSemantics();
      // Arms the push-up rules would call uneven (60° and 170°).
      await show(tester, issue58Squat());
      expect(find.text('앉은 깊이'), findsOneWidget);
      expect(find.text('서 있을 때 허벅지 길이 기준'), findsOneWidget);
      expect(find.text('머리 하강 깊이'), findsNothing);
      expect(find.text('어깨 너비 기준'), findsNothing);
      expect(find.bySemanticsLabel('앉은 깊이 그래프'), findsOneWidget);
      expect(find.text('팔꿈치 각도'), findsNothing);
      expect(find.textContaining('실선이 왼팔'), findsNothing);
      expect(find.textContaining('좌우 각도'), findsNothing);
      expect(find.textContaining('더 굽혀져'), findsNothing);
      expect(find.text('팔꿈치'), findsNothing);
      expect(find.text('좌우 불균형'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a squat shows its hip angle as its joint-angle chart, '
        'without a verdict', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, issue58Squat());
      expect(find.text('엉덩이 각도'), findsOneWidget);
      expect(find.text('180° = 똑바로 선 자세'), findsOneWidget);
      expect(find.bySemanticsLabel('엉덩이 각도 그래프'), findsOneWidget);
      expect(
        find.text(
          '어깨-엉덩이-무릎 각도예요. 똑바로 서면 180°에 가깝고, 깊이 앉을수록 작아져요. '
          '끊긴 곳은 몸이 안 보인 때예요.',
        ),
        findsOneWidget,
      );
      final hip = tester.widgetList<LineChart>(find.byType(LineChart)).last;
      expect(hip.data.lineBarsData.single.spots.first.y, 150);
      expect(find.byType(LineChart), findsNWidgets(2));
      semantics.dispose();
    });

    testWidgets('a squat whose body was not seen says so in the hip chart '
        'place', (tester) async {
      await show(
        tester,
        feedbackReport(exercise: ExerciseType.squat, hipAngle: null),
      );
      expect(find.text('엉덩이 각도'), findsOneWidget);
      expect(find.text('이 구간은 카메라에 잡히지 않았어요.'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('a push-up keeps 머리 하강 깊이, the elbow chart, its legend '
        'and the elbow column', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, feedbackReport());
      expect(find.text('머리 하강 깊이'), findsOneWidget);
      expect(find.text('어깨 너비 기준'), findsOneWidget);
      expect(find.bySemanticsLabel('머리 하강 깊이 그래프'), findsOneWidget);
      expect(find.text('팔꿈치 각도'), findsWidgets);
      expect(find.bySemanticsLabel('팔꿈치 각도 그래프'), findsOneWidget);
      expect(find.text('왼팔'), findsOneWidget);
      expect(find.text('오른팔'), findsOneWidget);
      expect(find.text('팔꿈치'), findsOneWidget);
      expect(find.text('엉덩이 각도'), findsNothing);
      expect(find.byType(LineChart), findsNWidgets(2));
      semantics.dispose();
    });

    testWidgets('the arm sentence follows the analyzer: even, left or right '
        'bent more, as the cards say', (tester) async {
      await show(tester, feedbackReport());
      expect(find.text('양팔 균형'), findsOneWidget);
      expect(find.textContaining('좌우 각도가 비슷해요.'), findsOneWidget);

      await show(tester, feedbackReport(leftElbow: 100, rightElbow: 140));
      expect(find.text('좌우 불균형'), findsOneWidget);
      expect(find.textContaining('왼팔을 더 굽혔어요.'), findsOneWidget);
      expect(find.textContaining('왼팔이 더 굽혀져 있어요.'), findsOneWidget);

      await show(tester, feedbackReport(leftElbow: 140, rightElbow: 100));
      expect(find.textContaining('오른팔이 더 굽혀져 있어요.'), findsOneWidget);
    });

    testWidgets('when the analyzer cannot tell the arms apart, the sentence '
        'does not judge them', (tester) async {
      // Six samples: fewer than the arm rule needs.
      await show(
        tester,
        feedbackReport(leftElbow: 100, rightElbow: 160, samples: 6),
      );
      expect(
        find.text('실선이 왼팔, 점선이 오른팔이에요. 끊긴 곳은 팔이 안 보인 때예요.'),
        findsOneWidget,
      );
      expect(find.textContaining('더 굽혀져'), findsNothing);
      expect(find.textContaining('비슷해요'), findsNothing);
    });

    testWidgets('the screen words the values it is given, never its own', (
      tester,
    ) async {
      await show(
        tester,
        feedbackReport(),
        form: const FormFeedback(
          findings: [
            FormFinding(
              kind: FindingKind.issue,
              title: '뷰모델의 판정',
              detail: '화면이 다시 계산하지 않아요.',
            ),
          ],
          meanDepth: 0.42,
          depthTrend: DepthTrend.dropped,
          armBalance: ArmBalance.rightDeeper,
          paceBuckets: [9, 0, 0, 0, 0, 1],
          sliceSeconds: 5,
          repsPerSecond: 1.234,
        ),
      );
      expect(find.text('뷰모델의 판정'), findsOneWidget);
      expect(find.text('양팔 균형'), findsNothing);
      expect(find.text('0.42배'), findsOneWidget);
      expect(find.textContaining('후반으로 갈수록 깊이가 줄었어요.'), findsOneWidget);
      expect(find.textContaining('오른팔이 더 굽혀져 있어요.'), findsOneWidget);
      expect(
        find.text('5초마다 인정된 횟수예요. 초반 5초 9회, 마지막 5초 1회, 평균 1.23회/초.'),
        findsOneWidget,
      );
    });

    testWidgets('opened with only a report, it shows what the view model '
        'makes of it, and follows a new report', (tester) async {
      final report = feedbackReport(
        rejected: const [RejectReason.insufficientDepth],
      );
      await show(tester, report);
      final form = FeedbackViewModel.fromReport(report).state.form!;
      for (final finding in form.findings) {
        expect(find.text(finding.title), findsWidgets, reason: finding.title);
      }
      expect(
        find.text('${form.meanDepth!.toStringAsFixed(2)}배'),
        findsOneWidget,
      );

      await show(tester, issue58Squat());
      expect(find.text('앉은 깊이'), findsOneWidget);
      expect(find.text('후반 깊이 감소'), findsOneWidget);
    });

    testWidgets('a round cut short by a KO is read in its own slices', (
      tester,
    ) async {
      await show(tester, feedbackReport(round: const Duration(seconds: 17)));
      expect(find.text('2.8초마다 인정 횟수'), findsOneWidget);
      // Reps at 2, 4, 6, 8 s in slices of 2.83 s; 4 reps in 17 s.
      expect(
        find.text('2.8초마다 인정된 횟수예요. 초반 2.8초 1회, 마지막 2.8초 0회, 평균 0.24회/초.'),
        findsOneWidget,
      );
      final charts = tester.widgetList<LineChart>(find.byType(LineChart));
      for (final chart in charts) {
        expect(chart.data.maxX, closeTo(17, 1e-9));
      }
      expect(find.text('17s'), findsNWidgets(2));
      expect(find.text('30s'), findsNothing);
    });

    testWidgets('#59: an AI squat without depth over time says where the '
        'depths are and still gives the verdict', (tester) async {
      await show(
        tester,
        feedbackReport(
          exercise: ExerciseType.squat,
          depths: const [0.95, 0.95, 0.80, 0.80],
          depthSamples: false,
        ),
      );
      // Only the hip angle's chart: no depth was saved over time.
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.bySemanticsLabel('앉은 깊이 그래프'), findsNothing);
      expect(
        find.text(
          '시간별 깊이는 저장되지 않았어요. 횟수별 깊이는 아래 표에 있어요. '
          '후반으로 갈수록 깊이가 줄었어요.',
        ),
        findsOneWidget,
      );
      expect(find.text('후반 깊이 감소'), findsOneWidget);
      expect(find.text('0.95'), findsNWidgets(2));
      expect(find.byType(BarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a depth seen only after the round ends gives the note, '
        'not an empty chart (Codex review of #63)', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        feedbackReport(
          exercise: ExerciseType.squat,
          depths: const [0.95, 0.95, 0.80, 0.80],
          depthSamples: false,
          hipAngle: null,
          // The last camera frame, handled just after the 30 s round.
          extraSamples: const [
            FormSample(at: Duration(milliseconds: 30200), depth: 1.6),
          ],
        ),
      );
      expect(find.bySemanticsLabel('앉은 깊이 그래프'), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      expect(
        find.text(
          '시간별 깊이는 저장되지 않았어요. 횟수별 깊이는 아래 표에 있어요. '
          '후반으로 갈수록 깊이가 줄었어요.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('#59 with too few reps to judge: only where the depths are', (
      tester,
    ) async {
      await show(
        tester,
        feedbackReport(
          exercise: ExerciseType.squat,
          depths: const [0.9],
          depthSamples: false,
        ),
      );
      expect(
        find.text('시간별 깊이는 저장되지 않았어요. 횟수별 깊이는 아래 표에 있어요.'),
        findsOneWidget,
      );
    });

    testWidgets('nothing judged and nothing seen: the notes say so', (
      tester,
    ) async {
      await show(
        tester,
        feedbackReport(
          depths: const [],
          depthSamples: false,
          leftElbow: null,
          rightElbow: null,
        ),
      );
      expect(find.text('이 구간은 카메라에 잡히지 않았어요.'), findsNWidgets(2));
      expect(find.text('판정된 횟수가 없어요.'), findsOneWidget);
      expect(find.text('속도'), findsNothing);
      expect(find.text('0회 판정'), findsOneWidget);
    });

    testWidgets('palette B: every word is ink; color only fills badges, '
        'swatches, squares and bars', (tester) async {
      await show(
        tester,
        feedbackReport(
          rejected: const [
            RejectReason.insufficientDepth,
            RejectReason.kneesDown,
          ],
        ),
      );
      final fills = {
        for (final color in [
          AppColors.accent,
          AppColors.warning,
          AppColors.opponent,
          AppColors.fever,
          AppColors.danger,
          AppColors.accentDeep,
          AppColors.opponentDeep,
        ])
          color.toARGB32(),
      };
      final texts = tester.widgetList<RichText>(
        find.descendant(
          of: find.byType(FeedbackScreen),
          matching: find.byType(RichText),
        ),
      );
      expect(texts, isNotEmpty);
      for (final text in texts) {
        text.text.visitChildren((span) {
          expect(
            fills.contains(span.style?.color?.toARGB32()),
            isFalse,
            reason: span.toPlainText(),
          );
          return true;
        });
      }
      expect(find.byType(FeedbackSwatch), findsWidgets);
      expect(find.byType(FeedbackBadge), findsWidgets);
    });

    for (final (exercise, scale, reason) in [
      (ExerciseType.pushUp, 1.3, RejectReason.insufficientDepth),
      (ExerciseType.pushUp, 2.0, RejectReason.insufficientDepth),
      (ExerciseType.squat, 1.3, RejectReason.shallowSquat),
      (ExerciseType.squat, 2.0, RejectReason.shallowSquat),
    ]) {
      final lastRow = '무효 · ${reason.koreanMessage}';
      testWidgets('${exercise.name} at ${scale}x text on a 360 x 780 phone: '
          'nothing overflows down to the last rep', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          app(
            FeedbackScreen(
              report: feedbackReport(
                exercise: exercise,
                rejected: [reason],
                endedAt: DateTime(2026, 12, 31, 23, 59),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.scrollUntilVisible(
          find.text(lastRow),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(lastRow), findsOneWidget);
        // The reason wraps instead of ending in "…".
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(lastRow))
              .didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
