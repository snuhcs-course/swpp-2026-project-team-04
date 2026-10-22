import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/services/auth/token_store.dart';
import 'package:gymrats_app/services/online/synthetic_battle_pose.dart';

Future<void> waitFor(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsedMilliseconds > 15000) {
      throw TimeoutException('Public WSS smoke timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('synthetic pose is explicit coordinate-only moving data', () {
    final top = syntheticBattlePose(0), bottom = syntheticBattlePose(1500);
    expect(top.keypoints.length, lessThanOrEqualTo(33));
    expect(
      top.keypoints.values.every(
        (p) => p.x.isFinite && p.y.isFinite && p.z.isFinite,
      ),
      isTrue,
    );
    expect(
      top.keypoints.values.first.y,
      isNot(bottom.keypoints.values.first.y),
    );
  });

  test(
    'public trusted TLS, real login, FIFO, avatar pose, score and result',
    () async {
      final endpoint = Uri.parse('wss://52.78.38.225/ws/v1/battle');
      final authA = ServerAuthRepository(
        api: ApiClient(),
        store: MemoryTokenStore(),
      );
      final authB = ServerAuthRepository(
        api: ApiClient(),
        store: MemoryTokenStore(),
      );
      final random = Random.secure();
      Future<void> signIn(ServerAuthRepository auth, String nickname) async {
        final suffix = List.generate(
          12,
          (_) => random.nextInt(16).toRadixString(16),
        ).join();
        final password = List.generate(
          32,
          (_) => random.nextInt(16).toRadixString(16),
        ).join();
        await auth.signUp(
          nickname: nickname,
          loginId: 'test_$suffix',
          password: password,
        );
        await auth.logOut();
        await auth.logIn(loginId: 'test_$suffix', password: password);
      }

      await signIn(authA, '로그인 TEST A');
      await signIn(authB, '로그인 TEST B');
      final a = OnlineBattleSession(
        endpoint: endpoint,
        accessToken: authA.session!.token,
        avatar: AvatarModel.astronaut,
      );
      final b = OnlineBattleSession(
        endpoint: endpoint,
        accessToken: authB.session!.token,
        avatar: AvatarModel.robot,
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.connect();
      await waitFor(() => a.phase == OnlinePhase.queued);
      await b.connect();
      await waitFor(() => a.opponent != null && b.opponent != null);
      expect(a.playerId, authA.session!.account.id.toString());
      expect(b.playerId, authB.session!.account.id.toString());
      expect(a.opponent!.name, authB.session!.account.nickname);
      expect(a.opponent!.avatar, AvatarModel.robot);
      expect(b.opponent!.avatar, AvatarModel.astronaut);
      a.ready(true);
      b.ready(true);
      await waitFor(() => a.roundRunning && b.roundRunning);
      final publisher = Timer.periodic(const Duration(milliseconds: 100), (_) {
        a.publishPose(syntheticBattlePose(a.elapsedMs));
        b.publishPose(syntheticBattlePose(b.elapsedMs));
      });
      addTearDown(publisher.cancel);
      await waitFor(() => a.opponentFrame != null && b.opponentFrame != null);
      a.submitRep(
        RepEvent(
          index: 1,
          valid: true,
          at: Duration(milliseconds: a.elapsedMs),
        ),
      );
      await waitFor(() => a.myReps == 1 && b.opponentReps == 1);
      await a.leave();
      await waitFor(() => a.terminal && b.terminal);
      expect(a.outcome, 'loss');
      expect(b.outcome, 'win');
    },
    skip: !const bool.fromEnvironment('RUN_PUBLIC_BATTLE_SMOKE'),
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
