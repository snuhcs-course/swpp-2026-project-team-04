import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/battle_result.dart';
import 'models/exercise_type.dart';
import 'models/form_report.dart';
import 'models/matchup.dart';
import 'screens/arcade_screen.dart';
import 'screens/battle_screen.dart';
import 'screens/body_info_screen.dart';
import 'screens/character_select_screen.dart';
import 'screens/coach_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/friends_screen.dart';
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
import 'screens/social_signup_screen.dart';
import 'screens/versus_screen.dart';
import 'screens/weekly_rankings_screen.dart';
import 'services/device/device_controls.dart';
import 'services/telemetry/telemetry_service.dart';
import 'services/api/api_client.dart';
import 'services/arcade/arcade_progress_store.dart';
import 'services/auth/auth_repository.dart';
import 'services/auth/google_sign_in_service.dart';
import 'services/auth/token_store.dart';
import 'services/feedback/form_report_store.dart';
import 'services/feedback/hold_record_store.dart';
import 'services/feedback/goal_store.dart';
import 'services/friends/friend_repository.dart';
import 'services/matching/bot_matchmaker.dart';
import 'services/matching/matchmaker.dart';
import 'services/rankings/rankings_repository.dart';
import 'services/user/character_store.dart';
import 'services/user/rules_seen_store.dart';
import 'services/user/settings_store.dart';
import 'services/user/server_user_repository.dart';
import 'services/user/user_repository.dart';
import 'services/user/avatar_store.dart';
import 'theme/app_theme.dart';
import 'viewmodels/arcade_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/body_info_viewmodel.dart';
import 'viewmodels/character_viewmodel.dart';
import 'viewmodels/coach_viewmodel.dart';
import 'viewmodels/friends_viewmodel.dart';
import 'viewmodels/weekly_rankings_viewmodel.dart';
import 'viewmodels/help_viewmodel.dart';
import 'viewmodels/login_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/signup_viewmodel.dart';
import 'viewmodels/social_signup_viewmodel.dart';
import 'widgets/gym_background_art.dart';

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
  // The arcade's art is built once, now, not on its first paint (A3).
  GymArt.warmUp();
  final api = ApiClient();
  final auth = ServerAuthRepository(api: api, store: SecureTokenStore());
  runApp(
    GymRatsApp(
      authRepository: auth,
      // A build that clears the client id hides the Google button.
      googleSignIn: googleServerClientId.isEmpty ? null : GoogleSignInService(),
      userRepository: ServerUserRepository(api: api, auth: auth),
      characterStore: SecureCharacterStore(),
      rulesSeenStore: SecureRulesSeenStore(),
      settingsStore: SecureSettingsStore(),
      arcadeStore: SecureArcadeProgressStore(),
      holdRecords: FileHoldRecordStore(),
      friendRepository: ServerFriendRepository(api: api),
      rankingsRepository: ServerRankingsRepository(api: api),
      // P17: P6's events, sent with the login; kept on the phone meanwhile.
      telemetry: Telemetry(
        send: httpTelemetrySender(api),
        root: appFilesDirectory,
        // Events go only with the login of the account that made them.
        owner: () => auth.session?.account.id.toString(),
      ),
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
    this.arcadeStore,
    this.holdRecords,
    this.googleSignIn,
    this.friendRepository,
    this.rankingsRepository,
    this.telemetry,
  });

  final AuthRepository authRepository;

  /// The login screen's Google sign-in; null hides its button.
  final SocialSignInService? googleSignIn;
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

  /// Keeps each account's arcade progress. Defaults to
  /// [MemoryArcadeProgressStore].
  final ArcadeProgressStore? arcadeStore;

  /// Keeps the played holds for their report and the archive (P13).
  /// Defaults to [InMemoryHoldRecordStore].
  final HoldRecordStore? holdRecords;

  /// Friends and friend battle invites (P9). Defaults to an empty
  /// [InMemoryFriendRepository].
  final FriendRepository? friendRepository;

  /// Weekly rankings (P11). Defaults to an empty
  /// [InMemoryRankingsRepository].
  final RankingsRepository? rankingsRepository;

  /// Where the screens record P6's telemetry events (P17). Defaults to one
  /// that only keeps them in memory and sends nothing.
  final Telemetry? telemetry;

  static const signupRoute = '/signup';

  /// 친구와의 대전 (P9).
  static const friendsRoute = '/friends';

  /// 주간 랭킹 (P11), from the online battle's exercise sheet.
  static const weeklyRankingsRoute = '/weekly-rankings';

  /// The nickname of a new Google account; its argument is the
  /// [SocialSignupRequest].
  static const socialSignupRoute = '/social-signup';
  static const historyRoute = '/history';
  static const onlineBattleRoute = '/online-battle';

  /// The arcade's map, from 게임 시작 (P16). Its stages' screens close back
  /// down to it.
  static const arcadeRoute = '/arcade';

  /// The names of the arcade's stage screens over its map (P16), so that a
  /// friend's invite waits while one is open (`FriendInviteRouteWatch`):
  /// a fight's sheet, a hold stage, a boss match's intro and its break
  /// between the rounds, and a stage's result. A fight itself opens
  /// [versusRoute] and [battleRoute]. These screens are opened with their
  /// stage by the arcade's screens and `ArcadeFlow`, never by name alone.
  static const arcadeSheetRoute = '/arcade/sheet';
  static const arcadeHoldRoute = '/arcade/hold';
  static const arcadeBossRoute = '/arcade/boss';
  static const arcadeBreakRoute = '/arcade/break';
  static const arcadeResultRoute = '/arcade/result';

  /// 캐릭터 선택, from home's 캐릭터 row and 환경설정.
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

  /// The character's talk about one battle, from the result screen's
  /// character card; its argument is the report's [CoachViewModel].
  static const coachRoute = '/coach';

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

  /// The signed-in account's arcade, the same on the map and its stages.
  late final ArcadeViewModel _arcade;

  /// Friends (P9), the same for every screen.
  late final FriendRepository _friends =
      widget.friendRepository ?? InMemoryFriendRepository();

  /// A friend's battle invite, above every page while signed in (P9).
  late final _inviteAlert = FriendInviteAlertViewModel(repository: _friends);
  final _inviteRoutes = FriendInviteRouteWatch();
  AuthStatus? _shownStatus;
  late final Telemetry _telemetry = widget.telemetry ?? Telemetry();

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
    _arcade = ArcadeViewModel(
      store: widget.arcadeStore ?? MemoryArcadeProgressStore(),
    );
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
    _inviteAlert.setSignedIn(_auth.status == AuthStatus.signedIn);
    if (_auth.status == AuthStatus.signedIn && account != null) {
      _help.load(account.id);
      _characters.load(account.id);
      _arcade.load(account.id);
      // Events kept while logged out (the tutorial before the first home).
      _telemetry.flush();
    } else if (_auth.status == AuthStatus.signedOut) {
      _characters.clear();
      _arcade.clear();
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
    _arcade.dispose();
    _inviteAlert.dispose();
    _inviteRoutes.dispose();
    _telemetry.dispose();
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
        Provider<FriendRepository>.value(value: _friends),
        ChangeNotifierProvider<HelpViewModel>.value(value: _help),
        ChangeNotifierProvider<SettingsViewModel>.value(value: _settings),
        ChangeNotifierProvider<CharacterViewModel>.value(value: _characters),
        ChangeNotifierProvider<ArcadeViewModel>.value(value: _arcade),
        Provider<FormReportStore>(create: (_) => FileFormReportStore()),
        Provider<HoldRecordStore>(
          create: (_) => widget.holdRecords ?? InMemoryHoldRecordStore(),
        ),
        Provider<GoalStore>(create: (_) => SecureGoalStore()),
        Provider<Telemetry>.value(value: _telemetry),
      ],
      child: MaterialApp(
        title: 'GymRats',
        theme: AppTheme.light,
        navigatorKey: _navigator,
        navigatorObservers: [GymRatsApp.routeObserver, _inviteRoutes],
        builder: (context, child) => FriendInviteOverlay(
          viewModel: _inviteAlert,
          routes: _inviteRoutes,
          navigator: _navigator,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Consumer3<AuthViewModel, HelpViewModel, CharacterViewModel>(
          builder: (context, auth, help, character, _) => switch (auth.status) {
            AuthStatus.restoring => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            AuthStatus.signedOut => LoginScreen(
              createViewModel: () =>
                  LoginViewModel(auth: _auth, google: widget.googleSignIn),
            ),
            // A new account first gives (or skips) height and weight.
            AuthStatus.signedIn when auth.needsBodyInfo => BodyInfoScreen(
              createViewModel: () => BodyInfoViewModel(auth: _auth),
            ),
            AuthStatus.signedIn => switch (help.gateFor(auth.account?.id)) {
              HelpGate.checking => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              HelpGate.rules => HelpScreen(onStart: help.markSeen),
              // Home also waits for the account's saved character, so no
              // screen opened from it takes the stand-in default for it: a
              // pick on 캐릭터 선택 would save it over the saved one, and a
              // battle would fight with it.
              HelpGate.home when !character.isReadyFor(auth.account?.id) =>
                const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
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
          // An exercise for the main match, or a FriendBattle (P9).
          GymRatsApp.onlineBattleRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => OnlineLobbyScreen(
              auth: widget.authRepository,
              exercise: switch (settings.arguments) {
                final ExerciseType exercise => exercise,
                final FriendBattle battle => battle.exercise,
                _ => ExerciseType.pushUp,
              },
              friendBattle: settings.arguments is FriendBattle
                  ? settings.arguments! as FriendBattle
                  : null,
              friends: _friends,
              onAuthenticationFailed: _auth.logOut,
              myCharacter: _characters.characterId,
              createSession: widget.createOnlineSession,
              userRepository: widget.userRepository,
            ),
          ),
          GymRatsApp.arcadeRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ArcadeScreen(),
          ),
          GymRatsApp.friendsRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => FriendsScreen(
              createViewModel: () => FriendsViewModel(repository: _friends),
            ),
          ),
          GymRatsApp.weeklyRankingsRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => WeeklyRankingsScreen(
              createViewModel: () => WeeklyRankingsViewModel(
                repository:
                    widget.rankingsRepository ?? InMemoryRankingsRepository(),
              ),
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
          GymRatsApp.socialSignupRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => SocialSignupScreen(
              createViewModel: () => SocialSignupViewModel(
                auth: _auth,
                help: _help,
                request: settings.arguments! as SocialSignupRequest,
              ),
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
          GymRatsApp.coachRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                CoachScreen(viewModel: settings.arguments! as CoachViewModel),
          ),
          _ => null,
        },
      ),
    );
  }
}
