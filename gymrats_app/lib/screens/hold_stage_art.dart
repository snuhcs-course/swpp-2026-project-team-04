import 'package:flutter/material.dart';

import '../models/hold_reading.dart';
import '../models/setup_hint_short.dart';
import '../theme/app_theme.dart';
import '../widgets/battle_art_path.dart';
import '../widgets/battle_camera_area.dart';

/// The hold stage's small drawings, in the design's own coordinates
/// (arcade hold spec 3, "그림"): the stars, the warning marks, the poses'
/// icons, every warning icon of both poses, and the two figures of the
/// camera box. A pose's definition only names which to show.
///
/// They are kept with the hold screen because the step's files are the
/// `hold*` screens (A4 file scope), not `lib/widgets/`.

/// Ink lines with round ends, as the design's icons are drawn.
Paint _ink(double width, {Color color = AppColors.ink}) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// The drawings' corner radii (the design's `rx`), in their own
/// coordinates.
abstract final class _Rx {
  static const strike = 3.0;
  static const shoulders = 23.0;
  static const seatedBody = 26.0;
  static const arm = 15.0;
  static const lock = 2.0;
  static const shackle = 4.0;
}

/// Paints [draw] in a [view] wide square scaled to its size.
abstract class _ViewPainter extends CustomPainter {
  const _ViewPainter(this.view);

  final Size view;

  void draw(Canvas canvas);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / view.width, size.height / view.height);
    draw(canvas);
    canvas.restore();
  }
}

/// A star: the design's five-point star, [fill] inside an ink line.
class HoldStar extends StatelessWidget {
  const HoldStar({
    super.key,
    required this.size,
    required this.lit,
    this.edge = 2,
  });

  final double size;
  final bool lit;

  /// The ink line, in the star's 24 view.
  final double edge;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: HoldStarPainter(lit: lit, edge: edge),
  );
}

class HoldStarPainter extends _ViewPainter {
  const HoldStarPainter({required this.lit, required this.edge})
    : super(const Size.square(24));

  final bool lit;
  final double edge;

  static const _path =
      'M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3 6.1 20.6l1.3-6.6L2.5 '
      '9.4l6.6-.8z';

  @override
  void draw(Canvas canvas) {
    final path = battleArtPath(_path);
    canvas.drawPath(
      path,
      Paint()..color = lit ? AppColors.warning : HoldColors.starOff,
    );
    canvas.drawPath(path, _ink(edge)..strokeCap = StrokeCap.butt);
  }

  @override
  bool shouldRepaint(HoldStarPainter oldDelegate) =>
      oldDelegate.lit != lit || oldDelegate.edge != edge;
}

/// A warning mark: the whistle shape, red once the warning was given.
class HoldStrike extends StatelessWidget {
  const HoldStrike({super.key, required this.size, required this.fill});

  /// 22 x 16 on the briefing, 24 x 18 over the stage and on the result.
  final Size size;
  final Color fill;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: size, painter: HoldStrikePainter(fill));
}

class HoldStrikePainter extends _ViewPainter {
  const HoldStrikePainter(this.fill) : super(const Size(22, 16));

  final Color fill;

  @override
  void draw(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1.5, 4, 12, 8),
      const Radius.circular(_Rx.strike),
    );
    final paint = Paint()..color = fill;
    final line = _ink(2);
    canvas
      ..drawRRect(body, paint)
      ..drawRRect(body, line)
      ..drawCircle(const Offset(15, 9), 5, paint)
      ..drawCircle(const Offset(15, 9), 5, line);
  }

  @override
  bool shouldRepaint(HoldStrikePainter oldDelegate) => oldDelegate.fill != fill;
}

/// The pose's icon beside its name on the briefing.
class HoldPoseIconPainter extends _ViewPainter {
  const HoldPoseIconPainter(this.pose) : super(const Size.square(24));

  final HoldSilhouette pose;

  @override
  void draw(Canvas canvas) {
    final line = _ink(2);
    switch (pose) {
      case HoldSilhouette.plank:
        canvas.drawCircle(const Offset(4.5, 8.5), 2, line);
        canvas.drawPath(
          battleArtPath('M6.8 9.6L21 12M7.5 10v7M21 12l.5 5M2 19.5h20'),
          line,
        );
      case HoldSilhouette.sit:
        canvas.drawCircle(const Offset(8, 4), 2, line);
        canvas.drawPath(battleArtPath('M8 6.5v6h7v7M8 9l4 1.5M4 20h16'), line);
    }
  }

