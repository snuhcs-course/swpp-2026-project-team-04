import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/battle_result.dart';
import 'models/exercise_type.dart';
import 'models/form_report.dart';
import 'models/matchup.dart';
import 'screens/battle_screen.dart';
import 'screens/character_select_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/help_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_shell_screen.dart';
import 'screens/login_screen.dart';
import 'screens/match_setup_screen.dart';
import 'screens/matching_screen.dart';
import 'screens/online_lobby_screen.dart';
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
import 'services/user/character_store.dart';
import 'services/user/rules_seen_store.dart';
import 'services/user/settings_store.dart';
import 'services/user/server_user_repository.dart';
import 'services/user/user_repository.dart';
import 'services/user/avatar_store.dart';
import 'theme/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/character_viewmodel.dart';
import 'viewmodels/help_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/signup_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Camera frames and the pose overlay assume portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Dark status and navigation bar icons on the light screens.
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final api = ApiClient();
  final auth = ServerAuthRepository(api: api, store: SecureTokenStore());
  runApp(
    GymRatsApp(
      authRepository: auth,
      userRepository: ServerUserRepository(api: api, auth: auth),
      characterStore: SecureCharacterStore(),
      rulesSeenStore: SecureRulesSeenStore(),
      settingsStore: SecureSettingsStore(),
    ),
  );
}

/// The app: the login screen while logged out, home while logged in.
/// An account that signed up on this phone sees the battle rules once
/// before its first home.
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
    this.characterStore,
    this.createOnlineSession,
    this.rulesSeenStore,
    this.settingsStore,
  });

  final AuthRepository authRepository;
  final UserRepository userRepository;

  /// Defaults to [BotMatchmaker].
  final Matchmaker Function()? createMatchmaker;

  /// Unused since the characters replaced the avatars (W3): nothing reads
  /// it, and the app passes none. Kept only because
  /// `test/support/fakes.dart` still passes it; the PM removes it with
  /// `avatar_store.dart` once no branch uses it.
  final AvatarStore? avatarStore;

  /// Keeps each account's character. Defaults to [MemoryCharacterStore].
  final CharacterStore? characterStore;
  final OnlineSessionFactory? createOnlineSession;

  /// Defaults to [MemoryRulesSeenStore].
  final RulesSeenStore? rulesSeenStore;

  /// Keeps the 환경설정 switches across restarts. Defaults to
  /// [MemorySettingsStore].
  final SettingsStore? settingsStore;

  static const signupRoute = '/signup';
  static const historyRoute = '/history';
  static const onlineBattleRoute = '/online-battle';

  /// 캐릭터 선택, from 게임 시작's 캐릭터 row and 환경설정.
  static const characterRoute = '/character';

  /// The battle rules, from '?' on home; back returns there.
  static const helpRoute = '/help';

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
  late final HelpViewModel _help;

  /// The signed-in account's character, the same on every screen.
  late final CharacterViewModel _characters;

  /// The app's settings, the same on every screen and every visit.
  late final SettingsViewModel _settings;
  AuthStatus? _shownStatus;

  @override
  void initState() {
    super.initState();
    _characters = CharacterViewModel(
      store: widget.characterStore ?? MemoryCharacterStore(),
    );
    _help = HelpViewModel(
      store: widget.rulesSeenStore ?? MemoryRulesSeenStore(),
    );
    _settings = SettingsViewModel(
      store: widget.settingsStore ?? MemorySettingsStore(),
    )..load();
    _auth = AuthViewModel(repository: widget.authRepository)
      ..addListener(_onAuthChanged)
      ..restore();
  }

  /// Logging in or out swaps the first screen; anything opened on top of
  /// it (sign-up, a match, history) belongs to the old state and closes.
  /// A login reads whether the account still has the rules to see, and
  /// its character; a logout puts the default character back.
  void _onAuthChanged() {
    if (_auth.status == _shownStatus) return;
    _shownStatus = _auth.status;
    _navigator.currentState?.popUntil((route) => route.isFirst);
    final account = _auth.account;
    if (_auth.status == AuthStatus.signedIn && account != null) {
      _help.load(account.id);
      _characters.load(account.id);
    } else if (_auth.status == AuthStatus.signedOut) {
      _characters.clear();
    }
  }

  @override
  void dispose() {
    _auth
      ..removeListener(_onAuthChanged)
      ..dispose();
    _help.dispose();
    _settings.dispose();
    _characters.dispose();
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
        ChangeNotifierProvider<HelpViewModel>.value(value: _help),
        ChangeNotifierProvider<SettingsViewModel>.value(value: _settings),
        ChangeNotifierProvider<CharacterViewModel>.value(value: _characters),
        Provider<FormReportStore>(create: (_) => FileFormReportStore()),
      ],
      child: MaterialApp(
        title: 'GymRats',
        theme: AppTheme.light,
        navigatorKey: _navigator,
        navigatorObservers: [GymRatsApp.routeObserver],
        home: Consumer2<AuthViewModel, HelpViewModel>(
          builder: (context, auth, help, _) => switch (auth.status) {
            AuthStatus.restoring => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            AuthStatus.signedOut => const LoginScreen(),
            AuthStatus.signedIn => switch (help.gateFor(auth.account?.id)) {
              HelpGate.checking => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              HelpGate.rules => HelpScreen(onStart: help.markSeen),
              // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
              // A new home shell per account, so nothing of the previous
              // user's profile stays on screen.
              HelpGate.home => HomeShellScreen(
                key: ValueKey(auth.account?.id),
                onLogOut: auth.logOut,
              ),
            },
          },
        ),
        onGenerateRoute: (settings) => switch (settings.name) {
          GymRatsApp.onlineBattleRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OnlineLobbyScreen(
              auth: widget.authRepository,
              exercise:
                  (settings.arguments as ExerciseType?) ?? ExerciseType.pushUp,
              onAuthenticationFailed: _auth.logOut,
              myCharacter: _characters.characterId,
              createSession: widget.createOnlineSession,
              userRepository: widget.userRepository,
            ),
          ),
          GymRatsApp.characterRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const CharacterSelectScreen(),
          ),
          GymRatsApp.signupRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => SignupScreen(
              createViewModel: () => SignupViewModel(auth: _auth, help: _help),
            ),
          ),
          GymRatsApp.helpRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const HelpScreen(),
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
            builder: (_) {
              final request = settings.arguments! as BotMatchRequest;
              return MatchingScreen(
                exercise: request.exercise,
                difficulty: request.difficulty,
              );
            },
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
            builder: (_) => BattleScreen(
              matchup: settings.arguments! as Matchup,
              myCharacter: _characters.characterId,
            ),
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
