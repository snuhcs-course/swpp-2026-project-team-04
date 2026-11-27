import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/tutorial_page.dart';
import '../theme/app_theme.dart';
import 'battle_banner.dart';
import 'battle_fx_motion.dart';
import 'help_rules.dart';
import 'tutorial_figure_painters.dart';
import 'tutorial_game_shot.dart';
import 'tutorial_person.dart';
import 'tutorial_setup_scenes.dart';

/// The tutorial pictures from page 3 on (A12 design `TutDraft`, 316 x 248):
/// way a, the game screen on a phone beside what to look at on it, made
/// large; way b, the person in front of the phone on the wall with the game
/// screen in a bubble over the phone.
abstract final class TutorialDraft {
  static const size = Size(316, 248);

  /// Way a for the battle, combo, fever and KO pages; way b for the grades.
  static bool isWayA(TutorialStep step) => switch (step) {
    TutorialStep.battle ||
    TutorialStep.combo ||
    TutorialStep.fever ||
    TutorialStep.ko => true,
    _ => false,
  };
}

/// A game screen of [scene] shrunk into a box: [scale] times the screen's
/// 360 x 780, moved up by [rise] screen points (the part a bubble shows).
class _ShrunkShot extends StatelessWidget {
  const _ShrunkShot({required this.scene, required this.scale, this.rise = 0});

  final TutorialGameScene scene;
  final double scale;
  final double rise;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: 0,
      minHeight: 0,
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: Transform(
        transform: Matrix4.diagonal3Values(
          scale,
          scale,
          1,
        ).multiplied(Matrix4.translationValues(0, -rise, 0)),
        child: TutorialGameShot(scene: scene),
      ),
    );
  }
}

/// Way a (`TutDraft` a): the whole game screen at that moment on a phone at
/// the left, and at the right the marks to look at, made large: the band
/// and the health bar (battle), "2 HIT" with the points (combo), the clock
/// with FEVER (fever), K.O. with the lead (KO).
class TutorialPhoneZoom extends StatelessWidget {
  const TutorialPhoneZoom({
    super.key,
    required this.exercise,
    required this.step,
  });

  final ExerciseType exercise;
  final TutorialStep step;

  /// The phone: its place, size, edge and corners, and how much of the
  /// game screen fits in it.
  static const _phone = Rect.fromLTWH(16, 7, 108, 234);
  static const _phoneEdge = 3.0;
  static const _phoneCorner = 16.0;
  static const _shotScale = 0.2833;

  /// The marks' column, between the phone and the picture's edge.
  static const _marksLeft = 136.0;
  static const _marksRight = 8.0;
  static const _gap = 10.0;
  static const _koGap = 12.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: TutorialDraft.size,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: TutorialGridPainter(background: AppColors.cardHigh),
            ),
          ),
          Positioned.fromRect(
            rect: _phone,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(_phoneCorner),
                ),
                boxShadow: [TutorialShadow.drop],
              ),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.all(Radius.circular(_phoneCorner)),
                ),
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: AppColors.ink, width: _phoneEdge),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_phoneCorner),
                  ),
                ),
                // The screen starts inside the edge, as the design's box.
                padding: const EdgeInsets.all(_phoneEdge),
                child: _ShrunkShot(
                  scene: TutorialGameScene.of(exercise, step),
                  scale: _shotScale,
                ),
              ),
            ),
          ),
          Positioned(
            left: _marksLeft,
            right: _marksRight,
            top: 0,
            bottom: 0,
            // Shrunk to fit should wider letters not.
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: _marks(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _marks(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rules = battleRules;
    Widget band(String words, double size, Color color, double turn) =>
        Transform.rotate(
          angle: turn * math.pi / 180,
          child: BattleBand.number(
            text: words,
            size: size,
            color: color,
            theme: text,
          ),
        );
    return switch (step) {
      TutorialStep.combo => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          band('2 HIT', _comboSize, BattleFxTone.plain.color, -6),
          const SizedBox(height: _gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TutorialChip('+${rules.goodPoints}'),
              const SizedBox(width: _chipGap),
              TutorialChip('콤보 +${rules.comboBonus}', color: AppColors.warning),
            ],
          ),
        ],
      ),
      TutorialStep.fever => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '0:${rules.feverLength.inSeconds.toString().padLeft(2, '0')}',
            style: text.archiveTotal.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: _gap),
          band(
            BattleFx.feverText(rules.feverMultiplier),
            _feverSize,
            BattleFxTone.fever.color,
            -4,
          ),
          const SizedBox(height: _gap),
          TutorialChip(
            'EXCELLENT +${rules.excellentPoints * rules.feverMultiplier}',
          ),
        ],
      ),
      TutorialStep.ko => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          band('K.O.', _koSize, BattleFxTone.me.color, -4),
          const SizedBox(height: _koGap),
          TutorialChip('${rules.koLead}점 차'),
        ],
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          band('GOOD', _goodSize, BattleFxTone.me.color, -4),
          const SizedBox(height: _koGap),
          const _BarToward(),
          const SizedBox(height: _koGap),
          Text(
            '체력 바가 상대 쪽으로',
            style: text.cameraNotice.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    };
  }

  /// The large marks' sizes, as designed.
  static const _comboSize = 34.0;
  static const _feverSize = 30.0;
  static const _koSize = 54.0;
  static const _goodSize = 30.0;
  static const _chipGap = 6.0;
}