  @override
  bool shouldRepaint(HoldPoseIconPainter oldDelegate) =>
      oldDelegate.pose != pose;
}

/// A warning's icon in the red box of the camera (spec 4), 44 points: the
/// design's knee, sit-lower and knees-apart icons, the setup cue's body for
/// off screen, or nothing.
class HoldWarningIcon extends StatelessWidget {
  const HoldWarningIcon(this.icon, {super.key});

  final HoldIcon icon;

  static const size = 44.0;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: switch (icon) {
      HoldIcon.blank => null,
      HoldIcon.offScreen => const CustomPaint(
        painter: SetupCueIconPainter(SetupCueIcon.person),
      ),
      final drawn => CustomPaint(painter: HoldWarningIconPainter(drawn)),
    },
  );
}

class HoldWarningIconPainter extends _ViewPainter {
  const HoldWarningIconPainter(this.icon)
    : assert(
        icon != HoldIcon.blank && icon != HoldIcon.offScreen,
        'not one of the design icons',
      ),
      super(const Size.square(24));

  final HoldIcon icon;

  @override
  void draw(Canvas canvas) {
    final line = _ink(2.4);
    switch (icon) {
      case HoldIcon.knee:
        canvas.drawPath(battleArtPath('M3 19h18'), line);
        canvas.drawCircle(const Offset(9, 16.5), 2.3, line);
        canvas.drawPath(battleArtPath('M9 14V7M15 9l2-2 2 2M17 7v7'), line);
      case HoldIcon.low:
        canvas.drawPath(
          battleArtPath('M3 19h18M5 5v7h7v7M18 5v8M15.5 10.5L18 13l2.5-2.5'),
          line,
        );
      case HoldIcon.spread:
        canvas.drawPath(
          battleArtPath(
            'M3 19h18M10 5l-1 7 1 7M14 5l1 7-1 7M6 12H2.5M4 10.5L2.5 12 4 '
            '13.5M18 12h3.5M20 10.5l1.5 1.5-1.5 1.5',
          ),
          line,
        );
      case HoldIcon.offScreen || HoldIcon.blank:
        break;
    }
  }

  @override
  bool shouldRepaint(HoldWarningIconPainter oldDelegate) =>
      oldDelegate.icon != icon;
}

/// The camera box's gray figure where the camera picture is not (the
/// design's camera box for `move=plank` and `move=sit`): the design's
/// 360 x 390 box scaled to the width it is given, cut at its height.
class HoldSilhouettePainter extends CustomPainter {
  const HoldSilhouettePainter(this.pose);

  final HoldSilhouette pose;

  static const view = Size(360, 390);

  /// The floor band along the bottom.
  static const _floor = 92.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / view.width;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = HoldColors.cameraBox);
    canvas.drawRect(
      Rect.fromLTRB(0, size.height - _floor * scale, size.width, size.height),
      Paint()..color = HoldColors.cameraFloor,
    );
    canvas.scale(scale);
    final figure = Paint()..color = HoldColors.figure;
    final feet = Paint()..color = HoldColors.figureFeet;
    switch (pose) {
      case HoldSilhouette.plank:
        canvas.drawPath(
          battleArtPath('M140 200 L220 200 L204 268 L156 268 Z'),
          Paint()..color = HoldColors.figureBody,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(102, 176, 156, 46),
            const Radius.circular(_Rx.shoulders),
          ),
          figure,
        );
        _arm(canvas, const Offset(119, 196), 4, const Offset(104, 196), figure);
        _arm(
          canvas,
          const Offset(241, 196),
          -4,
          const Offset(226, 196),
          figure,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(114, 326),
            width: 44,
            height: 18,
          ),
          feet,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(246, 326),
            width: 44,
            height: 18,
          ),
          feet,
        );
        canvas.drawCircle(const Offset(180, 160), 36, figure);
      case HoldSilhouette.sit:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(146, 120, 68, 104),
            const Radius.circular(_Rx.seatedBody),
          ),
          figure,
        );
        canvas.drawCircle(const Offset(180, 92), 30, figure);
        final thigh = Paint()
          ..color = HoldColors.figure
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 34;
        canvas.drawPath(battleArtPath('M160 214 L104 236'), thigh);
        canvas.drawPath(battleArtPath('M200 214 L256 236'), thigh);
        final shin = Paint()
          ..color = HoldColors.figure
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 30;
        canvas.drawPath(battleArtPath('M104 236 L110 320'), shin);
        canvas.drawPath(battleArtPath('M256 236 L250 320'), shin);
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(108, 330),
            width: 48,
            height: 18,
          ),
          feet,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(252, 330),
            width: 48,
            height: 18,
          ),
          feet,
        );
    }
    canvas.restore();
  }

  /// One of the plank's arms: a 30 x 128 bar from [origin], turned
  /// [degrees] about [pivot].
  void _arm(
    Canvas canvas,
    Offset pivot,
    double degrees,
    Offset origin,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(degrees * 3.141592653589793 / 180);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, 30, 128),
        const Radius.circular(_Rx.arm),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(HoldSilhouettePainter oldDelegate) =>
      oldDelegate.pose != pose;
}

