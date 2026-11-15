import 'package:flutter/widgets.dart';

import '../models/setup_squat_silhouette_alignment.dart';
import '../theme/app_theme.dart';

class StandingSilhouetteGuide extends StatelessWidget {
  const StandingSilhouetteGuide({super.key, required this.ready});
  final bool ready;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    image: true,
    label: ready ? '스쿼트 준비 자세 확인됨' : '스쿼트 준비 자세 안내: 정면을 보고 전신을 실루엣에 맞추세요',
    child: IgnorePointer(child: CustomPaint(painter: _StandingPainter(ready))),
  );
}

/// Front-facing standing figure, visually matched to the alignment regions.
class _StandingPainter extends CustomPainter {
  _StandingPainter(this.ready);
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = standingGuideRect(size);
    if (rect.isEmpty) return;
    Offset p(double x, double y) =>
        Offset(rect.left + x * rect.width, rect.top + y * rect.height);
    void curve(Path path, Offset a, Offset b, Offset c) =>
        path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    final path = Path()..moveTo(p(.50, .025).dx, p(.50, .025).dy);
    curve(path, p(.575, .025), p(.625, .055), p(.625, .095));
    curve(path, p(.625, .14), p(.60, .17), p(.575, .18));
    path.lineTo(p(.58, .205).dx, p(.58, .205).dy);
    curve(path, p(.64, .21), p(.73, .22), p(.75, .25));
    curve(path, p(.77, .285), p(.81, .34), p(.82, .37));
    curve(path, p(.83, .39), p(.81, .405), p(.78, .405));
    curve(path, p(.73, .405), p(.70, .38), p(.67, .36));
    curve(path, p(.66, .40), p(.65, .46), p(.655, .51));
    curve(path, p(.66, .60), p(.69, .78), p(.695, .875));
    curve(path, p(.70, .90), p(.75, .905), p(.75, .925));
    curve(path, p(.75, .95), p(.64, .955), p(.61, .94));
    curve(path, p(.59, .92), p(.57, .72), p(.54, .62));
    curve(path, p(.53, .59), p(.51, .58), p(.50, .58));
    curve(path, p(.49, .58), p(.47, .59), p(.46, .62));
    curve(path, p(.43, .72), p(.41, .92), p(.39, .94));
    curve(path, p(.36, .955), p(.25, .95), p(.25, .925));
    curve(path, p(.25, .905), p(.30, .90), p(.305, .875));
    curve(path, p(.31, .78), p(.34, .60), p(.345, .51));
    curve(path, p(.35, .46), p(.34, .40), p(.33, .36));
    curve(path, p(.30, .38), p(.27, .405), p(.22, .405));
    curve(path, p(.19, .405), p(.17, .39), p(.18, .37));
    curve(path, p(.19, .34), p(.23, .285), p(.25, .25));
    curve(path, p(.27, .22), p(.36, .21), p(.42, .205));
    path.lineTo(p(.425, .18).dx, p(.425, .18).dy);
    curve(path, p(.40, .17), p(.375, .14), p(.375, .095));
    curve(path, p(.375, .055), p(.425, .025), p(.50, .025));
    path.close();

    // Two bent forearms meet in front of the chest. The inner lines make
    // the overlapping arms and clasped hands readable on the camera image.
    final arms = Path()..moveTo(p(.205, .385).dx, p(.205, .385).dy);
    curve(arms, p(.27, .375), p(.37, .335), p(.44, .30));
    arms.moveTo(p(.795, .385).dx, p(.795, .385).dy);
    curve(arms, p(.73, .375), p(.63, .335), p(.56, .30));
    final hands = Path()..moveTo(p(.44, .30).dx, p(.44, .30).dy);
    curve(hands, p(.435, .286), p(.45, .277), p(.465, .278));
    curve(hands, p(.48, .275), p(.50, .28), p(.51, .282));
    curve(hands, p(.53, .277), p(.55, .283), p(.56, .30));
    curve(hands, p(.565, .313), p(.55, .325), p(.53, .325));
    curve(hands, p(.51, .33), p(.48, .326), p(.465, .322));
    curve(hands, p(.45, .32), p(.44, .31), p(.44, .30));
    hands.close();
    final clasp = Path()..moveTo(p(.465, .288).dx, p(.465, .288).dy);
    curve(clasp, p(.48, .29), p(.49, .298), p(.50, .304));
    clasp.moveTo(p(.485, .284).dx, p(.485, .284).dy);
    curve(clasp, p(.50, .287), p(.51, .294), p(.52, .30));
    clasp.moveTo(p(.505, .285).dx, p(.505, .285).dy);
    curve(clasp, p(.52, .29), p(.53, .296), p(.535, .301));

    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(path, Offset.zero);
    canvas.drawPath(scrim, Paint()..color = AppColors.setupGuideScrim);
    final dark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.setupGuideScrim.withAlpha(60);
    final light = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = (ready ? AppColors.squatGuideReady : AppColors.onInk).withAlpha(
        220,
      );
    for (final outline in [path, arms, hands, clasp]) {
      canvas.drawPath(outline, dark);
      canvas.drawPath(outline, light);
    }
  }

  @override
  bool shouldRepaint(_StandingPainter oldDelegate) =>
      oldDelegate.ready != ready;
}
