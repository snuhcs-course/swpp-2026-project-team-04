import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/battle_result.dart';
import 'models/exercise_type.dart';
import 'models/form_report.dart';
import 'models/matchup.dart';
import 'screens/battle_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/match_setup_screen.dart';
import 'screens/matching_screen.dart';
import 'screens/online_lobby_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/result_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/versus_screen.dart';
import 'services/api/api_client.dart';
import 'services/auth/auth_repository.dart';
import 'services/auth/token_store.dart';
import 'services/feedback/form_report_store.dart';
import 'services/matching/bot_matchmaker.dart';
import 'services/matching/matchmaker.dart';
import 'services/user/server_user_repository.dart';
import 'services/user/user_repository.dart';
import 'services/user/avatar_store.dart';
import 'theme/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Camera frames and the pose overlay assume portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final api = ApiClient();
  final auth = ServerAuthRepository(api: api, store: SecureTokenStore());
  runApp(
    GymRatsApp(
      authRepository: auth,
      userRepository: ServerUserRepository(api: api, auth: auth),
      avatarStore: SecureAvatarStore(),
    ),
  );
}

/// The app: the login screen while logged out, home while logged in.
///
/// The repositories come in from outside, so tests and demos can run it
/// on in-memory ones without a server.
class GymRatsApp extends StatefulWidget {
  const GymRatsApp({
    super.key,
    required this.authRepository,
    required this.userRepository,
    this.createMatchmaker,
    this.avatarStore,
    this.createOnlineSession,
  });

  final AuthRepository authRepository;
  final UserRepository userRepository;

  /// Defaults to [BotMatchmaker].
  final Matchmaker Function()? createMatchmaker;
  final AvatarStore? avatarStore;
  final OnlineSessionFactory? createOnlineSession;

  static const signupRoute = '/signup';
  static const historyRoute = '/history';
  static const onlineBattleRoute = '/online-battle';
  static const profileRoute = '/profile';

  static const setupRoute = '/setup';
  static const matchingRoute = '/matching';
  static const versusRoute = '/versus';

  /// SetupScreen inside the matching flow, with a way to cancel the match.
  static const matchSetupRoute = '/match-setup';
  static const battleRoute = '/battle';
  static const resultRoute = '/result';

  /// The form feedback of one battle, from the result screen or home.
  static const feedbackRoute = '/feedback';

  /// Tells HomeScreen when it shows again, so it reloads the latest battle.
  static final routeObserver = RouteObserver<ModalRoute<void>>();

  @override
  State<GymRatsApp> createState() => _GymRatsAppState();
}

class _GymRatsAppState extends State<GymRatsApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final AuthViewModel _auth;
  late final AvatarStore _avatars;
  AuthStatus? _shownStatus;

  @override
  void initState() {
    super.initState();
    _avatars = widget.avatarStore ?? MemoryAvatarStore();
    _auth = AuthViewModel(repository: widget.authRepository)
      ..addListener(_onAuthChanged)
      ..restore();
  }

  /// Logging in or out swaps the first screen; anything opened on top of
  /// it (sign-up, a match, history) belongs to the old state and closes.
  void _onAuthChanged() {
    if (_auth.status == _shownStatus) return;
    _shownStatus = _auth.status;
    _navigator.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _auth
      ..removeListener(_onAuthChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One repository and one matchmaker for the whole app. They sit above
    // the navigator, so every route sees the same ones.
    return MultiProvider(
      providers: [
        Provider<UserRepository>.value(value: widget.userRepository),
        Provider<Matchmaker>(
          create: (_) => widget.createMatchmaker?.call() ?? BotMatchmaker(),
        ),
        ChangeNotifierProvider<AuthViewModel>.value(value: _auth),
        Provider<FormReportStore>(create: (_) => FileFormReportStore()),
      ],
      child: MaterialApp(
        title: 'GymRats',
        theme: AppTheme.dark,
        navigatorKey: _navigator,
        navigatorObservers: [GymRatsApp.routeObserver],
        home: Consumer<AuthViewModel>(
          builder: (context, auth, _) => switch (auth.status) {
            AuthStatus.restoring => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            AuthStatus.signedOut => const LoginScreen(),
            // A new HomeScreen per account, so nothing of the previous
            // user's profile stays on screen.
            AuthStatus.signedIn => HomeScreen(
              key: ValueKey(auth.account?.id),
              onLogOut: auth.logOut,
            ),
          },
        ),
        onGenerateRoute: (settings) => switch (settings.name) {
          GymRatsApp.onlineBattleRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OnlineLobbyScreen(
              auth: widget.authRepository,
              onAuthenticationFailed: _auth.logOut,
              avatarStore: _avatars,
              createSession: widget.createOnlineSession,
            ),
          ),
          GymRatsApp.profileRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                ProfileScreen(auth: widget.authRepository, avatars: _avatars),
          ),
          GymRatsApp.signupRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SignupScreen(),
          ),
          GymRatsApp.historyRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const HistoryScreen(),
          ),
          GymRatsApp.setupRoute => MaterialPageRoute<ExerciseType>(
            settings: settings,
            builder: (_) =>
                SetupScreen(exercise: settings.arguments! as ExerciseType),
          ),
          GymRatsApp.matchingRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                MatchingScreen(exercise: settings.arguments! as ExerciseType),
          ),
          GymRatsApp.versusRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                VersusScreen(matchup: settings.arguments! as Matchup),
          ),
          GymRatsApp.matchSetupRoute => MaterialPageRoute<ExerciseType>(
            settings: settings,
            builder: (_) =>
                MatchSetupScreen(matchup: settings.arguments! as Matchup),
          ),
          GymRatsApp.battleRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                BattleScreen(matchup: settings.arguments! as Matchup),
          ),
          GymRatsApp.resultRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                ResultScreen(result: settings.arguments! as BattleResult),
          ),
          GymRatsApp.feedbackRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                FeedbackScreen(report: settings.arguments! as FormReport),
          ),
          _ => null,
        },
      ),
    );
  }
}