/// The briefing's back chevron and the dark buttons' lime arrow.
class HoldArrowPainter extends _ViewPainter {
  const HoldArrowPainter.back() : forward = false, super(const Size.square(24));
  const HoldArrowPainter.forward()
    : forward = true,
      super(const Size.square(24));

  final bool forward;

  @override
  void draw(Canvas canvas) {
    if (forward) {
      canvas.drawPath(
        battleArtPath('M5 12h14M13 6l6 6-6 6'),
        _ink(2.6, color: AppColors.accent),
      );
    } else {
      canvas.drawPath(battleArtPath('M15 6l-6 6 6 6'), _ink(2.4));
    }
  }

  @override
  bool shouldRepaint(HoldArrowPainter oldDelegate) =>
      oldDelegate.forward != forward;
}

/// The next stage card's glove and the lock beside its tag.
class HoldNextIconPainter extends _ViewPainter {
  const HoldNextIconPainter.glove()
    : lock = false,
      super(const Size.square(24));
  const HoldNextIconPainter.lock() : lock = true, super(const Size.square(24));

  final bool lock;

  @override
  void draw(Canvas canvas) {
    if (lock) {
      final line = _ink(2.8, color: AppColors.textSecondary);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 11, 14, 10),
          const Radius.circular(_Rx.lock),
        ),
        line,
      );
      canvas.drawPath(
        Path()
          ..moveTo(8, 11)
          ..lineTo(8, 8)
          ..arcToPoint(
            const Offset(15.5, 6),
            radius: const Radius.circular(_Rx.shackle),
          ),
        line,
      );
      return;
    }
    final line = _ink(2)..strokeCap = StrokeCap.butt;
    final glove = Path()
      ..moveTo(8, 10)
      ..cubicTo(8, 6.4, 10.2, 4, 13.6, 4)
      ..lineTo(14.4, 4)
      ..cubicTo(17.8, 4, 20, 6.4, 20, 10)
      ..lineTo(20, 13.4)
      ..cubicTo(20, 16.2, 18, 18.2, 15.2, 18.2)
      ..lineTo(12.4, 18.2)
      ..cubicTo(9.8, 18.2, 8, 16.4, 8, 13.8)
      ..close();
    final thumb = Path()
      ..moveTo(8, 10.6)
      ..cubicTo(6, 10.2, 4, 11.4, 4, 13.6)
      ..cubicTo(4, 15.8, 5.6, 16.8, 8, 16.6);
    canvas
      ..drawPath(glove, Paint()..color = AppColors.card)
      ..drawPath(glove, line)
      ..drawPath(thumb, Paint()..color = AppColors.card)
      ..drawPath(thumb, line);
    final cuff = const Rect.fromLTWH(10.2, 18.2, 8.2, 3.3);
    canvas
      ..drawRect(cuff, Paint()..color = AppColors.ink)
      ..drawRect(cuff, line);
  }

  @override
  bool shouldRepaint(HoldNextIconPainter oldDelegate) =>
      oldDelegate.lock != lock;
}
