import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../models/reject_reason_korean.dart';
import '../theme/app_theme.dart';
import 'battle_art_path.dart';
import 'battle_banner.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';

/// What a mark of a pictogram is drawn with.
enum _Ink {
  /// The gray person or phone.
  figure,

  /// The ink arrow or target line.
  pointer,

  /// The faint floor.
  floor,
}

/// One mark of a pictogram, in the design's 96 x 96 points.
class _Mark {
  /// A stroked line.
  const _Mark.line(this.data, this.width, {this.ink = _Ink.figure})
    : filled = false,
      dashed = false,
      circle = null,
      box = null;

  /// A dashed target line.
  const _Mark.dashes(this.data, this.width)
    : ink = _Ink.pointer,
      filled = false,
      dashed = true,
      circle = null,
      box = null;

  /// An arrow head: filled, with a rounded edge of [width].
  const _Mark.arrow(this.data, this.width)
    : ink = _Ink.pointer,
      filled = true,
      dashed = false,
      circle = null,
      box = null;

  /// A filled dot: a head, or the phone's camera.
  const _Mark.dot(double x, double y, double radius)
    : circle = (x, y, radius),
      data = '',
      width = 0,
      ink = _Ink.figure,
      filled = true,
      dashed = false,
      box = null;

  /// The phone's outline.
  const _Mark.phone(double x, double y, double w, double h, this.width)
    : box = (x, y, w, h),
      data = '',
      ink = _Ink.figure,
      filled = false,
      dashed = false,
      circle = null;

  final String data;
  final double width;
  final _Ink ink;
  final bool filled;
  final bool dashed;
  final (double, double, double)? circle;
  final (double, double, double, double)? box;
}

const _floor = _Mark.line('M6 84H90', 3, ink: _Ink.floor);

/// The ten pictograms of the design (FxIcon), by number.
const _icons = <List<_Mark>>[
  // 0: go deeper (push-up).
  [
    _floor,
    _Mark.dot(15, 50, 8),
    _Mark.line('M26 58L58 62L88 80', 7),
    _Mark.line('M26 58L37 67L27 82', 7),
    _Mark.line('M44 10V28', 7, ink: _Ink.pointer),
    _Mark.arrow('M33 28L44 44L55 28Z', 3),
  ],
  // 1: lock out the arms.
  [
    _floor,
    _Mark.dot(15, 44, 8),
    _Mark.line('M26 52L58 59L88 80', 7),
    _Mark.line('M26 52L36 66L27 82', 7),
    _Mark.line('M52 28V44', 7, ink: _Ink.pointer),
    _Mark.arrow('M41 28L52 12L63 28Z', 3),
  ],
  // 2: level the shoulders.
  [
    _floor,
    _Mark.dot(48, 22, 9),
    _Mark.line('M24 52L72 38', 7),
    _Mark.line('M24 52L22 82', 7),
    _Mark.line('M72 38L74 82', 7),
    _Mark.dashes('M18 45H78', 3),
    _Mark.line('M9 58V68', 6, ink: _Ink.pointer),
    _Mark.arrow('M2 58L9 46L16 58Z', 2.5),
    _Mark.line('M87 22V32', 6, ink: _Ink.pointer),
    _Mark.arrow('M80 32L87 44L94 32Z', 2.5),
  ],
  // 3: knees off the floor.
  [
    _floor,
    _Mark.dot(15, 40, 8),
    _Mark.line('M26 48L60 58L74 80', 7),
    _Mark.line('M74 80L90 66', 7),
    _Mark.line('M26 48V82', 7),
    _Mark.line('M74 38V56', 7, ink: _Ink.pointer),
    _Mark.arrow('M63 38L74 22L85 38Z', 3),
  ],
  // 4: bend the arms.
  [
    _floor,
    _Mark.dot(15, 42, 8),
    _Mark.line('M26 50L58 57L88 80', 7),
    _Mark.line('M26 50V82', 7),
    _Mark.line('M36 71H48', 7, ink: _Ink.pointer),
    _Mark.arrow('M48 62L61 71L48 80Z', 3),
  ],
  // 5: belly off the floor.
  [
    _floor,
    _Mark.dot(15, 40, 8),
    _Mark.line('M26 48L56 75L88 79', 7),
    _Mark.line('M26 48V82', 7),
    _Mark.line('M60 42V58', 7, ink: _Ink.pointer),
    _Mark.arrow('M49 42L60 26L71 42Z', 3),
  ],
  // 6: on the floor, not against a wall.
  [
    _Mark.line('M6 86H90', 6, ink: _Ink.pointer),
    _Mark.dot(15, 40, 8),
    _Mark.line('M26 48L58 56L88 78', 7),
    _Mark.line('M26 48V80', 7),
    _Mark.line('M66 8V24', 7, ink: _Ink.pointer),
    _Mark.arrow('M55 24L66 40L77 24Z', 3),
  ],
  // 7: hold the phone still.
  [
    _Mark.line('M8 84H88', 3, ink: _Ink.floor),
    _Mark.phone(35, 18, 26, 50, 6),
    _Mark.dot(48, 28, 2.5),
    _Mark.line('M30 76H66', 7),
    _Mark.line('M14 28V44', 6, ink: _Ink.pointer),
    _Mark.arrow('M6 44L14 57L22 44Z', 2.5),
    _Mark.line('M82 28V44', 6, ink: _Ink.pointer),
    _Mark.arrow('M74 44L82 57L90 44Z', 2.5),
  ],
  // 8: sit lower (squat).
  [
    _Mark.line('M18 86H86', 3, ink: _Ink.floor),
    _Mark.dot(46, 16, 8),
    _Mark.line('M44 28L34 48L62 60L56 84', 7),
    _Mark.line('M44 31L66 37', 7),
    _Mark.dashes('M8 61H52', 3),
    _Mark.line('M16 16V34', 7, ink: _Ink.pointer),
    _Mark.arrow('M5 34L16 50L27 34Z', 3),
  ],
  // 9: stand up fully.
  [
    _Mark.line('M14 86H82', 3, ink: _Ink.floor),
    _Mark.dot(40, 14, 8),
    _Mark.line('M40 26L38 50L47 65L41 84', 7),
    _Mark.line('M40 29L49 47', 7),
    _Mark.line('M72 30V54', 7, ink: _Ink.pointer),
    _Mark.arrow('M61 30L72 14L83 30Z', 3),
  ],
];

