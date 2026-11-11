import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_banner.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_reject_sign.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

import 'battle_test_support.dart';

/// The pictograms are drawn 96 points wide here, the design's own size, so a
/// probe point is a coordinate of the design's drawing.
Future<PaintedPicture> _icon(WidgetTester tester, int icon) => paintPicture(
  tester,
  CustomPaint(
    size: const Size.square(BattleRejectIconPainter.viewSize),
    painter: BattleRejectIconPainter(icon),
  ),
  size: const Size.square(BattleRejectIconPainter.viewSize),
);

BattleFxSign _sign(
  RejectReason reason, {
  bool average = false,
  int points = 5,
  double scale = 1,
  double rotation = 0,
  double opacity = 1,
}) => BattleFxSign(
  reason: reason,
  average: average,
  points: points,
  scale: scale,
  rotation: rotation,
  opacity: opacity,
);

/// Where the design's 360 x 780 frame has the sign's box: in the middle,
/// [BattleRejectSignView.riseAboveLine] above the line at 390.
const _signAt = Offset(92, 340);

/// The point the sign grows and turns around, in the frame.
const _pivot = Offset(92 + 88, 340 + 86);

Future<void> _pumpSign(WidgetTester tester, BattleFxSign sign) =>
    tester.pumpWidget(
      battleTestApp(
        Stack(
          children: [
            Positioned(
              left: _signAt.dx,
              top: _signAt.dy,
              child: BattleRejectSignView(sign: sign),
            ),
          ],
        ),
      ),
    );

/// The white tile's box on screen.
Rect _tile(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: find.byType(CustomPaint),
        matching: find.byType(DecoratedBox),
      )
      .first,
);

