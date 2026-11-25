import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/screens/feedback_screen.dart';
import 'package:gymrats_app/screens/history_screen.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/feedback/form_summary.dart';
import 'package:gymrats_app/services/feedback/report_metrics.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/feedback_viewmodel.dart';

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

/// Earlier battles of [exercise] with [valid] counted reps each, the latest
/// first, all before [feedbackReport]'s end.
List<FormReport> earlier(
  List<int> valid, {
  ExerciseType exercise = ExerciseType.pushUp,
}) => [
  for (final (i, n) in valid.indexed)
    feedbackReport(
      exercise: exercise,
      depths: List.filled(n, 1.2),
      repGap: 1,
      endedAt: DateTime(2026, 11, 14 - i, 9, 5),
    ),
];

void main() {
  void phone(WidgetTester tester, {double height = 915}) {
    tester.view.physicalSize = Size(412, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// The report of [report] as the view model makes it, with [kept] as the
  /// phone's earlier battles, on a screen tall enough for every part.
  Future<void> show(
    WidgetTester tester,
    FormReport report, {
    List<FormReport> kept = const [],
    double height = 4000,
  }) async {
    phone(tester, height: height);
    final state = FeedbackViewModel.fromReport(report).state;
    await tester.pumpWidget(
      app(
        FeedbackScreen(
          report: report,
          form: state.form,
          metrics: ReportMetrics.of(report, earlier: kept),
          history: ReportHistory.of(report, kept),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openDetail(WidgetTester tester) async {
    await tester.ensureVisible(find.text('자세 분석 자세히 보기'));
    await tester.tap(find.text('자세 분석 자세히 보기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('the post-game report (P14, D-3)', () {
    testWidgets('shows the date, the form score and the battle line', (
      tester,
    ) async {
      final report = feedbackReport(rejected: [RejectReason.kneesDown]);
      await show(tester, report);
      final score = ReportMetrics.of(report).score!;
      expect(find.text('REPORT'), findsOneWidget);
      expect(find.text('26.11.15(일) 09:05'), findsOneWidget);
      expect(find.text('자세 점수'), findsOneWidget);
      expect(find.text('$score'), findsWidgets);
      expect(find.bySemanticsLabel('자세 점수 $score점'), findsOneWidget);
      expect(find.text('푸쉬업 · vs AI 봇 · 고수 · 30초'), findsOneWidget);
      expect(find.text('인정 4 · 무효 1'), findsOneWidget);
    });

    testWidgets('without earlier battles: no comparison toggle, change chips, '
        'average bars, endurance or trend', (tester) async {
      await show(tester, feedbackReport());
      expect(find.text('최근 평균과 비교'), findsNothing);
      expect(find.text('평균 이하'), findsNothing);
      expect(find.text('개인 최고 갱신'), findsNothing);
      expect(find.text('변화'), findsNothing);
      expect(find.text('근지구력 지수'), findsNothing);
    });

    testWidgets('운동 분석 shows counted reps, calories and lifted weight on '
        'the assumed 65 kg, and endurance against the recent mean', (
      tester,
    ) async {
      final report = feedbackReport(depths: List.filled(6, 1.2));
      await show(tester, report, kept: earlier([4, 4]));
      expect(
        find.text(ReportMetrics.of(report).kcal.toStringAsFixed(1)),
        findsOneWidget,
      );
      expect(find.text('${(6 * 65 * 0.64).round()}'), findsOneWidget);
      // Both are estimates on the default weight, and say so.
      expect(find.text('체중 65 kg(기본값) 기준 추정'), findsNWidgets(2));
      expect(find.text('150'), findsOneWidget);
      expect(find.text('평균 = 100'), findsOneWidget);
      expect(find.text('+2'), findsWidgets);
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('평균 이하'), findsNWidgets(4));
      expect(find.bySemanticsLabel('평균 이상'), findsWidgets);
    });

    testWidgets('최근 평균과 비교 lays the recent mean over the pentagon and '
        'adds the change to each axis card', (tester) async {
      await show(
        tester,
        feedbackReport(depths: List.filled(6, 1.2)),
        kept: earlier([4, 5, 6]),
      );
      ReportRadarPainter radar() =>
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) =>
                          w is CustomPaint && w.painter is ReportRadarPainter,
                    ),
                  )
                  .painter!
              as ReportRadarPainter;
      bool change(Widget w) =>
          w is Text &&
          ((w.data ?? '').startsWith('▲') || (w.data ?? '').startsWith('▼'));
      expect(find.text('최근 5경기 평균'), findsNothing);
      expect(radar().mean, isNull);
      expect(find.byWidgetPredicate(change), findsNothing);
      // The same reps as before: each card says it is at the mean.
      final atMean = tester.widgetList(find.text('평균')).length;
      await tester.tap(find.text('최근 평균과 비교'));
      await tester.pump();
      expect(find.text('최근 5경기 평균'), findsOneWidget);
      expect(radar().mean, isNotEmpty);
      expect(
        tester.widgetList(find.text('평균')).length +
            tester.widgetList(find.byWidgetPredicate(change)).length,
        atMean + 4,
      );
      // The segment, not the legend's label.
      await tester.tap(find.text('이번 경기').first);
      await tester.pump();
      expect(find.text('최근 5경기 평균'), findsNothing);
      expect(radar().mean, isNull);
    });

    testWidgets("each axis card says 우수 · 표준 · 부족, or — for a squat's arms", (
      tester,
    ) async {
      final report = feedbackReport(
        exercise: ExerciseType.squat,
        depths: const [0.95, 0.95, 0.95, 0.95],
      );
      await show(tester, report);
      for (final axis in ReportAxis.values) {
        expect(find.text(axis.label), findsOneWidget);
      }
      // No arms in a squat, and these reps kept no descent time.
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('우수'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('좌우 균형 측정 안 됨')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('템포 측정 안 됨')), findsOneWidget);
    });

    testWidgets('이번 경기 유형 names the pace with the first and last thirds', (
      tester,
    ) async {
      // Reps at 2, 4, ..., 12 s: four in the first third, none in the last.
      await show(tester, feedbackReport(depths: List.filled(6, 1.2)));
      expect(find.text('초반 집중형'), findsOneWidget);
      expect(find.text('0–10초 4회 · 20–30초 0회'), findsOneWidget);
    });

    testWidgets('highlights: reached lines with a check, the next goal '
        'without', (tester) async {
      await show(
        tester,
        feedbackReport(depths: List.filled(6, 1.2)),
        kept: earlier([4, 7]),
      );
      expect(find.text('이번 경기 성과'), findsOneWidget);
      expect(find.text('첫 10초 무효 없이 4회'), findsOneWidget);
      expect(find.text('최근 평균보다 1회 더'), findsOneWidget);
      expect(find.text('개인 최고까지 2회'), findsOneWidget);
      Finder checkIn(String line) => find.descendant(
        of: find.ancestor(of: find.text(line), matching: find.byType(Row)),
        matching: find.byIcon(Icons.check_rounded),
      );
      expect(checkIn('최근 평균보다 1회 더'), findsOneWidget);
      expect(checkIn('개인 최고까지 2회'), findsNothing);
    });

    testWidgets('변화 shows the recent counted reps, their scores and dates, '
        'this battle last', (tester) async {
      await show(
        tester,
        feedbackReport(depths: List.filled(6, 1.2)),
        kept: earlier([4, 5]),
      );
      expect(find.text('변화'), findsOneWidget);
      expect(find.text('최근 3경기 · 인정 횟수'), findsOneWidget);
      expect(find.bySemanticsLabel('최근 3경기 인정 횟수: 5, 4, 6'), findsOneWidget);
      expect(find.text('11.13'), findsOneWidget);
      expect(find.text('11.14'), findsOneWidget);
      expect(find.text('이번'), findsOneWidget);
    });

    testWidgets('the coach line is how to fix the first issue', (tester) async {
      final report = feedbackReport(
        rejected: [RejectReason.kneesDown, RejectReason.kneesDown],
      );
      await show(tester, report);
      final form = FeedbackViewModel.fromReport(report).state.form!;
      final issue = form.findings.firstWhere(
        (f) => f.kind == FindingKind.issue,
      );
      expect(find.text('코치 한마디'), findsOneWidget);
      expect(find.text(issue.fix ?? issue.detail), findsOneWidget);
    });

    testWidgets("opened with only a report, it reads the kept battles from the "
        "app's store for the comparison", (tester) async {
      phone(tester, height: 4000);
      final store = InMemoryFormReportStore();
      for (final r in earlier([4])) {
        await store.save(r);
      }
      await tester.pumpWidget(
        Provider<FormReportStore>.value(
          value: store,
          child: app(
            FeedbackScreen(report: feedbackReport(depths: List.filled(6, 1.2))),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('최근 평균과 비교'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('opened with only a report and no store, it still shows the '
        'report', (tester) async {
      phone(tester, height: 4000);
      await tester.pumpWidget(app(FeedbackScreen(report: _report)));
      await tester.pump();
      expect(find.text('자세 점수'), findsOneWidget);
      expect(find.text('최근 평균과 비교'), findsNothing);
    });
  });

  group('the report reads honestly (P14 review)', () {
    testWidgets('an axis above and one below the recent mean show ▲ and ▼ '
        'with the points', (tester) async {
      // Before: every rep deep (depth 1.0) but 2 of 6 rejected (accuracy
      // 0.67). Now: 4 of 4 counted (1.0) at good depth only (0.67).
      final before = feedbackReport(
        depths: List.filled(4, 2.0),
        rejected: [RejectReason.kneesDown, RejectReason.kneesDown],
        endedAt: DateTime(2026, 11, 14, 9, 5),
      );
      await show(tester, feedbackReport(), kept: [before]);
      await tester.tap(find.text('최근 평균과 비교'));
      await tester.pump();
      expect(find.text('▲ 33'), findsOneWidget);
      expect(find.text('▼ 33'), findsOneWidget);
    });

    testWidgets('an unmeasured axis is left out of the pentagon, not drawn '
        'at the centre', (tester) async {
      const size = Size(300, 260);
      final center = size.center(Offset.zero);
      final radius = size.shortestSide / 2 - 44;
      // Inside the chord that skips 좌우 균형 (the fifth corner), outside a
      // shape that dips to the centre there.
      final nearBalance =
          center +
          Offset.fromDirection(198 * 3.141592653589793 / 180, radius * 0.2);
      final full = {for (final a in ReportAxis.values) a: 1.0};
      final squat = Map.of(full)..remove(ReportAxis.balance);
      final shape = AppColors.ink.withValues(alpha: 0.78);
      ReportRadarPainter painter(Map<ReportAxis, double> values) =>
          ReportRadarPainter(
            values: values,
            labelStyle: AppTheme.dark.textTheme.reportCardTitle,
          );
      expect(
        (Canvas c) => painter(squat).paint(c, size),
        paints
          // the three rings and the five spokes, then the shape
          ..path()
          ..path()
          ..path()
          ..line()
          ..line()
          ..line()
          ..line()
          ..line()
          ..path(color: shape, includes: [nearBalance]),
      );
      expect(
        (Canvas c) => painter({...squat, ReportAxis.balance: 0}).paint(c, size),
        paints
          // the three rings and the five spokes, then the shape
          ..path()
          ..path()
          ..path()
          ..line()
          ..line()
          ..line()
          ..line()
          ..line()
          ..path(color: shape, excludes: [nearBalance]),
      );
    });

    testWidgets('a round cut short by a KO names its own thirds', (
      tester,
    ) async {
      await show(
        tester,
        feedbackReport(
          depths: List.filled(6, 1.2),
          round: const Duration(seconds: 17),
        ),
      );
      // Reps at 2, 4, ..., 12 s: two before 5.7 s, one after 11.3 s.
      expect(find.text('0–6초 2회 · 11–17초 1회'), findsOneWidget);
      expect(find.text('첫 6초 무효 없이 2회'), findsOneWidget);
      expect(find.textContaining('17초'), findsWidgets);
      await openDetail(tester);
      // 6, 5 and 6 s parts: not all "6초".
      expect(find.text('구간별 횟수'), findsOneWidget);
      expect(find.text('6초 구간'), findsNothing);
      expect(find.text('6–11초'), findsOneWidget);
    });

    testWidgets('the way into the detail is announced as a button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await show(tester, feedbackReport());
      expect(
        tester.getSemantics(find.text('자세 분석 자세히 보기')),
        matchesSemantics(
          label: '자세 분석 자세히 보기',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  testWidgets('with a body weight, the estimates use it and say so', (
    tester,
  ) async {
    phone(tester, height: 4000);
    final report = feedbackReport(depths: List.filled(6, 1.2));
    await tester.pumpWidget(
      app(
        FeedbackScreen(
          report: report,
          form: FeedbackViewModel.fromReport(report).state.form,
          metrics: ReportMetrics.of(report, weightKg: 80),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('체중 80 kg 기준 추정'), findsNWidgets(2));
    expect(find.text('${(6 * 80 * 0.64).round()}'), findsOneWidget);
  });

  group('자세 분석 자세히 보기 (D-3 detail)', () {
    testWidgets('opens from the report and goes back', (tester) async {
      await show(tester, feedbackReport());
      await openDetail(tester);
      expect(find.byType(FeedbackDetailScreen), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FeedbackDetailScreen), findsNothing);
      expect(find.text('자세 점수'), findsOneWidget);
    });

    testWidgets('an issue shows its side-view example, without the front-view '
        'stick figure of the moment or a how-to line', (tester) async {
      const pose = FormPose(
        at: Duration(seconds: 3),
        points: {
          'leftShoulder': FormPoint(-0.5, 0),
          'rightShoulder': FormPoint(0.5, 0),
          'leftElbow': FormPoint(-1.5, 0.3),
          'nose': FormPoint(0, -0.4),
        },
      );
      final report = FormReport(
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
      );
      await show(tester, report);
      await openDetail(tester);
      expect(find.text('고칠 점'), findsOneWidget);
      expect(find.text('팔꿈치 벌어짐'), findsOneWidget);
      // The phone check (2026-11-26) found the front-view figure beside the
      // side-view example only repeated it: the report keeps the pose, the
      // screen no longer draws it.
      expect(find.bySemanticsLabel(RegExp('순간의 자세 그림')), findsNothing);
      expect(find.text('예시 동작 · 누르면 멈춤'), findsOneWidget);
      expect(find.textContaining('→ '), findsNothing);
      expect(find.textContaining('이렇게 해 보세요'), findsNothing);
    });

    testWidgets('무효 사유 counts each reason; the thirds stack counted and '
        'rejected reps; no rep table', (tester) async {
      await show(
        tester,
        feedbackReport(
          rejected: [
            RejectReason.insufficientDepth,
            RejectReason.insufficientDepth,
            RejectReason.kneesDown,
          ],
        ),
      );
      await openDetail(tester);
      expect(find.text('무효 사유'), findsOneWidget);
      expect(find.text('7회 중 3회'), findsOneWidget);
      expect(find.text('가슴을 더 내려요'), findsOneWidget);
      expect(find.text('2회'), findsOneWidget);
      expect(find.text('무릎을 바닥에서 떼요'), findsOneWidget);
      expect(find.text('10초 구간'), findsOneWidget);
      // Counted at 2-8 s, rejected at 10, 12 and 14 s.
      expect(find.text('0 +3'), findsOneWidget);
      // The bars are drawn as wide as their slot, not only as tall: on the
      // phone (2026-11-26) they had no width and the chart looked empty.
      // Only the split chart's bars: 무효 사유 draws warning bars too.
      Iterable<Size> drawn(Color color) => tester
          .renderObjectList<RenderBox>(
            find.descendant(
              of: find.bySemanticsLabel(RegExp('초 인정')),
              matching: find.byWidgetPredicate(
                (w) => w is ColoredBox && w.color == color,
              ),
            ),
          )
          .map((box) => box.size)
          .where((size) => size.height > 0);
      expect(drawn(AppColors.statusGood), isNotEmpty);
      expect(drawn(AppColors.warning), isNotEmpty);
      for (final size in [
        ...drawn(AppColors.statusGood),
        ...drawn(AppColors.warning),
      ]) {
        expect(size.width, greaterThan(40));
      }
      expect(find.text('횟수별 기록'), findsNothing);
    });

    testWidgets('a push-up shows the depth and elbow charts with two-line '
        'captions', (tester) async {
      await show(tester, _report);
      await openDetail(tester);
      await tester.scrollUntilVisible(find.text('팔꿈치 각도'), 300);
      expect(find.text('깊이'), findsWidgets);
      expect(find.byType(LineChart), findsWidgets);
      expect(
        find.text('위가 쭉 편 팔(180°), 아래로 갈수록 많이 굽힌 팔이에요.\n왼팔이 더 굽혀졌어요.'),
        findsOneWidget,
      );
    });

    testWidgets('a squat is titled 앉은 깊이 and shows its hip angle, no elbow '
        'chart', (tester) async {
      await show(tester, issue58Squat());
      await openDetail(tester);
      await tester.scrollUntilVisible(find.text('엉덩이 각도'), 300);
      expect(find.text('앉은 깊이'), findsOneWidget);
      expect(find.text('팔꿈치 각도'), findsNothing);
      expect(
        find.text('똑바로 서면 180°에 가깝고, 깊이 앉을수록 작아져요.\n끊긴 곳은 몸이 안 보인 때예요.'),
        findsOneWidget,
      );
    });

    testWidgets('reps with a depth but no samples over time: the note says '
        'it was not kept (#59)', (tester) async {
      await show(tester, feedbackReport(depthSamples: false));
      await openDetail(tester);
      expect(find.textContaining('시간별 깊이는 저장되지 않았어요.'), findsOneWidget);
    });

    for (final (left, right, sentence) in [
      (100.0, 104.0, '좌우 각도가 비슷해요.'),
      (120.0, 90.0, '오른팔이 더 굽혀졌어요.'),
    ]) {
      testWidgets('the elbow caption says "$sentence"', (tester) async {
        await show(tester, feedbackReport(leftElbow: left, rightElbow: right));
        await openDetail(tester);
        await tester.scrollUntilVisible(find.text('팔꿈치 각도'), 300);
        expect(
          find.text('위가 쭉 편 팔(180°), 아래로 갈수록 많이 굽힌 팔이에요.\n$sentence'),
          findsOneWidget,
        );
      });
    }

    testWidgets('nothing judged and nothing seen: the notes say so', (
      tester,
    ) async {
      final empty = FormReport(
        endedAt: _report.endedAt,
        opponentName: 'RepBot',
        roundLength: const Duration(seconds: 60),
        reps: const [],
        samples: const [],
      );
      await show(tester, empty);
      expect(find.text('—'), findsWidgets);
      await openDetail(tester);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('이 구간은 카메라에 잡히지 않았어요.'), findsNWidgets(2));
      expect(find.text('무효 사유'), findsNothing);
    });
  });

  for (final (exercise, scale) in [
    (ExerciseType.pushUp, 1.3),
    (ExerciseType.pushUp, 2.0),
    (ExerciseType.squat, 1.3),
    (ExerciseType.squat, 2.0),
  ]) {
    testWidgets('${exercise.name} at ${scale}x text on a 360 x 780 phone: '
        'nothing overflows on the report or the detail', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final report = feedbackReport(
        exercise: exercise,
        rejected: [RejectReason.insufficientDepth],
        endedAt: DateTime(2026, 12, 31, 23, 59),
      );
      final kept = earlier([3, 5], exercise: exercise);
      await tester.pumpWidget(
        app(
          FeedbackScreen(
            report: report,
            form: FeedbackViewModel.fromReport(report).state.form,
            metrics: ReportMetrics.of(report, earlier: kept),
            history: ReportHistory.of(report, kept),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
        find.text('자세 분석 자세히 보기'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('자세 분석 자세히 보기'));
      await tester.pump();
      await tester.tap(find.text('자세 분석 자세히 보기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.scrollUntilVisible(
        find.text(exercise == ExerciseType.squat ? '엉덩이 각도' : '팔꿈치 각도'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
    });
  }

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
    await tester.tap(find.text('상세 리포트 보기'));
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
    // its 상세 리포트 보기 opens the feedback.
    expect(find.byType(ResultScreen), findsOneWidget);
    await tester.ensureVisible(find.text('상세 리포트 보기'));
    await tester.tap(find.text('상세 리포트 보기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(
      tester.widget<FeedbackScreen>(find.byType(FeedbackScreen)).report,
      same(_report),
    );
  });
}
