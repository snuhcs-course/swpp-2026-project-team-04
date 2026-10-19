import 'dart:async';

import 'package:flutter/material.dart';

import '../config/server_config.dart';
import '../models/avatar_model.dart';
import '../models/exercise_type.dart';
import '../models/matchup.dart';
import '../services/auth/auth_repository.dart';
import '../services/user/avatar_store.dart';
import '../services/online/online_battle_session.dart';
import '../theme/app_theme.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/grid_background.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import 'matching_screen.dart';
import 'online_battle_screen.dart';
import 'online_synthetic_battle_screen.dart';
import 'versus_screen.dart';

typedef OnlineSessionFactory = OnlineBattleSession Function(
  Uri endpoint,
  String accessToken,
  AvatarModel avatar,
);

/// Uses the existing signed-in account, with no second login or token editor.
class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({
    super.key,
    required this.auth,
    this.createSession,
    this.onAuthenticationFailed,
    this.createCounter,
    this.avatarStore,
    this.autoJoin = true,
  });
  final AuthRepository auth;
  final OnlineSessionFactory? createSession;
  final Future<void> Function()? onAuthenticationFailed;
  final RepCounterViewModel Function()? createCounter;
  final AvatarStore? avatarStore;
  final bool autoJoin;
  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen>
    with SingleTickerProviderStateMixin {
  AvatarModel _avatar = AvatarModel.astronaut;
  OnlineBattleSession? _session;
  StreamSubscription<void>? _expiry;
  bool _opened = false;
  bool _authFailureHandled = false;
  String? _error;
  late final AnimationController _radar;
  Timer? _elapsedTimer;
  final _searchClock = Stopwatch();
  bool _askingToLeave = false;
  late final AvatarStore _avatars;
  bool _loadingAvatar = true, _avatarLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _avatars = widget.avatarStore ?? MemoryAvatarStore();
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
      setState(() {
        _loadingAvatar = false;
        _error = '로그인이 만료됐어요. 다시 로그인해주세요.';
      });
    });
    unawaited(_loadAvatar());
  }

  Future<void> _loadAvatar() async {
    final account = widget.auth.session?.account;
    if (account == null) {
      setState(() => _loadingAvatar = false);
      return;
    }
    setState(() {
      _loadingAvatar = true;
      _avatarLoadFailed = false;
      _error = null;
    });
    try {
      final avatar = await _avatars.read(account.id);
      if (!mounted || widget.auth.session?.account.id != account.id) return;
      setState(() {
        _avatar = avatar;
        _loadingAvatar = false;
      });
      if (widget.autoJoin) await _join();
    } catch (_) {
      if (!mounted || widget.auth.session?.account.id != account.id) return;
      setState(() {
        _loadingAvatar = false;
        _avatarLoadFailed = true;
        _error = '프로필 아바타를 불러오지 못했어요. 다시 시도해주세요.';
      });
    }
  }

  Future<void> _join() async {
    if (_session != null || _loadingAvatar || _avatarLoadFailed) return;
    final login = widget.auth.session;
    if (login == null || login.token.isEmpty) {
      setState(() => _error = '먼저 로그인해주세요.');
      return;
    }
    final endpoint = Uri.parse(gymratsBattleUrl);
    final session =
        widget.createSession?.call(endpoint, login.token, _avatar) ??
        OnlineBattleSession(
          endpoint: endpoint,
          accessToken: login.token,
          avatar: _avatar,
        );
    _session = session;
    _searchClock
      ..reset()
      ..start();
    _radar.repeat();
    session.addListener(_changed);
    setState(() => _error = null);
    await session.connect();
  }

  void _changed() {
    if (!mounted || _session == null) return;
    final session = _session!;
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
    setState(() {});
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
              ),
      ),
    );
    if (!mounted) return;
    // The lobby is still underneath the setup/battle route. Close it too,
    // rather than exposing the old manual-entry screen after leaving a match.
    await _cancelSearch();
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
    if (_loadingAvatar) {
      return const Scaffold(
        body: GridBackground(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (busy && session.opponent != null) {
      return VersusScreen(
        matchup: Matchup(
          exercise: ExerciseType.pushUp,
          playerName: login?.account.nickname ?? '나',
          opponent: Opponent(name: session.opponent!.name, isBot: false),
        ),
        duration: Duration(milliseconds: session.durationMs),
        onStartSetup: () => _openBattle(session),
        onLeave: _cancelSearch,
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
                exercise: ExerciseType.pushUp,
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
            Text(
              'LIVE BATTLE',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(color: AppColors.accent),
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
              '상대 카메라 영상 대신 아바타만 표시해요. 관절 좌표·아바타 종류·판정만 전송하고 영상과 음성은 전송하지 않습니다.',
            ),
            const SizedBox(height: 24),
            Text('프로필 아바타 · ${_avatar.label}'),
            const Text('아바타는 홈의 프로필에서 변경할 수 있어요.'),
            const SizedBox(height: 24),
            if (_error ?? session?.error case final text?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(text, style: const TextStyle(color: Colors.amber)),
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
                      if (_avatarLoadFailed) {
                        unawaited(_loadAvatar());
                        return;
                      }
                      if (_session != null) _release();
                      unawaited(_join());
                    },
              child: Text(_avatarLoadFailed ? '다시 시도' : '온라인 상대 찾기'),
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
