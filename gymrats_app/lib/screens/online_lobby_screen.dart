import 'dart:async';

import 'package:flutter/material.dart';

import '../config/server_config.dart';
import '../models/avatar_model.dart';
import '../services/auth/auth_repository.dart';
import '../services/online/online_battle_session.dart';
import 'online_battle_screen.dart';
import 'online_synthetic_battle_screen.dart';

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
  });
  final AuthRepository auth;
  final OnlineSessionFactory? createSession;
  final Future<void> Function()? onAuthenticationFailed;
  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  AvatarModel _avatar = AvatarModel.astronaut;
  OnlineBattleSession? _session;
  StreamSubscription<void>? _expiry;
  bool _opened = false;
  bool _authFailureHandled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expiry = widget.auth.sessionExpired.listen((_) {
      if (!mounted) return;
      _release();
      setState(() => _error = '로그인이 만료됐어요. 다시 로그인해주세요.');
    });
  }

  Future<void> _join() async {
    if (_session != null) return;
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
    if (session.opponent != null && !session.terminal && !_opened) {
      _opened = true;
      unawaited(_openBattle(session));
    }
    setState(() {});
  }

  Future<void> _openBattle(OnlineBattleSession session) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => syntheticOnlineEnabled
            ? OnlineSyntheticBattleScreen(session: session)
            : OnlineBattleScreen(session: session),
      ),
    );
    if (!mounted) return;
    _release();
    setState(() {});
  }

  void _release() {
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
    unawaited(_expiry?.cancel());
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session, login = widget.auth.session;
    final busy = session != null && !session.terminal;
    return Scaffold(
      appBar: AppBar(title: const Text('온라인 배틀')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
          DropdownButtonFormField<AvatarModel>(
            initialValue: _avatar,
            decoration: const InputDecoration(labelText: '이번 경기의 아바타'),
            items: [
              for (final a in AvatarModel.values)
                DropdownMenuItem(value: a, child: Text(a.label)),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() => _avatar = value!),
          ),
          const SizedBox(height: 24),
          if (session?.phase == OnlinePhase.queued)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('상대를 찾고 있어요… 먼저 참가한 순서대로 두 명씩 연결됩니다.'),
            ),
          if (_error ?? session?.error case final text?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(text, style: const TextStyle(color: Colors.amber)),
            ),
          FilledButton(
            onPressed: busy || login == null
                ? null
                : () {
                    if (_session != null) _release();
                    unawaited(_join());
                  },
            child: Text(busy ? '매칭 연결 중…' : '온라인 상대 찾기'),
          ),
          if (busy)
            TextButton(
              onPressed: () {
                _release();
                setState(() {});
              },
              child: const Text('매칭 취소'),
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
    );
  }
}
