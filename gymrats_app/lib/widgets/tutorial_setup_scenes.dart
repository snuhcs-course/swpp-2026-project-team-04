import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'help_rules.dart';
import 'pose_silhouette_guide.dart';
import 'pose_silhouette_squat.dart';
import 'tutorial_figure_painters.dart';
import 'tutorial_person.dart';

/// Page 1's picture (A12 design `TutX` p1, s1): a phone leaning on the wall
/// at the left, its view reaching the person doing the exercise over and
/// over on a lime mat, and the battle's "1:1 · 30초" tag. On the picture's
/// 316 x 248 board.
class TutorialWallScene extends StatelessWidget {
  const TutorialWallScene({super.key, required this.squat});

  final bool squat;

  static const size = Size(316, 248);

  /// Where page 1's person box (220 x 200) is, sized by [_personScale].
  static const _personTop = 39.0;
  static const _pushLeft = 86.0;
  static const _squatLeft = 104.0;
  static const _personScale = 0.89;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: TutorialGridPainter(background: AppColors.card),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _WallRoomPainter(squat))),
          Positioned(
            left: 0,
            top: 0,
            child: Transform(
              transform:
                  Matrix4.translationValues(
                    squat ? _squatLeft : _pushLeft,
                    _personTop,
                    0,
                  ).multiplied(
                    Matrix4.diagonal3Values(_personScale, _personScale, 1),
                  ),
              child: TutorialSidePerson(squat: squat),
            ),
          ),
          Positioned(
            right: TutorialTag.inset,
            top: TutorialTag.inset,
            child: TutorialTag('1:1 · ${HelpRules.totalSeconds}초'),
          ),
        ],
      ),
    );
  }
}

/// The ink tag at a picture's corner, e.g. "1:1 · 30초": Do Hyeon 19 white
/// on ink.
class TutorialTag extends StatelessWidget {
  const TutorialTag(this.text, {super.key});

  final String text;

  /// Its distance from the picture's edges.
  static const inset = 14.0;
  static const _side = 13.0;
  static const _above = 4.0;
  static const _below = 5.0;
  static const _padding = EdgeInsets.fromLTRB(_side, _above, _side, _below);
  static const _corner = 16.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(_corner)),
      ),
      child: Padding(
        padding: _padding,
        child: Text(
          text,
          style: Theme.of(context).textTheme.goalMissionSticker
              .copyWith(color: AppColors.onInk),
        ),
      ),
    );
  }
}

/// Page 1's room: the lime mat, the floor, the wall at the left with its
/// stripes, the phone's view and the phone leaning on the wall.
class _WallRoomPainter extends CustomPainter {
  const _WallRoomPainter(this.squat);

  final bool squat;

  @override
  void paint(Canvas canvas, Size size) {
    TutorialRoom.paintMat(
      canvas,
      left: squat ? 182 : 104,
      width: squat ? 86 : 156,
      top: 199,
      height: 12,
    );
    TutorialRoom.paintFloor(
      canvas,
      Rect.fromLTRB(26, 205, size.width - 14, 208),
    );
    TutorialRoom.paintWall(
      canvas,
      const Rect.fromLTWH(0, 0, 26, 205),
      edgeOnLeft: false,
    );
    // The camera's view, two dashed lines from the lens.
    final view = squat
        ? const [Offset(196, 60), Offset(206, 204)]
        : const [Offset(118, 128), Offset(114, 200)];
    for (final end in view) {
      TutorialRoom.paintDashes(canvas, const Offset(42, 158), end);
    }
    TutorialRoom.paintPhone(canvas, const Offset(48, 205), -25, toRight: true);
  }

  @override
  bool shouldRepaint(_WallRoomPainter oldDelegate) =>
      oldDelegate.squat != squat;
}

/// The pieces of the pictures' rooms (A12 design `TutX` p1, `TutDraft` b).
abstract final class TutorialRoom {
  static const _floorCorner = 2.0;
  static const _phoneCorner = 3.0;

  /// The lime mat under the person: slanted like the bands (skew -12°).
  static void paintMat(
    Canvas canvas, {
    required double left,
    required double width,
    required double top,
    required double height,
  }) {
    final lean = height * math.tan(12 * math.pi / 180) / 2;
    canvas.drawPath(
      Path()..addPolygon([
        Offset(left + lean, top),
        Offset(left + width + lean, top),
        Offset(left + width - lean, top + height),
        Offset(left - lean, top + height),
      ], true),
      Paint()..color = AppColors.accent,
    );
  }

