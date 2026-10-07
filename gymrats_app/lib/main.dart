import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/exercise_type.dart';
import 'models/matchup.dart';
import 'screens/coming_soon_screen.dart';
import 'screens/home_screen.dart';
import 'screens/match_setup_screen.dart';
import 'screens/matching_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/versus_screen.dart';
import 'services/matching/bot_matchmaker.dart';
import 'services/matching/matchmaker.dart';
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
  static const versusRoute = '/versus';

  /// SetupScreen inside the matching flow, with a way to cancel the match.
  static const matchSetupRoute = '/match-setup';
  static const battleRoute = '/battle';

  @override
  Widget build(BuildContext context) {
    // One repository and one matchmaker for the whole app. They sit above
    // the navigator, so every route sees the same ones.
    return MultiProvider(
      providers: [
        Provider<UserRepository>(create: (_) => InMemoryUserRepository()),
        Provider<Matchmaker>(create: (_) => BotMatchmaker()),
      ],
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
          matchingRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                MatchingScreen(exercise: settings.arguments! as ExerciseType),
          ),
          versusRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                VersusScreen(matchup: settings.arguments! as Matchup),
          ),
          matchSetupRoute => MaterialPageRoute<ExerciseType>(
            settings: settings,
            builder: (_) =>
                MatchSetupScreen(matchup: settings.arguments! as Matchup),
          ),
          // Placeholder until P10 builds the battle screen. It will read the
          // Matchup from settings.arguments, like the versus route.
          battleRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                const ComingSoonScreen(message: '배틀 화면은 P10에서 구현 예정'),
          ),
          _ => null,
        },
      ),
    );
  }
}
