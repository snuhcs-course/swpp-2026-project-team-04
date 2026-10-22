import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/rep_event.dart';
import '../services/online/online_battle_session.dart';
import '../services/online/synthetic_battle_pose.dart';
import '../widgets/opponent_avatar_panel.dart';
import '../widgets/pose_avatar_view.dart';

const syntheticOnlineEnabled =
    !kReleaseMode && bool.fromEnvironment('BATTLE_SYNTHETIC_OPPONENT');

/// Explicitly gated debug-only counterpart for one-phone network testing.
class OnlineSyntheticBattleScreen extends StatefulWidget {
  const OnlineSyntheticBattleScreen({super.key, required this.session});
  final OnlineBattleSession session;
  @override
  State<OnlineSyntheticBattleScreen> createState() =>
      _OnlineSyntheticBattleScreenState();
}

class _OnlineSyntheticBattleScreenState
    extends State<OnlineSyntheticBattleScreen> {
  Timer? _timer;
  int _lastRep = 0;
  bool _readySent = false;
  OnlineBattleSession get session => widget.session;
  @override
  void initState() {
    super.initState();
    if (!syntheticOnlineEnabled) return;
    session.addListener(_changed);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _tick() {
    if (session.terminal) return;
    if (session.canReady && !_readySent) {
      _readySent = true;
      session.ready(true);
    }
    session.publishPose(syntheticBattlePose(session.elapsedMs));
    if (session.roundRunning) {
      final completed = session.elapsedMs ~/ 3000;
      if (completed > _lastRep) {
        _lastRep = completed;
        session.submitRep(
          RepEvent(
            index: completed,
            valid: true,
            at: Duration(milliseconds: session.elapsedMs),
          ),
        );
      }
    }
    _changed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    session.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!syntheticOnlineEnabled) {
      return const Scaffold(body: Center(child: Text('개발 전용 기능')));
    }
    final opponent = session.opponent!;
    return PopScope(
      canPop: session.terminal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(session.leave());
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('개발 TEST · 가상 상대')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '위: 휴대폰에서 받은 실제 자세 아바타\n아래: 합성 자세 · 실제 운동 기록 아님',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 5,
              child: OpponentAvatarPanel(
                name: opponent.name,
                model: opponent.avatar,
                frame: session.opponentFrame,
                connected: session.connected && session.opponentConnected,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '휴대폰 ${session.opponentReps}  :  TEST ${session.myReps}   ·   ${(session.remainingMs / 1000).ceil()}초',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 3,
              child: PoseAvatarView(
                mirror: false,
                model: session.avatar,
                frame: syntheticBattlePose(session.elapsedMs),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                session.terminal
                    ? '종료: ${session.outcome ?? session.phase.name}'
                    : session.roundRunning
                    ? '테스트 경기 진행 중'
                    : '가상 상대 준비 완료 · 휴대폰에서 준비해주세요',
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: () async {
                await session.leave();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('테스트 종료'),
            ),
          ],
        ),
      ),
    );
  }
}
