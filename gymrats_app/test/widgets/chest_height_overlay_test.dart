import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';

import '../support/pose_fixtures.dart';

/// A frame the size of the box (no crop), the shoulders level at y 150.
final _frame = PoseFrame(
  imageWidth: 290,
  imageHeight: 387,
  keypoints: {
    BodyLandmark.leftShoulder: kp(BodyLandmark.leftShoulder, 100, 150),
    BodyLandmark.rightShoulder: kp(BodyLandmark.rightShoulder, 190, 150),
  },
);

ChestHeightGuidePainter _painter({RepPhase? phase, double? baseline = 100}) =>
    ChestHeightGuidePainter(
      frame: _frame,
      baselineY: baseline,
      mirror: false,
      phase: phase,
    );

Future<RenderObject> _paint(
  WidgetTester tester,
  ChestHeightGuidePainter painter,
) async {
  await tester.pumpWidget(
    Center(
      child: SizedBox(
        width: 290,
        height: 387,
        child: CustomPaint(painter: painter),
      ),
    ),
  );
  return tester.renderObject(find.byType(CustomPaint));
}

/// The pill of [name] centered on the line at [y]: 4 from the left, 8
/// beside the 13 bold name ([BattleCameraText.cameraLineLabel]), 22 tall
/// and fully round.
RRect _pill(String name, double y) {
  final text = TextPainter(
    text: TextSpan(text: name, style: BattleCameraText.cameraLineLabel),
    textDirection: TextDirection.ltr,
  )..layout();
  return RRect.fromRectAndRadius(
    Rect.fromLTWH(4, y - 11, text.width + 16, 22),
    const Radius.circular(11),
  );
}

/// Where the lines start, as in the design: 4 after the widest of the
/// pills of [names].
double _lineStart(List<String> names) =>
    names.map((name) => _pill(name, 0).right).reduce(math.max) + 4;

void main() {
  testWidgets('the start height is white dashes 3 over 6 of ink, named in a '
      'white pill (A9 spec 4)', (tester) async {
    final guide = await _paint(tester, _painter());
    // After the wider of the two pills, as in the design.
    final start = _lineStart(['어깨', '시작 높이']);
    expect(
      guide,
      paints
        ..line(
          p1: Offset(start, 100),
          p2: Offset(start + 6, 100),
          color: AppColors.ink,
          strokeWidth: 6,
        )
        ..line(
          p1: Offset(start, 100),
          p2: Offset(start + 6, 100),
          color: AppColors.card,
          strokeWidth: 3,
        )
        ..rrect(rrect: _pill('시작 높이', 100), color: AppColors.card)
        ..rrect(
          rrect: _pill('시작 높이', 100),
          color: AppColors.ink,
          style: PaintingStyle.stroke,
          strokeWidth: 2,
        ),
    );
    expect(ChestHeightGuidePainter.dashWidth, 3);
    expect(ChestHeightGuidePainter.dashOutlineWidth, 6);
  });

  testWidgets('the shoulder line is white 8 over 14 of ink, over the start '
      'height, with a 9 dot edged in 3 of ink and a white "어깨" pill', (
    tester,
  ) async {
    // Without a start height, so the shoulder line is the first one drawn.
    final guide = await _paint(
      tester,
      _painter(phase: RepPhase.descending, baseline: null),
    );
    // After its own pill.
    final start = _lineStart(['어깨']);
    expect(
      guide,
      paints
        ..line(
          p1: Offset(start, 150),
          p2: const Offset(278, 150),
          color: AppColors.ink,
          strokeWidth: 14,
        )
        ..line(
          p1: Offset(start, 150),
          p2: const Offset(278, 150),
          color: AppColors.card,
          strokeWidth: 8,
        )
        ..circle(
          x: 145,
          y: 150,
          radius: 9,
          color: AppColors.card,
          style: PaintingStyle.fill,
        )
        ..circle(
          x: 145,
          y: 150,
          radius: 9,
          color: AppColors.ink,
          style: PaintingStyle.stroke,
          strokeWidth: 3,
        )
        ..rrect(rrect: _pill('어깨', 150), color: AppColors.card),
    );
  });

  testWidgets('at the bottom of a rep the shoulder line, its dot and its '
      'pill turn status green; the start height stays white', (tester) async {
    final guide = await _paint(
      tester,
      _painter(phase: RepPhase.bottom, baseline: null),
    );
    expect(
      guide,
      paints
        ..line(color: AppColors.ink, strokeWidth: 14)
        ..line(color: AppColors.statusGood, strokeWidth: 8)
        ..circle(radius: 9, color: AppColors.statusGood)
        ..rrect(rrect: _pill('어깨', 150), color: AppColors.statusGood),
    );
  });

  testWidgets('at the top of a rep the start height\'s pill stands above the '
      'shoulder\'s, so neither covers the other; both after the lines', (
    tester,
  ) async {
    // The shoulders at the start height, y 150.
    final guide = await _paint(tester, _painter(baseline: 150));
    expect(
      guide,
      paints
        ..rrect(rrect: _pill('시작 높이', 150 - 22 - 2), color: AppColors.card)
        ..rrect(
          rrect: _pill('시작 높이', 150 - 22 - 2),
          style: PaintingStyle.stroke,
        )
        ..rrect(rrect: _pill('어깨', 150), color: AppColors.card),
    );
    // Further down, each on its own line.
    expect(
      await _paint(tester, _painter(baseline: 100)),
      paints
        ..rrect(rrect: _pill('시작 높이', 100), color: AppColors.card)
        ..rrect(rrect: _pill('시작 높이', 100), style: PaintingStyle.stroke)
        ..rrect(rrect: _pill('어깨', 150)),
    );
  });

  testWidgets('without a start height only the shoulder line is drawn', (
    tester,
  ) async {
    final guide = await _paint(tester, _painter(baseline: null));
    // The shoulder line's ink and white, and no dashes or bracket.
    expect(guide, paintsExactlyCountTimes(#drawLine, 2));
    // With one, its dashes (ink and white each) and the bracket come first.
    final dashes = ((290 - 12 - _lineStart(['어깨', '시작 높이'])) / 12).ceil();
    expect(
      await _paint(tester, _painter()),
      paintsExactlyCountTimes(#drawLine, 2 * dashes + 3 + 2),
    );
  });

  testWidgets('the overlay gives the painter the judge\'s phase', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChestHeightOverlay(
            frame: _frame,
            snapshot: const JudgeSnapshot(
              phase: RepPhase.bottom,
              shoulderDrop: 0.7,
              topShoulderY: 100,
            ),
          ),
        ),
      ),
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) =>
                        w is CustomPaint &&
                        w.painter is ChestHeightGuidePainter,
                  ),
                )
                .painter!
            as ChestHeightGuidePainter;
    expect(painter.phase, RepPhase.bottom);
  });

  test('repaints when the phase changes', () {
    final painter = _painter(phase: RepPhase.up);
    expect(painter.shouldRepaint(_painter(phase: RepPhase.up)), isFalse);
    expect(painter.shouldRepaint(_painter(phase: RepPhase.bottom)), isTrue);
  });
}
