import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../widgets/pose_camera_view.dart';

/// Standalone S2 camera demo: flutter run -t lib/demo/squat_judge_demo.dart
void main() => runApp(const MaterialApp(home: SquatJudgeDemo()));

class SquatJudgeDemo extends StatefulWidget {
  const SquatJudgeDemo({super.key});
  @override
  State<SquatJudgeDemo> createState() => _SquatJudgeDemoState();
}

class _SquatJudgeDemoState extends State<SquatJudgeDemo> {
  late final RepCounterViewModel counter;
  @override
  void initState() {
    super.initState();
    counter = RepCounterViewModel(exercise: ExerciseType.squat)
      ..addListener(_changed);
    counter.start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    counter.removeListener(_changed);
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Squat judge demo')),
    body: Stack(
      fit: StackFit.expand,
      children: [
        PoseCameraView(
          controller: counter.cameraController,
          frame: counter.state.lastFrame,
          mirror: counter.isFrontCamera,
          showLandmarks: true,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(16),
            child: Text(
              'Valid: ${counter.state.validReps}   Rejected: ${counter.state.invalidReps}   ${counter.state.snapshot.phase.name}',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    ),
  );
}