  /// The floor's ink line, rounded at its ends.
  static void paintFloor(Canvas canvas, Rect line) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(line, const Radius.circular(_floorCorner)),
      Paint()..color = AppColors.ink,
    );
  }

  /// A wall: light, striped across (CSS `repeating-linear-gradient`, a 2
  /// wide line every 9), with an ink edge 3 wide on its room side.
  static void paintWall(Canvas canvas, Rect wall, {required bool edgeOnLeft}) {
    canvas
      ..save()
      ..clipRect(wall)
      ..drawRect(wall, Paint()..color = AppColors.facetLight);
    final stripe = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2;
    // Rising to the right ("/") on the left wall (CSS 135°), rising to the
    // left ("\") on the right wall (45°); one every 9 across them.
    const step = 9 * math.sqrt2;
    final reach = wall.width + wall.height;
    for (var c = -reach; c < reach * 2; c += step) {
      if (edgeOnLeft) {
        canvas.drawLine(
          Offset(wall.left + c, wall.top),
          Offset(wall.left + c + reach, wall.top + reach),
          stripe,
        );
      } else {
        canvas.drawLine(
          Offset(wall.left + c, wall.top),
          Offset(wall.left + c - reach, wall.top + reach),
          stripe,
        );
      }
    }
    canvas.restore();
    final edgeX = edgeOnLeft ? wall.left + 1.5 : wall.right - 1.5;
    canvas.drawLine(
      Offset(edgeX, wall.top),
      Offset(edgeX, wall.bottom),
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 3,
    );
  }

  /// A dashed line, 4 on and 5 off, of the camera's view.
  static void paintDashes(Canvas canvas, Offset from, Offset to) {
    final paint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.45)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final length = (to - from).distance;
    final along = (to - from) / length;
    for (var d = 0.0; d < length; d += 9) {
      canvas.drawLine(
        from + along * d,
        from + along * math.min(d + 4, length),
        paint,
      );
    }
  }

  /// The phone leaning on a wall: its foot at [foot], turned [degrees]; its
  /// screen faces the room ([toRight] when the wall is at the left).
  static void paintPhone(
    Canvas canvas,
    Offset foot,
    double degrees, {
    required bool toRight,
  }) {
    canvas
      ..save()
      ..translate(foot.dx, foot.dy)
      ..rotate(degrees * math.pi / 180);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(toRight ? 0 : -10, -52, 10, 52),
      const Radius.circular(_phoneCorner),
    );
    canvas
      ..drawRRect(body, Paint()..color = AppColors.card)
      ..drawRRect(
        body,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawCircle(
        Offset(toRight ? 13.5 : -13.5, -45),
        2.4,
        Paint()..color = AppColors.ink,
      )
      ..restore();
  }
}

/// A picture's grid (24 apart, faint gray lines) over [background].
class TutorialGridPainter extends CustomPainter {
  const TutorialGridPainter({required this.background, this.alpha = 0.08});

  final Color background;

  /// How strongly the lines show: 0.08 on white, 0.07 on the screen's gray.
  final double alpha;

  static const _step = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final line = Paint()
      ..color = AppColors.line.withValues(alpha: alpha)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += _step) {
      canvas.drawLine(Offset(x + 0.5, 0), Offset(x + 0.5, size.height), line);
    }
    for (var y = 0.0; y <= size.height; y += _step) {
      canvas.drawLine(Offset(0, y + 0.5), Offset(size.width, y + 0.5), line);
    }
  }

  @override
  bool shouldRepaint(TutorialGridPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.alpha != alpha;
}

/// Page 2's picture (A12 design `TutX` p2, s2): the setup's camera twice,
/// the body outside the guide (white line) and inside it (green line), an
/// arrow between, and a line under each. On the picture's 316 x 248 board.
class TutorialSetupCameras extends StatelessWidget {
  const TutorialSetupCameras({super.key, required this.squat});

  final bool squat;

