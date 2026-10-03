import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/exercise_type.dart';
import 'screens/coming_soon_screen.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/user/in_memory_user_repository.dart';
import 'services/user/user_repository.dart';
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
  static const matchingRoute = '/matching';

  @override
  Widget build(BuildContext context) {
    // One repository for the whole app. It sits above the navigator, so
    // every route sees the same data.
    return Provider<UserRepository>(
      create: (_) => InMemoryUserRepository(),
      child: MaterialApp(
        title: 'GymRats',
        theme: AppTheme.dark,
        home: const HomeScreen(),
        onGenerateRoute: (settings) => switch (settings.name) {
          setupRoute => MaterialPageRoute<ExerciseType>(
            settings: settings,
            builder: (_) =>
                SetupScreen(exercise: settings.arguments! as ExerciseType),
          ),
          // Placeholder until MatchingScreen is built.
          matchingRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ComingSoonScreen(message: '매칭 중 화면은 구현 예정'),
          ),
          _ => null,
        },
      ),
    );
  }
}
