// Standalone demo for manually checking the pose setup step on a phone.
//
// Run from gymrats_app/:
//   flutter run -t lib/demo/pose_setup_demo.dart -d <device-id>
//
// Needs no login, server, or other features. It uses the real SetupScreen,
// SetupViewModel, SetupChecker, PoseEstimator, and CameraService.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_type.dart';
import '../screens/setup_screen.dart';
import '../viewmodels/setup_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PoseSetupDemoApp());
}

class PoseSetupDemoApp extends StatelessWidget {
  const PoseSetupDemoApp({super.key, this.createViewModel});

  /// Builds the setup view model; replaces the default one in tests.
  final SetupViewModel Function(ExerciseType exercise)? createViewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose setup demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _ExercisePicker(createViewModel: createViewModel),
    );
  }
}

class _ExercisePicker extends StatelessWidget {
  const _ExercisePicker({this.createViewModel});

  final SetupViewModel Function(ExerciseType exercise)? createViewModel;

  Future<void> _openSetup(BuildContext context, ExerciseType exercise) async {
    final result = await Navigator.push<ExerciseType>(
      context,
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          exercise: exercise,
          showDebugTools: true,
          createViewModel: switch (createViewModel) {
            final create? => () => create(exercise),
            null => null,
          },
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => _SetupComplete(exercise: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pose setup demo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose an exercise',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 24),
              for (final exercise in ExerciseType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton(
                    onPressed: () => _openSetup(context, exercise),
                    child: Text(exercise.label),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupComplete extends StatelessWidget {
  const _SetupComplete({required this.exercise});

  final ExerciseType exercise;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 72),
            const SizedBox(height: 16),
            Text(
              'Setup complete: ${exercise.label}',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to exercise picker'),
            ),
          ],
        ),
      ),
    );
  }
}