/// The soft drop shadow under the pictures' phones and screenshots
/// (0 4 0, ink at 0.18).
abstract final class TutorialShadow {
  static final drop = BoxShadow(
    color: AppColors.ink.withValues(alpha: 0.18),
    offset: const Offset(0, 4),
  );
}

/// An ink pill of Oxanium words, e.g. "+10" or "100점 차"; [color] fills it
/// instead (ink words on it).
class TutorialChip extends StatelessWidget {
  const TutorialChip(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  static const _height = 28.0;
  static const _side = 11.0;
  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppColors.ink;
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: _side),
      decoration: ShapeDecoration(
        color: fill,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.ink, width: _edge),
        ),
      ),
      // As wide as its words.
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          style: Theme.of(context).textTheme.archiveScore
              .copyWith(color: color == null ? AppColors.onInk : AppColors.ink),
        ),
      ),
    );
  }
}

/// The health bar pushed toward the opponent: lime most of the way, pink
/// for the rest, an arrow along it (`TutDraft` a, battle).
class _BarToward extends StatelessWidget {
  const _BarToward();

  static const size = Size(160, 22);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: size, painter: const _BarTowardPainter());
  }
}

class _BarTowardPainter extends CustomPainter {
  const _BarTowardPainter();

  static const _edge = 3.0;
  static const _corner = 7.0;

  /// The lime's width inside the edge, and its own ink edge after it.
  static const _lime = 104.0;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_corner),
    );
    // Inside the ink edge, as the design's box: the lime from the edge,
    // its own edge after it, and the arrow along the middle.
    const inner = Offset(_edge, _edge);
    canvas
      ..save()
      ..clipRRect(box)
      ..drawRect(Offset.zero & size, Paint()..color = AppColors.opponent)
      ..drawRect(
        Rect.fromLTWH(_edge, 0, _lime, size.height),
        Paint()..color = AppColors.accent,
      )
      ..drawLine(
        const Offset(_edge + _lime + _edge / 2, 0),
        Offset(_edge + _lime + _edge / 2, size.height),
        Paint()
          ..color = AppColors.ink
          ..strokeWidth = _edge,
      )
      ..restore()
      ..drawRRect(
        box.deflate(_edge / 2),
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _edge,
      );
    final arrow = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawLine(
        inner + const Offset(60, 8),
        inner + const Offset(92, 8),
        arrow,
      )
      ..drawPath(
        Path()
          ..moveTo(inner.dx + 86, inner.dy + 3)
          ..lineTo(inner.dx + 92, inner.dy + 8)
          ..lineTo(inner.dx + 86, inner.dy + 13),
        arrow,
      );
  }

  @override
  bool shouldRepaint(_BarTowardPainter oldDelegate) => false;
}

/// Way b (`TutDraft` b): the person doing the exercise at the grade's depth
/// in front of the phone leaning on the wall at the right, and over the
/// phone a bubble with the game screen of that moment.
class TutorialPersonBubble extends StatelessWidget {
  const TutorialPersonBubble({
    super.key,
    required this.exercise,
    required this.step,
  });

  final ExerciseType exercise;
  final TutorialStep step;

  /// The person's pose and how far down for each grade (the design's `k`).
  static (TutorialSidePose, double) poseOf(
    ExerciseType exercise,
    TutorialStep step,
  ) {
    final squat = exercise == ExerciseType.squat;
    return switch (step) {
      TutorialStep.excellent => (
        squat ? TutorialSidePose.squat : TutorialSidePose.push,
        squat ? 1.12 : 0.95,
      ),
      TutorialStep.average => (TutorialSidePose.push, 0.3),
      TutorialStep.fail =>
        squat ? (TutorialSidePose.squat, 0.5) : (TutorialSidePose.kneel, 0.9),
      _ => (
        squat ? TutorialSidePose.squat : TutorialSidePose.push,
        squat ? 1.0 : 0.72,
      ),
    };
  }

