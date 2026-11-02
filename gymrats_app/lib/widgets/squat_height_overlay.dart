import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pose_frame.dart';
import '../services/pose/rep_judge.dart';

/// Displays the same hip and knee heights that the squat judge used.
class SquatHeightOverlay extends StatelessWidget {
  const SquatHeightOverlay({
    super.key,
    required this.frame,
    required this.snapshot,
  });

  final PoseFrame? frame;
  final JudgeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final currentFrame = frame;
    if (currentFrame == null ||
        currentFrame.imageWidth <= 0 ||
        currentFrame.imageHeight <= 0 ||
        !currentFrame.imageWidth.isFinite ||
        !currentFrame.imageHeight.isFinite ||
        snapshot.squatHipY == null ||
        snapshot.squatKneeY == null ||
        snapshot.phase == RepPhase.lost) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: SquatHeightPainter(frame: currentFrame, snapshot: snapshot),
      ),
    );
  }
}

class SquatHeightPainter extends CustomPainter {
  SquatHeightPainter({required this.frame, required this.snapshot});
  final PoseFrame frame;
  final JudgeSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final color = switch (snapshot.phase) {
      RepPhase.up => Colors.lightBlueAccent,
      RepPhase.bottom => Colors.greenAccent,
      _ => Colors.white70,
    };
    final scale = math.max(
      size.width / frame.imageWidth,
      size.height / frame.imageHeight,
    );
    double projectY(double y) =>
        (y - frame.imageHeight / 2) * scale + size.height / 2;
    final hipY = projectY(snapshot.squatHipY!);
    final kneeY = projectY(snapshot.squatKneeY!);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final (y, label) in [(hipY, '엉덩이'), (kneeY, '무릎')]) {
      final dark = Paint()
        ..color = Colors.black87
        ..strokeWidth = 5;
      final line = Paint()
        ..color = color
        ..strokeWidth = 2.5;
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), dark);
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), line);
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(14, y - text.height - 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SquatHeightPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.snapshot != snapshot;
}
