import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/online/pose_wire.dart';

// Sibling standalone server is intentionally exercised through real sockets.
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/battle_server.dart';

import 'package:gymrats_app/shared/battle_protocol.dart';

Future<void> until(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsedMilliseconds > 5000) {
      throw TimeoutException('state not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class Wire {
  static int nextConnection = 0;
  final prefix = 'wire-${nextConnection++}';
  Wire(this.socket) {
    socket.listen(
      (raw) => events.add(
        Map<String, dynamic>.from(jsonDecode(raw as String) as Map),
      ),
    );
  }
  final WebSocket socket;
  final events = <Map<String, dynamic>>[];
  int cursor = 0, sequence = 0;
  String? match;
  static Future<Wire> open(BattleServer server, String token) async {
    final wire = Wire(
      await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/ws/v1/battle',
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    await wire.next('session.welcome');
    return wire;
  }

  Map<String, dynamic> send(
    String type,
    Map<String, dynamic> payload, {
    String? rid,
  }) {
    final message = {
      'v': 1,
      'type': type,
      if (type != 'pose.frame') 'request_id': rid ?? '$prefix-r${++sequence}',
      if (match != null) 'match_id': match,
      'payload': payload,
    };
    socket.add(jsonEncode(message));
    return message;
  }

  Future<Map<String, dynamic>> next(String type) async {
    int index() => events.indexWhere((e) => e['type'] == type, cursor);
    try {
      await until(() => index() >= 0);
    } catch (_) {
      throw StateError(
        'Waiting for $type; received ${events.map((e) => e['type']).toList()}',
      );
    }
    final found = index();
    cursor = found + 1;
    return events[found];
  }

  Future<void> close() => socket.close();
}

void main() {
  test('production battle server defaults to thirty seconds', () async {
    final s = BattleServer(authenticate: (_) => null);
    expect(s.durationMs, 30000);
    await s.close();
  });
  Future<BattleServer> server({
    int duration = 1500,
    int reconnect = 300,
    int ready = 1000,
  }) async {
    final s = BattleServer(
      authenticate: (token) => switch (token) {
        'alpha' => const BattleIdentity('a', 'Alpha'),
        'beta' => const BattleIdentity('b', 'Beta'),
        'third' => const BattleIdentity('c', 'Third'),
        'fourth' => const BattleIdentity('d', 'Fourth'),
        _ => null,
      },
      durationMs: duration,
      countdownMs: 80,
      readyTimeoutMs: ready,
      reconnectMs: reconnect,
    );
    await s.start();
    addTearDown(s.close);
    return s;
  }

  test(
    'rejected login token stops connection without retrying as another user',
    () async {
      final s = await server();
      final session = OnlineBattleSession(
        endpoint: Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle'),
        accessToken: 'invalid-token',
        avatar: AvatarModel.astronaut,
        allowInsecureLoopback: true,
      );
      addTearDown(session.dispose);
      await session.connect();
      expect(session.authenticationRejected, isTrue);
      expect(session.phase, OnlinePhase.failed);
      expect(session.connected, isFalse);
      expect(session.playerId, isNull);
    },
  );

  Future<(Wire, Wire)> paired(BattleServer s) async {
    final a = await Wire.open(s, 'alpha'), b = await Wire.open(s, 'beta');
    addTearDown(a.close);
    addTearDown(b.close);
    a.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_02'});
    b.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_04'});
    final found = await a.next('match.found');
    await b.next('match.found');
    a.match = b.match = found['match_id'] as String;
    return (a, b);
  }

  Future<void> ready(Wire a, Wire b) async {
    a.send('match.ready', {'ready': true});
    b.send('match.ready', {'ready': true});
    final x = await a.next('match.start'), y = await b.next('match.start');
    expect(x['payload'], y['payload']);
    await Future<void>.delayed(const Duration(milliseconds: 110));
  }

  Future<void> joinQueue(Wire wire) async {
    wire.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_01'});
    await wire.next('queue.joined');
  }

  List<String> rosterIds(Map<String, dynamic> found) =>
      (found['payload']['players'] as List)
          .map((p) => p['player_id'] as String)
          .toList();

  test(
    'all catalog avatars can match and appear on the opponent client',
    () async {
      for (final avatar in AvatarModel.values) {
        final s = BattleServer(
          authenticate: (token) => token == 'alpha'
              ? const BattleIdentity('a', 'Alpha')
              : const BattleIdentity('b', 'Beta'),
          readyTimeoutMs: 10000,
        );
        await s.start();
        final endpoint = Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle');
        final a = OnlineBattleSession(
          endpoint: endpoint,
          accessToken: 'alpha',
          avatar: avatar,
          allowInsecureLoopback: true,
        );
        final b = OnlineBattleSession(
          endpoint: endpoint,
          accessToken: 'beta',
          avatar: AvatarModel.robot,
          allowInsecureLoopback: true,
        );
        try {
          await a.connect();
          await until(() => a.phase == OnlinePhase.queued);
          await b.connect();
          await until(
            () =>
                a.phase == OnlinePhase.preparing &&
                b.phase == OnlinePhase.preparing,
          );
          expect(b.opponent!.avatar, avatar);
          expect(a.error, isNull);
          await a.leave();
          await until(() => b.terminal);
        } finally {
          a.dispose();
          b.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await s.close();
        }
      }
    },
  );

  test('FIFO pairs by queue arrival, not connection order', () async {
    final s = await server(ready: 10000);
    final a = await Wire.open(s, 'alpha');
    final b = await Wire.open(s, 'beta');
    final c = await Wire.open(s, 'third');
    final d = await Wire.open(s, 'fourth');
    for (final wire in [a, b, c, d]) {
      addTearDown(wire.close);
    }
    // Reverse socket order deliberately: C,D must pair, then B,A.
    await joinQueue(c);
    expect(c.events.where((e) => e['type'] == 'match.found'), isEmpty);
    await joinQueue(d);
    final first = await c.next('match.found');
    expect(rosterIds(first), ['c', 'd']);
    expect((await d.next('match.found'))['match_id'], first['match_id']);
    await joinQueue(b);
    await joinQueue(a);
    final second = await b.next('match.found');
    expect(rosterIds(second), ['b', 'a']);
    expect((await a.next('match.found'))['match_id'], second['match_id']);
    expect(second['match_id'], isNot(first['match_id']));
  });

  test(
    'FIFO excludes cancelled waiters and rejoin starts a new queue entry',
    () async {
      final s = await server();
      final a = await Wire.open(s, 'alpha');
      final b = await Wire.open(s, 'beta');
      final c = await Wire.open(s, 'third');
      for (final wire in [a, b, c]) {
        addTearDown(wire.close);
      }
      await joinQueue(a);
      a.send('queue.cancel', {'queue_id': 'a'});
      await a.next('queue.cancelled');
      await joinQueue(b);
      await joinQueue(a);
      expect(rosterIds(await b.next('match.found')), ['b', 'a']);
      await a.next('match.found');
      await joinQueue(c);
      expect(c.events.where((e) => e['type'] == 'match.found'), isEmpty);
    },
  );

  test(
    'FIFO removes disconnected waiters before matching the next player',
    () async {
      final s = await server();
      final a = await Wire.open(s, 'alpha');
      await joinQueue(a);
      await a.close();
      // Open subsequent clients only after the first socket has closed.
      final b = await Wire.open(s, 'beta');
      final c = await Wire.open(s, 'third');
      addTearDown(b.close);
      addTearDown(c.close);
      await joinQueue(b);
      await joinQueue(c);
      expect(rosterIds(await b.next('match.found')), ['b', 'c']);
      await c.next('match.found');
      expect(a.events.where((e) => e['type'] == 'match.found'), isEmpty);
    },
  );

  test(
    'pose wire preserves aspect, z and screen movement; rejects image fields',
    () {
      const frame = PoseFrame(
        imageWidth: 480,
        imageHeight: 640,
        keypoints: {
          BodyLandmark.leftElbow: Keypoint(
            landmark: BodyLandmark.leftElbow,
            x: 240,
            y: 320,
            z: -24,
            likelihood: .9,
          ),
        },
      );
      final packet = encodeBattlePose(frame, sequence: 1, elapsedMs: 20),
          decoded = decodeBattlePose(packet);
      expect(decoded.imageWidth / decoded.imageHeight, .75);
      final elbow = decoded[BodyLandmark.leftElbow]!;
      expect(elbow.x / decoded.imageWidth, .5);
      expect(elbow.y / decoded.imageHeight, .5);
      expect(elbow.z / decoded.imageWidth, -.05);
      expect(
        () => checkedPose({...packet, 'image': 'not-allowed'}),
        throwsA(isA<BattleProtocolError>()),
      );
      expect(
        () => checkedPose({
          ...packet,
          'joints': [
            [13, 0, 0, 0, 1],
            [13, 0, 0, 0, 1],
          ],
        }),
        throwsA(isA<BattleProtocolError>()),
      );
      expect(
        () => checkedPose({
          ...packet,
          'joints': [
            [13, double.nan, 0, 0, 1],
          ],
        }),
        throwsA(isA<BattleProtocolError>()),
      );
      expect(
        encodeBattlePose(null, sequence: 2, elapsedMs: 30)['has_person'],
        false,
      );
    },
  );
  test('authentication required and unknown avatar rejected', () async {
    final s = await server();
    await expectLater(
      WebSocket.connect('ws://127.0.0.1:${s.port}/ws/v1/battle'),
      throwsA(isA<WebSocketException>()),
    );
    final a = await Wire.open(s, 'alpha');
    addTearDown(a.close);
    a.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'evil-url'});
    expect((await a.next('error'))['payload']['code'], 'INVALID_AVATAR');
  });
  test('server deduplicates verdicts, rejects conflicts, relays only pose whitelist', () async {
    final s = await server();
    final (a, b) = await paired(s);
    await ready(a, b);
    final rep = {
      'rep_seq': 1,
      'elapsed_ms': 120,
      'valid': true,
      'reason': null,
    };
    final original = a.send('rep.submit', rep, rid: 'rep-first');
    expect((await a.next('rep.accepted'))['payload']['valid_reps'], 1);
    await b.next('rep.updated');
    a.socket.add(jsonEncode(original));
    expect((await a.next('rep.accepted'))['payload']['valid_reps'], 1);
    a.socket.add(
      jsonEncode({
        for (final key in original.keys.toList().reversed) key: original[key],
      }),
    );
    expect((await a.next('rep.accepted'))['payload']['valid_reps'], 1);
    a.send('rep.submit', rep, rid: 'rep-replay');
    expect((await a.next('rep.accepted'))['payload']['valid_reps'], 1);
    a.send('rep.submit', {
      ...rep,
      'valid': false,
      'reason': 'too_fast',
    }, rid: 'conflict');
    expect((await a.next('error'))['payload']['code'], 'REP_CONFLICT');
    a.send('rep.submit', {...rep, 'rep_seq': 3}, rid: 'out-of-order');
    expect((await a.next('error'))['payload']['code'], 'REP_OUT_OF_ORDER');
    a.send('rep.submit', {...rep, 'rep_seq': 2}, rid: 'rep-first');
    expect((await a.next('error'))['payload']['code'], 'REQUEST_ID_REUSED');
    final pose = {
      'frame_seq': 1,
      'elapsed_ms': 130,
      'aspect_ratio': .75,
      'has_person': true,
      'joints': [
        [13, .4, .5, -.1, .9],
      ],
    };
    a.send('pose.frame', pose);
    final received = await b.next('pose.frame');
    expect(received['payload']['player_id'], 'a');
    expect(received['payload']['joints'], pose['joints']);
    a.send('pose.frame', {...pose, 'frame_seq': 2, 'video': 'forbidden'});
    expect((await a.next('error'))['payload']['code'], 'INVALID_PAYLOAD');
    final result = await b.next('match.finished');
    expect(result['payload']['winner_id'], 'a');
    expect((result['payload']['players'] as List).first['valid_reps'], 1);
  });
  test(
    'ready timeout cancels; leaving preparation never fabricates a win',
    () async {
      final s = await server(ready: 150);
      final (a, b) = await paired(s);
      expect(
        (await a.next('match.cancelled'))['payload']['reason'],
        'ready_timeout',
      );
      expect(
        (await b.next('match.cancelled'))['payload'].containsKey('winner_id'),
        false,
      );
    },
  );
  test(
    'disconnect grace resumes and snapshot restores accepted score',
    () async {
      final s = await server(duration: 2000, reconnect: 800);
      final (a, b) = await paired(s);
      await ready(a, b);
      a.send('rep.submit', {
        'rep_seq': 1,
        'elapsed_ms': 120,
        'valid': true,
        'reason': null,
      });
      await a.next('rep.accepted');
      await a.close();
      expect(
        (await b.next('match.connection_state'))['payload']['state'],
        'disconnected',
      );
      final again = await Wire.open(s, 'alpha');
      addTearDown(again.close);
      again.match = a.match;
      again.send('match.resume', {});
      final snapshot = (await again.next('match.snapshot'))['payload'];
      expect(snapshot['scores']['a']['valid_reps'], 1);
      expect(
        (await b.next('match.connection_state'))['payload']['state'],
        'reconnected',
      );
      again.send('match.leave', {'reason': 'user_exit'});
      expect((await b.next('match.finished'))['payload']['winner_id'], 'b');
    },
  );
  test(
    'one lost connection forfeits, two lost connections void rather than win',
    () async {
      final s = await server(duration: 2000);
      final (a, b) = await paired(s);
      await ready(a, b);
      await a.close();
      expect(
        (await b.next('match.finished'))['payload']['reason'],
        'disconnect_timeout',
      );
      expect(
        b.events.lastWhere(
          (e) => e['type'] == 'match.finished',
        )['payload']['winner_id'],
        'b',
      );
      // New match after final result; queued session state is cleared by join.
      final again = await Wire.open(s, 'alpha');
      addTearDown(again.close);
      again.send('queue.join', {
        'exercise': 'push_up',
        'avatar_id': 'avatar_01',
      });
      b.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_02'});
      again.match = (await again.next('match.found'))['match_id'] as String;
      b.match = (await b.next('match.found'))['match_id'] as String;
      await ready(again, b);
      await again.close();
      await b.close();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final resumed = await Wire.open(s, 'alpha');
      addTearDown(resumed.close);
      resumed.match = again.match;
      resumed.send('match.resume', {});
      final p = (await resumed.next('match.snapshot'))['payload'];
      expect(p['status'], 'void');
      expect(p['result']['reason'], 'both_disconnected');
      expect(p['result'].containsKey('winner_id'), false);
    },
  );
  test('two real Flutter sessions match, exchange avatar pose and use server result', () async {
    final s = await server(duration: 3000);
    final uri = Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle');
    final a = OnlineBattleSession(
          endpoint: uri,
          accessToken: 'alpha',
          avatar: AvatarModel.robot,
          allowInsecureLoopback: true,
        ),
        b = OnlineBattleSession(
          endpoint: uri,
          accessToken: 'beta',
          avatar: AvatarModel.humanoid,
          allowInsecureLoopback: true,
        );
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.connect();
    await b.connect();
    await until(
      () =>
          a.phase == OnlinePhase.preparing && b.phase == OnlinePhase.preparing,
    );
    expect(a.opponent!.avatar, AvatarModel.humanoid);
    expect(b.opponent!.avatar, AvatarModel.robot);
    a.ready(true);
    b.ready(true);
    await until(() => a.roundRunning && b.roundRunning);
    const frame = PoseFrame(
      imageWidth: 480,
      imageHeight: 640,
      keypoints: {
        BodyLandmark.leftElbow: Keypoint(
          landmark: BodyLandmark.leftElbow,
          x: 200,
          y: 300,
          z: -10,
          likelihood: .9,
        ),
      },
    );
    a.publishPose(frame);
    await until(() => b.opponentFrame != null);
    expect(b.opponentFrame![BodyLandmark.leftElbow]!.likelihood, .9);
    a.submitRep(const RepEvent(index: 99, valid: true, at: Duration.zero));
    await until(() => b.opponentReps == 1 && a.myReps == 1);
    var rejected = 0;
    for (final reason in RejectReason.values) {
      a.submitRep(
        RepEvent(
          index: 100 + rejected,
          valid: false,
          reason: reason,
          at: Duration.zero,
        ),
      );
      rejected++;
      await until(() => a.myInvalidReps == rejected);
      expect(a.error, isNull, reason: 'Server must accept ${reason.name}');
      // Leave room under the server's per-second control-message limit.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await until(
      () => b.opponentFrame == null,
    ); // no new camera frame → clear stale pose
    await until(
      () => a.phase == OnlinePhase.finished && b.phase == OnlinePhase.finished,
    );
    expect(a.outcome, 'win');
    expect(b.outcome, 'loss');
    expect(a.result!['result_id'], b.result!['result_id']);
  });
  test(
    'client refuses insecure public endpoint without attempting a socket',
    () async {
      final session = OnlineBattleSession(
        endpoint: Uri.parse('ws://52.78.38.225/ws/v1/battle'),
        accessToken: 'not-sent',
        avatar: AvatarModel.astronaut,
        allowInsecureLoopback: true,
      );
      addTearDown(session.dispose);
      await session.connect();
      expect(session.phase, OnlinePhase.failed);
      expect(session.connected, false);
    },
  );
}
