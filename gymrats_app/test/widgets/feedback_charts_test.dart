import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/feedback_charts.dart';

import 'feedback_test_reports.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, child: child)),
  ),
);

LineChartData _line(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

BarChartData _bars(WidgetTester tester) =>
    tester.widget<BarChart>(find.byType(BarChart)).data;

Future<void> _depth(
  WidgetTester tester,
  FormReport report, {
  double sliceSeconds = 5,
}) => tester.pumpWidget(
  _host(
    FeedbackDepthPlot(
      samples: report.samples,
      reps: report.reps,
      sliceSeconds: sliceSeconds,
      squat: report.exercise == ExerciseType.squat,
    ),
  ),
);

List<FormSample> _depths(List<double> values) => [
  for (var i = 0; i < values.length; i++)
    FormSample(
      at: Duration(seconds: i),
      depth: values[i],
    ),
];

void main() {
  group('feedbackSeconds', () {
    test('a whole number has no decimal, a slice of a KO round has one', () {
      expect(feedbackSeconds(5), '5');
      expect(feedbackSeconds(30), '30');
      expect(feedbackSeconds(0), '0');
      expect(feedbackSeconds(17 / 6), '2.8');
      expect(feedbackSeconds(17 / 6 * 3), '8.5');
      expect(feedbackSeconds(4.96), '5');
    });
  });

  group('FeedbackDepthPlot', () {
    testWidgets('a push-up spans the round and 0 to 2 with a gray dashed mark '
        'per judged rep', (tester) async {
      await _depth(
        tester,
        feedbackReport(rejected: const [RejectReason.insufficientDepth]),
      );
      final data = _line(tester);
      expect(data.minX, 0);
      expect(data.maxX, 30);
      expect(data.minY, 0);
      expect(data.maxY, 2);
      expect(data.clipData, const FlClipData.none());
      final marks = data.extraLinesData.verticalLines;
      expect(marks.map((m) => m.x), [2, 4, 6, 8, 10]);
      for (final mark in marks) {
        expect(mark.color, AppColors.line.withValues(alpha: 0.6));
        expect(mark.strokeWidth, 1);
        expect(mark.dashArray, [3, 3]);
      }
      final depth = data.lineBarsData.first;
      expect(depth.color, AppColors.ink);
      expect(depth.barWidth, 2);
      expect(depth.dashArray, isNull);
      expect(depth.dotData.show, isFalse);
    });

    testWidgets('only a rejected rep gets the amber square, at the top', (
      tester,
    ) async {
      await _depth(
        tester,
        feedbackReport(rejected: const [RejectReason.insufficientDepth]),
      );
      final squares = _line(tester).lineBarsData[1];
      expect(squares.spots, [const FlSpot(10, 2)]);
      expect(squares.barWidth, 0);
      expect(squares.color, Colors.transparent);
      expect(
        squares.dotData.getDotPainter(squares.spots.first, 0, squares, 0),
        isA<FeedbackRejectMark>(),
      );

      await _depth(tester, feedbackReport());
      expect(_line(tester).lineBarsData, hasLength(1));
    });

    testWidgets('a push-up deeper than 2 rounds up to the next whole number, '
        'below 0 down', (tester) async {
      await tester.pumpWidget(
        _host(
          FeedbackDepthPlot(
            samples: _depths([2.3, -0.2, 1]),
            reps: const [],
            sliceSeconds: 5,
          ),
        ),
      );
      expect(_line(tester).maxY, 3);
      expect(_line(tester).minY, -1);
    });

    testWidgets('a squat runs up to 1, or the next half above its deepest', (
      tester,
    ) async {
      Future<double> top(List<double> depths) async {
        await tester.pumpWidget(
          _host(
            FeedbackDepthPlot(
              samples: _depths(depths),
              reps: const [],
              sliceSeconds: 5,
              squat: true,
            ),
          ),
        );
        return _line(tester).maxY;
      }

      expect(await top([0.2, 0.9]), 1);
      expect(await top([0.2, 1.1]), 1.5);
      expect(await top([0.2, 1.5]), 1.5);
    });

    testWidgets('a KO round ends the chart at its own length, and a rep or a '
        'sample after it stays at the end or is left out', (tester) async {
      final report = feedbackReport(
        round: const Duration(seconds: 12),
        repGap: 4,
        rejected: const [RejectReason.insufficientDepth],
        samples: 40,
      );
      await _depth(tester, report, sliceSeconds: 2);
      final data = _line(tester);
      expect(data.maxX, 12);
      // Reps close at 2, 6, 10, 14, 18 s.
      expect(data.extraLinesData.verticalLines.map((m) => m.x), [
        2,
        6,
        10,
        12,
        12,
      ]);
      expect(data.lineBarsData[1].spots.single.x, 12);
      final xs = data.lineBarsData.first.spots
          .where((s) => s.isNotNull())
          .map((s) => s.x);
      expect(xs.last, 12);
      expect(xs.every((x) => x <= 12), isTrue);
    });

    testWidgets('a moment without a depth breaks the line', (tester) async {
      await tester.pumpWidget(
        _host(
          FeedbackDepthPlot(
            samples: const [
              FormSample(at: Duration(seconds: 1), depth: 1),
              FormSample(at: Duration(seconds: 2)),
              FormSample(at: Duration(seconds: 3), depth: 1),
            ],
            reps: const [],
            sliceSeconds: 5,
          ),
        ),
      );
      final [first, gap, last] = _line(tester).lineBarsData.first.spots;
      expect(first, const FlSpot(1, 1));
      expect(gap.isNull(), isTrue);
      expect(last, const FlSpot(3, 1));
    });

    testWidgets('the axis numbers are the small gray ones and do not grow '
        'with the text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _depth(tester, feedbackReport());
      await tester.pump(const Duration(milliseconds: 500));
      final label = tester.widget<Text>(find.text('2.0'));
      expect(label.textScaler, TextScaler.noScaling);
      expect(label.style!.fontSize, 10);
      expect(label.style!.color, AppColors.textMuted);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('5s'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without any depth it keeps its height and draws nothing', (
      tester,
    ) async {
      await _depth(tester, feedbackReport(depthSamples: false));
      expect(find.byType(LineChart), findsNothing);
      expect(
        tester.getSize(find.byType(FeedbackDepthPlot)).height,
        FeedbackDepthPlot.height,
      );
    });

    test('hasData: a depth at any moment of the round, not after it', () {
      bool has(List<FormSample> samples) =>
          FeedbackDepthPlot.hasData(samples, sliceSeconds: 5);
      expect(has(feedbackReport().samples), isTrue);
      expect(has(feedbackReport(depthSamples: false).samples), isFalse);
      expect(has(const []), isFalse);
      // The round's last moment counts; a frame handled after it does not.
      expect(
        has(const [FormSample(at: Duration(seconds: 30), depth: 1)]),
        isTrue,
      );
      expect(
        has(const [FormSample(at: Duration(milliseconds: 30100), depth: 1)]),
        isFalse,
      );
      // A KO round of 12 s ends its round at 12 s.
      expect(
        FeedbackDepthPlot.hasData(const [
          FormSample(at: Duration(seconds: 13), depth: 1),
        ], sliceSeconds: 2),
        isFalse,
      );
    });

    testWidgets('a sample after the round does not stretch the scale', (
      tester,
    ) async {
      Future<(double, double)> scale(
        List<double> inRound,
        double after, {
        bool squat = false,
      }) async {
        await tester.pumpWidget(
          _host(
            FeedbackDepthPlot(
              samples: [
                ..._depths(inRound),
                FormSample(at: const Duration(seconds: 31), depth: after),
              ],
              reps: const [],
              sliceSeconds: 5,
              squat: squat,
            ),
          ),
        );
        return (_line(tester).minY, _line(tester).maxY);
      }

      expect(await scale([0.2, 1.2], 3.5), (0, 2));
      expect(await scale([0.2, 1.2], -1.5), (0, 2));
      expect(await scale([0.2, 0.9], 1.6, squat: true), (0, 1));
      // And it is not drawn.
      expect(
        _line(tester).lineBarsData.first.spots
            .where((s) => s.isNotNull())
            .map((s) => s.x),
        [0, 1],
      );
    });

    testWidgets('a depth only after the round draws nothing', (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackDepthPlot(
            samples: [
              FormSample(at: Duration(seconds: 1)),
              FormSample(at: Duration(seconds: 31), depth: 1.4),
            ],
            reps: [],
            sliceSeconds: 5,
          ),
        ),
      );
      expect(find.byType(LineChart), findsNothing);
    });
  });

  group('FeedbackElbowPlot', () {
    testWidgets('the left arm is solid ink, the right dashed gray, from 60 to '
        '180 degrees', (tester) async {
      final report = feedbackReport();
      await tester.pumpWidget(
        _host(FeedbackElbowPlot(samples: report.samples, sliceSeconds: 5)),
      );
      final data = _line(tester);
      expect(data.minY, 60);
      expect(data.maxY, 180);
      expect(data.maxX, 30);
      expect(data.clipData, const FlClipData.vertical());
      final [left, right] = data.lineBarsData;
      expect(left.color, AppColors.ink);
      expect(left.dashArray, isNull);
      expect(left.spots.first, const FlSpot(0, 100));
      expect(right.color, AppColors.line);
      expect(right.dashArray, FeedbackLegend.dashes);
      expect(right.spots.first, const FlSpot(0, 104));
      expect(find.text('180°'), findsOneWidget);
      expect(find.text('60°'), findsOneWidget);
    });

    testWidgets('a KO round labels its own slices', (tester) async {
      final report = feedbackReport(round: const Duration(seconds: 17));
      await tester.pumpWidget(
        _host(FeedbackElbowPlot(samples: report.samples, sliceSeconds: 17 / 6)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_line(tester).maxX, closeTo(17, 1e-9));
      expect(find.text('2.8s'), findsOneWidget);
      expect(find.text('17s'), findsOneWidget);
      expect(find.text('30s'), findsNothing);
    });

    test('hasData: either arm seen at any moment of the round, not after '
        'it', () {
      bool has(List<FormSample> samples) =>
          FeedbackElbowPlot.hasData(samples, sliceSeconds: 5);
      expect(has(feedbackReport().samples), isTrue);
      expect(
        has(feedbackReport(leftElbow: null, rightElbow: 150).samples),
        isTrue,
      );
      expect(
        has(feedbackReport(leftElbow: null, rightElbow: null).samples),
        isFalse,
      );
      expect(
        has(
          feedbackReport(
            leftElbow: null,
            rightElbow: null,
            extraSamples: const [
              FormSample(at: Duration(seconds: 31), leftElbow: 90),
            ],
          ).samples,
        ),
        isFalse,
      );
    });

    testWidgets("a deep bend after the round does not lower the chart's "
        'floor', (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackElbowPlot(
            samples: [
              FormSample(at: Duration.zero, leftElbow: 150, rightElbow: 150),
              FormSample(
                at: Duration(seconds: 31),
                leftElbow: 20,
                rightElbow: 20,
              ),
            ],
            sliceSeconds: 5,
          ),
        ),
      );
      expect(_line(tester).minY, 60);
    });
  });

  group('FeedbackHipPlot', () {
    testWidgets("a squat's hip angle is one solid ink line from 60 to 180 "
        'degrees', (tester) async {
      final report = feedbackReport(
        exercise: ExerciseType.squat,
        hipAngle: 120,
      );
      await tester.pumpWidget(
        _host(FeedbackHipPlot(samples: report.samples, sliceSeconds: 5)),
      );
      final data = _line(tester);
      expect(data.minY, 60);
      expect(data.maxY, 180);
      expect(data.maxX, 30);
      final line = data.lineBarsData.single;
      expect(line.color, AppColors.ink);
      expect(line.dashArray, isNull);
      expect(line.spots.first, const FlSpot(0, 120));
      expect(
        tester.getSize(find.byType(FeedbackHipPlot)).height,
        FeedbackElbowPlot.height,
      );
    });

    testWidgets('a deep bend below 60 degrees lowers the floor to the 30 '
        'degree step under it, never below 0', (tester) async {
      Future<double> floor(double angle) async {
        await tester.pumpWidget(
          _host(
            FeedbackHipPlot(
              samples: [
                const FormSample(at: Duration.zero, hipAngle: 170),
                FormSample(at: const Duration(seconds: 1), hipAngle: angle),
              ],
              sliceSeconds: 5,
            ),
          ),
        );
        return _line(tester).minY;
      }

      expect(await floor(75), 60);
      expect(await floor(59), 30);
      expect(await floor(30), 30);
      expect(await floor(12), 0);
      expect(await floor(-5), 0);
      await tester.pumpWidget(
        _host(
          FeedbackElbowPlot(
            samples: const [
              FormSample(at: Duration.zero, leftElbow: 150, rightElbow: 45),
            ],
            sliceSeconds: 5,
          ),
        ),
      );
      expect(_line(tester).minY, 30);
    });

    test('hasData: a hip angle at any moment of the round, not after it', () {
      bool has(List<FormSample> samples) =>
          FeedbackHipPlot.hasData(samples, sliceSeconds: 5);
      expect(has(feedbackReport().samples), isTrue);
      expect(has(feedbackReport(hipAngle: null).samples), isFalse);
      expect(
        has(
          feedbackReport(
            hipAngle: null,
            extraSamples: const [
              FormSample(at: Duration(seconds: 31), hipAngle: 100),
            ],
          ).samples,
        ),
        isFalse,
      );
    });
  });

  testWidgets('the line charts keep half a square of room on the right, so '
      'a rejected rep at the round end shows all of its square', (
    tester,
  ) async {
    final report = feedbackReport(
      rejected: const [RejectReason.insufficientDepth],
    );
    for (final chart in [
      FeedbackDepthPlot(
        samples: report.samples,
        reps: report.reps,
        sliceSeconds: 5,
      ),
      FeedbackElbowPlot(samples: report.samples, sliceSeconds: 5),
      FeedbackHipPlot(samples: report.samples, sliceSeconds: 5),
    ]) {
      await tester.pumpWidget(_host(chart));
      final right = _line(tester).titlesData.rightTitles.sideTitles;
      expect(right.showTitles, isTrue, reason: '$chart');
      expect(right.reservedSize, FeedbackRejectMark.size / 2);
      expect(feedbackChartRightInset, FeedbackRejectMark.size / 2);
    }
    // The square of a rep at the end (30 s) ends inside the chart.
    await tester.pumpWidget(
      _host(
        FeedbackDepthPlot(
          samples: report.samples,
          reps: const [
            RepRecord(
              index: 1,
              valid: false,
              at: Duration(seconds: 30),
              reason: RejectReason.insufficientDepth,
            ),
          ],
          sliceSeconds: 5,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final width = tester.getSize(find.byType(LineChart)).width;
    final squares = <RRect>[];
    final clips = <Rect>[];
    expect(
      find.byType(LineChart),
      paints..everything((method, args) {
        if (method == #clipRect) clips.add(args[0] as Rect);
        if (method == #drawRRect &&
            (args[1] as Paint).color.toARGB32() ==
                AppColors.warning.toARGB32()) {
          squares.add(args[0] as RRect);
        }
        return true;
      }),
    );
    // The plot is painted right of the 34 of left axis; the square of a rep
    // at 30 s ends exactly at the chart's right edge, inside it. Without
    // the inset it would end half a square past it, cut off.
    expect(squares, hasLength(1));
    expect(squares.single.width, FeedbackRejectMark.size);
    expect(squares.single.right, closeTo(width - 34, 0.01));
    // And nothing cuts it off: no clip ends left of the square.
    for (final clip in clips) {
      expect(clip.right, greaterThanOrEqualTo(squares.single.right));
    }
  });

  group('FeedbackPacePlot', () {
    testWidgets('a lime bar with an ink edge per slice; an empty slice has '
        'no edge', (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackPacePlot(buckets: [2, 0, 1, 0, 0, 3], sliceSeconds: 5),
        ),
      );
      final data = _bars(tester);
      expect(data.maxY, 3);
      final rods = [for (final g in data.barGroups) g.barRods.single];
      expect(rods.map((r) => r.toY), [2, 0, 1, 0, 0, 3]);
      for (final rod in rods) {
        expect(rod.color, AppColors.accent);
        expect(rod.width, 16);
        expect(
          rod.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(AppRadius.mark)),
        );
      }
      expect(
        rods[0].borderSide,
        const BorderSide(color: AppColors.ink, width: 1.5),
      );
      expect(rods[1].borderSide.width, 0);
    });

    testWidgets('the scale shows at least 2', (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackPacePlot(buckets: [1, 0, 0, 0, 0, 0], sliceSeconds: 5),
        ),
      );
      expect(_bars(tester).maxY, 2);
    });

    testWidgets('each bar is labelled with its slice start', (tester) async {
      await tester.pumpWidget(
        _host(
          const FeedbackPacePlot(
            buckets: [1, 1, 1, 1, 1, 1],
            sliceSeconds: 17 / 6,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      for (final label in ['0s', '2.8s', '5.7s', '8.5s', '11.3s', '14.2s']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });

  group('FeedbackRejectMark', () {
    test('its square hangs from the top of the mark, swatch-sized', () {
      expect(
        FeedbackRejectMark.box(const Offset(20, 6)),
        const Rect.fromLTWH(15, 6, 10, 10),
      );
      const mark = FeedbackRejectMark();
      expect(mark.getSize(const FlSpot(0, 0)), const Size.square(10));
      expect(mark.mainColor, AppColors.warning);
      expect(
        mark.lerp(mark, const FeedbackRejectMark(), 0.5),
        isA<FeedbackRejectMark>(),
      );
      expect(mark, const FeedbackRejectMark());
    });

    testWidgets('it paints amber, then a 1.5 ink edge inside', (tester) async {
      await tester.pumpWidget(
        CustomPaint(painter: _MarkPainter(), size: const Size(40, 40)),
      );
      final square = RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 0, 10, 10),
        const Radius.circular(AppRadius.mark),
      );
      expect(
        find.byType(CustomPaint),
        paints
          ..rrect(rrect: square, color: AppColors.warning)
          ..rrect(
            rrect: square.deflate(0.75),
            color: AppColors.ink,
            style: PaintingStyle.stroke,
            strokeWidth: 1.5,
          ),
      );
    });
  });

  group('FeedbackLegend', () {
    testWidgets('names the solid ink line 왼팔 and the dashed gray one 오른팔', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FeedbackLegend()));
      expect(find.text('왼팔'), findsOneWidget);
      expect(find.text('오른팔'), findsOneWidget);
      final lines = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(FeedbackLegend),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((p) => p.painter! as FeedbackLegendLine)
          .toList();
      expect(lines.map((l) => (l.color, l.dashes)), [
        (AppColors.ink, null),
        (AppColors.line, FeedbackLegend.dashes),
      ]);
      expect(
        tester.getSize(
          find
              .descendant(
                of: find.byType(FeedbackLegend),
                matching: find.byType(CustomPaint),
              )
              .first,
        ),
        const Size(16, 4),
      );
    });

    testWidgets(
      'a solid sample is one line, a dashed one is cut by its dashes',
      (tester) async {
        await tester.pumpWidget(
          const Center(
            child: CustomPaint(
              size: Size(16, 4),
              painter: FeedbackLegendLine(color: AppColors.ink),
            ),
          ),
        );
        expect(
          find.byType(CustomPaint),
          paints..line(p1: const Offset(0, 2), p2: const Offset(16, 2)),
        );
        await tester.pumpWidget(
          const Center(
            child: CustomPaint(
              size: Size(16, 4),
              painter: FeedbackLegendLine(
                color: AppColors.line,
                dashes: [5, 4],
              ),
            ),
          ),
        );
        expect(
          find.byType(CustomPaint),
          paints
            ..line(p1: const Offset(0, 2), p2: const Offset(5, 2))
            ..line(p1: const Offset(9, 2), p2: const Offset(14, 2)),
        );
        expect(
          const FeedbackLegendLine(color: AppColors.ink)
              .shouldRepaint(const FeedbackLegendLine(color: AppColors.line)),
          isTrue,
        );
        expect(
          const FeedbackLegendLine(color: AppColors.ink)
              .shouldRepaint(const FeedbackLegendLine(color: AppColors.ink)),
          isFalse,
        );
      },
    );
  });
}

/// Draws one reject mark with its top at (20, 0).
class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => const FeedbackRejectMark().draw(
    canvas,
    const FlSpot(0, 0),
    const Offset(20, 0),
  );

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
