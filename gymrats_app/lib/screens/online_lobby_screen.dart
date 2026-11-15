import 'dart:async';

import 'package:flutter/material.dart';

import '../config/server_config.dart';
import '../models/character_rig.dart';
import '../models/exercise_type.dart';
import '../models/matchup.dart';
import '../services/auth/auth_repository.dart';
import '../services/user/user_repository.dart';
import '../services/online/online_battle_session.dart';
import '../theme/app_theme.dart';
import '../widgets/battle_stage_model.dart';
import '../widgets/character_figure.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/grid_background.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import 'battle_screen.dart' show BattleSetupListener;
import 'matching_screen.dart';
import 'online_battle_screen.dart';
import 'online_synthetic_battle_screen.dart';
import 'versus_screen.dart';

typedef OnlineSessionFactory = OnlineBattleSession Function(
  Uri endpoint,
  String accessToken,
  String character,
);

/// Uses the existing signed-in account, with no second login or token editor.
class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({
    super.key,
    required this.auth,
    this.exercise = ExerciseType.pushUp,
    this.createSession,
    this.onAuthenticationFailed,
    this.createCounter,
    this.myCharacter = CharacterRig.defaultId,
    this.autoJoin = true,
    this.userRepository,
    this.onCue,
    this.onSetup,
  });
  final AuthRepository auth;
  final ExerciseType exercise;
  final OnlineSessionFactory? createSession;
  final Future<void> Function()? onAuthenticationFailed;
  final RepCounterViewModel Function()? createCounter;

  /// The user's character id, sent to the server for the opponent's stage
  /// (W3).
  final String myCharacter;
  final bool autoJoin;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Where the battle's form feedback is uploaded; null keeps it on the
  /// phone only.
  final UserRepository? userRepository;

  /// Passed on to the battle it opens ([OnlineBattleScreen.onCue] and
  /// [OnlineBattleScreen.onSetup]), so sound hooks in where the app builds
  /// this lobby, without changing it.
  final ValueChanged<BattleStageCue>? onCue;
  final BattleSetupListener? onSetup;

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen>
    with SingleTickerProviderStateMixin {
  /// The server cancels a match whose players are not ready within 60 s of
  /// `match.found` (protocol §5, `ready_deadline_ms`). The safety warning
  /// takes at most this much of that time.
  static const _warningAutoClose = Duration(seconds: 5);

  OnlineBattleSession? _session;
  StreamSubscription<void>? _expiry;
  bool _opened = false;
  bool _authFailureHandled = false;
  String? _error;
  late final AnimationController _radar;
  Timer? _elapsedTimer;
  final _searchClock = Stopwatch();
  bool _askingToLeave = false;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _searchClock.isRunning) setState(() {});
    });
    _expiry = widget.auth.sessionExpired.listen((_) {
      if (!mounted) return;
      _release();
      setState(() => _error = '로그인이 만료됐어요. 다시 로그인해주세요.');
    });
    // Searching from the first frame. What connecting says before its first
    // wait is read by that first build; what comes after reaches _changed.
    final session = widget.autoJoin ? _start() : null;
    if (session != null) {
      unawaited(session.connect());
      session.addListener(_changed);
      _follow(session);
    }
  }

  /// Makes the session that searches with [OnlineLobbyScreen.myCharacter],
  /// without connecting it or listening to it; null when there is no login
  /// to search with.
  OnlineBattleSession? _start() {
    final login = widget.auth.session;
    if (login == null || login.token.isEmpty) {
      _error = '먼저 로그인해주세요.';
      return null;
    }
    final endpoint = Uri.parse(gymratsBattleUrl);
    final session =
        widget.createSession?.call(endpoint, login.token, widget.myCharacter) ??
        OnlineBattleSession(
          endpoint: endpoint,
          accessToken: login.token,
          character: widget.myCharacter,
          exercise: widget.exercise,
        );
    _session = session;
    _error = null;
    _searchClock
      ..reset()
      ..start();
    _radar.repeat();
    return session;
  }

  Future<void> _join() async {
    if (_session != null) return;
    final session = _start()?..addListener(_changed);
    setState(() {});
    await session?.connect();
  }

  void _changed() {
    if (!mounted || _session == null) return;
    _follow(_session!);
    setState(() {});
  }

  /// Acts on what [session] says now: a refused login signs out, and a
  /// found opponent or an ended search stops the radar and its clock.
  void _follow(OnlineBattleSession session) {
    if (session.authenticationRejected && !_authFailureHandled) {
      _authFailureHandled = true;
      if (widget.onAuthenticationFailed case final signOut?) {
        unawaited(signOut());
      }
    }
    if (session.opponent != null || session.terminal) {
      _radar.stop();
      _searchClock.stop();
    }
  }

  Future<void> _openBattle(OnlineBattleSession session) async {
    if (_opened || session.terminal || !identical(session, _session)) return;
    _opened = true;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => syntheticOnlineEnabled
            ? OnlineSyntheticBattleScreen(session: session)
            : OnlineBattleScreen(
                session: session,
                createCounter: widget.createCounter,
                userRepository: widget.userRepository,
                playerName: widget.auth.session?.account.nickname ?? '나',
                onCue: widget.onCue,
                onSetup: widget.onSetup,
              ),
      ),
    );
    if (!mounted) return;
    // The lobby is still underneath the setup/battle route. Close it too,
    // rather than exposing the old manual-entry screen after leaving a match.
    // The battle may have handed over to the result screen, which then sits
    // on top: only the lobby's own route goes.
    _release();
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.pop(context);
    } else {
      Navigator.removeRoute(context, route);
    }
  }

  Future<void> _cancelSearch() async {
    _release();
    if (!mounted) return;
    setState(() {});
    if (Navigator.of(context).canPop()) Navigator.pop(context);
  }

  Future<void> _askToLeave() async {
    if (_askingToLeave) return;
    _askingToLeave = true;
    final leave = await confirmExit(context, const ExitDialog.matching());
    _askingToLeave = false;
    if (mounted && leave) await _cancelSearch();
  }

  void _release() {
    _radar.stop();
    _searchClock.stop();
    final session = _session;
    _session = null;
    session?.removeListener(_changed);
    if (session != null) {
      unawaited(session.leave());
      session.dispose();
    }
    _opened = false;
    _authFailureHandled = false;
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    unawaited(_expiry?.cancel());
    _release();
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session, login = widget.auth.session;
    final busy = session != null && !session.terminal;
    if (busy && session.opponent != null) {
      return VersusScreen(
        matchup: Matchup(
          exercise: widget.exercise,
          playerName: login?.account.nickname ?? '나',
          opponent: Opponent(name: session.opponent!.name, isBot: false),
        ),
        // As the battle draws them: mine as sent, theirs as the server
        // passed it on.
        characters: BattleCharacters(
          me: session.character,
          opponent: session.opponent!.character,
        ),
        duration: Duration(milliseconds: session.durationMs),
        onStartSetup: () => _openBattle(session),
        onLeave: _cancelSearch,
        warningAutoClose: _warningAutoClose,
      );
    }
    if (busy) {
      return PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_askToLeave());
        },
        child: Scaffold(
          body: GridBackground(
            child: SafeArea(
              child: BattleSearchView(
                exercise: widget.exercise,
                title: '실시간 상대를 찾는 중',
                duration: Duration(milliseconds: session.durationMs),
                searchArea: BattleSearchRadar(
                  animation: _radar,
                  elapsed: _searchClock.elapsed,
                  playerName: login?.account.nickname,
                ),
                onCancel: () => unawaited(_cancelSearch()),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('실시간 배틀')),
      body: GridBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Palette B: text is ink; lime only fills.
            Text(
              'LIVE BATTLE',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            Text(
              login == null
                  ? '로그인이 필요해요.'
                  : '${login.account.nickname} 계정으로 참가합니다.',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '상대 카메라 영상 대신 상대의 캐릭터만 표시해요. 관절 좌표·캐릭터 종류·판정만 전송하고 영상과 음성은 전송하지 않습니다.',
            ),
            const SizedBox(height: 24),
            Text('캐릭터 · ${CharacterRig.standard.art(widget.myCharacter).name}'),
            const Text('캐릭터는 게임 시작의 캐릭터 줄에서 바꿀 수 있어요.'),
            const SizedBox(height: 24),
            // Ink words on an amber band (palette B: amber only fills).
            if (_error ?? session?.error case final text?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DecoratedBox(
                  decoration: AppHighlight.band(AppColors.warning),
                  child: Padding(
                    padding: AppHighlight.bandPadding,
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.ink),
                    ),
                  ),
                ),
              ),
            if (session?.terminal == true && session?.error == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('매칭이 종료됐어요. 다시 상대를 찾아주세요.'),
              ),
            FilledButton(
              onPressed: login == null
                  ? null
                  : () {
                      if (_session != null) _release();
                      unawaited(_join());
                    },
              child: const Text('온라인 상대 찾기'),
            ),
            const SizedBox(height: 20),
            const Text(
              '고정 팀 서버 · HTTPS/WSS 암호화 연결\n두 기기는 서로 다른 계정으로 로그인해주세요.',
              style: TextStyle(fontSize: 12),
            ),
            if (syntheticOnlineEnabled)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('에뮬레이터 개발 모드: 매칭 후 가상 자세를 전송합니다. 실제 운동 기록이 아닙니다.'),
              ),
          ],
        ),
      ),
    );
  }
}