  static const size = Size(316, 248);
  static const _inset = 14.0;
  static const _rightLeft = 170.0;
  static const _arrowAt = Offset(139, 84);
  static const _captionTop = 200.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.card)),
          Positioned(
            left: _inset,
            top: _inset,
            child: TutorialSetupCamera(squat: squat, ready: false),
          ),
          Positioned(
            left: _rightLeft,
            top: _inset,
            child: TutorialSetupCamera(squat: squat, ready: true),
          ),
          Positioned(
            left: _arrowAt.dx,
            top: _arrowAt.dy,
            child: const TutorialArrowDisc(),
          ),
          for (final (left, words, style) in [
            (
              _inset,
              '선 밖이면 대기',
              text.cameraHint.copyWith(color: AppColors.textSecondary),
            ),
            (_rightLeft, '선 안 = 준비 완료', text.cameraButton),
          ])
            Positioned(
              left: left,
              top: _captionTop,
              width: TutorialSetupCamera.width,
              child: Text(words, textAlign: TextAlign.center, style: style),
            ),
        ],
      ),
    );
  }
}

/// The setup's camera as a small framed picture (A12 design `TutFigCam`,
/// 132 wide): the person from the front, and the app's own setup guide over
/// them ([PoseSilhouetteGuide] for a push-up, [StandingSilhouetteGuide]
/// for a squat). Not [ready]: the person stands off to the side, smaller,
/// and the guide's line is white; [ready]: inside it, the line green.
class TutorialSetupCamera extends StatelessWidget {
  const TutorialSetupCamera({
    super.key,
    required this.squat,
    required this.ready,
  });

  final bool squat;
  final bool ready;

  static const width = 132.0;
  static const _edge = 2.0;
  static const _corner = 14.0;

  /// The camera's 290 x 387 box sized into the frame.
  static double get _scale => (width - 2 * _edge) / TutorialFront.box.width;
  static double get height =>
      ((width - 2 * _edge) *
                  TutorialFront.box.height /
                  TutorialFront.box.width +
              2 * _edge)
          .roundToDouble();

  @override
  Widget build(BuildContext context) {
    final figure = squat
        ? TutorialFront.setupStand()
        : TutorialFront.setupPush();
    // Off to the side: where the design moves the person outside the line.
    final aside = squat
        ? Matrix4.translationValues(
            96,
            54,
            0,
          ).multiplied(Matrix4.diagonal3Values(0.8, 0.8, 1))
        : Matrix4.translationValues(
            78,
            70,
            0,
          ).multiplied(Matrix4.diagonal3Values(0.74, 0.74, 1));
    // The ink edge over the picture, so the picture's corners do not hide
    // its rounding.
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.pictogramFloor,
        borderRadius: BorderRadius.all(Radius.circular(_corner)),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: AppColors.ink, width: _edge),
        borderRadius: const BorderRadius.all(Radius.circular(_corner)),
      ),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.scale(
          scale: _scale,
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: TutorialFront.box,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: TutorialCameraBackdropPainter()),
                ),
                Positioned.fill(
                  child: Transform(
                    transform: ready ? Matrix4.identity() : aside,
                    child: CustomPaint(painter: TutorialFrontPainter(figure)),
                  ),
                ),
                Positioned.fill(
                  child: squat
                      ? StandingSilhouetteGuide(ready: ready)
                      : PoseSilhouetteGuide(ready: ready),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The lime disc with an arrow between the two cameras.
class TutorialArrowDisc extends StatelessWidget {
  const TutorialArrowDisc({super.key});

  static const size = 38.0;
  static const _edge = 2.5;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: const CustomPaint(painter: TutorialArrowPainter()),
    );
  }
}

/// An arrow to the right in the middle of its box (the design's 20 x 20
/// icon: a shaft and a head, ink, 3 wide, rounded).
class TutorialArrowPainter extends CustomPainter {
  const TutorialArrowPainter({this.width = 3});

  final double width;

  static const _icon = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = _icon / 24;
    final origin = Offset((size.width - _icon) / 2, (size.height - _icon) / 2);
    Offset at(double x, double y) => origin + Offset(x * unit, y * unit);
    final paint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawLine(at(5, 12), at(19, 12), paint)
      ..drawPath(
        Path()
          ..moveTo(at(13, 6).dx, at(13, 6).dy)
          ..lineTo(at(19, 12).dx, at(19, 12).dy)
          ..lineTo(at(13, 18).dx, at(13, 18).dy),
        paint,
      );
  }

  @override
  bool shouldRepaint(TutorialArrowPainter oldDelegate) =>
      oldDelegate.width != width;
}
