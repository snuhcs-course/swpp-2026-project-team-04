import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/archive_chart.dart';

import 'battle_test_support.dart';

void main() {
  setUpAll(loadBattleFonts);

  group('the trend chart layout (P13)', () {
    const size = Size(350, 150);

    test('one point in the middle of each slot, oldest left', () {
      final points = TrendChartLayout.points([10, 20, 40], size);
      expect(points.map((p) => p.dx), [
        closeTo(350 / 6, 0.001),
        closeTo(350 / 2, 0.001),
        closeTo(350 * 5 / 6, 0.001),
      ]);
    });

    test('the highest at the top line, zero at the base line', () {
      final points = TrendChartLayout.points([0, 40], size);
      expect(points.first.dy, size.height - TrendChartLayout.padBottom);
      expect(points.last.dy, TrendChartLayout.padTop);
    });

    test('all zero stays on the base line; no values, no points', () {
      expect(
        TrendChartLayout.points([0, 0], size).map((p) => p.dy),
        everyElement(size.height - TrendChartLayout.padBottom),
      );
      expect(TrendChartLayout.points([], size), isEmpty);
    });

    test('the mean', () {
      expect(TrendChartLayout.mean([60, 110, 15]), closeTo(61.67, 0.01));
      expect(TrendChartLayout.mean([]), 0);
    });
  });

  group('the painter', () {
    ArchiveTrendPainter painter(List<int> values) => ArchiveTrendPainter(
      values: values,
      labelStyle: const TextStyle(color: AppColors.ink),
      meanStyle: const TextStyle(color: AppColors.textSecondary),
    );

    testWidgets('paints one, several or no values', (tester) async {
      for (final values in [
        [110],
        [110, 170, 0, 35, 15],
        <int>[],
      ]) {
        await tester.pumpWidget(
          Center(
            child: SizedBox(
              width: 350,
              height: 150,
              child: CustomPaint(painter: painter(values)),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    test('repaints only when the values or styles change', () {
      expect(painter([1, 2]).shouldRepaint(painter([1, 2])), isFalse);
      expect(painter([1, 2]).shouldRepaint(painter([1, 3])), isTrue);
      expect(
        painter([1]).shouldRepaint(
          ArchiveTrendPainter(
            values: const [1],
            labelStyle: const TextStyle(color: AppColors.warning),
            meanStyle: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        isTrue,
      );
    });
  });
}
