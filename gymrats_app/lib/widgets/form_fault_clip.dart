// AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/feedback/form_analyzer.dart';
import '../theme/app_theme.dart';

/// A 2.5 second side-view example of one fault, looping until tapped.
///
/// The figure is prepared for that fault. It is not redrawn from the
/// user's joints, so a plank fault is not shown as a kneel. Knees stay
/// off the floor except for [FormDemo.knees].
///
/// Palette B (BFeedback): a thin ink figure on a light floor line, kept in
/// shape at any width; the part at fault is amber with an ink edge.
class FormFaultClip extends StatefulWidget {
  const FormFaultClip({super.key, required this.demo});

  final FormDemo demo;

  @override
  State<FormFaultClip> createState() => _FormFaultClipState();
}

class _FormFaultClipState extends State<FormFaultClip>
    with SingleTickerProviderStateMixin {
  static const _length = Duration(milliseconds: 2500);
  static const _height = 150.0;

  late final AnimationController _play;

  @override
  void initState() {
    super.initState();
    _play = AnimationController(vsync: this, duration: _length)..repeat();
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_play.isAnimating) {
        _play.stop();
      } else {
        _play.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playing = _play.isAnimating;
    final caption = playing ? '예시 동작 · 누르면 멈춤' : '예시 동작 · 누르면 재생';
    return Tooltip(
      message: playing ? '예시 멈춤' : '예시 재생',
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _height,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _play,
                builder: (context, _) => CustomPaint(
                  painter: _FaultPainter(demo: widget.demo, t: _play.value),
                ),
              ),
            ),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaultPainter extends CustomPainter {
  _FaultPainter({required this.demo, required this.t});

  final FormDemo demo;
  final double t;

  /// The figure's own units; it is scaled to fit, keeping its shape, and
  /// stands on the clip's bottom.
  static const _design = Size(150, 110);

  /// The floor's height in figure units.
  static const _floorY = 104.0;

  /// The floor line's distance from the clip's sides, in pixels.
  static const _floorInset = 20.0;

  /// Line widths and the head in pixels, whatever the scale (BFeedback):
  /// a 9 px body from the shoulder to the knee, 6 px for the shins, the
  /// arms and the neck, an 8.2 px head; the part at fault keeps its width
  /// in amber inside a 1.5 px ink edge.
  static const _floorWidth = 1.5;
  static const _bodyWidth = 9.0;
  static const _limbWidth = 6.0;
  static const _headRadius = 8.2;
  static const _hotEdge = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / _design.width,
      size.height / _design.height,
    );
    final left = (size.width - _design.width * scale) / 2;
    final top = size.height - _design.height * scale;
    final floor = Paint()
      ..color = AppColors.pictogramFloor
      ..strokeWidth = _floorWidth
      ..strokeCap = StrokeCap.round;
    final floorY = top + _floorY * scale;
    canvas
      ..clipRect(Offset.zero & size)
      ..drawLine(
        Offset(_floorInset, floorY),
        Offset(size.width - _floorInset, floorY),
        floor,
      )
      ..translate(left, top)
      ..scale(scale);
    if (demo == FormDemo.upright) {
      canvas.drawLine(
        const Offset(28, 18),
        const Offset(28, _floorY),
        floor..strokeWidth = _floorWidth / scale,
      );
    }

    final pose = _pose(demo, t);
    if (demo == FormDemo.tilted) {
      final pivot = pose.hip;
      canvas
        ..translate(pivot.dx, pivot.dy)
        ..rotate(-0.22 * pose.bend)
        ..translate(-pivot.dx, -pivot.dy);
    }

    final parts = <_Limb>[
      // The neck: with thin lines the small head would float off the body.
      _Limb(pose.shoulder, pose.head, _limbWidth, false),
      _Limb(pose.hip, pose.knee, _bodyWidth, _hot(demo, 'knee')),
      _Limb(pose.knee, pose.foot, _limbWidth, _hot(demo, 'knee')),
      _Limb(
        pose.shoulder,
        pose.hip,
        _bodyWidth,
        _hot(demo, 'hip') || _hot(demo, 'shoulder'),
      ),
      _Limb(pose.shoulder, pose.elbow, _limbWidth, _hot(demo, 'elbow')),
      _Limb(
        pose.elbow,
        pose.wrist,
        _limbWidth,
        _hot(demo, 'elbow') || _hot(demo, 'wrist'),
      ),
    ];

    final px = 1 / scale;
    for (final limb in parts) {
      if (limb.hot) {
        canvas
          ..drawLine(
            limb.from,
            limb.to,
            _stroke(AppColors.ink, (limb.width + _hotEdge * 2) * px),
          )
          ..drawLine(
            limb.from,
            limb.to,
            _stroke(AppColors.warning, limb.width * px),
          );
      } else {
        canvas.drawLine(
          limb.from,
          limb.to,
          _stroke(AppColors.ink, limb.width * px),
        );
      }
    }

    final head = _headRadius * px;
    if (_hot(demo, 'head')) {
      canvas
        ..drawCircle(pose.head, head, Paint()..color = AppColors.warning)
        ..drawCircle(
          pose.head,
          head,
          Paint()
            ..color = AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = _hotEdge * px,
        );
    } else {
      canvas.drawCircle(pose.head, head, Paint()..color = AppColors.ink);
    }
  }

  @override
  bool shouldRepaint(_FaultPainter oldDelegate) =>
      oldDelegate.demo != demo || oldDelegate.t != t;

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
}

