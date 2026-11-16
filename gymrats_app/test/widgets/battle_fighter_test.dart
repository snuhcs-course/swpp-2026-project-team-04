import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_fighter.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

import 'battle_test_support.dart';

/// Room around the fighter's box, so what a pose draws outside it shows.
const _margin = 30.0;

Future<PaintedPicture> _paint(
  WidgetTester tester,
  BattlePose pose, {
  BattleSide side = BattleSide.me,
}) => paintPicture(
  tester,
  Padding(
    padding: const EdgeInsets.all(_margin),
    child: BattleFighter(pose: pose, side: side),
  ),
  size: const Size(140 + 2 * _margin, 160 + 2 * _margin),
);

/// The color at ([x], [y]) of the design's 140 x 160 drawing.
Color _at(PaintedPicture picture, double x, double y) =>
    picture.at(x + _margin, y + _margin);

void main() {
  group('BattleFighter', () {
    testWidgets('is the design\'s 140 x 160 box, standing on (70, 150)', (
      tester,
    ) async {
      await tester.pumpWidget(
        battleTestApp(
          const Center(
            child: BattleFighter(pose: BattlePose.idle, side: BattleSide.me),
          ),
        ),
      );
      expect(tester.getSize(find.byType(BattleFighter)), const Size(140, 160));
      expect(BattleFighter.size, const Size(140, 160));
      expect(BattleFighter.foot, const Offset(70, 150));
    });

    testWidgets('idle: gloves up, both feet down, eyes open on an ink body', (
      tester,
    ) async {
      final picture = await _paint(tester, BattlePose.idle);
      expect(_at(picture, 112, 103), AppColors.accent, reason: 'front glove');
      expect(_at(picture, 86, 127), AppColors.accent, reason: 'back glove');
      expect(_at(picture, 40, 143), AppColors.accent, reason: 'left foot');
      expect(_at(picture, 96, 144), AppColors.accent, reason: 'right foot');
      expect(_at(picture, 77, 95), AppColors.card, reason: 'eye');
      expect(_at(picture, 60, 110), AppColors.ink, reason: 'body');
      expect(_at(picture, 29, 66), AppColors.accent, reason: 'headband end');
    });

    testWidgets('attack: the fist reaches out past the right of the box', (
      tester,
    ) async {
      final picture = await _paint(tester, BattlePose.attack);
      expect(_at(picture, 136, 104), AppColors.accent, reason: 'fist');
      expect(_at(picture, 150, 100), AppColors.accent, reason: 'past the box');
      expect(
        _at(picture, 156.5, 96),
        AppColors.ink,
        reason: 'the fist\'s edge',
      );
      expect(_at(picture, 84, 125), AppColors.accent, reason: 'back glove');
      expect(_at(picture, 28, 143), AppColors.accent, reason: 'back foot');
      expect(_at(picture, 106, 143), AppColors.accent, reason: 'front foot');
    });

    testWidgets('hit: thrown back, one foot off the floor, arms flung', (
      tester,
    ) async {
      final picture = await _paint(tester, BattlePose.hit);
      expect(_at(picture, 8, 112), AppColors.accent, reason: 'low glove');
      expect(_at(picture, 98, 56), AppColors.accent, reason: 'high glove');
      expect(_at(picture, 42, 143), AppColors.accent, reason: 'standing foot');
      expect(_at(picture, 98, 20), isNot(AppColors.accent));
      // The hit marks beside the head are drawn outside the body, in ink.
      expect(_at(picture, 104, 32), AppColors.ink, reason: 'hit mark');
    });

    testWidgets('knocked out: lying down under two dizzy stars', (
      tester,
    ) async {
      final picture = await _paint(tester, BattlePose.knockedOut);
      expect(_at(picture, 76, 84), AppColors.accent, reason: 'glove');
      expect(_at(picture, -2, 142), AppColors.accent, reason: 'far glove');
      expect(_at(picture, 24, 71.5), AppColors.warning, reason: 'big star');
      expect(_at(picture, 50, 58), AppColors.warning, reason: 'small star');
      expect(_at(picture, 90, 120), AppColors.ink, reason: 'body lying');
      expect(_at(picture, 68, 60), AppColors.card, reason: 'nothing upright');
    });

    testWidgets('win: both gloves over the head', (tester) async {
      final picture = await _paint(tester, BattlePose.win);
      expect(_at(picture, 24, 34), AppColors.accent, reason: 'left glove');
      expect(_at(picture, 110, 28), AppColors.accent, reason: 'right glove');
      expect(_at(picture, 68, 125), AppColors.ink, reason: 'body');
      expect(_at(picture, 44, 143), AppColors.accent, reason: 'foot');
    });

    testWidgets('the opponent wears pink where the user wears lime', (
      tester,
    ) async {
      final picture = await _paint(
        tester,
        BattlePose.idle,
        side: BattleSide.opponent,
      );
      expect(_at(picture, 112, 103), AppColors.opponent);
      expect(_at(picture, 40, 143), AppColors.opponent);
      expect(_at(picture, 60, 110), AppColors.ink);
    });

    testWidgets('every pose draws for both sides', (tester) async {
      for (final side in BattleSide.values) {
        for (final pose in BattlePose.values) {
          await tester.pumpWidget(
            battleTestApp(BattleFighter.standIn(pose, side)),
          );
          final fighter = tester.widget<BattleFighter>(
            find.byType(BattleFighter),
          );
          expect(fighter.pose, pose);
          expect(fighter.side, side);
          expect(tester.takeException(), isNull);
        }
      }
    });

    test('repaints only when the pose or the color changes', () {
      const painter = BattleFighterPainter(
        pose: BattlePose.idle,
        color: AppColors.accent,
      );
      expect(
        painter.shouldRepaint(
          const BattleFighterPainter(
            pose: BattlePose.idle,
            color: AppColors.accent,
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          const BattleFighterPainter(
            pose: BattlePose.hit,
            color: AppColors.accent,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const BattleFighterPainter(
            pose: BattlePose.idle,
            color: AppColors.opponent,
          ),
        ),
        isTrue,
      );
    });
  });

  group('the drawing, part by part', () {
    testWidgets('idle: a team-colored headband and outline on the ink body', (
      tester,
    ) async {
      final picture = await _paint(tester, BattlePose.idle);
      expect(_at(picture, 72.5, 73.7), AppColors.accent, reason: 'headband');
      expect(_at(picture, 36.7, 97.7), AppColors.accent, reason: 'outline');
      expect(_at(picture, 32, 97.4), AppColors.ink, reason: 'outer edge');
      expect(_at(picture, 92, 96.5), AppColors.card, reason: 'second eye');
    });

    testWidgets('the eyes show white in every pose', (tester) async {
      final attack = await _paint(tester, BattlePose.attack);
      expect(_at(attack, 87, 98.5), AppColors.card, reason: 'attack');
      final hit = await _paint(tester, BattlePose.hit);
      expect(_at(hit, 64.2, 94), AppColors.card, reason: 'hit');
      final win = await _paint(tester, BattlePose.win);
      expect(_at(win, 69.5, 94), AppColors.card, reason: 'win');
      final out = await _paint(tester, BattlePose.knockedOut);
      expect(_at(out, 26.5, 108.5), AppColors.card, reason: 'knocked out');
    });

    testWidgets('the attack leans forward and the hit leans back', (
      tester,
    ) async {
      // The forehead, 78 above the hips, is carried 20 forward by the 15
      // degree lean and 24 back by the -18 degree one.
      const forward = Offset(88.2, 62.7);
      const back = Offset(43.9, 63.8);
      final attack = await _paint(tester, BattlePose.attack);
      expect(_at(attack, forward.dx, forward.dy), AppColors.ink);
      expect(_at(attack, back.dx, back.dy), isNot(AppColors.ink));
      final hit = await _paint(tester, BattlePose.hit);
      expect(_at(hit, back.dx, back.dy), AppColors.ink);
      expect(_at(hit, forward.dx, forward.dy), isNot(AppColors.ink));
    });

    for (final pose in BattlePose.values) {
      test('${pose.name}: every number of the reviewed drawing is kept', () {
        expectReviewedDrawing(
          'fighter ${pose.name}',
          paintedOps(
            BattleFighterPainter(pose: pose, color: AppColors.accent),
            BattleFighter.size,
          ),
        );
      });
    }

    test('the opponent is the same drawing in pink', () {
      String recolor(String line) => line.replaceAll('#FFC6FF3D', '#FFFF4F81');
      for (final pose in BattlePose.values) {
        expect(
          paintedOps(
            BattleFighterPainter(pose: pose, color: AppColors.opponent),
            BattleFighter.size,
          ),
          paintedOps(
            BattleFighterPainter(pose: pose, color: AppColors.accent),
            BattleFighter.size,
          ).map(recolor),
          reason: pose.name,
        );
      }
    });

    test('a smaller canvas draws the same picture, smaller', () {
      final ops = paintedOps(
        const BattleFighterPainter(
          pose: BattlePose.idle,
          color: AppColors.accent,
        ),
        const Size(70, 80),
      );
      expect(ops[1], 'scale(0.500, 0.500)');
    });
  });
}