/// Paints one of the design's reject pictograms (FxIcon): a gray figure, an
/// ink arrow or target line showing what to change, and a faint floor.
class BattleRejectIconPainter extends CustomPainter {
  const BattleRejectIconPainter(this.icon)
    : assert(icon >= 0 && icon < count, 'no such pictogram');

  /// The pictogram's number, from [BattleRejectSign.signIcon].
  final int icon;

  /// How many pictograms there are.
  static const count = 10;

  /// The side of the square the pictograms are drawn in.
  static const viewSize = 96.0;

  /// The dashes and gaps of a target line.
  static const _dash = 5.0;
  static const _gap = 6.0;

  static const _phoneCorner = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / viewSize, size.height / viewSize);
    for (final mark in _icons[icon]) {
      final color = switch (mark.ink) {
        _Ink.figure => AppColors.line,
        _Ink.pointer => AppColors.ink,
        _Ink.floor => AppColors.pictogramFloor,
      };
      final fill = Paint()..color = color;
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = mark.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (mark.circle case (final x, final y, final radius)) {
        canvas.drawCircle(Offset(x, y), radius, fill);
      } else if (mark.box case (final x, final y, final w, final h)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            const Radius.circular(_phoneCorner),
          ),
          stroke,
        );
      } else {
        final path = battleArtPath(mark.data);
        if (mark.filled) canvas.drawPath(path, fill);
        canvas.drawPath(mark.dashed ? _dashed(path) : path, stroke);
      }
    }
    canvas.restore();
  }

  /// The dashed form of each target line, cut once.
  static final _dashes = <Path, Path>{};

  /// [path] cut into dashes of [_dash] with gaps of [_gap].
  static Path _dashed(Path path) => _dashes[path] ??= _cut(path);

  static Path _cut(Path path) {
    final dashes = Path();
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        dashes.addPath(
          metric.extractPath(at, math.min(at + _dash, metric.length)),
          Offset.zero,
        );
      }
    }
    return dashes;
  }

  @override
  bool shouldRepaint(BattleRejectIconPainter oldDelegate) =>
      oldDelegate.icon != icon;
}

/// The sign for the user's rep that did not count: a white tile with the
/// pictogram of what to fix, and under it the short label on a band, red for
/// a rep that earned nothing and amber, with the points, for an average one.
///
/// It is drawn in design points with its top left at the box the design
/// gives it ([size]), and pops, wobbles and fades as [sign] says. A screen
/// reader finds the full sentence of the reason on it; the stage says that
/// sentence aloud when the sign comes up, so the sign itself does not.
class BattleRejectSignView extends StatelessWidget {
  const BattleRejectSignView({super.key, required this.sign});

  final BattleFxSign sign;

  /// The sign's box, in design points.
  static const size = Size(176, 200);

  /// The sign sits across the line between the stage and the camera, in the
  /// middle: its box starts this many stage points above that line. (In the
  /// design's 360 x 780 frame, where the line is at 390: at (92, 340).)
  static const riseAboveLine = 50.0;

  /// The point the sign grows and wobbles around.
  static const _pivot = Offset(88, 86);

  static const _tileSize = 128.0;
  static const _tileEdge = 4.0;
  static const _tileCorner = 26.0;
  static const _iconSize = 112.0;
  static const _labelTop = 134.0;
  static const _labelTopPadding = 2.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final icon = sign.reason.signIcon;
    return Semantics(
      container: true,
      label: sign.average
          ? '${sign.reason.koreanMessage} · +${sign.points}점'
          : sign.reason.koreanMessage,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: sign.opacity.clamp(0.0, 1.0),
          child: Transform(
            transform: Matrix4.rotationZ(sign.rotation * math.pi / 180)
                .multiplied(Matrix4.diagonal3Values(sign.scale, sign.scale, 1)),
            origin: _pivot,
            child: SizedBox.fromSize(
              size: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (icon != null)
                    Positioned(
                      left: (size.width - _tileSize) / 2,
                      top: 0,
                      width: _tileSize,
                      height: _tileSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          border: Border.all(
                            color: AppColors.ink,
                            width: _tileEdge,
                          ),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(_tileCorner),
                          ),
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size.square(_iconSize),
                            painter: BattleRejectIconPainter(icon),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _labelTop,
                    // A long label is wider than the sign's box.
                    child: OverflowBox(
                      fit: OverflowBoxFit.deferToChild,
                      minWidth: 0,
                      maxWidth: double.infinity,
                      child: BattleBand(
                        text: sign.text,
                        style: theme.stageSignLabel,
                        color: sign.tone.color,
                        topPadding: _labelTopPadding,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
