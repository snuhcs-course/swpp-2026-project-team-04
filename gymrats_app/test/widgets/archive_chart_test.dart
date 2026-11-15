import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/archive_chart.dart';

/// The mockup's push-up scores (BArchive `growth()`).
const _designScores = [80, 95, 110, 105, 130, 150, 185, 240];

/// The mockup's graph box.
const _designSize = Size(286, 96);

void main() {
  group('GrowthChartLayout', () {
    test('the mockup scores land where BArchive draws them', () {
      final points = GrowthChartLayout.points(_designScores, _designSize);
      // BArchive: x = 12 + i * 262 / 7, y = 88 - v / (240 * 1.04) * 64.
      expect(points, hasLength(_designScores.length));
      for (final (i, score) in _designScores.indexed) {
        expect(
          points[i],
          offsetMoreOrLessEquals(
            Offset(12 + i * 262 / 7, 88 - score / 249.6 * 64),
            epsilon: 0.01,
          ),
        );
      }
      // The path's first and last points as the mockup prints them.
      expect(
        points.first,
        offsetMoreOrLessEquals(const Offset(12, 67.5), epsilon: 0.05),
      );
      expect(
        points.last,
        offsetMoreOrLessEquals(const Offset(274, 26.5), epsilon: 0.05),
      );
    });

    test('a single score sits at the right end, under the headroom', () {
      final points = GrowthChartLayout.points(const [80], _designSize);
      expect(
        points.single,
        offsetMoreOrLessEquals(
          const Offset(274, 88 - 64 / 1.04),
          epsilon: 0.01,
        ),
      );
    });

    test('zero scores lie on the base line; no scores, no points', () {
      final points = GrowthChartLayout.points(const [0, 0], _designSize);
      expect(points.map((p) => p.dy), [88, 88]);
      expect(GrowthChartLayout.points(const [], _designSize), isEmpty);
      expect(GrowthChartLayout.baseOf(96), 88);
    });
  });

  group('archiveBarHeights', () {
    test('the mockup reps give the mockup bars', () {
      expect(
        archiveBarHeights(
          const [7, 8, 8, 21, 24, 26, 29],
          max: 58,
          min: 6,
          zero: 3,
        ),
        [14, 16, 16, 42, 48, 52, 58],
      );
      // W7-STATS's archive (W7Archive.dc.html), with a day without battles.
      expect(
        archiveBarHeights(
          const [12, 27, 0, 10, 43, 16, 28],
          max: 58,
          min: 6,
          zero: 3,
        ),
        [16, 36, 3, 13, 58, 22, 38],
      );
    });

    test(
      'a day without battles is the thin line; a few reps the least bar',
      () {
        expect(archiveBarHeights(const [0, 1], max: 58, min: 6, zero: 3), [
          3,
          58,
        ]);
        expect(archiveBarHeights(const [1, 100], max: 58, min: 6, zero: 3), [
          6,
          58,
        ]);
        expect(archiveBarHeights(const [0, 0, 0], max: 58, min: 6, zero: 3), [
          3,
          3,
          3,
        ]);
        expect(archiveBarHeights(const [], max: 58, min: 6, zero: 3), isEmpty);
      },
    );
  });

  group('ArchiveGrowthPainter', () {
    const key = ValueKey('chart');

    Future<void> paintChart(WidgetTester tester, List<int> scores) =>
        tester.pumpWidget(
          Center(
            child: CustomPaint(
              key: key,
              size: _designSize,
              painter: ArchiveGrowthPainter(
                scores: scores,
                valueStyle: const TextStyle(),
              ),
            ),
          ),
        );

    testWidgets('the base line, the lime area, the ink line, the dots and '
        'the last ring with its score', (tester) async {
      await paintChart(tester, _designScores);
      final points = GrowthChartLayout.points(_designScores, _designSize);
      final pattern = paints
        ..line(
          p1: const Offset(10, 88),
          p2: const Offset(276, 88),
          color: AppColors.chartBar,
        )
        ..path(color: AppColors.accent.withValues(alpha: 0.45))
        ..path(color: AppColors.ink, style: PaintingStyle.stroke);
      for (final point in points.take(7)) {
        pattern.circle(
          x: point.dx,
          y: point.dy,
          radius: 3,
          color: AppColors.ink,
        );
      }
      pattern
        ..circle(x: 274, radius: 6.5, color: AppColors.accent)
        ..circle(
          x: 274,
          radius: 6.5,
          color: AppColors.ink,
          style: PaintingStyle.stroke,
        )
        ..paragraph();
      expect(find.byKey(key), pattern);
      // 7 dots and the last point's fill and ring.
      expect(find.byKey(key), paintsExactlyCountTimes(#drawCircle, 9));
    });

    testWidgets('many scores: only the last point gets a mark', (tester) async {
      await paintChart(tester, [for (var i = 0; i < 13; i++) 10 * i]);
      expect(find.byKey(key), paintsExactlyCountTimes(#drawCircle, 2));
      expect(find.byKey(key), paintsExactlyCountTimes(#drawPath, 2));
    });

    testWidgets('one score: the ring and its score, no line or area', (
      tester,
    ) async {
      await paintChart(tester, const [80]);
      expect(find.byKey(key), paintsExactlyCountTimes(#drawPath, 0));
      expect(find.byKey(key), paintsExactlyCountTimes(#drawCircle, 2));
      expect(find.byKey(key), paintsExactlyCountTimes(#drawParagraph, 1));
    });

    testWidgets('no scores: only the base line', (tester) async {
      await paintChart(tester, const []);
      expect(find.byKey(key), paintsExactlyCountTimes(#drawLine, 1));
      expect(find.byKey(key), paintsExactlyCountTimes(#drawCircle, 0));
      expect(find.byKey(key), paintsExactlyCountTimes(#drawParagraph, 0));
    });

    test('repaints only for new scores, style or text size', () {
      const style = TextStyle();
      const painter = ArchiveGrowthPainter(scores: [1, 2], valueStyle: style);
      expect(
        painter.shouldRepaint(
          const ArchiveGrowthPainter(scores: [1, 2], valueStyle: style),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          const ArchiveGrowthPainter(scores: [1, 3], valueStyle: style),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const ArchiveGrowthPainter(
            scores: [1, 2],
            valueStyle: TextStyle(fontWeight: FontWeight.w300),
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const ArchiveGrowthPainter(
            scores: [1, 2],
            valueStyle: style,
            textScaler: TextScaler.linear(2),
          ),
        ),
        isTrue,
      );
    });
  });

  group('ArchiveExerciseIcon', () {
    testWidgets('a push-up: the head and four strokes, in ink', (tester) async {
      await tester.pumpWidget(
        const Center(child: ArchiveExerciseIcon(ExerciseType.pushUp)),
      );
      final icon = find.byType(ArchiveExerciseIcon);
      expect(tester.getSize(icon), const Size.square(22));
      expect(
        icon,
        paints
          ..circle(x: 4.5, y: 9, radius: 2, color: AppColors.ink)
          ..line(p1: const Offset(7, 10.6), p2: const Offset(20, 14.5))
          ..line(p1: const Offset(8.6, 11.1), p2: const Offset(8.6, 17))
          ..line(p1: const Offset(20, 14.5), p2: const Offset(21.3, 17.1))
          ..line(p1: const Offset(2, 19.5), p2: const Offset(22, 19.5)),
      );
      expect(icon, paintsExactlyCountTimes(#drawLine, 4));
      expect(icon, paintsExactlyCountTimes(#drawPath, 0));
    });

    testWidgets('a squat: the head, the bent body and two strokes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(child: ArchiveExerciseIcon(ExerciseType.squat, size: 24)),
      );
      final icon = find.byType(ArchiveExerciseIcon);
      expect(icon, paints..circle(x: 10.5, y: 4, radius: 2));
      expect(icon, paintsExactlyCountTimes(#drawPath, 1));
      expect(icon, paintsExactlyCountTimes(#drawLine, 2));
    });

    test('repaints only for another exercise', () {
      const pushUp = ArchiveExerciseIconPainter(ExerciseType.pushUp);
      expect(
        pushUp.shouldRepaint(
          const ArchiveExerciseIconPainter(ExerciseType.pushUp),
        ),
        isFalse,
      );
      expect(
        pushUp.shouldRepaint(
          const ArchiveExerciseIconPainter(ExerciseType.squat),
        ),
        isTrue,
      );
    });
  });

  group('ArchiveStatsIcon', () {
    testWidgets("the statistics pill's icon: a floor and three bars in ink", (
      tester,
    ) async {
      await tester.pumpWidget(const Center(child: ArchiveStatsIcon()));
      final icon = find.byType(ArchiveStatsIcon);
      expect(tester.getSize(icon), const Size.square(18));
      expect(
        icon,
        paints
          ..line(
            p1: const Offset(4, 20),
            p2: const Offset(20, 20),
            color: AppColors.ink,
          )
          ..line(p1: const Offset(7, 16), p2: const Offset(7, 11))
          ..line(p1: const Offset(12, 16), p2: const Offset(12, 6))
          ..line(p1: const Offset(17, 16), p2: const Offset(17, 8)),
      );
      expect(
        const ArchiveStatsIconPainter().shouldRepaint(
          const ArchiveStatsIconPainter(),
        ),
        isFalse,
      );
    });
  });
}