void main() {
  setUpAll(loadBattleFonts);

  group('BattleRejectIconPainter', () {
    /// Where each pictogram has its gray head (or the phone's camera), the
    /// middle of an ink arrow head, and a point of its floor line.
    const marks = <({Offset head, Offset arrow, Offset floor})>[
      (head: Offset(15, 50), arrow: Offset(44, 33), floor: Offset(45, 84)),
      (head: Offset(15, 44), arrow: Offset(52, 23), floor: Offset(45, 84)),
      (head: Offset(48, 22), arrow: Offset(9, 54), floor: Offset(45, 84)),
      (head: Offset(15, 40), arrow: Offset(74, 33), floor: Offset(45, 84)),
      (head: Offset(15, 42), arrow: Offset(52, 71), floor: Offset(70, 84)),
      (head: Offset(15, 40), arrow: Offset(60, 37), floor: Offset(40, 84)),
      (head: Offset(15, 40), arrow: Offset(66, 29), floor: Offset(48, 86)),
      (head: Offset(48, 28), arrow: Offset(14, 48), floor: Offset(20, 84)),
      (head: Offset(46, 16), arrow: Offset(16, 39), floor: Offset(75, 86)),
      (head: Offset(40, 14), arrow: Offset(72, 25), floor: Offset(65, 86)),
    ];

    for (var i = 0; i < BattleRejectIconPainter.count; i++) {
      testWidgets('pictogram $i: a gray figure, an ink arrow, a floor', (
        tester,
      ) async {
        final picture = await _icon(tester, i);
        final mark = marks[i];
        expect(picture.at(mark.head.dx, mark.head.dy), AppColors.line);
        expect(picture.at(mark.arrow.dx, mark.arrow.dy), AppColors.ink);
        expect(
          picture.at(mark.floor.dx, mark.floor.dy),
          // "On the floor" draws its floor as the thing to notice.
          i == 6 ? AppColors.ink : AppColors.pictogramFloor,
        );
      });
    }

    testWidgets('the target lines are dashed: 5 drawn, 6 left open', (
      tester,
    ) async {
      final shoulders = await _icon(tester, 2);
      expect(shoulders.at(20, 45), AppColors.ink);
      expect(shoulders.at(26, 45), AppColors.card);
      expect(shoulders.at(31, 45), AppColors.ink);
      final squat = await _icon(tester, 8);
      expect(squat.at(10, 61), AppColors.ink);
      expect(squat.at(16, 61), AppColors.card);
      expect(squat.at(21, 61), AppColors.ink);
    });

    testWidgets('"hold the phone still" has two arrows pointing down', (
      tester,
    ) async {
      final picture = await _icon(tester, 7);
      expect(picture.at(14, 48), AppColors.ink);
      expect(picture.at(82, 48), AppColors.ink);
      expect(picture.at(48, 45), AppColors.card, reason: 'the phone is hollow');
      expect(picture.at(35, 40), AppColors.line, reason: 'the phone\'s edge');
    });

    for (var i = 0; i < BattleRejectIconPainter.count; i++) {
      test('pictogram $i: every number of the reviewed drawing is kept', () {
        expectReviewedDrawing(
          'pictogram $i',
          paintedOps(
            BattleRejectIconPainter(i),
            const Size.square(BattleRejectIconPainter.viewSize),
          ),
        );
      });
    }

    test('drawn 112 wide it is the same picture, 112 / 96 as large', () {
      final ops = paintedOps(
        const BattleRejectIconPainter(0),
        const Size.square(112),
      );
      expect(ops[1], 'scale(1.167, 1.167)');
    });

    test('there are ten, and no other number is accepted', () {
      expect(BattleRejectIconPainter.count, 10);
      expect(() => BattleRejectIconPainter(10), throwsAssertionError);
      expect(() => BattleRejectIconPainter(-1), throwsAssertionError);
    });

    test('repaints only for another pictogram', () {
      const painter = BattleRejectIconPainter(3);
      expect(painter.shouldRepaint(const BattleRejectIconPainter(3)), isFalse);
      expect(painter.shouldRepaint(const BattleRejectIconPainter(4)), isTrue);
    });
  });

  group('BattleRejectSignView', () {
    testWidgets('a rejected rep: the pictogram over its short label on red', (
      tester,
    ) async {
      await _pumpSign(tester, _sign(RejectReason.kneesDown));
      expect(find.text('무릎 떼기'), findsOneWidget);
      expect(
        tester.widget<BattleBand>(find.byType(BattleBand)).color,
        AppColors.danger,
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(BattleRejectSignView),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as BattleRejectIconPainter;
      expect(painter.icon, RejectReason.kneesDown.signIcon);
    });

    testWidgets('an average rep: amber, with the points it earned', (
      tester,
    ) async {
      await _pumpSign(
        tester,
        _sign(RejectReason.insufficientDepth, average: true, points: 10),
      );
      expect(find.text('더 깊게 +10'), findsOneWidget);
      expect(
        tester.widget<BattleBand>(find.byType(BattleBand)).color,
        AppColors.warning,
      );
    });

    testWidgets('sits where the design puts it: a 128 tile from y 340, in '
        'the middle, the label 6 below', (tester) async {
      await _pumpSign(tester, _sign(RejectReason.kneesDown));
      final tile = tester.getRect(
        find
            .ancestor(
              of: find.byType(CustomPaint),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(tile, const Rect.fromLTWH(116, 340, 128, 128));
      final label = tester.getRect(find.byType(BattleBand));
      expect(label.top, 340 + 128 + 6);
      expect(label.center.dx, 180);
    });

    testWidgets('the tile is white with a thick ink edge and round corners', (
      tester,
    ) async {
      await _pumpSign(tester, _sign(RejectReason.kneesDown));
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(CustomPaint),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, AppColors.card);
      expect(decoration.border, Border.all(color: AppColors.ink, width: 4));
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(26)),
      );
      expect(
        tester.getSize(find.byType(CustomPaint).last),
        const Size.square(112),
      );
    });

    testWidgets('a reason with no picture shows only its label', (
      tester,
    ) async {
      await _pumpSign(tester, _sign(RejectReason.tooFast));
      expect(find.text('천천히'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BattleRejectSignView),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('a long label is not squeezed into the sign\'s box', (
      tester,
    ) async {
      await _pumpSign(
        tester,
        _sign(RejectReason.standUpFully, average: true, points: 10),
      );
      expect(tester.takeException(), isNull);
      final label = tester.getRect(find.byType(BattleBand));
      expect(label.width, greaterThan(BattleRejectSignView.size.width));
      expect(label.center.dx, closeTo(180, 0.01));
    });

    testWidgets('grows around the design\'s pivot, (88, 86) of its box', (
      tester,
    ) async {
      await _pumpSign(tester, _sign(RejectReason.kneesDown, scale: 0.6));
      // Every point moves 0.6 of its way from the pivot.
      const whole = Rect.fromLTWH(116, 340, 128, 128);
      final tile = _tile(tester);
      expect(
        tile.left,
        closeTo(_pivot.dx + 0.6 * (whole.left - _pivot.dx), 0.01),
      );
      expect(
        tile.top,
        closeTo(_pivot.dy + 0.6 * (whole.top - _pivot.dy), 0.01),
      );
      expect(tile.width, closeTo(0.6 * 128, 0.01));
      expect(tile.height, closeTo(0.6 * 128, 0.01));
    });

    testWidgets('wobbles by turning around the same pivot, clockwise for a '
        'positive angle', (tester) async {
      await _pumpSign(tester, _sign(RejectReason.kneesDown, rotation: 90));
      // The tile's middle is 22 above the pivot; a quarter turn clockwise
      // puts it 22 to the right of it.
      final center = _tile(tester).center;
      expect(center.dx, closeTo(_pivot.dx + 22, 0.01));
      expect(center.dy, closeTo(_pivot.dy, 0.01));

      await _pumpSign(tester, _sign(RejectReason.kneesDown, rotation: 3));
      expect(_tile(tester).center.dx, greaterThan(_pivot.dx));
    });

    testWidgets('the label has 2 above and below its line and 16 beside it', (
      tester,
    ) async {
      await _pumpSign(tester, _sign(RejectReason.kneesDown));
      final band = tester.getSize(find.byType(BattleBand));
      final label = tester.getSize(find.text('무릎 떼기'));
      // A 40 point line 1.2 high.
      expect(label.height, 48);
      expect(band.height, 48 + 2 * 2);
      expect(band.width, closeTo(label.width + 2 * 16, 0.01));
    });

    testWidgets('fades as the effect says', (tester) async {
      await _pumpSign(
        tester,
        _sign(RejectReason.kneesDown, scale: 0.6, rotation: 3, opacity: 0.5),
      );
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byType(BattleRejectSignView),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0.5,
      );
    });

    testWidgets('carries its sentence but does not say it by itself: the '
        'stage announces it once', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpSign(tester, _sign(RejectReason.kneesDown));
      expect(
        tester.getSemantics(find.bySemanticsLabel('무릎을 바닥에서 떼요')),
        matchesSemantics(label: '무릎을 바닥에서 떼요'),
      );
      handle.dispose();
    });

    test('rises 50 above the line between the stage and the camera', () {
      expect(BattleRejectSignView.riseAboveLine, 390 - _signAt.dy);
      expect(BattleRejectSignView.size, const Size(176, 200));
      // Centered across the stage's 360.
      expect(_signAt.dx, (360 - BattleRejectSignView.size.width) / 2);
    });

    testWidgets('a screen reader hears the whole sentence of the reason', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpSign(tester, _sign(RejectReason.kneesDown));
      expect(find.bySemanticsLabel('무릎을 바닥에서 떼요'), findsOneWidget);
      await _pumpSign(
        tester,
        _sign(RejectReason.insufficientDepth, average: true),
      );
      expect(find.bySemanticsLabel('가슴을 더 내려요 · +5점'), findsOneWidget);
      handle.dispose();
    });
  });
}