  /// How far down the game screen the bubble looks: lower for a fail, to
  /// show the reject sign over the camera.
  static double windowOf(TutorialStep step) =>
      step == TutorialStep.fail ? 236 : 140;

  /// The person: its middle at [_centerX], the floor at [_floorY], sized by
  /// [_pushScale] or [_squatScale], turned to face the phone, the near
  /// arm's white edge [_armEdge].
  static const _centerX = 104.0;
  static const _floorY = 217.0;
  static const _pushScale = 1.5;
  static const _squatScale = 1.45;
  static const _armEdge = 2.6;

  /// The bubble: its place and size, edge and corners, and how much of the
  /// game screen fits in it.
  static const _bubble = Rect.fromLTWH(146, 8, 157, 148);
  static const _bubbleEdge = 2.5;
  static const _bubbleCorner = 16.0;
  static const _shotScale = 0.4222;

  @override
  Widget build(BuildContext context) {
    final squat = exercise == ExerciseType.squat;
    final (pose, k) = poseOf(exercise, step);
    final scale = squat ? _squatScale : _pushScale;
    final joints = TutorialSide.place(
      TutorialSide.joints(pose, k),
      scale: scale,
      centerX: _centerX,
      floorY: _floorY,
    );
    return SizedBox.fromSize(
      size: TutorialDraft.size,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: TutorialGridPainter(background: AppColors.card),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _PhoneRoomPainter(squat: squat)),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: TutorialSidePainter(
                shapes: TutorialSide.shapes(joints, scale),
                armEdge: _armEdge,
                mirrored: true,
                mirrorAxis: _centerX,
              ),
            ),
          ),
          Positioned.fromRect(
            rect: _bubble,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.all(Radius.circular(_bubbleCorner)),
              ),
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: AppColors.ink, width: _bubbleEdge),
                borderRadius: const BorderRadius.all(
                  Radius.circular(_bubbleCorner),
                ),
              ),
              padding: const EdgeInsets.all(_bubbleEdge),
              child: _ShrunkShot(
                scene: TutorialGameScene.of(exercise, step),
                scale: _shotScale,
                rise: windowOf(step),
              ),
            ),
          ),
          const Positioned.fill(
            child: CustomPaint(painter: _BubbleTailPainter()),
          ),
        ],
      ),
    );
  }
}

/// Way b's room: the lime mat, the floor, the wall at the right with its
/// stripes, and the phone leaning on it.
class _PhoneRoomPainter extends CustomPainter {
  const _PhoneRoomPainter({required this.squat});

  final bool squat;

  @override
  void paint(Canvas canvas, Size size) {
    TutorialRoom.paintMat(
      canvas,
      left: squat ? 62 : 34,
      width: squat ? 86 : 140,
      top: 211,
      height: 11,
    );
    TutorialRoom.paintFloor(
      canvas,
      Rect.fromLTRB(12, 217, size.width - 22, 220),
    );
    TutorialRoom.paintWall(
      canvas,
      Rect.fromLTWH(size.width - 22, 0, 22, 217),
      edgeOnLeft: true,
    );
    TutorialRoom.paintPhone(canvas, const Offset(270, 217), 25, toRight: false);
  }

  @override
  bool shouldRepaint(_PhoneRoomPainter oldDelegate) =>
      oldDelegate.squat != squat;
}

/// The bubble's tail down to the phone, its fill hiding the bubble's edge
/// where they meet.
class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final tail = Path()
      ..moveTo(255, 153)
      ..lineTo(281, 166)
      ..lineTo(273, 153);
    canvas
      ..drawPath(tail, Paint()..color = AppColors.background)
      ..drawPath(
        tail,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawRect(
        const Rect.fromLTWH(257, 151, 15, 6),
        Paint()..color = AppColors.background,
      );
  }

  /// Only a drawing over the picture: what lies under it is what a tap or a
  /// finder reaches.
  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) => false;
}

/// The words a screen reader hears for way a and way b (the design's
/// `aria-label`s).
abstract final class TutorialDraftLabel {
  static const wayA = '왼쪽은 그 순간의 게임 화면 전체, 오른쪽은 그 화면에서 눈여겨볼 표시를 크게 보여 줌';

  static String wayB(ExerciseType exercise) =>
      '사람이 벽에 기댄 폰 앞에서 ${HelpRules.exerciseName(exercise)}를 하고, '
      '폰 위 말풍선에 그때의 게임 장면';
}