bool _hot(FormDemo demo, String part) => switch (demo) {
  FormDemo.knees => part == 'knee',
  FormDemo.shallow || FormDemo.headFirst => part == 'head',
  FormDemo.lockout ||
  FormDemo.straightArms ||
  FormDemo.flare ||
  FormDemo.uneven ||
  FormDemo.fastDrop => part == 'elbow',
  FormDemo.belly || FormDemo.upright => part == 'hip',
  FormDemo.tilted => part == 'shoulder',
  FormDemo.wideHands => part == 'wrist',
};

/// 0 at the top, 1 at the bottom. [drop] is the share of the loop spent going down.
double _down(double t, {double drop = 0.42}) {
  const hold = 0.14;
  final rise = 1 - drop - hold;
  if (t < drop) return t / drop;
  if (t < drop + hold) return 1;
  final climbed = (t - drop - hold) / rise;
  return climbed >= 1 ? 0 : 1 - climbed;
}

class _Pose {
  const _Pose({
    required this.head,
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.hip,
    required this.knee,
    required this.foot,
    required this.bend,
  });

  final Offset head;
  final Offset shoulder;
  final Offset elbow;
  final Offset wrist;
  final Offset hip;
  final Offset knee;
  final Offset foot;
  final double bend;
}

class _Limb {
  const _Limb(this.from, this.to, this.width, this.hot);

  final Offset from;
  final Offset to;
  final double width;
  final bool hot;
}

_Pose _pose(FormDemo demo, double t) {
  final full = demo == FormDemo.fastDrop ? _down(t, drop: 0.12) : _down(t);
  final bend = switch (demo) {
    FormDemo.shallow => full * 0.42,
    FormDemo.lockout => 0.36 + full * 0.64,
    FormDemo.straightArms => 0.06,
    FormDemo.upright => full * 0.28,
    _ => full,
  };
  final body = demo == FormDemo.uneven ? bend * 0.28 : bend;
  final headLead = demo == FormDemo.headFirst
      ? math.min(1.0, full * 2.2)
      : body;

  if (demo == FormDemo.upright) {
    return _Pose(
      head: _mix(const Offset(78, 20), const Offset(70, 34), bend),
      shoulder: _mix(const Offset(84, 36), const Offset(76, 48), bend),
      elbow: _mix(const Offset(64, 46), const Offset(58, 62), bend),
      wrist: const Offset(46, 74),
      hip: _mix(const Offset(92, 72), const Offset(86, 78), bend),
      knee: _mix(const Offset(96, 90), const Offset(92, 92), bend),
      foot: const Offset(100, 104),
      bend: bend,
    );
  }

  var head = _mix(const Offset(30, 26), const Offset(22, 70), headLead);
  var shoulder = _mix(const Offset(46, 38), const Offset(40, 76), body);
  var elbow = _mix(const Offset(40, 62), const Offset(56, 90), bend);
  final wrist = _mix(
    const Offset(34, 100),
    Offset(demo == FormDemo.wideHands ? 16 : 34, 100),
    bend,
  );
  var hip = _mix(const Offset(100, 52), const Offset(96, 80), body);
  var knee = _mix(const Offset(122, 68), const Offset(118, 88), body);
  var foot = _mix(const Offset(144, 98), const Offset(140, 100), body);

  if (demo == FormDemo.knees) {
    knee = Offset(hip.dx + 14, 100);
    foot = Offset(knee.dx + 26, 100);
    hip = _mix(const Offset(86, 78), const Offset(82, 86), bend);
    shoulder = _mix(const Offset(48, 58), const Offset(44, 78), bend);
    head = _mix(const Offset(34, 46), const Offset(26, 72), bend);
  } else if (demo == FormDemo.straightArms) {
    hip = _mix(const Offset(100, 52), const Offset(72, 30), full);
    head = _mix(const Offset(30, 26), const Offset(40, 74), full);
    knee = _mix(const Offset(122, 72), const Offset(118, 78), full);
    foot = const Offset(142, 100);
  } else if (demo == FormDemo.belly) {
    hip = _mix(const Offset(100, 62), const Offset(96, 102), full);
    knee = _mix(const Offset(122, 70), const Offset(126, 74), full);
  } else if (demo == FormDemo.flare) {
    elbow = Offset(elbow.dx, elbow.dy - 18 * full);
  }

  return _Pose(
    head: head,
    shoulder: shoulder,
    elbow: elbow,
    wrist: wrist,
    hip: hip,
    knee: knee,
    foot: foot,
    bend: bend,
  );
}

Offset _mix(Offset a, Offset b, double t) => Offset.lerp(a, b, t.clamp(0, 1))!;
