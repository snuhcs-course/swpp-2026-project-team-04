import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/squat_height_overlay.dart';

/// A frame the size of the box, so heights are drawn where they are.
const _frame = PoseFrame.empty(imageWidth: 290, imageHeight: 387);

JudgeSnapshot _squat(RepPhase phase, {double? hip = 200, double? knee = 260}) =>
    JudgeSnapshot(phase: phase, squatHipY: hip, squatKneeY: knee);

Future<RenderObject> _pump(
  WidgetTester tester, {
  PoseFrame? frame = _frame,
  required JudgeSnapshot snapshot,
}) async {
  await tester.pumpWidget(
    Center(
      child: SizedBox(
        width: 290,
        height: 387,
        child: SquatHeightOverlay(frame: frame, snapshot: snapshot),
      ),
    ),
  );
  return tester.renderObject(find.byType(CustomPaint));
}

void main() {
  testWidgets('the hip and knee lines are bold: 8 of their color over 14 of '
      'ink, the knee amber and the hip white while standing; the knee first, '
      'so the hip lies over it; both start after the wider pill (A9 spec 4)', (
    tester,
  ) async {
    final overlay = await _pump(tester, snapshot: _squat(RepPhase.up));
    final start = _lineStart(['무릎', '엉덩이']);
    // The design's lines start at 62 of its 290: after its pills.
    expect(start, greaterThan(_pill('무릎', 0).right));
    expect(
      overlay,
      paints
        ..line(
          p1: Offset(start, 260),
          p2: const Offset(278, 260),
          color: AppColors.ink,
          strokeWidth: 14,
        )
        ..line(
          p1: Offset(start, 260),
          p2: const Offset(278, 260),
          color: AppColors.warning,
          strokeWidth: 8,
        )
        ..line(
          p1: Offset(start, 200),
          p2: const Offset(278, 200),
          color: AppColors.ink,
          strokeWidth: 14,
        )
        ..line(
          p1: Offset(start, 200),
          p2: const Offset(278, 200),
          color: AppColors.card,
          strokeWidth: 8,
        ),
    );
    expect(overlay, paintsExactlyCountTimes(#drawLine, 4));
    expect(SquatHeightPainter.lineWidth, 8);
    expect(SquatHeightPainter.outlineWidth, 14);
  });

  testWidgets('at the bottom of a rep the hip line turns status green, the '
      'knee line stays amber', (tester) async {
    final overlay = await _pump(
      tester,
      snapshot: _squat(RepPhase.bottom, hip: 258),
    );
    expect(
      overlay,
      paints
        ..line(color: AppColors.ink, strokeWidth: 14)
        ..line(color: AppColors.warning, strokeWidth: 8)
        ..line(color: AppColors.ink, strokeWidth: 14)
        // Over the knee line it all but touches.
        ..line(color: AppColors.statusGood, strokeWidth: 8)
        // Both names after both lines, the hip's last.
        ..rrect(rrect: _pill('무릎', 260), color: AppColors.warning)
        ..rrect(rrect: _pill('무릎', 260), style: PaintingStyle.stroke)
        ..rrect(rrect: _pill('엉덩이', 258), color: AppColors.statusGood),
    );
  });

  testWidgets("each name is a pill 22 tall at its line's left end, in the "
      "line's color with a 2 ink edge", (tester) async {
    final overlay = await _pump(tester, snapshot: _squat(RepPhase.up));
    expect(
      overlay,
      paints
        ..rrect(rrect: _pill('무릎', 260), color: AppColors.warning)
        ..rrect(
          rrect: _pill('무릎', 260),
          color: AppColors.ink,
          style: PaintingStyle.stroke,
          strokeWidth: 2,
        )
        ..rrect(rrect: _pill('엉덩이', 200), color: AppColors.card)
        ..rrect(
          rrect: _pill('엉덩이', 200),
          color: AppColors.ink,
          style: PaintingStyle.stroke,
          strokeWidth: 2,
        ),
    );
  });

  testWidgets('nothing is drawn without a frame, without both heights, or '
      'with the person lost', (tester) async {
    for (final (frame, snapshot) in [
      (null, _squat(RepPhase.up)),
      (_frame, _squat(RepPhase.up, hip: null)),
      (_frame, _squat(RepPhase.up, knee: null)),
      (_frame, _squat(RepPhase.lost)),
      (
        const PoseFrame.empty(imageWidth: 0, imageHeight: 387),
        _squat(RepPhase.up),
      ),
    ]) {
      await tester.pumpWidget(
        Center(
          child: SizedBox(
            width: 290,
            height: 387,
            child: SquatHeightOverlay(frame: frame, snapshot: snapshot),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsNothing);
    }
  });

  test('repaints for a new frame or a new judge state only', () {
    final painter = SquatHeightPainter(
      frame: _frame,
      snapshot: _squat(RepPhase.up),
    );
    expect(
      painter.shouldRepaint(
        SquatHeightPainter(frame: _frame, snapshot: painter.snapshot),
      ),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        SquatHeightPainter(frame: _frame, snapshot: _squat(RepPhase.bottom)),
      ),
      isTrue,
    );
  });
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
