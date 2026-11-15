import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/tutorial_rep_bot.dart';

void main() {
  const figures = {
    'pushUpSide': RepBotFigure.pushUpSide,
    'squatFront': RepBotFigure.squatFront,
    'pushUpFront': RepBotFigure.pushUpFront,
  };

  test('a bar moves its ends in straight lines from top to bottom', () {
    const bar = RepBotBar(
      [0, 0, 10, 0, 20, 40, 30, 40],
      width: 4,
      color: AppColors.ink,
    );
    expect(bar.endsAt(0), (Offset.zero, const Offset(10, 0)));
    expect(bar.endsAt(1), (const Offset(20, 40), const Offset(30, 40)));
    expect(bar.endsAt(0.5), (const Offset(10, 20), const Offset(20, 20)));
  });

  test('the head drops with the depth', () {
    const squat = RepBotFigure.squatFront;
    expect(squat.headAt(0), squat.headTop);
    expect(squat.headAt(1), squat.headBottom);
    expect(squat.headAt(0.5).dy, (squat.headTop.dy + squat.headBottom.dy) / 2);
    expect(
      RepBotFigure.pushUpFront.headAt(1),
      RepBotFigure.pushUpFront.headTop,
    );
  });

  test('the squat hip sinks: a deeper squat is below the pass line', () {
    final hip = RepBotFigure.squatFront.hip!;
    final pass = RepBotPainter.hipY(hip, 0.75);
    expect(RepBotPainter.hipY(hip, 1), greaterThan(pass));
    expect(RepBotPainter.hipY(hip, 0.35), lessThan(pass));
    expect(RepBotFigure.pushUpSide.hip, isNull);
  });

  test('every bar has two poses of two ends', () {
    for (final MapEntry(key: name, value: figure) in figures.entries) {
      for (final bar in [...figure.limbs, figure.visor]) {
        expect(bar.ends, hasLength(8), reason: name);
      }
      expect(figure.visor.color, AppColors.opponent, reason: name);
      expect(figure.visor.shine, isFalse, reason: name);
    }
  });

  for (final MapEntry(key: name, value: figure) in figures.entries) {
    for (final depth in [0.0, 0.5, 1.0]) {
      test('$name paints at depth $depth', () async {
        final recorder = ui.PictureRecorder();
        RepBotPainter(
          figure: figure,
          depth: depth,
          passDepth: figure.hip == null ? null : 0.75,
          passLabel: '기준 깊이',
        ).paint(Canvas(recorder), const Size(260, 400));
        final image = await recorder.endRecording().toImage(260, 400);
        final pixels = await image.toByteData();
        // Something was drawn.
        expect(pixels!.buffer.asUint8List().any((value) => value != 0), isTrue);
      });
    }
  }

  test('repaints only when what it shows changes', () {
    const a = RepBotPainter(figure: RepBotFigure.squatFront, depth: 0.5);
    expect(
      a.shouldRepaint(
        const RepBotPainter(figure: RepBotFigure.squatFront, depth: 0.5),
      ),
      isFalse,
    );
    expect(
      a.shouldRepaint(
        const RepBotPainter(figure: RepBotFigure.squatFront, depth: 1),
      ),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        const RepBotPainter(figure: RepBotFigure.pushUpSide, depth: 0.5),
      ),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        const RepBotPainter(
          figure: RepBotFigure.squatFront,
          depth: 0.5,
          passDepth: 0.75,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('the widget takes its figure\'s size and draws the label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Center(
          child: TutorialRepBot(
            figure: RepBotFigure.squatFront,
            depth: 1,
            passDepth: 0.75,
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(TutorialRepBot)),
      RepBotFigure.squatFront.viewBox.size,
    );
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(TutorialRepBot),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = paint.painter! as RepBotPainter;
    expect(painter.passDepth, 0.75);
    expect(painter.passLabel, '기준 깊이');
    expect(painter.labelStyle?.color, AppColors.ink);
  });
}
