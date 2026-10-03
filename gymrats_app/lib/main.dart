import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/exercise_type.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Camera frames and the pose overlay assume portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GymRatsApp());
}

class GymRatsApp extends StatelessWidget {
  const GymRatsApp({super.key});

  static const setupRoute = '/setup';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymRats',
      theme: AppTheme.dark,
      // HomeScreen and the rest of the flow come in later branches.
      home: const Scaffold(body: Center(child: Text('GymRats'))),
      onGenerateRoute: (settings) => switch (settings.name) {
        setupRoute => MaterialPageRoute<ExerciseType>(
          settings: settings,
          builder: (_) =>
              SetupScreen(exercise: settings.arguments! as ExerciseType),
        ),
        _ => null,
      },
    );
  }
}
